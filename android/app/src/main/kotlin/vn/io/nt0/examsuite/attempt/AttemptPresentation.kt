package vn.io.nt0.examsuite.attempt

import vn.io.nt0.examsuite.core.model.OptionId
import vn.io.nt0.examsuite.core.model.QuestionType
import vn.io.nt0.examsuite.core.scoring.QuestionOutcome
import vn.io.nt0.examsuite.core.scoring.Scorer
import vn.io.nt0.examsuite.core.scoring.SectionScore
import vn.io.nt0.examsuite.core.session.ExamSession
import vn.io.nt0.examsuite.core.session.PauseReason
import vn.io.nt0.examsuite.core.session.SessionMode
import vn.io.nt0.examsuite.core.session.SessionPhase
import vn.io.nt0.examsuite.data.library.AttemptSummary
import java.text.Normalizer
import java.time.Instant
import java.util.Locale
import java.util.UUID
import kotlin.math.ceil
import kotlin.math.floor

// Trạng thái màn làm bài dựng từ `ExamSession` (docs/product/exam-taking.md, mobile.md). Chỉ dữ liệu, không chữ giao
// diện: composable tra chuỗi trong strings.xml. Luật của phiên (chuyển trạng thái, đồng hồ, chấm điểm) ở `:core`.

/** Mức của đồng hồ Thi; mỗi mức có biểu tượng riêng kèm màu (không chỉ dựa vào màu). */
enum class ClockLevel {
    /** Còn hơn 5 phút (và mọi lúc ở Luyện tập). */
    NORMAL,

    /** Sắp hết: còn ≤ 5 phút. */
    WARNING,

    /** Gấp: còn ≤ 1 phút. */
    URGENT,
}

/** Đồng hồ trên thanh trên. Thi: đếm ngược thời gian còn lại; Luyện tập: thời gian đã làm. */
data class ClockDisplay(val seconds: Long, val text: String, val level: ClockLevel, val isCountdown: Boolean)

/** Dải thông báo không chặn trên đầu câu. `id` tăng dần để giao diện tự ẩn đúng dải (cảnh báo giờ). */
data class SessionBanner(val id: Int, val kind: Kind) {
    sealed interface Kind {
        /** Còn 5 / 1 phút; tự ẩn sau vài giây. */
        data class TimeWarning(val minutesLeft: Int) : Kind

        /** Đã hết giờ; ở lại trên Rà soát khoá. */
        data object TimeUp : Kind
    }

    val autoDismisses: Boolean get() = kind is Kind.TimeWarning
}

/** Dấu của lựa chọn sau Kiểm tra đáp án: **Đúng** (lựa chọn đúng) hoặc **Sai** (đã chọn nhưng sai). */
enum class OptionMark { CORRECT, INCORRECT }

/** Một lựa chọn như hiện khi làm bài: nhãn A, B… theo **vị trí hiển thị**, không theo mã gốc. */
data class OptionView(val position: Int, val label: String, val optionId: OptionId, val text: String, val isSelected: Boolean, val mark: OptionMark?)

/** Kết quả Kiểm tra đáp án của câu đang xem (chỉ Luyện tập). */
data class AnswerCheckView(val isCorrect: Boolean, val explanation: String?)

data class QuestionView(
    val index: Int,
    val number: Int,
    val total: Int,
    val sectionTitle: String,
    val text: String,
    val imagePath: String?,
    val type: QuestionType,
    /** Số đáp án đúng, cho gợi ý "Chọn N đáp án" của câu nhiều đáp án. */
    val correctCount: Int,
    val options: List<OptionView>,
    val isFlagged: Boolean,
    /** Đáp án đã khoá sau Kiểm tra đáp án. */
    val isLocked: Boolean,
    val check: AnswerCheckView?,
)

/** Một ô của bảng câu hỏi; có thể vừa Đã làm vừa Đánh dấu vừa Đang xem. */
data class NavigatorCell(val index: Int, val number: Int, val isAnswered: Boolean, val isFlagged: Boolean, val isCurrent: Boolean) {
    /** Phần của câu đọc trình đọc màn hình, theo thứ tự: "Câu 3, Đã làm, Đánh dấu, Đang xem". */
    val spokenParts: List<CellPart>
        get() = buildList {
            add(CellPart.NUMBER)
            add(if (isAnswered) CellPart.ANSWERED else CellPart.UNANSWERED)
            if (isFlagged) add(CellPart.FLAGGED)
            if (isCurrent) add(CellPart.CURRENT)
        }
}

enum class CellPart { NUMBER, ANSWERED, UNANSWERED, FLAGGED, CURRENT }

/** Một nhóm của bảng câu hỏi (một phần của đề). */
data class NavigatorSection(val id: UUID, val title: String, val cells: List<NavigatorCell>)

