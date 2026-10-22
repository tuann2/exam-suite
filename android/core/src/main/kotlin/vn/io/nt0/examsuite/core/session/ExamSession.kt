package vn.io.nt0.examsuite.core.session

import vn.io.nt0.examsuite.core.composer.CompositionOptions
import vn.io.nt0.examsuite.core.composer.ExamPaper
import vn.io.nt0.examsuite.core.composer.PaperItem
import vn.io.nt0.examsuite.core.composer.QuestionSelection
import vn.io.nt0.examsuite.core.model.Exam
import vn.io.nt0.examsuite.core.model.OptionId
import vn.io.nt0.examsuite.core.model.Question
import vn.io.nt0.examsuite.core.model.QuestionType
import vn.io.nt0.examsuite.core.scoring.AnswerSheet
import vn.io.nt0.examsuite.core.scoring.ScoreResult
import vn.io.nt0.examsuite.core.scoring.Scorer
import java.time.Instant
import java.util.UUID

/**
 * Trạng thái so sánh được của phiên (mọi thứ trừ đồng hồ tiêm vào). Test "lệnh bị từ chối giữ nguyên phiên" so hai giá
 * trị này; `SessionSnapshot` (phiên dở) dựng từ đây.
 */
data class SessionState(
    val phase: SessionPhase,
    val currentIndex: Int,
    val answers: AnswerSheet,
    val flagged: Set<UUID>,
    val checkedQuestionIds: Set<UUID>,
    val pauseReason: PauseReason?,
    val result: ScoreResult?,
    val submittedAt: Instant?,
    val accumulated: Double,
    val runningSince: Double?,
    val phaseBeforePause: SessionPhase?,
    val issuedWarnings: Set<Int>,
    val pendingEvents: List<SessionEvent>,
)

/**
 * Phiên dở để lưu khi app xuống nền và khôi phục sau (mobile.md, Q7). Đồng hồ không chạy trong snapshot:
 * `elapsedSeconds` là thời gian đã làm tại lúc chụp.
 */
data class SessionSnapshot(
    val examId: UUID,
    val paper: ExamPaper,
    val mode: SessionMode,
    val timeLimitMinutes: Int?,
    val candidateName: String,
    val startedAt: Instant,
    val phase: SessionPhase,
    val currentIndex: Int,
    val answers: AnswerSheet,
    val flagged: Set<UUID>,
    val checkedQuestionIds: Set<UUID>,
    val pauseReason: PauseReason?,
    val elapsedSeconds: Double,
    val phaseBeforePause: SessionPhase?,
    val issuedWarnings: Set<Int>,
    val pendingEvents: List<SessionEvent>,
)

/**
 * Phiên thi: máy trạng thái theo docs/product/exam-session.md (thẩm quyền), cùng hành vi với `ExamSession` của bản macOS
 * (test viết theo danh sách tình huống của `ExamSessionTests`). Không Timer, không luồng nền: mỗi lệnh đọc đồng hồ một
 * lần; giao diện gọi `tick()` định kỳ.
 *
 * Mọi lệnh đối chiếu đồng hồ trước, kể cả lệnh rồi bị từ chối: cảnh báo đã tới mốc được ghi nhận; đã quá giờ thì phiên
 * sang `TimeUp` và chính lệnh bị từ chối với phase `TimeUp` (kể cả `openReview`). Sự kiện ghi nhận lúc đó trả ở `tick()`
 * kế tiếp; sau khi nộp thì bỏ.
 */
