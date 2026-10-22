package vn.io.nt0.examsuite.core

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNotEquals
import org.junit.jupiter.api.Assertions.assertThrows
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import vn.io.nt0.examsuite.core.composer.CompositionException
import vn.io.nt0.examsuite.core.composer.CompositionOptions
import vn.io.nt0.examsuite.core.composer.ExamComposer
import vn.io.nt0.examsuite.core.composer.QuestionSelection
import vn.io.nt0.examsuite.core.composer.SeededGenerator
import java.util.UUID

/** Tình huống không phải vector của `ExamComposerTests` bản macOS (vector ở SharedOracleTest). */
class ComposerTest {
    private val sample = Repo.exam("kien-thuc-chung")
    private val physics = sample.sections[0].id
    private val math = sample.sections[1].id
    private val q = sample.allQuestions.map { it.id }

    @Test
    fun `nextInt luôn trong khoảng, kể cả cận Long MAX`() {
        for (bound in listOf(1L, 2L, 3L, 7L, 1_000_003L, Long.MAX_VALUE)) {
            val g = SeededGenerator(bound.toULong())
            repeat(2_000) { val v = g.nextInt(bound); assertTrue(v in 0 until bound) }
        }
    }

    @Test
    fun `nextInt phân phối đều (kiểm thô)`() {
        val g = SeededGenerator(2026uL)
        val counts = IntArray(6)
        repeat(60_000) { counts[g.nextInt(6).toInt()]++ }
        counts.forEach { assertTrue(kotlin.math.abs(it - 10_000) < 500, counts.contentToString()) }
    }

    @Test
    fun `tất cả câu theo thứ tự file, nhớ phần gốc, seed không ảnh hưởng khi không xáo`() {
        val a = ExamComposer.compose(sample, CompositionOptions(seed = 1uL))
        val b = ExamComposer.compose(sample, CompositionOptions(seed = 2uL))
        assertEquals(q, a.questionIds)
        assertEquals(listOf(physics, physics, physics, math, math), a.items.map { it.sectionId })
        assertEquals(listOf("ABCD", "ABCD", "ABC", "ABC", "ABCDE"), a.items.map { it.optionOrder.joinToString("") })
        assertEquals(a.items, b.items)
    }

    @Test
    fun `theo phần giữ thứ tự file dù tập không có thứ tự`() {
        assertEquals(q.drop(3), ExamComposer.compose(sample, CompositionOptions(QuestionSelection.Sections(setOf(math)), seed = 0uL)).questionIds)
        assertEquals(q, ExamComposer.compose(sample, CompositionOptions(QuestionSelection.Sections(setOf(math, physics)), seed = 0uL)).questionIds)
    }

    @Test
    fun `chọn ra 0 câu thì NoQuestions`() {
        assertThrows(CompositionException.NoQuestions::class.java) { ExamComposer.compose(sample, CompositionOptions(QuestionSelection.Sections(emptySet()), seed = 0uL)) }
        val empty = Build.exam(Build.section(1))
        assertThrows(CompositionException.NoQuestions::class.java) { ExamComposer.compose(empty, CompositionOptions(seed = 0uL)) }
        assertThrows(CompositionException.NoQuestions::class.java) { ExamComposer.compose(sample, CompositionOptions(QuestionSelection.Questions(emptyList()), seed = 0uL)) }
    }

    @Test
    fun `phần lạ báo id nhỏ nhất theo chuỗi`() {
        val a = UUID.fromString("ffffffff-0000-4000-8000-000000000000")
        val b = UUID.fromString("00000000-0000-4000-8000-0000000000aa")
        val e = assertThrows(CompositionException.UnknownSection::class.java) {
            ExamComposer.compose(sample, CompositionOptions(QuestionSelection.Sections(setOf(a, b, math)), seed = 0uL))
        }
        assertEquals(b, e.id)
    }

    @Test
    fun `ngẫu nhiên đúng N câu không trùng, N ngoài 1 tới tổng thì CountOutOfRange, đề rỗng available 0`() {
        val paper = ExamComposer.compose(sample, CompositionOptions(QuestionSelection.Random(3), seed = 9uL))
        assertEquals(3, paper.questionIds.toSet().size)
        assertEquals(q.toSet(), ExamComposer.compose(sample, CompositionOptions(QuestionSelection.Random(5), seed = 9uL)).questionIds.toSet())
        for (n in listOf(0, -1, 6, 100)) {
            assertEquals(CompositionException.CountOutOfRange(n, 5), assertThrows(CompositionException.CountOutOfRange::class.java) {
                ExamComposer.compose(sample, CompositionOptions(QuestionSelection.Random(n), seed = 42uL))
            })
        }
        assertEquals(CompositionException.CountOutOfRange(1, 0), assertThrows(CompositionException.CountOutOfRange::class.java) {
            ExamComposer.compose(Build.exam(Build.section(1)), CompositionOptions(QuestionSelection.Random(1), seed = 0uL))
        })
    }

    @Test
    fun `cùng tuỳ chọn và seed thì cùng đề, khác seed thường khác, xáo giữ đủ tập câu và lựa chọn`() {
        val big = Build.simple(2_000, sections = 10)
        for (selection in listOf(QuestionSelection.All, QuestionSelection.Random(50))) {
            val o = CompositionOptions(selection, shuffleQuestions = true, shuffleOptions = true, seed = 77uL)
            assertEquals(ExamComposer.compose(big, o), ExamComposer.compose(big, o))
            assertNotEquals(ExamComposer.compose(big, o).items, ExamComposer.compose(big, o.copy(seed = 78uL)).items)
        }
        val shuffled = ExamComposer.compose(big, CompositionOptions(shuffleQuestions = true, shuffleOptions = true, seed = 5uL))
        assertEquals(big.allQuestions.map { it.id }.toSet(), shuffled.questionIds.toSet())
        val sectionOf = big.sections.flatMap { s -> s.questions.map { it.id to s.id } }.toMap()
        shuffled.items.forEach { assertEquals(sectionOf[it.questionId], it.sectionId); assertEquals(4, it.optionOrder.toSet().size) }
    }

    @Test
    fun `seed 64 bit đủ dải không dấu`() {
        val o = CompositionOptions(QuestionSelection.Random(3), shuffleOptions = true, seed = ULong.MAX_VALUE)
        assertEquals(ExamComposer.compose(sample, o), ExamComposer.compose(sample, o))
    }

    @Test
    fun `luyện lại câu sai, đúng các câu theo thứ tự truyền vào, trùng giữ lần đầu, câu lạ thì UnknownQuestion`() {
        val paper = ExamComposer.compose(sample, CompositionOptions(QuestionSelection.Questions(listOf(q[4], q[0], q[2])), seed = 0uL))
        assertEquals(listOf(q[4], q[0], q[2]), paper.questionIds)
        assertEquals(listOf(math, physics, physics), paper.items.map { it.sectionId })
        assertEquals(listOf(q[1], q[3], q[0]), ExamComposer.compose(sample, CompositionOptions(QuestionSelection.Questions(listOf(q[1], q[3], q[1], q[3], q[0])), seed = 0uL)).questionIds)
        val stranger = UUID.randomUUID()
        assertEquals(stranger, assertThrows(CompositionException.UnknownQuestion::class.java) {
            ExamComposer.compose(sample, CompositionOptions(QuestionSelection.Questions(listOf(q[0], stranger)), seed = 0uL))
        }.id)
    }
}
