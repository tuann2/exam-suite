package vn.io.nt0.examsuite.data

import android.content.Context
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import vn.io.nt0.examsuite.data.db.LibraryDatabase
import vn.io.nt0.examsuite.data.library.ExamLibrary
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.File
import java.nio.file.Files
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

/** Hỗ trợ test của `:data` (Robolectric): kho trong bộ nhớ, thư mục tạm, đồng hồ giả, gói đề từ fixtures của repo. */
object DataTest {
    val context: Context get() = ApplicationProvider.getApplicationContext()
    val fixtures = File("../../fixtures")

    fun database(): LibraryDatabase =
        Room.inMemoryDatabaseBuilder(context, LibraryDatabase::class.java).allowMainThreadQueries().build()

    class Clock(var millis: Long = 1_760_000_000_000L) : () -> Long {
        override fun invoke(): Long = millis
    }

    fun library(db: LibraryDatabase = database(), clock: Clock = Clock(), maxFileBytes: Long = ExamLibrary.MAX_FILE_BYTES) =
        ExamLibrary(db, Files.createTempDirectory("thu-vien").toFile(), clock, maxFileBytes = maxFileBytes)

    /** Gói `.exam` của `fixtures/exams/<tên>`, tuỳ chọn sửa `exam.json` trước khi đóng gói. */
    fun pack(name: String, edit: (String) -> String = { it }): ByteArray {
        val dir = File(fixtures, "exams/$name")
        val entries = mutableListOf("exam.json" to edit(File(dir, "exam.json").readText()).toByteArray())
        File(dir, "media").listFiles()?.sortedBy { it.name }?.forEach { entries += "media/${it.name}" to it.readBytes() }
        return zip(entries)
    }

    fun packInvalid(name: String) = zip(listOf("exam.json" to File(fixtures, "invalid/$name.json").readBytes()))

    fun zip(entries: List<Pair<String, ByteArray>>): ByteArray {
        val out = ByteArrayOutputStream()
        ZipOutputStream(out).use { z -> entries.forEach { (n, b) -> z.putNextEntry(ZipEntry(n)); z.write(b); z.closeEntry() } }
        return out.toByteArray()
    }

    fun stream(bytes: ByteArray) = ByteArrayInputStream(bytes)
}
