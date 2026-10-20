import ExamKit
import Foundation
@testable import LibraryFeature
import PDFKit
import ReportFeature
@testable import SessionFeature
import Testing

/// PDF kết quả ở giao diện tiếng Anh (giai đoạn 5 bước 7c; export-print.md "Ngôn ngữ nhãn": nhãn theo ngôn ngữ giao diện,
/// nội dung đề giữ nguyên): cả luồng Kết quả → Xem lại → `ResultsReport` → PDF đọc lại bằng PDFKit, chữ tra catalog `en`
/// (`InterfaceStrings.languageOverride`, vì `swift test` khoá tiếng Việt), số và ngày dạng tiếng Anh.
@MainActor
@Suite("PDF kết quả tiếng Anh")
struct EnglishResultsReportTests {
    private let en = Locale(identifier: "en")
    private let utc = TimeZone(identifier: "UTC")!

    @Test("Nhãn tiếng Anh, nội dung đề tiếng Việt nguyên văn, không còn nhãn tiếng Việt")
    func englishLabels() async throws {
        let base = ResultsReportTests()
        let text = try await InterfaceStrings.$languageOverride.withValue(en) {
            let harness = Harness(candidateName: "Nguyễn Văn Đức")
            let (results, _) = try await base.submit(harness, exam: base.exam(), plan: "cccc-", flags: [1])
            let review = await results.makeAnswerReview()
            let report = ResultsReport(
                results: results, review: review, level: .all, appVersion: "1.0", locale: en, timeZone: utc
            )
            #expect(report.verdict.title == "Pass")
            #expect(report.headerFields.map(\.label)
                == ["Candidate", "Exam code", "Mode", "Submitted", "Time taken", "Passing score"])
            let pdf = try await ReportRenderer(locale: en).render(report.document())
            let reader = try #require(PDFDocument(data: pdf.data))
            let attributes = reader.documentAttributes ?? [:]
            #expect(attributes[PDFDocumentAttribute.titleAttribute] as? String == "Địa lý Đông Nam Á – Results")
            // Chữ đọc lại nguyên văn, không so sau NFKC: PDF không có chữ ghép (bước 8a; "official" của chân trang).
            return try #require(reader.string)
        }
        let ligatures = text.unicodeScalars.filter { (0xFB00 ... 0xFB06).contains($0.value) }
        #expect(ligatures.isEmpty, "PDF có chữ ghép: \(ligatures.map { String(format: "U+%04X", $0.value) })")
        for expected in ["Results", "Candidate", "Passing score", "Correct answers", "By Section", "Weakest section",
                         "Answer Review", "Your answer", "Correct answer", "Explanation", "Flagged", "Page 1 of",
                         "Practice result, not an official certification", "Question 1 of 5",
                         // Nội dung đề và tên thí sinh giữ nguyên.
                         "Địa lý Đông Nam Á", "Nguyễn Văn Đức", "Địa hình", "Đỉnh núi cao nhất?"] {
            #expect(text.contains(expected), "thiếu \(expected)")
        }
        for vietnamese in ["Thí sinh", "Ngưỡng đậu", "Theo phần", "Phần yếu nhất", "Xem lại bài", "Bạn chọn", "Đáp án đúng",
                           "Giải thích", "Trang ", "Kết quả luyện tập", "Số câu đúng", "Câu 1/5"] {
            #expect(!text.contains(vietnamese), "còn nhãn tiếng Việt: \(vietnamese)")
        }
    }
}
