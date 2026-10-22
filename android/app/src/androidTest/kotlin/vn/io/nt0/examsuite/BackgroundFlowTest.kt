package vn.io.nt0.examsuite

import androidx.compose.ui.test.junit4.accessibility.enableAccessibilityChecks
import androidx.compose.ui.test.junit4.v2.createEmptyComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.performClick
import androidx.lifecycle.Lifecycle
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Luồng 3 (mobile.md): Quay lại hỏi Bỏ bài; xuống nền thì tạm dừng; app bị dừng ở nền rồi mở lại thì về đúng câu ở trạng
 * thái Tạm dừng; Bỏ bài về Thư viện.
 */
@RunWith(AndroidJUnit4::class)
class BackgroundFlowTest {
    @get:Rule
    val compose = createEmptyComposeRule()

    @Before
    fun enableChecks() {
        compose.enableAccessibilityChecks()
    }

    @Test
    fun backAsksBackgroundPausesAndReopenResumes() {
        val second = Flow.str(R.string.question_number, "2", "23")
        val first = Flow.launch()
        compose.clickText(Flow.SAMPLE_SECURITY)
        compose.enterName("Lê Văn C")
        compose.clickTag("start")
        compose.clickTag("option-0")
        compose.onNodeWithContentDescription(Flow.str(R.string.next_question)).performClick()
        compose.assertShown(second)

        first.onActivity { it.onBackPressedDispatcher.onBackPressed() }
        compose.assertShown(Flow.str(R.string.discard_title))
        compose.clickTag("keepWorking")
        compose.assertShown(second)

        first.moveToState(Lifecycle.State.CREATED) // xuống nền: tạm dừng, lưu phiên dở
        first.moveToState(Lifecycle.State.RESUMED)
        compose.assertShown(Flow.str(R.string.paused_background))
        compose.tap(Flow.str(R.string.resume))
        compose.assertShown(second)

        first.moveToState(Lifecycle.State.CREATED)
        first.close() // hệ điều hành dừng app khi đang ở nền

        Flow.launch().use { again ->
            compose.assertShown(Flow.str(R.string.paused_background))
            compose.tap(Flow.str(R.string.resume))
            compose.assertShown(second)
            again.onActivity { it.onBackPressedDispatcher.onBackPressed() }
            compose.clickTag("confirmDiscard")
            compose.assertShown(Flow.SAMPLE_SECURITY)
        }
    }
}
