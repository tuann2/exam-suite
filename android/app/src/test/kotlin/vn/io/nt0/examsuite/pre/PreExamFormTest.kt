package vn.io.nt0.examsuite.pre

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import vn.io.nt0.examsuite.attempt.NextAttempt
import vn.io.nt0.examsuite.attempt.testExam
import vn.io.nt0.examsuite.attempt.uuid
import vn.io.nt0.examsuite.core.composer.CompositionOptions
import vn.io.nt0.examsuite.core.composer.QuestionSelection
import vn.io.nt0.examsuite.core.session.SessionMode

/** Trước khi thi (exam-taking.md): mặc định, lý do khoá theo thứ tự, Làm lại và Luyện lại câu sai điền sẵn. */
class PreExamFormTest {
    private val exam = testExam(2, 3) // phần 1: câu 101–102, phần 2: câu 103–105; 30 phút, đậu 70%

    @Test
    fun freshFormSelectsEverythingWithExamDefaults() {
        val form = PreExamForm.fresh(exam, SessionMode.EXAM, "An")
        assertEquals(SelectionKind.ALL, form.kind)
        assertEquals(setOf(uuid(1), uuid(2)), form.selectedSections)
        assertEquals("5", form.randomCountText)
        assertEquals("30", form.timeLimitText)
        assertFalse(form.shuffleQuestions || form.shuffleOptions)
        assertEquals(5, form.questionCount)
        assertTrue(form.canStart)
        assertEquals(CompositionOptions(QuestionSelection.All, seed = 9uL), form.options(9uL))
        assertEquals(30, form.sessionTimeLimit())
    }

    @Test
    fun hiddenAnswersForceExamAndRefusePractice() {
        val hidden = testExam(2, hideAnswers = true)
        val form = PreExamForm.fresh(hidden, SessionMode.PRACTICE, "An")
        assertEquals(SessionMode.EXAM, form.mode)
        assertEquals(SessionMode.EXAM, form.withMode(SessionMode.PRACTICE).mode)
        // Luyện lại câu sai của đề ẩn đáp án (không có từ giao diện) vẫn bị khoá kèm lý do.
        val forced = form.copy(mode = SessionMode.PRACTICE)
        assertEquals(PreExamIssue.PracticeUnavailable, forced.issues.first())
    }

    @Test
    fun nameIsTrimmedAndRequired() {
        val form = PreExamForm.fresh(exam, SessionMode.PRACTICE, "  Bình \n")
        assertEquals("Bình", form.trimmedName)
        assertEquals(listOf(PreExamIssue.EmptyCandidateName), form.copy(candidateName = "   ").issues)
    }

    @Test
    fun sectionSelectionCountsAndBlocksWhenEmpty() {
        val form = PreExamForm.fresh(exam, SessionMode.PRACTICE, "An").copy(kind = SelectionKind.SECTIONS)
        val second = form.withSection(uuid(1), false)
        assertEquals(3, second.questionCount)
        assertEquals(QuestionSelection.Sections(setOf(uuid(2))), second.options(1uL).selection)
        assertEquals(listOf(PreExamIssue.NoSectionSelected), form.deselectAllSections().issues)
        assertEquals(5, form.deselectAllSections().selectAllSections().questionCount)
        assertEquals(form, form.withSection(uuid(99), false)) // phần lạ: bỏ qua
        val withEmpty = testExam(0, 2)
        val onlyEmpty = PreExamForm.fresh(withEmpty, SessionMode.PRACTICE, "An").copy(kind = SelectionKind.SECTIONS).withSection(uuid(2), false)
        assertEquals(listOf(PreExamIssue.SelectedSectionsEmpty), onlyEmpty.issues)
    }

    @Test
    fun randomCountMustBeWithinOneToTotal() {
        val form = PreExamForm.fresh(exam, SessionMode.PRACTICE, "An").copy(kind = SelectionKind.RANDOM)
        assertTrue(form.copy(randomCountText = "1").canStart)
        assertEquals(QuestionSelection.Random(3), form.copy(randomCountText = "3").options(1uL).selection)
        for (bad in listOf("0", "6", "", "abc")) {
            assertEquals(bad, listOf(PreExamIssue.RandomCountOutOfRange(5)), form.copy(randomCountText = bad).issues)
        }
        // N câu ngẫu nhiên: dòng tóm tắt đếm đúng N đã nhập, kể cả ngoài khoảng.
        assertEquals(7, form.copy(randomCountText = "7").questionCount)
    }

