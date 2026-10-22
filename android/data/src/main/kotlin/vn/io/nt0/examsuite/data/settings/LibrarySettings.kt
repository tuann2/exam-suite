package vn.io.nt0.examsuite.data.settings

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import vn.io.nt0.examsuite.core.session.SessionMode
import vn.io.nt0.examsuite.data.library.LibrarySort

/** Cài đặt nhỏ (library.md, Lưu trữ; exam-taking.md phương án 7): DataStore Preferences trong bộ nhớ riêng của app. */
data class Settings(
    /** Tên thí sinh lần trước, chung cho mọi đề. */
    val candidateName: String,
    /** Chế độ dùng lần trước (nhấp vào đề mở Trước khi thi với chế độ này). */
    val lastMode: SessionMode,
    val sort: LibrarySort,
    val samplesSeeded: Boolean,
    val welcomeDismissed: Boolean,
)

class LibrarySettings(private val store: DataStore<Preferences>) {
    val settings: Flow<Settings> = store.data.map { p ->
        Settings(
            candidateName = p[CANDIDATE_NAME] ?: "",
            lastMode = SessionMode.entries.firstOrNull { it.raw == p[LAST_MODE] } ?: SessionMode.PRACTICE,
            sort = LibrarySort.entries.firstOrNull { it.name == p[SORT] } ?: LibrarySort.RECENT,
            samplesSeeded = p[SAMPLES_SEEDED] ?: false,
            welcomeDismissed = p[WELCOME_DISMISSED] ?: false,
        )
    }

    suspend fun current(): Settings = settings.first()

    suspend fun setCandidateName(name: String) = store.edit { it[CANDIDATE_NAME] = name }

    suspend fun setLastMode(mode: SessionMode) = store.edit { it[LAST_MODE] = mode.raw }

    suspend fun setSort(sort: LibrarySort) = store.edit { it[SORT] = sort.name }

    suspend fun markSamplesSeeded() = store.edit { it[SAMPLES_SEEDED] = true }

    suspend fun dismissWelcome() = store.edit { it[WELCOME_DISMISSED] = true }

    private companion object {
        val CANDIDATE_NAME = stringPreferencesKey("candidate_name")
        val LAST_MODE = stringPreferencesKey("last_mode")
        val SORT = stringPreferencesKey("library_sort")
        val SAMPLES_SEEDED = booleanPreferencesKey("samples_seeded")
        val WELCOME_DISMISSED = booleanPreferencesKey("welcome_dismissed")
    }
}
