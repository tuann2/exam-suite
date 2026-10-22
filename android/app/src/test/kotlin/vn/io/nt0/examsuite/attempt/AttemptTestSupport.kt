package vn.io.nt0.examsuite.attempt

import vn.io.nt0.examsuite.core.composer.CompositionOptions
import vn.io.nt0.examsuite.core.composer.ExamComposer
import vn.io.nt0.examsuite.core.composer.QuestionSelection
import vn.io.nt0.examsuite.core.model.Exam
import vn.io.nt0.examsuite.core.model.ExamOption
import vn.io.nt0.examsuite.core.model.ExamSection
import vn.io.nt0.examsuite.core.model.OptionId
import vn.io.nt0.examsuite.core.model.Question
import vn.io.nt0.examsuite.core.model.QuestionType
import vn.io.nt0.examsuite.core.session.ExamSession
import vn.io.nt0.examsuite.core.session.SessionClock
import vn.io.nt0.examsuite.core.session.SessionMode
import java.time.Instant
import java.util.UUID

/** Đồng hồ tiêm cho test: thời gian chỉ chạy khi gọi `advance`. */
class FakeClock(var uptime: Double = 1_000.0) : SessionClock {
    override fun now(): Instant = Instant.ofEpochSecond(1_792_000_000L + uptime.toLong())

    override fun uptimeSeconds(): Double = uptime

    fun advance(seconds: Double) {
        uptime += seconds
    }
}

fun uuid(n: Int): UUID = UUID.fromString("00000000-0000-4000-8000-%012d".format(n))

fun letter(c: Char): OptionId = OptionId.of(c.toString())!!

/**
 * Đề thử: mỗi phần `sizes[i]` câu, câu `single` có 4 lựa chọn A–D, đáp án đúng A; câu thứ `multipleAt` (nếu có) là
 * `multiple` với đáp án đúng A, C. Id câu: 100 + số thứ tự trong đề; id phần: 1, 2…
 */
fun testExam(
    vararg sizes: Int,
    hideAnswers: Boolean = false,
    multipleAt: Int? = null,
    sectionTitles: List<String> = sizes.indices.map { "Phần ${it + 1}" },
    timeLimitMinutes: Long = 30,
): Exam {
    var n = 0
    val sections = sizes.mapIndexed { s, size ->
        ExamSection(
            id = uuid(s + 1),
            title = sectionTitles[s],
            questions = List(size) {
                n += 1
                val multiple = multipleAt == n
                Question(
                    id = uuid(100 + n),
                    type = if (multiple) QuestionType.MULTIPLE else QuestionType.SINGLE,
                    text = "Câu hỏi số $n\nDòng hai",
                    options = "ABCD".map { ExamOption(letter(it), "Lựa chọn $it của câu $n") },
                    correct = if (multiple) listOf(letter('A'), letter('C')) else listOf(letter('A')),
                    explanation = "Giải thích câu $n",
                )
            },
        )
    }
    return Exam(
        formatVersion = 1, id = uuid(1), title = "Đề thử", code = "DT-01", passPercent = 70, timeLimitMinutes = timeLimitMinutes,
        hideAnswers = hideAnswers, sections = sections,
    )
}

fun startSession(
    exam: Exam,
    mode: SessionMode,
    clock: FakeClock,
    options: CompositionOptions = CompositionOptions(QuestionSelection.All, seed = 7uL),
    timeLimitMinutes: Int? = null,
): ExamSession = ExamSession.start(exam, ExamComposer.compose(exam, options), mode, timeLimitMinutes, "Nguyễn Văn A", clock)
