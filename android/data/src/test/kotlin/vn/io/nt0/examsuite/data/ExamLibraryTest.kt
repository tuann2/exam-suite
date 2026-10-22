package vn.io.nt0.examsuite.data

import androidx.test.ext.junit.runners.AndroidJUnit4
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import vn.io.nt0.examsuite.core.composer.CompositionOptions
import vn.io.nt0.examsuite.core.composer.ExamComposer
import vn.io.nt0.examsuite.core.file.ExamFileError
import vn.io.nt0.examsuite.core.model.Exam
import vn.io.nt0.examsuite.core.session.ExamSession
import vn.io.nt0.examsuite.core.session.PauseReason
import vn.io.nt0.examsuite.core.session.SessionClock
import vn.io.nt0.examsuite.core.session.SessionMode
import vn.io.nt0.examsuite.core.session.SessionPhase
import vn.io.nt0.examsuite.data.db.AttemptEntity
import vn.io.nt0.examsuite.data.library.AssetSampleSource
import vn.io.nt0.examsuite.data.library.ExamLibrary
import vn.io.nt0.examsuite.data.library.ImportProblem
import vn.io.nt0.examsuite.data.library.ImportResult
import java.io.File
import java.time.Instant
import java.util.UUID

/** Thư viện của bản Android (library.md, mobile.md): nhập, Cập nhật đề, xoá có Hoàn tác, dọn, đề mẫu, lần thi, phiên dở. */
@RunWith(AndroidJUnit4::class)
class ExamLibraryTest {
    private val db = DataTest.database()
    private val clock = DataTest.Clock()
    private val library = DataTest.library(db, clock)
    private val kienThucChung = UUID.fromString("0b6c1f8e-4d2a-4c1b-9f3e-2a7d5e8c1b40")

    private fun add(bytes: ByteArray = DataTest.pack("kien-thuc-chung")) = runBlocking {
        (library.import(DataTest.stream(bytes)) as ImportResult.Added).item
    }

    private class Clock(var t: Double = 0.0) : SessionClock {
        override fun now(): Instant = Instant.parse("2026-10-22T08:00:00Z").plusMillis((t * 1000).toLong())
        override fun uptimeSeconds() = t
    }

    private fun submitted(exam: Exam, answerFirst: Boolean = true): ExamSession {
        val c = Clock()
        val s = ExamSession.start(exam, ExamComposer.compose(exam, CompositionOptions(seed = 3uL)), SessionMode.EXAM, null, "Nguyễn Văn A", c)
        if (answerFirst) s.currentQuestion.correct.forEach { s.select(it) }
        c.t = 90.0
        s.openReview(); s.submit()
        return s
    }

    @Test
    fun importCopiesFileIntoAppStorageAndAddsEntry() = runBlocking {
        val item = add()
        assertEquals(kienThucChung, item.examId)
        assertEquals(listOf(5, 2, 1), listOf(item.questionCount, item.sectionCount, item.mediaCount))
        assertTrue(library.examFile(item.examId).isFile)
        assertEquals(listOf(item), library.items().first())
        assertEquals(emptyList<File>(), File(library.examsDir, ".incoming").listFiles()?.toList() ?: emptyList<File>())
        assertEquals(5, library.open(item.examId).exam.questionCount)
    }

    @Test
    fun invalidOrNonZipFilesAreRejectedWithCodedReasonAndNothingIsKept() = runBlocking {
        val invalid = library.import(DataTest.stream(DataTest.packInvalid("one-option"))) as ImportResult.Rejected
        assertTrue((invalid.problem as ImportProblem.InvalidPackage).error is ExamFileError.ValidationFailed)
        val notZip = library.import(DataTest.stream("không phải zip".toByteArray())) as ImportResult.Rejected
        assertEquals(ImportProblem.InvalidPackage(ExamFileError.NotAZipArchive), notZip.problem)
        assertEquals(emptyList<Any>(), library.items().first())
        assertEquals(0, File(library.examsDir, ".incoming").listFiles()?.size ?: 0)
    }

    @Test
    fun fileLargerThanCapIsRejectedBeforeReading() = runBlocking {
        val small = DataTest.library(maxFileBytes = 100)
        assertEquals(ImportResult.Rejected(ImportProblem.FileTooLarge(100)), small.import(DataTest.stream(DataTest.pack("kien-thuc-chung"))))
    }

    @Test
    fun sameExamIdAlwaysAsksAndCancelKeepsLibraryUnchanged() = runBlocking {
        val first = add()
        val again = library.import(DataTest.stream(DataTest.pack("kien-thuc-chung"))) as ImportResult.NeedsUpdateConfirmation
        assertEquals(first, again.existing)
        library.discard(again.pending)
        assertEquals(listOf(first), library.items().first())
        assertEquals(0, File(library.examsDir, ".incoming").listFiles()?.size ?: 0)
    }

