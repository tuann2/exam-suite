package vn.io.nt0.examsuite.core.text

/** Một đoạn chữ với kiểu Markdown cơ bản (exam-format.md: đậm, nghiêng, mã trong dòng). */
data class MarkdownSpan(val text: String, val bold: Boolean = false, val italic: Boolean = false, val code: Boolean = false)

/**
 * Markdown cơ bản của nội dung đề, chỉ cú pháp trong dòng, giữ xuống dòng (như `PlainMarkdown`/`MarkdownText` của bản
 * macOS): `**đậm**`/`__đậm__`, `*nghiêng*`/`_nghiêng_`, `` `mã` ``, `[chữ](liên kết)` (giữ chữ), escape `\*`. Không
 * bảng, ảnh, HTML (exam-format.md). Cặp ký hiệu không đóng thì giữ nguyên chữ.
 */
object Markdown {
    /** Chữ trơn đã bỏ ký hiệu, cho câu đọc của trình đọc màn hình. */
    fun plainText(source: String): String = spans(source).joinToString("") { it.text }

    fun spans(source: String): List<MarkdownSpan> {
        val out = mutableListOf<MarkdownSpan>()
        parse(source, bold = false, italic = false, out)
        return merge(out)
    }

    private fun parse(s: String, bold: Boolean, italic: Boolean, out: MutableList<MarkdownSpan>) {
        val text = StringBuilder()
        fun flush() {
            if (text.isNotEmpty()) out += MarkdownSpan(text.toString(), bold, italic)
            text.clear()
        }
        var i = 0
        while (i < s.length) {
            val c = s[i]
            when {
                c == '\\' && i + 1 < s.length && s[i + 1] in PUNCTUATION -> {
                    text.append(s[i + 1]); i += 2
                }
                c == '`' -> {
                    val run = s.runLength(i, '`')
                    val close = findRun(s, i + run, '`', run)
                    if (close < 0) {
                        text.append(s, i, i + run); i += run
                    } else {
                        flush()
                        var content = s.substring(i + run, close)
                        if (content.length >= 2 && content.first() == ' ' && content.last() == ' ' && content.isNotBlank()) {
                            content = content.substring(1, content.length - 1)
                        }
                        out += MarkdownSpan(content, bold, italic, code = true)
                        i = close + run
                    }
                }
                c == '[' -> {
                    val end = matchingBracket(s, i)
                    if (end > 0 && end + 1 < s.length && s[end + 1] == '(' && s.indexOf(')', end + 2) > 0) {
                        flush()
                        parse(s.substring(i + 1, end), bold, italic, out)
                        i = s.indexOf(')', end + 2) + 1
                    } else {
                        text.append(c); i++
                    }
                }
                (c == '*' || c == '_') && canOpen(s, i, c) -> {
                    val run = minOf(s.runLength(i, c), 3)
                    val close = findClosing(s, i + run, c, run)
                    if (close < 0) {
                        text.append(s, i, i + s.runLength(i, c)); i += s.runLength(i, c)
                    } else {
                        flush()
                        parse(s.substring(i + run, close), bold || run >= 2, italic || run != 2, out)
                        i = close + run
                    }
                }
                else -> {
                    text.append(c); i++
                }
            }
        }
        flush()
    }

    private const val PUNCTUATION = "\\`*_{}[]()#+-.!~|<>\"'"

    private fun String.runLength(from: Int, c: Char): Int {
        var n = 0
        while (from + n < length && this[from + n] == c) n++
        return n
    }

    private fun findRun(s: String, from: Int, c: Char, length: Int): Int {
        var i = from
        while (i < s.length) {
            if (s[i] == c) {
                val n = s.runLength(i, c)
                if (n == length) return i
                i += n
            } else {
                i++
            }
        }
        return -1
    }

    /** Mở được khi ký tự sau không phải khoảng trắng; `_` không mở giữa chữ (`snake_case`). */
    private fun canOpen(s: String, i: Int, c: Char): Boolean {
        val after = s.getOrNull(i + s.runLength(i, c)) ?: return false
        if (after.isWhitespace()) return false
        if (c == '_' && i > 0 && s[i - 1].isLetterOrDigit()) return false
        return true
    }

    /** Dấu đóng cùng loại, đủ độ dài, ký tự trước không phải khoảng trắng; `_` không đóng giữa chữ. */
    private fun findClosing(s: String, from: Int, c: Char, length: Int): Int {
        var i = from
        while (i < s.length) {
            when {
                s[i] == '\\' -> i += 2
                s[i] == '`' -> {
                    val run = s.runLength(i, '`')
                    val close = findRun(s, i + run, '`', run)
                    i = if (close < 0) i + run else close + run
                }
                s[i] == c -> {
                    val n = s.runLength(i, c)
                    val before = s.getOrNull(i - 1)
                    val after = s.getOrNull(i + n)
                    val closes = n >= length && i > from && before != null && !before.isWhitespace() &&
                        !(c == '_' && after != null && after.isLetterOrDigit())
                    if (closes) return i + (n - length)
                    i += n
                }
                else -> i++
            }
        }
        return -1
    }

    private fun matchingBracket(s: String, open: Int): Int {
        var depth = 0
        for (i in open until s.length) {
            when (s[i]) {
                '[' -> depth++
                ']' -> if (--depth == 0) return i
                '\n' -> return -1
            }
        }
        return -1
    }

    private fun merge(spans: List<MarkdownSpan>): List<MarkdownSpan> {
        val out = mutableListOf<MarkdownSpan>()
        for (span in spans) {
            if (span.text.isEmpty()) continue
            val last = out.lastOrNull()
            if (last != null && last.bold == span.bold && last.italic == span.italic && last.code == span.code) {
                out[out.size - 1] = last.copy(text = last.text + span.text)
            } else {
                out += span
            }
        }
        return out
    }
}
