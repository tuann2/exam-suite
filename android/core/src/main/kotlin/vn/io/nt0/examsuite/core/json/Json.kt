package vn.io.nt0.examsuite.core.json

import java.nio.ByteBuffer
import java.nio.charset.CharacterCodingException
import java.nio.charset.CodingErrorAction
import java.text.Normalizer

/** Giá trị JSON đã phân tích. Số giữ nguyên chữ trong file để bộ giải mã quyết cách đọc (xem `ExamDecoder`). */
sealed interface JsonValue

/** Object; khoá trùng thì giữ giá trị **đầu** (như `JSONSerialization` trên macOS), chỗ trùng ghi ở `ParsedJson`. */
class JsonObject(val entries: Map<String, JsonValue>) : JsonValue

class JsonArray(val items: List<JsonValue>) : JsonValue

data class JsonString(val value: String) : JsonValue

data class JsonNumber(val literal: String) : JsonValue

data class JsonBool(val value: Boolean) : JsonValue

data object JsonNull : JsonValue

/**
 * Kết quả phân tích: cây giá trị, cộng những điều JSON chuẩn và schema cấm mà bộ phân tích vẫn nhận để bản Học viên báo
 * đúng chỗ (cùng cách `StrictJSON.scan` của ExamFile):
 * - [duplicateKeys]: đường dẫn khoá xuất hiện từ hai lần trong cùng object, theo thứ tự lần lặp đầu; mỗi khoá của một
 *   object báo một lần; so sau khi giải mã escape (`"a"` và `"a"` là trùng).
 * - [trailingCommas]: đường dẫn object/mảng có dấu phẩy ngay trước dấu đóng, theo thứ tự dấu đóng; gốc là [ROOT_PATH].
 */
class ParsedJson(val root: JsonValue, val duplicateKeys: List<String>, val trailingCommas: List<String>)

/** Lỗi cú pháp; `message` chỉ cho nhật ký. */
class JsonSyntaxException(message: String) : Exception(message)

object StrictJson {
    /** Tên của gốc trong đường dẫn (cùng `JSONProblem.rootPath` của bản macOS). */
    const val ROOT_PATH = "<gốc>"

    fun join(prefix: String, key: String): String = if (prefix.isEmpty()) key else "$prefix.$key"

    /**
     * `true` nếu có chỗ lồng object/mảng sâu hơn `limit` cấp (gốc là cấp 1). Quét byte, bỏ qua ngoặc trong chuỗi (kể
     * cả sau `\"`), dừng ngay khi vượt trần; chạy trên dữ liệu chưa kiểm cú pháp. Cùng thuật toán với
     * `StrictJSON.depthExceeds` của bản macOS, để bộ phân tích đệ quy phía sau không bao giờ sâu quá trần.
     */
    fun depthExceeds(data: ByteArray, limit: Int): Boolean {
        var depth = 0
        var inString = false
        var escaped = false
        for (byte in data) {
            val b = byte.toInt() and 0xFF
            if (inString) {
                when {
                    escaped -> escaped = false
                    b == '\\'.code -> escaped = true
                    b == '"'.code -> inString = false
                }
                continue
            }
            when (b) {
                '"'.code -> inString = true
                '{'.code, '['.code -> {
                    depth += 1
                    if (depth > limit) return true
                }
                '}'.code, ']'.code -> depth = maxOf(0, depth - 1)
            }
        }
        return false
    }

    /** Giải mã UTF-8 nghiêm (byte hỏng → null), không thay bằng U+FFFD như `String(bytes, UTF_8)`. */
    fun decodeUtf8(data: ByteArray): String? = try {
        Charsets.UTF_8.newDecoder()
            .onMalformedInput(CodingErrorAction.REPORT)
            .onUnmappableCharacter(CodingErrorAction.REPORT)
            .decode(ByteBuffer.wrap(data))
            .toString()
    } catch (_: CharacterCodingException) {
        null
    }

    /**
     * Phân tích như `JSONSerialization` của Foundation (đã đối chiếu bằng fixtures/invalid-json): bỏ BOM đầu văn bản;
     * gốc phải là object hay mảng; từ chối `NaN`/`Infinity`, số cực lớn (xem `number`), surrogate lẻ, ký tự điều khiển
     * chưa escape, rác sau gốc;
     * **nhận** dấu phẩy thừa và khoá trùng nhưng ghi lại. Gọi sau `depthExceeds` (bộ phân tích đệ quy theo độ sâu).
     */
    fun parse(text: String): ParsedJson = Parser(text).run()

