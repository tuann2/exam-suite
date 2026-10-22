package vn.io.nt0.examsuite.core

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test
import vn.io.nt0.examsuite.core.text.Markdown
import vn.io.nt0.examsuite.core.text.MarkdownSpan

/** Markdown cơ bản (exam-format.md): đậm, nghiêng, mã, liên kết giữ chữ, escape; giữ xuống dòng. */
class MarkdownTest {
    @Test
    fun `đậm, nghiêng, đậm nghiêng, mã trong dòng`() {
        assertEquals(listOf(MarkdownSpan("Chọn "), MarkdownSpan("một", bold = true), MarkdownSpan(" đáp án "), MarkdownSpan("đúng", italic = true)),
            Markdown.spans("Chọn **một** đáp án *đúng*"))
        assertEquals(listOf(MarkdownSpan("cả hai", bold = true, italic = true)), Markdown.spans("***cả hai***"))
        assertEquals(listOf(MarkdownSpan("Lệnh "), MarkdownSpan("ls -la", code = true)), Markdown.spans("Lệnh `ls -la`"))
        assertEquals(listOf(MarkdownSpan("đậm", bold = true), MarkdownSpan(" và "), MarkdownSpan("nghiêng", italic = true)), Markdown.spans("__đậm__ và _nghiêng_"))
    }

    @Test
    fun `chữ trơn cho trình đọc màn hình, bỏ ký hiệu, giữ chữ của liên kết và xuống dòng`() {
        assertEquals("Xem tài liệu SI\nrồi chọn A*B", Markdown.plainText("Xem [tài liệu **SI**](https://x.vn)\nrồi chọn A\\*B"))
    }

    @Test
    fun `ký hiệu không đóng hay giữa chữ giữ nguyên, mã không phân tích bên trong`() {
        assertEquals("2 * 3 = 6", Markdown.plainText("2 * 3 = 6"))
        assertEquals("snake_case_name", Markdown.plainText("snake_case_name"))
        assertEquals("**chưa đóng", Markdown.plainText("**chưa đóng"))
        assertEquals(listOf(MarkdownSpan("a **b**", code = true)), Markdown.spans("`a **b**`"))
    }
}
