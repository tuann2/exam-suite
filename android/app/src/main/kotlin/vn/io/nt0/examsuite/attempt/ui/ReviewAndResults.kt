package vn.io.nt0.examsuite.attempt.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import vn.io.nt0.examsuite.R
import vn.io.nt0.examsuite.attempt.AttemptActions
import vn.io.nt0.examsuite.attempt.NavigatorCell
import vn.io.nt0.examsuite.attempt.NavigatorSection
import vn.io.nt0.examsuite.attempt.NextAttempt
import vn.io.nt0.examsuite.attempt.ResultsView
import vn.io.nt0.examsuite.attempt.ReviewSummary
import vn.io.nt0.examsuite.attempt.SaveState
import vn.io.nt0.examsuite.attempt.SectionRow
import vn.io.nt0.examsuite.core.review.ReviewFilter
import vn.io.nt0.examsuite.ui.ExamTheme

// ---------- Rà soát & nộp ----------

/** Ba số, câu chưa làm, câu đã đánh dấu, toàn bộ bảng câu hỏi; bấm số câu để quay lại làm bài (không có khi khoá). */
@Composable
fun ReviewSubmitContent(summary: ReviewSummary, navigator: List<NavigatorSection>, actions: AttemptActions) {
    val cellsByIndex = navigator.flatMap { it.cells }.associateBy { it.index }
    val select: ((Int) -> Unit)? = if (summary.canReturnToAttempt) { index -> actions.returnToAttempt(index) } else null
    LazyVerticalGrid(
        columns = GridCells.Adaptive(56.dp),
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        item(span = { GridItemSpan(maxLineSpan) }) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(stringResource(R.string.review_and_submit), style = MaterialTheme.typography.headlineSmall, modifier = Modifier.semantics { heading() })
                if (summary.isLocked) Text(stringResource(R.string.time_up_locked), style = MaterialTheme.typography.bodyMedium)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    StatBox(stringResource(R.string.answered), summary.answeredCount, Modifier.weight(1f))
                    StatBox(stringResource(R.string.unanswered), summary.unansweredCount, Modifier.weight(1f))
                    StatBox(stringResource(R.string.flagged), summary.flaggedCount, Modifier.weight(1f))
                }
            }
        }
        listSection(R.string.unanswered_questions, R.string.no_unanswered, summary.unansweredIndices.mapNotNull { cellsByIndex[it] }, select)
        listSection(R.string.flagged_questions, R.string.no_flagged, summary.flaggedIndices.mapNotNull { cellsByIndex[it] }, select)
        item(span = { GridItemSpan(maxLineSpan) }) {
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                HorizontalDivider(Modifier.padding(vertical = 8.dp))
                Text(stringResource(R.string.all_questions), style = MaterialTheme.typography.titleMedium, modifier = Modifier.semantics { heading() })
                NavigatorLegend()
            }
        }
        navigatorCells(navigator, select)
    }
}

