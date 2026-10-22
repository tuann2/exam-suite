package vn.io.nt0.examsuite.core

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import vn.io.nt0.examsuite.core.Build.opt
import vn.io.nt0.examsuite.core.model.ExamOption
import vn.io.nt0.examsuite.core.model.QuestionType
import vn.io.nt0.examsuite.core.validation.ExamValidator
import vn.io.nt0.examsuite.core.validation.IssueArguments
import vn.io.nt0.examsuite.core.validation.IssueCode
import vn.io.nt0.examsuite.core.validation.IssueLocation
import vn.io.nt0.examsuite.core.validation.IssueSeverity
import java.util.UUID

/** Quy tắc kiểm đề mà fixture chưa phủ (tình huống theo `ExamValidatorTests` bản macOS; fixture ở SharedOracleTest). */
class ValidatorTest {
    private fun codes(exam: vn.io.nt0.examsuite.core.model.Exam, media: Set<String>? = null) = ExamValidator.validate(exam, media).map { it.code }

    @Test
    fun `đề dựng bằng code và hai đề mẫu fixture không có vấn đề nào`() {
        assertEquals(emptyList<IssueCode>(), codes(Build.simple(3, sections = 2)))
        for (name in listOf("kien-thuc-chung", "toi-thieu")) {
            val media = Repo.examDir(name).resolve("media").list()?.map { "media/$it" }?.toSet() ?: emptySet()
            assertEquals(emptyList<IssueCode>(), codes(Repo.exam(name), media), name)
        }
    }

    @Test
    fun `cấp đề, tên trống hay quá 200 code point, mã đề, ngưỡng, thời gian, hướng dẫn, không có phần`() {
        val base = Build.simple(1)
        assertEquals(listOf(IssueCode.TITLE_EMPTY), codes(base.copy(title = " \u3000\n")))
        assertEquals(emptyList<IssueCode>(), codes(base.copy(title = "ệ".repeat(200))))
        assertEquals(listOf(IssueCode.TITLE_TOO_LONG), codes(base.copy(title = "ệ".repeat(67))))
        assertEquals(listOf(IssueCode.CODE_INVALID), codes(base.copy(code = "KTC 01")))
        assertEquals(listOf(IssueCode.CODE_INVALID), codes(base.copy(code = "A".repeat(33))))
        assertEquals(emptyList<IssueCode>(), codes(base.copy(code = "a.B_9-x")))
        assertEquals(listOf(IssueCode.PASS_PERCENT_OUT_OF_RANGE), codes(base.copy(passPercent = 101)))
        assertEquals(listOf(IssueCode.PASS_PERCENT_OUT_OF_RANGE), codes(base.copy(passPercent = -1)))
        assertEquals(listOf(IssueCode.TIME_LIMIT_OUT_OF_RANGE), codes(base.copy(timeLimitMinutes = 0)))
        assertEquals(listOf(IssueCode.TIME_LIMIT_OUT_OF_RANGE), codes(base.copy(timeLimitMinutes = 601)))
        assertEquals(listOf(IssueCode.INSTRUCTIONS_TOO_LONG), codes(base.copy(instructions = "x".repeat(4001))))
        assertEquals(listOf(IssueCode.NO_SECTIONS), codes(base.copy(sections = emptyList())))
    }

    @Test
    fun `cấp phần, tiêu đề trống, phần không có câu, tiêu đề trùng sau khi bỏ khoảng trắng và không phân biệt hoa thường là warning`() {
        val exam = Build.exam(
            Build.section(1, Build.question(1), title = "Mạng"),
            Build.section(2, Build.question(2), title = "  mạng\u00A0"),
            Build.section(3, title = "\t"),
        )
        val issues = ExamValidator.validate(exam)
        assertEquals(listOf(IssueCode.DUPLICATE_SECTION_TITLE, IssueCode.TITLE_EMPTY, IssueCode.SECTION_HAS_NO_QUESTIONS), issues.map { it.code })
        assertEquals(IssueArguments(text = "mạng", firstLocation = IssueLocation.Section(0, exam.sections[0].id)), issues[0].arguments)
        assertEquals(IssueSeverity.WARNING, issues[0].severity)
    }

