package vn.io.nt0.examsuite.core

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertThrows
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import vn.io.nt0.examsuite.core.file.ExamDecoderAccess
import vn.io.nt0.examsuite.core.file.ExamFileError
import vn.io.nt0.examsuite.core.file.JsonProblem
import vn.io.nt0.examsuite.core.json.JsonSyntaxException
import vn.io.nt0.examsuite.core.json.StrictJson
import java.io.File

/**
 * Bộ phân tích JSON và bộ giải mã: chỉ chi tiết riêng của Kotlin. Ca so với lõi Swift (khoá trùng qua escape và lồng nhau,
 * dấu phẩy thừa, số, UUID, lỗi giải mã có đường dẫn) ở fixtures/invalid-json (SharedOracleTest).
 */
class JsonAndDecoderTest {
    private val base = File(Repo.fixtures, "invalid-json/base.json").readText()

    @Test
    fun `cú pháp JSON chuẩn, từ chối số 0 đứng đầu, dấu cộng, chấm cụt, ký tự điều khiển, escape lạ, phẩy đầu, gốc là số`() {
        for (bad in listOf("""{"a": 01}""", """{"a": +1}""", """{"a": .5}""", """{"a": 1.}""", "{\"a\": \"x\ny\"}", """{"a": "\x"}""",
            """{,}""", """[1,,2]""", "1", "", "   ", """{"a" 1}""", """{"a": tru}""")) {
            assertThrows(JsonSyntaxException::class.java, { StrictJson.parse(bad) }, bad)
        }
        StrictJson.parse("""{"a": -0.5e-3, "b": [true, false, null], "c": "é\t"}""")
    }

    @Test
    fun `bộ đếm độ sâu bỏ qua ngoặc trong chuỗi, kể cả sau nháy escape, lồng 100 nghìn cấp không tràn stack`() {
        val quoteInString = """{"a": "\"[[[[", "b": "\\", "c": [[1]]}"""
        assertTrue(!StrictJson.depthExceeds(quoteInString.toByteArray(), 3))
        assertTrue(StrictJson.depthExceeds(quoteInString.toByteArray(), 2))
        assertTrue(!StrictJson.depthExceeds("[[]][[]]".toByteArray(), 2))
        val huge = "[".repeat(100_000) + "]".repeat(100_000)
        assertTrue(StrictJson.depthExceeds(huge.toByteArray(), 32))
    }

    @Test
    fun `thứ tự khoá như Swift, theo code point sau NFC, ký tự ngoài BMP sau U+FFFF`() {
        val keys = listOf("�", "😀", "b", "a", "é", "é").sortedWith(StrictJson.keyOrder)
        assertEquals(listOf("a", "b", "é", "é", "�", "😀").map { java.text.Normalizer.normalize(it, java.text.Normalizer.Form.NFC) },
            keys.map { java.text.Normalizer.normalize(it, java.text.Normalizer.Form.NFC) })
    }

    private fun decodeWith(old: String, new: String) = ExamDecoderAccess.decode(base.replace(old, new).toByteArray().also { check(base.contains(old)) })

    private fun problem(old: String, new: String): JsonProblem =
        (assertThrows(ExamFileError.InvalidJson::class.java) { decodeWith(old, new) }).problem

    @Test
    fun `trường lạ bị bỏ qua và null ở trường tuỳ chọn như vắng mặt khi giải mã không nghiêm`() {
        val exam = decodeWith("\"passPercent\": 50", "\"passPercent\": 50, \"extra\": {\"x\": 1}, \"code\": null")
        assertEquals(null, exam.code)
    }
}
