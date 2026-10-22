package vn.io.nt0.examsuite.library

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import vn.io.nt0.examsuite.R
import vn.io.nt0.examsuite.attempt.ui.Fmt
import vn.io.nt0.examsuite.attempt.ui.IconLabel
import vn.io.nt0.examsuite.attempt.ui.LocalTimeZone
import vn.io.nt0.examsuite.attempt.ui.interfaceLocale
import vn.io.nt0.examsuite.attempt.ui.num
import vn.io.nt0.examsuite.attempt.ui.percentText
import vn.io.nt0.examsuite.core.session.SessionMode
import vn.io.nt0.examsuite.data.library.LibraryItem
import vn.io.nt0.examsuite.data.library.LibraryQuery
import vn.io.nt0.examsuite.data.library.LibrarySort
import vn.io.nt0.examsuite.ui.ExamTheme
import java.time.Instant

/** Lệnh của màn Thư viện. */
interface LibraryActions {
    fun setQuery(query: String)
    fun setSort(sort: LibrarySort)
    fun addExam()
    fun openHistory()
    /** Mở Trước khi thi; `mode` null là chế độ dùng lần trước. */
    fun open(item: LibraryItem, mode: SessionMode?)
    fun viewHistory(item: LibraryItem)
    fun remove(item: LibraryItem)
    fun dismissWelcome()
}

/**
 * Thư viện dạng danh sách (library.md; mobile.md: không có trạng thái mất file, đề luôn đọc nghiêm được khi đã thêm): tìm
 * theo tên và mã không dấu, sắp xếp, dải chào mừng, xoá có Hoàn tác.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LibraryScreen(
    items: List<LibraryItem>,
    sort: LibrarySort,
    query: String,
    showWelcome: Boolean,
    actions: LibraryActions,
    snackbarHost: @Composable () -> Unit = {},
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.library_title)) },
                actions = {
                    IconButton(onClick = actions::openHistory) {
                        Icon(painterResource(R.drawable.ic_history), contentDescription = stringResource(R.string.history))
                    }
                    SortMenu(sort, actions::setSort)
                    IconButton(onClick = actions::addExam) {
                        Icon(painterResource(R.drawable.ic_add), contentDescription = stringResource(R.string.add_exams))
                    }
                },
            )
        },
        snackbarHost = snackbarHost,
    ) { padding ->
        val shown = remember(items, query, sort) { LibraryQuery.query(items, query, sort) }
        LazyColumn(Modifier.fillMaxSize().padding(padding), contentPadding = PaddingValues(bottom = 24.dp)) {
            item {
                OutlinedTextField(
                    value = query,
                    onValueChange = actions::setQuery,
                    placeholder = { Text(stringResource(R.string.search_hint)) },
                    leadingIcon = { Icon(painterResource(R.drawable.ic_search), contentDescription = null) },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp).testTag("search"),
                )
            }
            if (showWelcome) item { WelcomeCard(actions::dismissWelcome) }
            when {
                items.isEmpty() -> item { EmptyText(stringResource(R.string.library_empty)) }
                shown.isEmpty() -> item { EmptyText(stringResource(R.string.no_matching_exams, query)) }
            }
            items(shown, key = { it.examId }) { item ->
                LibraryRow(item, actions)
                HorizontalDivider(Modifier.padding(start = 16.dp))
            }
        }
    }
}

@Composable
private fun EmptyText(text: String) {
    Text(text, style = MaterialTheme.typography.bodyLarge, modifier = Modifier.padding(16.dp))
}

@Composable
private fun SortMenu(sort: LibrarySort, onSort: (LibrarySort) -> Unit) {
    var open by remember { mutableStateOf(false) }
    Box {
        IconButton(onClick = { open = true }) {
            Icon(painterResource(R.drawable.ic_sort), contentDescription = stringResource(R.string.sort_current, sortName(sort)))
        }
        DropdownMenu(expanded = open, onDismissRequest = { open = false }) {
            LibrarySort.entries.forEach { option ->
                DropdownMenuItem(
                    text = { Text(sortName(option)) },
                    leadingIcon = { RadioButton(selected = option == sort, onClick = null) },
                    onClick = {
                        open = false
                        onSort(option)
                    },
                )
            }
        }
    }
}

@Composable
private fun sortName(sort: LibrarySort): String = stringResource(
    when (sort) {
        LibrarySort.RECENT -> R.string.sort_recent
        LibrarySort.TITLE -> R.string.sort_title
        LibrarySort.LAST_SCORE -> R.string.sort_last_score
    },
)

@Composable
private fun WelcomeCard(onDismiss: () -> Unit) {
    Surface(
        shape = RoundedCornerShape(8.dp),
        color = MaterialTheme.colorScheme.primary.copy(alpha = ExamTheme.palette.tintOpacity),
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
    ) {
        Row(Modifier.padding(start = 12.dp, top = 8.dp, bottom = 12.dp)) {
            Column(Modifier.weight(1f).padding(top = 4.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(stringResource(R.string.welcome_title), style = MaterialTheme.typography.titleMedium, modifier = Modifier.semantics { heading() })
                Text(stringResource(R.string.welcome_body), style = MaterialTheme.typography.bodyMedium)
            }
            IconButton(onClick = onDismiss) {
                Icon(painterResource(R.drawable.ic_close), contentDescription = stringResource(R.string.dismiss_banner))
            }
        }
    }
}

/** Dòng tóm tắt của đề: "ATTT01 · 23 câu · 3 phần · 20 phút · đậu 70%". */
@Composable
fun examFacts(item: LibraryItem): String {
    val separator = stringResource(R.string.summary_separator)
    return listOfNotNull(
        item.code,
        pluralStringResource(R.plurals.question_count, item.questionCount, num(item.questionCount)),
        pluralStringResource(R.plurals.section_count, item.sectionCount, num(item.sectionCount)),
        pluralStringResource(R.plurals.duration_minutes, item.timeLimitMinutes, num(item.timeLimitMinutes)),
        stringResource(R.string.pass_from, percentText(item.passPercent)),
    ).joinToString(separator)
}

