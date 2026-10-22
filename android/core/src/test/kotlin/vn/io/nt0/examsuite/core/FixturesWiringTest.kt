package vn.io.nt0.examsuite.core

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import java.io.File

/** Test của khung A0: :core đọc được oracle dùng chung tại chỗ (fixtures/ của repo), không qua bản chép. */
class FixturesWiringTest {
    private val fixtures = File(requireNotNull(System.getProperty("examsuite.fixtures")) { "thiếu examsuite.fixtures" })

    @Test
    fun `đọc expected-verdicts tại chỗ, đủ fixture và danh sách khoảng trắng`() {
        val root = Json.parseToJsonElement(fixtures.resolve("expected-verdicts.json").readText()).jsonObject
        val verdicts = root.getValue("verdicts") as JsonObject
        val whiteSpace = root.getValue("whiteSpace") as JsonArray

        val onDisk = fixtures.resolve("invalid").list()!!.count { it.endsWith(".json") } +
            fixtures.resolve("exams").list()!!.size
        assertEquals(onDisk, verdicts.size, "mỗi fixture có đúng một dòng kết luận")
        val codePoints = whiteSpace.flatMap { entry ->
            val (first, last) = entry.jsonPrimitive.content.split("-").let { it.first() to it.last() }
            (first.toInt(16)..last.toInt(16)).toList()
        }
        assertEquals(25, codePoints.toSet().size, "25 code point White_Space của exam-format.md, ghi theo dải")
        assertTrue(ExamFormat.SUPPORTED_FORMAT_VERSION >= 1)
    }
}
