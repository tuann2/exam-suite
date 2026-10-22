package vn.io.nt0.examsuite.data.db

import android.content.Context
import androidx.room.Dao
import androidx.room.Database
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.Upsert
import androidx.sqlite.db.SupportSQLiteDatabase
import androidx.sqlite.db.SupportSQLiteOpenHelper
import androidx.sqlite.db.framework.FrameworkSQLiteOpenHelperFactory
import kotlinx.coroutines.flow.Flow
import java.io.File

@Dao
interface ExamEntryDao {
    @Query("SELECT * FROM exam_entry WHERE removedAtMillis IS NULL")
    fun observeActive(): Flow<List<ExamEntryEntity>>

    @Query("SELECT * FROM exam_entry WHERE removedAtMillis IS NULL")
    suspend fun active(): List<ExamEntryEntity>

    @Query("SELECT * FROM exam_entry")
    suspend fun all(): List<ExamEntryEntity>

    @Query("SELECT * FROM exam_entry WHERE examId = :examId")
    suspend fun get(examId: String): ExamEntryEntity?

    @Query("SELECT * FROM exam_entry WHERE removedAtMillis IS NOT NULL")
    suspend fun removed(): List<ExamEntryEntity>

    @Upsert
    suspend fun upsert(entry: ExamEntryEntity)

    @Query("UPDATE exam_entry SET removedAtMillis = :at WHERE examId = :examId AND removedAtMillis IS NULL")
    suspend fun markRemoved(examId: String, at: Long): Int

    @Query("UPDATE exam_entry SET removedAtMillis = NULL WHERE examId = :examId AND removedAtMillis IS NOT NULL")
    suspend fun unmarkRemoved(examId: String): Int

    @Query("DELETE FROM exam_entry WHERE examId = :examId")
    suspend fun delete(examId: String)
}

@Dao
interface AttemptDao {
    @Query("SELECT * FROM attempt ORDER BY submittedAtMillis DESC, attemptId")
    fun observeAll(): Flow<List<AttemptEntity>>

    @Query("SELECT * FROM attempt WHERE examId = :examId ORDER BY submittedAtMillis DESC, attemptId")
    suspend fun forExam(examId: String): List<AttemptEntity>

    @Query("SELECT * FROM attempt WHERE attemptId = :attemptId")
    suspend fun get(attemptId: String): AttemptEntity?

    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insert(attempt: AttemptEntity)
}

@Dao
interface DraftDao {
    @Query("SELECT * FROM draft_session WHERE slot = 0")
    suspend fun get(): DraftEntity?

    @Upsert
    suspend fun upsert(draft: DraftEntity)

    @Query("DELETE FROM draft_session")
    suspend fun clear()
}

/**
 * Kho Thư viện, schema v1 (`android/data/schemas/.../1.json`, commit). Đổi schema phải tăng phiên bản, thêm `Migration`
 * và test mở kho của phiên bản cũ (LibraryDatabaseSchemaTest), không sửa schema v1 (như `LibrarySchemaV1` bản macOS).
 */
@Database(entities = [ExamEntryEntity::class, AttemptEntity::class, DraftEntity::class], version = 1, exportSchema = true)
abstract class LibraryDatabase : RoomDatabase() {
    abstract fun entries(): ExamEntryDao

    abstract fun attempts(): AttemptDao

    abstract fun drafts(): DraftDao
}

/**
 * Mở kho trong bộ nhớ riêng của app (library.md, Lưu trữ). Kho không mở được thì app không crash: file kho cũ đổi tên
 * thành `<tên>.broken-<thời điểm>` (cùng `-wal`, `-shm`), tạo kho mới, `recoveredFrom` báo cho giao diện. Android mặc
 * định **xoá** kho hỏng; bộ mở kho ở đây đổi tên thay vì xoá để còn cứu dữ liệu.
 */
object LibraryStore {
    const val FILE_NAME = "library.db"

    class Opened(val database: LibraryDatabase, val recoveredFrom: File?)

    fun open(context: Context, now: () -> Long = System::currentTimeMillis): Opened {
        val file = context.getDatabasePath(FILE_NAME)
        var recovered: File? = null
        if (file.exists() && !hasSqliteHeader(file)) recovered = quarantine(file, now())
        var database = build(context) { recovered = recovered ?: quarantine(file, now()) }
        try {
            database.openHelper.writableDatabase.query("SELECT count(*) FROM exam_entry").use { it.moveToFirst() }
        } catch (e: android.database.sqlite.SQLiteException) {
            database.close()
            if (file.exists()) recovered = quarantine(file, now())
            database = build(context) {}
        }
        return Opened(database, recovered)
    }

    private fun build(context: Context, onCorruption: () -> Unit): LibraryDatabase =
        Room.databaseBuilder(context.applicationContext, LibraryDatabase::class.java, FILE_NAME)
            .openHelperFactory(PreservingFactory(onCorruption))
            .build()

    private fun hasSqliteHeader(file: File): Boolean {
        if (file.length() == 0L) return true
        val magic = "SQLite format 3\u0000".toByteArray(Charsets.US_ASCII)
        val head = ByteArray(magic.size)
        val read = file.inputStream().use { it.read(head) }
        return read == magic.size && head.contentEquals(magic)
    }

    /** Đổi tên kho (và file phụ) thành `.broken-<thời điểm>`; trả file kho đã đổi tên. */
    private fun quarantine(file: File, at: Long): File {
        val target = File(file.parentFile, "${file.name}.broken-$at")
        for (suffix in listOf("", "-wal", "-shm", "-journal")) {
            val source = File(file.path + suffix)
            if (source.exists()) source.renameTo(File(target.path + suffix))
        }
        return target
    }

    /** Bọc bộ mở kho mặc định: khi SQLite báo hỏng thì gọi `onCorruption` (đổi tên) thay vì để Android xoá file. */
    private class PreservingFactory(private val onCorruption: () -> Unit) : SupportSQLiteOpenHelper.Factory {
        private val delegate = FrameworkSQLiteOpenHelperFactory()

        override fun create(configuration: SupportSQLiteOpenHelper.Configuration): SupportSQLiteOpenHelper {
            val inner = configuration.callback
            val callback = object : SupportSQLiteOpenHelper.Callback(inner.version) {
                override fun onConfigure(db: SupportSQLiteDatabase) = inner.onConfigure(db)
                override fun onCreate(db: SupportSQLiteDatabase) = inner.onCreate(db)
                override fun onUpgrade(db: SupportSQLiteDatabase, oldVersion: Int, newVersion: Int) = inner.onUpgrade(db, oldVersion, newVersion)
                override fun onDowngrade(db: SupportSQLiteDatabase, oldVersion: Int, newVersion: Int) = inner.onDowngrade(db, oldVersion, newVersion)
                override fun onOpen(db: SupportSQLiteDatabase) = inner.onOpen(db)
                override fun onCorruption(db: SupportSQLiteDatabase) {
                    runCatching { db.close() }
                    onCorruption()
                }
            }
            return delegate.create(
                SupportSQLiteOpenHelper.Configuration.builder(configuration.context)
                    .name(configuration.name)
                    .callback(callback)
                    .noBackupDirectory(configuration.useNoBackupDirectory)
                    .allowDataLossOnRecovery(false)
                    .build(),
            )
        }
    }
}
