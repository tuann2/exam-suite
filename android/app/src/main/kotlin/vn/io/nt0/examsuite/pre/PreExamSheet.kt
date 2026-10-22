package vn.io.nt0.examsuite.pre

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.Checkbox
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.RadioButton
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import vn.io.nt0.examsuite.R
import vn.io.nt0.examsuite.app.PreExamUi
import vn.io.nt0.examsuite.app.preExamIssueMessage
import vn.io.nt0.examsuite.app.startErrorMessage
import vn.io.nt0.examsuite.attempt.ui.MarkdownText
import vn.io.nt0.examsuite.attempt.ui.modeText
import vn.io.nt0.examsuite.attempt.ui.num
import vn.io.nt0.examsuite.attempt.ui.percentText
import vn.io.nt0.examsuite.core.session.SessionMode

/** Màn **Trước khi thi** dạng bảng kéo lên từ dưới (plan-android-v1.md A3a; exam-taking.md, Trước khi thi). */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PreExamSheet(ui: PreExamUi, onChange: ((PreExamForm) -> PreExamForm) -> Unit, onStart: () -> Unit, onCancel: () -> Unit) {
    ModalBottomSheet(
        onDismissRequest = onCancel,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        // Không có tay nắm: tay nắm mặc định là vùng chạm dưới 48dp (kiểm trợ năng của test Compose); đóng bằng Huỷ, vuốt
        // xuống hay chạm ra ngoài.
        dragHandle = null,
    ) {
        PreExamContent(ui, onChange, onStart, onCancel)
    }
}

