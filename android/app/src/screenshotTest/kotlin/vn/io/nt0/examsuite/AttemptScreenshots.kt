package vn.io.nt0.examsuite

import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.tooling.preview.Preview
import com.android.tools.screenshot.PreviewTest
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import vn.io.nt0.examsuite.attempt.AttemptModel
import vn.io.nt0.examsuite.attempt.AttemptStore
import vn.io.nt0.examsuite.attempt.ui.AttemptFlow
import vn.io.nt0.examsuite.attempt.ui.LocalQuestionImages
import vn.io.nt0.examsuite.attempt.ui.LocalTimeZone
import vn.io.nt0.examsuite.attempt.ui.QuestionImages
import vn.io.nt0.examsuite.core.composer.CompositionOptions
import vn.io.nt0.examsuite.core.composer.ExamComposer
import vn.io.nt0.examsuite.core.composer.QuestionSelection
import vn.io.nt0.examsuite.core.model.Exam
import vn.io.nt0.examsuite.core.model.ExamOption
import vn.io.nt0.examsuite.core.model.ExamSection
import vn.io.nt0.examsuite.core.model.OptionId
import vn.io.nt0.examsuite.core.model.Question
import vn.io.nt0.examsuite.core.model.QuestionType
import vn.io.nt0.examsuite.core.review.ReviewFilter
import vn.io.nt0.examsuite.core.session.ExamSession
import vn.io.nt0.examsuite.core.session.SessionClock
import vn.io.nt0.examsuite.core.session.SessionMode
import vn.io.nt0.examsuite.core.session.SessionSnapshot
import vn.io.nt0.examsuite.ui.ExamSuiteTheme
import java.time.Instant
import java.util.TimeZone
import java.util.UUID

/*
 * Ảnh bố cục màn làm bài (plan-android-v1.md, A3b): câu dài 10 lựa chọn, ảnh lớn, Kết quả nhiều phần, Xem lại đề
 * `hideAnswers`, sáng/tối; câu dài và Kết quả thêm cỡ chữ hệ thống 150% (mobile.md, Nt0 chốt 2026-10-22). Trạng thái
 * dựng bằng `AttemptModel` thật trên phiên thật, nội dung đề tự soạn.
 */

private const val W = 360
private const val H = 780

private class FixedClock(var uptime: Double) : SessionClock {
    override fun now(): Instant = Instant.parse("2026-10-22T07:05:00Z").plusSeconds(uptime.toLong())

    override fun uptimeSeconds(): Double = uptime
}

private object NoStore : AttemptStore {
    override suspend fun saveDraft(snapshot: SessionSnapshot) = Unit

    override suspend fun clearDraft() = Unit

    override suspend fun previousPercent(examId: UUID, mode: SessionMode): Int? = 70

    override suspend fun saveAttempt(session: ExamSession) = Unit
}

private fun id(n: Int) = UUID.fromString("00000000-0000-4000-8000-%012d".format(n))

private fun opt(c: Char, text: String) = ExamOption(OptionId.of(c.toString())!!, text)

private fun filler(n: Int, section: Int) = Question(
    id = id(1000 + section * 100 + n),
    type = QuestionType.SINGLE,
    text = "Câu hỏi ôn tập số $n",
    options = listOf(opt('A', "Đúng"), opt('B', "Sai")),
    correct = listOf(OptionId.of("A")!!),
)

private val longQuestion = Question(
    id = id(7),
    type = QuestionType.MULTIPLE,
    text = "Một công ty có ba chi nhánh nối với nhau qua Internet. Quản trị viên cần chọn các biện pháp để **mã hoá** lưu " +
        "lượng giữa các chi nhánh, đồng thời vẫn cho phép giám sát truy cập. Lệnh kiểm tra cấu hình hiện tại là " +
        "`show crypto session`. Chọn các phương án phù hợp nhất.",
    options = listOf(
        opt('A', "Dùng đường hầm IPsec giữa các bộ định tuyến biên"),
        opt('B', "Chỉ dùng VLAN riêng cho từng chi nhánh"),
        opt('C', "Bật TLS cho mọi ứng dụng nội bộ và kiểm tra chứng chỉ ở cả hai đầu kết nối"),
        opt('D', "Tắt tường lửa để giảm độ trễ"),
        opt('E', "Dùng giao thức Telnet để quản trị từ xa"),
        opt('F', "Ghi nhật ký tập trung trên máy chủ syslog"),
        opt('G', "Đổi mật khẩu mặc định của thiết bị"),
        opt('H', "Mở mọi cổng để dễ khắc phục sự cố"),
        opt('I', "Dùng *WPA2-Personal* cho mạng khách"),
        opt('J', "Không cần làm gì thêm"),
    ),
    correct = listOf(OptionId.of("A")!!, OptionId.of("C")!!, OptionId.of("F")!!),
)

