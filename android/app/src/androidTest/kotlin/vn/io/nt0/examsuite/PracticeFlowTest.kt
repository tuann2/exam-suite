package vn.io.nt0.examsuite

import androidx.compose.ui.test.junit4.accessibility.enableAccessibilityChecks
import androidx.compose.ui.test.junit4.v2.createEmptyComposeRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/** Luồng 1 (overview.md, plan-android-v1.md A3a): đề mẫu → Luyện tập → Kiểm tra đáp án → nộp → Kết quả → Xem lại → Luyện lại câu sai. */
@RunWith(AndroidJUnit4::class)
class PracticeFlowTest {
    @get:Rule
    val compose = createEmptyComposeRule()

    @Before
    fun enableChecks() {
        compose.enableAccessibilityChecks()
    }

    @Test
    fun practiceThenReviewThenPracticeIncorrect() {
        Flow.launch().use {
            compose.clickText(Flow.SAMPLE_INTRO) // lần đầu: chế độ Luyện tập
            compose.enterName("Nguyễn Văn A")
            compose.clickTag("start")
            compose.assertShown(Flow.str(R.string.question_number, "1", "12"))

            compose.clickTag("option-1") // sai: đáp án đúng là A
            compose.clickText(Flow.str(R.string.check_answer))
            compose.assertShown(Flow.str(R.string.check_incorrect))

            compose.tap(Flow.str(R.string.review_and_submit))
            compose.tap(Flow.str(R.string.submit))
            compose.clickTag("confirmSubmit") // còn 11 câu chưa làm
            compose.assertShown(Flow.str(R.string.results_title))

            compose.clickText(Flow.str(R.string.review_answers))
            compose.assertShown(Flow.str(R.string.filter_with_count, Flow.str(R.string.filter_all), "12"))
            compose.tap(Flow.str(R.string.practice_incorrect))

            // Trước khi thi của Luyện lại câu sai: tên nhớ từ lần trước, chỉ đổi được tên.
            compose.assertShown(Flow.app.resources.getQuantityString(R.plurals.practice_incorrect_summary, 12, "12"))
            compose.clickTag("start")
            compose.assertShown(Flow.str(R.string.question_number, "1", "12"))
        }
    }
}
