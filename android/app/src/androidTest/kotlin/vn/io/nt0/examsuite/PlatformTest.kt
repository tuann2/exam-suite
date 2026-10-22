package vn.io.nt0.examsuite

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import vn.io.nt0.examsuite.core.file.ExamPackageReader
import vn.io.nt0.examsuite.data.library.LibraryItem
import vn.io.nt0.examsuite.data.library.LibraryQuery
import vn.io.nt0.examsuite.data.library.LibrarySort
import java.io.File
import java.util.UUID

/**
 * Hành vi của nền tảng mà test JVM không thấy (không mở màn hình): đọc gói dùng chung `fixtures/packages` trên ART (Android
 * 14+ có ZipPathValidator, app tắt ở Application) và sắp xếp tên tiếng Việt bằng ICU của Android.
 */
@RunWith(AndroidJUnit4::class)
class PlatformTest {
    @Test
    fun sharedPackagesReadStrictlyOnDevice() {
        val assets = InstrumentationRegistry.getInstrumentation().context.assets
        for (name in listOf("pack-exam-py.exam", "non-utf8-junk-name.exam")) {
            val file = File(Flow.app.cacheDir, name)
            assets.open(name).use { input -> file.outputStream().use { input.copyTo(it) } }
            assertEquals(name, 5, ExamPackageReader.readStrict(file).exam.questionCount)
        }
    }

    @Test
    fun vietnameseTitleOrderOnIcu() {
        fun item(title: String) = LibraryItem(
            UUID.nameUUIDFromBytes(title.toByteArray()), title, null, 1, 1, 0, 10, 50, false, 1, 1, 0, 0, false, null,
        )
        val titles = listOf("Đê", "Bê", "Ân", "An", "Dê", "Ăn")
        assertEquals(listOf("An", "Ăn", "Ân", "Bê", "Dê", "Đê"), LibraryQuery.sort(titles.map(::item), LibrarySort.TITLE).map { it.title })
    }
}
