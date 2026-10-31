package vn.io.nt0.examsuite.core.file

import vn.io.nt0.examsuite.core.model.Exam
import vn.io.nt0.examsuite.core.model.Question
import java.io.OutputStream
import java.io.OutputStreamWriter
import java.nio.ByteBuffer
import java.util.zip.CRC32
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

/**
 * Ghi gói `.exam` (docs/product/exam-format.md, mục Gói) từ một đề đã có: bản Android chuyển `.oef` thành gói lúc thêm
 * vào Thư viện rồi đọc nghiêm lại như mọi đề (plan-oef.md Phần 4, Kotlin). `exam.json` theo schema v1, trường tuỳ chọn
 * vắng (null, `hideAnswers` false) thì không ghi; ghi dạng luồng, không dựng cả chuỗi JSON trong bộ nhớ. Ảnh ghi không nén
 * (ảnh đã nén sẵn), theo thứ tự đường dẫn.
 */
object ExamPackageWriter {
    fun write(exam: Exam, media: Map<String, ByteBuffer>, out: OutputStream) {
        ZipOutputStream(out).use { zip ->
            zip.putNextEntry(ZipEntry(ExamFormat.MANIFEST_NAME))
            // Không đóng writer: đóng nó là đóng cả zip.
            val writer = OutputStreamWriter(zip, Charsets.UTF_8).buffered()
            writeManifest(exam, writer)
            writer.flush()
            zip.closeEntry()

            val chunk = ByteArray(64 * 1024)
            for ((path, data) in media.toSortedMap()) {
                val entry = ZipEntry(path).apply {
                    method = ZipEntry.STORED
                    size = data.remaining().toLong()
                    crc = CRC32().apply { update(data.duplicate()) }.value
                }
                zip.putNextEntry(entry)
                val source = data.duplicate()
                while (source.hasRemaining()) {
                    val n = minOf(chunk.size, source.remaining())
                    source.get(chunk, 0, n)
                    zip.write(chunk, 0, n)
                }
                zip.closeEntry()
            }
        }
    }

    /** `exam.json` của đề, khoá theo thứ tự của schema. */
    internal fun writeManifest(exam: Exam, out: Appendable) {
        out.append("{\"formatVersion\":").append(exam.formatVersion.toString())
        out.append(",\"id\":").string(exam.id.toString())
        out.append(",\"title\":").string(exam.title)
        exam.code?.let { out.append(",\"code\":").string(it) }
        out.append(",\"passPercent\":").append(exam.passPercent.toString())
        out.append(",\"timeLimitMinutes\":").append(exam.timeLimitMinutes.toString())
        if (exam.hideAnswers) out.append(",\"hideAnswers\":true")
        exam.instructions?.let { out.append(",\"instructions\":").string(it) }
        out.append(",\"sections\":[")
        exam.sections.forEachIndexed { s, section ->
            if (s > 0) out.append(',')
            out.append("{\"id\":").string(section.id.toString())
            out.append(",\"title\":").string(section.title)
            out.append(",\"questions\":[")
            section.questions.forEachIndexed { q, question ->
                if (q > 0) out.append(',')
                writeQuestion(question, out)
            }
            out.append("]}")
        }
        out.append("]}")
    }

    private fun writeQuestion(question: Question, out: Appendable) {
        out.append("{\"id\":").string(question.id.toString())
        out.append(",\"type\":").string(question.type.raw)
        out.append(",\"text\":").string(question.text)
        question.image?.let { out.append(",\"image\":").string(it) }
        out.append(",\"options\":[")
        question.options.forEachIndexed { i, option ->
            if (i > 0) out.append(',')
            out.append("{\"id\":").string(option.id.toString())
            out.append(",\"text\":").string(option.text).append('}')
        }
        out.append("],\"correct\":[")
        question.correct.forEachIndexed { i, id ->
            if (i > 0) out.append(',')
            out.string(id.toString())
        }
        out.append(']')
        question.explanation?.let { out.append(",\"explanation\":").string(it) }
        out.append('}')
    }

    /** Chuỗi JSON: thoát `"`, `\` và U+0000–U+001F; ký tự khác ghi nguyên (UTF-8). */
    private fun Appendable.string(value: String): Appendable {
        append('"')
        for (c in value) {
            when {
                c == '"' -> append("\\\"")
                c == '\\' -> append("\\\\")
                c == '\n' -> append("\\n")
                c == '\r' -> append("\\r")
                c == '\t' -> append("\\t")
                c < ' ' -> append("\\u00").append(HEX[c.code shr 4]).append(HEX[c.code and 0x0F])
                else -> append(c)
            }
        }
        return append('"')
    }

    private const val HEX = "0123456789abcdef"
}
