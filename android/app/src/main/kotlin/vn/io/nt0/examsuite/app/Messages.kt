package vn.io.nt0.examsuite.app

import androidx.compose.runtime.Composable
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import vn.io.nt0.examsuite.R
import vn.io.nt0.examsuite.attempt.ui.num
import vn.io.nt0.examsuite.core.file.ExamFileError
import vn.io.nt0.examsuite.core.session.ExamSession
import vn.io.nt0.examsuite.data.library.ImportProblem
import vn.io.nt0.examsuite.pre.PreExamIssue

// Câu báo lỗi dựng theo mã của lõi và `:data` (chữ của strings.xml); câu tiếng Việt của lõi chỉ cho nhật ký.

private const val MAX_PATHS = 5

/** Danh sách đường dẫn trong đề: tối đa vài mục, còn lại thành "…". Đường dẫn là mã, không dịch. */
private fun paths(list: List<String>): String =
    list.take(MAX_PATHS).joinToString(", ") + if (list.size > MAX_PATHS) ", …" else ""

@Composable
@ReadOnlyComposable
fun importProblemMessage(problem: ImportProblem): String = when (problem) {
    is ImportProblem.InvalidPackage -> examFileErrorMessage(problem.error)
    is ImportProblem.FileTooLarge -> stringResource(R.string.error_file_too_large, num((problem.limitBytes / (1024 * 1024)).toInt()))
    is ImportProblem.Io -> stringResource(R.string.error_file_unreadable)
}

@Composable
@ReadOnlyComposable
fun examFileErrorMessage(error: ExamFileError): String = when (error) {
    ExamFileError.NotAZipArchive -> stringResource(R.string.error_not_zip)
    ExamFileError.MissingManifest -> stringResource(R.string.error_missing_manifest)
    is ExamFileError.CorruptedEntry -> stringResource(R.string.error_corrupted_entry, error.path)
    is ExamFileError.InvalidJson -> stringResource(R.string.error_invalid_json)
    // Số phiên bản định dạng là mã: chữ số trơn.
    is ExamFileError.UnsupportedVersion -> stringResource(R.string.error_unsupported_version, error.found.toString(), error.supported.toString())
    is ExamFileError.InvalidVersion -> stringResource(R.string.error_invalid_version, error.version.toString())
    is ExamFileError.UnknownFields -> stringResource(R.string.error_unknown_fields, paths(error.paths))
    is ExamFileError.DuplicateJsonKeys -> stringResource(R.string.error_duplicate_keys, paths(error.paths))
    is ExamFileError.NullValues -> stringResource(R.string.error_null_values, paths(error.paths))
    is ExamFileError.MissingMedia -> stringResource(R.string.error_missing_media, paths(error.paths))
    is ExamFileError.InvalidMediaPath -> stringResource(R.string.error_invalid_media_path, paths(error.paths))
    is ExamFileError.ValidationFailed -> pluralStringResource(R.plurals.error_validation_failed, error.issues.size, num(error.issues.size))
    is ExamFileError.DuplicateEntry -> stringResource(R.string.error_duplicate_entry, error.path)
    is ExamFileError.TooLarge -> stringResource(R.string.error_too_large, error.entry, error.limit.toString())
    is ExamFileError.TooDeep -> stringResource(R.string.error_too_deep, num(error.limit))
    is ExamFileError.MigrationFailed -> stringResource(R.string.error_migration_failed, error.from.toString(), (error.from + 1).toString())
}

@Composable
@ReadOnlyComposable
fun preExamIssueMessage(issue: PreExamIssue): String = when (issue) {
    PreExamIssue.PracticeUnavailable -> stringResource(R.string.practice_unavailable)
    PreExamIssue.NoQuestionsToPractice -> stringResource(R.string.no_questions_to_practice)
    PreExamIssue.ExamHasNoQuestions -> stringResource(R.string.exam_has_no_questions)
    PreExamIssue.NoSectionSelected -> stringResource(R.string.no_section_selected)
    PreExamIssue.SelectedSectionsEmpty -> stringResource(R.string.selected_sections_empty)
    is PreExamIssue.RandomCountOutOfRange -> stringResource(R.string.random_count_out_of_range, num(issue.total))
    PreExamIssue.TimeLimitOutOfRange -> stringResource(
        R.string.time_limit_out_of_range,
        num(ExamSession.TIME_LIMIT_RANGE.first),
        num(ExamSession.TIME_LIMIT_RANGE.last),
    )
    PreExamIssue.EmptyCandidateName -> stringResource(R.string.empty_candidate_name)
}

@Composable
@ReadOnlyComposable
fun startErrorMessage(error: StartError): String = when (error) {
    is StartError.Unreadable -> stringResource(R.string.start_unreadable, examFileErrorMessage(error.error))
    StartError.Changed -> stringResource(R.string.start_exam_changed)
    StartError.Failed -> stringResource(R.string.start_failed)
}
