package vn.io.nt0.examsuite.core

import org.junit.jupiter.api.Assertions.assertArrayEquals
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertThrows
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import vn.io.nt0.examsuite.core.file.ExamFileError
import vn.io.nt0.examsuite.core.file.ExamPackageLimits
import vn.io.nt0.examsuite.core.file.ExamPackageReader
import vn.io.nt0.examsuite.core.validation.IssueCode
import vn.io.nt0.examsuite.core.validation.IssueSeverity
import java.io.File

/** Bộ đọc gói ở mức zip và ảnh (exam-format.md, mục Gói); ca JSON ở fixtures/invalid-json. */
class PackageReaderTest {
    private val dir = Repo.examDir("kien-thuc-chung")
    private val manifest = File(dir, "exam.json").readBytes()
    private val mediaName = File(dir, "media").list()!!.first()
    private val image = File(dir, "media/$mediaName").readBytes()
    private val entries = listOf("exam.json" to manifest, "media/$mediaName" to image)

    private inline fun <reified T : ExamFileError> rejects(file: File, limits: ExamPackageLimits = ExamPackageLimits.DEFAULT): T =
        assertThrows(T::class.java) { ExamPackageReader.readStrict(file, limits) }

    @Test
    fun `đọc được fixture, ảnh có trong mediaPaths, đọc lại ảnh lúc cần đúng byte`() {
        val file = Zip.make(entries)
        val package_ = ExamPackageReader.readStrict(file)
        assertEquals(setOf("media/$mediaName"), package_.mediaPaths)
        assertEquals(5, package_.exam.questionCount)
        assertArrayEquals(image, ExamPackageReader.readMedia(file, "media/$mediaName"))
    }

    @Test
    fun `gói nén STORED cũng đọc được`() {
        ExamPackageReader.readStrict(Zip.make(entries, stored = true))
    }

    @Test
    fun `không phải zip, file rỗng, thiếu exam json`() {
        val text = File.createTempFile("khong-zip", ".exam").apply { writeText("không phải zip"); deleteOnExit() }
        rejects<ExamFileError.NotAZipArchive>(text)
        val empty = File.createTempFile("khong-zip", ".exam").apply { deleteOnExit() }
        rejects<ExamFileError.NotAZipArchive>(empty)
        rejects<ExamFileError.MissingManifest>(Zip.make(listOf("media/$mediaName" to image, "de/exam.json" to manifest)))
    }

    /** `ZipOutputStream` chặn tên trùng: ghi tên đảo ngược cùng độ dài rồi sửa byte tên trong file. */
    private fun fixDuplicates(file: File, list: List<Pair<String, ByteArray>>): File {
        var bytes = String(file.readBytes(), Charsets.ISO_8859_1)
        for ((name, _) in list) if (name == "exam.json".reversed() || name == "media/$mediaName".reversed()) bytes = bytes.replace(name, name.reversed())
        file.writeBytes(bytes.toByteArray(Charsets.ISO_8859_1))
        return file
    }

    @Test
    fun `entry thư mục, entry lạ, ảnh sai tên hay trong thư mục con bị bỏ qua`() {
        val file = Zip.make(entries + listOf(
            "media/" to ByteArray(0), "__MACOSX/._exam.json" to byteArrayOf(1, 2), "readme.txt" to "x".toByteArray(),
            "media/a/$mediaName" to image, "media/ABCDEF0123456789.png" to image,
        ))
        assertEquals(setOf("media/$mediaName"), ExamPackageReader.readStrict(file).mediaPaths)
    }

    @Test
    fun `trần số entry tính cả entry bị bỏ qua`() {
        val many = entries + (1..5).map { "junk/$it" to byteArrayOf() }
        assertEquals(ExamPackageLimits.ENTRY_COUNT_NAME, rejects<ExamFileError.TooLarge>(Zip.make(many), ExamPackageLimits(entryCount = 6)).entry)
        ExamPackageReader.readStrict(Zip.make(many), ExamPackageLimits(entryCount = 7))
    }

