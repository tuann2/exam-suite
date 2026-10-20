import AuthoringData
import ExamKit
import Foundation
import LibraryFeature
import SessionFeature

/// Chữ của cây đề và thanh lỗi, tách khỏi view để test (VoiceOver, biểu tượng + chữ).
public enum AuthoringPresentation {
    /// Biểu tượng và chữ của một mức vấn đề (không chỉ dựa vào màu).
    public static func severityTitle(_ severity: IssueSeverity) -> String {
        switch severity {
        case .error: localized("Lỗi")
        case .warning: localized("Cảnh báo")
        }
    }

    public static func severitySymbol(_ severity: IssueSeverity) -> String {
        switch severity {
        case .error: "xmark.octagon.fill"
        case .warning: "exclamationmark.triangle.fill"
        }
    }

    /// Dòng đầu của câu trên cây đề; câu chưa có nội dung thì nói rõ.
    public static func firstLine(_ summary: QuestionSummary) -> String {
        summary.firstLine.isEmpty ? localized("(Chưa có nội dung)") : summary.firstLine
    }

    /// Trạng thái lỗi của một dòng: "2 lỗi, 1 cảnh báo"; rỗng nếu không có vấn đề.
    public static func issueStatus(_ issues: [ValidationIssue]) -> String {
        let errors = issues.count { $0.severity == .error }
        let warnings = issues.count - errors
        var parts: [String] = []
        if errors > 0 { parts.append(localized("\(errors) lỗi")) }
        if warnings > 0 { parts.append(localized("\(warnings) cảnh báo")) }
        return parts.joined(separator: ", ")
    }

    /// Câu VoiceOver đọc cho dòng câu: số, dòng đầu, ảnh, loại, trạng thái lỗi (authoring.md, mục Bàn phím và trợ năng).
    /// Dòng đầu đọc chữ trơn, không đọc ký hiệu Markdown (`**`, `` ` ``; bước 8b), dù trên cây vẫn hiện nguyên văn.
    public static func questionAccessibilityLabel(_ summary: QuestionSummary, issues: [ValidationIssue]) -> String {
        var parts = [localized("Câu \(summary.number)"), PlainMarkdown.text(firstLine(summary))]
        if summary.hasImage { parts.append(localized("có ảnh")) }
        if summary.isMultiple { parts.append(localized("nhiều đáp án")) }
        let status = issueStatus(issues)
        parts.append(status.isEmpty ? localized("không có lỗi") : status)
        return parts.joined(separator: ", ")
    }

    public static func sectionAccessibilityLabel(_ section: SectionSummary, issues: [ValidationIssue]) -> String {
        var parts = [sectionTitle(section.title), localized("\(section.questions.count) câu")]
        let status = issueStatus(issues)
        if !status.isEmpty { parts.append(status) }
        return parts.joined(separator: ", ")
    }

    public static func sectionTitle(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? localized("(Phần chưa có tên)") : title
    }

    /// Câu VoiceOver khi lần kiểm đề có thêm `count` lỗi: "Kiểm đề: 2 lỗi mới".
    public static func newErrorsAnnouncement(_ count: Int) -> String {
        localized("Kiểm đề: \(count) lỗi mới")
    }

    /// Câu VoiceOver khi lưu xong (⌘S, Lưu thành…): "Đã lưu “Đề thử.exam”".
    public static func savedAnnouncement(fileName: String) -> String {
        localized("Đã lưu “\(fileName)”")
    }

    /// Tóm tắt của thanh lỗi: "3 lỗi · 1 cảnh báo", hoặc "Không có lỗi".
    public static func issueBarSummary(errors: Int, warnings: Int) -> String {
        if errors == 0 && warnings == 0 { return localized("Không có lỗi hay cảnh báo") }
        return [
            errors > 0 ? localized("\(errors) lỗi") : nil,
            warnings > 0 ? localized("\(warnings) cảnh báo") : nil,
        ].compactMap { $0 }.joined(separator: " · ")
    }

    /// Chỗ của vấn đề, để dòng của thanh lỗi nói rõ bấm vào sẽ tới đâu.
    public static func location(of issue: ValidationIssue) -> String {
        switch IssueTarget(issue).node {
        case .exam:
            return localized("Đề")
        case let .section(_, index):
            return localized("Phần \(index + 1)")
        case let .question(_, path):
            return localized("Phần \(path.section + 1), câu \(path.question + 1)")
        case let .option(_, path, option):
            let letter = OptionID(index: option)?.description ?? "\(option + 1)"
            return localized("Phần \(path.section + 1), câu \(path.question + 1), lựa chọn \(letter)")
        }
    }

    /// Ngưỡng đậu theo thang 1000 hiển thị cạnh ô % (scoring.md: đậu khi `score1000 >= passPercent * 10`): "= 700/1000",
    /// "= 1000/1000". Thang 1000 luôn số trơn ở mọi ngôn ngữ (Nt0 chốt 2026-10-17, `InterfaceLocale.scale1000`).
    /// `locale` chỉ để test tra theo ngôn ngữ cố định; `nil` là ngôn ngữ giao diện.
    public static func passScale1000(_ percent: Int, locale: Locale? = nil) -> String {
        let scaled = InterfaceLocale.scale1000(percent * 10)
        guard let locale else { return localized("= \(scaled)/1000") }
        return InterfaceStrings.resolve("= \(scaled)/1000", bundle: ModuleStrings.bundle, locale: locale)
    }
}