private fun androidx.compose.foundation.lazy.grid.LazyGridScope.listSection(
    title: Int,
    empty: Int,
    cells: List<NavigatorCell>,
    onSelect: ((Int) -> Unit)?,
) {
    item(span = { GridItemSpan(maxLineSpan) }) {
        Column(Modifier.padding(top = 8.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(stringResource(title), style = MaterialTheme.typography.titleMedium, modifier = Modifier.semantics { heading() })
            if (cells.isEmpty()) Text(stringResource(empty), style = MaterialTheme.typography.bodyMedium)
        }
    }
    items(cells, key = { "${title}-${it.index}" }) { NavigatorCellView(it, onSelect) }
}

@Composable
private fun StatBox(label: String, value: Int, modifier: Modifier = Modifier) {
    Surface(modifier, shape = RoundedCornerShape(8.dp), color = MaterialTheme.colorScheme.surfaceVariant) {
        Column(Modifier.padding(12.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            Text(num(value), style = MaterialTheme.typography.headlineSmall)
            Text(label, style = MaterialTheme.typography.labelMedium, maxLines = 2)
        }
    }
}

// ---------- Kết quả ----------

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ResultsScreen(results: ResultsView, examTitle: String, actions: AttemptActions, onExit: () -> Unit, onNextAttempt: (NextAttempt) -> Unit) {
    Scaffold(
        topBar = {
            TopAppBar(title = {
                Column {
                    Text(stringResource(R.string.results_title), style = MaterialTheme.typography.titleMedium)
                    Text(examTitle, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1)
                }
            })
        },
    ) { padding ->
        Column(
            Modifier.fillMaxSize().padding(padding).verticalScroll(rememberScrollState()).navigationBarsPadding().padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            ResultsBody(results)
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Button(onClick = { actions.openAnswerReview(ReviewFilter.ALL) }, modifier = Modifier.fillMaxWidth()) {
                    Text(stringResource(R.string.review_answers))
                }
                if (results.incorrectCount > 0) {
                    OutlinedButton(onClick = { actions.openAnswerReview(ReviewFilter.INCORRECT) }, modifier = Modifier.fillMaxWidth()) {
                        Text(stringResource(R.string.review_incorrect))
                    }
                }
                OutlinedButton(onClick = { actions.retake()?.let(onNextAttempt) }, modifier = Modifier.fillMaxWidth()) {
                    Text(stringResource(R.string.retake))
                }
                OutlinedButton(onClick = onExit, modifier = Modifier.fillMaxWidth()) {
                    Text(stringResource(R.string.back_to_library))
                }
            }
        }
    }
}

@Composable
fun ResultsBody(results: ResultsView) {
    val palette = ExamTheme.palette
    val verdictColor = if (results.passed) palette.positive else palette.critical
    val verdict = stringResource(if (results.passed) R.string.pass else R.string.fail)
    val percent = percentText(results.percent)
    val announcement = stringResource(R.string.result_announcement, verdict, percent)
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.clearAndSetSemantics {
                heading()
                contentDescription = announcement
                liveRegion = LiveRegionMode.Polite
            },
        ) {
            Icon(painterResource(if (results.passed) R.drawable.ic_pass else R.drawable.ic_fail), contentDescription = null, tint = verdictColor, modifier = Modifier.size(36.dp))
            Text(verdict, style = MaterialTheme.typography.headlineMedium, color = verdictColor, fontWeight = FontWeight.Bold)
        }
        Text(stringResource(R.string.score_line, percent, results.score1000.toString()), style = MaterialTheme.typography.titleLarge)
        ScoreBar(results.percent, results.passPercent, verdictColor)
        Text(stringResource(R.string.passing_score, percentText(results.passPercent)), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        results.previousDelta?.let {
            Text(stringResource(R.string.compared_previous, percentDelta(it)), style = MaterialTheme.typography.bodyLarge)
        }
        if (results.saveState == SaveState.FAILED) {
            IconLabel(R.drawable.ic_warning, stringResource(R.string.save_failed), palette.critical)
        }
        Surface(shape = RoundedCornerShape(8.dp), color = MaterialTheme.colorScheme.surfaceVariant) {
            Column(Modifier.fillMaxWidth().padding(12.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                InfoRow(stringResource(R.string.candidate), results.candidateName)
                results.examCode?.let { InfoRow(stringResource(R.string.exam_code), it) }
                InfoRow(stringResource(R.string.mode), modeText(results.mode))
                InfoRow(stringResource(R.string.submitted_at), Fmt.dateTime(results.submittedAt, interfaceLocale(), LocalTimeZone.current))
                val taken = durationText(results.elapsedSeconds)
                InfoRow(
                    stringResource(R.string.time_taken),
                    results.timeLimitMinutes?.let { stringResource(R.string.time_of_limit, taken, durationText(it * 60L)) } ?: taken,
                )
                InfoRow(stringResource(R.string.correct_answers), stringResource(R.string.fraction, num(results.correct), num(results.total)))
            }
        }
        Text(stringResource(R.string.by_section), style = MaterialTheme.typography.titleMedium, modifier = Modifier.semantics { heading() })
        results.sections.forEach { SectionScoreRow(it) }
    }
}

@Composable
private fun InfoRow(label: String, value: String) {
    Row(Modifier.fillMaxWidth().semantics(mergeDescendants = true) {}, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(label, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.weight(0.4f))
        Text(value, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.weight(0.6f))
    }
}

/** Thanh điểm có vạch ngưỡng đậu. */
@Composable
private fun ScoreBar(percent: Int, passPercent: Int, color: Color, modifier: Modifier = Modifier) {
    val track = MaterialTheme.colorScheme.surfaceVariant
    val marker = MaterialTheme.colorScheme.onSurface
    Canvas(modifier.fillMaxWidth().height(14.dp).clearAndSetSemantics { }) {
        val radius = CornerRadius(size.height / 2)
        drawRoundRect(track, cornerRadius = radius)
        drawRoundRect(color, size = Size(size.width * percent.coerceIn(0, 100) / 100f, size.height), cornerRadius = radius)
        val x = size.width * passPercent.coerceIn(0, 100) / 100f
        drawLine(marker, Offset(x, -2f), Offset(x, size.height + 2f), strokeWidth = 3f)
    }
}

@Composable
private fun SectionScoreRow(row: SectionRow) {
    val palette = ExamTheme.palette
    Column(Modifier.fillMaxWidth().semantics(mergeDescendants = true) {}, verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(row.title, style = MaterialTheme.typography.bodyLarge, modifier = Modifier.weight(1f))
            if (row.total == 0) {
                Text(stringResource(R.string.no_questions), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            } else {
                Text(stringResource(R.string.section_score, num(row.correct), num(row.total), percentText(row.percent)), style = MaterialTheme.typography.bodyMedium)
            }
        }
        if (row.total > 0) {
            val track = MaterialTheme.colorScheme.surfaceVariant
            val fill = MaterialTheme.colorScheme.primary
            Canvas(Modifier.fillMaxWidth().height(8.dp)) {
                val radius = CornerRadius(size.height / 2)
                drawRoundRect(track, cornerRadius = radius)
                drawRoundRect(fill, size = Size(size.width * row.percent / 100f, size.height), cornerRadius = radius)
            }
        }
        if (row.isWeakest) IconLabel(R.drawable.ic_warning, stringResource(R.string.weakest_section), palette.warning)
    }
}