    @Test
    fun `trần kích thước exam json, mỗi ảnh và tổng giải nén`() {
        val file = Zip.make(entries)
        assertEquals("exam.json", rejects<ExamFileError.TooLarge>(file, ExamPackageLimits(manifestBytes = manifest.size - 1L)).entry)
        assertEquals("media/$mediaName", rejects<ExamFileError.TooLarge>(file, ExamPackageLimits(mediaEntryBytes = image.size - 1L)).entry)
        assertEquals(ExamPackageLimits.TOTAL_SIZE_NAME,
            rejects<ExamFileError.TooLarge>(file, ExamPackageLimits(totalUncompressedBytes = manifest.size + image.size - 1L)).entry)
        ExamPackageReader.readStrict(file, ExamPackageLimits(totalUncompressedBytes = manifest.size + image.size.toLong()))
    }

    @Test
    fun `trần độ sâu tuỳ chỉnh, đề hợp lệ sâu đúng 7 cấp`() {
        val file = Zip.make(entries)
        assertEquals(6, rejects<ExamFileError.TooDeep>(file, ExamPackageLimits(maxJsonDepth = 6)).limit)
        ExamPackageReader.readStrict(file, ExamPackageLimits(maxJsonDepth = 7))
    }

    @Test
    fun `CRC sai hay dữ liệu nén hỏng thì CorruptedEntry`() {
        val file = Zip.make(entries, stored = true)
        val bytes = file.readBytes()
        val at = indexOf(bytes, image.copyOfRange(0, 16)) + 20
        bytes[at] = (bytes[at].toInt() xor 0xFF).toByte()
        file.writeBytes(bytes)
        assertEquals("media/$mediaName", rejects<ExamFileError.CorruptedEntry>(file).path)
    }

    private fun indexOf(haystack: ByteArray, needle: ByteArray): Int =
        (0..haystack.size - needle.size).first { i -> needle.indices.all { haystack[i + it] == needle[it] } }

    @Test
    fun `ảnh câu hỏi sai tên thì InvalidMediaPath, thiếu trong gói thì MissingMedia, trước bước kiểm đề`() {
        val text = String(manifest)
        val image0 = Regex("\"image\": \"([^\"]+)\"").find(text)!!.groupValues[1]
        val badName = text.replace(image0, "media/khong-hop-le.png").toByteArray()
        assertEquals(listOf("media/khong-hop-le.png"), rejects<ExamFileError.InvalidMediaPath>(Zip.manifestOnly(badName)).paths)
        assertEquals(listOf(image0), rejects<ExamFileError.MissingMedia>(Zip.manifestOnly(manifest)).paths)
    }

    @Test
    fun `kiểm đề chỉ chặn lỗi mức error, warning vẫn mở được`() {
        val warnOnly = Zip.pack(Repo.examDir("bien-khoang-trang"))
        ExamPackageReader.readStrict(warnOnly)
        val bad = String(manifest).replace("\"passPercent\": 70", "\"passPercent\": 170").toByteArray()
        val error = rejects<ExamFileError.ValidationFailed>(Zip.make(listOf("exam.json" to bad, "media/$mediaName" to image)))
        assertEquals(listOf(IssueCode.PASS_PERCENT_OUT_OF_RANGE), error.issues.map { it.code })
        assertTrue(error.issues.all { it.severity == IssueSeverity.ERROR })
    }

    @Test
    fun `entry trùng tên thật trong zip (sửa byte tên) bị từ chối`() {
        val list = entries + ("exam.json".reversed() to manifest)
        val file = fixDuplicates(Zip.make(list), list)
        assertEquals("exam.json", rejects<ExamFileError.DuplicateEntry>(file).path)
        val list2 = entries + ("media/$mediaName".reversed() to image)
        val file2 = fixDuplicates(Zip.make(list2), list2)
        assertEquals("media/$mediaName", rejects<ExamFileError.DuplicateEntry>(file2).path)
    }
}
