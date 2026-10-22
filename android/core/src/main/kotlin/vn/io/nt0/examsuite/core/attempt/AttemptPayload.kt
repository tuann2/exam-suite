package vn.io.nt0.examsuite.core.attempt

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.int
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import vn.io.nt0.examsuite.core.composer.CompositionOptions
import vn.io.nt0.examsuite.core.composer.ExamPaper
import vn.io.nt0.examsuite.core.composer.PaperItem
import vn.io.nt0.examsuite.core.composer.QuestionSelection
import vn.io.nt0.examsuite.core.model.OptionId
import vn.io.nt0.examsuite.core.model.StrictUuid
import vn.io.nt0.examsuite.core.scoring.QuestionOutcome
import vn.io.nt0.examsuite.core.scoring.ScoreResult
import vn.io.nt0.examsuite.core.scoring.Scorer
import vn.io.nt0.examsuite.core.scoring.SectionScore
import vn.io.nt0.examsuite.core.session.ExamSession
import vn.io.nt0.examsuite.core.session.SessionMode
import vn.io.nt0.examsuite.core.session.SessionPhase
import java.util.UUID

sealed class AttemptPayloadException(message: String) : Exception(message) {
    data class SessionNotSubmitted(val phase: SessionPhase) : AttemptPayloadException("phiên chưa nộp ($phase)")

    data class MissingFingerprint(val questionId: UUID) : AttemptPayloadException("thiếu dấu vân tay câu $questionId")

    data class InvalidFingerprint(val questionId: UUID) : AttemptPayloadException("dấu vân tay câu $questionId sai dạng")

    /** Payload ghi bởi bản app mới hơn. */
    data class UnsupportedVersion(val found: Int, val supported: Int) : AttemptPayloadException("payload v$found, app hiểu tới v$supported")

    /** JSON hỏng, thiếu khoá, sai kiểu, giá trị sai; lý do kỹ thuật cho nhật ký. */
    data class Malformed(val reason: String) : AttemptPayloadException("payload hỏng: $reason")

    /** Đọc được nhưng mâu thuẫn (câu ngoài đề, tổng lệch…). */
    data class Inconsistent(val reason: String) : AttemptPayloadException("payload mâu thuẫn: $reason")
}

/**
 * Chi tiết một lần thi đã nộp của bản Android, lưu ở cột payload của lần thi (docs/product/exam-taking.md, "Dữ liệu một
 * lần thi"). **Định dạng riêng của Android** (Nt0 chốt Q11 2026-10-22), cùng nội dung và cùng luật kiểm nhất quán với
 * `AttemptRecord` của bản macOS; dấu vân tay câu cùng thuật toán. Đổi khoá hay nghĩa của trường đã có phải tăng
 * [CURRENT_VERSION] kèm bước đọc bản cũ (test JSON mẫu cố định chặn đổi vô tình).
 *
 * JSON (`payloadVersion` 1), khoá cố định, viết gọn:
 * `payloadVersion`, `mode` ("practice" | "exam"), `timeLimitMinutes` (chỉ Thi), `paper` {`examId`, `options`
 * {`selection` {`kind`, `sectionIds` | `count` | `questionIds`}, `shuffleQuestions`, `shuffleOptions`, `seed` (chuỗi
 * thập phân 64 bit không dấu)}, `items` [{`questionId`, `sectionId`, `optionOrder`}]}, `answers` {id câu: [mã đã sắp
 * xếp]}, `flagged`, `checkedQuestionIds` (sắp xếp), `result` {`total`, `correct`, `score1000`, `percent`,
 * `passPercent`, `passed`, `sections`, `outcomes`, `questionIds`}, `fingerprints` {id câu: sha-256 hex}.
 */
