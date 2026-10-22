package vn.io.nt0.examsuite.core.file

import vn.io.nt0.examsuite.core.json.JsonObject
import vn.io.nt0.examsuite.core.json.StrictJson
import vn.io.nt0.examsuite.core.model.Exam

/**
 * Giải mã `exam.json` **không** qua các kiểm của chế độ nghiêm (bỏ qua trường lạ, `null` ở trường tuỳ chọn như vắng
 * mặt, nhận dấu phẩy thừa, khoá trùng lấy giá trị đầu). Chỉ để phân loại fixture như nhãn `undecodable`/`error` của
 * fixtures/expected-verdicts.json và để test dựng đề; app mở đề bằng `ExamPackageReader.readStrict`.
 */
object ExamDecoderAccess {
    /** Ném `ExamFileError.InvalidJson` khi không phân tích hay không giải mã được. */
    fun decode(bytes: ByteArray): Exam {
        val text = StrictJson.decodeUtf8(bytes) ?: throw ExamFileError.InvalidJson(JsonProblem.NotUtf8)
        val root = try {
            StrictJson.parse(text).root as? JsonObject ?: throw ExamFileError.InvalidJson(JsonProblem.RootNotObject)
        } catch (e: vn.io.nt0.examsuite.core.json.JsonSyntaxException) {
            throw ExamFileError.InvalidJson(JsonProblem.Unparsable(e.message ?: ""))
        }
        return try {
            ExamDecoder.decode(root)
        } catch (e: DecodeException) {
            throw ExamFileError.InvalidJson(e.problem)
        }
    }
}

/** Tập khoá hợp lệ của từng cấp, cho test so với schema. */
object SchemaKeysAccess {
    val exam: Set<String> get() = ExamSchemaKeys.exam
    val section: Set<String> get() = ExamSchemaKeys.section
    val question: Set<String> get() = ExamSchemaKeys.question
    val option: Set<String> get() = ExamSchemaKeys.option
}
