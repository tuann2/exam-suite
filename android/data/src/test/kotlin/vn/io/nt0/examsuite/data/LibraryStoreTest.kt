package vn.io.nt0.examsuite.data

import android.database.sqlite.SQLiteDatabase
import androidx.room.Room
import androidx.test.ext.junit.runners.AndroidJUnit4
import kotlinx.coroutines.runBlocking
import org.json.JSONObject
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import vn.io.nt0.examsuite.data.db.LibraryDatabase
import vn.io.nt0.examsuite.data.db.LibraryStore
import java.io.File

/** Kho trên đĩa (library.md, Lưu trữ): mở lại giữ dữ liệu, kho hỏng đổi tên chứ không xoá, schema v1 không đổi ngầm. */
@RunWith(AndroidJUnit4::class)
class LibraryStoreTest {
    private val context = DataTest.context
    private val file: File get() = context.getDatabasePath(LibraryStore.FILE_NAME)

    @After
    fun cleanUp() {
        file.parentFile?.listFiles()?.forEach { it.delete() }
    }

    @Test
    fun reopeningKeepsDataWithoutRecovery() = runBlocking {
        val first = LibraryStore.open(context)
        assertNull(first.recoveredFrom)
        val library = DataTest.library(first.database)
        library.import(DataTest.stream(DataTest.pack("toi-thieu")))
        first.database.close()
        val second = LibraryStore.open(context)
        assertNull(second.recoveredFrom)
        assertEquals(1, second.database.entries().active().size)
        second.database.close()
    }

    @Test
    fun brokenStoreIsRenamedAndANewEmptyStoreOpens() = runBlocking {
        file.parentFile!!.mkdirs()
        file.writeText("không phải SQLite")
        val opened = LibraryStore.open(context) { 1234L }
        val broken = assertNotNull(opened.recoveredFrom).let { opened.recoveredFrom!! }
        assertEquals("${LibraryStore.FILE_NAME}.broken-1234", broken.name)
        assertEquals("không phải SQLite", broken.readText())
        assertEquals(0, opened.database.entries().active().size)
        opened.database.close()
    }

    /**
     * Kho v1 dựng đúng từ file schema đã commit (`schemas/.../1.json`) phải mở được bằng code hiện tại: đổi bảng hay cột
     * mà không tăng phiên bản làm Room báo lệch dấu vân tay schema và test này đỏ.
     */
    @Test
    fun storeCreatedFromCommittedV1SchemaOpensWithCurrentCode() = runBlocking {
        val schema = JSONObject(File("schemas/vn.io.nt0.examsuite.data.db.LibraryDatabase/1.json").readText()).getJSONObject("database")
        assertEquals(1, schema.getInt("version"))
        // Plugin Room ghi đè file schema của phiên bản hiện tại mỗi lần build: đổi bảng mà không tăng phiên bản thì file
        // tự sinh lại và phép mở bên dưới vẫn đạt. Khoá dấu vân tay v1 ở đây (như v1ModelHashesUnchanged của bản macOS);
        // đỏ thì tăng phiên bản kèm Migration, không sửa hằng số này.
        assertEquals(V1_IDENTITY_HASH, schema.getString("identityHash"))
        file.parentFile!!.mkdirs()
        SQLiteDatabase.openOrCreateDatabase(file, null).use { sql ->
            val entities = schema.getJSONArray("entities")
            for (i in 0 until entities.length()) {
                val entity = entities.getJSONObject(i)
                val table = entity.getString("tableName")
                sql.execSQL(entity.getString("createSql").replace("\${TABLE_NAME}", table))
                val indices = entity.optJSONArray("indices")
                for (j in 0 until (indices?.length() ?: 0)) {
                    sql.execSQL(indices!!.getJSONObject(j).getString("createSql").replace("\${TABLE_NAME}", table))
                }
            }
            val setup = schema.getJSONArray("setupQueries")
            for (i in 0 until setup.length()) sql.execSQL(setup.getString(i))
            sql.execSQL("INSERT INTO exam_entry VALUES ('11111111-2222-4333-8444-555555555555','Đề cũ',NULL,1,1,0,10,70,0,1,10,'ab',1,1,NULL,NULL)")
            sql.version = 1
        }
        val db = Room.databaseBuilder(context, LibraryDatabase::class.java, LibraryStore.FILE_NAME).build()
        assertEquals(listOf("Đề cũ"), db.entries().active().map { it.title })
        db.close()
        assertTrue(file.exists())
    }

    private companion object {
        const val V1_IDENTITY_HASH = "d7287117f556d461eefc70e8d70e826a"
    }
}
