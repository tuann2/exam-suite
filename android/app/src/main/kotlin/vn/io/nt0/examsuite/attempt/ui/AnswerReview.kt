package vn.io.nt0.examsuite.attempt.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import vn.io.nt0.examsuite.R
import vn.io.nt0.examsuite.attempt.AnswerReviewState
import vn.io.nt0.examsuite.attempt.AttemptActions
import vn.io.nt0.examsuite.attempt.AttemptPresentation
import vn.io.nt0.examsuite.attempt.NextAttempt
import vn.io.nt0.examsuite.attempt.ReviewRow
import vn.io.nt0.examsuite.core.review.QuestionChange
import vn.io.nt0.examsuite.core.review.ReviewDetail
import vn.io.nt0.examsuite.core.review.ReviewFilter
import vn.io.nt0.examsuite.core.review.ReviewOption
import vn.io.nt0.examsuite.core.scoring.QuestionOutcome
import vn.io.nt0.examsuite.ui.ExamTheme

/** Xem lại bài (exam-taking.md): danh sách có bộ lọc, chạm một câu để xem chi tiết; nội dung và luật ẩn/hiện từ `ReviewItems`. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AnswerReviewScreen(review: AnswerReviewState, actions: AttemptActions, onNextAttempt: (NextAttempt) -> Unit) {
    val detail = review.detail
    Scaffold(
        topBar = {
            TopAppBar(
                navigationIcon = {
                    IconButton(onClick = { actions.backFromAnswerReview() }) {
                        Icon(
                            painterResource(R.drawable.ic_arrow_back),
                            contentDescription = stringResource(if (detail == null) R.string.back_to_results else R.string.navigate_back),
                        )
                    }
                },
                title = {
                    Text(
                        if (detail == null) stringResource(R.string.review_answers) else stringResource(R.string.question_number, num(detail.number), num(detail.total)),
                        style = MaterialTheme.typography.titleMedium,
                    )
                },
            )
        },
        bottomBar = {
            if (detail != null) {
                DetailBottomBar(review, actions)
            } else if (review.canPracticeIncorrect) {
                Surface(tonalElevation = 3.dp) {
                    Button(
                        onClick = { actions.practiceIncorrect()?.let(onNextAttempt) },
                        modifier = Modifier.fillMaxWidth().navigationBarsPadding().padding(horizontal = 16.dp, vertical = 8.dp),
                    ) { Text(stringResource(R.string.practice_incorrect)) }
                }
            }
        },
    ) { padding ->
        if (detail == null) {
            ReviewList(review, actions, Modifier.padding(padding))
        } else {
            ReviewDetailContent(detail, review.answersHidden, Modifier.padding(padding))
        }
    }
}

@Composable
private fun ReviewList(review: AnswerReviewState, actions: AttemptActions, modifier: Modifier) {
    LazyColumn(modifier.fillMaxSize(), contentPadding = PaddingValues(bottom = 16.dp)) {
        item {
            val filterLabel = stringResource(R.string.filter)
            Row(
                Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()).padding(horizontal = 16.dp, vertical = 8.dp)
                    .selectableGroup().semantics { contentDescription = filterLabel },
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                FILTERS.forEach { filter ->
                    FilterChip(
                        selected = review.filter == filter,
                        onClick = { actions.setReviewFilter(filter) },
                        label = { Text(stringResource(R.string.filter_with_count, filterName(filter), num(review.counts[filter] ?: 0))) },
                    )
                }
            }
        }
        if (review.answersHidden) {
            item { HideAnswersNotice(Modifier.padding(horizontal = 16.dp, vertical = 4.dp)) }
        }
        if (review.rows.isEmpty()) {
            item {
                Text(stringResource(R.string.filter_empty), style = MaterialTheme.typography.bodyLarge, modifier = Modifier.padding(16.dp))
            }
        }
        items(review.rows, key = { it.index }) { row ->
            ReviewListRow(row) { actions.openReviewQuestion(row.index) }
            HorizontalDivider(Modifier.padding(start = 16.dp))
        }
    }
}

private val FILTERS = listOf(ReviewFilter.ALL, ReviewFilter.INCORRECT, ReviewFilter.UNANSWERED, ReviewFilter.FLAGGED, ReviewFilter.CORRECT)

@Composable
private fun filterName(filter: ReviewFilter): String = stringResource(
    when (filter) {
        ReviewFilter.ALL -> R.string.filter_all
        ReviewFilter.INCORRECT -> R.string.mark_incorrect
        ReviewFilter.UNANSWERED -> R.string.unanswered
        ReviewFilter.FLAGGED -> R.string.flagged
        ReviewFilter.CORRECT -> R.string.mark_correct
    },
)

@Composable
private fun HideAnswersNotice(modifier: Modifier = Modifier) {
    Row(modifier, horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.Top) {
        Icon(painterResource(R.drawable.ic_info), contentDescription = null, tint = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(stringResource(R.string.hide_answers_notice), style = MaterialTheme.typography.bodyMedium)
    }
}

/** Kết quả lúc thi bằng biểu tượng + chữ (Đúng, Sai, Chưa làm). */
@Composable
private fun OutcomeLabel(outcome: QuestionOutcome, modifier: Modifier = Modifier) {
    val palette = ExamTheme.palette
    when (outcome) {
        QuestionOutcome.CORRECT -> IconLabel(R.drawable.ic_check, stringResource(R.string.mark_correct), palette.positive, modifier)
        QuestionOutcome.INCORRECT -> IconLabel(R.drawable.ic_close, stringResource(R.string.mark_incorrect), palette.critical, modifier)
        QuestionOutcome.UNANSWERED -> IconLabel(R.drawable.ic_remove, stringResource(R.string.unanswered), MaterialTheme.colorScheme.onSurfaceVariant, modifier)
    }
}

