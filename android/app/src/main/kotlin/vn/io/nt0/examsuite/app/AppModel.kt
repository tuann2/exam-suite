package vn.io.nt0.examsuite.app

import android.app.Application
import android.net.Uri
import android.os.Build
import android.os.Process
import android.os.SystemClock
import android.util.Log
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import vn.io.nt0.examsuite.attempt.AppScope
import vn.io.nt0.examsuite.attempt.AttemptModel
import vn.io.nt0.examsuite.attempt.AttemptPresentation
import vn.io.nt0.examsuite.attempt.LibraryAttemptStore
import vn.io.nt0.examsuite.attempt.NextAttempt
import vn.io.nt0.examsuite.attempt.PastAttemptModel
import vn.io.nt0.examsuite.attempt.ReviewAvailability
import vn.io.nt0.examsuite.attempt.Timing
import vn.io.nt0.examsuite.attempt.randomSeed
import vn.io.nt0.examsuite.attempt.ui.QuestionImages
import vn.io.nt0.examsuite.core.composer.CompositionException
import vn.io.nt0.examsuite.core.composer.ExamComposer
import vn.io.nt0.examsuite.core.file.ExamFileError
import vn.io.nt0.examsuite.core.model.Exam
import vn.io.nt0.examsuite.core.session.ExamSession
import vn.io.nt0.examsuite.core.session.SessionException
import vn.io.nt0.examsuite.core.session.SessionMode
import vn.io.nt0.examsuite.data.db.LibraryStoreException
import vn.io.nt0.examsuite.data.library.AttemptSummary
import vn.io.nt0.examsuite.data.library.DraftRecord
import vn.io.nt0.examsuite.data.library.ExamLibrary
import vn.io.nt0.examsuite.data.library.ImportProblem
import vn.io.nt0.examsuite.data.library.ImportResult
import vn.io.nt0.examsuite.data.library.LibraryItem
import vn.io.nt0.examsuite.data.library.LibrarySort
import vn.io.nt0.examsuite.data.library.PendingImport
import vn.io.nt0.examsuite.data.settings.Settings
import vn.io.nt0.examsuite.pre.PreExamForm
import java.io.IOException
import java.util.UUID

private const val TAG = "ExamSuite"

/** Số đo mở app chỉ ghi một lần mỗi tiến trình (AppModel mới trong tiến trình cũ không phải lần mở app). */
private var readyReported = false

/** Màn đang hiện; ngăn xếp có Thư viện ở đáy. */
sealed interface Route {
    data object Library : Route

    /** Lịch sử thi, lọc theo một đề khi `examId` có (Xem lịch sử thi). */
    data class History(val examId: UUID?, val examTitle: String?) : Route

    class Attempt(val model: AttemptModel, val images: QuestionImages) : Route

    class PastAttempt(val model: PastAttemptModel, val images: QuestionImages) : Route
}

/** Đề định bắt đầu: từ thẻ đề (chế độ yêu cầu hay lần trước), mở `.exam` từ app khác, Làm lại, Luyện lại câu sai. */
data class StartTarget(val examId: UUID, val mode: SessionMode?, val next: NextAttempt?)

sealed interface StartError {
    data class Unreadable(val error: ExamFileError) : StartError

    /** Lựa chọn không còn hợp với đề vừa đọc lại (phần, câu đã xoá). */
    data object Changed : StartError

    data object Failed : StartError
}

data class PreExamUi(val examId: UUID, val form: PreExamForm, val starting: Boolean = false, val startError: StartError? = null)

sealed interface AppDialog {
    /** Đã có đề cùng id (mobile.md): **Cập nhật đề** / **Huỷ**; đề đang có bài dở thì báo bài dở sẽ bị bỏ. */
    class UpdateConfirm(val existing: LibraryItem, val pending: PendingImport, val dropsDraft: Boolean, val openAfter: Boolean) : AppDialog

    /** Mỗi lúc một phiên (mobile.md): **Tiếp tục đề A** / **Bỏ bài và làm đề B** / **Huỷ**. */
    data class Conflict(val currentTitle: String, val targetTitle: String, val target: StartTarget) : AppDialog

