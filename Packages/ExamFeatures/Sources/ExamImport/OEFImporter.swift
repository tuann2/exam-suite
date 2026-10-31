import ExamFile
import ExamKit
import Foundation

/// Import file `.oef` của Open Exam Suite (docs/product/import.md mục `.oef`, ADR 0014): đọc bằng `OEFReader` ở chế
/// độ dễ, cùng bộ chuyển với bản Học viên mở thẳng file, nên đề import có cùng id, chữ và ảnh (`.exam` lưu ra thay được
/// file `.oef` mà lịch sử thi vẫn nối tiếp). Chỗ bộ đọc đã sửa hoặc bỏ thành mục báo cáo; phần không tên lấy tên phần
/// chung theo ngôn ngữ giao diện.
enum OEFImporter {
    static func convert(
        _ data: Data,
        fileStem: String,
        limits: ImportLimits,
        sharedSectionTitle: String,
        progress: ProgressReporter
    ) throws -> ImportResult {
        guard data.count <= limits.oefBytes else { throw ImportError.tooLarge(what: .oefFile, limit: limits.oefBytes) }
        try Task.checkCancellation()
        progress.report(.converting, fraction: 0.1)
        let readerLimits = OEFLimits(fileBytes: limits.oefBytes, imageBytes: limits.mediaEntryBytes,
                                     textBytes: limits.textBytes)
        let conversion: OEFReader.Conversion
        do {
            conversion = try OEFReader.convert(data, mode: .lenient, limits: readerLimits)
        } catch let ExamFileError.oef(problem) {
            throw ImportError.unreadableOEF(problem)
        }
        try Task.checkCancellation()

        let exam = conversion.package.exam
        var sections = exam.sections
        for index in sections.indices where sections[index].title.isEmpty {
            sections[index].title = sharedSectionTitle
        }
        var report = ReportBuilder()
        for note in conversion.notes {
            add(note, to: &report, conversion: conversion, sharedSectionTitle: sharedSectionTitle)
        }
        return ImportResult(
            examID: exam.id,
            sections: sections,
            media: conversion.package.media,
            report: report.makeReport(),
            suggestions: ImportSuggestions(
                title: exam.title.isEmpty ? fileStem : exam.title,
                code: exam.code,
                passPercent: conversion.passPercent,
                timeLimitMinutes: conversion.timeLimitMinutes
            ),
            sourceFormat: .oef,
            instructions: exam.instructions,
            hideAnswers: exam.hideAnswers
        )
    }

    private static func add(
        _ note: OEFNote, to report: inout ReportBuilder, conversion: OEFReader.Conversion, sharedSectionTitle: String
    ) {
        let examID = conversion.package.exam.id
        /// Vị trí "câu N" theo thứ tự trong file và id câu trong đề đã chuyển (`nil` khi câu bị bỏ).
        func at(_ place: OEFPlace, kept: Bool = true) -> (ImportLocation, UUID?) {
            let id = OEFReader.questionID(exam: examID, section: place.section, question: place.question)
            return (ImportLocation(questionNumber: conversion.questionNumber(place)), kept ? id : nil)
        }
        switch note {
        case let .unknownField(path):
            report.add(.unknownField, ImportLocation(), .oefUnknownField(path))
        case let .invalidCode(code):
            report.add(.invalidCode, ImportLocation(), .invalidOefCode(code))
        case .passmarkOutOfRange:
            report.add(.invalidPassingScore, ImportLocation(), .oefPassmarkOutOfRange)
        case let .timeLimitOutOfRange(value):
            report.add(.invalidTimeLimit, ImportLocation(), .invalidOefTimeLimit(value))
        case let .emptySection(section):
            report.add(.emptySection, ImportLocation(), .oefEmptySection(section: section + 1))
        case let .untitledSection(section):
            report.add(.untitledSection, ImportLocation(),
                       .oefUntitledSection(section: section + 1, fallbackSection: sharedSectionTitle))
        case let .noOptions(place):
            let (location, _) = at(place, kept: false)
            report.add(.noOptions, location, .noOptions(misplaced: nil))
        case let .tooManyOptions(place, count):
            let (location, id) = at(place)
            report.add(.tooManyOptions, location, question: id, .tooManyOptions(count: count))
        case let .duplicateOptionLetter(place, letter):
            let (location, id) = at(place)
            report.add(.duplicateOptionLetter, location, question: id, .oefDuplicateOptionLetter(letter))
        case let .answerNotInOptions(place, letters):
            let (location, id) = at(place)
            report.add(.answerNotInOptions, location, question: id, .oefAnswerNotInOptions(letters))
        case let .unsupportedImage(place):
            let (location, id) = at(place)
            report.add(.unsupportedImageFormat, location, question: id, .unsupportedImageFormat(fileExtension: nil))
        case let .imageTooLarge(place, _):
            let (location, id) = at(place)
            report.add(.imageTooLarge, location, question: id, .oefImageTooLarge)
        }
    }
}
