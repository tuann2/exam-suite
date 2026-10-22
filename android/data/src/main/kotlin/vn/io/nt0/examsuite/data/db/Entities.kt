package vn.io.nt0.examsuite.data.db

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

/**
 * Một đề trong Thư viện (docs/product/library.md; mobile.md: file đề **sao chép** vào `files/exams/<examId>.exam`). Thông
 * tin thẻ lưu lại để Thư viện hiện ngay khi mở app. Không có trạng thái mất file: đề chỉ được thêm khi đọc nghiêm được.
 */
@Entity(tableName = "exam_entry")
data class ExamEntryEntity(
    /** UUID chữ thường của đề; mỗi id đề một mục. */
    @PrimaryKey val examId: String,
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
    /** SHA-256 hex của file đề đã chép. */
    val fileSha256: String,
    val addedAtMillis: Long,
    val updatedAtMillis: Long,
    /** Tên thư mục đề mẫu nếu đề do app tạo lần đầu mở; null với đề của người dùng. */
    val sampleKey: String?,
    /** Đã xoá khỏi Thư viện, đang chờ Hoàn tác; null nếu đang có trong Thư viện. */
    val removedAtMillis: Long?,
)

/**
 * Một lần thi đã nộp (library.md, Lịch sử thi): tóm tắt để hiện ngay, cộng payload chi tiết (`AttemptPayload` của
 * `:core`, định dạng riêng của Android, Q11). Lịch sử gắn với id đề và còn lại khi đề bị xoá khỏi Thư viện.
 */
@Entity(tableName = "attempt", indices = [Index("examId"), Index("submittedAtMillis")])
data class AttemptEntity(
    @PrimaryKey val attemptId: String,
    val examId: String,
    /** Tên đề lúc thi. */
    val examTitle: String,
    val examCode: String?,
    val candidateName: String,
    /** "practice" | "exam". */
    val mode: String,
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
    val payloadVersion: Int,
    val payload: String,
)

/** Phiên dở (mobile.md, Q7): mỗi lúc một phiên, một dòng duy nhất (`slot` 0). `snapshot` là JSON của `SnapshotCodec`. */
@Entity(tableName = "draft_session")
data class DraftEntity(
    @PrimaryKey val slot: Int = 0,
    val examId: String,
    val snapshot: String,
    val savedAtMillis: Long,
)
