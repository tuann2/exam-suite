package vn.io.nt0.examsuite.app

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SnackbarDuration
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.SnackbarResult
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalResources
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import vn.io.nt0.examsuite.R
import vn.io.nt0.examsuite.attempt.ui.AttemptFlow
import vn.io.nt0.examsuite.attempt.ui.AttemptRoute
import vn.io.nt0.examsuite.attempt.ui.LocalQuestionImages
import vn.io.nt0.examsuite.core.session.SessionMode
import vn.io.nt0.examsuite.data.library.LibraryItem
import vn.io.nt0.examsuite.data.library.LibrarySort
import vn.io.nt0.examsuite.library.HistoryScreen
import vn.io.nt0.examsuite.library.LibraryActions
import vn.io.nt0.examsuite.library.LibraryScreen
import vn.io.nt0.examsuite.pre.PreExamSheet

/** Gốc giao diện: màn theo ngăn xếp của `AppModel`, Trước khi thi, hộp thoại, thông báo. */
@Composable
fun AppRoot(model: AppModel, onAddExam: () -> Unit) {
    val state by model.state.collectAsStateWithLifecycle()
    val items by model.items.collectAsStateWithLifecycle()
    val history by model.history.collectAsStateWithLifecycle()
    val settings by model.settings.collectAsStateWithLifecycle()
    val snackbar = remember { SnackbarHostState() }
    val resources = LocalResources.current

    state.notice?.let { notice ->
        LaunchedEffect(notice.id) {
            val (text, undo) = when (notice) {
                is Notice.Removed -> resources.getString(R.string.removed_notice, notice.title) to resources.getString(R.string.undo)
                is Notice.Added -> resources.getString(if (notice.updated) R.string.updated_notice else R.string.added_notice, notice.title) to null
            }
            val result = snackbar.showSnackbar(text, actionLabel = undo, withDismissAction = undo == null, duration = SnackbarDuration.Long)
            if (result == SnackbarResult.ActionPerformed && notice is Notice.Removed) model.undoRemove(notice) else model.noticeShown(notice)
        }
    }

    when {
        state.failed -> CenteredText(stringResource(R.string.library_failed))
        !state.ready -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
        else -> when (val route = state.route) {
            Route.Library -> LibraryScreen(
                items = items,
                sort = settings?.sort ?: LibrarySort.RECENT,
                query = state.query,
                showWelcome = settings?.welcomeDismissed == false,
                actions = libraryActions(model, onAddExam),
                snackbarHost = { SnackbarHost(snackbar) },
            )
            is Route.History -> HistoryScreen(history, route.examId, route.examTitle, model::openPastAttempt, model::back)
            is Route.Attempt -> AttemptRoute(route.model, route.images, onExit = model::exitAttempt, onNextAttempt = model::startNext)
            is Route.PastAttempt -> {
                val past by route.model.state.collectAsStateWithLifecycle()
                CompositionLocalProvider(LocalQuestionImages provides route.images) {
                    AttemptFlow(past, route.model, onExit = model::back, onNextAttempt = model::startNext)
                }
            }
        }
    }

    state.preExam?.let { ui ->
        PreExamSheet(ui, onChange = model::updateForm, onStart = model::startPreExam, onCancel = model::cancelPreExam)
    }
    state.dialog?.let { AppDialogView(it, model) }
}

private fun libraryActions(model: AppModel, onAddExam: () -> Unit) = object : LibraryActions {
    override fun setQuery(query: String) = model.setQuery(query)
    override fun setSort(sort: LibrarySort) = model.setSort(sort)
    override fun addExam() = onAddExam()
    override fun openHistory() = model.openHistory()
    override fun open(item: LibraryItem, mode: SessionMode?) = model.requestStart(StartTarget(item.examId, mode, null))
    override fun viewHistory(item: LibraryItem) = model.openHistory(item.examId, item.title)
    override fun remove(item: LibraryItem) = model.remove(item)
    override fun dismissWelcome() = model.dismissWelcome()
}

@Composable
private fun CenteredText(text: String) {
    Surface(Modifier.fillMaxSize()) {
        Box(Modifier.padding(24.dp), contentAlignment = Alignment.Center) {
            Text(text, style = MaterialTheme.typography.bodyLarge)
        }
    }
}

@Composable
private fun AppDialogView(dialog: AppDialog, model: AppModel) {
    when (dialog) {
        is AppDialog.UpdateConfirm -> AlertDialog(
            onDismissRequest = { model.cancelUpdate(dialog) },
            title = { Text(stringResource(R.string.update_title, dialog.existing.title)) },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(stringResource(R.string.update_message))
                    if (dialog.dropsDraft) Text(stringResource(R.string.update_drops_draft), color = MaterialTheme.colorScheme.error)
                }
            },
            confirmButton = { TextButton(onClick = { model.confirmUpdate(dialog) }) { Text(stringResource(R.string.update_exam)) } },
            dismissButton = { TextButton(onClick = { model.cancelUpdate(dialog) }) { Text(stringResource(R.string.cancel)) } },
        )
        is AppDialog.Conflict -> AlertDialog(
            onDismissRequest = model::dismissDialog,
            title = { Text(stringResource(R.string.conflict_title, dialog.currentTitle)) },
            text = { Text(stringResource(R.string.conflict_message)) },
            confirmButton = {
                Column(horizontalAlignment = Alignment.End) {
                    TextButton(onClick = model::continueCurrent) { Text(stringResource(R.string.conflict_continue, dialog.currentTitle)) }
                    TextButton(onClick = { model.discardAndStart(dialog.target) }) {
                        Text(stringResource(R.string.conflict_discard, dialog.targetTitle), color = MaterialTheme.colorScheme.error)
                    }
                    TextButton(onClick = model::dismissDialog) { Text(stringResource(R.string.cancel)) }
                }
            },
        )
        is AppDialog.ImportRejected -> MessageDialog(stringResource(R.string.import_rejected_title), importProblemMessage(dialog.problem), model)
        is AppDialog.OpenFailed -> MessageDialog(
            stringResource(R.string.open_failed_title),
            dialog.error?.let { examFileErrorMessage(it) } ?: stringResource(R.string.exam_gone),
            model,
        )
        AppDialog.StoreRecovered -> MessageDialog(stringResource(R.string.store_recovered_title), stringResource(R.string.store_recovered_message), model)
    }
}

@Composable
private fun MessageDialog(title: String, message: String, model: AppModel) {
    AlertDialog(
        onDismissRequest = model::dismissDialog,
        title = { Text(title) },
        text = { Text(message) },
        confirmButton = { TextButton(onClick = model::dismissDialog) { Text(stringResource(R.string.close)) } },
    )
}
