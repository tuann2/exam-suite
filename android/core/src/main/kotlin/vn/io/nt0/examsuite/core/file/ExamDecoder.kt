package vn.io.nt0.examsuite.core.file

import vn.io.nt0.examsuite.core.json.JsonArray
import vn.io.nt0.examsuite.core.json.JsonBool
import vn.io.nt0.examsuite.core.json.JsonNull
import vn.io.nt0.examsuite.core.json.JsonNumber
import vn.io.nt0.examsuite.core.json.JsonObject
import vn.io.nt0.examsuite.core.json.JsonString
import vn.io.nt0.examsuite.core.json.JsonValue
import vn.io.nt0.examsuite.core.json.StrictJson
import vn.io.nt0.examsuite.core.model.Exam
import vn.io.nt0.examsuite.core.model.ExamOption
import vn.io.nt0.examsuite.core.model.ExamSection
import vn.io.nt0.examsuite.core.model.OptionId
import vn.io.nt0.examsuite.core.model.Question
import vn.io.nt0.examsuite.core.model.QuestionType
import vn.io.nt0.examsuite.core.model.StrictUuid
import java.util.UUID

internal class DecodeException(val problem: JsonProblem) : Exception(problem.toString())

/**
 * Giải mã cây JSON thành `Exam` theo đúng cách `JSONDecoder` + `Codable` của bản macOS kết luận (fixtures/
 * expected-verdicts.json, nhãn `undecodable`): trường lạ bị bỏ qua (chế độ nghiêm đã từ chối trước), `null` ở trường
 * tuỳ chọn như vắng mặt, thứ tự đọc khoá như `init(from:)` của Swift để lỗi đầu tiên trùng nhau.
 *
 * Số nguyên như `JSONDecoder` (đã đối chiếu): chữ số thuần đọc thẳng thành Int64, tràn là lỗi; có `.`/`e`/`E` thì đọc
 * qua Double rồi nhận nếu là số nguyên nằm trong Int64 (`1.0`, `5e1` hợp lệ; `70.5` lỗi).
 */
internal object ExamDecoder {
    fun decode(root: JsonObject): Exam = Ctx(root, "").run {
        Exam(
            formatVersion = long("formatVersion"),
            id = uuid("id"),
            title = string("title"),
            code = optString("code"),
            passPercent = long("passPercent"),
            timeLimitMinutes = long("timeLimitMinutes"),
            hideAnswers = optBool("hideAnswers") ?: false,
            instructions = optString("instructions"),
            sections = objects("sections").map { section(it) },
        )
    }

    private fun section(c: Ctx) = ExamSection(
        id = c.uuid("id"),
        title = c.string("title"),
        questions = c.objects("questions").map { question(it) },
    )

    private fun question(c: Ctx): Question {
        val id = c.uuid("id")
        val typeRaw = c.string("type")
        val type = QuestionType.fromRaw(typeRaw)
            ?: throw DecodeException(JsonProblem.InvalidValue(c.childPath("type"), "loại câu lạ \"$typeRaw\""))
        return Question(
            id = id,
            type = type,
            text = c.string("text"),
            image = c.optString("image"),
            options = c.objects("options").map { option(it) },
            correct = c.optionIds("correct"),
            explanation = c.optString("explanation"),
        )
    }

    private fun option(c: Ctx) = ExamOption(id = c.optionId("id"), text = c.string("text"))

    /** Một object đang giải mã, kèm đường dẫn của nó (`sections[0].questions[2]`). */
    private class Ctx(val obj: JsonObject, val path: String) {
        fun childPath(key: String) = StrictJson.join(path, key)

        private fun displayPath() = path.ifEmpty { StrictJson.ROOT_PATH }

        private fun required(key: String, type: String): JsonValue {
            val value = obj.entries[key] ?: throw DecodeException(JsonProblem.MissingKey(displayPath(), key))
            if (value is JsonNull) throw DecodeException(JsonProblem.ValueMissing(childPath(key), type))
            return value
        }

        private fun optional(key: String): JsonValue? = obj.entries[key]?.takeUnless { it is JsonNull }

        fun string(key: String): String = asString(required(key, "String"), childPath(key))

        fun optString(key: String): String? = optional(key)?.let { asString(it, childPath(key)) }

        fun optBool(key: String): Boolean? = optional(key)?.let {
            (it as? JsonBool)?.value ?: throw DecodeException(JsonProblem.TypeMismatch(childPath(key), "Bool"))
        }

        fun long(key: String): Long = asLong(required(key, "Int"), childPath(key))

        fun uuid(key: String): UUID {
            val text = string(key)
            return StrictUuid.parse(text)
                ?: throw DecodeException(JsonProblem.InvalidValue(childPath(key), "UUID không hợp lệ \"$text\""))
        }

        fun optionId(key: String): OptionId = parseOptionId(string(key), childPath(key))

        private fun array(key: String): List<JsonValue> {
            val value = required(key, "Array")
            return (value as? JsonArray)?.items
                ?: throw DecodeException(JsonProblem.TypeMismatch(childPath(key), "Array"))
        }

        fun objects(key: String): List<Ctx> = array(key).mapIndexed { i, element ->
            val elementPath = "${childPath(key)}[$i]"
            when (element) {
                is JsonObject -> Ctx(element, elementPath)
                is JsonNull -> throw DecodeException(JsonProblem.ValueMissing(elementPath, "Object"))
                else -> throw DecodeException(JsonProblem.TypeMismatch(elementPath, "Object"))
            }
        }

        fun optionIds(key: String): List<OptionId> = array(key).mapIndexed { i, element ->
            val elementPath = "${childPath(key)}[$i]"
            if (element is JsonNull) throw DecodeException(JsonProblem.ValueMissing(elementPath, "String"))
            parseOptionId(asString(element, elementPath), elementPath)
        }
    }

    private fun asString(value: JsonValue, path: String): String =
        (value as? JsonString)?.value ?: throw DecodeException(JsonProblem.TypeMismatch(path, "String"))

    private fun parseOptionId(text: String, path: String): OptionId = OptionId.of(text)
        ?: throw DecodeException(JsonProblem.InvalidValue(path, "mã lựa chọn phải là một chữ cái A–Z, nhận \"$text\""))

    fun asLong(value: JsonValue, path: String): Long {
        val literal = (value as? JsonNumber)?.literal ?: throw DecodeException(JsonProblem.TypeMismatch(path, "Int"))
        // JSONDecoder của Foundation báo "số không vừa Int" với codingPath rỗng (đã đối chiếu, fixtures/invalid-json
        // pass-percent-*): giữ đúng đường dẫn đó để hai lõi cùng kết luận.
        return integerValue(literal)
            ?: throw DecodeException(JsonProblem.InvalidValue(StrictJson.ROOT_PATH, "số $literal ở $path không phải số nguyên Int64"))
    }

    /** Giá trị số nguyên của chữ số JSON theo quy tắc của `JSONDecoder` (xem tài liệu của kiểu); null nếu không nhận. */
    fun integerValue(literal: String): Long? {
        if (literal.none { it == '.' || it == 'e' || it == 'E' }) return literal.toLongOrNull()
        val d = literal.toDoubleOrNull() ?: return null
        if (!d.isFinite() || d != Math.floor(d)) return null
        return if (d >= -9.223372036854775808E18 && d < 9.223372036854775808E18) d.toLong() else null
    }
}
