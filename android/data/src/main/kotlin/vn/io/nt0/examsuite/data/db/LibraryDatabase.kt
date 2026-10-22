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

/** Kho không mở được vì lỗi không phải kho hỏng (đầy bộ nhớ, lỗi đọc ghi, bị khoá): không đổi tên kho, giao diện báo lỗi. */
class LibraryStoreException(message: String, cause: Throwable? = null) : Exception(message, cause)

/**
 * Mở kho trong bộ nhớ riêng của app (library.md, Lưu trữ). Kho **hỏng** thì app không crash: file kho đổi tên thành
 * `<tên>.broken-<thời điểm>` (cùng `-wal`, `-shm`, `-journal`), tạo kho mới, `recoveredFrom` báo cho giao diện. Android mặc
 * định **xoá** kho hỏng; ở đây đổi tên để còn cứu dữ liệu. Chỉ cách ly khi SQLite báo kho hỏng (`SQLiteDatabaseCorruptException`,
 * gồm "file is not a database") hoặc khi Room không mở được vì lệch schema (kho của bản app khác); lỗi tạm thời (đầy bộ nhớ,
 * lỗi đọc ghi, bị khoá) ném `LibraryStoreException`, không đổi tên kho lành (review độc lập PR #3, C2).
 *
 * Kho hỏng phát hiện trong lúc chạy (`onCorruption`): đổi tên ngay, ghi file đánh dấu `<tên>.recovered`; lần mở sau báo
 * `recoveredFrom` một lần.
 */
object LibraryStore {
    const val FILE_NAME = "library.db"

    class Opened(val database: LibraryDatabase, val recoveredFrom: File?)

    fun open(context: Context, now: () -> Long = System::currentTimeMillis): Opened {
        val file = context.getDatabasePath(FILE_NAME)
        val marker = File(file.path + ".recovered")
        var recovered: File? = marker.takeIf { it.exists() }?.readText()?.let(::File)
        marker.delete()
        if (file.exists() && !hasSqliteHeader(file)) recovered = quarantine(file, now())
        var database = build(context) { quarantineAtRuntime(file, marker, now()) }
        try {
            probe(database)
        } catch (e: Exception) {
            database.close()
            if (!isCorruptOrIncompatible(e)) throw LibraryStoreException("không mở được kho Thư viện", e)
            if (file.exists()) recovered = quarantine(file, now())
            database = build(context) { quarantineAtRuntime(file, marker, now()) }
            try {
                probe(database)
            } catch (again: Exception) {
                database.close()
                throw LibraryStoreException("không tạo được kho Thư viện mới", again)
            }
        }
        return Opened(database, recovered)
    }

    private fun probe(database: LibraryDatabase) {
        database.openHelper.writableDatabase.query("SELECT count(*) FROM exam_entry").use { it.moveToFirst() }
    }

    /** Kho hỏng (SQLite) hoặc Room không chấp nhận schema của kho (kho do bản app khác ghi, hạ phiên bản). */
    private fun isCorruptOrIncompatible(e: Throwable): Boolean {
        var cause: Throwable? = e
        while (cause != null) {
            if (cause is android.database.sqlite.SQLiteDatabaseCorruptException) return true
            if (cause is IllegalStateException && (cause.message?.contains("Room") == true || cause.message?.contains("migration") == true)) return true
            cause = cause.cause
        }
        return false
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

    private fun quarantineAtRuntime(file: File, marker: File, at: Long) {
        val broken = quarantine(file, at)
        runCatching { marker.writeText(broken.path) }
    }

    /**
     * Đổi tên kho (và file phụ) thành `.broken-<thời điểm>`; trả file kho đã đổi tên. Đổi tên file kho chính thất bại thì
     * ném `LibraryStoreException` (không tạo kho mới đè lên dữ liệu cũ).
     */
    private fun quarantine(file: File, at: Long): File {
        val target = File(file.parentFile, "${file.name}.broken-$at")
        for (suffix in listOf("", "-wal", "-shm", "-journal")) {
            val source = File(file.path + suffix)
            if (source.exists() && !source.renameTo(File(target.path + suffix)) && suffix.isEmpty()) {
                throw LibraryStoreException("không đổi tên được kho hỏng ${file.name}")
            }
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