/** Bảng **Rà soát & nộp**. */
data class ReviewSummary(
    val answeredCount: Int,
    val unansweredCount: Int,
    val flaggedCount: Int,
    val unansweredIndices: List<Int>,
    val flaggedIndices: List<Int>,
    /** Rà soát khoá (hết giờ): không quay lại làm bài. */
    val isLocked: Boolean,
) {
    val canReturnToAttempt: Boolean get() = !isLocked

    /** Nộp khi còn câu chưa làm thì hỏi "Còn N câu chưa làm. Vẫn nộp?"; không còn thì nộp luôn. */
    val needsSubmitConfirmation: Boolean get() = unansweredCount > 0
}

data class SectionRow(val id: UUID, val title: String, val correct: Int, val total: Int, val percent: Int, val isWeakest: Boolean)

enum class SaveState { SAVING, SAVED, FAILED }

/** Màn Kết quả (exam-taking.md, Kết quả). */
data class ResultsView(
    val passed: Boolean,
    val percent: Int,
    val score1000: Int,
    val passPercent: Int,
    val correct: Int,
    val total: Int,
    val candidateName: String,
    val examCode: String?,
    val mode: SessionMode,
    val submittedAt: Instant,
    val elapsedSeconds: Long,
    val timeLimitMinutes: Int?,
    /** Chênh lệch % so với lần trước cùng đề, cùng chế độ; null khi không có lần trước (không hiện dòng này). */
    val previousDelta: Int?,
    val sections: List<SectionRow>,
    val saveState: SaveState,
    /** Số câu Sai (đã trả lời nhưng sai), cho nút **Xem câu sai**. */
    val incorrectCount: Int,
)

/** Phần của câu đọc khi đổi câu: "Câu 3 trên 60, Phần Mạng". */
data class QuestionAnnouncement(val number: Int, val total: Int, val sectionTitle: String, val needsSectionPrefix: Boolean)

object AttemptPresentation {
    const val WARNING_SECONDS = 5 * 60.0
    const val URGENT_SECONDS = 60.0

    /** Nhãn lựa chọn theo vị trí hiển thị: 0 → "A", 1 → "B"… */
    fun optionLabel(position: Int): String = OptionId.at(position)?.toString() ?: (position + 1).toString()

    /** Đồng hồ: `mm:ss`, từ 60 phút trở lên `h:mm:ss`. */
    fun clockText(seconds: Long): String {
        val total = maxOf(0L, seconds)
        val hours = total / 3600
        val minutes = total % 3600 / 60
        val rest = total % 60
        fun two(v: Long) = if (v < 10) "0$v" else "$v"
        return if (hours > 0) "$hours:${two(minutes)}:${two(rest)}" else "${two(minutes)}:${two(rest)}"
    }

    /**
     * Thi đếm ngược thời gian còn lại, làm tròn lên giây để chạm 00:00 đúng lúc hết giờ; Luyện tập hiện thời gian đã làm
     * (làm tròn xuống), như bản macOS.
     */
    fun clock(session: ExamSession): ClockDisplay {
        val remaining = session.remaining
        if (remaining != null) {
            val seconds = ceil(remaining).toLong()
            val level = when {
                remaining <= URGENT_SECONDS -> ClockLevel.URGENT
                remaining <= WARNING_SECONDS -> ClockLevel.WARNING
                else -> ClockLevel.NORMAL
            }
            return ClockDisplay(seconds, clockText(seconds), level, isCountdown = true)
        }
        val seconds = floor(session.elapsed).toLong()
        return ClockDisplay(seconds, clockText(seconds), ClockLevel.NORMAL, isCountdown = false)
    }

    fun question(session: ExamSession): QuestionView {
        val item = session.currentItem
        val q = session.currentQuestion
        val selected = session.answers[q.id] ?: emptySet()
        val checked = q.id in session.checkedQuestionIds
        val texts = q.options.associate { it.id to it.text }
        val options = item.optionOrder.mapIndexed { position, id ->
            val mark = when {
                !checked -> null
                id in q.correctSet -> OptionMark.CORRECT
                id in selected -> OptionMark.INCORRECT
                else -> null
            }
            OptionView(position, optionLabel(position), id, texts[id] ?: "", id in selected, mark)
        }
        val check = if (checked) AnswerCheckView(Scorer.outcome(q, selected) == QuestionOutcome.CORRECT, q.explanation) else null
        return QuestionView(
            index = session.currentIndex,
            number = session.currentIndex + 1,
            total = session.questionCount,
            sectionTitle = sectionTitle(session, item.sectionId),
            text = q.text,
            imagePath = q.image,
            type = q.type,
            correctCount = q.correctSet.size,
            options = options,
            isFlagged = q.id in session.flagged,
            isLocked = checked,
            check = check,
        )
    }

    /** Kiểm tra đáp án bật khi Luyện tập, đang làm, câu hiện tại có đáp án và chưa kiểm tra. */
    fun canCheckAnswer(session: ExamSession): Boolean {
        val id = session.currentItem.questionId
        return session.mode == SessionMode.PRACTICE && session.phase == SessionPhase.InProgress &&
            session.isAnswered(id) && id !in session.checkedQuestionIds
    }