@Composable
fun PreExamContent(ui: PreExamUi, onChange: ((PreExamForm) -> PreExamForm) -> Unit, onStart: () -> Unit, onCancel: () -> Unit) {
    val form = ui.form
    val exam = form.exam
    Column(
        Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).navigationBarsPadding().padding(start = 16.dp, end = 16.dp, top = 16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(stringResource(R.string.pre_exam_title), style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(exam.title, style = MaterialTheme.typography.headlineSmall, modifier = Modifier.semantics { heading() })
        exam.code?.let { Text(it, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant) }
        exam.instructions?.let { MarkdownText(it, style = MaterialTheme.typography.bodyMedium) }

        Text(stringResource(R.string.mode), style = MaterialTheme.typography.titleSmall)
        ModeRow(form, onChange)
        if (exam.hideAnswers) Text(stringResource(R.string.practice_unavailable), style = MaterialTheme.typography.bodySmall)

        OutlinedTextField(
            value = form.candidateName,
            onValueChange = { name -> onChange { it.copy(candidateName = name) } },
            label = { Text(stringResource(R.string.candidate_name)) },
            singleLine = true,
            modifier = Modifier.fillMaxWidth().testTag("candidateName"),
        )

        if (form.isPracticeIncorrect) {
            Text(pluralStringResource(R.plurals.practice_incorrect_summary, form.questionCount, num(form.questionCount)), style = MaterialTheme.typography.bodyMedium)
        } else {
            SelectionGroup(form, onChange)
            SwitchRow(stringResource(R.string.shuffle_questions), form.shuffleQuestions) { v -> onChange { it.copy(shuffleQuestions = v) } }
            SwitchRow(stringResource(R.string.shuffle_options), form.shuffleOptions) { v -> onChange { it.copy(shuffleOptions = v) } }
            if (form.showsTimeLimit) {
                NumberField(form.timeLimitText, stringResource(R.string.time_limit_minutes), Modifier.testTag("timeLimit")) { v ->
                    onChange { it.copy(timeLimitText = v) }
                }
            }
        }

        HorizontalDivider()
        Text(summaryLine(form), style = MaterialTheme.typography.titleMedium)
        val issue = form.issues.firstOrNull()?.let { preExamIssueMessage(it) } ?: ui.startError?.let { startErrorMessage(it) }
        issue?.let {
            Text(it, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite })
        }
        Row(Modifier.fillMaxWidth().padding(bottom = 16.dp), horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.End)) {
            TextButton(onClick = onCancel) { Text(stringResource(R.string.cancel)) }
            Button(onClick = onStart, enabled = form.canStart && !ui.starting, modifier = Modifier.testTag("start")) {
                Text(stringResource(R.string.start))
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ModeRow(form: PreExamForm, onChange: ((PreExamForm) -> PreExamForm) -> Unit) {
    val modes = listOf(SessionMode.PRACTICE, SessionMode.EXAM)
    SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
        modes.forEachIndexed { i, mode ->
            SegmentedButton(
                selected = form.mode == mode,
                onClick = { onChange { it.withMode(mode) } },
                enabled = form.canChangeOptions && !(mode == SessionMode.PRACTICE && form.exam.hideAnswers),
                shape = SegmentedButtonDefaults.itemShape(i, modes.size),
                modifier = Modifier.testTag("mode-${mode.name}"),
                label = { Text(modeText(mode)) },
            )
        }
    }
}

@Composable
private fun SelectionGroup(form: PreExamForm, onChange: ((PreExamForm) -> PreExamForm) -> Unit) {
    Text(stringResource(R.string.question_selection), style = MaterialTheme.typography.titleSmall)
    Column(Modifier.selectableGroup()) {
        RadioRow(stringResource(R.string.all_questions_count, num(form.totalQuestionCount)), form.kind == SelectionKind.ALL) {
            onChange { it.copy(kind = SelectionKind.ALL) }
        }
        RadioRow(stringResource(R.string.by_section), form.kind == SelectionKind.SECTIONS) { onChange { it.copy(kind = SelectionKind.SECTIONS) } }
        if (form.kind == SelectionKind.SECTIONS) {
            Column(Modifier.padding(start = 24.dp)) {
                form.sections.forEach { section ->
                    Row(
                        Modifier.fillMaxWidth().heightIn(min = 48.dp)
                            .toggleable(section.isSelected, role = Role.Checkbox) { v -> onChange { it.withSection(section.id, v) } },
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Checkbox(checked = section.isSelected, onCheckedChange = null)
                        Text(section.title, Modifier.weight(1f).padding(horizontal = 8.dp))
                        Text(pluralStringResource(R.plurals.question_count, section.questionCount, num(section.questionCount)), style = MaterialTheme.typography.bodySmall)
                    }
                }
                Row {
                    TextButton(onClick = { onChange { it.selectAllSections() } }) { Text(stringResource(R.string.select_all)) }
                    TextButton(onClick = { onChange { it.deselectAllSections() } }) { Text(stringResource(R.string.deselect_all)) }
                }
            }
        }
        RadioRow(stringResource(R.string.random_questions), form.kind == SelectionKind.RANDOM) { onChange { it.copy(kind = SelectionKind.RANDOM) } }
        if (form.kind == SelectionKind.RANDOM) {
            NumberField(
                form.randomCountText,
                stringResource(R.string.random_count_label, num(form.totalQuestionCount)),
                Modifier.padding(start = 24.dp).testTag("randomCount"),
            ) { v -> onChange { it.copy(randomCountText = v) } }
        }
    }
}

@Composable
private fun RadioRow(label: String, selected: Boolean, onSelect: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().heightIn(min = 48.dp).selectable(selected, role = Role.RadioButton, onClick = onSelect),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        RadioButton(selected = selected, onClick = null)
        Text(label, Modifier.padding(start = 8.dp))
    }
}

@Composable
private fun SwitchRow(label: String, checked: Boolean, onChange: (Boolean) -> Unit) {
    Row(
        Modifier.fillMaxWidth().heightIn(min = 48.dp).toggleable(checked, role = Role.Switch, onValueChange = onChange),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(label, Modifier.weight(1f))
        Switch(checked = checked, onCheckedChange = null)
    }
}

@Composable
private fun NumberField(value: String, label: String, modifier: Modifier = Modifier, onChange: (String) -> Unit) {
    OutlinedTextField(
        value = value,
        onValueChange = { text -> onChange(text.filter { it.isDigit() }.take(5)) },
        label = { Text(label) },
        singleLine = true,
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
        modifier = modifier.fillMaxWidth(),
    )
}

/** "60 câu · 90 phút · đậu 70%" (Luyện tập: "60 câu · không giới hạn giờ · đậu 70%"). */
@Composable
fun summaryLine(form: PreExamForm): String {
    val count = form.questionCount
    val time = if (form.mode == SessionMode.EXAM) {
        val minutes = form.timeLimitMinutes ?: 0
        pluralStringResource(R.plurals.duration_minutes, minutes, num(minutes))
    } else {
        stringResource(R.string.no_time_limit)
    }
    return listOf(
        pluralStringResource(R.plurals.question_count, count, num(count)),
        time,
        stringResource(R.string.pass_from, percentText(form.exam.passPercent.toInt())),
    ).joinToString(stringResource(R.string.summary_separator))
}
