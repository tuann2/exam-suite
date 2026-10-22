package vn.io.nt0.examsuite.core.attempt

import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import vn.io.nt0.examsuite.core.model.StrictUuid

/**
 * Kiểm kiểu trên cây JSON trước khi giải mã DTO, để payload và phiên dở chặt như `JSONDecoder` của bản macOS (review độc
 * lập PR #2): kotlinx.serialization nhận số và Bool viết trong ngoặc kép (`"total":"5"`), nhận hai khoá UUID chỉ khác
 * hoa/thường như hai khoá khác nhau rồi gộp khi đổi sang UUID. Trả lý do đầu tiên, null nếu ổn.
 */
internal object StrictPayloadJson {
    /** Seed: chuỗi thập phân thuần (không dấu `+`, không khoảng trắng), vừa 64 bit không dấu. */
    fun parseSeed(text: String): ULong? = if (text.isNotEmpty() && text.all { it in '0'..'9' }) text.toULongOrNull() else null

    fun problem(element: JsonElement, numericKeys: Set<String>, booleanKeys: Set<String>, uuidKeyedMaps: Set<String>): String? {
        val pending = ArrayDeque<Pair<String, JsonElement>>()
        pending.addLast("" to element)
        while (pending.isNotEmpty()) {
            val (path, value) = pending.removeLast()
            when (value) {
                is JsonObject -> {
                    val name = path.substringAfterLast('.')
                    if (name in uuidKeyedMaps) {
                        val ids = value.keys.map { StrictUuid.parse(it) ?: return "$path: khoá \"$it\" không phải UUID" }
                        if (ids.toSet().size != ids.size) return "$path: hai khoá cùng một UUID (khác hoa/thường)"
                    } else {
                        for ((key, child) in value) {
                            if (key in numericKeys && !(child is JsonPrimitive && !child.isString && child.content != "true" && child.content != "false" && child.content != "null")) {
                                return "$path.$key: cần số, không phải chuỗi"
                            }
                            if (key in booleanKeys && !(child is JsonPrimitive && !child.isString && (child.content == "true" || child.content == "false"))) {
                                return "$path.$key: cần true/false"
                            }
                        }
                    }
                    for ((key, child) in value) pending.addLast("$path.$key" to child)
                }
                is JsonArray -> value.forEachIndexed { i, child -> pending.addLast("$path[$i]" to child) }
                else -> Unit
            }
        }
        return null
    }
}
