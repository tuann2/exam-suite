import ExamImport
import ExamKit
import Foundation

/// Hộp thoại xác nhận của **Import đề…** (docs/product/import.md, Luồng bước 3): tiêu đề, mã đề, ngưỡng đậu (%) và
/// thời gian Thi (phút), điền sẵn từ file nếu có; trống thì phải nhập. Giá trị kiểm theo ràng buộc của exam-format.md
/// (cùng giới hạn với `ExamValidator`): **Import** chỉ bật khi mọi ô hợp lệ.
///
/// Ô số là chuỗi để "chưa nhập" khác "0". Không giao diện: test ở AuthoringFeatureTests.
public struct ImportConfirmForm: Equatable, Sendable {
    public enum Field: Hashable, Sendable, CaseIterable {
        case title
        case code
        case passPercent
        case timeLimitMinutes
    }

    public var title: String
    /// Mã đề (tuỳ chọn): để trống thì đề không có mã.
    public var code: String
    public var passPercent: String
    public var timeLimitMinutes: String
    /// Tóm tắt kết quả chuyển đổi, hiện dưới các ô.
    public let summary: ImportSummary

    public init(suggestions: ImportSuggestions, summary: ImportSummary) {
        title = suggestions.title
        code = suggestions.code ?? ""
        passPercent = suggestions.passPercent.map(String.init) ?? ""
        timeLimitMinutes = suggestions.timeLimitMinutes.map(String.init) ?? ""
        self.summary = summary
    }

    /// Chữ của một ô.
    public subscript(field: Field) -> String {
        get {
            switch field {
            case .title: title
            case .code: code
            case .passPercent: passPercent
            case .timeLimitMinutes: timeLimitMinutes
            }
        }
        set {
            switch field {
            case .title: title = newValue
            case .code: code = newValue
            case .passPercent: passPercent = newValue
            case .timeLimitMinutes: timeLimitMinutes = newValue
            }
        }
    }

    // MARK: - Kiểm giá trị

    /// Lý do ô chưa dùng được (tiếng Việt, hiện ngay dưới ô); `nil` nếu hợp lệ.
    public func problem(_ field: Field) -> String? {
        switch field {
        case .title:
            let value = Self.clean(title)
            if value.isEmpty {
                return localized("Nhập tiêu đề đề thi.")
            }
            let length = ExamValidator.textLength(value)
            if length > ExamValidator.Limits.titleLength.upperBound {
                return localized("Tiêu đề dài \(length) ký tự, tối đa \(ExamValidator.Limits.titleLength.upperBound).")
            }
            return nil
        case .code:
            let value = Self.clean(code)
            if value.isEmpty || ExamValidator.isValidCode(value) { return nil }
            return localized("Mã đề gồm 1–32 ký tự: chữ không dấu, số, dấu chấm, gạch ngang hoặc gạch dưới.")
        case .passPercent:
            let range = ExamValidator.Limits.passPercent
            if Self.clean(passPercent).isEmpty {
                return localized("Nhập ngưỡng đậu (%).")
            }
            guard let value = Self.integer(passPercent), range.contains(value) else {
                return localized("Ngưỡng đậu là số nguyên từ \(range.lowerBound) đến \(range.upperBound).")
            }
            return nil
        case .timeLimitMinutes:
            let range = ExamValidator.Limits.timeLimitMinutes
            if Self.clean(timeLimitMinutes).isEmpty {
                return localized("Nhập thời gian Thi (phút).")
            }
            guard let value = Self.integer(timeLimitMinutes), range.contains(value) else {
                return localized("Thời gian Thi là số nguyên từ \(range.lowerBound) đến \(range.upperBound) phút.")
            }
            return nil
        }
    }

    /// Mọi ô hợp lệ: **Import** bật.
    public var canImport: Bool { confirmation != nil }

    /// Giá trị đã kiểm cho `ImportResult.makePackage`; `nil` khi còn ô chưa hợp lệ.
    public var confirmation: ImportConfirmation? {
        guard Field.allCases.allSatisfy({ problem($0) == nil }),
              let pass = Self.integer(passPercent),
              let minutes = Self.integer(timeLimitMinutes)
        else { return nil }
        let code = Self.clean(code)
        return ImportConfirmation(
            title: Self.clean(title),
            code: code.isEmpty ? nil : code,
            passPercent: pass,
            timeLimitMinutes: minutes
        )
    }

    // MARK: - Chuẩn hoá

    /// NFC, bỏ khoảng trắng (Unicode `White_Space`) hai đầu, như bộ chuyển đổi và `ExamValidator`.
    static func clean(_ text: String) -> String {
        let scalars = text.precomposedStringWithCanonicalMapping.unicodeScalars
        guard let start = scalars.firstIndex(where: { !$0.properties.isWhitespace }),
              let end = scalars.lastIndex(where: { !$0.properties.isWhitespace })
        else { return "" }
        return String(String.UnicodeScalarView(scalars[start ... end]))
    }

    /// Số nguyên thập phân không dấu (chữ số ASCII, tối đa 6 chữ số); khác thì `nil`.
    static func integer(_ text: String) -> Int? {
        let value = clean(text)
        guard !value.isEmpty, value.count <= 6, value.unicodeScalars.allSatisfy({ ("0" ... "9").contains($0) }) else {
            return nil
        }
        return Int(value)
    }
}

/// Tóm tắt của hộp thoại xác nhận: số phần, số câu, số câu bị bỏ, số cảnh báo (import.md, Luồng bước 3).
public struct ImportSummary: Equatable, Sendable {
    public let sectionCount: Int
    public let questionCount: Int
    public let droppedCount: Int
    public let warningCount: Int

    public init(sectionCount: Int, questionCount: Int, droppedCount: Int, warningCount: Int) {
        self.sectionCount = sectionCount
        self.questionCount = questionCount
        self.droppedCount = droppedCount
        self.warningCount = warningCount
    }

    public init(_ result: ImportResult) {
        self.init(
            sectionCount: result.sections.count,
            questionCount: result.questionCount,
            droppedCount: result.report.droppedCount,
            warningCount: result.report.warningCount
        )
    }

    /// "2 phần · 40 câu · 1 câu bị bỏ · 3 cảnh báo".
    public var text: String {
        [
            localized("\(sectionCount) phần"),
            localized("\(questionCount) câu"),
            localized("\(droppedCount) câu bị bỏ"),
            localized("\(warningCount) cảnh báo"),
        ].joined(separator: " · ")
    }
}