    data class ImportRejected(val problem: ImportProblem) : AppDialog

    /** Không mở được đề để làm bài: không còn trong Thư viện (`error` null) hoặc không đọc nghiêm được. */
    data class OpenFailed(val error: ExamFileError?) : AppDialog

    /** Kho Thư viện bị hỏng và đã được tạo lại (library.md, Lưu trữ). */
    data object StoreRecovered : AppDialog
}

sealed interface Notice {
    val id: Int

    data class Removed(override val id: Int, val examId: UUID, val title: String) : Notice

    data class Added(override val id: Int, val title: String, val updated: Boolean) : Notice
}

data class AppState(
    val ready: Boolean = false,
    /** Không mở được kho (lỗi tạm thời: đầy bộ nhớ…). */
    val failed: Boolean = false,
    val stack: List<Route> = listOf(Route.Library),
    val query: String = "",
    val preExam: PreExamUi? = null,
    val dialog: AppDialog? = null,
    val notice: Notice? = null,
) {
    val route: Route get() = stack.last()
}

/**
 * Điều phối của app (một Activity): mở kho, dọn và tạo đề mẫu lúc mở, khôi phục phiên dở, nhận `.exam` từ app khác,
 * Trước khi thi, mỗi lúc một phiên, Lịch sử thi. Màn làm bài là `AttemptModel`; giữ qua xoay màn hình vì đây là ViewModel.
 */
class AppModel(app: Application) : AndroidViewModel(app) {
    private val services = (app as ExamSuiteApplication).services
    private lateinit var library: ExamLibrary

    private val _state = MutableStateFlow(AppState())
    val state: StateFlow<AppState> = _state.asStateFlow()

    val items = MutableStateFlow<List<LibraryItem>>(emptyList())
    val history = MutableStateFlow<List<AttemptSummary>>(emptyList())
    val settings = MutableStateFlow<Settings?>(null)

    /** Đề có phiên dở đã lưu mà chưa mở lại (mở `.exam` khác lúc mở app, hay chọn Huỷ ở hộp hỏi). */
    private var draftExamId: UUID? = null
    private val pendingIncoming = mutableListOf<Uri>()
    private var nextNoticeId = 1

    init {
        viewModelScope.launch { startUp() }
    }

    /** Activity đang hiện (giữa ON_START và ON_STOP, không tính xoay màn hình); `MainActivity` cập nhật. */
    @Volatile
    var inForeground = false

    private val activeAttempt: AttemptModel?
        get() = (_state.value.route as? Route.Attempt)?.model?.takeIf { !it.isSubmitted }

