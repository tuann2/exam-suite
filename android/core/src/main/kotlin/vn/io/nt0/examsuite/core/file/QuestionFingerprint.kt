package vn.io.nt0.examsuite.core.file

import vn.io.nt0.examsuite.core.model.Exam
import vn.io.nt0.examsuite.core.model.Question
import java.security.MessageDigest
import java.text.Normalizer
import java.util.UUID

/**
 * Dấu vân tay câu: SHA-256 (hex thường) của dạng chuẩn phiên bản 1, **cùng thuật toán với `QuestionFingerprint` của bản
 * macOS** (Nt0 chốt Q11 2026-10-22: payload riêng nhưng quy tắc "câu đã sửa sau lần thi" giống hệt). Vector cố định:
 * fixtures/vectors/question-fingerprints.json.
 *
 * Dạng chuẩn: object JSON viết liền, khoá sắp xếp, UTF-8:
 * `{"correct":[…],"explanation":"…"|null,"image":"…"|null,"options":[{"id":"A","text":"…"},…],"text":"…","type":"…"}`;
 * `correct` sắp xếp, bỏ trùng; `options` theo thứ tự file; chuỗi NFC; chỉ escape `"`, `\`, U+0000–U+001F (`\b \f \n
 * \r \t` dạng ngắn, còn lại `\u00xx` hex thường). Không gồm id câu và phần.
 */
object QuestionFingerprint {
    fun fingerprint(question: Question): String {
        val digest = MessageDigest.getInstance("SHA-256").digest(canonicalJson(question).toByteArray(Charsets.UTF_8))
        // Hex tự dựng: `String.format` cho từng byte chiếm phần lớn thời gian với đề 2.000 câu trên điện thoại (A4).
        val hex = CharArray(digest.size * 2)
        for ((i, byte) in digest.withIndex()) {
            val v = byte.toInt() and 0xFF
            hex[2 * i] = HEX_DIGITS[v ushr 4]
            hex[2 * i + 1] = HEX_DIGITS[v and 0x0F]
        }
        return String(hex)
    }

    private val HEX_DIGITS = "0123456789abcdef".toCharArray()

    /** Dấu vân tay mọi câu theo id; id trùng (đề sai) thì lấy lần xuất hiện đầu. */
    fun fingerprints(exam: Exam): Map<UUID, String> {
        val result = LinkedHashMap<UUID, String>()
        for (question in exam.allQuestions) if (question.id !in result) result[question.id] = fingerprint(question)
        return result
    }

    fun canonicalJson(question: Question): String = buildString {
        append("{\"correct\":[")
        append(question.correct.toSortedSet().joinToString(",") { string(it.toString()) })
        append("],\"explanation\":").append(question.explanation?.let(::string) ?: "null")
        append(",\"image\":").append(question.image?.let(::string) ?: "null")
        append(",\"options\":[")
        append(question.options.joinToString(",") { "{\"id\":" + string(it.id.toString()) + ",\"text\":" + string(it.text) + "}" })
        append("],\"text\":").append(string(question.text))
        append(",\"type\":").append(string(question.type.raw))
        append("}")
    }

    private fun string(value: String): String = buildString {
        append('"')
        val nfc = Normalizer.normalize(value, Normalizer.Form.NFC)
        var i = 0
        while (i < nfc.length) {
            val cp = nfc.codePointAt(i)
            i += Character.charCount(cp)
            when {
                cp == '"'.code -> append("\\\"")
                cp == '\\'.code -> append("\\\\")
                cp == 0x08 -> append("\\b")
                cp == 0x0C -> append("\\f")
                cp == 0x0A -> append("\\n")
                cp == 0x0D -> append("\\r")
                cp == 0x09 -> append("\\t")
                cp < 0x20 -> append("\\u00").append("%02x".format(cp))
                else -> appendCodePoint(cp)
            }
        }
        append('"')
    }
}