@Composable
private fun ChangeLabel(change: QuestionChange) {
    when (change) {
        QuestionChange.EDITED -> IconLabel(R.drawable.ic_edit, stringResource(R.string.edited), ExamTheme.palette.warning)
        QuestionChange.DELETED -> IconLabel(R.drawable.ic_delete, stringResource(R.string.deleted), MaterialTheme.colorScheme.onSurfaceVariant)
        QuestionChange.UNCHANGED -> Unit
    }
}

@Composable
private fun ReviewListRow(row: ReviewRow, onOpen: () -> Unit) {
    Column(
        Modifier.fillMaxWidth().heightIn(min = 48.dp).clickable(onClick = onOpen).padding(horizontal = 16.dp, vertical = 10.dp)
            .semantics(mergeDescendants = true) {},
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(stringResource(R.string.cell_number, num(row.number)), style = MaterialTheme.typography.titleSmall)
            OutcomeLabel(row.outcome)
            if (row.isFlagged) IconLabel(R.drawable.ic_flag, stringResource(R.string.flagged), ExamTheme.palette.warning)
            ChangeLabel(row.change)
        }
        row.preview?.let {
            Text(
                remember(it) { markdownAnnotated(it) },
                style = MaterialTheme.typography.bodyMedium,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun ReviewDetailContent(detail: ReviewDetail, answersHidden: Boolean, modifier: Modifier) {
    Column(
        modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(detail.sectionTitle, style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
            OutcomeLabel(detail.outcome)
            if (detail.isFlagged) IconLabel(R.drawable.ic_flag, stringResource(R.string.flagged), ExamTheme.palette.warning)
        }
        if (answersHidden) HideAnswersNotice()
        when (detail.change) {
            QuestionChange.DELETED -> {
                IconLabel(R.drawable.ic_delete, stringResource(R.string.question_deleted), MaterialTheme.colorScheme.onSurfaceVariant)
                return@Column
            }
            QuestionChange.EDITED -> {
                IconLabel(R.drawable.ic_edit, stringResource(R.string.question_edited), ExamTheme.palette.warning)
                Text(stringResource(R.string.answer_hidden_edited), style = MaterialTheme.typography.bodyMedium)
            }
            QuestionChange.UNCHANGED -> Unit
        }
        detail.text?.let { MarkdownText(it) }
        detail.imagePath?.let { QuestionImage(it) }
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            detail.options.forEach { ReviewOptionRow(it) }
        }
        detail.explanation?.let { ExplanationBox(it) }
    }
}

/** Lựa chọn ở Xem lại: **Bạn chọn**, **Đáp án đúng** bằng biểu tượng + chữ; nhãn A, B… theo vị trí đã hiện lúc làm. */
@Composable
private fun ReviewOptionRow(option: ReviewOption) {
    val palette = ExamTheme.palette
    val tint = when {
        option.isCorrectAnswer == true -> palette.positive
        option.isSelected && option.isCorrectAnswer == false -> palette.critical
        option.isSelected -> MaterialTheme.colorScheme.primary
        else -> Color.Transparent
    }
    val shape = RoundedCornerShape(8.dp)
    Row(
        Modifier
            .fillMaxWidth()
            .heightIn(min = 48.dp)
            .background(tint.copy(alpha = if (tint == Color.Transparent) 0f else palette.tintOpacity), shape)
            .border(1.dp, if (tint == Color.Transparent) MaterialTheme.colorScheme.outlineVariant else tint, shape)
            .padding(horizontal = 12.dp, vertical = 8.dp)
            .semantics(mergeDescendants = true) {},
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            AttemptPresentation.optionLabel(option.position),
            fontWeight = FontWeight.Bold,
            modifier = Modifier.padding(end = 8.dp),
            style = MaterialTheme.typography.bodyLarge,
        )
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            MarkdownText(option.text)
            if (option.isSelected) IconLabel(R.drawable.ic_circle_filled, stringResource(R.string.your_answer), MaterialTheme.colorScheme.primary)
            if (option.isCorrectAnswer == true) IconLabel(R.drawable.ic_check, stringResource(R.string.correct_answer), palette.positive)
        }
    }
}

@Composable
private fun DetailBottomBar(review: AnswerReviewState, actions: AttemptActions) {
    Surface(tonalElevation = 3.dp) {
        Row(
            Modifier.fillMaxWidth().navigationBarsPadding().padding(horizontal = 8.dp, vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            IconButton(onClick = { actions.stepReviewQuestion(-1) }, enabled = review.hasPrevious) {
                Icon(painterResource(R.drawable.ic_chevron_left), contentDescription = stringResource(R.string.previous_in_filter))
            }
            Spacer(Modifier.weight(1f))
            Text(
                stringResource(R.string.filter_with_count, filterName(review.filter), num(review.rows.size)),
                style = MaterialTheme.typography.labelLarge,
            )
            Spacer(Modifier.weight(1f))
            IconButton(onClick = { actions.stepReviewQuestion(1) }, enabled = review.hasNext) {
                Icon(painterResource(R.drawable.ic_chevron_right), contentDescription = stringResource(R.string.next_in_filter))
            }
        }
    }
}
