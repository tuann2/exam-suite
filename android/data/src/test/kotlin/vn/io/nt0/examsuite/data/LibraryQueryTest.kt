package vn.io.nt0.examsuite.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import vn.io.nt0.examsuite.data.library.LastAttempt
import vn.io.nt0.examsuite.data.library.LibraryItem
import vn.io.nt0.examsuite.data.library.LibraryQuery
import vn.io.nt0.examsuite.data.library.LibrarySort
import java.util.UUID

/** Tìm không dấu và sắp xếp Thư viện (library.md, Tìm, lọc, sắp xếp). */
class LibraryQueryTest {
    private fun item(title: String, code: String? = null, added: Long = 0, last: LastAttempt? = null, n: Int = title.hashCode()) = LibraryItem(
        UUID(0, n.toLong()), title, code, 1, 1, 0, 10, 70, false, 1, 1, added, added, false, last,
    )

    @Test
    fun searchIgnoresCaseAndDiacriticsIncludingDStroke() {
        assertEquals("toan cao cap", LibraryQuery.searchKey("Toán Cao Cấp"))
        assertEquals("dia ly", LibraryQuery.searchKey("Địa lý"))
        assertTrue(LibraryQuery.matches(item("Toán học"), "toan"))
        assertTrue(LibraryQuery.matches(item("Địa lý"), "d"))
        assertTrue(LibraryQuery.matches(item("Khác", code = "KTC01"), "ktc"))
        assertTrue(LibraryQuery.matches(item("Bất kỳ"), "   "))
        assertFalse(LibraryQuery.matches(item("Toán học"), "lý"))
    }

    @Test
    fun titleSortFollowsVietnameseOrder() {
        val titles = listOf("Đê", "Bê", "An", "Ân", "Dê", "Ăn")
        assertEquals(listOf("An", "Ăn", "Ân", "Bê", "Dê", "Đê"), LibraryQuery.sort(titles.map { item(it) }, LibrarySort.TITLE).map { it.title })
    }

    @Test
    fun recentSortUsesLatestOfAddedAndLastAttemptNewestFirst() {
        val a = item("A", added = 100)
        val b = item("B", added = 50, last = LastAttempt(80, 800, true, 300))
        val c = item("C", added = 200)
        assertEquals(listOf("B", "C", "A"), LibraryQuery.sort(listOf(a, b, c), LibrarySort.RECENT).map { it.title })
    }

    @Test
    fun lastScoreSortPutsHighestFirstAndUnattemptedLast() {
        val low = item("Thấp", last = LastAttempt(40, 400, false, 1))
        val high = item("Cao", last = LastAttempt(90, 900, true, 1))
        val none = item("Chưa thi")
        assertEquals(listOf("Cao", "Thấp", "Chưa thi"), LibraryQuery.query(listOf(none, low, high), "", LibrarySort.LAST_SCORE).map { it.title })
    }
}
