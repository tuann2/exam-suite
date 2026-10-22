package vn.io.nt0.examsuite.core.session

import kotlinx.serialization.Serializable
import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import vn.io.nt0.examsuite.core.composer.CompositionOptions
import vn.io.nt0.examsuite.core.composer.ExamPaper
import vn.io.nt0.examsuite.core.composer.PaperItem
import vn.io.nt0.examsuite.core.composer.QuestionSelection
import vn.io.nt0.examsuite.core.model.OptionId
import vn.io.nt0.examsuite.core.model.StrictUuid
import java.time.Instant

/**
 * JSON của phiên dở (`SessionSnapshot`, mobile.md Q7), để tầng dữ liệu (A2) lưu khi app xuống nền. Có `draftVersion`;
 * đọc hỏng hay phiên bản mới hơn thì trả lỗi để app bỏ phiên dở (không khôi phục sai). Kiểm khớp đề là việc của
 * `ExamSession.restore`.
 */
object SnapshotCodec {
    const val CURRENT_VERSION = 1

    class DecodeException(message: String) : Exception(message)

    private val json = Json { encodeDefaults = false; explicitNulls = false }

    fun encode(s: SessionSnapshot): String = json.encodeToString(DraftDto.serializer(), DraftDto(
        draftVersion = CURRENT_VERSION,
        examId = s.examId.toString(),
        mode = s.mode.raw,
        timeLimitMinutes = s.timeLimitMinutes,
        candidateName = s.candidateName,
        startedAtEpochMillis = s.startedAt.toEpochMilli(),
        selection = when (val sel = s.paper.options.selection) {
            QuestionSelection.All -> DraftSelection("all")
            is QuestionSelection.Sections -> DraftSelection("sections", ids = sel.ids.map { it.toString() }.sorted())
            is QuestionSelection.Random -> DraftSelection("random", count = sel.count)
            is QuestionSelection.Questions -> DraftSelection("questions", ids = sel.ids.map { it.toString() })
        },
        shuffleQuestions = s.paper.options.shuffleQuestions,
        shuffleOptions = s.paper.options.shuffleOptions,
        seed = s.paper.options.seed.toString(),
        items = s.paper.items.map { DraftItem(it.questionId.toString(), it.sectionId.toString(), it.optionOrder.joinToString("")) },
        phase = phaseName(s.phase),
        phaseBeforePause = s.phaseBeforePause?.let(::phaseName),
        pauseReason = s.pauseReason?.name,
        currentIndex = s.currentIndex,
        answers = s.answers.entries.associate { (id, set) -> id.toString() to set.sorted().joinToString("") }.toSortedMap(),
        flagged = s.flagged.map { it.toString() }.sorted(),
        checked = s.checkedQuestionIds.map { it.toString() }.sorted(),
        elapsedSeconds = s.elapsedSeconds,
        issuedWarnings = s.issuedWarnings.sorted(),
        pendingEvents = s.pendingEvents.map { if (it is SessionEvent.Warning) "warning:${it.minutesLeft}" else "timeUp" },
        fingerprints = s.fingerprints.entries.associate { (id, fp) -> id.toString() to fp }.toSortedMap(),
    ))

