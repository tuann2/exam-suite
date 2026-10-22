package vn.io.nt0.examsuite.data.library

import androidx.room.withTransaction
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import vn.io.nt0.examsuite.core.attempt.AttemptPayload
import vn.io.nt0.examsuite.core.attempt.AttemptPayloadException
import vn.io.nt0.examsuite.core.file.ExamFileError
import vn.io.nt0.examsuite.core.file.ExamPackage
import vn.io.nt0.examsuite.core.file.ExamPackageLimits
import vn.io.nt0.examsuite.core.file.ExamPackageReader
import vn.io.nt0.examsuite.core.file.QuestionFingerprint
import vn.io.nt0.examsuite.core.model.StrictUuid
import vn.io.nt0.examsuite.core.session.ExamSession
import vn.io.nt0.examsuite.core.session.SessionMode
import vn.io.nt0.examsuite.core.session.SessionPhase
import vn.io.nt0.examsuite.core.session.SnapshotCodec
import vn.io.nt0.examsuite.data.db.AttemptEntity
import vn.io.nt0.examsuite.data.db.DraftEntity
import vn.io.nt0.examsuite.data.db.ExamEntryEntity
import vn.io.nt0.examsuite.data.db.LibraryDatabase
import java.io.File
import java.io.IOException
import java.io.InputStream
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import java.security.MessageDigest
import java.util.UUID
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

/**
 * Thư viện của bản Android: đề, lịch sử thi, phiên dở (docs/product/library.md, mobile.md). File đề **sao chép** vào
 * `<root>/exams/<examId>.exam` (bộ nhớ riêng của app, không sao lưu đám mây, không chuyển máy). Mọi thao tác file chạy
 * trên `Dispatchers.IO`.
 *
 * Nhập đề nguyên tử: chép nguồn vào `exams/.incoming/<ngẫu nhiên>.part` (có trần), đọc **nghiêm** bằng `:core`, rồi đổi
 * tên thành file đích; ghi kho sau khi đổi tên. Cập nhật đề ghi file đánh dấu `<examId>.updating` trước khi đổi tên, xoá
 * sau khi ghi kho. Tắt giữa chừng thì `recoverOnStart` dọn file tạm, nạp lại file đề chưa có mục và làm mới mục có dấu.
 * Mọi thao tác ghi chạy tuần tự dưới một khoá (nhập đồng thời không ghi đè nhau mà không hỏi).
 */