data class AttemptPayload(
    val mode: SessionMode,
    val timeLimitMinutes: Int?,
    val paper: ExamPaper,
    val answers: Map<UUID, Set<OptionId>>,
    val flagged: Set<UUID>,
    val checkedQuestionIds: Set<UUID>,
    val result: ScoreResult,
    val fingerprints: Map<UUID, String>,
) {
    val examId: UUID get() = paper.examId
    val options: CompositionOptions get() = paper.options

    fun encode(): String = json.encodeToString(PayloadDto.serializer(), toDto())

    /** Điều mâu thuẫn đầu tiên; null nếu nhất quán. Cùng luật với `AttemptRecord.consistencyProblem` của bản macOS. */
    fun consistencyProblem(): String? {
        val items = paper.items
        if (items.isEmpty()) return "đề của lần thi không có câu"
        val paperIds = items.map { it.questionId }.toSet()
        if (paperIds.size != items.size) return "đề của lần thi có câu lặp"
        when (mode) {
            SessionMode.PRACTICE -> {
                if (timeLimitMinutes != null) return "Luyện tập không có thời gian cho phép"
                if (!answers.keys.containsAll(checkedQuestionIds)) return "câu đã Kiểm tra đáp án phải có đáp án"
            }
            SessionMode.EXAM -> {
                if (timeLimitMinutes == null || timeLimitMinutes !in ExamSession.TIME_LIMIT_RANGE) return "Thi phải có thời gian 1–600"
                if (checkedQuestionIds.isNotEmpty()) return "Thi không có Kiểm tra đáp án"
            }
        }
        when (val selection = paper.options.selection) {
            QuestionSelection.All -> Unit
            is QuestionSelection.Sections -> items.firstOrNull { it.sectionId !in selection.ids }?.let {
                return "câu ${it.questionId} thuộc phần không được chọn"
            }
            is QuestionSelection.Random -> if (selection.count != items.size) return "chọn ${selection.count} câu nhưng đề có ${items.size}"
            is QuestionSelection.Questions -> if (selection.ids.toSet() != paperIds) return "danh sách câu đã chọn khác các câu của đề"
        }
        resultProblem(result)?.let { return it }
        if (result.questionIds != paper.questionIds) return "kết quả không khớp thứ tự câu của đề"
        val byId = items.associateBy { it.questionId }
        for ((id, selected) in answers) {
            val item = byId[id] ?: return "đáp án của câu $id không thuộc đề"
            if (selected.isEmpty()) return "đáp án rỗng ở câu $id"
            if (!item.optionOrder.toSet().containsAll(selected)) return "đáp án câu $id có lựa chọn không thuộc câu"
        }
        for (item in items) {
            val answered = item.questionId in answers
            val unanswered = result.outcomes[item.questionId] == QuestionOutcome.UNANSWERED
            if (answered == unanswered) return "kết quả câu ${item.questionId} không khớp đáp án"
        }
        val counts = HashMap<UUID, IntArray>()
        for (item in items) {
            val c = counts.getOrPut(item.sectionId) { IntArray(2) }
            c[0] += 1
            if (result.outcomes[item.questionId] == QuestionOutcome.CORRECT) c[1] += 1
        }
        val sectionIds = result.sections.map { it.sectionId }.toSet()
        counts.keys.firstOrNull { it !in sectionIds }?.let { return "phần $it có câu nhưng không có trong kết quả" }
        for (section in result.sections) {
            val c = counts[section.sectionId] ?: IntArray(2)
            if (section.total != c[0] || section.correct != c[1]) return "kết quả phần ${section.sectionId} không khớp các câu"
        }
        if (!paperIds.containsAll(flagged)) return "câu đánh dấu không thuộc đề"
        if (fingerprints.keys != paperIds) return "dấu vân tay không khớp các câu của đề"
        fingerprints.entries.firstOrNull { !isValidFingerprint(it.value) }?.let { return "dấu vân tay câu ${it.key} không phải SHA-256 hex" }
        return null
    }

    private fun toDto() = PayloadDto(
        payloadVersion = CURRENT_VERSION,
        mode = mode.raw,
        timeLimitMinutes = timeLimitMinutes,
        paper = PaperDto(
            examId = paper.examId.toString(),
            options = OptionsDto(
                selection = when (val s = paper.options.selection) {
                    QuestionSelection.All -> SelectionDto("all")
                    is QuestionSelection.Sections -> SelectionDto("sections", sectionIds = s.ids.map { it.toString() }.sorted())
                    is QuestionSelection.Random -> SelectionDto("random", count = s.count)
                    is QuestionSelection.Questions -> SelectionDto("questions", questionIds = s.ids.map { it.toString() })
                },
                shuffleQuestions = paper.options.shuffleQuestions,
                shuffleOptions = paper.options.shuffleOptions,
                seed = paper.options.seed.toString(),
            ),
            items = paper.items.map { ItemDto(it.questionId.toString(), it.sectionId.toString(), it.optionOrder.map { o -> o.toString() }) },
        ),
        answers = answers.entries.associate { (id, set) -> id.toString() to set.sorted().map { it.toString() } }.toSortedMap(),
        flagged = flagged.map { it.toString() }.sorted(),
        checkedQuestionIds = checkedQuestionIds.map { it.toString() }.sorted(),
        result = ResultDto(
            total = result.total, correct = result.correct, score1000 = result.score1000, percent = result.percent,
            passPercent = result.passPercent, passed = result.passed,
            sections = result.sections.map { SectionDto(it.sectionId.toString(), it.title, it.total, it.correct) },
            outcomes = result.outcomes.entries.associate { (id, o) -> id.toString() to o.name.lowercase() }.toSortedMap(),
            questionIds = result.questionIds.map { it.toString() },
        ),
        fingerprints = fingerprints.entries.associate { (id, fp) -> id.toString() to fp }.toSortedMap(),
    )

    companion object {
        const val CURRENT_VERSION = 1

        private val json = Json { encodeDefaults = false; explicitNulls = false }

        fun isValidFingerprint(value: String): Boolean = value.length == 64 && value.all { it in '0'..'9' || it in 'a'..'f' }

        /** Payload của phiên đã nộp; `fingerprints` phải có mọi câu của đề đã tạo (câu khác bị bỏ). */
        fun from(session: ExamSession, fingerprints: Map<UUID, String>): AttemptPayload {
            val result = session.result
            if (session.phase != SessionPhase.Submitted || result == null) throw AttemptPayloadException.SessionNotSubmitted(session.phase)
            val kept = LinkedHashMap<UUID, String>()
            for (id in session.paper.questionIds) {
                val value = fingerprints[id] ?: throw AttemptPayloadException.MissingFingerprint(id)
                if (!isValidFingerprint(value)) throw AttemptPayloadException.InvalidFingerprint(id)
                kept[id] = value
            }
            val payload = AttemptPayload(session.mode, session.timeLimitMinutes, session.paper, session.answers, session.flagged,
                session.checkedQuestionIds, result, kept)
            payload.consistencyProblem()?.let { throw AttemptPayloadException.Inconsistent(it) }
            return payload
        }

        /** Đọc payload: `payloadVersion` trước mọi trường khác, rồi kiểu, rồi nhất quán. */
        fun decode(text: String): AttemptPayload {
            val version = try {
                json.parseToJsonElement(text).jsonObject["payloadVersion"]?.jsonPrimitive
            } catch (e: Exception) {
                throw AttemptPayloadException.Malformed("không phải object JSON: ${e.message}")
            }
            val v = version?.intOrNull ?: throw AttemptPayloadException.Malformed("thiếu hoặc sai payloadVersion")
            if (v < 1) throw AttemptPayloadException.Malformed("payloadVersion phải ≥ 1, nhận $v")
            if (v > CURRENT_VERSION) throw AttemptPayloadException.UnsupportedVersion(v, CURRENT_VERSION)
            val dto = try {
                json.decodeFromString(PayloadDto.serializer(), text)
            } catch (e: SerializationException) {
                throw AttemptPayloadException.Malformed(e.message ?: "")
            } catch (e: IllegalArgumentException) {
                throw AttemptPayloadException.Malformed(e.message ?: "")
            }
            val payload = fromDto(dto)
            payload.consistencyProblem()?.let { throw AttemptPayloadException.Inconsistent(it) }
            return payload
        }

        private fun malformed(reason: String): Nothing = throw AttemptPayloadException.Malformed(reason)

        private fun uuid(text: String) = StrictUuid.parse(text) ?: malformed("UUID sai \"$text\"")

        private fun option(text: String) = OptionId.of(text) ?: malformed("mã lựa chọn sai \"$text\"")

        private fun uniqueIds(list: List<String>, what: String): Set<UUID> {
            val set = list.map(::uuid).toSet()
            if (set.size != list.size) malformed("$what có id trùng")
            return set
        }

        private fun fromDto(dto: PayloadDto): AttemptPayload {
            val mode = SessionMode.entries.firstOrNull { it.raw == dto.mode } ?: malformed("mode lạ \"${dto.mode}\"")
            val o = dto.paper.options
            val selection = when (o.selection.kind) {
                "all" -> QuestionSelection.All
                "sections" -> QuestionSelection.Sections(uniqueIds(o.selection.sectionIds ?: malformed("thiếu sectionIds"), "sectionIds"))
                "random" -> QuestionSelection.Random(o.selection.count ?: malformed("thiếu count"))
                "questions" -> QuestionSelection.Questions((o.selection.questionIds ?: malformed("thiếu questionIds")).map(::uuid))
                else -> malformed("kind lạ \"${o.selection.kind}\"")
            }
            val seed = o.seed.toULongOrNull() ?: malformed("seed phải là số thập phân 64 bit không dấu")
            val items = dto.paper.items.map { item ->
                val order = item.optionOrder.map(::option)
                if (order.toSet().size != order.size) malformed("thứ tự lựa chọn có mã trùng")
                PaperItem(uuid(item.questionId), uuid(item.sectionId), order)
            }
            val answers = dto.answers.entries.associate { (id, letters) ->
                val set = letters.map(::option).toSet()
                if (set.size != letters.size) malformed("đáp án câu $id có lựa chọn trùng")
                uuid(id) to set
            }
            val r = dto.result
            val result = ScoreResult(
                total = r.total, correct = r.correct, score1000 = r.score1000, percent = r.percent, passPercent = r.passPercent,
                passed = r.passed,
                sections = r.sections.map { SectionScore(uuid(it.sectionId), it.title, it.total, it.correct) },
                outcomes = r.outcomes.entries.associate { (id, value) ->
                    uuid(id) to (QuestionOutcome.entries.firstOrNull { it.name.lowercase() == value } ?: malformed("kết quả lạ \"$value\""))
                },
                questionIds = r.questionIds.map(::uuid),
            )
            return AttemptPayload(
                mode = mode,
                timeLimitMinutes = dto.timeLimitMinutes,
                paper = ExamPaper(uuid(dto.paper.examId), CompositionOptions(selection, o.shuffleQuestions, o.shuffleOptions, seed), items),
                answers = answers,
                flagged = uniqueIds(dto.flagged, "flagged"),
                checkedQuestionIds = uniqueIds(dto.checkedQuestionIds, "checkedQuestionIds"),
                result = result,
                fingerprints = dto.fingerprints.entries.associate { (id, fp) -> uuid(id) to fp },
            )
        }

        /** Luật bên trong `ScoreResult` (cùng `ScoreResult.init(from:)` của bản macOS). */
        private fun resultProblem(r: ScoreResult): String? {
            val ids = r.questionIds.toSet()
            if (ids.size != r.questionIds.size) return "danh sách câu của kết quả có id trùng"
            if (r.total != r.questionIds.size) return "total = ${r.total} nhưng có ${r.questionIds.size} câu"
            if (r.outcomes.keys != ids) return "kết quả từng câu không khớp danh sách câu"
            val counted = r.outcomes.values.count { it == QuestionOutcome.CORRECT }
            if (r.correct != counted) return "correct = ${r.correct} nhưng có $counted câu đúng"
            if (r.sections.map { it.sectionId }.toSet().size != r.sections.size) return "phần có id trùng"
            if (r.sections.any { it.correct < 0 || it.correct > it.total }) return "phần có số câu đúng sai"
            val sectionTotal = r.sections.sumOf { it.total.toLong() }
            val sectionCorrect = r.sections.sumOf { it.correct.toLong() }
            if (sectionTotal != r.total.toLong() || sectionCorrect != r.correct.toLong()) return "tổng theo phần khác tổng chung"
            if (r.score1000 != Scorer.score1000(r.correct, r.total)) return "score1000 không khớp"
            if (r.percent != Scorer.percent(r.correct, r.total)) return "percent không khớp"
            if (r.passPercent !in 0..100) return "passPercent ngoài 0–100"
            if (r.passed != Scorer.isPassed(r.score1000, r.passPercent)) return "passed không khớp"
            return null
        }
    }
}

