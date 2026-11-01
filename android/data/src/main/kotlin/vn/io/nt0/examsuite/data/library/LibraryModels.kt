package vn.io.nt0.examsuite.data.library

import vn.io.nt0.examsuite.core.attempt.AttemptPayload
import vn.io.nt0.examsuite.core.file.ExamFileError
import vn.io.nt0.examsuite.core.file.ExamPackage
import vn.io.nt0.examsuite.core.session.SessionMode
import vn.io.nt0.examsuite.core.session.SessionSnapshot
import java.io.File
import java.util.UUID

/** Lần thi gần nhất của một đề, cho thẻ đề (library.md). */
data class LastAttempt(val percent: Int, val score1000: Int, val passed: Boolean, val submittedAtMillis: Long)

/** Một đề trong Thư viện, như giao diện hiện. */
data class LibraryItem(
    val examId: UUID,
    val title: String,
    val code: String?,
    val questionCount: Int,
    val sectionCount: Int,
    val mediaCount: Int,
    val timeLimitMinutes: Int,
    val passPercent: Int,
    val hideAnswers: Boolean,
    val formatVersion: Int,
    val fileSize: Long,
    val addedAtMillis: Long,
    val updatedAtMillis: Long,
    val isSample: Boolean,
    val lastAttempt: LastAttempt?,
)

/** Tóm tắt một lần thi (library.md, Lịch sử thi). */
data class AttemptSummary(
    val attemptId: UUID,
    val examId: UUID,
    val examTitle: String,
    val examCode: String?,
    val candidateName: String,
    val mode: SessionMode,
    val startedAtMillis: Long,
    val submittedAtMillis: Long,
    val elapsedSeconds: Double,
    val timeLimitMinutes: Int?,
    val total: Int,
    val correct: Int,
    val score1000: Int,
    val percent: Int,
    val passPercent: Int,
    val passed: Boolean,
)

/**
 * Chi tiết lần thi: tóm tắt luôn có; payload không đọc được (hỏng, mới hơn app) thì `payload` null và `unreadableReason`
 * có lý do kỹ thuật; giao diện hiện "Không đọc được chi tiết lần thi này" (exam-taking.md, Dữ liệu một lần thi).
 */
data class AttemptDetail(val summary: AttemptSummary, val payload: AttemptPayload?, val unreadableReason: String?)

/** Phiên dở đã lưu. `snapshot` null khi không đọc được (phiên bản khác, hỏng): app bỏ phiên dở. */
data class DraftRecord(val examId: UUID, val snapshot: SessionSnapshot?, val savedAtMillis: Long)

/** Đề đã đọc nghiêm, chờ người dùng chọn Cập nhật đề hay Huỷ (mobile.md: file cùng id đề luôn hỏi). */
class PendingImport internal constructor(internal val file: File, val package_: ExamPackage, internal val sha256: String) {
    val examId: UUID get() = package_.exam.id
}

/** Kết quả nhập một file đề. */
sealed interface ImportResult {
    data class Added(val item: LibraryItem) : ImportResult

    /** Đã có đề cùng id: hỏi **Cập nhật đề** (`confirmUpdate`) hay **Huỷ** (`discard`). */
    class NeedsUpdateConfirmation(val existing: LibraryItem, val pending: PendingImport) : ImportResult

    /** Không thêm (library.md phương án 2): lý do có mã của lõi, hoặc file quá lớn hay lỗi đọc/ghi. */
    data class Rejected(val problem: ImportProblem) : ImportResult
}

sealed interface ImportProblem {
    /** Gói `.exam` hay file `.oef` không đọc nghiêm được; giao diện dựng câu từ mã của `ExamFileError`. */
    data class InvalidPackage(val error: ExamFileError) : ImportProblem

    /** Không phải file đề: không phải zip, không phải `.oef` (nhận theo nội dung, `ExamSourceKind`). */
    data object NotAnExamFile : ImportProblem

    /** File lớn hơn trần chép (`ExamLibrary.MAX_FILE_BYTES`). */
    data class FileTooLarge(val limitBytes: Long) : ImportProblem

    /** Lỗi đọc nguồn hay ghi bộ nhớ của app (hết chỗ…); `detail` kỹ thuật, chỉ cho nhật ký. */
    data class Io(val detail: String) : ImportProblem
}

/** Kết quả dọn dẹp lúc mở app (`ExamLibrary.recoverOnStart`), chỉ để ghi nhật ký và test. */
data class RecoveryReport(
    val purgedRemoved: Int,
    /** File đề chưa có mục, đọc nghiêm được, đã nạp lại thành mục. */
    val orphanFilesRestored: Int,
    /** File đề chưa có mục, không đọc được, đã xoá. */
    val orphanFilesDeleted: Int,
    /** Mục có dấu Cập nhật đề dở, đã làm mới từ file. */
    val entriesRefreshed: Int,
    val entriesWithoutFileDropped: Int,
    val incomingDeleted: Int,
)
