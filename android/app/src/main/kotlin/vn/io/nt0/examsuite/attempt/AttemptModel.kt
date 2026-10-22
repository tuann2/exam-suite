package vn.io.nt0.examsuite.attempt

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import vn.io.nt0.examsuite.core.attempt.AttemptPayload
import vn.io.nt0.examsuite.core.composer.CompositionOptions
import vn.io.nt0.examsuite.core.file.QuestionFingerprint
import vn.io.nt0.examsuite.core.model.QuestionType
import vn.io.nt0.examsuite.core.review.QuestionChange
import vn.io.nt0.examsuite.core.review.ReviewDetail
import vn.io.nt0.examsuite.core.review.ReviewFilter
import vn.io.nt0.examsuite.core.review.ReviewItems
import vn.io.nt0.examsuite.core.scoring.QuestionOutcome
import vn.io.nt0.examsuite.core.session.ExamSession
import vn.io.nt0.examsuite.core.session.PauseReason
import vn.io.nt0.examsuite.core.session.SessionEvent
import vn.io.nt0.examsuite.core.session.SessionException
import vn.io.nt0.examsuite.core.session.SessionMode
import vn.io.nt0.examsuite.core.session.SessionPhase
import java.util.UUID

/** Màn đang hiện của luồng làm bài, theo trạng thái phiên. */
sealed interface AttemptScreen {
    data class Answering(
        val question: QuestionView,
        val answeredCount: Int,
        val canCheckAnswer: Boolean,
        val isFirst: Boolean,
        val isLast: Boolean,
        val announcement: QuestionAnnouncement,
    ) : AttemptScreen

    /** Tạm dừng: lớp phủ che toàn bộ câu và lựa chọn, bảng câu hỏi không hiện. */
    data class Paused(val reason: PauseReason) : AttemptScreen

    data class Review(val summary: ReviewSummary) : AttemptScreen

    data class Results(val results: ResultsView) : AttemptScreen

    data class AnswerReview(val review: AnswerReviewState) : AttemptScreen
}

data class AttemptUiState(
    val examTitle: String,
    val mode: SessionMode,
    val clock: ClockDisplay,
    val banner: SessionBanner?,
    /** Bảng câu hỏi (làm bài và Rà soát); rỗng ở các màn khác. */
    val navigator: List<NavigatorSection>,
    val screen: AttemptScreen,
)

/** Một dòng của danh sách Xem lại bài. */
data class ReviewRow(
    val index: Int,
    val number: Int,
    val outcome: QuestionOutcome,
    val isFlagged: Boolean,
    val change: QuestionChange,
    /** Dòng đầu của nội dung câu; null nếu câu đã xoá. */
    val preview: String?,
)

/** Xem lại bài (exam-taking.md): bộ lọc, danh sách câu theo thứ tự phiên, chi tiết câu đang mở (null: đang ở danh sách). */
data class AnswerReviewState(
    val filter: ReviewFilter,
    val counts: Map<ReviewFilter, Int>,
    val rows: List<ReviewRow>,
    val detail: ReviewDetail?,
    /** Vị trí của câu đang mở trong bộ lọc, cho Câu trước / Câu sau. */
    val positionInFilter: Int?,
    val answersHidden: Boolean,
    val canPracticeIncorrect: Boolean,
) {
    val hasPrevious: Boolean get() = positionInFilter != null && positionInFilter > 0
    val hasNext: Boolean get() = positionInFilter != null && positionInFilter < rows.size - 1
}

/** Lệnh của giao diện làm bài; `AttemptModel` làm thật, preview và test giao diện dùng bản rỗng. */
interface AttemptActions {
    fun toggleOption(position: Int)
    fun next()
    fun previous()
    fun goTo(index: Int)
    fun toggleFlag()
    fun checkAnswer()
    fun pause()
    fun resume()
    fun openReview()
    fun returnToAttempt(index: Int? = null)
    fun submit()
    fun discard()
    fun dismissBanner(id: Int)
    fun retake(): NextAttempt?
    fun practiceIncorrect(): NextAttempt?
    fun openAnswerReview(filter: ReviewFilter = ReviewFilter.ALL)
    fun setReviewFilter(filter: ReviewFilter)
    fun openReviewQuestion(index: Int)
    fun stepReviewQuestion(delta: Int)
    fun backFromAnswerReview(): Boolean
}

