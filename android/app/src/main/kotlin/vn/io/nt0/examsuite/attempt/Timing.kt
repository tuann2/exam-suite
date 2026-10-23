package vn.io.nt0.examsuite.attempt

/**
 * Đo thời gian các thao tác của bảng ngân sách (large-exams.md) để đo tay đề chuẩn trên máy thật (plan-android-v1.md, A4;
 * docs/notes/android-measurements.md). Chỉ bản debug ghi nhật ký (`ExamSuiteApplication` gắn `sink`, thẻ logcat
 * `ExamSuiteTiming`); bản phát hành và test JVM không gắn nên không đo.
 */
object Timing {
    @Volatile
    var sink: ((code: String, millis: Double) -> Unit)? = null

    inline fun <T> measure(code: String, block: () -> T): T {
        val out = sink ?: return block()
        val start = System.nanoTime()
        try {
            return block()
        } finally {
            out(code, (System.nanoTime() - start) / 1e6)
        }
    }

    fun record(code: String, millis: Double) {
        sink?.invoke(code, millis)
    }
}