    @Test
    fun updateReplacesFileAndCardInfoKeepsAddedDateAndHistory() = runBlocking {
        val first = add()
        library.saveAttempt(submitted(library.open(first.examId).exam))
        clock.millis += 60_000
        val changed = DataTest.pack("kien-thuc-chung") { it.replace("\"passPercent\": 70", "\"passPercent\": 80") }
        val ask = library.import(DataTest.stream(changed)) as ImportResult.NeedsUpdateConfirmation
        val updated = library.confirmUpdate(ask.pending)
        assertEquals(80, updated.passPercent)
        assertEquals(first.addedAtMillis, updated.addedAtMillis)
        assertEquals(clock.millis, updated.updatedAtMillis)
        assertEquals(1, library.attemptsFor(first.examId).size)
        assertEquals(80L, library.open(first.examId).exam.passPercent)
    }

    @Test
    fun removeHidesUndoRestoresPurgeDeletesFileAndDraftButKeepsHistory() = runBlocking {
        val item = add()
        val exam = library.open(item.examId).exam
        library.saveAttempt(submitted(exam))
        library.saveDraft(ExamSession.start(exam, ExamComposer.compose(exam, CompositionOptions(seed = 1uL)), SessionMode.PRACTICE, null, "A", Clock()))
        assertTrue(library.remove(item.examId))
        assertEquals(emptyList<Any>(), library.items().first())
        assertTrue(library.undoRemove(item.examId))
        assertEquals(1, library.items().first().size)
        library.remove(item.examId)
        assertEquals(1, library.purgeRemoved())
        assertFalse(library.examFile(item.examId).exists())
        assertNull(library.item(item.examId))
        assertNull(library.loadDraft())
        assertEquals(1, library.history().first().size)
        assertFalse(library.undoRemove(item.examId))
    }

    @Test
    fun importingAnExamThatIsPendingRemovalAddsItFresh() = runBlocking {
        val item = add()
        library.remove(item.examId)
        clock.millis += 1_000
        val again = add()
        assertEquals(clock.millis, again.addedAtMillis)
        assertEquals(listOf(again), library.items().first())
    }

    @Test
    fun recoverOnStartCleansIncomingOrphansPendingRemovalsAndEntriesWithoutFile() = runBlocking {
        val kept = add()
        val gone = add(DataTest.pack("toi-thieu"))
        library.examFile(gone.examId).delete()
        File(library.examsDir, ".incoming").mkdirs()
        File(library.examsDir, ".incoming/x.part").writeText("dở")
        File(library.examsDir, "${UUID.randomUUID()}.exam").writeText("mồ côi")
        val removed = add(DataTest.pack("bien-khoang-trang"))
        library.remove(removed.examId)
        val report = library.recoverOnStart()
        assertEquals(listOf(1, 0, 1, 0, 1, 1), listOf(report.purgedRemoved, report.orphanFilesRestored, report.orphanFilesDeleted,
            report.entriesRefreshed, report.entriesWithoutFileDropped, report.incomingDeleted))
        assertEquals(listOf(kept.examId), library.items().first().map { it.examId })
        assertEquals(setOf("${kept.examId}.exam", ".incoming"), library.examsDir.list()!!.toSet())
    }

    @Test
    fun samplesFromAssetsAreReadStrictlyAndSeededOnceAsSamples() = runBlocking {
        val source = AssetSampleSource(DataTest.context.assets)
        assertEquals(2, source.names().size)
        assertEquals(2, library.seedSamples(source))
        val items = library.items().first()
        assertEquals(2, items.size)
        assertTrue(items.all { it.isSample })
        assertEquals(0, library.seedSamples(source))
        items.forEach { assertNotNull(library.open(it.examId)) }
    }

    @Test
    fun attemptIsSavedWithPayloadAppearsInHistoryAndAsLastAttemptAndClearsDraft() = runBlocking {
        val item = add()
        val exam = library.open(item.examId).exam
        library.saveDraft(ExamSession.start(exam, ExamComposer.compose(exam, CompositionOptions(seed = 1uL)), SessionMode.EXAM, null, "A", Clock()))
        val session = submitted(exam)
        val summary = library.saveAttempt(session)
        assertEquals(listOf("Nguyễn Văn A", "Kiến thức chung", "KTC01"), listOf(summary.candidateName, summary.examTitle, summary.examCode))
        assertEquals(90.0, summary.elapsedSeconds, 0.0)
        assertEquals(session.result!!.score1000, summary.score1000)
        assertEquals(listOf(summary), library.history().first())
        assertEquals(summary.percent, library.items().first().single().lastAttempt!!.percent)
        val detail = library.attemptDetail(summary.attemptId)!!
        assertEquals(session.paper, detail.payload!!.paper)
        assertNull(library.loadDraft())
    }