    private suspend fun startUp() {
        val opened = try {
            services.library()
        } catch (_: LibraryStoreException) {
            _state.update { it.copy(failed = true) }
            return
        }
        library = opened.library
        library.recoverOnStart()
        library.purgeRemoved()
        if (!services.settings.current().samplesSeeded) {
            library.seedSamples(services.samples)
            services.settings.markSamplesSeeded()
        }
        viewModelScope.launch { library.items().collect { items.value = it } }
        viewModelScope.launch { library.history().collect { history.value = it } }
        viewModelScope.launch { services.settings.settings.collect { settings.value = it } }
        val draft = library.loadDraft()
        draftExamId = draft?.examId
        _state.update { it.copy(ready = true, dialog = if (opened.recoveredFrom != null) AppDialog.StoreRecovered else null) }
        if (!readyReported) {
            readyReported = true
            val start = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) Process.getStartRequestedUptimeMillis() else Process.getStartUptimeMillis()
            Timing.record("app.ready", (SystemClock.uptimeMillis() - start).toDouble())
        }
        if (pendingIncoming.isNotEmpty()) {
            val uris = pendingIncoming.toList()
            pendingIncoming.clear()
            uris.forEach { importUri(it, openAfter = true) }
        } else if (draft != null) {
            resumeDraft(draft)
        }
    }

    // ---------- Thêm đề, mở .exam từ app khác ----------

    /** File `.exam` mở từ app khác (Mở bằng, Chia sẻ): thêm vào Thư viện rồi mở Trước khi thi của đề đó. */
    fun receive(uri: Uri) {
        if (!_state.value.ready) pendingIncoming += uri else viewModelScope.launch { importUri(uri, openAfter = true) }
    }

    /** **Thêm đề** (hộp chọn file của hệ điều hành). */
    fun add(uri: Uri) {
        viewModelScope.launch { importUri(uri, openAfter = false) }
    }

    private suspend fun importUri(uri: Uri, openAfter: Boolean) {
        val resolver = getApplication<Application>().contentResolver
        val result = try {
            Timing.measure("library.import") { withContext(Dispatchers.IO) { resolver.openInputStream(uri)?.use { library.import(it) } } }
                ?: ImportResult.Rejected(ImportProblem.Io("không mở được $uri"))
        } catch (e: IOException) {
            ImportResult.Rejected(ImportProblem.Io(e.message ?: e.javaClass.simpleName))
        } catch (e: SecurityException) {
            ImportResult.Rejected(ImportProblem.Io(e.message ?: e.javaClass.simpleName))
        }
        when (result) {
            is ImportResult.Added -> {
                notify { Notice.Added(it, result.item.title, updated = false) }
                if (openAfter) requestStart(StartTarget(result.item.examId, null, null))
            }
            is ImportResult.NeedsUpdateConfirmation -> showDialog(
                AppDialog.UpdateConfirm(result.existing, result.pending, hasDraftFor(result.existing.examId), openAfter),
            )
            is ImportResult.Rejected -> showDialog(AppDialog.ImportRejected(result.problem))
        }
    }

    private fun hasDraftFor(examId: UUID) = draftExamId == examId || activeAttempt?.examId == examId

    /** **Cập nhật đề**: đề có bài dở thì bỏ bài dở (mobile.md, Nt0 chốt 2026-10-22). */
    fun confirmUpdate(dialog: AppDialog.UpdateConfirm) {
        dismissDialog()
        viewModelScope.launch {
            if (dialog.dropsDraft) {
                val active = activeAttempt
                if (active != null && active.examId == dialog.existing.examId) {
                    active.discard()
                    _state.update { it.copy(stack = listOf(Route.Library)) }
                } else {
                    library.clearDraft()
                    draftExamId = null
                }
            }
            val item = library.confirmUpdate(dialog.pending)
            notify { Notice.Added(it, item.title, updated = true) }
            if (dialog.openAfter) requestStart(StartTarget(item.examId, null, null))
        }
    }

    fun cancelUpdate(dialog: AppDialog.UpdateConfirm) {
        dismissDialog()
        viewModelScope.launch { library.discard(dialog.pending) }
    }

    // ---------- Bắt đầu, mỗi lúc một phiên ----------

    /** Mở Trước khi thi; đang có bài dở của đề khác thì hỏi trước (mobile.md). */
    fun requestStart(target: StartTarget) {
        viewModelScope.launch {
            val active = activeAttempt
            val draft = draftExamId
            when {
                active != null && active.examId != target.examId ->
                    showDialog(AppDialog.Conflict(active.state.value.examTitle, titleOf(target.examId), target))
                active != null -> Unit
                draft != null && draft != target.examId -> showDialog(AppDialog.Conflict(titleOf(draft), titleOf(target.examId), target))
                draft != null -> library.loadDraft()?.let { resumeDraft(it) }
                else -> openPreExam(target)
            }
        }
    }

    /** **Tiếp tục đề A**. */
    fun continueCurrent() {
        dismissDialog()
        if (activeAttempt != null) return
        viewModelScope.launch { library.loadDraft()?.let { resumeDraft(it) } }
    }

    /** **Bỏ bài và làm đề B**. */
    fun discardAndStart(target: StartTarget) {
        dismissDialog()
        viewModelScope.launch {
            val active = activeAttempt
            if (active != null) {
                active.discard()
                _state.update { it.copy(stack = listOf(Route.Library)) }
            } else {
                library.clearDraft()
                draftExamId = null
            }
            openPreExam(target)
        }
    }

    private suspend fun titleOf(examId: UUID): String = library.item(examId)?.title ?: ""

    private suspend fun readExam(examId: UUID): Exam? {
        if (library.item(examId) == null) {
            showDialog(AppDialog.OpenFailed(null))
            return null
        }
        return try {
            library.open(examId).exam
        } catch (e: ExamFileError) {
            showDialog(AppDialog.OpenFailed(e))
            null
        }
    }

    private suspend fun openPreExam(target: StartTarget) {
        val exam = Timing.measure("preExam.read") { readExam(target.examId) } ?: return
        val current = services.settings.current()
        val form = target.next?.let { PreExamForm.from(exam, it, current.candidateName) }
            ?: PreExamForm.fresh(exam, target.mode ?: current.lastMode, current.candidateName)
        _state.update { it.copy(preExam = PreExamUi(target.examId, form)) }
    }

    fun updateForm(transform: (PreExamForm) -> PreExamForm) {
        _state.update { s -> s.copy(preExam = s.preExam?.let { it.copy(form = transform(it.form), startError = null) }) }
    }

    fun cancelPreExam() {
        _state.update { it.copy(preExam = null) }
    }

    /** **Bắt đầu**: đọc lại file đề (nghiêm), kiểm lại lựa chọn trên đề vừa đọc, tạo đề với seed mới, tạo phiên. */
    fun startPreExam() {
        val ui = _state.value.preExam ?: return
        if (!ui.form.canStart || ui.starting) return
        _state.update { it.copy(preExam = ui.copy(starting = true, startError = null)) }
        viewModelScope.launch {
            fun fail(error: StartError?, form: PreExamForm = ui.form) =
                _state.update { s -> s.copy(preExam = s.preExam?.copy(form = form, starting = false, startError = error)) }
            val started = System.nanoTime()
            val exam = try {
                Timing.measure("attempt.start.read") { library.open(ui.examId).exam }
            } catch (e: ExamFileError) {
                return@launch fail(StartError.Unreadable(e))
            }
            val form = ui.form.withExam(exam)
            if (!form.canStart) return@launch fail(null, form)
            val session = try {
                Timing.measure("attempt.start.compose") {
                    val paper = ExamComposer.compose(exam, form.options(randomSeed()))
                    ExamSession.start(exam, paper, form.mode, form.sessionTimeLimit(), form.trimmedName, services.clock)
                }
            } catch (_: CompositionException) {
                return@launch fail(StartError.Changed, form)
            } catch (_: SessionException) {
                return@launch fail(StartError.Failed, form)
            }
            services.settings.setCandidateName(form.trimmedName)
            services.settings.setLastMode(form.mode)
            // Đã đóng Trước khi thi trong lúc chờ đọc đề: không bắt đầu.
            if (_state.value.preExam?.starting != true) return@launch
            _state.update { it.copy(preExam = null) }
            Timing.measure("attempt.start.model") { showAttempt(session) }
            Timing.record("attempt.start", (System.nanoTime() - started) / 1e6)
        }
    }

    private fun showAttempt(session: ExamSession) {
        val model = AttemptModel(session, LibraryAttemptStore(library), AppScope, ::randomSeed) { what, e -> Log.w(TAG, "Không $what", e) }
        _state.update { it.copy(stack = listOf(Route.Library, Route.Attempt(model, services.images(library, session.exam.id)))) }
        // Dấu vân tay của mọi câu (đề 2.000 câu: vài trăm ms) tính trước trên nền, để xuống nền và nộp bài không chặn giao
        // diện (A4); phiên khôi phục đã có sẵn.
        viewModelScope.launch(Dispatchers.Default) { Timing.measure("attempt.fingerprints") { session.fingerprints } }
        // App đã xuống nền trong lúc chờ đọc đề: màn làm bài chưa kịp nhận ON_STOP, tạm dừng và lưu ngay (mobile.md).
        if (!inForeground) model.onBackground()
    }

    /** Mở lại phiên dở (mobile.md): về đúng câu ở trạng thái Tạm dừng. Không dùng được thì bỏ. */
    private suspend fun resumeDraft(draft: DraftRecord) = Timing.measure("draft.resume") {
        val snapshot = draft.snapshot
        val exam = if (snapshot != null && library.item(draft.examId) != null) {
            try {
                library.open(draft.examId).exam
            } catch (_: ExamFileError) {
                null
            }
        } else {
            null
        }
        val session = if (exam != null && snapshot != null) {
            withContext(Dispatchers.Default) {
                try {
                    ExamSession.restore(exam, snapshot, services.clock)
                } catch (_: SessionException) {
                    null
                }
            }
        } else {
            null
        }
        draftExamId = null
        if (session == null) library.clearDraft() else showAttempt(session)
    }

    /** Rời màn làm bài (Bỏ bài, Về thư viện). */
    fun exitAttempt() {
        _state.update { it.copy(stack = listOf(Route.Library)) }
    }

    /** **Làm lại** / **Luyện lại câu sai**: về Thư viện rồi mở Trước khi thi điền sẵn. */
    fun startNext(next: NextAttempt) {
        _state.update { it.copy(stack = listOf(Route.Library)) }
        requestStart(StartTarget(next.examId, next.mode, next))
    }

    // ---------- Thư viện ----------

    fun setQuery(query: String) = _state.update { it.copy(query = query) }

    fun setSort(sort: LibrarySort) {
        viewModelScope.launch { services.settings.setSort(sort) }
    }

    fun dismissWelcome() {
        viewModelScope.launch { services.settings.dismissWelcome() }
    }

    /** **Xoá khỏi thư viện**: không hỏi, có **Hoàn tác** (library.md). */
    fun remove(item: LibraryItem) {
        viewModelScope.launch {
            if (library.remove(item.examId)) notify { Notice.Removed(it, item.examId, item.title) }
        }
    }

    fun undoRemove(notice: Notice.Removed) {
        _state.update { it.copy(notice = null) }
        viewModelScope.launch { library.undoRemove(notice.examId) }
    }

    /** Thông báo đã ẩn: hết thời gian Hoàn tác thì xoá hẳn (file, mục, phiên dở của đề đó; lịch sử giữ lại). */
    fun noticeShown(notice: Notice) {
        _state.update { if (it.notice?.id == notice.id) it.copy(notice = null) else it }
        if (notice is Notice.Removed) {
            viewModelScope.launch {
                library.purgeRemoved()
                draftExamId = library.loadDraft()?.examId
            }
        }
    }

    // ---------- Lịch sử thi ----------

    fun openHistory(examId: UUID? = null, examTitle: String? = null) {
        _state.update { it.copy(stack = it.stack + Route.History(examId, examTitle)) }
    }

    /** Mở Kết quả của một lần thi cũ; nội dung câu của Xem lại lấy từ file đề hiện tại. */
    fun openPastAttempt(summary: AttemptSummary) {
        viewModelScope.launch {
            val started = System.nanoTime()
            val detail = library.attemptDetail(summary.attemptId) ?: return@launch
            var problem: ReviewAvailability? = null
            val exam = if (library.item(summary.examId) == null) {
                problem = ReviewAvailability.EXAM_GONE
                null
            } else {
                try {
                    library.open(summary.examId).exam
                } catch (_: ExamFileError) {
                    problem = ReviewAvailability.EXAM_UNREADABLE
                    null
                }
            }
            val previous = AttemptPresentation.previousAttempt(history.value, summary.examId, summary.mode, summary.submittedAtMillis)?.percent
            val model = Timing.measure("history.open.model") {
                withContext(Dispatchers.Default) { PastAttemptModel(detail.summary, detail.payload, exam, problem, previous, ::randomSeed) }
            }
            _state.update { it.copy(stack = it.stack + Route.PastAttempt(model, services.images(library, summary.examId))) }
            Timing.record("history.open", (System.nanoTime() - started) / 1e6)
        }
    }

    /** Quay lại một màn (Lịch sử thi, Kết quả cũ). */
    fun back() {
        _state.update { if (it.stack.size > 1) it.copy(stack = it.stack.dropLast(1)) else it }
    }

    // ---------- Hộp thoại, thông báo ----------

    fun dismissDialog() = _state.update { it.copy(dialog = null) }

    private fun showDialog(dialog: AppDialog) = _state.update { it.copy(dialog = dialog) }

    private fun notify(make: (Int) -> Notice) {
        val notice = make(nextNoticeId++)
        _state.update { it.copy(notice = notice) }
    }
}
