package vn.io.nt0.examsuite.core

import org.junit.jupiter.api.Assertions.assertArrayEquals
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertThrows
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.Timeout
import org.junit.jupiter.params.ParameterizedTest
import org.junit.jupiter.params.provider.ValueSource
import vn.io.nt0.examsuite.core.composer.SeededGenerator
import vn.io.nt0.examsuite.core.file.ExamFileError
import vn.io.nt0.examsuite.core.file.ExamPackageReader
import vn.io.nt0.examsuite.core.file.ExamPackageWriter
import vn.io.nt0.examsuite.core.file.ExamSourceKind
import vn.io.nt0.examsuite.core.file.OefLimit
import vn.io.nt0.examsuite.core.file.OefLimits
import vn.io.nt0.examsuite.core.file.OefPlace
import vn.io.nt0.examsuite.core.file.OefProblem
import vn.io.nt0.examsuite.core.file.OefReader
import vn.io.nt0.examsuite.core.model.QuestionType
import java.io.File
import java.nio.ByteBuffer
import java.util.concurrent.TimeUnit

/**
 * Bộ đọc `.oef` ngoài oracle (oracle ở `SharedOracleTest`): file hỏng hay dựng có chủ đích chỉ ra `ExamFileError`, không
 * crash hay treo (như `OEFRobustnessTests` của bản macOS); nhận diện theo nội dung; ghi gói `.exam` rồi đọc nghiêm lại.
 */
class OefReaderTest {
    private fun fixture(name: String) = File(Repo.fixtures, "oef/$name.oef").readBytes()

    /** Đọc nghiêm; lỗi nào cũng phải là `ExamFileError` (lỗi khác lọt ra làm test đỏ). */
    private fun readAny(data: ByteArray, limits: OefLimits = OefLimits.DEFAULT) {
        try {
            OefReader.convert(data, limits)
        } catch (_: ExamFileError) {
        }
    }

    private fun assertOef(expected: OefProblem, block: () -> Unit) {
        val error = assertThrows(ExamFileError::class.java) { block() }
        assertEquals(ExamFileError.Oef(expected), error)
    }

    // ---------- Bền vững ----------

    @ParameterizedTest
    @ValueSource(strings = ["co-ban", "goi-dap-an-packed", "qua-26-lua-chon"])
    fun `cắt cụt ở mọi vị trí`(name: String) {
        val data = fixture(name)
        for (length in 0 until data.size) readAny(data.copyOf(length))
    }

    @ParameterizedTest
    @ValueSource(strings = ["co-ban", "goi-dap-an-packed", "qua-26-lua-chon"])
    fun `đột biến ngẫu nhiên có seed (đổi, chèn, xoá byte)`(name: String) {
        val original = fixture(name).toList()
        val rng = SeededGenerator(20_261_031uL)
        repeat(1_500) {
            val bytes = original.toMutableList()
            repeat(rng.nextInt(3).toInt() + 1) {
                val index = rng.nextInt(bytes.size.toLong()).toInt()
                when (rng.nextInt(3)) {
                    0L -> bytes[index] = rng.next().toByte()
                    1L -> bytes.add(index, rng.next().toByte())
                    else -> if (bytes.size > 1) bytes.removeAt(index)
                }
            }
            readAny(bytes.toByteArray())
        }
    }

    @Test
    fun `độ dài khổng lồ, varint quá dài, số trường 0 là dây hỏng`() {
        // Gốc: trường 1 (độ dài) khai 2^62 byte.
        assertOef(OefProblem.Malformed(1)) { OefReader.convert(bytes(0x0A, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x40)) }
        // Varint 11 byte.
        assertOef(OefProblem.Malformed(1)) { OefReader.convert(bytes(0x0A, *IntArray(10) { 0xFF }, 0x01)) }
        // Byte thứ 10 mang hơn một bit.
        assertOef(OefProblem.Malformed(1)) { OefReader.convert(bytes(0x18, *IntArray(9) { 0xFF }, 0x02)) }
        assertOef(OefProblem.Malformed(0)) { OefReader.convert(bytes(0x02, 0x00)) }
    }

    @Test
    fun `vượt giới hạn file, chữ, số phần tử`() {
        val data = fixture("co-ban")
        assertOef(OefProblem.TooLarge(OefLimit.FILE, 100)) { OefReader.convert(data, OefLimits(fileBytes = 100)) }
        assertOef(OefProblem.TooLarge(OefLimit.TEXT, 40)) { OefReader.convert(data, OefLimits(textBytes = 40)) }
        assertOef(OefProblem.TooLarge(OefLimit.ELEMENTS, 14)) { OefReader.convert(data, OefLimits(elementCount = 14)) }
        // Vừa đúng giới hạn thì đọc được: co-ban có 2 phần, 3 câu, 8 lựa chọn, 2 đáp án trong Answers.
        OefReader.convert(data, OefLimits(elementCount = 15))
    }

    @Test
    @Timeout(value = 1, unit = TimeUnit.MINUTES)
    fun `hàng trăm nghìn đáp án khác nhau đọc xong nhanh, đáp án tính vào giới hạn`() {
        val packed = ArrayList<Byte>()
        for (value in 0x4000 until 0x4000 + 200_000) {
            var v = value
            while (v >= 0x80) {
                packed += ((v and 0x7F) or 0x80).toByte()
                v = v ushr 7
            }
            packed += v.toByte()
        }
        val options = field(7, bytes(0x08, 0x41) + field(2, bytes(0x61))) + field(7, bytes(0x08, 0x42) + field(2, bytes(0x62)))
        val question = field(2, bytes(0x71)) + bytes(0x28, 0x01) + field(6, packed.toByteArray()) + options
        val passmark = ByteBuffer.allocate(8).order(java.nio.ByteOrder.LITTLE_ENDIAN).putDouble(500.0).array()
        val data = field(1, field(1, bytes(0x74)) + bytes(0x21) + passmark) + field(2, field(2, question))
        val error = assertThrows(ExamFileError.Oef::class.java) { OefReader.convert(data) }
        val problem = error.problem as OefProblem.AnswerNotInOptions
        assertEquals(OefPlace(0, 0), problem.place)
        assertEquals(20, problem.letters.size, "câu báo giữ 20 chữ đầu")
        assertOef(OefProblem.TooLarge(OefLimit.ELEMENTS, 1_000)) { OefReader.convert(data, OefLimits(elementCount = 1_000)) }
    }

