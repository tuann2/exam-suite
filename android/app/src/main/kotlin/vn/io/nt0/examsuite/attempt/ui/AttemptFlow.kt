package vn.io.nt0.examsuite.attempt.ui

import androidx.activity.compose.BackHandler
import androidx.activity.compose.LocalActivity
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyGridScope
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.BottomSheetDefaults
import androidx.compose.material3.Button
import androidx.compose.material3.Checkbox
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LifecycleEventEffect
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.repeatOnLifecycle
import kotlinx.coroutines.delay
import vn.io.nt0.examsuite.R
import vn.io.nt0.examsuite.attempt.AttemptActions
import vn.io.nt0.examsuite.attempt.AttemptScreen
import vn.io.nt0.examsuite.attempt.AttemptUiState
import vn.io.nt0.examsuite.attempt.AttemptModel
import vn.io.nt0.examsuite.attempt.CellPart
import vn.io.nt0.examsuite.attempt.ClockDisplay
import vn.io.nt0.examsuite.attempt.ClockLevel
import vn.io.nt0.examsuite.attempt.NavigatorCell
import vn.io.nt0.examsuite.attempt.NavigatorSection
import vn.io.nt0.examsuite.attempt.NextAttempt
import vn.io.nt0.examsuite.attempt.OptionMark
import vn.io.nt0.examsuite.attempt.OptionView
import vn.io.nt0.examsuite.attempt.QuestionAnnouncement
import vn.io.nt0.examsuite.attempt.ReviewSummary
import vn.io.nt0.examsuite.attempt.SessionBanner
import vn.io.nt0.examsuite.core.model.QuestionType
import vn.io.nt0.examsuite.core.session.PauseReason
import vn.io.nt0.examsuite.core.session.SessionMode
import vn.io.nt0.examsuite.ui.ExamTheme

private const val TICK_MILLIS = 250L
private const val BANNER_MILLIS = 5_000L

/**
 * Luồng làm bài trong một màn: Làm bài → Rà soát & nộp → Kết quả → Xem lại bài (exam-taking.md, mobile.md). Đồng hồ
 * chạy khi màn hình đang hiện; app xuống nền (không phải xoay màn hình) thì tạm dừng và lưu phiên dở.
 */
