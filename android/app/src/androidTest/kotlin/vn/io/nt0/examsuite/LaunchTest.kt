package vn.io.nt0.examsuite

import androidx.compose.ui.test.junit4.accessibility.enableAccessibilityChecks
import androidx.compose.ui.test.junit4.v2.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/** Test của khung A0 trên emulator: app mở, có tiêu đề Thư viện, kiểm trợ năng của Compose bật (không lớp riêng). */
@RunWith(AndroidJUnit4::class)
class LaunchTest {
    @get:Rule
    val compose = createAndroidComposeRule<MainActivity>()

    @Before
    fun enableChecks() {
        compose.enableAccessibilityChecks()
    }

    @Test
    fun launchShowsLibraryTitle() {
        val title = compose.activity.getString(R.string.library_title)
        compose.onNodeWithText(title).assertExists()
        compose.onNodeWithText(title).performClick()
    }
}
