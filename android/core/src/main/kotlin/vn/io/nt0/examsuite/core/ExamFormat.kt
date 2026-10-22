package vn.io.nt0.examsuite.core

/** Hằng số của định dạng gói đề (docs/product/exam-format.md). Lõi đầy đủ viết ở bước A1. */
object ExamFormat {
    /** Phiên bản định dạng cao nhất mà lõi đọc được. */
    const val SUPPORTED_FORMAT_VERSION: Int = 1

    /** Đuôi file gói đề. */
    const val FILE_EXTENSION: String = "exam"
}