    @Test
    fun unreadablePayloadStillShowsSummaryWithReason() = runBlocking {
        val item = add()
        val summary = library.saveAttempt(submitted(library.open(item.examId).exam))
        val broken = AttemptEntity(UUID.randomUUID().toString(), item.examId.toString(), "Kiến thức chung", "KTC01", "B", "exam", 0, 1, 1.0, 10,
            5, 1, 200, 20, 70, false, 2, "{\"payloadVersion\":2}")
        db.attempts().insert(broken)
        val detail = library.attemptDetail(UUID.fromString(broken.attemptId))!!
        assertNull(detail.payload)
        assertTrue(detail.unreadableReason!!.contains("v2"))
        assertNotNull(library.attemptDetail(summary.attemptId)!!.payload)
    }

    @Test
    fun draftIsSavedLoadedRestoredAndBrokenDraftLoadsWithoutSnapshot() = runBlocking {
        val item = add()
        val exam = library.open(item.examId).exam
        val c = Clock()
        val s = ExamSession.start(exam, ExamComposer.compose(exam, CompositionOptions(shuffleOptions = true, seed = 5uL)), SessionMode.EXAM, null, "A", c)
        s.select(s.currentItem.optionOrder[0]); c.t = 42.0
        library.saveDraft(s)
        val draft = library.loadDraft()!!
        assertEquals(item.examId, draft.examId)
        // Luật khôi phục là của lõi (SnapshotTest); ở đây chỉ cần ghi rồi đọc lại đúng snapshot.
        assertEquals(s.snapshot(), draft.snapshot)
        db.drafts().upsert(vn.io.nt0.examsuite.data.db.DraftEntity(0, item.examId.toString(), "{\"draftVersion\":9}", 1))
        assertNull(library.loadDraft()!!.snapshot)
        library.clearDraft()
        assertNull(library.loadDraft())
    }

    @Test
    fun mediaIsReadFromTheCopiedFileOnDemand() = runBlocking {
        val item = add()
        val path = library.open(item.examId).mediaPaths.single()
        assertEquals(File(DataTest.fixtures, "exams/kien-thuc-chung/$path").readBytes().toList(), library.media(item.examId, path).toList())
    }

    @Test
    fun orphanExamFileThatReadsStrictlyIsRestoredNotDeleted() = runBlocking {
        val item = add()
        db.entries().delete(item.examId.toString())
        val report = library.recoverOnStart()
        assertEquals(1, report.orphanFilesRestored)
        assertEquals(listOf(item.examId), library.items().first().map { it.examId })
        assertTrue(library.examFile(item.examId).exists())
    }

    @Test
    fun updateInterruptedAfterFileMoveIsCompletedOnNextStart() = runBlocking {
        val first = add()
        val changed = DataTest.pack("kien-thuc-chung") { it.replace("\"passPercent\": 70", "\"passPercent\": 85") }
        val ask = library.import(DataTest.stream(changed)) as ImportResult.NeedsUpdateConfirmation
        // Tắt app sau khi đổi tên file, trước khi ghi kho: dấu cập nhật còn, mục còn thông tin cũ.
        File(library.examsDir, "${first.examId}.updating").writeText("")
        java.nio.file.Files.move(ask.pending.file.toPath(), library.examFile(first.examId).toPath(), java.nio.file.StandardCopyOption.REPLACE_EXISTING)
        assertEquals(70, library.item(first.examId)!!.passPercent)
        val report = library.recoverOnStart()
        assertEquals(1, report.entriesRefreshed)
        assertEquals(85, library.item(first.examId)!!.passPercent)
        assertEquals(first.addedAtMillis, library.item(first.examId)!!.addedAtMillis)
        assertFalse(File(library.examsDir, "${first.examId}.updating").exists())
    }

    @Test
    fun concurrentImportsOfTheSameNewExamNeverOverwriteWithoutAsking() = runBlocking {
        val bytes = DataTest.pack("kien-thuc-chung")
        val results = coroutineScope {
            (1..4).map { async(kotlinx.coroutines.Dispatchers.Default) { library.import(DataTest.stream(bytes)) } }.map { it.await() }
        }
        assertEquals(1, results.count { it is ImportResult.Added })
        assertEquals(3, results.count { it is ImportResult.NeedsUpdateConfirmation })
    }

    @Test(expected = IllegalStateException::class)
    fun confirmUpdateAfterPendingFileWasCleanedFails() = runBlocking<Unit> {
        add()
        val ask = library.import(DataTest.stream(DataTest.pack("kien-thuc-chung"))) as ImportResult.NeedsUpdateConfirmation
        library.recoverOnStart()
        library.confirmUpdate(ask.pending)
    }
}
