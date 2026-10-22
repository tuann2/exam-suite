package vn.io.nt0.examsuite.core

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertThrows
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import vn.io.nt0.examsuite.core.Build.opt
import vn.io.nt0.examsuite.core.model.QuestionType
import vn.io.nt0.examsuite.core.scoring.QuestionOutcome
import vn.io.nt0.examsuite.core.scoring.Scorer
import vn.io.nt0.examsuite.core.scoring.ScoringException
import java.util.UUID

/** Tình huống theo docs/product/scoring.md và danh sách của `ScorerTests` bản macOS. */
class ScorerTest {
    private val single = Build.question(1, correct = "B")
    private val multiple = Build.question(2, QuestionType.MULTIPLE, correct = "CA")
    private fun set(letters: String) = letters.map { opt(it) }.toSet()

    @Test
    fun `score1000 và percent chia lấy phần nguyên, total nhỏ hơn hoặc bằng 0 cho 0`() {
        assertEquals(666, Scorer.score1000(2, 3))
        assertEquals(66, Scorer.percent(2, 3))
        assertEquals(0, Scorer.score1000(0, 0))
        assertEquals(0, Scorer.score1000(3, -1))
        assertEquals(0, Scorer.percent(1, 0))
    }

    @Test
    fun `đậu khi score1000 lớn hơn hoặc bằng passPercent nhân 10, biên đúng ngưỡng`() {
        assertTrue(Scorer.isPassed(700, 70))
        assertTrue(!Scorer.isPassed(699, 70))
        assertTrue(Scorer.isPassed(0, 0))
    }

    @Test
    fun `so bằng score1000 hay percent cho cùng kết luận với mọi total tới 200`() {
        for (total in 1..200) for (correct in 0..total) for (pass in listOf(0, 1, 50, 66, 67, 70, 99, 100)) {
            assertEquals(Scorer.isPassed(Scorer.score1000(correct, total), pass), Scorer.percent(correct, total) >= pass, "$correct/$total @$pass")
        }
    }

    @Test
    fun `single đúng, sai, chọn hai lựa chọn kể cả có đáp án đúng là sai`() {
        assertEquals(QuestionOutcome.CORRECT, Scorer.outcome(single, set("B")))
        assertEquals(QuestionOutcome.INCORRECT, Scorer.outcome(single, set("A")))
        assertEquals(QuestionOutcome.INCORRECT, Scorer.outcome(single, set("AB")))
    }

    @Test
    fun `multiple đủ tập là đúng, không xét thứ tự, thiếu hay thừa một là sai`() {
        assertEquals(QuestionOutcome.CORRECT, Scorer.outcome(multiple, set("AC")))
        assertEquals(QuestionOutcome.INCORRECT, Scorer.outcome(multiple, set("A")))
        assertEquals(QuestionOutcome.INCORRECT, Scorer.outcome(multiple, set("ACD")))
    }

    @Test
    fun `chưa trả lời là null hoặc tập rỗng, id ngoài options là sai`() {
        assertEquals(QuestionOutcome.UNANSWERED, Scorer.outcome(single, null))
        assertEquals(QuestionOutcome.UNANSWERED, Scorer.outcome(single, emptySet()))
        assertEquals(QuestionOutcome.INCORRECT, Scorer.outcome(single, set("Z")))
    }

    @Test
    fun `đề mẫu 4 trên 5 cho 800, 80 phần trăm, đậu với 70, theo phần đúng`() {
        val exam = Repo.exam("kien-thuc-chung")
        val ids = exam.allQuestions.map { it.id }
        val answers = exam.allQuestions.associate { it.id to it.correctSet }.toMutableMap()
        answers[ids[4]] = emptySet()
        val result = Scorer.score(exam, ids, answers)
        assertEquals(listOf(5, 4, 800, 80, true), listOf(result.total, result.correct, result.score1000, result.percent, result.passed))
        assertEquals(listOf(3 to 3, 2 to 1), result.sections.map { it.total to it.correct })
        assertEquals(QuestionOutcome.UNANSWERED, result.outcomes[ids[4]])
    }

    @Test
    fun `biên qua score, 7 trên 10 đậu với 70, 2 trên 3 trượt với 67`() {
        val exam = Build.simple(10)
        val ids = exam.allQuestions.map { it.id }
        val seven = Scorer.score(exam, ids, ids.take(7).associateWith { set("A") })
        assertTrue(seven.passed)
        val six = Scorer.score(exam, ids, ids.take(6).associateWith { set("A") })
        assertTrue(!six.passed)
        val three = Scorer.score(exam.copy(passPercent = 67), ids.take(3), ids.take(2).associateWith { set("A") })
        assertEquals(666 to false, three.score1000 to three.passed)
    }

    @Test
    fun `phiên 0 câu cho 0 điểm, passPercent 0 thì đậu, mọi phần 0 trên 0`() {
        val exam = Build.simple(4, sections = 2)
        val result = Scorer.score(exam.copy(passPercent = 0), emptyList(), emptyMap())
        assertEquals(0, result.score1000)
        assertTrue(result.passed)
        assertEquals(listOf(0, 0), result.sections.map { it.total })
    }

    @Test
    fun `phần không có câu trong phiên vẫn có mặt, tổng các phần bằng tổng phiên, đáp án ngoài phiên bị bỏ`() {
        val exam = Build.simple(4, sections = 2)
        val ids = exam.sections[0].questions.map { it.id }
        val result = Scorer.score(exam, ids, mapOf(exam.sections[1].questions[0].id to set("A"), ids[0] to set("A")))
        assertEquals(listOf(2 to 1, 0 to 0), result.sections.map { it.total to it.correct })
        assertEquals(1, result.correct)
    }

    @Test
    fun `câu sai và chưa làm giữ thứ tự phiên`() {
        val exam = Build.simple(4)
        val ids = exam.allQuestions.map { it.id }.reversed()
        val result = Scorer.score(exam, ids, mapOf(ids[1] to set("A")))
        assertEquals(listOf(ids[0], ids[2], ids[3]), result.incorrectOrUnansweredIds)
    }

    @Test
    fun `id lạ ném UnknownQuestion, id lặp ném DuplicateQuestion`() {
        val exam = Build.simple(2)
        val stranger = UUID.randomUUID()
        assertThrows(ScoringException.UnknownQuestion::class.java) { Scorer.score(exam, listOf(stranger), emptyMap()) }
        val id = exam.allQuestions[0].id
        assertThrows(ScoringException.DuplicateQuestion::class.java) { Scorer.score(exam, listOf(id, id), emptyMap()) }
    }
}
