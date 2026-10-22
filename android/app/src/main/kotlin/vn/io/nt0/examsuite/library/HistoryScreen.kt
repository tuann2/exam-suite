package vn.io.nt0.examsuite.library

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import vn.io.nt0.examsuite.R
import vn.io.nt0.examsuite.attempt.ui.Fmt
import vn.io.nt0.examsuite.attempt.ui.IconLabel
import vn.io.nt0.examsuite.attempt.ui.LocalTimeZone
import vn.io.nt0.examsuite.attempt.ui.durationText
import vn.io.nt0.examsuite.attempt.ui.interfaceLocale
import vn.io.nt0.examsuite.attempt.ui.modeText
import vn.io.nt0.examsuite.attempt.ui.percentText
import vn.io.nt0.examsuite.data.library.AttemptSummary
import vn.io.nt0.examsuite.ui.ExamTheme
import java.time.Instant
import java.util.UUID

/**
 * Lịch sử thi (library.md): mọi lần thi, mới nhất trước, hoặc chỉ của một đề (Xem lịch sử thi). Lịch sử còn khi đề đã xoá
 * khỏi Thư viện; chạm một lần thi để mở Kết quả của lần đó.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HistoryScreen(attempts: List<AttemptSummary>, examId: UUID?, examTitle: String?, onOpen: (AttemptSummary) -> Unit, onBack: () -> Unit) {
    BackHandler(onBack = onBack)
    val shown = if (examId == null) attempts else attempts.filter { it.examId == examId }
    Scaffold(
        topBar = {
            TopAppBar(
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(painterResource(R.drawable.ic_arrow_back), contentDescription = stringResource(R.string.navigate_back))
                    }
                },
                title = {
                    Text(
                        examTitle?.let { stringResource(R.string.history_of, it) } ?: stringResource(R.string.history),
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                    )
                },
            )
        },
    ) { padding ->
        LazyColumn(Modifier.fillMaxSize().padding(padding), contentPadding = PaddingValues(bottom = 24.dp)) {
            if (shown.isEmpty()) {
                item {
                    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(stringResource(R.string.history_empty), style = MaterialTheme.typography.titleMedium, modifier = Modifier.semantics { heading() })
                        Text(stringResource(R.string.history_empty_body), style = MaterialTheme.typography.bodyMedium)
                    }
                }
            }
            items(shown, key = { it.attemptId }) { attempt ->
                HistoryRow(attempt) { onOpen(attempt) }
                HorizontalDivider(Modifier.padding(start = 16.dp))
            }
        }
    }
}

@Composable
private fun HistoryRow(a: AttemptSummary, onOpen: () -> Unit) {
    val palette = ExamTheme.palette
    val separator = stringResource(R.string.summary_separator)
    Column(
        Modifier.fillMaxWidth().clickable(onClick = onOpen).padding(horizontal = 16.dp, vertical = 10.dp).semantics(mergeDescendants = true) {},
        verticalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        Text(a.examTitle, style = MaterialTheme.typography.titleMedium, maxLines = 2, overflow = TextOverflow.Ellipsis)
        Text(
            listOf(
                Fmt.dateTime(Instant.ofEpochMilli(a.submittedAtMillis), interfaceLocale(), LocalTimeZone.current),
                a.candidateName,
                modeText(a.mode),
            ).joinToString(separator),
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        IconLabel(
            if (a.passed) R.drawable.ic_pass else R.drawable.ic_fail,
            listOf(
                stringResource(if (a.passed) R.string.pass else R.string.fail),
                stringResource(R.string.score_line, percentText(a.percent), a.score1000.toString()),
                durationText(Math.round(a.elapsedSeconds)),
            ).joinToString(separator),
            if (a.passed) palette.positive else palette.critical,
        )
    }
}
