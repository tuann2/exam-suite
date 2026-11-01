package vn.io.nt0.examsuite.app

import androidx.compose.runtime.Composable
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import vn.io.nt0.examsuite.R
import vn.io.nt0.examsuite.attempt.ui.num
import vn.io.nt0.examsuite.core.file.ExamFileError
import vn.io.nt0.examsuite.core.file.OefLimit
import vn.io.nt0.examsuite.core.file.OefPlace
import vn.io.nt0.examsuite.core.file.OefProblem
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
    ImportProblem.NotAnExamFile -> stringResource(R.string.error_not_exam_file)
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
    is ExamFileError.Oef -> oefProblemMessage(error.problem)
}

/**
 * File `.oef` của Open Exam Suite không đọc được: cùng câu với bản macOS, trừ danh sách đường dẫn và chữ đáp án rút gọn
 * còn 5 mục như các câu khác của bản Android (`paths`). Vị trí byte là mã: chữ số trơn.
 */
@Composable
@ReadOnlyComposable
private fun oefProblemMessage(problem: OefProblem): String = when (problem) {
    OefProblem.LegacyFormat -> stringResource(R.string.error_oef_legacy)
    is OefProblem.Malformed -> stringResource(R.string.error_oef_malformed, problem.offset.toString())
    OefProblem.NoQuestions -> stringResource(R.string.error_oef_no_questions)
    is OefProblem.TooLarge -> when (problem.limit) {
        OefLimit.FILE -> stringResource(R.string.error_oef_file_too_large, num(problem.value))
        OefLimit.TEXT -> stringResource(R.string.error_oef_text_too_large, num(problem.value))
        OefLimit.ELEMENTS -> stringResource(R.string.error_oef_too_many_elements, num(problem.value))
    }
    is OefProblem.ImageTooLarge -> stringResource(R.string.error_oef_image_too_large, oefPlace(problem.place), num(problem.limit))
    is OefProblem.UnknownFields -> stringResource(R.string.error_oef_unknown_fields, paths(problem.paths))
    OefProblem.PassmarkOutOfRange -> stringResource(R.string.error_oef_passmark_out_of_range)
    is OefProblem.UnsupportedImage -> stringResource(R.string.error_oef_unsupported_image, oefPlace(problem.place))
    is OefProblem.TooManyOptions -> stringResource(R.string.error_oef_too_many_options, oefPlace(problem.place), num(problem.count))
    is OefProblem.DuplicateOptionLetter -> stringResource(R.string.error_oef_duplicate_letter, oefPlace(problem.place), problem.letter)
    is OefProblem.AnswerNotInOptions -> stringResource(R.string.error_oef_answer_not_in_options, paths(problem.letters), oefPlace(problem.place))
}

/** "phần 2, câu 3": vị trí câu trong file `.oef`, đếm từ 1. */
@Composable
@ReadOnlyComposable
private fun oefPlace(place: OefPlace): String = stringResource(R.string.oef_place, num(place.section + 1), num(place.question + 1))

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
