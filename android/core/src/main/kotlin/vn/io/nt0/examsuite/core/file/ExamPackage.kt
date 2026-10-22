package vn.io.nt0.examsuite.core.file

import vn.io.nt0.examsuite.core.json.JsonArray
import vn.io.nt0.examsuite.core.json.JsonNull
import vn.io.nt0.examsuite.core.json.JsonObject
import vn.io.nt0.examsuite.core.json.JsonValue
import vn.io.nt0.examsuite.core.json.StrictJson
import vn.io.nt0.examsuite.core.model.Exam

/** Hằng số của định dạng gói (docs/product/exam-format.md). */
object ExamFormat {
    const val CURRENT_VERSION: Long = Exam.CURRENT_FORMAT_VERSION
    const val FILE_EXTENSION = "exam"
    const val MANIFEST_NAME = "exam.json"
    const val MEDIA_DIRECTORY = "media"
}

/**
 * Đề đã đọc nghiêm. Khác bản macOS: ảnh **không** nằm trong bộ nhớ; `mediaPaths` là các ảnh có trong gói và đã được kiểm
 * (đúng tên, kích thước, CRC, trần dung lượng) lúc đọc. App đọc ảnh lúc cần bằng `ExamPackageReader.readMedia` từ chính
 * file đề (đã sao chép vào bộ nhớ của app, mobile.md), để đề 2.000 câu 200 ảnh không giữ hàng trăm MB trong RAM.
 */
data class ExamPackage(val exam: Exam, val mediaPaths: Set<String>)

/** Trần khi đọc gói (exam-format.md, mục Gói), chống zip bomb; vượt trần → `ExamFileError.TooLarge`/`TooDeep`. */
data class ExamPackageLimits(
    val manifestBytes: Long = 32L shl 20,
    val mediaEntryBytes: Long = 50L shl 20,
    val totalUncompressedBytes: Long = 1L shl 30,
    val entryCount: Int = 20_000,
    val maxJsonDepth: Int = 32,
) {
    companion object {
        val DEFAULT = ExamPackageLimits()

        /** Tên dùng trong `TooLarge` khi vượt trần số entry hoặc tổng dung lượng (cùng bản macOS). */
        const val ENTRY_COUNT_NAME = "<số entry>"
        const val TOTAL_SIZE_NAME = "<tổng giải nén>"
    }
}

/** Tên ảnh trong gói (exam-format.md): `media/<16–64 hex thường>.<png|jpg|jpeg|gif|webp|heic>`. */
object MediaNaming {
    val allowedExtensions = setOf("png", "jpg", "jpeg", "gif", "webp", "heic")

    /** Khớp tuyệt đối mẫu `image` của schema v1; chặn `media/../x.png`, `media/a/b.png`. */
    fun isValidPath(path: String): Boolean {
        val prefix = ExamFormat.MEDIA_DIRECTORY + "/"
        if (!path.startsWith(prefix)) return false
        val name = path.substring(prefix.length)
        val dot = name.lastIndexOf('.')
        if (dot < 0) return false
        val hash = name.substring(0, dot)
        val ext = name.substring(dot + 1)
        return hash.length in 16..64 && hash.all { it in '0'..'9' || it in 'a'..'f' } && ext in allowedExtensions
    }
}

/** Khoá hợp lệ ở từng cấp của `exam.json` v1; trùng `properties` của schema (test `SchemaKeysTest` so với schema). */
internal object ExamSchemaKeys {
    val exam = setOf("formatVersion", "id", "title", "code", "passPercent", "timeLimitMinutes", "hideAnswers", "instructions", "sections")
    val section = setOf("id", "title", "questions")
    val question = setOf("id", "type", "text", "image", "options", "correct", "explanation")
    val option = setOf("id", "text")

    /**
     * Đường dẫn mọi trường lạ, theo thứ tự đề → phần → câu → lựa chọn; trong một object xếp theo tên khoá. Giá trị sai
     * kiểu được bỏ qua ở đây (bước giải mã báo). Cùng kết quả với `ExamSchemaKeys.unknownFieldPaths` của bản macOS.
     */
    fun unknownFieldPaths(exam: JsonObject): List<String> {
        val paths = unknown(exam, this.exam, "").toMutableList()
        objects(exam.entries["sections"]).forEachIndexed { si, section ->
            val sp = "sections[$si]"
            paths += unknown(section, this.section, sp)
            objects(section.entries["questions"]).forEachIndexed { qi, question ->
                val qp = "$sp.questions[$qi]"
                paths += unknown(question, this.question, qp)
                objects(question.entries["options"]).forEachIndexed { oi, option ->
                    paths += unknown(option, this.option, "$qp.options[$oi]")
                }
            }
        }
        return paths
    }

    private fun unknown(obj: JsonObject, allowed: Set<String>, prefix: String): List<String> =
        obj.entries.keys.filter { it !in allowed }.sortedWith(StrictJson.keyOrder).map { StrictJson.join(prefix, it) }

    /** Phần tử không phải object thay bằng object rỗng để chỉ số trong đường dẫn vẫn đúng vị trí gốc. */
    private fun objects(value: JsonValue?): List<JsonObject> =
        (value as? JsonArray)?.items?.map { it as? JsonObject ?: JsonObject(emptyMap()) } ?: emptyList()

    /**
     * Đường dẫn mọi giá trị `null`, duyệt theo cấu trúc (object theo tên khoá, mảng theo chỉ số), bằng ngăn xếp tường
     * minh. Cùng thứ tự với `StrictJSON.nullValuePaths` của bản macOS.
     */
    fun nullValuePaths(exam: JsonObject): List<String> {
        val paths = mutableListOf<String>()
        val pending = ArrayDeque<Pair<JsonValue, String>>()
        pending.addLast(exam to "")
        while (pending.isNotEmpty()) {
            val (value, path) = pending.removeLast()
            when (value) {
                is JsonObject -> value.entries.keys.sortedWith(StrictJson.keyOrder).asReversed()
                    .forEach { pending.addLast(value.entries.getValue(it) to StrictJson.join(path, it)) }
                is JsonArray -> value.items.indices.reversed().forEach { pending.addLast(value.items[it] to "$path[$it]") }
                is JsonNull -> paths += path
                else -> Unit
            }
        }
        return paths
    }
}
