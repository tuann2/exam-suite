package vn.io.nt0.examsuite.attempt

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.sync.Mutex
import kotlin.random.Random

/** Phạm vi của cả app cho việc ghi không được bỏ dở khi rời màn hình (lưu lần thi, phiên dở). */
object AppScope : CoroutineScope by MainScope()

/** Mọi lệnh ghi của màn làm bài chạy lần lượt dưới một khoá chung (phiên dở, xoá phiên dở, lưu lần thi). */
object StoreWrites {
    val lock = Mutex()
}

/** Seed mới cho mỗi lần Bắt đầu, Làm lại, Luyện lại câu sai (64 bit không dấu, scoring.md). */
fun randomSeed(): ULong = Random.nextLong().toULong()
