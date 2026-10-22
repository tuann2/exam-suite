package vn.io.nt0.examsuite.app

import android.app.Application
import android.os.Build
import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import androidx.datastore.preferences.preferencesDataStoreFile
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import vn.io.nt0.examsuite.attempt.AndroidSessionClock
import vn.io.nt0.examsuite.attempt.ui.QuestionImages
import vn.io.nt0.examsuite.core.session.SessionClock
import vn.io.nt0.examsuite.data.db.LibraryStore
import vn.io.nt0.examsuite.data.library.AssetSampleSource
import vn.io.nt0.examsuite.data.library.ExamLibrary
import vn.io.nt0.examsuite.data.settings.LibrarySettings
import java.io.File
import java.util.UUID

/** Application của app: giữ các dịch vụ dùng chung một lần cho cả tiến trình. */
class ExamSuiteApplication : Application() {
    val services: AppServices by lazy { AppServices(this) }

    override fun onCreate() {
        super.onCreate()
        // Android 14+ (targetSdk ≥ 34) làm `ZipFile` từ chối cả gói khi có entry tên chứa ".." hay bắt đầu bằng "/", trước
        // khi bộ đọc của `:core` kịp bỏ qua entry lạ như bản macOS (Decisions A1 của docs/plans/active/android-v1.md).
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) dalvik.system.ZipPathValidator.clearCallback()
    }
}

/** Kho Thư viện vừa mở và file kho cũ đã cách ly nếu kho bị hỏng (library.md, Lưu trữ). */
class OpenedLibrary(val library: ExamLibrary, val recoveredFrom: File?)

/** Dịch vụ của app: Thư viện (`:data`), cài đặt, đề mẫu, đồng hồ của phiên. */
class AppServices(private val app: Application) {
    /** Đồng hồ cho phiên mới và phiên dở khôi phục; test Compose thay bằng đồng hồ nhanh trước khi mở màn hình. */
    @Volatile
    var clock: SessionClock = AndroidSessionClock

    val settings: LibrarySettings by lazy {
        LibrarySettings(PreferenceDataStoreFactory.create { app.preferencesDataStoreFile(SETTINGS_FILE) })
    }

    val samples by lazy { AssetSampleSource(app.assets) }

    private val lock = Mutex()
    private var opened: OpenedLibrary? = null

    /** Mở kho một lần (đọc đĩa nên chạy nền); lỗi tạm thời ném `LibraryStoreException`, lần sau thử lại. */
    suspend fun library(): OpenedLibrary = lock.withLock {
        opened ?: withContext(Dispatchers.IO) {
            val store = LibraryStore.open(app)
            OpenedLibrary(ExamLibrary(store.database, app.filesDir), store.recoveredFrom)
        }.also { opened = it }
    }

    fun images(library: ExamLibrary, examId: UUID): QuestionImages = object : QuestionImages {
        override suspend fun bytes(path: String): ByteArray = library.media(examId, path)
    }

    private companion object {
        const val SETTINGS_FILE = "settings"
    }
}
