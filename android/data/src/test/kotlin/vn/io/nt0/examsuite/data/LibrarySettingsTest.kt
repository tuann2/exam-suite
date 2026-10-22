package vn.io.nt0.examsuite.data

import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import androidx.test.ext.junit.runners.AndroidJUnit4
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import vn.io.nt0.examsuite.core.session.SessionMode
import vn.io.nt0.examsuite.data.library.LibrarySort
import vn.io.nt0.examsuite.data.settings.LibrarySettings
import vn.io.nt0.examsuite.data.settings.Settings
import java.nio.file.Files

/** Cài đặt nhỏ: mặc định và đọc lại sau khi ghi. */
@RunWith(AndroidJUnit4::class)
class LibrarySettingsTest {
    @Test
    fun defaultsThenValuesPersist() = runBlocking {
        val file = Files.createTempDirectory("caidat").resolve("settings.preferences_pb").toFile()
        val store = PreferenceDataStoreFactory.create(scope = CoroutineScope(Dispatchers.IO + SupervisorJob())) { file }
        val settings = LibrarySettings(store)
        assertEquals(Settings("", SessionMode.PRACTICE, LibrarySort.RECENT, samplesSeeded = false, welcomeDismissed = false), settings.current())
        settings.setCandidateName("Nguyễn Văn A")
        settings.setLastMode(SessionMode.EXAM)
        settings.setSort(LibrarySort.TITLE)
        settings.markSamplesSeeded()
        settings.dismissWelcome()
        assertEquals(Settings("Nguyễn Văn A", SessionMode.EXAM, LibrarySort.TITLE, samplesSeeded = true, welcomeDismissed = true), settings.current())
    }
}
