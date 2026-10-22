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

/** Bộ phân tích JSON và bộ giải mã: chi tiết không có trong fixture (ca đọc nghiêm ở fixtures/invalid-json). */
class JsonAndDecoderTest {
    private val base = File(Repo.fixtures, "invalid-json/base.json").readText()

    @Test
    fun `bộ quét khoá trùng, cặp surrogate, escape trong khoá, ngoặc trong chuỗi, cùng kết quả với lõi Swift`() {
        // § thay cho dấu gạch ngược của escape JSON, đổi lại lúc chạy, để escape hiện rõ trong mã.
        val json = """
            {"§ud83d§ude00": 1, "😀": 2,
             "a§"b": "}", "a§u0022b": "]",
             "x": {"k": "§§", "k": [1, {"k": 1}]},
             "list": [{"q": 1}, {"q": 2, "q": 3}, [], {"q": null}],
             "§u006A": 1, "§u006a": 2, "j": 3,
             "a§/b": 1, "a/b": 2}
        """.trimIndent().replace('§', '\\')
        assertEquals(listOf("😀", "a\"b", "x.k", "list[1].q", "j", "a/b"), StrictJson.parse(json).duplicateKeys)
    }

    @Test
    fun `khoá trùng ngoài báo trước khoá trùng bên trong giá trị của nó, giá trị đầu được giữ`() {
        val parsed = StrictJson.parse("""{"a": 1, "a": {"b": 1, "b": 2}}""")
        assertEquals(listOf("a", "a.b"), parsed.duplicateKeys)
        assertEquals(vn.io.nt0.examsuite.core.json.JsonNumber("1"), (parsed.root as vn.io.nt0.examsuite.core.json.JsonObject).entries["a"])
    }

    @Test
    fun `dấu phẩy thừa, phẩy trong chuỗi không tính, khoảng trắng trước dấu đóng vẫn tính, theo thứ tự dấu đóng`() {
        assertEquals(emptyList<String>(), StrictJson.parse("""{"a": ",}", "b": [",]", 1]}""").trailingCommas)
        assertEquals(listOf("a", "b"), StrictJson.parse("{\"a\": [1,\n\t ], \"b\": {\"c\": 1 ,\r\n}}").trailingCommas)
        assertEquals(listOf("[0]", "[1]", StrictJson.ROOT_PATH), StrictJson.parse("""[[1,],{"x":[],},]""").trailingCommas)
    }

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
    fun `số nguyên như JSONDecoder, 50 và 50 chấm 0 và 5e1 nhận, 50 chấm 5 và tràn Int64 từ chối, âm 0 là 0`() {
        assertEquals(50L, decodeWith("\"passPercent\": 50", "\"passPercent\": 50.0").passPercent)
        assertEquals(50L, decodeWith("\"passPercent\": 50", "\"passPercent\": 5E1").passPercent)
        assertEquals(50L, decodeWith("\"passPercent\": 50", "\"passPercent\": 50.000000000000001").passPercent)
        assertEquals(0L, decodeWith("\"passPercent\": 50", "\"passPercent\": -0").passPercent)
        assertEquals(9_223_372_036_854_775_807L, decodeWith("\"passPercent\": 50", "\"passPercent\": 9223372036854775807").passPercent)
        assertTrue(problem("\"passPercent\": 50", "\"passPercent\": 50.5") is JsonProblem.InvalidValue)
        assertTrue(problem("\"passPercent\": 50", "\"passPercent\": 9223372036854775808") is JsonProblem.InvalidValue)
        assertTrue(problem("\"passPercent\": 50", "\"passPercent\": 1e19") is JsonProblem.InvalidValue)
        assertEquals(JsonProblem.TypeMismatch("passPercent", "Int"), problem("\"passPercent\": 50", "\"passPercent\": \"50\""))
    }

    @Test
    fun `UUID như Swift, hoa thường đều nhận, dạng khác từ chối`() {
        val id = "11111111-2222-4333-8444-555555555555"
        decodeWith(id, id.uppercase())
        for (bad in listOf("{$id}", id.replace("-", ""), "1-1-1-1-1", " $id", id + "5", id.dropLast(1) + "g")) {
            assertTrue(problem(id, bad) is JsonProblem.InvalidValue, bad)
        }
    }

    @Test
    fun `lỗi giải mã nêu đường dẫn, thiếu khoá, null ở trường bắt buộc, sai kiểu, loại câu lạ, mã lựa chọn sai, Bool chỉ từ true false`() {
        assertEquals(JsonProblem.MissingKey("sections[0].questions[0]", "correct"), problem("],\n          \"correct\": [\"B\"]", "]"))
        assertEquals(JsonProblem.ValueMissing("title", "String"), problem("\"title\": \"Đề", "\"title\": null, \"x\": \"Đề"))
        assertEquals(JsonProblem.TypeMismatch("sections", "Array"), problem("\"sections\": [", "\"sections\": \"x\", \"y\": ["))
        assertTrue(problem("\"type\": \"single\"", "\"type\": \"truefalse\"") is JsonProblem.InvalidValue)
        assertEquals("sections[0].questions[0].options[1].id", (problem("{ \"id\": \"B\"", "{ \"id\": \"b\"") as JsonProblem.InvalidValue).path)
        assertEquals(JsonProblem.TypeMismatch("hideAnswers", "Bool"), problem("\"passPercent\": 50", "\"passPercent\": 50, \"hideAnswers\": 1"))
    }

    @Test
    fun `trường lạ bị bỏ qua và null ở trường tuỳ chọn như vắng mặt khi giải mã không nghiêm`() {
        val exam = decodeWith("\"passPercent\": 50", "\"passPercent\": 50, \"extra\": {\"x\": 1}, \"code\": null")
        assertEquals(null, exam.code)
    }
}
