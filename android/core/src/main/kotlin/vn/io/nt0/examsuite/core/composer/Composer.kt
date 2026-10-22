package vn.io.nt0.examsuite.core.composer

import vn.io.nt0.examsuite.core.model.Exam
import vn.io.nt0.examsuite.core.model.OptionId
import vn.io.nt0.examsuite.core.model.Question
import java.util.UUID

/**
 * SplitMix64 tự cài đặt (docs/product/scoring.md, mục "Bộ sinh số ngẫu nhiên và thứ tự tiêu thụ"); cùng chuỗi số với
 * `SeededGenerator` của bản macOS (vector: fixtures/vectors/composer.json). Mọi phép tính modulo 2^64 trên `ULong`.
 */
class SeededGenerator(seed: ULong) {
    private var state: ULong = seed

    fun next(): ULong {
        state += GAMMA
        var z = state
        z = (z xor (z shr 30)) * MIX1
        z = (z xor (z shr 27)) * MIX2
        return z xor (z shr 31)
    }

    /** Số nguyên đều trong `0 until bound` bằng rejection sampling: `threshold = 2^64 mod bound`. */
    fun nextInt(bound: Long): Long {
        require(bound > 0) { "bound phải > 0" }
        val b = bound.toULong()
        val threshold = (0uL - b) % b
        while (true) {
            val r = next()
            if (r >= threshold) return (r % b).toLong()
        }
    }

    /** Fisher–Yates (Durstenfeld): `i` từ `size - 1` xuống 1, `j = nextInt(i + 1)`. 0–1 phần tử không tiêu thụ số. */
    fun <T> shuffle(items: MutableList<T>) {
        if (items.size <= 1) return
        for (i in items.size - 1 downTo 1) {
            val j = nextInt((i + 1).toLong()).toInt()
            if (i != j) items[i] = items.set(j, items[i])
        }
    }

    private companion object {
        const val GAMMA: ULong = 0x9E3779B97F4A7C15uL
        const val MIX1: ULong = 0xBF58476D1CE4E5B9uL
        const val MIX2: ULong = 0x94D049BB133111EBuL
    }
}

/** Cách chọn câu cho một phiên (màn Trước khi thi). */
sealed interface QuestionSelection {
    data object All : QuestionSelection

    /** Chỉ các phần này, giữ thứ tự phần và câu trong file. */
    data class Sections(val ids: Set<UUID>) : QuestionSelection

    /** N câu ngẫu nhiên trên toàn đề. */
    data class Random(val count: Int) : QuestionSelection

    /** "Luyện lại câu sai": đúng các câu này theo thứ tự truyền vào; trùng id giữ lần đầu. */
    data class Questions(val ids: List<UUID>) : QuestionSelection
}

/** Tuỳ chọn tạo đề; cùng đề + cùng tuỳ chọn (kể cả seed 64 bit không dấu) ⇒ cùng `ExamPaper`. */
data class CompositionOptions(
    val selection: QuestionSelection = QuestionSelection.All,
    val shuffleQuestions: Boolean = false,
    val shuffleOptions: Boolean = false,
    val seed: ULong,
)

/** Một câu của đề đã tạo: phần gốc (chấm theo phần) và thứ tự **hiển thị** các id lựa chọn gốc. */
data class PaperItem(val questionId: UUID, val sectionId: UUID, val optionOrder: List<OptionId>)

data class ExamPaper(val examId: UUID, val options: CompositionOptions, val items: List<PaperItem>) {
    val questionIds: List<UUID> get() = items.map { it.questionId }
}

sealed class CompositionException(message: String) : Exception(message) {
    data object NoQuestions : CompositionException("lựa chọn ra 0 câu")

    data class CountOutOfRange(val requested: Int, val available: Int) : CompositionException("N=$requested ngoài 1…$available")

    data class UnknownSection(val id: UUID) : CompositionException("phần $id không thuộc đề")

    data class UnknownQuestion(val id: UUID) : CompositionException("câu $id không thuộc đề")
}

/**
 * Chọn câu và xáo (scoring.md). Một `SeededGenerator(seed)` cho cả lần tạo, tiêu thụ theo thứ tự: (1) `Random`:
 * Fisher–Yates toàn bộ câu, lấy N câu đầu; (2) xáo câu; (3) xáo đáp án từng câu theo thứ tự cuối. Bước không bật không
 * tiêu thụ số. Đổi thứ tự này làm seed đã lưu ra đề khác (rủi ro cao).
 */
object ExamComposer {
    fun compose(exam: Exam, options: CompositionOptions): ExamPaper {
        val generator = SeededGenerator(options.seed)
        val picked = select(exam, options.selection, generator).toMutableList()
        if (picked.isEmpty()) throw CompositionException.NoQuestions
        if (options.shuffleQuestions) generator.shuffle(picked)
        val items = picked.map { (question, sectionId) ->
            val order = question.options.map { it.id }.toMutableList()
            if (options.shuffleOptions) generator.shuffle(order)
            PaperItem(question.id, sectionId, order)
        }
        return ExamPaper(exam.id, options, items)
    }

    private fun entries(exam: Exam, sections: List<vn.io.nt0.examsuite.core.model.ExamSection>): List<Pair<Question, UUID>> =
        sections.flatMap { section -> section.questions.map { it to section.id } }

    private fun select(exam: Exam, selection: QuestionSelection, generator: SeededGenerator): List<Pair<Question, UUID>> =
        when (selection) {
            QuestionSelection.All -> entries(exam, exam.sections)
            is QuestionSelection.Sections -> {
                val known = exam.sections.map { it.id }.toSet()
                // Báo id lạ nhỏ nhất theo chuỗi để lỗi ổn định (cùng bản macOS).
                selection.ids.filter { it !in known }.minByOrNull { it.toString() }?.let { throw CompositionException.UnknownSection(it) }
                entries(exam, exam.sections.filter { it.id in selection.ids })
            }
            is QuestionSelection.Random -> {
                val all = entries(exam, exam.sections).toMutableList()
                if (selection.count < 1 || selection.count > all.size) {
                    throw CompositionException.CountOutOfRange(selection.count, all.size)
                }
                generator.shuffle(all)
                all.take(selection.count)
            }
            is QuestionSelection.Questions -> {
                val lookup = LinkedHashMap<UUID, Pair<Question, UUID>>()
                for (entry in entries(exam, exam.sections)) if (entry.first.id !in lookup) lookup[entry.first.id] = entry
                val seen = HashSet<UUID>()
                selection.ids.mapNotNull { id ->
                    val entry = lookup[id] ?: throw CompositionException.UnknownQuestion(id)
                    if (seen.add(id)) entry else null
                }
            }
        }
}
