package vn.io.nt0.examsuite.core.session

import vn.io.nt0.examsuite.core.model.OptionId
import vn.io.nt0.examsuite.core.scoring.QuestionOutcome
import java.time.Instant
import java.util.UUID

/**
 * Nguồn thời gian tiêm từ ngoài (docs/product/exam-session.md, mục Đồng hồ): `now()` chỉ để ghi mốc; `uptimeSeconds()`
 * đơn điệu, không chạy khi máy ngủ sâu, dùng cho mọi phép đo. Android: `SystemClock.uptimeMillis()`.
 */
interface SessionClock {
    fun now(): Instant

    fun uptimeSeconds(): Double
}

enum class SessionMode(val raw: String) { PRACTICE("practice"), EXAM("exam") }

sealed interface SessionPhase {
    data object InProgress : SessionPhase

    data object Paused : SessionPhase

    data object TimeUp : SessionPhase

    data class Reviewing(val locked: Boolean) : SessionPhase

    data object Submitted : SessionPhase
}

enum class PauseReason {
    /** Người dùng bấm Tạm dừng. */
    USER,

    /** Máy sắp ngủ (bản macOS). */
    SYSTEM_SLEEP,

    /** App xuống nền (cuộc gọi, khoá màn hình, chuyển app) hoặc phiên dở được khôi phục (mobile.md, Q7). */
    BACKGROUND,
}

sealed interface SessionEvent {
    data class Warning(val minutesLeft: Int) : SessionEvent

    data object TimeUp : SessionEvent
}

enum class SessionCommand {
    SELECT, CLEAR_ANSWER, TOGGLE_FLAG, GO_TO, NEXT, PREVIOUS, PAUSE, RESUME, OPEN_REVIEW, RETURN_TO_ATTEMPT, SUBMIT, CHECK_ANSWER
}

data class AnswerCheck(
    val questionId: UUID,
    /** Không bao giờ UNANSWERED: không kiểm được câu chưa trả lời. */
    val outcome: QuestionOutcome,
    val correctOptions: Set<OptionId>,
    val explanation: String?,
)

/** Lỗi của phiên; lệnh bị từ chối không đổi phiên, trừ phần ghi nhận đồng hồ (cảnh báo, hết giờ). */
sealed class SessionException(message: String) : Exception(message) {
    data object PracticeNotAllowed : SessionException("đề hideAnswers khoá Luyện tập")

    data class PaperExamMismatch(val paperExamId: UUID, val examId: UUID) : SessionException("đề đã tạo không thuộc đề này")

    data object EmptyPaper : SessionException("đề đã tạo không có câu")

    data class UnknownQuestion(val id: UUID) : SessionException("câu $id không thuộc đề")

    data class DuplicateQuestion(val id: UUID) : SessionException("câu $id lặp")

    data class InvalidTimeLimit(val minutes: Int) : SessionException("thời hạn $minutes phút ngoài 1–600")

    data class InvalidCommand(val command: SessionCommand, val phase: SessionPhase) : SessionException("$command không hợp lệ ở $phase")

    data class UnavailableInMode(val command: SessionCommand, val mode: SessionMode) : SessionException("$command không có ở $mode")

    data class IndexOutOfRange(val index: Int, val count: Int) : SessionException("vị trí $index ngoài 0..<$count")

    data class UnknownOption(val option: OptionId) : SessionException("lựa chọn $option không thuộc câu")

    data class AnswerLocked(val questionId: UUID) : SessionException("đáp án câu $questionId đã khoá")

    data class NoAnswerToCheck(val questionId: UUID) : SessionException("câu $questionId chưa có đáp án")

    /** Phiên dở không khôi phục được (đề đổi, dữ liệu mâu thuẫn); lý do kỹ thuật cho nhật ký. */
    data class InvalidSnapshot(val reason: String) : SessionException("phiên dở không dùng được: $reason")
}
