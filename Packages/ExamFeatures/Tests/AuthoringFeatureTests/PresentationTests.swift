import AppKit
import AuthoringData
@testable import AuthoringFeature
import ExamKit
import Foundation
import LibraryFeature
import SwiftUI
import Testing

@Suite("Màu burgundy đạt tương phản; chữ VoiceOver và thanh lỗi")
struct PresentationTests {
    private static let smallText = 4.5
    private static let largeTextOrIcon = 3.0

    @Test("Màu nhấn burgundy #801638; nền nút có chữ trắng đạt 4,5:1")
    func accentFill() {
        #expect(AuthoringPalette.accentFillLight == LibraryPalette.RGB(hex: 0x801638))
        for fill in [AuthoringPalette.accentFillLight, AuthoringPalette.accentFillDark] {
            #expect(LibraryPalette.contrast(LibraryPalette.white, fill) >= Self.smallText)
        }
    }

    @Test("Chữ burgundy đạt 4,5:1 trên mọi nền (kể cả nền cửa sổ thật) và nền nhạt, ở giao diện sáng và tối",
          arguments: [false, true])
    @MainActor
    func accentForegroundIsReadable(dark: Bool) {
        let foreground = dark ? AuthoringPalette.accentForegroundDark : AuthoringPalette.accentForegroundLight
        for background in LibraryPalette.backgrounds(dark: dark) {
            let tinted = foreground.blended(over: background, opacity: LibraryPalette.tintedBackgroundOpacity)
            #expect(LibraryPalette.contrast(foreground, background) >= Self.smallText, "\(background)")
            #expect(LibraryPalette.contrast(foreground, tinted) >= Self.smallText, "\(background)")
        }
    }

    @Test("Nền dòng đang chọn của cây đề là burgundy đặc có chữ trắng 4,5:1; burgundy sáng của giao diện tối thì không")
    func selectedTreeRowFill() {
        for dark in [false, true] {
            #expect(LibraryPalette.contrast(LibraryPalette.white, AuthoringPalette.accentFill.rgb(dark: dark)) >= Self.smallText)
        }
        // Lý do cây đề đặt `.tint(AuthoringStyle.accentFill)`: tint của cửa sổ ở giao diện tối là #F7A1B8.
        #expect(LibraryPalette.contrast(LibraryPalette.white, AuthoringPalette.accentForeground.dark) < Self.largeTextOrIcon)
    }

    @Test("AuthoringStyle dựng đúng màu sRGB của AuthoringPalette và LibraryPalette ở từng giao diện", arguments: [false, true])
    @MainActor
    func styleColorsMatchPalette(dark: Bool) {
        let cases: [(name: String, color: Color, pair: LibraryPalette.Pair)] = [
            ("accentForeground", AuthoringStyle.accentForeground, AuthoringPalette.accentForeground),
            ("accentFill", AuthoringStyle.accentFill, AuthoringPalette.accentFill),
            ("critical", AuthoringStyle.critical, LibraryPalette.critical),
            ("warning", AuthoringStyle.warning, LibraryPalette.warning),
        ]
        for item in cases {
            let resolved = LibraryPalette.systemColor(NSColor(item.color), dark: dark)
            #expect(resolved.rgb == item.pair.rgb(dark: dark), "\(item.name)")
        }
    }

    @Test("Dòng câu VoiceOver: số, dòng đầu, ảnh, nhiều đáp án, trạng thái lỗi")
    func questionLabel() {
        var question = makeQuestion(11, "\n  Thủ đô **Việt Nam**?\nDòng hai", type: .multiple)
        question.image = "media/0123456789abcdef.png"
        let summary = QuestionSummary(question, path: QuestionPath(section: 0, question: 2), number: 7)
        #expect(summary.firstLine == "Thủ đô **Việt Nam**?")
        let issues = ExamValidator.validate(Exam(
            id: fixedID(1), title: "Đ", passPercent: 70, timeLimitMinutes: 10,
            sections: [ExamSection(id: fixedID(2), title: "P", questions: [question])]
        ), availableMedia: [])
        // Dòng đầu hiện nguyên văn trên cây, VoiceOver đọc chữ trơn (không đọc "**").
        #expect(AuthoringPresentation.questionAccessibilityLabel(summary, issues: issues)
            == "Câu 7, Thủ đô Việt Nam?, có ảnh, nhiều đáp án, 1 lỗi, 1 cảnh báo")
        let empty = QuestionSummary(makeQuestion(12, " "), path: QuestionPath(section: 0, question: 0), number: 1)
        #expect(AuthoringPresentation.questionAccessibilityLabel(empty, issues: [])
            == "Câu 1, (Chưa có nội dung), không có lỗi")
    }

    @Test("Tóm tắt thanh lỗi, chỗ của vấn đề, thang 1000")
    func issueBarTexts() {
        #expect(AuthoringPresentation.issueBarSummary(errors: 0, warnings: 0) == "Không có lỗi hay cảnh báo")
        #expect(AuthoringPresentation.issueBarSummary(errors: 3, warnings: 1) == "3 lỗi · 1 cảnh báo")
        let issue = ValidationIssue(
            code: .optionTextEmpty,
            location: .option(sectionIndex: 1, questionIndex: 4, optionIndex: 2, questionID: fixedID(1)),
            message: ""
        )
        #expect(AuthoringPresentation.location(of: issue) == "Phần 2, câu 5, lựa chọn C")
        #expect(AuthoringPresentation.passScale1000(70) == "= 700/1000")
    }

    /// Thang 1000 luôn số trơn ở mọi ngôn ngữ (Nt0 chốt 2026-10-17): "= 1000/1000", không "= 1.000/1000" (vi) hay
    /// "= 1,000/1000" (en). Tiếng Anh chưa có bản dịch (bước 7c) nên chỉ so phần số.
    @Test("Soạn đề: ngưỡng thang 1000 số trơn với locale vi và en")
    func passScale1000IsPlainDigits() {
        #expect(AuthoringPresentation.passScale1000(100) == "= 1000/1000")
        #expect(AuthoringPresentation.passScale1000(100, locale: Locale(identifier: "vi")) == "= 1000/1000")
        #expect(AuthoringPresentation.passScale1000(100, locale: Locale(identifier: "en")).hasSuffix("1000/1000"))
        #expect(AuthoringPresentation.passScale1000(85, locale: Locale(identifier: "en")).hasSuffix("850/1000"))
    }
}