@Composable
fun AttemptRoute(model: AttemptModel, images: QuestionImages, onExit: () -> Unit, onNextAttempt: (NextAttempt) -> Unit) {
    val state by model.state.collectAsStateWithLifecycle()
    val lifecycleOwner = LocalLifecycleOwner.current
    LaunchedEffect(model, lifecycleOwner) {
        lifecycleOwner.repeatOnLifecycle(Lifecycle.State.STARTED) {
            while (true) {
                model.tick()
                delay(TICK_MILLIS)
            }
        }
    }
    val activity = LocalActivity.current
    LifecycleEventEffect(Lifecycle.Event.ON_STOP) {
        if (activity?.isChangingConfigurations != true) model.onBackground()
    }
    CompositionLocalProvider(LocalQuestionImages provides images) {
        AttemptFlow(state, model, onExit, onNextAttempt)
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AttemptFlow(state: AttemptUiState, actions: AttemptActions, onExit: () -> Unit, onNextAttempt: (NextAttempt) -> Unit) {
    var askDiscard by rememberSaveable { mutableStateOf(false) }
    var showNavigator by rememberSaveable { mutableStateOf(false) }
    val screen = state.screen
    // Tạm dừng, hết giờ, nộp: bảng câu hỏi đóng, không tự mở lại khi Tiếp tục.
    LaunchedEffect(screen is AttemptScreen.Answering) { if (screen !is AttemptScreen.Answering) showNavigator = false }

    BackHandler {
        when (screen) {
            is AttemptScreen.Answering, is AttemptScreen.Paused -> askDiscard = true
            is AttemptScreen.Review -> if (screen.summary.canReturnToAttempt) actions.returnToAttempt() else askDiscard = true
            is AttemptScreen.Results -> onExit()
            is AttemptScreen.AnswerReview -> actions.backFromAnswerReview()
        }
    }

    when (screen) {
        is AttemptScreen.Results -> ResultsScreen(screen.results, state.examTitle, actions, onExit, onNextAttempt)
        is AttemptScreen.AnswerReview -> AnswerReviewScreen(screen.review, actions, onNextAttempt)
        else -> Scaffold(
            topBar = {
                SessionTopBar(
                    state = state,
                    paused = screen is AttemptScreen.Paused,
                    onBack = {
                        if (screen is AttemptScreen.Review && screen.summary.canReturnToAttempt) actions.returnToAttempt() else askDiscard = true
                    },
                    onPauseToggle = { if (screen is AttemptScreen.Paused) actions.resume() else actions.pause() },
                    canPause = screen is AttemptScreen.Answering || (screen is AttemptScreen.Review && !screen.summary.isLocked) ||
                        screen is AttemptScreen.Paused,
                )
            },
            bottomBar = {
                when (screen) {
                    is AttemptScreen.Answering -> AnsweringBottomBar(screen, actions, onShowNavigator = { showNavigator = true })
                    is AttemptScreen.Review -> ReviewBottomBar(screen.summary, actions)
                    else -> Unit
                }
            },
        ) { padding ->
            Column(Modifier.fillMaxSize().padding(padding)) {
                state.banner?.let { BannerRow(it, actions) }
                when (screen) {
                    is AttemptScreen.Answering -> AnsweringContent(screen, state, actions)
                    is AttemptScreen.Paused -> PausedContent(screen.reason, actions)
                    is AttemptScreen.Review -> ReviewSubmitContent(screen.summary, state.navigator, actions)
                    else -> Unit
                }
            }
        }
    }

    if (showNavigator && screen is AttemptScreen.Answering) {
        ModalBottomSheet(
            onDismissRequest = { showNavigator = false },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
            dragHandle = { BottomSheetDefaults.DragHandle(width = 48.dp) }, // vùng chạm tối thiểu 48dp
        ) {
            NavigatorSheet(state.navigator, screen.answeredCount, screen.question.total) { index ->
                actions.goTo(index)
                showNavigator = false
            }
        }
    }

    if (askDiscard && !(screen is AttemptScreen.Results || screen is AttemptScreen.AnswerReview)) {
        AlertDialog(
            onDismissRequest = { askDiscard = false },
            title = { Text(stringResource(R.string.discard_title)) },
            text = { Text(stringResource(R.string.discard_message)) },
            confirmButton = {
                TextButton(onClick = { askDiscard = false }, modifier = Modifier.testTag("keepWorking")) { Text(stringResource(R.string.keep_working)) }
            },
            dismissButton = {
                TextButton(onClick = {
                    askDiscard = false
                    actions.discard()
                    onExit()
                }, modifier = Modifier.testTag("confirmDiscard")) { Text(stringResource(R.string.discard), color = MaterialTheme.colorScheme.error) }
            },
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SessionTopBar(state: AttemptUiState, paused: Boolean, onBack: () -> Unit, onPauseToggle: () -> Unit, canPause: Boolean) {
    TopAppBar(
        navigationIcon = {
            IconButton(onClick = onBack) {
                Icon(painterResource(R.drawable.ic_arrow_back), contentDescription = stringResource(R.string.navigate_back))
            }
        },
        title = {
            Column {
                Text(state.examTitle, maxLines = 1, overflow = TextOverflow.Ellipsis, style = MaterialTheme.typography.titleMedium)
                Text(modeText(state.mode), style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        },
        actions = {
            ClockChip(state.clock)
            if (canPause) {
                IconButton(onClick = onPauseToggle) {
                    Icon(
                        painterResource(if (paused) R.drawable.ic_play else R.drawable.ic_pause),
                        contentDescription = stringResource(if (paused) R.string.resume else R.string.pause),
                    )
                }
            }
        },
    )
}

/** Đồng hồ: biểu tượng theo mức (bình thường, sắp hết, gấp) kèm màu, đọc "Còn 4 phút 59 giây" / "Đã làm 12 phút". */
@Composable
fun ClockChip(clock: ClockDisplay, modifier: Modifier = Modifier) {
    val palette = ExamTheme.palette
    val (icon, color) = when (clock.level) {
        ClockLevel.NORMAL -> R.drawable.ic_clock to MaterialTheme.colorScheme.onSurface
        ClockLevel.WARNING -> R.drawable.ic_hourglass to palette.warning
        ClockLevel.URGENT -> R.drawable.ic_warning to palette.critical
    }
    val spoken = stringResource(if (clock.isCountdown) R.string.clock_remaining else R.string.clock_elapsed, durationText(clock.seconds))
    Row(
        modifier.padding(horizontal = 4.dp).clearAndSetSemantics { contentDescription = spoken },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Icon(painterResource(icon), contentDescription = null, tint = color, modifier = Modifier.size(20.dp))
        Text(
            clock.text,
            color = color,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = if (clock.level == ClockLevel.NORMAL) FontWeight.Normal else FontWeight.Bold,
        )
    }
}

/** Dải thông báo không chặn: cảnh báo giờ tự ẩn sau vài giây; trình đọc màn hình đọc ngay. */
@Composable
private fun BannerRow(banner: SessionBanner, actions: AttemptActions) {
    if (banner.autoDismisses) {
        LaunchedEffect(banner.id) {
            delay(BANNER_MILLIS)
            actions.dismissBanner(banner.id)
        }
    }
    val palette = ExamTheme.palette
    val (icon, text) = when (val kind = banner.kind) {
        is SessionBanner.Kind.TimeWarning -> R.drawable.ic_hourglass to
            pluralStringResource(R.plurals.minutes_left, kind.minutesLeft, num(kind.minutesLeft))
        SessionBanner.Kind.TimeUp -> R.drawable.ic_alarm to stringResource(R.string.time_up_banner)
    }
    val color = if (banner.kind is SessionBanner.Kind.TimeUp) palette.critical else palette.warning
    Surface(
        color = color.copy(alpha = palette.tintOpacity),
        border = BorderStroke(1.dp, color.copy(alpha = 0.4f)),
        shape = RoundedCornerShape(8.dp),
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
    ) {
        Row(Modifier.padding(start = 12.dp), verticalAlignment = Alignment.CenterVertically) {
            Icon(painterResource(icon), contentDescription = null, tint = color)
            Text(
                text,
                style = MaterialTheme.typography.bodyMedium,
                modifier = Modifier.weight(1f).padding(horizontal = 8.dp, vertical = 12.dp)
                    .semantics { liveRegion = LiveRegionMode.Assertive },
            )
            IconButton(onClick = { actions.dismissBanner(banner.id) }) {
                Icon(painterResource(R.drawable.ic_close), contentDescription = stringResource(R.string.dismiss_banner))
            }
        }
    }
}

@Composable
private fun AnsweringContent(screen: AttemptScreen.Answering, state: AttemptUiState, actions: AttemptActions) {
    val q = screen.question
    val palette = ExamTheme.palette
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 16.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text(q.sectionTitle, style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
                val spoken = announcementText(screen.announcement)
                Text(
                    stringResource(R.string.question_number, num(q.number), num(q.total)),
                    style = MaterialTheme.typography.titleLarge,
                    modifier = Modifier.semantics {
                        heading()
                        contentDescription = spoken
                        liveRegion = LiveRegionMode.Polite
                    },
                )
            }
            if (q.isFlagged) IconLabel(R.drawable.ic_flag, stringResource(R.string.flagged), palette.warning)
        }
        MarkdownText(q.text)
        q.imagePath?.let { QuestionImage(it) }
        if (q.type == QuestionType.MULTIPLE) {
            Text(
                pluralStringResource(R.plurals.choose_answers, q.correctCount, num(q.correctCount)),
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        val groupLabel = stringResource(if (q.type == QuestionType.SINGLE) R.string.options_single else R.string.options_multiple)
        Column(
            Modifier.selectableGroup().semantics { contentDescription = groupLabel },
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            q.options.forEach { option -> OptionRow(option, q.type, enabled = !q.isLocked) { actions.toggleOption(option.position) } }
        }
        q.check?.let { check ->
            val (icon, text, color) = if (check.isCorrect) {
                Triple(R.drawable.ic_check, stringResource(R.string.mark_correct), palette.positive)
            } else {
                Triple(R.drawable.ic_close, stringResource(R.string.check_incorrect), palette.critical)
            }
            IconLabel(icon, text, color, Modifier.semantics { liveRegion = LiveRegionMode.Polite })
            check.explanation?.let { ExplanationBox(it) }
        }
        if (state.mode == SessionMode.PRACTICE && q.check == null) {
            Button(onClick = actions::checkAnswer, enabled = screen.canCheckAnswer, modifier = Modifier.fillMaxWidth()) {
                Text(stringResource(R.string.check_answer))
            }
        }
        Spacer(Modifier.heightIn(min = 8.dp))
    }
}

@Composable
fun announcementText(a: QuestionAnnouncement): String {
    val section = if (a.needsSectionPrefix) stringResource(R.string.section_named, a.sectionTitle) else a.sectionTitle
    return stringResource(R.string.question_announcement, num(a.number), num(a.total), section)
}

/** Hàng lựa chọn rộng hết khung, chạm vào chỗ nào cũng được; nhãn A, B… theo vị trí hiển thị. */
@Composable
private fun OptionRow(option: OptionView, type: QuestionType, enabled: Boolean, onToggle: () -> Unit) {
    val palette = ExamTheme.palette
    val tint = when {
        option.mark == OptionMark.CORRECT -> palette.positive
        option.mark == OptionMark.INCORRECT -> palette.critical
        option.isSelected -> MaterialTheme.colorScheme.primary
        else -> Color.Transparent
    }
    val shape = RoundedCornerShape(8.dp)
    val interaction = if (type == QuestionType.SINGLE) {
        Modifier.selectable(selected = option.isSelected, enabled = enabled, role = Role.RadioButton, onClick = onToggle)
    } else {
        Modifier.toggleable(value = option.isSelected, enabled = enabled, role = Role.Checkbox, onValueChange = { onToggle() })
    }
    Row(
        Modifier
            .fillMaxWidth()
            .heightIn(min = 48.dp)
            .background(tint.copy(alpha = if (tint == Color.Transparent) 0f else palette.tintOpacity), shape)
            .border(1.dp, if (option.isSelected) tint else MaterialTheme.colorScheme.outlineVariant, shape)
            .then(interaction)
            .testTag("option-${option.position}")
            .padding(horizontal = 8.dp, vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (type == QuestionType.SINGLE) {
            RadioButton(selected = option.isSelected, onClick = null, enabled = enabled)
        } else {
            Checkbox(checked = option.isSelected, onCheckedChange = null, enabled = enabled)
        }
        Text(option.label, fontWeight = FontWeight.Bold, modifier = Modifier.padding(horizontal = 8.dp), style = MaterialTheme.typography.bodyLarge)
        MarkdownText(option.text, Modifier.weight(1f).padding(vertical = 8.dp))
        when (option.mark) {
            OptionMark.CORRECT -> IconLabel(R.drawable.ic_check, stringResource(R.string.mark_correct), palette.positive, Modifier.padding(start = 8.dp))
            OptionMark.INCORRECT -> IconLabel(R.drawable.ic_close, stringResource(R.string.mark_incorrect), palette.critical, Modifier.padding(start = 8.dp))
            null -> Unit
        }
    }
}

@Composable
private fun AnsweringBottomBar(screen: AttemptScreen.Answering, actions: AttemptActions, onShowNavigator: () -> Unit) {
    Surface(tonalElevation = 3.dp) {
        Row(
            Modifier.fillMaxWidth().navigationBarsPadding().padding(horizontal = 8.dp, vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            IconButton(onClick = actions::previous, enabled = !screen.isFirst) {
                Icon(painterResource(R.drawable.ic_chevron_left), contentDescription = stringResource(R.string.previous_question))
            }
            IconButton(onClick = actions::next, enabled = !screen.isLast) {
                Icon(painterResource(R.drawable.ic_chevron_right), contentDescription = stringResource(R.string.next_question))
            }
            val flagged = screen.question.isFlagged
            IconButton(onClick = actions::toggleFlag) {
                Icon(
                    painterResource(if (flagged) R.drawable.ic_flag else R.drawable.ic_flag_outline),
                    contentDescription = stringResource(if (flagged) R.string.unflag else R.string.flag),
                    tint = if (flagged) ExamTheme.palette.warning else MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            val progress = stringResource(R.string.answered_progress, num(screen.answeredCount), num(screen.question.total))
            val navigatorLabel = stringResource(R.string.question_navigator)
            val spoken = listOf(navigatorLabel, progress).joinToString(stringResource(R.string.list_separator))
            IconButton(onClick = onShowNavigator, modifier = Modifier.semantics { contentDescription = spoken }) {
                Icon(painterResource(R.drawable.ic_grid), contentDescription = null)
            }
            Spacer(Modifier.weight(1f))
            Button(onClick = actions::openReview, modifier = Modifier.widthIn(max = 200.dp)) {
                Text(stringResource(R.string.review_and_submit), maxLines = 2)
            }
        }
    }
}

@Composable
private fun PausedContent(reason: PauseReason, actions: AttemptActions) {
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp, Alignment.CenterVertically),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Icon(painterResource(R.drawable.ic_pause), contentDescription = null, modifier = Modifier.size(48.dp))
        Text(
            stringResource(if (reason == PauseReason.BACKGROUND) R.string.paused_background else R.string.paused_title),
            style = MaterialTheme.typography.headlineSmall,
            modifier = Modifier.semantics { heading() },
        )
        Text(stringResource(R.string.paused_body), style = MaterialTheme.typography.bodyLarge)
        Button(onClick = actions::resume) { Text(stringResource(R.string.resume)) }
    }
}

// ---------- Bảng câu hỏi ----------

@Composable
private fun NavigatorSheet(sections: List<NavigatorSection>, answered: Int, total: Int, onSelect: (Int) -> Unit) {
    LazyVerticalGrid(
        columns = GridCells.Adaptive(56.dp),
        contentPadding = PaddingValues(start = 16.dp, end = 16.dp, bottom = 24.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        item(span = { GridItemSpan(maxLineSpan) }) {
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(stringResource(R.string.question_navigator), style = MaterialTheme.typography.titleLarge, modifier = Modifier.semantics { heading() })
                Text(stringResource(R.string.answered_progress, num(answered), num(total)), style = MaterialTheme.typography.bodyMedium)
                NavigatorLegend()
            }
        }
        navigatorCells(sections, onSelect)
    }
}

/** Ô của bảng câu hỏi theo phần; dùng ở bảng câu hỏi và màn Rà soát. */
fun LazyGridScope.navigatorCells(sections: List<NavigatorSection>, onSelect: ((Int) -> Unit)?) {
    for (section in sections) {
        item(key = "s-${section.id}", span = { GridItemSpan(maxLineSpan) }) {
            Text(section.title, style = MaterialTheme.typography.titleSmall, modifier = Modifier.padding(top = 8.dp).semantics { heading() })
        }
        items(section.cells, key = { "c-${it.index}" }) { cell -> NavigatorCellView(cell, onSelect) }
    }
}

@Composable
fun NavigatorLegend() {
    val palette = ExamTheme.palette
    Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.clearAndSetSemantics { }) {
        IconLabel(R.drawable.ic_circle_filled, stringResource(R.string.answered), MaterialTheme.colorScheme.primary)
        IconLabel(R.drawable.ic_circle_outline, stringResource(R.string.unanswered), MaterialTheme.colorScheme.onSurfaceVariant)
        IconLabel(R.drawable.ic_flag, stringResource(R.string.flagged), palette.warning)
    }
}

@Composable
fun NavigatorCellView(cell: NavigatorCell, onSelect: ((Int) -> Unit)?) {
    val palette = ExamTheme.palette
    val primary = MaterialTheme.colorScheme.primary
    val parts = cell.spokenParts.map { part ->
        when (part) {
            CellPart.NUMBER -> stringResource(R.string.cell_number, num(cell.number))
            CellPart.ANSWERED -> stringResource(R.string.answered)
            CellPart.UNANSWERED -> stringResource(R.string.unanswered)
            CellPart.FLAGGED -> stringResource(R.string.flagged)
            CellPart.CURRENT -> stringResource(R.string.current)
        }
    }
    val spoken = parts.joinToString(stringResource(R.string.list_separator))
    val shape = RoundedCornerShape(8.dp)
    Box(
        Modifier
            .sizeIn(minWidth = 48.dp, minHeight = 48.dp)
            .background(if (cell.isAnswered) primary.copy(alpha = palette.tintOpacity) else Color.Transparent, shape)
            .border(if (cell.isCurrent) 3.dp else 1.dp, if (cell.isCurrent) primary else MaterialTheme.colorScheme.outline, shape)
            .then(if (onSelect != null) Modifier.clickable { onSelect(cell.index) } else Modifier)
            .clearAndSetSemantics { contentDescription = spoken },
        contentAlignment = Alignment.Center,
    ) {
        Text(num(cell.number), style = MaterialTheme.typography.bodyMedium, fontWeight = if (cell.isCurrent) FontWeight.Bold else FontWeight.Normal)
        Icon(
            painterResource(if (cell.isAnswered) R.drawable.ic_circle_filled else R.drawable.ic_circle_outline),
            contentDescription = null,
            tint = if (cell.isAnswered) primary else MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.align(Alignment.BottomStart).padding(3.dp).size(9.dp),
        )
        if (cell.isFlagged) {
            Icon(
                painterResource(R.drawable.ic_flag),
                contentDescription = null,
                tint = palette.warning,
                modifier = Modifier.align(Alignment.TopEnd).padding(2.dp).size(14.dp),
            )
        }
    }
}

@Composable
private fun ReviewBottomBar(summary: ReviewSummary, actions: AttemptActions) {
    var confirm by rememberSaveable { mutableStateOf(false) }
    Surface(tonalElevation = 3.dp) {
        Row(
            Modifier.fillMaxWidth().navigationBarsPadding().padding(horizontal = 16.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.End),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            if (summary.canReturnToAttempt) {
                OutlinedButton(onClick = { actions.returnToAttempt() }, modifier = Modifier.weight(1f, fill = false)) {
                    Text(stringResource(R.string.back_to_questions), maxLines = 2)
                }
            }
            Button(onClick = { if (summary.needsSubmitConfirmation) confirm = true else actions.submit() }) {
                Text(stringResource(R.string.submit))
            }
        }
    }
    if (confirm) {
        AlertDialog(
            onDismissRequest = { confirm = false },
            title = { Text(pluralStringResource(R.plurals.submit_confirm, summary.unansweredCount, num(summary.unansweredCount))) },
            confirmButton = { TextButton(onClick = { confirm = false }) { Text(stringResource(R.string.go_back)) } },
            dismissButton = {
                TextButton(onClick = {
                    confirm = false
                    actions.submit()
                }, modifier = Modifier.testTag("confirmSubmit")) { Text(stringResource(R.string.submit)) }
            },
        )
    }
}
