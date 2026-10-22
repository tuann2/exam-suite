package vn.io.nt0.examsuite.attempt

import android.os.SystemClock
import vn.io.nt0.examsuite.core.session.ExamSession
import vn.io.nt0.examsuite.core.session.SessionClock
import vn.io.nt0.examsuite.core.session.SessionMode
import vn.io.nt0.examsuite.core.session.SessionSnapshot
import vn.io.nt0.examsuite.data.library.ExamLibrary
import java.time.Instant
import java.util.UUID

/** Nơi lưu của màn làm bài: phiên dở (mobile.md) và lần thi khi nộp (exam-taking.md, Kết quả). */
interface AttemptStore {
    /** Ghi đè phiên dở (mỗi lúc một phiên), đã chụp lúc xuống nền. */
    suspend fun saveDraft(snapshot: SessionSnapshot)

    suspend fun clearDraft()

    /** % của lần trước cùng đề, cùng chế độ (exam-taking.md phương án 8); gọi trước khi lưu lần này. */
    suspend fun previousPercent(examId: UUID, mode: SessionMode): Int?

    /** Lưu lần thi đã nộp; xoá phiên dở của đề đó. */
    suspend fun saveAttempt(session: ExamSession)
}

/** `AttemptStore` trên Thư viện thật (`:data`). */
class LibraryAttemptStore(private val library: ExamLibrary) : AttemptStore {
    override suspend fun saveDraft(snapshot: SessionSnapshot) = library.saveDraft(snapshot)

    override suspend fun clearDraft() = library.clearDraft()

    override suspend fun previousPercent(examId: UUID, mode: SessionMode): Int? =
        AttemptPresentation.previousAttempt(library.attemptsFor(examId), examId, mode)?.percent

    override suspend fun saveAttempt(session: ExamSession) {
        library.saveAttempt(session)
    }
}

/** Đồng hồ của phiên trên Android: `uptimeMillis` không chạy khi máy ngủ sâu (exam-session.md, Đồng hồ). */
object AndroidSessionClock : SessionClock {
    override fun now(): Instant = Instant.now()

    override fun uptimeSeconds(): Double = SystemClock.uptimeMillis() / 1000.0
}