    @Test
    fun `ảnh vượt giới hạn, file rỗng`() {
        assertOef(OefProblem.ImageTooLarge(OefPlace(0, 1), 10)) { OefReader.convert(fixture("co-ban"), OefLimits(imageBytes = 10)) }
        assertOef(OefProblem.NoQuestions) { OefReader.convert(ByteArray(0)) }
    }

    @Test
    fun `đọc qua file như qua dữ liệu, cùng file ra cùng đề`() {
        val file = File(Repo.fixtures, "oef/co-ban.oef")
        val fromFile = OefReader.read(file)
        val fromBytes = OefReader.convert(file.readBytes())
        assertEquals(fromBytes.exam, fromFile.exam)
        assertEquals(fromBytes.media, fromFile.media)
        assertOef(OefProblem.TooLarge(OefLimit.FILE, 10)) { OefReader.read(file, OefLimits(fileBytes = 10)) }
    }

    // ---------- Nhận diện theo nội dung (bản Android) ----------

    @Test
    fun `nhận diện theo nội dung, zip là gói, oef mới và cũ là oef, còn lại không phải file đề`() {
        fun kind(name: String) = ExamSourceKind.of(fixture(name).copyOf(ExamSourceKind.HEAD_BYTES))
        assertEquals(ExamSourceKind.EXAM_PACKAGE, ExamSourceKind.of(File(Repo.fixtures, "packages").listFiles()!!.first { it.extension == "exam" }.readBytes().copyOf(4)))
        assertEquals(ExamSourceKind.EXAM_PACKAGE, ExamSourceKind.of(bytes(0x50, 0x4B, 0x05, 0x06)))
        // .oef bản cũ dạng zip đọc như gói `.exam` (không có tên file để phân biệt).
        assertEquals(ExamSourceKind.EXAM_PACKAGE, kind("ban-cu-zip"))
        assertEquals(ExamSourceKind.OEF, kind("ban-cu-nrbf"))
        assertEquals(ExamSourceKind.OEF, kind("co-ban"))
        assertEquals(ExamSourceKind.OEF, kind("cat-cut"))
        assertEquals(ExamSourceKind.UNKNOWN, kind("van-ban-wims"))
        assertEquals(ExamSourceKind.UNKNOWN, ExamSourceKind.of(ByteArray(0)))
        assertEquals(ExamSourceKind.UNKNOWN, ExamSourceKind.of("không phải zip".toByteArray()))
    }

    // ---------- Ghi gói .exam ----------

    @ParameterizedTest
    @ValueSource(strings = ["co-ban", "goi-dap-an-packed", "anh-cac-loai", "thoi-gian-64bit"])
    fun `gói ghi từ oef đọc nghiêm lại ra đúng đề và ảnh`(name: String) {
        val conversion = OefReader.read(File(Repo.fixtures, "oef/$name.oef"))
        val file = File.createTempFile("oef", ".exam").also { it.deleteOnExit() }
        file.outputStream().use { ExamPackageWriter.write(conversion.exam, conversion.media, it) }
        val package_ = ExamPackageReader.readStrict(file)
        assertEquals(conversion.exam, package_.exam)
        assertEquals(conversion.media.keys, package_.mediaPaths)
        for ((path, data) in conversion.media) {
            assertArrayEquals(ByteArray(data.remaining()).also { data.duplicate().get(it) }, ExamPackageReader.readMedia(file, path))
        }
    }

    @Test
    fun `exam json thoát đúng ngoặc kép, gạch chéo, ký tự điều khiển, trường tuỳ chọn chỉ ghi khi có`() {
        val odd = "a\"b\\c\u0000d\u0001e\u001f\tf\ng\rh 😀 ư"
        val exam = Build.exam(
            Build.section(1, Build.question(1, text = odd, explanation = odd), Build.question(2, type = QuestionType.MULTIPLE, correct = "AC", explanation = null)),
        ).copy(code = "MA-1", hideAnswers = true, instructions = odd)
        val file = File.createTempFile("viet", ".exam").also { it.deleteOnExit() }
        file.outputStream().use { ExamPackageWriter.write(exam, emptyMap(), it) }
        assertEquals(exam, ExamPackageReader.readStrict(file).exam)
        val json = buildString { ExamPackageWriter.writeManifest(exam.copy(code = null, hideAnswers = false, instructions = null), this) }
        assertTrue("\"code\"" !in json && "\"hideAnswers\"" !in json && "\"instructions\"" !in json, json)
        assertTrue("\\u0000" in buildString { ExamPackageWriter.writeManifest(exam, this) })
    }

    private fun bytes(vararg values: Int) = ByteArray(values.size) { values[it].toByte() }

    /** Trường độ dài: khoá, varint độ dài, nội dung. */
    private fun field(number: Int, payload: ByteArray): ByteArray {
        val head = ArrayList<Byte>()
        head += ((number shl 3) or 2).toByte()
        var length = payload.size
        while (length >= 0x80) {
            head += ((length and 0x7F) or 0x80).toByte()
            length = length ushr 7
        }
        head += length.toByte()
        return head.toByteArray() + payload
    }
}
