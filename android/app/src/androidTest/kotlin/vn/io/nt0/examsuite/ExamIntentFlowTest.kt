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
import java.io.InputStream

/**
 * Luồng 2: mở `.exam` từ app khác (Intent VIEW) → Trước khi thi của đề đó → Thi 1 phút → hết giờ (đồng hồ nhanh) sang
 * Rà soát khoá → nộp → Kết quả → Lịch sử thi có lần thi. Rồi mở `.oef` của Open Exam Suite cùng cách → Trước khi thi của
 * đề đã chuyển (plan-oef.md O3).
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
        val file = copy(InstrumentationRegistry.getInstrumentation().context.assets.open("pack-exam-py.exam"), "kien-thuc-chung.exam")
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

        // `.oef` của Open Exam Suite (oracle fixtures/oef): chuyển thành đề rồi mở Trước khi thi như `.exam`.
        val oef = copy(requireNotNull(javaClass.classLoader?.getResourceAsStream("co-ban.oef")), "de-thu.oef")
        Flow.launch(Intent(Intent.ACTION_VIEW, Uri.fromFile(oef))).use {
            compose.waitForTag("candidateName")
            compose.assertShown(OEF_TITLE)
        }
    }

    private fun copy(source: InputStream, name: String): File {
        val file = File(Flow.app.cacheDir, name)
        source.use { input -> file.outputStream().use { input.copyTo(it) } }
        return file
    }

    private companion object {
        const val KIEN_THUC_CHUNG = "Kiến thức chung"
        const val OEF_TITLE = "Đề thử OEF cơ bản"
    }
}