@Serializable
internal data class PayloadDto(
    val payloadVersion: Int,
    val mode: String,
    val timeLimitMinutes: Int? = null,
    val paper: PaperDto,
    val answers: Map<String, List<String>>,
    val flagged: List<String>,
    val checkedQuestionIds: List<String>,
    val result: ResultDto,
    val fingerprints: Map<String, String>,
)

@Serializable
internal data class PaperDto(val examId: String, val options: OptionsDto, val items: List<ItemDto>)

@Serializable
internal data class OptionsDto(val selection: SelectionDto, val shuffleQuestions: Boolean, val shuffleOptions: Boolean, val seed: String)

@Serializable
internal data class SelectionDto(
    val kind: String,
    val sectionIds: List<String>? = null,
    val count: Int? = null,
    val questionIds: List<String>? = null,
)

@Serializable
internal data class ItemDto(val questionId: String, val sectionId: String, val optionOrder: List<String>)

@Serializable
internal data class ResultDto(
    val total: Int,
    val correct: Int,
    val score1000: Int,
    val percent: Int,
    val passPercent: Int,
    val passed: Boolean,
    val sections: List<SectionDto>,
    val outcomes: Map<String, String>,
    val questionIds: List<String>,
)

@Serializable
internal data class SectionDto(val sectionId: String, val title: String, val total: Int, val correct: Int)