class ExamSession private constructor(
    val exam: Exam,
    val paper: ExamPaper,
    val mode: SessionMode,
    /** Thời hạn (phút) của phiên Thi; null ở Luyện tập. */
    val timeLimitMinutes: Int?,
    val candidateName: String,
    /** Giờ hệ thống lúc tạo phiên; chỉ để ghi lại. */
    val startedAt: Instant,
    private val clock: SessionClock,
    private val questionsById: Map<UUID, Question>,
    private var s: SessionState,
) {
    val phase: SessionPhase get() = s.phase
    val currentIndex: Int get() = s.currentIndex
    val answers: AnswerSheet get() = s.answers
    val flagged: Set<UUID> get() = s.flagged
    val checkedQuestionIds: Set<UUID> get() = s.checkedQuestionIds
    val pauseReason: PauseReason? get() = s.pauseReason
    val result: ScoreResult? get() = s.result
    val submittedAt: Instant? get() = s.submittedAt

    /** Toàn bộ trạng thái so sánh được (cho test và phiên dở). */
    val state: SessionState get() = s

    val currentItem: PaperItem get() = paper.items[s.currentIndex]
    val currentQuestion: Question get() = question(currentItem)

    fun question(item: PaperItem): Question = questionsById.getValue(item.questionId)

    val questionCount: Int get() = paper.items.size

    fun isAnswered(questionId: UUID): Boolean = !s.answers[questionId].isNullOrEmpty()

    val unansweredCount: Int get() = paper.items.count { !isAnswered(it.questionId) }

    val flaggedCount: Int get() = s.flagged.size

    val isClockRunning: Boolean get() = s.runningSince != null

    /** Thời gian đã làm, giây; Thi không vượt thời hạn. */
    val elapsed: Double get() = elapsedAt(clock.uptimeSeconds())

    /** Thời gian còn lại, giây, không âm; null ở Luyện tập. */
    val remaining: Double? get() = timeLimit?.let { maxOf(0.0, it - elapsed) }

    /** "Luyện lại câu sai": câu sai/chưa làm theo thứ tự phiên, không xáo; null nếu chưa nộp, hết câu sai hay đề `hideAnswers`. */
    fun practiceIncorrectOptions(seed: ULong): CompositionOptions? {
        val result = s.result ?: return null
        if (exam.hideAnswers) return null
        val ids = result.incorrectOrUnansweredIds
        if (ids.isEmpty()) return null
        return CompositionOptions(QuestionSelection.Questions(ids), shuffleQuestions = false, shuffleOptions = false, seed = seed)
    }

    /** "Làm lại": giữ cách chọn câu và xáo, thay seed (truyền seed cũ để tái hiện đúng đề). */
    fun retakeOptions(seed: ULong): CompositionOptions = paper.options.copy(seed = seed)

    // ---------- Lệnh: trả lời, đánh dấu, điều hướng ----------

    fun select(option: OptionId) {
        syncClock(clock.uptimeSeconds())
        require(SessionCommand.SELECT, s.phase == SessionPhase.InProgress)
        val q = currentQuestion
        if (q.id in s.checkedQuestionIds) throw SessionException.AnswerLocked(q.id)
        if (q.options.none { it.id == option }) throw SessionException.UnknownOption(option)
        val updated = s.answers.toMutableMap()
        when (q.type) {
            QuestionType.SINGLE -> updated[q.id] = setOf(option)
            QuestionType.MULTIPLE -> {
                val set = (updated[q.id] ?: emptySet()).toMutableSet()
                if (!set.remove(option)) set += option
                if (set.isEmpty()) updated.remove(q.id) else updated[q.id] = set
            }
        }
        s = s.copy(answers = updated)
    }

    fun clearAnswer() {
        syncClock(clock.uptimeSeconds())
        require(SessionCommand.CLEAR_ANSWER, s.phase == SessionPhase.InProgress)
        val id = currentItem.questionId
        if (id in s.checkedQuestionIds) throw SessionException.AnswerLocked(id)
        s = s.copy(answers = s.answers - id)
    }

    /** Được cả khi đáp án đã khoá sau Kiểm tra đáp án. */
    fun toggleFlag() {
        syncClock(clock.uptimeSeconds())
        require(SessionCommand.TOGGLE_FLAG, s.phase == SessionPhase.InProgress)
        val id = currentItem.questionId
        s = s.copy(flagged = if (id in s.flagged) s.flagged - id else s.flagged + id)
    }

    fun goTo(index: Int) {
        syncClock(clock.uptimeSeconds())
        require(SessionCommand.GO_TO, s.phase == SessionPhase.InProgress)
        if (index !in paper.items.indices) throw SessionException.IndexOutOfRange(index, paper.items.size)
        s = s.copy(currentIndex = index)
    }

    /** Ở câu cuối thì đứng yên. */
    fun next() {
        syncClock(clock.uptimeSeconds())
        require(SessionCommand.NEXT, s.phase == SessionPhase.InProgress)
        s = s.copy(currentIndex = minOf(s.currentIndex + 1, paper.items.size - 1))
    }

    /** Ở câu đầu thì đứng yên. */
    fun previous() {
        syncClock(clock.uptimeSeconds())
        require(SessionCommand.PREVIOUS, s.phase == SessionPhase.InProgress)
        s = s.copy(currentIndex = maxOf(s.currentIndex - 1, 0))
    }

    /** Chỉ Luyện tập, khi đang làm: chấm câu hiện tại và khoá đáp án câu đó; gọi lại trả cùng kết quả. */
    fun checkAnswer(): AnswerCheck {
        syncClock(clock.uptimeSeconds())
        if (mode != SessionMode.PRACTICE) throw SessionException.UnavailableInMode(SessionCommand.CHECK_ANSWER, mode)
        require(SessionCommand.CHECK_ANSWER, s.phase == SessionPhase.InProgress)
        val q = currentQuestion
        val selected = s.answers[q.id]
        if (selected.isNullOrEmpty()) throw SessionException.NoAnswerToCheck(q.id)
        s = s.copy(checkedQuestionIds = s.checkedQuestionIds + q.id)
        return AnswerCheck(q.id, Scorer.outcome(q, selected), q.correctSet, q.explanation)
    }

    // ---------- Tạm dừng ----------

    fun pause(reason: PauseReason) {
        val t = clock.uptimeSeconds()
        syncClock(t)
        require(SessionCommand.PAUSE, s.phase == SessionPhase.InProgress || s.phase == SessionPhase.Reviewing(false))
        s = s.copy(phaseBeforePause = s.phase, pauseReason = reason)
        setPhase(SessionPhase.Paused, t)
    }

    fun resume() {
        val t = clock.uptimeSeconds()
        syncClock(t)
        require(SessionCommand.RESUME, s.phase == SessionPhase.Paused)
        val target = s.phaseBeforePause ?: SessionPhase.InProgress
        s = s.copy(phaseBeforePause = null, pauseReason = null)
        setPhase(target, t)
    }

    // ---------- Rà soát và nộp ----------

    fun openReview() {
        val t = clock.uptimeSeconds()
        if (syncClock(t)) throw SessionException.InvalidCommand(SessionCommand.OPEN_REVIEW, s.phase)
        when (s.phase) {
            SessionPhase.InProgress -> setPhase(SessionPhase.Reviewing(false), t)
            SessionPhase.TimeUp -> setPhase(SessionPhase.Reviewing(true), t)
            else -> throw SessionException.InvalidCommand(SessionCommand.OPEN_REVIEW, s.phase)
        }
    }

    fun returnToAttempt(index: Int? = null) {
        val t = clock.uptimeSeconds()
        syncClock(t)
        require(SessionCommand.RETURN_TO_ATTEMPT, s.phase == SessionPhase.Reviewing(false))
        if (index != null) {
            if (index !in paper.items.indices) throw SessionException.IndexOutOfRange(index, paper.items.size)
            s = s.copy(currentIndex = index)
        }
        setPhase(SessionPhase.InProgress, t)
    }

    fun submit() {
        val t = clock.uptimeSeconds()
        syncClock(t)
        if (s.phase !is SessionPhase.Reviewing) throw SessionException.InvalidCommand(SessionCommand.SUBMIT, s.phase)
        val scored = Scorer.score(exam, paper.questionIds, s.answers)
        setPhase(SessionPhase.Submitted, t)
        s = s.copy(result = scored, submittedAt = clock.now(), pendingEvents = emptyList())
    }

    // ---------- Đồng hồ ----------

    /** Sự kiện mới theo thứ tự; không bao giờ ném. Tick thưa nhảy qua mốc vẫn phát đủ (5 rồi 1); đã hết giờ thì chỉ `TimeUp`. */
    fun tick(): List<SessionEvent> {
        syncClock(clock.uptimeSeconds())
        val events = s.pendingEvents
        s = s.copy(pendingEvents = emptyList())
        return events
    }

    // ---------- Phiên dở (mobile) ----------

    /** Chụp phiên dở để lưu. Phiên đã nộp không cần lưu dở (lưu thành lần thi). */
    fun snapshot(): SessionSnapshot {
        val t = clock.uptimeSeconds()
        syncClock(t)
        if (s.phase == SessionPhase.Submitted) throw SessionException.InvalidCommand(SessionCommand.PAUSE, s.phase)
        return SessionSnapshot(
            examId = exam.id, paper = paper, mode = mode, timeLimitMinutes = timeLimitMinutes, candidateName = candidateName,
            startedAt = startedAt, phase = s.phase, currentIndex = s.currentIndex, answers = s.answers, flagged = s.flagged,
            checkedQuestionIds = s.checkedQuestionIds, pauseReason = s.pauseReason, elapsedSeconds = elapsedAt(t),
            phaseBeforePause = s.phaseBeforePause, issuedWarnings = s.issuedWarnings, pendingEvents = s.pendingEvents,
        )
    }

    private val timeLimit: Double? get() = timeLimitMinutes?.let { it * 60.0 }

    private fun elapsedAt(t: Double): Double {
        val raw = rawElapsedAt(t)
        return timeLimit?.let { minOf(raw, it) } ?: raw
    }

    private fun rawElapsedAt(t: Double): Double = s.runningSince?.let { s.accumulated + maxOf(0.0, t - it) } ?: s.accumulated

    private fun setPhase(newPhase: SessionPhase, t: Double) {
        val shouldRun = clockRuns(newPhase)
        s = when {
            shouldRun && s.runningSince == null -> s.copy(runningSince = t)
            !shouldRun && s.runningSince != null -> s.copy(accumulated = elapsedAt(t), runningSince = null)
            else -> s
        }
        s = s.copy(phase = newPhase)
    }

    /** Thi, đồng hồ chạy: phát cảnh báo chưa phát, chuyển `TimeUp` nếu hết giờ. Trả true nếu lần này chuyển sang `TimeUp`. */
    private fun syncClock(t: Double): Boolean {
        val limit = timeLimit ?: return false
        if (s.runningSince == null) return false
        val used = rawElapsedAt(t)
        if (used >= limit) {
            s = s.copy(accumulated = limit, runningSince = null, phase = SessionPhase.TimeUp, pendingEvents = s.pendingEvents + SessionEvent.TimeUp)
            return true
        }
        val left = limit - used
        for (minutes in WARNING_MINUTES) {
            if (minutes in s.issuedWarnings) continue
            val threshold = minutes * 60.0
            if (limit > threshold && left <= threshold) {
                s = s.copy(issuedWarnings = s.issuedWarnings + minutes, pendingEvents = s.pendingEvents + SessionEvent.Warning(minutes))
            }
        }
        return false
    }

    private fun require(command: SessionCommand, allowed: Boolean) {
        if (!allowed) throw SessionException.InvalidCommand(command, s.phase)
    }

    companion object {
        val TIME_LIMIT_RANGE = 1..600
        val WARNING_MINUTES = listOf(5, 1)

        private fun clockRuns(phase: SessionPhase) = phase == SessionPhase.InProgress || phase == SessionPhase.Reviewing(false)

        /** Câu của đề đã tạo, kiểm theo thứ tự như bản macOS (lấy lần đầu nếu đề có id trùng). */
        private fun questionsFor(exam: Exam, paper: ExamPaper): Map<UUID, Question> {
            if (paper.examId != exam.id) throw SessionException.PaperExamMismatch(paper.examId, exam.id)
            if (paper.items.isEmpty()) throw SessionException.EmptyPaper
            val lookup = HashMap<UUID, Question>()
            for (q in exam.allQuestions) if (q.id !in lookup) lookup[q.id] = q
            val seen = HashSet<UUID>()
            val used = HashMap<UUID, Question>()
            for (item in paper.items) {
                val q = lookup[item.questionId] ?: throw SessionException.UnknownQuestion(item.questionId)
                if (!seen.add(item.questionId)) throw SessionException.DuplicateQuestion(item.questionId)
                used[q.id] = q
            }
            return used
        }

        /**
         * Tạo phiên và bắt đầu ngay: `InProgress`, câu đầu, đồng hồ chạy. Lỗi kiểm theo thứ tự: `PaperExamMismatch`,
         * `EmptyPaper`, `PracticeNotAllowed`, `UnknownQuestion`, `DuplicateQuestion`, `InvalidTimeLimit`.
         * @param timeLimitMinutes thời hạn Thi người dùng đổi; null → của đề. Bỏ qua ở Luyện tập.
         */
        fun start(
            exam: Exam,
            paper: ExamPaper,
            mode: SessionMode,
            timeLimitMinutes: Int?,
            candidateName: String,
            clock: SessionClock,
        ): ExamSession {
            if (paper.examId != exam.id) throw SessionException.PaperExamMismatch(paper.examId, exam.id)
            if (paper.items.isEmpty()) throw SessionException.EmptyPaper
            if (mode == SessionMode.PRACTICE && exam.hideAnswers) throw SessionException.PracticeNotAllowed
            val used = questionsFor(exam, paper)
            val minutes = when (mode) {
                SessionMode.PRACTICE -> null
                SessionMode.EXAM -> {
                    val value = timeLimitMinutes?.toLong() ?: exam.timeLimitMinutes
                    if (value !in TIME_LIMIT_RANGE.first.toLong()..TIME_LIMIT_RANGE.last.toLong()) {
                        throw SessionException.InvalidTimeLimit(value.coerceIn(Int.MIN_VALUE.toLong(), Int.MAX_VALUE.toLong()).toInt())
                    }
                    value.toInt()
                }
            }
            val now = clock.now()
            val t = clock.uptimeSeconds()
            return ExamSession(
                exam, paper, mode, minutes, candidateName, now, clock, used,
                SessionState(
                    phase = SessionPhase.InProgress, currentIndex = 0, answers = emptyMap(), flagged = emptySet(),
                    checkedQuestionIds = emptySet(), pauseReason = null, result = null, submittedAt = null,
                    accumulated = 0.0, runningSince = t, phaseBeforePause = null, issuedWarnings = emptySet(),
                    pendingEvents = emptyList(),
                ),
            )
        }

        /**
         * Khôi phục phiên dở (mobile.md, Q7): phiên đang chạy (làm bài, rà soát chưa khoá) về **Tạm dừng** với lý do
         * `BACKGROUND`, đúng câu, đúng đáp án, thời gian đã làm như lúc chụp; phiên đang tạm dừng, hết giờ hay rà soát khoá
         * giữ nguyên trạng thái. Đề phải là đề của phiên (cùng id, mọi câu còn đó, lựa chọn còn đó); không thì
         * `InvalidSnapshot` và app bỏ phiên dở.
         */
        fun restore(exam: Exam, snapshot: SessionSnapshot, clock: SessionClock): ExamSession {
            fun invalid(reason: String): Nothing = throw SessionException.InvalidSnapshot(reason)
            if (snapshot.examId != exam.id) invalid("id đề khác")
            val used = try {
                questionsFor(exam, snapshot.paper)
            } catch (e: SessionException) {
                invalid(e.message ?: "")
            }
            if (snapshot.mode == SessionMode.PRACTICE && exam.hideAnswers) invalid("đề hideAnswers khoá Luyện tập")
            if (snapshot.mode == SessionMode.EXAM && snapshot.timeLimitMinutes !in TIME_LIMIT_RANGE) invalid("thời hạn sai")
            if (snapshot.mode == SessionMode.PRACTICE && snapshot.timeLimitMinutes != null) invalid("Luyện tập có thời hạn")
            if (snapshot.currentIndex !in snapshot.paper.items.indices) invalid("vị trí câu sai")
            if (snapshot.phase == SessionPhase.Submitted) invalid("phiên đã nộp")
            for (item in snapshot.paper.items) {
                val ids = used.getValue(item.questionId).options.map { it.id }.toSet()
                if (item.optionOrder.toSet() != ids || item.optionOrder.size != ids.size) invalid("lựa chọn của câu ${item.questionId} đã đổi")
            }
            for ((id, selected) in snapshot.answers) {
                val q = used[id] ?: invalid("đáp án của câu ngoài đề")
                if (selected.isEmpty() || !q.options.map { it.id }.toSet().containsAll(selected)) invalid("đáp án câu $id sai")
            }
            if (!used.keys.containsAll(snapshot.flagged) || !used.keys.containsAll(snapshot.checkedQuestionIds)) invalid("câu ngoài đề")
            val limit = snapshot.timeLimitMinutes?.let { it * 60.0 }
            if (snapshot.elapsedSeconds < 0 || (limit != null && snapshot.elapsedSeconds > limit)) invalid("thời gian đã làm sai")

            val running = clockRuns(snapshot.phase)
            val state = SessionState(
                phase = if (running) SessionPhase.Paused else snapshot.phase,
                currentIndex = snapshot.currentIndex,
                answers = snapshot.answers,
                flagged = snapshot.flagged,
                checkedQuestionIds = snapshot.checkedQuestionIds,
                pauseReason = if (running) PauseReason.BACKGROUND else snapshot.pauseReason,
                result = null,
                submittedAt = null,
                accumulated = snapshot.elapsedSeconds,
                runningSince = null,
                phaseBeforePause = if (running) snapshot.phase else snapshot.phaseBeforePause,
                issuedWarnings = snapshot.issuedWarnings,
                pendingEvents = snapshot.pendingEvents,
            )
            return ExamSession(exam, snapshot.paper, snapshot.mode, snapshot.timeLimitMinutes, snapshot.candidateName,
                snapshot.startedAt, clock, used, state)
        }
    }
}