    @Test
    fun `cấp câu, nội dung, giải thích, số lựa chọn, đáp án đúng lặp, thiếu, ngoài lựa chọn, single nhiều đáp án, multiple một đáp án`() {
        val q = Build.question(1)
        fun one(question: vn.io.nt0.examsuite.core.model.Question) = ExamValidator.validate(Build.exam(Build.section(1, question)))
        assertEquals(listOf(IssueCode.QUESTION_TEXT_EMPTY), one(q.copy(text = "")).map { it.code })
        assertEquals(listOf(IssueCode.QUESTION_TEXT_TOO_LONG), one(q.copy(text = "x".repeat(10_001))).map { it.code })
        assertEquals(listOf(IssueCode.EXPLANATION_TOO_LONG), one(q.copy(explanation = "x".repeat(10_001))).map { it.code })
        assertEquals(listOf(IssueCode.TOO_MANY_OPTIONS), one(q.copy(options = (0 until 27).map { ExamOption(opt('A' + minOf(it, 25)), "x") })).map { it.code }.distinct().take(1))
        assertEquals(listOf(IssueCode.NO_CORRECT_ANSWER), one(q.copy(correct = emptyList())).map { it.code })
        val dup = one(q.copy(type = QuestionType.MULTIPLE, correct = "BABZZ".map { opt(it) }))
        assertEquals(listOf(IssueCode.DUPLICATE_CORRECT_ANSWER, IssueCode.CORRECT_ANSWER_NOT_IN_OPTIONS), dup.map { it.code })
        assertEquals(listOf(opt('B'), opt('Z')), dup[0].arguments.optionIds)
        assertEquals(listOf(opt('Z')), dup[1].arguments.optionIds)
        val single = one(q.copy(correct = "AB".map { opt(it) }))
        assertEquals(listOf(IssueCode.SINGLE_HAS_MULTIPLE_CORRECT), single.map { it.code })
        assertEquals(2L, single[0].arguments.value)
        assertEquals(listOf(IssueCode.MULTIPLE_HAS_SINGLE_CORRECT), one(q.copy(type = QuestionType.MULTIPLE, correct = "AA".map { opt(it) })).map { it.code }.filter { it.severity == IssueSeverity.WARNING })
    }

    @Test
    fun `cấp lựa chọn, sai thứ tự, nội dung trống, quá 4000 code point`() {
        val q = Build.question(1).let { it.copy(options = listOf(ExamOption(opt('A'), "a"), ExamOption(opt('C'), " "), ExamOption(opt('B'), "x".repeat(4001)))) }
        val issues = ExamValidator.validate(Build.exam(Build.section(1, q)))
        assertEquals(listOf(IssueCode.OPTION_ID_OUT_OF_ORDER, IssueCode.OPTION_TEXT_EMPTY, IssueCode.OPTION_ID_OUT_OF_ORDER, IssueCode.OPTION_TEXT_TOO_LONG), issues.map { it.code })
        assertEquals(IssueArguments(optionId = opt('C'), expectedOptionId = opt('B')), issues[0].arguments)
        assertEquals(IssueLocation.OptionAt(0, 0, 1, q.id), issues[0].location)
    }

