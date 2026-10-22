package vn.io.nt0.examsuite.attempt

import androidx.lifecycle.ViewModel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.sync.Mutex
import vn.io.nt0.examsuite.attempt.ui.QuestionImages
import vn.io.nt0.examsuite.core.session.ExamSession
import kotlin.random.Random

/** Phạm vi của cả app cho việc ghi không được bỏ dở khi rời màn hình (lưu lần thi, phiên dở). */
object AppScope : CoroutineScope by MainScope()

/** Mọi lệnh ghi của màn làm bài chạy lần lượt dưới một khoá chung (phiên dở, xoá phiên dở, lưu lần thi). */
object StoreWrites {
    val lock = Mutex()
}

/** Seed mới cho Làm lại / Luyện lại câu sai (64 bit không dấu, scoring.md). */
fun randomSeed(): ULong = Random.nextLong().toULong()

/** Giữ `AttemptModel` qua xoay màn hình; A3a tạo với phiên mới hay phiên dở khôi phục. */
class AttemptViewModel(
    session: ExamSession,
    store: AttemptStore,
    val images: QuestionImages,
    storeScope: CoroutineScope = AppScope,
    newSeed: () -> ULong = ::randomSeed,
) : ViewModel() {
    val model = AttemptModel(session, store, storeScope, newSeed)
}
