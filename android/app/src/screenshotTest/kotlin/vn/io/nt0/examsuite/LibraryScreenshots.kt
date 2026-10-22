package vn.io.nt0.examsuite

import android.content.res.Configuration
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.tooling.preview.Preview
import com.android.tools.screenshot.PreviewTest
import vn.io.nt0.examsuite.attempt.ui.LocalTimeZone
import vn.io.nt0.examsuite.core.session.SessionMode
import vn.io.nt0.examsuite.data.library.LastAttempt
import vn.io.nt0.examsuite.data.library.LibraryItem
import vn.io.nt0.examsuite.data.library.LibrarySort
import vn.io.nt0.examsuite.library.LibraryActions
import vn.io.nt0.examsuite.library.LibraryScreen
import vn.io.nt0.examsuite.ui.ExamSuiteTheme
import java.util.TimeZone
import java.util.UUID

/** Thư viện dạng danh sách, sáng/tối (plan-android-v1.md A3a): dải chào mừng, đề mẫu, đề có lần thi đậu và trượt. */

private fun libraryItem(n: Int, title: String, code: String?, questions: Int, sections: Int, minutes: Int, sample: Boolean, last: LastAttempt?) =
    LibraryItem(
        examId = UUID.fromString("00000000-0000-4000-8000-%012d".format(n)), title = title, code = code, questionCount = questions,
        sectionCount = sections, mediaCount = 0, timeLimitMinutes = minutes, passPercent = 70, hideAnswers = false, formatVersion = 1,
        fileSize = 1, addedAtMillis = n.toLong(), updatedAtMillis = n.toLong(), isSample = sample, lastAttempt = last,
    )

private val items = listOf(
    libraryItem(1, "Ôn tập Mạng máy tính và Bảo mật", "MMT-2026", 40, 3, 45, false, LastAttempt(72, 725, true, 1_792_650_000_000)),
    libraryItem(2, "Tiếng Anh giao tiếp — Đề luyện số 3 (bản dài để thử xuống dòng)", null, 120, 6, 90, false, LastAttempt(55, 550, false, 1_792_560_000_000)),
    libraryItem(3, "An toàn thông tin cơ bản", "ATTT01", 23, 3, 20, true, null),
    libraryItem(4, "Làm quen với Exam Suite", "LAMQUEN", 12, 2, 10, true, null),
)

private object NoLibraryActions : LibraryActions {
    override fun setQuery(query: String) = Unit
    override fun setSort(sort: LibrarySort) = Unit
    override fun addExam() = Unit
    override fun openHistory() = Unit
    override fun open(item: LibraryItem, mode: SessionMode?) = Unit
    override fun viewHistory(item: LibraryItem) = Unit
    override fun remove(item: LibraryItem) = Unit
    override fun dismissWelcome() = Unit
}

@PreviewTest
@Preview(name = "sang", locale = "vi", showBackground = true, widthDp = 360, heightDp = 780)
@Preview(name = "toi", locale = "vi", showBackground = true, widthDp = 360, heightDp = 780, uiMode = Configuration.UI_MODE_NIGHT_YES)
@Composable
fun LibraryScreenshot() {
    ExamSuiteTheme {
        CompositionLocalProvider(LocalTimeZone provides TimeZone.getTimeZone("Asia/Ho_Chi_Minh")) {
            LibraryScreen(items, LibrarySort.TITLE, query = "", showWelcome = true, actions = NoLibraryActions)
        }
    }
}
