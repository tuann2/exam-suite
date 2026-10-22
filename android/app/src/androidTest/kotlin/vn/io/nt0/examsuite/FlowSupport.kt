package vn.io.nt0.examsuite

import android.content.Intent
import android.os.SystemClock
import androidx.annotation.StringRes
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.test.ComposeTimeoutException
import androidx.compose.ui.test.SemanticsNodeInteraction
import androidx.compose.ui.test.isRoot
import androidx.compose.ui.test.printToLog
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.ComposeTestRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextReplacement
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import vn.io.nt0.examsuite.app.ExamSuiteApplication
import vn.io.nt0.examsuite.core.session.SessionClock
import java.time.Instant

/** Hạ tầng chung của ba luồng Compose (plan-android-v1.md Phần 4): mỗi test một lần mở app, dữ liệu app xoá trước mỗi test. */
object Flow {
    val app: ExamSuiteApplication get() = ApplicationProvider.getApplicationContext()

    fun str(@StringRes id: Int, vararg args: Any): String = app.getString(id, *args)

    fun launch(intent: Intent? = null): ActivityScenario<MainActivity> =
        if (intent == null) ActivityScenario.launch(MainActivity::class.java) else ActivityScenario.launch(intent.setClass(app, MainActivity::class.java))

    const val SAMPLE_INTRO = "Làm quen với Exam Suite"
    const val SAMPLE_SECURITY = "An toàn thông tin cơ bản"
}

/** Đồng hồ nhanh `scale` lần, tiêm qua `AppServices.clock` trong cùng tiến trình (không cần tham số khởi chạy). */
class FastClock(private val scale: Double) : SessionClock {
    private val origin = SystemClock.uptimeMillis() / 1000.0

    override fun now(): Instant = Instant.now()

    override fun uptimeSeconds(): Double = origin + (SystemClock.uptimeMillis() / 1000.0 - origin) * scale
}

fun ComposeTestRule.waitForText(text: String, timeoutMillis: Long = 15_000) = waitOrDump("text \"$text\"", timeoutMillis) {
    onAllNodesWithText(text, substring = true).fetchSemanticsNodes().isNotEmpty()
}

fun ComposeTestRule.waitForTag(tag: String, timeoutMillis: Long = 15_000) = waitOrDump("tag $tag", timeoutMillis) {
    onAllNodesWithTag(tag).fetchSemanticsNodes().isNotEmpty()
}

/** Chờ điều kiện; quá hạn thì ghi cây giao diện vào logcat (thẻ FLOW) để biết màn đang hiện gì. */
private fun ComposeTestRule.waitOrDump(what: String, timeoutMillis: Long, condition: () -> Boolean) {
    try {
        waitUntil(timeoutMillis, condition)
    } catch (e: ComposeTimeoutException) {
        onAllNodes(isRoot()).printToLog("FLOW")
        throw AssertionError("không thấy $what sau $timeoutMillis ms (cây giao diện: logcat thẻ FLOW)", e)
    }
}

fun ComposeTestRule.clickText(text: String) {
    waitForText(text)
    onNodeWithText(text).scrollIfNeeded().performClick()
}

fun ComposeTestRule.clickTag(tag: String) {
    waitForTag(tag)
    onNodeWithTag(tag).scrollIfNeeded().performClick()
}

/** Cuộn tới phần tử khi nó nằm trong vùng cuộn (nội dung câu, Trước khi thi); hộp thoại, thanh dưới thì không. */
private fun SemanticsNodeInteraction.scrollIfNeeded(): SemanticsNodeInteraction {
    val scrollable = fetchSemanticsNode().let { node ->
        generateSequence(node.parent) { it.parent }.any { SemanticsActions.ScrollBy in it.config }
    }
    return if (scrollable) performScrollTo() else this
}

/** Bấm nút theo chữ, không cuộn (thanh trên, thanh dưới, hộp thoại). */
fun ComposeTestRule.tap(text: String) {
    waitForText(text)
    onNode(hasText(text)).performClick()
}

fun ComposeTestRule.enterName(name: String) {
    waitForTag("candidateName")
    onNode(hasTestTag("candidateName")).performTextReplacement(name)
}

fun ComposeTestRule.assertShown(text: String): SemanticsNodeInteraction {
    waitForText(text)
    return onNodeWithText(text, substring = true)
}
