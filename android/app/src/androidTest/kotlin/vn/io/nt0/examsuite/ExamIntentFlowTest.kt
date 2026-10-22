package vn.io.nt0.examsuite

import android.content.Intent
import android.net.Uri
import androidx.compose.ui.test.junit4.accessibility.enableAccessibilityChecks
import androidx.compose.ui.test.junit4.v2.createEmptyComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextReplacement
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

/**
 * Luồng 2: mở `.exam` từ app khác (Intent VIEW) → Trước khi thi của đề đó → Thi 1 phút → hết giờ (đồng hồ nhanh) sang
 * Rà soát khoá → nộp → Kết quả → Lịch sử thi có lần thi.
 */
@RunWith(AndroidJUnit4::class)
class ExamIntentFlowTest {
    @get:Rule
    val compose = createEmptyComposeRule()

    @Before
    fun enableChecks() {
        compose.enableAccessibilityChecks()
    }

    @Test
    fun openExamFromAnotherAppThenTimeUp() {
        Flow.app.services.clock = FastClock(scale = 30.0)
        val file = File(Flow.app.cacheDir, "kien-thuc-chung.exam")
        InstrumentationRegistry.getInstrumentation().context.assets.open("pack-exam-py.exam").use { input ->
            file.outputStream().use { input.copyTo(it) }
        }
        Flow.launch(Intent(Intent.ACTION_VIEW, Uri.fromFile(file))).use {
            compose.enterName("Trần Thị B") // Trước khi thi mở ngay sau khi thêm đề
            compose.clickTag("mode-EXAM")
            compose.waitForTag("timeLimit")
            compose.onNodeWithTag("timeLimit").performTextReplacement("1")
            compose.clickTag("start")

            compose.waitForText(Flow.str(R.string.time_up_banner), timeoutMillis = 30_000)
            compose.assertShown(Flow.str(R.string.time_up_locked))
            compose.tap(Flow.str(R.string.submit))
            compose.clickTag("confirmSubmit")
            compose.clickText(Flow.str(R.string.back_to_library))

            compose.waitForText(KIEN_THUC_CHUNG)
            compose.onNodeWithContentDescription(Flow.str(R.string.history)).performClick()
            compose.assertShown("Trần Thị B")
        }
    }

    private companion object {
        const val KIEN_THUC_CHUNG = "Kiến thức chung"
    }
}