class ExamLibrary(
    private val db: LibraryDatabase,
    root: File,
    private val now: () -> Long = System::currentTimeMillis,
    private val limits: ExamPackageLimits = ExamPackageLimits.DEFAULT,
    /** Trần chép file đề (mặc định `MAX_FILE_BYTES`); test truyền nhỏ hơn. */
    private val maxFileBytes: Long = MAX_FILE_BYTES,
) {
    val examsDir = File(root, "exams")
    private val incomingDir = File(examsDir, ".incoming")

    private val mutex = Mutex()

    fun examFile(examId: UUID) = File(examsDir, "$examId.exam")

    private fun updatingMarker(examId: String) = File(examsDir, "$examId.updating")

    // ---------- Đề ----------

    /** Các đề đang có trong Thư viện (không gồm đề đang chờ Hoàn tác), kèm lần thi gần nhất. */
    fun items(): Flow<List<LibraryItem>> = combine(db.entries().observeActive(), db.attempts().observeAll()) { entries, attempts ->
        val latest = attempts.groupBy { it.examId }.mapValues { (_, list) -> list.maxBy { it.submittedAtMillis } }
        entries.map { it.toItem(latest[it.examId]) }
    }

    suspend fun item(examId: UUID): LibraryItem? = db.entries().get(examId.toString())
        ?.takeIf { it.removedAtMillis == null }
        ?.toItem(db.attempts().forExam(examId.toString()).firstOrNull())

    /** Mở đề để làm bài: đọc nghiêm lại file đã chép (ảnh không nạp vào bộ nhớ, đọc bằng `media`). */
    suspend fun open(examId: UUID): ExamPackage = withContext(Dispatchers.IO) { ExamPackageReader.readStrict(examFile(examId), limits) }

    suspend fun media(examId: UUID, path: String): ByteArray = withContext(Dispatchers.IO) { ExamPackageReader.readMedia(examFile(examId), path, limits) }

    /**
     * Nhập một file đề (nút Thêm đề hay mở `.exam` từ app khác). Đọc nghiêm; không đọc được thì không thêm, trả lý do
     * (library.md phương án 2). Đã có đề cùng id thì trả `NeedsUpdateConfirmation`; file đã đọc được giữ chờ trả lời.
     */
    suspend fun import(source: InputStream): ImportResult = mutex.withLock { withContext(Dispatchers.IO) { importLocked(source) } }

    private suspend fun importLocked(source: InputStream): ImportResult {
        incomingDir.mkdirs()
        val part = File(incomingDir, "${UUID.randomUUID()}.part")
        val copied = try {
            copyCapped(source, part)
        } catch (e: IOException) {
            part.delete()
            return ImportResult.Rejected(ImportProblem.Io(e.message ?: e.javaClass.simpleName))
        }
        if (!copied) {
            part.delete()
            return ImportResult.Rejected(ImportProblem.FileTooLarge(maxFileBytes))
        }
        val package_ = try {
            ExamPackageReader.readStrict(part, limits)
        } catch (e: ExamFileError) {
            part.delete()
            return ImportResult.Rejected(ImportProblem.InvalidPackage(e))
        }
        val pending = PendingImport(part, package_, sha256(part))
        val id = package_.exam.id.toString()
        val existing = db.entries().get(id)
        if (existing != null && existing.removedAtMillis != null) purge(existing)
        if (existing != null && existing.removedAtMillis == null) {
            return ImportResult.NeedsUpdateConfirmation(existing.toItem(db.attempts().forExam(id).firstOrNull()), pending)
        }
        return ImportResult.Added(commit(pending, sampleKey = null, previous = null))
    }

    /** **Cập nhật đề**: thay file và thông tin thẻ, giữ ngày thêm và lịch sử thi. */
    suspend fun confirmUpdate(pending: PendingImport): LibraryItem = mutex.withLock { withContext(Dispatchers.IO) {
        check(pending.file.exists()) { "file chờ đã bị dọn" }
        val previous = db.entries().get(pending.examId.toString())?.takeIf { it.removedAtMillis == null }
        commit(pending, sampleKey = null, previous = previous)
    } }

    /** **Huỷ**: bỏ file đã đọc, Thư viện không đổi. */
    suspend fun discard(pending: PendingImport) {
        withContext(Dispatchers.IO) { pending.file.delete() }
    }

    /** Xoá khỏi Thư viện, không hỏi (library.md phương án 3): chờ Hoàn tác; file và mục bị xoá hẳn ở `purgeRemoved`. */
    suspend fun remove(examId: UUID): Boolean = mutex.withLock { db.entries().markRemoved(examId.toString(), now()) == 1 }

    suspend fun undoRemove(examId: UUID): Boolean = mutex.withLock { db.entries().unmarkRemoved(examId.toString()) == 1 }

    /** Xoá hẳn các đề đã xoá khỏi Thư viện (hết thời gian Hoàn tác): file, mục, phiên dở của đề đó; lịch sử thi giữ lại. */
    suspend fun purgeRemoved(): Int = mutex.withLock { withContext(Dispatchers.IO) { purgeRemovedLocked() } }

    private suspend fun purgeRemovedLocked(): Int {
        val removed = db.entries().removed()
        removed.forEach { purge(it) }
        return removed.size
    }

    /**
     * Dọn lúc mở app (A3a gọi trước khi đọc phiên dở và xử lý file mở từ app khác):
     * - file tạm của lần nhập dở;
     * - đề chờ Hoàn tác từ lần trước;
     * - file đề **không có mục** (tắt giữa đổi tên và ghi kho, hoặc kho vừa được thay vì hỏng): đọc nghiêm được thì **nạp lại
     *   thành mục**, không đọc được mới xoá; không bao giờ xoá bản sao đề người dùng còn dùng được (review độc lập PR #3, C2);
     * - mục có dấu Cập nhật đề dở (`<examId>.updating`): đọc lại file và làm mới thông tin thẻ;
     * - mục không còn file (bị can thiệp ngoài app): bỏ mục, lịch sử thi giữ lại.
     */
    suspend fun recoverOnStart(): RecoveryReport = mutex.withLock { withContext(Dispatchers.IO) {
        val incoming = incomingDir.listFiles()?.count { it.delete() } ?: 0
        val purged = purgeRemovedLocked()
        val entries = db.entries().all().associateBy { it.examId }
        var restored = 0
        var deleted = 0
        examsDir.listFiles()?.filter { it.isFile && it.name.endsWith(".exam") }?.forEach { file ->
            val id = file.name.removeSuffix(".exam")
            if (id in entries) return@forEach
            // Chỉ xoá khi lõi báo gói hỏng; lỗi tạm thời (đọc ghi, hết bộ nhớ) thì giữ file cho lần sau.
            val package_ = try {
                ExamPackageReader.readStrict(file, limits)
            } catch (_: ExamFileError) {
                null
            } catch (_: Exception) {
                return@forEach
            }
            if (package_ != null && package_.exam.id.toString() == id) {
                upsertEntry(package_, file, sha256(file), sampleKey = null, previous = null)
                restored++
            } else if (file.delete()) {
                deleted++
            }
        }
        var refreshed = 0
        examsDir.listFiles()?.filter { it.isFile && it.name.endsWith(".updating") }?.forEach { marker ->
            val id = marker.name.removeSuffix(".updating")
            val file = File(examsDir, "$id.exam")
            val previous = db.entries().get(id)
            val package_ = runCatching { ExamPackageReader.readStrict(file, limits) }.getOrNull()
            // Tắt trước khi đổi tên thì file vẫn là bản cũ (cùng SHA-256): không đổi gì. Đã đổi tên thì làm mới mục như
            // Cập nhật đề thường (bỏ cờ đề mẫu, giữ ngày thêm).
            if (previous != null && package_ != null) {
                val sha = sha256(file)
                if (sha != previous.fileSha256) {
                    upsertEntry(package_, file, sha, sampleKey = null, previous = previous)
                    refreshed++
                }
            }
            marker.delete()
        }
        var dropped = 0
        for (entry in db.entries().all()) {
            if (!File(examsDir, "${entry.examId}.exam").exists()) {
                purge(entry)
                dropped++
            }
        }
        RecoveryReport(purged, restored, deleted, refreshed, dropped, incoming)
    } }

    // ---------- Đề mẫu ----------

    /**
     * Thêm đề mẫu (library.md, Đề mẫu và lần đầu mở app): mỗi thư mục của `samples` đóng thành gói `.exam`, đọc nghiêm,
     * thêm với cờ đề mẫu. Đề đã có trong Thư viện (cùng id) thì bỏ qua. Gọi một lần lúc lần đầu mở app (cờ ở
     * `LibrarySettings.samplesSeeded`); xoá đề mẫu thì không tự tạo lại. Trả số đề đã thêm.
     */
    suspend fun seedSamples(samples: SampleSource): Int = mutex.withLock { withContext(Dispatchers.IO) {
        var added = 0
        for (name in samples.names()) {
            incomingDir.mkdirs()
            val part = File(incomingDir, "${UUID.randomUUID()}.part")
            ZipOutputStream(part.outputStream()).use { zip ->
                for ((path, bytes) in samples.files(name)) {
                    zip.putNextEntry(ZipEntry(path))
                    zip.write(bytes)
                    zip.closeEntry()
                }
            }
            // Một đề mẫu lỗi (không xảy ra với đề mẫu đã kiểm trong repo) không làm dừng cả lượt.
            val package_ = try {
                ExamPackageReader.readStrict(part, limits)
            } catch (_: ExamFileError) {
                part.delete()
                continue
            }
            val existing = db.entries().get(package_.exam.id.toString())
            if (existing != null && existing.removedAtMillis == null) {
                part.delete()
                continue
            }
            if (existing != null) purge(existing)
            commit(PendingImport(part, package_, sha256(part)), sampleKey = name, previous = null)
            added++
        }
        added
    } }

    // ---------- Lịch sử thi ----------

    /** Mọi lần thi, mới nhất trước (library.md, Lịch sử thi). */
    fun history(): Flow<List<AttemptSummary>> = db.attempts().observeAll().map { list -> list.mapNotNull { it.toSummary() } }

    suspend fun attemptsFor(examId: UUID): List<AttemptSummary> = db.attempts().forExam(examId.toString()).mapNotNull { it.toSummary() }

    /**
     * Lưu lần thi khi nộp (library.md: tự lưu khi nộp bài Luyện tập hoặc Thi): tóm tắt + payload có dấu vân tay câu lúc
     * thi. Xoá phiên dở của đề đó (phiên đã nộp không còn dở).
     */
    suspend fun saveAttempt(session: ExamSession): AttemptSummary {
        check(session.phase == SessionPhase.Submitted) { "chỉ lưu phiên đã nộp" }
        val payload = AttemptPayload.from(session, QuestionFingerprint.fingerprints(session.exam))
        val result = payload.result
        val entity = AttemptEntity(
            attemptId = UUID.randomUUID().toString(),
            examId = session.exam.id.toString(),
            examTitle = session.exam.title,
            examCode = session.exam.code,
            candidateName = session.candidateName,
            mode = session.mode.raw,
            startedAtMillis = session.startedAt.toEpochMilli(),
            submittedAtMillis = session.submittedAt!!.toEpochMilli(),
            elapsedSeconds = session.elapsed,
            timeLimitMinutes = session.timeLimitMinutes,
            total = result.total,
            correct = result.correct,
            score1000 = result.score1000,
            percent = result.percent,
            passPercent = result.passPercent,
            passed = result.passed,
            payloadVersion = AttemptPayload.CURRENT_VERSION,
            payload = payload.encode(),
        )
        db.withTransaction {
            db.attempts().insert(entity)
            if (db.drafts().get()?.examId == entity.examId) db.drafts().clear()
        }
        return entity.toSummary()!!
    }

    suspend fun attemptDetail(attemptId: UUID): AttemptDetail? {
        val entity = db.attempts().get(attemptId.toString()) ?: return null
        return try {
            AttemptDetail(entity.toSummary() ?: return null, AttemptPayload.decode(entity.payload), null)
        } catch (e: AttemptPayloadException) {
            AttemptDetail(entity.toSummary() ?: return null, null, e.message)
        }
    }

    // ---------- Phiên dở ----------

    /** Lưu phiên dở (app xuống nền, mỗi lần đổi đáp án; mobile.md Q7). Mỗi lúc một phiên: ghi đè phiên cũ. */
    suspend fun saveDraft(session: ExamSession) {
        db.drafts().upsert(DraftEntity(0, session.exam.id.toString(), SnapshotCodec.encode(session.snapshot()), now()))
    }

    suspend fun loadDraft(): DraftRecord? {
        val draft = db.drafts().get() ?: return null
        val snapshot = try {
            SnapshotCodec.decode(draft.snapshot)
        } catch (_: SnapshotCodec.DecodeException) {
            null
        }
        val examId = StrictUuid.parse(draft.examId) ?: return null
        return DraftRecord(examId, snapshot, draft.savedAtMillis)
    }

    suspend fun clearDraft() = db.drafts().clear()

    // ---------- Nội bộ ----------

    private suspend fun commit(pending: PendingImport, sampleKey: String?, previous: ExamEntryEntity?): LibraryItem {
        val exam = pending.package_.exam
        val target = examFile(exam.id)
        examsDir.mkdirs()
        val marker = updatingMarker(exam.id.toString())
        if (previous != null) marker.writeText("")
        Files.move(pending.file.toPath(), target.toPath(), StandardCopyOption.REPLACE_EXISTING, StandardCopyOption.ATOMIC_MOVE)
        val entity = upsertEntry(pending.package_, target, pending.sha256, sampleKey, previous)
        marker.delete()
        return entity.toItem(db.attempts().forExam(entity.examId).firstOrNull())
    }

    private suspend fun upsertEntry(package_: ExamPackage, file: File, sha256: String, sampleKey: String?, previous: ExamEntryEntity?): ExamEntryEntity {
        val exam = package_.exam
        val at = now()
        val entity = ExamEntryEntity(
            examId = exam.id.toString(),
            title = exam.title,
            code = exam.code,
            questionCount = exam.questionCount,
            sectionCount = exam.sections.size,
            mediaCount = package_.mediaPaths.size,
            timeLimitMinutes = exam.timeLimitMinutes.toInt(),
            passPercent = exam.passPercent.toInt(),
            hideAnswers = exam.hideAnswers,
            formatVersion = exam.formatVersion.toInt(),
            fileSize = file.length(),
            fileSha256 = sha256,
            addedAtMillis = previous?.addedAtMillis ?: at,
            updatedAtMillis = at,
            sampleKey = sampleKey,
            removedAtMillis = null,
        )
        db.entries().upsert(entity)
        return entity
    }

    /** Xoá hẳn một đề. Xoá file thất bại thì giữ mục (chờ xoá) để lần sau thử lại, không để `recoverOnStart` nạp lại đề. */
    private suspend fun purge(entry: ExamEntryEntity) {
        val file = File(examsDir, "${entry.examId}.exam")
        if (file.exists() && !file.delete()) {
            if (entry.removedAtMillis == null) db.entries().markRemoved(entry.examId, now())
            return
        }
        db.withTransaction {
            db.entries().delete(entry.examId)
            if (db.drafts().get()?.examId == entry.examId) db.drafts().clear()
        }
    }

    /** Chép có trần; false nếu nguồn dài hơn `maxFileBytes`. */
    private fun copyCapped(source: InputStream, target: File): Boolean {
        var total = 0L
        target.outputStream().use { out ->
            val buffer = ByteArray(64 * 1024)
            while (true) {
                val n = source.read(buffer)
                if (n < 0) break
                total += n
                if (total > maxFileBytes) return false
                out.write(buffer, 0, n)
            }
        }
        return true
    }

    private fun sha256(file: File): String {
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buffer = ByteArray(64 * 1024)
            while (true) {
                val n = input.read(buffer)
                if (n < 0) break
                digest.update(buffer, 0, n)
            }
        }
        return digest.digest().joinToString("") { "%02x".format(it.toInt() and 0xFF) }
    }

    companion object {
        /**
         * Trần kích thước file đề khi chép vào app: tổng giải nén tối đa (1 GiB, exam-format.md) cộng 64 MiB cho phần
         * đầu zip. Gói nén lớn hơn mức này không thể đọc nghiêm được nên dừng chép sớm.
         */
        val MAX_FILE_BYTES: Long = ExamPackageLimits.DEFAULT.totalUncompressedBytes + (64L shl 20)
    }
}