private fun networkExam(hideAnswers: Boolean = false) = Exam(
    formatVersion = 1,
    id = id(1),
    title = "Ôn tập Mạng máy tính và Bảo mật",
    code = "MMT-2026",
    passPercent = 70,
    timeLimitMinutes = 45,
    hideAnswers = hideAnswers,
    sections = listOf(
        ExamSection(id(11), "Phần 1: Mạng máy tính", (1..6).map { filler(it, 1) } + longQuestion + (8..15).map { filler(it, 1) }),
        ExamSection(id(12), "Bảo mật", (1..15).map { filler(it, 2) }),
        ExamSection(id(13), "Phần 3: Hệ điều hành", (1..10).map { filler(it, 3) }),
    ),
)

/** `setUp` trả lời trên phiên; nộp và mở Xem lại đi qua model (`then`) như khi người dùng bấm. */
private fun model(
    exam: Exam,
    mode: SessionMode,
    clock: FixedClock,
    then: AttemptModel.() -> Unit = {},
    setUp: ExamSession.() -> Unit,
): AttemptModel {
    val paper = ExamComposer.compose(exam, CompositionOptions(QuestionSelection.All, seed = 1uL))
    val session = ExamSession.start(exam, paper, mode, null, "Nguyễn Thị Minh Anh", clock)
    session.setUp()
    return AttemptModel(session, NoStore, CoroutineScope(Dispatchers.Unconfined), { 1uL }).apply(then)
}

@Composable
private fun Screen(model: AttemptModel, images: QuestionImages? = null) {
    ExamSuiteTheme {
        CompositionLocalProvider(LocalQuestionImages provides images, LocalTimeZone provides TimeZone.getTimeZone("Asia/Ho_Chi_Minh")) {
            AttemptFlow(model.state.value, model, onExit = {}, onNextAttempt = {})
        }
    }
}

// ---------- Câu dài, 10 lựa chọn (Thi) ----------

private fun longQuestionModel(): AttemptModel {
    val clock = FixedClock(0.0)
    return model(networkExam(), SessionMode.EXAM, clock) {
        repeat(4) { select(OptionId.of("A")!!); next() }
        next(); next()
        select(OptionId.of("A")!!)
        select(OptionId.of("C")!!)
        toggleFlag()
        clock.uptime = 1_712.0
    }
}

@PreviewTest
@Preview(name = "sang", locale = "vi", showBackground = true, widthDp = W, heightDp = H)
@Preview(name = "toi", locale = "vi", showBackground = true, widthDp = W, heightDp = H, uiMode = Configuration.UI_MODE_NIGHT_YES)
@Preview(name = "sang-150", locale = "vi", showBackground = true, widthDp = W, heightDp = H, fontScale = 1.5f)
@Composable
fun LongQuestionScreenshot() = Screen(longQuestionModel())

// ---------- Ảnh lớn (vừa bề rộng màn), đã Kiểm tra đáp án (Luyện tập) ----------

private const val IMAGE_PATH = "media/0000000000000000000000000000000000000000000000000000000000000000.png"

/**
 * Ảnh thử dựng đúng bằng cỡ hiện trên màn (bề rộng nội dung 328dp ở mật độ 2,625 của ảnh chụp = 861px), chỉ hình chữ nhật
 * không khử răng cưa: ảnh không bị co nên Mac và runner Linux của CI vẽ giống hệt (lần đầu co ảnh 1600px thì lệch).
 */