    /** So khoá như `String <` của Swift: theo dãy code point sau khi chuẩn hoá NFC. */
    val keyOrder: Comparator<String> = Comparator { a, b ->
        val x = Normalizer.normalize(a, Normalizer.Form.NFC)
        val y = Normalizer.normalize(b, Normalizer.Form.NFC)
        var i = 0
        var j = 0
        while (i < x.length && j < y.length) {
            val cx = x.codePointAt(i)
            val cy = y.codePointAt(j)
            if (cx != cy) return@Comparator cx.compareTo(cy)
            i += Character.charCount(cx)
            j += Character.charCount(cy)
        }
        (x.length - i).compareTo(y.length - j)
    }

    private class Parser(private val s: String) {
        private var pos = if (s.startsWith('\uFEFF')) 1 else 0
        private val duplicates = mutableListOf<String>()
        private val trailing = mutableListOf<String>()

        fun run(): ParsedJson {
            skipWhitespace()
            val c = peek() ?: fail("dữ liệu rỗng")
            if (c != '{' && c != '[') fail("gốc phải là object hoặc mảng")
            val root = value("")
            skipWhitespace()
            if (pos != s.length) fail("rác sau giá trị gốc ở vị trí $pos")
            return ParsedJson(root, duplicates, trailing)
        }

        private fun fail(message: String): Nothing = throw JsonSyntaxException(message)

        private fun peek(): Char? = if (pos < s.length) s[pos] else null

        private fun skipWhitespace() {
            while (pos < s.length && (s[pos] == ' ' || s[pos] == '\t' || s[pos] == '\n' || s[pos] == '\r')) pos++
        }

        private fun expect(c: Char) {
            if (peek() != c) fail("cần '$c' ở vị trí $pos")
            pos++
        }

        private fun value(path: String): JsonValue {
            skipWhitespace()
            return when (val c = peek() ?: fail("hết dữ liệu")) {
                '{' -> obj(path)
                '[' -> array(path)
                '"' -> JsonString(string())
                't' -> literal("true", JsonBool(true))
                'f' -> literal("false", JsonBool(false))
                'n' -> literal("null", JsonNull)
                else -> if (c == '-' || c in '0'..'9') number() else fail("giá trị không hợp lệ ở vị trí $pos")
            }
        }

        private fun literal(word: String, result: JsonValue): JsonValue {
            if (!s.startsWith(word, pos)) fail("giá trị không hợp lệ ở vị trí $pos")
            pos += word.length
            return result
        }

        private fun obj(path: String): JsonObject {
            expect('{')
            val entries = LinkedHashMap<String, JsonValue>()
            val reported = HashSet<String>()
            val seen = HashSet<String>()
            skipWhitespace()
            if (peek() == '}') {
                pos++
                return JsonObject(entries)
            }
            while (true) {
                skipWhitespace()
                if (peek() != '"') fail("cần khoá ở vị trí $pos")
                val key = string()
                skipWhitespace()
                expect(':')
                // Ghi khoá trùng ngay khi đọc khoá, trước giá trị (cùng thứ tự với bộ quét của bản macOS). Swift so `String`
                // theo tương đương chuẩn: so dạng NFC; đường dẫn ghi đúng chữ của lần lặp như bản macOS.
                val canonical = Normalizer.normalize(key, Normalizer.Form.NFC)
                val duplicate = !seen.add(canonical)
                if (duplicate && reported.add(canonical)) duplicates += join(path, key)
                val child = value(join(path, key))
                if (!duplicate && key !in entries) entries[key] = child
                skipWhitespace()
                when (peek()) {
                    ',' -> {
                        pos++
                        skipWhitespace()
                        if (peek() == '}') {
                            pos++
                            trailing += path.ifEmpty { ROOT_PATH }
                            return JsonObject(entries)
                        }
                    }
                    '}' -> {
                        pos++
                        return JsonObject(entries)
                    }
                    else -> fail("cần ',' hoặc '}' ở vị trí $pos")
                }
            }
        }

