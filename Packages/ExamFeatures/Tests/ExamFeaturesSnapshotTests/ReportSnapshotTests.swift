@testable import AuthoringFeature
import ExamFile
import ExamKit
import Foundation
import LibraryFeature
import ReportFeature
@testable import SessionFeature
import Testing

/// Trang 1 của PDF kết quả và PDF đề, A4, sáng (docs/product/export-print.md, Kiểm chứng: "Snapshot trang đầu (sáng, A4)
/// cho kết quả và đề"; plan giai đoạn 5 bước 8a, review độc lập #49). Dựng PDF thật bằng `ReportRenderer` (như Xuất PDF…)
/// rồi vẽ trang 1 ra ảnh bằng Core Graphics (`SnapshotHost.assertPDFPage`).
extension SnapshotSuite {
    @MainActor
    @Suite("Snapshot: trang 1 của PDF")
    struct ReportSnapshotTests {
        /// PDF kết quả của bài Thi đề 8 phần (có so với lần trước), phần xem lại mặc định **Câu sai và chưa làm**: đầu
        /// trang (tên đề, thí sinh, mã đề, chế độ, nộp lúc, thời gian, ngưỡng đậu), Đậu/Trượt, điểm, theo phần. Trang 1 hết
        /// sau "Theo phần", còn ~235 pt trống: đề mục Xem lại bài và câu sai đầu tiên không vừa nên sang trang 2 (giữ khối
        /// câu trọn một trang, đề mục không đứng một mình; plan giai đoạn 5, Decisions 2026-10-18).
        @Test func resultsPDFFirstPage() async throws {
            let harness = SessionHarness()
            let package = ExamPackage(exam: SnapshotContent.manySectionsExam())
            let window = try await harness.submittedWindow(package: package, previousPercent: 45)
            let results = try #require(window.results)
            let review = await results.makeAnswerReview()
            let report = ResultsReport(
                results: results, review: review, level: .default, appVersion: "1.0",
                timeZone: TimeZone(identifier: "Asia/Ho_Chi_Minh")!
            )
            let pdf = try await ReportRenderer().render(report.document())
            await SnapshotHost.assertPDFPage(pdf.data)
        }

        /// PDF đề **Có đáp án và giải thích** của đề 8 phần: khối thông tin đề đầu trang 1, đề mục Phần 1 tiếp ngay sau,
        /// các câu với Đáp án đúng và Giải thích (phương án 19: không trang bìa). Câu ngắn để trang 1 có cả khối câu (câu 1
        /// dài hơn phần còn lại của trang 1 thì sang trang 2 cùng đề mục phần: quy tắc giữ khối câu trọn một trang).
        @Test func examPDFFirstPage() async throws {
            let package = ExamPackage(exam: SnapshotContent.manySectionsExam())
            let report = ExamReport(package: package, kind: .withAnswers, appVersion: "1.0")
            let pdf = try await ReportRenderer().render(report.document())
            await SnapshotHost.assertPDFPage(pdf.data)
        }
    }
}