    /** Ô của bảng câu hỏi nhóm theo phần (thứ tự phần trong đề), số thứ tự theo phiên. */
    fun navigator(session: ExamSession): List<NavigatorSection> {
        val bySection = LinkedHashMap<UUID, MutableList<NavigatorCell>>()
        session.paper.items.forEachIndexed { index, item ->
            bySection.getOrPut(item.sectionId) { mutableListOf() } += NavigatorCell(
                index = index,
                number = index + 1,
                isAnswered = session.isAnswered(item.questionId),
                isFlagged = item.questionId in session.flagged,
                isCurrent = index == session.currentIndex,
            )
        }
        return session.exam.sections.mapNotNull { section -> bySection[section.id]?.let { NavigatorSection(section.id, section.title, it) } }
    }

    fun reviewSummary(session: ExamSession): ReviewSummary {
        val items = session.paper.items
        val unanswered = items.indices.filter { !session.isAnswered(items[it].questionId) }
        val flagged = items.indices.filter { items[it].questionId in session.flagged }
        return ReviewSummary(
            answeredCount = items.size - unanswered.size,
            unansweredCount = unanswered.size,
            flaggedCount = flagged.size,
            unansweredIndices = unanswered,
            flaggedIndices = flagged,
            isLocked = session.phase == SessionPhase.Reviewing(true) || session.phase == SessionPhase.TimeUp,
        )
    }

    fun answeredCount(session: ExamSession): Int = session.questionCount - session.unansweredCount

    fun announcement(session: ExamSession): QuestionAnnouncement {
        val title = sectionTitle(session, session.currentItem.sectionId)
        return QuestionAnnouncement(session.currentIndex + 1, session.questionCount, title, !hasNumberedSectionPrefix(title))
    }

    /**
     * Tên phần bắt đầu bằng "Phần " hoặc "Section " (không phân biệt hoa thường) rồi tới chữ số: hai dạng tên mặc định app
     * ghi vào đề, bất kể giao diện đang dùng ngôn ngữ nào; khi đó đọc nguyên tên, không thêm "Phần" (exam-taking.md).
     */
    fun hasNumberedSectionPrefix(title: String): Boolean {
        val normalized = Normalizer.normalize(title, Normalizer.Form.NFC)
        val lowered = normalized.lowercase(Locale.ROOT)
        val prefix = NUMBERED_PREFIXES.firstOrNull { lowered.startsWith(it) } ?: return false
        return normalized.getOrNull(prefix.length)?.isDigit() == true
    }

    private val NUMBERED_PREFIXES = listOf("phần ", "section ")

    /**
     * Phần yếu nhất: % hiển thị thấp nhất trong các phần có câu, bằng nhau thì phần đứng trước; chỉ khi có từ hai phần có câu
     * trở lên (exam-taking.md, Kết quả).
     */
    fun weakestSectionId(sections: List<SectionScore>): UUID? {
        val scored = sections.filter { it.total > 0 }
        if (scored.size < 2) return null
        return scored.minWith(compareBy { Scorer.percent(it.correct, it.total) }).sectionId
    }

    /**
     * Lần trước để so (exam-taking.md phương án 8): cùng đề, **cùng chế độ**, nộp trước `beforeMillis` (null: mọi lần đã
     * lưu, dùng khi chưa lưu lần vừa nộp), mới nhất trước.
     */
    fun previousAttempt(attempts: List<AttemptSummary>, examId: UUID, mode: SessionMode, beforeMillis: Long? = null): AttemptSummary? =
        attempts.filter { it.examId == examId && it.mode == mode && (beforeMillis == null || it.submittedAtMillis < beforeMillis) }
            .maxByOrNull { it.submittedAtMillis }

    fun results(session: ExamSession, previousPercent: Int?, saveState: SaveState): ResultsView {
        val result = checkNotNull(session.result) { "phiên chưa nộp" }
        val weakest = weakestSectionId(result.sections)
        return ResultsView(
            passed = result.passed,
            percent = result.percent,
            score1000 = result.score1000,
            passPercent = result.passPercent,
            correct = result.correct,
            total = result.total,
            candidateName = session.candidateName,
            examCode = session.exam.code,
            mode = session.mode,
            submittedAt = checkNotNull(session.submittedAt),
            elapsedSeconds = Math.round(session.elapsed),
            timeLimitMinutes = session.timeLimitMinutes,
            previousDelta = previousPercent?.let { result.percent - it },
            sections = result.sections.map { s ->
                SectionRow(s.sectionId, s.title, s.correct, s.total, Scorer.percent(s.correct, s.total), s.sectionId == weakest)
            },
            saveState = saveState,
            incorrectCount = result.outcomes.values.count { it == QuestionOutcome.INCORRECT },
        )
    }

    /** Lý do tạm dừng như hiện trên lớp phủ; null khi không tạm dừng. */
    fun pauseReason(session: ExamSession): PauseReason? = if (session.phase == SessionPhase.Paused) session.pauseReason ?: PauseReason.USER else null

    private fun sectionTitle(session: ExamSession, sectionId: UUID): String =
        session.exam.sections.firstOrNull { it.id == sectionId }?.title ?: ""
}