private fun ExamEntryEntity.toItem(last: AttemptEntity?) = LibraryItem(
    examId = UUID.fromString(examId),
    title = title,
    code = code,
    questionCount = questionCount,
    sectionCount = sectionCount,
    mediaCount = mediaCount,
    timeLimitMinutes = timeLimitMinutes,
    passPercent = passPercent,
    hideAnswers = hideAnswers,
    formatVersion = formatVersion,
    fileSize = fileSize,
    addedAtMillis = addedAtMillis,
    updatedAtMillis = updatedAtMillis,
    isSample = sampleKey != null,
    lastAttempt = last?.let { LastAttempt(it.percent, it.score1000, it.passed, it.submittedAtMillis) },
)

/** null nếu dòng có chế độ lạ (không do app ghi): bỏ dòng đó thay vì làm hỏng cả danh sách. */
private fun AttemptEntity.toSummary(): AttemptSummary? = SessionMode.entries.firstOrNull { it.raw == mode }?.let { sessionMode -> AttemptSummary(
    attemptId = UUID.fromString(attemptId),
    examId = UUID.fromString(examId),
    examTitle = examTitle,
    examCode = examCode,
    candidateName = candidateName,
    mode = sessionMode,
    startedAtMillis = startedAtMillis,
    submittedAtMillis = submittedAtMillis,
    elapsedSeconds = elapsedSeconds,
    timeLimitMinutes = timeLimitMinutes,
    total = total,
    correct = correct,
    score1000 = score1000,
    percent = percent,
    passPercent = passPercent,
    passed = passed,
) }
