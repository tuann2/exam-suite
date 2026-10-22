package vn.io.nt0.examsuite.core

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import vn.io.nt0.examsuite.core.file.ExamDecoderAccess
import vn.io.nt0.examsuite.core.model.Exam
import vn.io.nt0.examsuite.core.model.ExamOption
import vn.io.nt0.examsuite.core.model.ExamSection
import vn.io.nt0.examsuite.core.model.OptionId
import vn.io.nt0.examsuite.core.model.Question
import vn.io.nt0.examsuite.core.model.QuestionType
import vn.io.nt0.examsuite.core.session.SessionClock
import java.io.File
import java.time.Instant
import java.util.UUID
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

/** Đường dẫn oracle dùng chung, đọc tại chỗ từ repo (thuộc tính `examsuite.fixtures` do build đặt). */
object Repo {
    val fixtures = File(requireNotNull(System.getProperty("examsuite.fixtures")) { "thiếu examsuite.fixtures" })
    val root: File = fixtures.parentFile
    val samples = File(root, "Packages/ExamFeatures/Sources/LibraryData/Resources/Samples")

    fun json(relative: String): JsonElement = Json.parseToJsonElement(File(fixtures, relative).readText())

    fun examDir(name: String) = File(fixtures, "exams/$name")

    /** Đề của fixture `exams/<tên>` (giải mã, không kiểm nghiêm). */
    fun exam(name: String): Exam = ExamDecoderAccess.decode(File(examDir(name), "exam.json").readBytes())
}

/** Đồng hồ giả: `now` và `uptime` chỉnh tay. */
class FakeClock(var uptime: Double = 1_000.0, var wall: Instant = Instant.parse("2026-10-22T08:00:00Z")) : SessionClock {
    override fun now(): Instant = wall

    override fun uptimeSeconds(): Double = uptime

    fun advance(seconds: Double) {
        uptime += seconds
        wall = wall.plusMillis((seconds * 1000).toLong())
    }
}

object Zip {
    /** Gói zip trong file tạm, giữ thứ tự entry; tên kết thúc bằng "/" là thư mục. */
    fun make(entries: List<Pair<String, ByteArray>>, stored: Boolean = false): File {
        val file = File.createTempFile("exam", ".exam").also { it.deleteOnExit() }
        ZipOutputStream(file.outputStream()).use { zip ->
            for ((name, data) in entries) {
                val entry = ZipEntry(name)
                if (stored || name.endsWith("/")) {
                    entry.method = ZipEntry.STORED
                    entry.size = data.size.toLong()
                    entry.crc = java.util.zip.CRC32().apply { update(data) }.value
                }
                zip.putNextEntry(entry)
                zip.write(data)
                zip.closeEntry()
            }
        }
        return file
    }

    /** Đóng gói thư mục đề (exam.json + media/) như scripts/pack_exam.py. */
    fun pack(dir: File): File {
        val entries = mutableListOf("exam.json" to File(dir, "exam.json").readBytes())
        File(dir, "media").listFiles()?.sortedBy { it.name }?.forEach { entries += "media/${it.name}" to it.readBytes() }
        return make(entries)
    }

    fun manifestOnly(json: ByteArray) = make(listOf("exam.json" to json))
}

/** Dựng đề trong test. */
object Build {
    fun id(n: Int): UUID = UUID.fromString("00000000-0000-4000-8000-%012d".format(n))

    fun opt(letter: Char) = OptionId.of(letter.toString())!!

    fun options(count: Int) = (0 until count).map { ExamOption(OptionId.at(it)!!, "Lựa chọn ${'A' + it}") }

    fun question(
        n: Int,
        type: QuestionType = QuestionType.SINGLE,
        correct: String = "A",
        optionCount: Int = 4,
        text: String = "Câu $n",
        image: String? = null,
        explanation: String? = "Giải thích $n",
    ) = Question(id(n), type, text, image, options(optionCount), correct.map { opt(it) }, explanation)

    fun section(n: Int, vararg questions: Question, title: String = "Phần $n") = ExamSection(id(10_000 + n), title, questions.toList())

    fun exam(
        vararg sections: ExamSection,
        passPercent: Long = 70,
        timeLimitMinutes: Long = 30,
        hideAnswers: Boolean = false,
        title: String = "Đề thử",
    ) = Exam(1, id(99_999), title, null, passPercent, timeLimitMinutes, hideAnswers, null, sections.toList())

    /** Đề `n` câu một đáp án đúng A, chia đều vào `sections` phần. */
    fun simple(n: Int, sections: Int = 1, timeLimitMinutes: Long = 30, hideAnswers: Boolean = false): Exam {
        val per = (n + sections - 1) / sections
        val list = (0 until sections).map { s ->
            section(s, *(0 until per).map { s * per + it }.filter { it < n }.map { question(it) }.toTypedArray())
        }
        return exam(*list.toTypedArray(), timeLimitMinutes = timeLimitMinutes, hideAnswers = hideAnswers)
    }
}