/** Phiên mới mở từ Kết quả/Xem lại: **Làm lại** hoặc **Luyện lại câu sai**; màn Trước khi thi điền sẵn (A3a). */
data class NextAttempt(
    val examId: UUID,
    val mode: SessionMode,
    val options: CompositionOptions,
    val timeLimitMinutes: Int?,
    val candidateName: String,
    /** Luyện lại câu sai: chỉ đổi được tên thí sinh. */
    val isPracticeIncorrect: Boolean,
)

/**
 * Model của luồng làm bài: bọc `ExamSession` (luật ở `:core`), dựng trạng thái màn hình, tạm dừng và lưu phiên dở khi
 * app xuống nền (mobile.md), lưu lần thi khi nộp. Không chữ giao diện, không Android: test JVM.
 *
 * Mọi việc ghi (`store`) chạy lần lượt trên `storeScope` (phạm vi của app, không bị huỷ khi rời màn hình, để lần thi vừa
 * nộp vẫn được lưu), theo đúng thứ tự gọi: phiên dở ghi sau khi đã nộp hay bỏ bài không thể ghi đè việc xoá.
 */
class AttemptModel(
    private val session: ExamSession,
    private val store: AttemptStore,
    private val storeScope: CoroutineScope,
    private val newSeed: () -> ULong,
    /** Khoá chung của mọi lệnh ghi của màn làm bài trong app (mỗi lúc một phiên, kể cả khi hai model nối nhau). */
    private val writeLock: Mutex = StoreWrites.lock,
) : AttemptActions {
    val examId: UUID get() = session.exam.id

    private var banner: SessionBanner? = null
    private var nextBannerId = 1
    private var previousPercent: Int? = null
    private var saveState = SaveState.SAVING
    private var reviewItems: ReviewItems? = null
    private var answerReview: Boolean = false
    private var reviewFilter = ReviewFilter.ALL
    private var reviewIndex: Int? = null
    /** Đã Bỏ bài: phiên không còn dùng, mọi lệnh (kể cả xuống nền) không làm gì, để không lưu lại phiên dở vừa xoá. */
    private var discarded = false

    private val _state: MutableStateFlow<AttemptUiState>
    val state: StateFlow<AttemptUiState>

    init {
        settle()
        _state = MutableStateFlow(build())
        state = _state.asStateFlow()
    }

    val isSubmitted: Boolean get() = session.phase == SessionPhase.Submitted

    // ---------- Làm bài ----------

    /** Chạm lựa chọn ở vị trí hiển thị `position`: chọn; chạm lại lựa chọn đang chọn thì bỏ chọn (như phím A–Z của macOS). */
    override fun toggleOption(position: Int) = command {
        val q = session.currentQuestion
        val id = session.currentItem.optionOrder.getOrNull(position) ?: return@command
        val selected = session.answers[q.id]
        if (q.type == QuestionType.SINGLE && selected == setOf(id)) session.clearAnswer() else session.select(id)
    }

    override fun next() = command { session.next() }

    override fun previous() = command { session.previous() }

    override fun goTo(index: Int) = command { session.goTo(index) }

    override fun toggleFlag() = command { session.toggleFlag() }

    override fun checkAnswer() = command { session.checkAnswer() }

    override fun pause() = command { session.pause(PauseReason.USER) }

    override fun resume() = command { session.resume() }

    override fun openReview() = command { session.openReview() }

    /** Quay lại làm bài từ Rà soát (chưa khoá), tại câu `index` nếu có. */
    override fun returnToAttempt(index: Int?) = command { session.returnToAttempt(index) }

    override fun dismissBanner(id: Int) {
        if (banner?.id == id) {
            banner = null
            publish()
        }
    }

    /** Gọi định kỳ khi màn hình đang hiện: đồng hồ, cảnh báo 5/1 phút, hết giờ chuyển ngay sang Rà soát khoá. */
    fun tick() {
        val before = session.phase
        val events = session.tick()
        for (event in events) {
            val kind = when (event) {
                is SessionEvent.Warning -> SessionBanner.Kind.TimeWarning(event.minutesLeft)
                SessionEvent.TimeUp -> SessionBanner.Kind.TimeUp
            }
            banner = SessionBanner(nextBannerId++, kind)
        }
        settle()
        if (events.isNotEmpty() || session.phase != before) {
            publish()
        } else {
            val clock = AttemptPresentation.clock(session)
            if (clock != _state.value.clock) _state.update { it.copy(clock = clock) }
        }
    }

    /**
     * App xuống nền (mobile.md): đang làm hay rà soát chưa khoá thì tạm dừng; chưa nộp thì lưu phiên dở. Không gọi khi chỉ
     * xoay màn hình (Activity dựng lại, model giữ nguyên).
     */
    fun onBackground() {
        if (discarded) return
        if (session.phase == SessionPhase.InProgress || session.phase == SessionPhase.Reviewing(false)) {
            command { session.pause(PauseReason.BACKGROUND) }
        }
        if (!isSubmitted) {
            // Chụp ngay: lệnh ghi chạy sau, khi đó phiên có thể đã được nộp.
            val snapshot = session.snapshot()
            write { store.saveDraft(snapshot) }
        }
    }

    /** Bỏ bài: không lưu gì, xoá phiên dở (exam-taking.md, mobile.md). */
    override fun discard() {
        if (isSubmitted || discarded) return
        discarded = true
        write { store.clearDraft() }
    }

    // ---------- Nộp, Kết quả ----------

    /** Nộp bài (Rà soát). Hỏi "Còn N câu chưa làm" là việc của giao diện (`ReviewSummary.needsSubmitConfirmation`). */
    override fun submit() {
        command { session.submit() }
        if (!isSubmitted || reviewItems != null) return
        reviewItems = ReviewItems(AttemptPayload.from(session, QuestionFingerprint.fingerprints(session.exam)), session.exam)
        banner = null
        publish()
        write {
            previousPercent = try {
                store.previousPercent(session.exam.id, session.mode)
            } catch (e: CancellationException) {
                throw e
            } catch (_: Exception) {
                null
            }
            saveState = try {
                store.saveAttempt(session)
                SaveState.SAVED
            } catch (e: CancellationException) {
                throw e
            } catch (_: Exception) {
                SaveState.FAILED
            }
            publish()
        }
    }

    /** **Làm lại**: cùng cách chọn câu và xáo, seed mới. */
    override fun retake(): NextAttempt? {
        if (!isSubmitted) return null
        return NextAttempt(examId, session.mode, session.retakeOptions(newSeed()), session.timeLimitMinutes, session.candidateName, false)
    }

    /** **Luyện lại câu sai**: null khi không còn câu sai hay đề ẩn đáp án. */
    override fun practiceIncorrect(): NextAttempt? {
        val options = session.practiceIncorrectOptions(newSeed()) ?: return null
        return NextAttempt(examId, SessionMode.PRACTICE, options, null, session.candidateName, true)
    }

    // ---------- Xem lại bài ----------

    /** Mở Xem lại từ Kết quả: **Xem lại bài** (Tất cả) hoặc **Xem câu sai** (Sai). */
    override fun openAnswerReview(filter: ReviewFilter) {
        if (reviewItems == null) return
        answerReview = true
        reviewFilter = filter
        reviewIndex = null
        publish()
    }

    override fun setReviewFilter(filter: ReviewFilter) {
        reviewFilter = filter
        reviewIndex = null
        publish()
    }

    override fun openReviewQuestion(index: Int) {
        reviewIndex = index
        publish()
    }

    /** Câu trước / sau trong bộ lọc đang chọn. */
    override fun stepReviewQuestion(delta: Int) {
        val items = reviewItems ?: return
        val current = reviewIndex ?: return
        val indices = items.indices(reviewFilter)
        val position = indices.indexOf(current)
        indices.getOrNull(position + delta)?.let {
            reviewIndex = it
            publish()
        }
    }

    /** Quay lại một bậc: chi tiết → danh sách → Kết quả. Trả false khi đã ở Kết quả. */
    override fun backFromAnswerReview(): Boolean {
        when {
            reviewIndex != null -> reviewIndex = null
            answerReview -> answerReview = false
            else -> return false
        }
        publish()
        return true
    }

    // ---------- Nội bộ ----------

    private fun command(block: () -> Unit) {
        if (discarded) return
        try {
            block()
        } catch (_: SessionException) {
            // Lệnh không hợp lệ ở trạng thái hiện tại (nút đã tắt; bấm đúng lúc hết giờ): phiên giữ nguyên.
        }
        settle()
        publish()
    }

    /** Hết giờ chuyển **ngay** sang Rà soát khoá (exam-taking.md phương án 10), kể cả phiên dở khôi phục ở trạng thái hết giờ. */
    private fun settle() {
        if (session.phase == SessionPhase.TimeUp) {
            try {
                session.openReview()
            } catch (_: SessionException) {
            }
        }
    }

    /**
     * Lỗi ghi phiên dở (đầy bộ nhớ, kho hỏng) không được làm app dừng: phiên trong bộ nhớ vẫn còn. Lưu lần thi tự bắt lỗi
     * để báo trên Kết quả.
     */
    private fun write(block: suspend () -> Unit) {
        storeScope.launch {
            writeLock.withLock {
                try {
                    block()
                } catch (e: CancellationException) {
                    throw e
                } catch (_: Exception) {
                }
            }
        }
    }

    private fun publish() {
        _state.value = build()
    }

    private fun build(): AttemptUiState {
        val screen: AttemptScreen = when (session.phase) {
            SessionPhase.InProgress -> AttemptScreen.Answering(
                question = AttemptPresentation.question(session),
                answeredCount = AttemptPresentation.answeredCount(session),
                canCheckAnswer = AttemptPresentation.canCheckAnswer(session),
                isFirst = session.currentIndex == 0,
                isLast = session.currentIndex == session.questionCount - 1,
                announcement = AttemptPresentation.announcement(session),
            )
            SessionPhase.Paused -> AttemptScreen.Paused(AttemptPresentation.pauseReason(session) ?: PauseReason.USER)
            SessionPhase.TimeUp, is SessionPhase.Reviewing -> AttemptScreen.Review(AttemptPresentation.reviewSummary(session))
            SessionPhase.Submitted -> {
                val items = reviewItems
                if (answerReview && items != null) {
                    AttemptScreen.AnswerReview(answerReviewState(items))
                } else {
                    AttemptScreen.Results(AttemptPresentation.results(session, previousPercent, saveState))
                }
            }
        }
        val showsNavigator = screen is AttemptScreen.Answering || screen is AttemptScreen.Review
        return AttemptUiState(
            examTitle = session.exam.title,
            mode = session.mode,
            clock = AttemptPresentation.clock(session),
            banner = banner,
            navigator = if (showsNavigator) AttemptPresentation.navigator(session) else emptyList(),
            screen = screen,
        )
    }

    private fun answerReviewState(items: ReviewItems): AnswerReviewState {
        val indices = items.indices(reviewFilter)
        val rows = indices.map { index ->
            ReviewRow(index, index + 1, items.outcome(index), items.isFlagged(index), items.changes[index], items.preview(index))
        }
        val selected = reviewIndex
        return AnswerReviewState(
            filter = reviewFilter,
            counts = ReviewFilter.entries.associateWith { items.count(it) },
            rows = rows,
            detail = selected?.let { items.detail(it) },
            positionInFilter = selected?.let { indices.indexOf(it).takeIf { p -> p >= 0 } },
            answersHidden = items.answersHidden,
            canPracticeIncorrect = session.practiceIncorrectOptions(0u) != null,
        )
    }
}