    fun decode(text: String): SessionSnapshot {
        val version = try {
            json.parseToJsonElement(text).jsonObject["draftVersion"]?.jsonPrimitive?.intOrNull
        } catch (e: Exception) {
            fail("không phải object JSON")
        } ?: fail("thiếu draftVersion")
        if (version != CURRENT_VERSION) fail("draftVersion $version, app hiểu $CURRENT_VERSION")
        vn.io.nt0.examsuite.core.attempt.StrictPayloadJson.problem(
            json.parseToJsonElement(text),
            numericKeys = setOf("draftVersion", "timeLimitMinutes", "startedAtEpochMillis", "currentIndex", "elapsedSeconds", "count", "issuedWarnings"),
            booleanKeys = setOf("shuffleQuestions", "shuffleOptions"),
            uuidKeyedMaps = setOf("answers", "fingerprints"),
        )?.let { fail(it) }
        val d = try {
            json.decodeFromString(DraftDto.serializer(), text)
        } catch (e: SerializationException) {
            fail(e.message ?: "")
        } catch (e: IllegalArgumentException) {
            fail(e.message ?: "")
        }
        fun uuid(t: String) = StrictUuid.parse(t) ?: fail("UUID sai \"$t\"")
        fun letters(t: String) = t.map { OptionId.of(it.toString()) ?: fail("mã lựa chọn sai \"$it\"") }
        val selection = when (d.selection.kind) {
            "all" -> QuestionSelection.All
            "sections" -> QuestionSelection.Sections((d.selection.ids ?: fail("thiếu ids")).map(::uuid).toSet())
            "random" -> QuestionSelection.Random(d.selection.count ?: fail("thiếu count"))
            "questions" -> QuestionSelection.Questions((d.selection.ids ?: fail("thiếu ids")).map(::uuid))
            else -> fail("kind lạ")
        }
        return SessionSnapshot(
            examId = uuid(d.examId),
            paper = ExamPaper(
                uuid(d.examId),
                CompositionOptions(selection, d.shuffleQuestions, d.shuffleOptions,
                    vn.io.nt0.examsuite.core.attempt.StrictPayloadJson.parseSeed(d.seed) ?: fail("seed sai")),
                d.items.map { PaperItem(uuid(it.questionId), uuid(it.sectionId), letters(it.optionOrder)) },
            ),
            mode = SessionMode.entries.firstOrNull { it.raw == d.mode } ?: fail("mode lạ"),
            timeLimitMinutes = d.timeLimitMinutes,
            candidateName = d.candidateName,
            startedAt = Instant.ofEpochMilli(d.startedAtEpochMillis),
            phase = phase(d.phase),
            currentIndex = d.currentIndex,
            answers = d.answers.entries.associate { (id, l) -> uuid(id) to letters(l).toSet() },
            flagged = d.flagged.map(::uuid).toSet(),
            checkedQuestionIds = d.checked.map(::uuid).toSet(),
            pauseReason = d.pauseReason?.let { name -> PauseReason.entries.firstOrNull { it.name == name } ?: fail("lý do tạm dừng lạ") },
            elapsedSeconds = d.elapsedSeconds,
            phaseBeforePause = d.phaseBeforePause?.let(::phase),
            issuedWarnings = d.issuedWarnings.toSet(),
            fingerprints = d.fingerprints.entries.associate { (id, fp) -> uuid(id) to fp },
            pendingEvents = d.pendingEvents.map {
                when {
                    it == "timeUp" -> SessionEvent.TimeUp
                    it.startsWith("warning:") -> SessionEvent.Warning(it.removePrefix("warning:").toIntOrNull() ?: fail("sự kiện lạ"))
                    else -> fail("sự kiện lạ")
                }
            },
        )
    }

    private fun fail(reason: String): Nothing = throw DecodeException(reason)

    private fun phaseName(p: SessionPhase) = when (p) {
        SessionPhase.InProgress -> "inProgress"
        SessionPhase.Paused -> "paused"
        SessionPhase.TimeUp -> "timeUp"
        is SessionPhase.Reviewing -> if (p.locked) "reviewingLocked" else "reviewing"
        SessionPhase.Submitted -> "submitted"
    }

    private fun phase(name: String) = when (name) {
        "inProgress" -> SessionPhase.InProgress
        "paused" -> SessionPhase.Paused
        "timeUp" -> SessionPhase.TimeUp
        "reviewing" -> SessionPhase.Reviewing(false)
        "reviewingLocked" -> SessionPhase.Reviewing(true)
        "submitted" -> SessionPhase.Submitted
        else -> fail("phase lạ \"$name\"")
    }
}

@Serializable
internal data class DraftDto(
    val draftVersion: Int,
    val examId: String,
    val mode: String,
    val timeLimitMinutes: Int? = null,
    val candidateName: String,
    val startedAtEpochMillis: Long,
    val selection: DraftSelection,
    val shuffleQuestions: Boolean,
    val shuffleOptions: Boolean,
    val seed: String,
    val items: List<DraftItem>,
    val phase: String,
    val phaseBeforePause: String? = null,
    val pauseReason: String? = null,
    val currentIndex: Int,
    val answers: Map<String, String>,
    val flagged: List<String>,
    val checked: List<String>,
    val elapsedSeconds: Double,
    val issuedWarnings: List<Int>,
    val pendingEvents: List<String>,
    val fingerprints: Map<String, String>,
)

@Serializable
internal data class DraftSelection(val kind: String, val ids: List<String>? = null, val count: Int? = null)

@Serializable
internal data class DraftItem(val questionId: String, val sectionId: String, val optionOrder: String)
