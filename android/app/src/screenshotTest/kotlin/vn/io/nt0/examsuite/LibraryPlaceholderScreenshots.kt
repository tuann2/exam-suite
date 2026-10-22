package vn.io.nt0.examsuite

import android.content.res.Configuration
import androidx.compose.runtime.Composable
import androidx.compose.ui.tooling.preview.Preview
import com.android.tools.screenshot.PreviewTest

/**
 * Spike A0: Compose Preview Screenshot Testing với AGP đang dùng; ảnh tham chiếu ghi trên cùng nền với CI.
 * layoutlib mặc định dựng ở en-US nên mỗi preview phải ghi `locale` (tiếng Việt là nguồn).
 */
@PreviewTest
@Preview(name = "sang", locale = "vi", showBackground = true, widthDp = 360, heightDp = 640)
@Preview(name = "toi", locale = "vi", showBackground = true, widthDp = 360, heightDp = 640, uiMode = Configuration.UI_MODE_NIGHT_YES)
@Composable
fun LibraryPlaceholderScreenshot() {
    ExamSuiteTheme { LibraryPlaceholder() }
}