@Composable
private fun LibraryRow(item: LibraryItem, actions: LibraryActions) {
    var menu by remember { mutableStateOf(false) }
    val practice = stringResource(R.string.mode_practice)
    val exam = stringResource(R.string.mode_exam)
    val remove = stringResource(R.string.remove_from_library)
    val viewHistory = stringResource(R.string.view_history)
    Row(
        Modifier
            .fillMaxWidth()
            .heightIn(min = 64.dp)
            .clickable { actions.open(item, null) }
            .semantics {
                customActions = listOfNotNull(
                    if (!item.hideAnswers) CustomAccessibilityAction(practice) { actions.open(item, SessionMode.PRACTICE); true } else null,
                    CustomAccessibilityAction(exam) { actions.open(item, SessionMode.EXAM); true },
                    CustomAccessibilityAction(viewHistory) { actions.viewHistory(item); true },
                    CustomAccessibilityAction(remove) { actions.remove(item); true },
                )
            }
            .padding(start = 16.dp, top = 10.dp, bottom = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(item.title, style = MaterialTheme.typography.titleMedium, maxLines = 2, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f, fill = false))
                if (item.isSample) {
                    Text(
                        stringResource(R.string.sample_badge),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.primary,
                        fontWeight = FontWeight.Bold,
                    )
                }
            }
            Text(examFacts(item), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            item.lastAttempt?.let { last ->
                val palette = ExamTheme.palette
                val date = Fmt.date(Instant.ofEpochMilli(last.submittedAtMillis), interfaceLocale(), LocalTimeZone.current)
                IconLabel(
                    if (last.passed) R.drawable.ic_pass else R.drawable.ic_fail,
                    stringResource(R.string.last_attempt, stringResource(if (last.passed) R.string.pass else R.string.fail), percentText(last.percent), date),
                    if (last.passed) palette.positive else palette.critical,
                )
            }
        }
        Box {
            IconButton(onClick = { menu = true }) {
                Icon(painterResource(R.drawable.ic_more_vert), contentDescription = stringResource(R.string.more_actions, item.title))
            }
            DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                DropdownMenuItem(text = { Text(practice) }, enabled = !item.hideAnswers, onClick = {
                    menu = false
                    actions.open(item, SessionMode.PRACTICE)
                })
                DropdownMenuItem(text = { Text(exam) }, onClick = {
                    menu = false
                    actions.open(item, SessionMode.EXAM)
                })
                DropdownMenuItem(text = { Text(viewHistory) }, onClick = {
                    menu = false
                    actions.viewHistory(item)
                })
                DropdownMenuItem(text = { Text(remove) }, onClick = {
                    menu = false
                    actions.remove(item)
                })
            }
        }
    }
}