private object PreviewImages : QuestionImages {
    val bitmap: ImageBitmap by lazy {
        val bmp = Bitmap.createBitmap(861, 592, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        canvas.drawColor(0xFFE8F1F2.toInt())
        val paint = Paint()
        paint.color = 0xFF017777.toInt()
        canvas.drawRect(64f, 86f, 334f, 248f, paint)
        canvas.drawRect(527f, 86f, 797f, 248f, paint)
        canvas.drawRect(296f, 376f, 566f, 538f, paint)
        paint.color = 0xFF934A00.toInt()
        canvas.drawRect(334f, 160f, 527f, 172f, paint)
        canvas.drawRect(425f, 248f, 437f, 376f, paint)
        bmp.asImageBitmap()
    }

    override fun cached(path: String): ImageBitmap = bitmap

    override suspend fun bytes(path: String): ByteArray = ByteArray(0)
}

private fun imageModel(): AttemptModel {
    val exam = Exam(
        formatVersion = 1, id = id(2), title = "Sơ đồ mạng", passPercent = 60, timeLimitMinutes = 20,
        sections = listOf(
            ExamSection(id(21), "Sơ đồ", listOf(
                Question(
                    id = id(22), type = QuestionType.SINGLE,
                    text = "Quan sát sơ đồ. Thiết bị nào nối ba mạng con với nhau?",
                    image = IMAGE_PATH,
                    options = listOf(opt('A', "Bộ chuyển mạch"), opt('B', "Bộ định tuyến"), opt('C', "Bộ lặp"), opt('D', "Điểm truy cập không dây")),
                    correct = listOf(OptionId.of("B")!!),
                    explanation = "Bộ định tuyến chuyển gói giữa các **mạng con** khác nhau; bộ chuyển mạch chỉ nối trong một mạng.",
                ),
                filler(2, 9),
            )),
        ),
    )
    return model(exam, SessionMode.PRACTICE, FixedClock(0.0)) {
        select(OptionId.of("A")!!)
        checkAnswer()
    }
}

@PreviewTest
@Preview(name = "sang", locale = "vi", showBackground = true, widthDp = W, heightDp = H)
@Preview(name = "toi", locale = "vi", showBackground = true, widthDp = W, heightDp = H, uiMode = Configuration.UI_MODE_NIGHT_YES)
@Composable
fun LargeImageScreenshot() = Screen(imageModel(), PreviewImages)

// ---------- Kết quả nhiều phần ----------

private fun resultsModel(): AttemptModel {
    val clock = FixedClock(0.0)
    return model(networkExam(), SessionMode.EXAM, clock, setUp = {
        // Phần 1: 12/15 đúng, Bảo mật: 8/15, Phần 3: 9/10.
        paper.items.forEachIndexed { index, item ->
            goTo(index)
            val wrong = (item.sectionId == id(11) && index % 5 == 0) || (item.sectionId == id(12) && index % 2 == 0) ||
                (item.sectionId == id(13) && index == 39)
            if (item.questionId == id(7)) {
                select(OptionId.of("A")!!); select(OptionId.of("C")!!); select(OptionId.of("F")!!)
            } else {
                select(OptionId.of(if (wrong) "B" else "A")!!)
            }
        }
        clock.uptime = 2_315.0
    }, then = {
        openReview()
        submit()
    })
}

@PreviewTest
@Preview(name = "sang", locale = "vi", showBackground = true, widthDp = W, heightDp = H)
@Preview(name = "toi", locale = "vi", showBackground = true, widthDp = W, heightDp = H, uiMode = Configuration.UI_MODE_NIGHT_YES)
@Preview(name = "sang-150", locale = "vi", showBackground = true, widthDp = W, heightDp = H, fontScale = 1.5f)
@Composable
fun ResultsScreenshot() = Screen(resultsModel())

// ---------- Xem lại bài, đề ẩn đáp án ----------

private fun hiddenReviewModel(): AttemptModel {
    val clock = FixedClock(0.0)
    return model(networkExam(hideAnswers = true), SessionMode.EXAM, clock, setUp = {
        repeat(6) { next() }
        select(OptionId.of("A")!!)
        select(OptionId.of("B")!!)
        toggleFlag()
        clock.uptime = 1_200.0
    }, then = {
        openReview()
        submit()
        openAnswerReview(ReviewFilter.ALL)
        openReviewQuestion(6)
    })
}

@PreviewTest
@Preview(name = "sang", locale = "vi", showBackground = true, widthDp = W, heightDp = H)
@Preview(name = "toi", locale = "vi", showBackground = true, widthDp = W, heightDp = H, uiMode = Configuration.UI_MODE_NIGHT_YES)
@Preview(name = "sang-150", locale = "vi", showBackground = true, widthDp = W, heightDp = H, fontScale = 1.5f)
@Composable
fun HiddenAnswersReviewScreenshot() = Screen(hiddenReviewModel())