    @Test
    fun timeLimitCheckedOnlyInExam() {
        val exam1 = PreExamForm.fresh(exam, SessionMode.EXAM, "An")
        assertEquals(listOf(PreExamIssue.TimeLimitOutOfRange), exam1.copy(timeLimitText = "601").issues)
        assertEquals(listOf(PreExamIssue.TimeLimitOutOfRange), exam1.copy(timeLimitText = "0").issues)
        assertTrue(exam1.copy(timeLimitText = "600").canStart)
        val practice = exam1.withMode(SessionMode.PRACTICE).copy(timeLimitText = "0")
        assertTrue(practice.canStart)
        assertNull(practice.sessionTimeLimit())
    }

    @Test
    fun issuesFollowDocumentedOrder() {
        val form = PreExamForm.fresh(exam, SessionMode.EXAM, "").copy(kind = SelectionKind.RANDOM, randomCountText = "9", timeLimitText = "0")
        assertEquals(
            listOf(PreExamIssue.RandomCountOutOfRange(5), PreExamIssue.TimeLimitOutOfRange, PreExamIssue.EmptyCandidateName),
            form.issues,
        )
    }

    @Test
    fun retakePrefillsPreviousChoices() {
        val options = CompositionOptions(QuestionSelection.Sections(setOf(uuid(2), uuid(77))), shuffleQuestions = true, shuffleOptions = true, seed = 5uL)
        val form = PreExamForm.from(exam, NextAttempt(uuid(1), SessionMode.EXAM, options, 45, "An", false), "Bình")
        assertEquals(SessionMode.EXAM, form.mode)
        assertEquals(SelectionKind.SECTIONS, form.kind)
        assertEquals(setOf(uuid(2)), form.selectedSections) // phần không còn trong đề bị bỏ
        assertTrue(form.shuffleQuestions && form.shuffleOptions)
        assertEquals("45", form.timeLimitText)
        assertEquals("Bình", form.candidateName)
        val random = PreExamForm.from(exam, NextAttempt(uuid(1), SessionMode.PRACTICE, options.copy(selection = QuestionSelection.Random(2)), null, "An", false), "An")
        assertEquals("2", random.randomCountText)
        assertEquals("30", random.timeLimitText)
    }

    @Test
    fun practiceIncorrectLocksOptionsAndKeepsKnownQuestionsInOrder() {
        val ids = listOf(uuid(104), uuid(999), uuid(102), uuid(104))
        val next = NextAttempt(uuid(1), SessionMode.PRACTICE, CompositionOptions(QuestionSelection.Questions(ids), seed = 1uL), null, "An", true)
        val form = PreExamForm.from(exam, next, "An")
        assertTrue(form.isPracticeIncorrect)
        assertFalse(form.canChangeOptions)
        assertEquals(SessionMode.PRACTICE, form.withMode(SessionMode.EXAM).mode)
        assertEquals(2, form.questionCount)
        assertEquals(CompositionOptions(QuestionSelection.Questions(listOf(uuid(104), uuid(102))), seed = 3uL), form.options(3uL))
        val gone = PreExamForm.from(exam, next.copy(options = next.options.copy(selection = QuestionSelection.Questions(listOf(uuid(999))))), "An")
        assertEquals(listOf(PreExamIssue.NoQuestionsToPractice), gone.issues)
    }

    @Test
    fun startCheckRunsAgainstReReadExam() {
        val form = PreExamForm.fresh(exam, SessionMode.PRACTICE, "An").copy(kind = SelectionKind.SECTIONS).withSection(uuid(2), false)
        // File đổi: phần 1 không còn.
        val changed = testExam(2, 3).let { it.copy(sections = it.sections.drop(1)) }
        assertEquals(listOf(PreExamIssue.NoSectionSelected), form.withExam(changed).issues)
    }
}
