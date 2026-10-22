package vn.io.nt0.examsuite.data.library

import java.text.Collator
import java.text.Normalizer
import java.util.Locale

/** Cách sắp xếp Thư viện (library.md): Gần đây, Tên (thứ tự tiếng Việt), Điểm lần trước. */
enum class LibrarySort { RECENT, TITLE, LAST_SCORE }

/** Tìm và sắp xếp Thư viện, thuần (không Android) để test JVM. */
object LibraryQuery {
    /**
     * Khoá tìm kiếm: không phân biệt hoa thường và dấu ("toan" khớp "Toán", "d" khớp "đ", library.md): đ/Đ thành d, tách
     * dấu (NFD) rồi bỏ dấu tổ hợp, chữ thường.
     */
    fun searchKey(text: String): String {
        val decomposed = Normalizer.normalize(text.replace('đ', 'd').replace('Đ', 'D'), Normalizer.Form.NFD)
        return decomposed.filter { Character.getType(it) != Character.NON_SPACING_MARK.toInt() }.lowercase(Locale.ROOT)
    }

    /** Tìm theo tiêu đề và mã đề; chuỗi tìm trống hay toàn khoảng trắng thì mọi đề đều khớp. */
    fun matches(item: LibraryItem, query: String): Boolean {
        val key = searchKey(query.trim())
        if (key.isEmpty()) return true
        return searchKey(item.title).contains(key) || (item.code?.let { searchKey(it).contains(key) } ?: false)
    }

    private val vietnamese: Collator = Collator.getInstance(Locale.forLanguageTag("vi")).apply { strength = Collator.TERTIARY }

    fun sort(items: List<LibraryItem>, sort: LibrarySort): List<LibraryItem> = when (sort) {
        // Gần đây: lần thi hoặc lần thêm (cập nhật) gần nhất, mới nhất trước.
        LibrarySort.RECENT -> items.sortedWith(compareByDescending<LibraryItem> { recency(it) }.thenBy { it.examId })
        LibrarySort.TITLE -> items.sortedWith(Comparator<LibraryItem> { a, b -> vietnamese.compare(a.title, b.title) }.thenBy { it.examId })
        // Điểm lần trước: cao trước; đề chưa thi xếp cuối, giữa chúng theo tên.
        LibrarySort.LAST_SCORE -> items.sortedWith(
            compareBy<LibraryItem> { it.lastAttempt == null }
                .thenByDescending { it.lastAttempt?.score1000 ?: 0 }
                .thenComparator { a, b -> vietnamese.compare(a.title, b.title) }
                .thenBy { it.examId },
        )
    }

    private fun recency(item: LibraryItem) = maxOf(item.addedAtMillis, item.updatedAtMillis, item.lastAttempt?.submittedAtMillis ?: 0)

    fun query(items: List<LibraryItem>, search: String, sort: LibrarySort): List<LibraryItem> = sort(items.filter { matches(it, search) }, sort)
}
