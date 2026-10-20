import ExamImport
import Foundation

/// Báo cáo import mở cùng cửa sổ soạn đề chưa lưu (docs/product/import.md, Luồng bước 5): từng câu bị bỏ hoặc có cảnh
/// báo, kèm vị trí trong file gốc và lý do. Mục gắn với một câu còn trong đề thì bấm để nhảy tới câu đó.
///
/// Chỉ sống trong bộ nhớ của cửa sổ: không ghi vào file `.exam`, mở lại file đã lưu thì không còn.
public struct ImportReportState: Equatable, Sendable {
    /// Tên file gốc (có đuôi), hiện trên đầu bảng báo cáo.
    public let fileName: String
    public let rows: [ImportReportRow]
    /// Số câu bị bỏ và số cảnh báo của cả báo cáo, kể cả các mục chỉ được đếm trong dòng tóm tắt (báo cáo quá 1.000
    /// mục; `ImportReport.droppedCount`/`warningCount`), không phải số dòng.
    public let droppedCount: Int
    public let warningCount: Int

    public init(fileName: String, report: ExamImport.ImportReport) {
        self.fileName = fileName
        rows = report.entries.enumerated().map { ImportReportRow(id: $0.offset, entry: $0.element) }
        droppedCount = report.droppedCount
        warningCount = report.warningCount
    }

    /// "Báo cáo import “de.docx”: 1 câu bị bỏ · 3 cảnh báo", hoặc "… không có câu bị bỏ hay cảnh báo".
    public var summary: String {
        if rows.isEmpty {
            return localized("Báo cáo import “\(fileName)”: không có câu bị bỏ hay cảnh báo")
        }
        return localized("Báo cáo import “\(fileName)”: \(droppedCount) câu bị bỏ · \(warningCount) cảnh báo")
    }
}

/// Một dòng của báo cáo import.
public struct ImportReportRow: Identifiable, Equatable, Sendable {
    /// Thứ tự trong báo cáo (từ 0).
    public let id: Int
    public let code: ImportIssueCode
    public let severity: ImportSeverity
    /// "Câu 12, dòng 345", "Câu 3", "Dòng 2", "Đầu file".
    public let location: String
    public let message: String
    /// Câu trong đề đã chuyển; `nil` với câu bị bỏ, mục không thuộc câu nào hoặc dòng tóm tắt (không bấm được).
    public let questionID: UUID?
    /// Số mục dòng này đại diện: 1, hoặc N với dòng tóm tắt "… và N mục tương tự" (một loại mục vượt 1.000 mục chi
    /// tiết).
    public let occurrences: Int
    /// Dòng tóm tắt các mục không liệt kê chi tiết của một loại (`ImportReportEntry.isSummary`).
    public let isSummary: Bool

    init(id: Int, entry: ImportReportEntry) {
        self.id = id
        code = entry.code
        severity = entry.severity
        occurrences = entry.occurrences
        isSummary = entry.isSummary
        if entry.isSummary {
            // Dòng tóm tắt không có vị trí trong file gốc.
            location = localized("\(entry.occurrences) mục")
            questionID = nil
        } else {
            location = AuthoringMessages.location(entry.location)
            questionID = entry.questionID
        }
        message = AuthoringMessages.message(for: entry.detail)
    }


    /// Dòng này dẫn tới đâu trong đề hiện tại.
    public enum Destination: Equatable, Sendable {
        /// Câu còn trong đề: bấm để chọn câu.
        case question(UUID)
        /// Câu đã bị xoá sau khi import: dòng không bấm được, kèm ghi chú "câu đã bị xoá".
        case deletedQuestion
        /// Mục không thuộc câu nào trong đề (câu bị bỏ khi import, đầu file).
        case none
    }

    /// Đích của dòng với đề hiện tại (`containsQuestion`: câu có id đó còn trong đề).
    public func destination(containsQuestion: (UUID) -> Bool) -> Destination {
        guard !isSummary, let questionID else { return .none }
        return containsQuestion(questionID) ? .question(questionID) : .deletedQuestion
    }

    /// Chữ đi kèm biểu tượng mức (không chỉ dựa vào màu).
    public var severityTitle: String {
        switch severity {
        case .dropped: localized("Bị bỏ")
        case .warning: localized("Cảnh báo")
        }
    }

    public var severitySymbol: String {
        switch severity {
        case .dropped: "minus.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        }
    }

    /// Câu VoiceOver đọc: mức, vị trí, lý do.
    public var accessibilityLabel: String {
        "\(severityTitle), \(location): \(message)"
    }
}