        private fun array(path: String): JsonArray {
            expect('[')
            val items = mutableListOf<JsonValue>()
            skipWhitespace()
            if (peek() == ']') {
                pos++
                return JsonArray(items)
            }
            while (true) {
                items += value("$path[${items.size}]")
                skipWhitespace()
                when (peek()) {
                    ',' -> {
                        pos++
                        skipWhitespace()
                        if (peek() == ']') {
                            pos++
                            trailing += path.ifEmpty { ROOT_PATH }
                            return JsonArray(items)
                        }
                    }
                    ']' -> {
                        pos++
                        return JsonArray(items)
                    }
                    else -> fail("cần ',' hoặc ']' ở vị trí $pos")
                }
            }
        }

        private fun string(): String {
            expect('"')
            val out = StringBuilder()
            while (true) {
                val c = peek() ?: fail("chuỗi chưa đóng")
                pos++
                when {
                    c == '"' -> return out.toString()
                    c == '\\' -> out.append(escape())
                    c < ' ' -> fail("ký tự điều khiển chưa escape trong chuỗi")
                    else -> out.append(c)
                }
            }
        }

        /** Một escape (đã qua `\`); `\uXXXX` là surrogate phải đi đúng cặp. */
        private fun escape(): String {
            val c = peek() ?: fail("escape cụt")
            pos++
            return when (c) {
                '"' -> "\""
                '\\' -> "\\"
                '/' -> "/"
                'b' -> "\b"
                'f' -> "\u000C"
                'n' -> "\n"
                'r' -> "\r"
                't' -> "\t"
                'u' -> {
                    val unit = hex4()
                    when {
                        Character.isHighSurrogate(unit) -> {
                            if (!s.startsWith("\\u", pos)) fail("surrogate cao không có surrogate thấp đi sau")
                            pos += 2
                            val low = hex4()
                            if (!Character.isLowSurrogate(low)) fail("surrogate cao không có surrogate thấp đi sau")
                            charArrayOf(unit, low).concatToString()
                        }
                        Character.isLowSurrogate(unit) -> fail("surrogate thấp đứng một mình")
                        else -> unit.toString()
                    }
                }
                else -> fail("escape không hợp lệ \\$c")
            }
        }

        private fun hex4(): Char {
            if (pos + 4 > s.length) fail("escape \\u cụt")
            val digits = s.substring(pos, pos + 4)
            if (!digits.all { it in '0'..'9' || it in 'a'..'f' || it in 'A'..'F' }) fail("escape \\u sai")
            pos += 4
            return digits.toInt(16).toChar()
        }

        /** Số theo đúng ngữ pháp JSON (RFC 8259): không số 0 đứng đầu, không `+`, không `.5`, không `1.`. */
        private fun number(): JsonNumber {
            val start = pos
            if (peek() == '-') pos++
            when (peek()) {
                '0' -> pos++
                in '1'..'9' -> while (peek()?.isAsciiDigit() == true) pos++
                else -> fail("số không hợp lệ ở vị trí $start")
            }
            if (peek() == '.') {
                pos++
                if (peek()?.isAsciiDigit() != true) fail("số không hợp lệ ở vị trí $start")
                while (peek()?.isAsciiDigit() == true) pos++
            }
            if (peek() == 'e' || peek() == 'E') {
                pos++
                if (peek() == '+' || peek() == '-') pos++
                if (peek()?.isAsciiDigit() != true) fail("số không hợp lệ ở vị trí $start")
                while (peek()?.isAsciiDigit() == true) pos++
            }
            val literal = s.substring(start, pos)
            // Xấp xỉ JSONSerialization của Foundation với số cực lớn (đã đo, fixtures/invalid-json number-*): Foundation từ
            // chối 1e309, số nguyên rất dài, 0e10000, 0e-1000 khi phân tích. Kotlin từ chối số mà Double ra vô cực và số mũ
            // từ 4 chữ số: cùng kết luận nhận/từ chối trên mọi ca đã đo; chỉ khác loại lỗi ở số không có trong đề thật
            // (-1e400 Foundation nhận rồi báo khi giải mã; số nguyên 167–308 chữ số Foundation báo khi phân tích).
            val exponentDigits = literal.substringAfter('e', literal.substringAfter('E', "")).trimStart('+', '-')
            if (literal.toDouble().isInfinite() || exponentDigits.length >= 4) fail("số quá lớn ở vị trí $start")
            return JsonNumber(literal)
        }

        private fun Char.isAsciiDigit() = this in '0'..'9'
    }
}