    @Test
    fun `ảnh, sai dạng chỉ báo imagePathInvalid, không có trong gói là imageNotFound, availableMedia null thì không kiểm tồn tại`() {
        val good = "media/0123456789abcdef.png"
        val withImage = Build.exam(Build.section(1, Build.question(1, image = good)))
        assertEquals(emptyList<IssueCode>(), codes(withImage))
        assertEquals(emptyList<IssueCode>(), codes(withImage, setOf(good)))
        assertEquals(listOf(IssueCode.IMAGE_NOT_FOUND), codes(withImage, emptySet()))
        for (bad in listOf("media/0123456789ABCDEF.png", "media/0123.png", "media/0123456789abcdef.bmp", "media/a/0123456789abcdef.png", "img/0123456789abcdef.png", "$good\n")) {
            assertEquals(listOf(IssueCode.IMAGE_PATH_INVALID), codes(Build.exam(Build.section(1, Build.question(1, image = bad))), emptySet()), bad)
        }
    }

    @Test
    fun `id trùng giữa đề, phần, câu báo nơi xuất hiện trước`() {
        val shared = UUID.fromString("aaaaaaaa-0000-4000-8000-000000000001")
        val exam = Build.exam(Build.section(1, Build.question(1).copy(id = shared)), Build.section(2, Build.question(2).copy(id = shared))).let {
            it.copy(sections = listOf(it.sections[0], it.sections[1].copy(id = it.id)))
        }
        val issues = ExamValidator.validate(exam).filter { it.code == IssueCode.DUPLICATE_ID }
        assertEquals(listOf(IssueLocation.ExamLevel, IssueLocation.QuestionAt(0, 0, shared)), issues.map { it.arguments.firstLocation })
        assertEquals(shared.toString(), issues[1].arguments.text)
    }

    @Test
    fun `thứ tự vấn đề đề, phần, câu, lựa chọn, ổn định giữa các lần gọi, chỉ hai mã là warning`() {
        val exam = Build.exam(Build.section(1, Build.question(1, text = "", correct = "").let { it.copy(options = it.options.take(1)) }), title = "")
        val first = ExamValidator.validate(exam)
        assertEquals(first, ExamValidator.validate(exam))
        assertEquals(listOf(IssueCode.TITLE_EMPTY, IssueCode.QUESTION_TEXT_EMPTY, IssueCode.TOO_FEW_OPTIONS, IssueCode.NO_CORRECT_ANSWER), first.map { it.code })
        assertEquals(setOf(IssueCode.DUPLICATE_SECTION_TITLE, IssueCode.MULTIPLE_HAS_SINGLE_CORRECT), IssueCode.entries.filter { it.severity == IssueSeverity.WARNING }.toSet())
    }

    @Test
    fun `hàm công khai, textLength đếm code point, isValidCode, isValidImagePath khớp cả chuỗi`() {
        assertEquals(1, ExamValidator.textLength("ệ"))
        assertEquals(3, ExamValidator.textLength("ệ"))
        assertEquals(1, ExamValidator.textLength("😀"))
        assertTrue(!ExamValidator.isValidCode("KTC01\n"))
        assertTrue(ExamValidator.isValidImagePath("media/" + "a".repeat(64) + ".heic"))
        assertTrue(!ExamValidator.isValidImagePath("media/" + "a".repeat(65) + ".png"))
    }

    @Test
    fun `tiêu đề phần trùng không phân biệt hoa thường như Swift, Sigma cuối từ đổi thành sigma thường`() {
        val upper = "Α" + Char(0x03A3)
        val lower = "α" + Char(0x03C3)
        val exam = Build.exam(Build.section(1, Build.question(1), title = upper), Build.section(2, Build.question(2), title = lower))
        assertEquals(listOf(IssueCode.DUPLICATE_SECTION_TITLE), ExamValidator.validate(exam).map { it.code })
    }

    @Test
    fun `tiêu đề phần trùng khi chỉ khác dạng chuẩn hoá Unicode NFC và NFD, như Swift`() {
        val nfc = "Caf" + Char(0xE9)
        val nfd = "Cafe" + Char(0x301)
        val exam = Build.exam(Build.section(1, Build.question(1), title = nfc), Build.section(2, Build.question(2), title = nfd))
        assertEquals(listOf(IssueCode.DUPLICATE_SECTION_TITLE), ExamValidator.validate(exam).map { it.code })
    }
}
