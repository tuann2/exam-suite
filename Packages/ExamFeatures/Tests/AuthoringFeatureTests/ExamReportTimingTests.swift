@testable import AuthoringFeature
import ExamFile
import Foundation
import LargeExamSupport
import PDFKit
import ReportFeature
import Testing

/// PDF đề chuẩn có đáp án (docs/product/large-exams.md, dòng "PDF đề chuẩn có đáp án (Admin)": ≤ 30 s Release, giới hạn
/// chặn 120 s Debug; main actor chặn ≤ 100 ms chỉ ghi số). Đo đúng việc của Xuất PDF…: dựng khối của đề ngoài main actor
/// như `ExamReportFlow`, rồi dựng trang và ghi thẳng ra file.
///
/// Cùng suite `.serialized` với các test đo khác của Soạn đề.
extension AuthoringTimingTests {
    @Test("PDF đề chuẩn có đáp án (2.000 câu, 200 ảnh)", .timeLimit(.minutes(6)))
    func standardExamPDF() async throws {
        let report = ExamReport(package: StandardExam.standard, kind: .withAnswers, appVersion: "1.0")
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ExamReportTimingTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Đề chuẩn (có đáp án).pdf")

        // 3 lần (thao tác nặng, large-exams.md "Cách đo"); nhịp main actor bao cả phần dựng khối.
        let timer = ContinuousClock()
        var runs: [Duration] = []
        var longestGap: Duration = .zero
        var pages = 0
        var questions = 0
        for _ in 0 ..< 3 {
            try? FileManager.default.removeItem(at: url)
            let probe = MainActorGapProbe()
            await probe.start()
            let began = timer.now
            let document = await Task.detached(priority: .userInitiated) { report.document() }.value
            pages = try await ReportRenderer().render(document, to: url).pageCount
            runs.append(timer.now - began)
            await probe.stop()
            longestGap = max(longestGap, probe.longestGap)
            questions = document.blocks.count { if case .question = $0 { true } else { false } }
        }
        #expect(questions == 2_000)
        // Số trang và cỡ file đi vào tên mục để vào bảng của measure_large.sh (dòng `Timing:` đúng dạng).
        let size = (try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue ?? 0
        let base = TimingBudget.reportExamWithAnswers
        let labeled = TimingBudget(
            id: base.id, label: "\(base.label) (\(pages) trang, PDF \(size / 1_000_000) MB)",
            budget: base.budget, limit: base.limit)
        let sample = Timing.record(TimingSample(budget: labeled, runs: runs))
        Timing.record(TimingSample(budget: .reportExamWithAnswersMainActor, runs: [longestGap]))

        // Cỡ file trong ngân sách (Nt0 chốt 2026-10-18: giữ ảnh 2× không mất, bắt cỡ file tăng).
        #expect(size <= PDFSizeBudget.examWithAnswers, "PDF đề có đáp án \(size) byte > \(PDFSizeBudget.examWithAnswers)")

        // Kiểu Chỉ đề (không đáp án): một lần, để ghi thời gian và cỡ file (chỉ khi measure_large.sh,
        // `Timing.recordsExtraMeasurements`: ~10 s mà swift test thường không cần trả).
        if Timing.recordsExtraMeasurements {
            let questionsOnlyURL = directory.appendingPathComponent("Đề chuẩn (đề).pdf")
            let questionsOnly = ExamReport(package: StandardExam.standard, kind: .questionsOnly, appVersion: "1.0")
            let questionsOnlyStart = timer.now
            let questionsOnlyDocument = await Task.detached(priority: .userInitiated) { questionsOnly.document() }.value
            let questionsOnlyPages = try await ReportRenderer().render(questionsOnlyDocument, to: questionsOnlyURL).pageCount
            let questionsOnlyRun = timer.now - questionsOnlyStart
            let questionsOnlyAttributes = try FileManager.default.attributesOfItem(atPath: questionsOnlyURL.path)
            let questionsOnlySize = (questionsOnlyAttributes[.size] as? NSNumber)?.intValue ?? 0
            let onlyBase = TimingBudget.reportExamQuestionsOnly
            let questionsOnlySample = Timing.record(TimingSample(
                budget: TimingBudget(
                    id: onlyBase.id,
                    label: "\(onlyBase.label) (\(questionsOnlyPages) trang, PDF \(questionsOnlySize / 1_000_000) MB)",
                    budget: onlyBase.budget, limit: onlyBase.limit),
                runs: [questionsOnlyRun]))
            #expect(questionsOnlySample.isWithinLimit, "\(questionsOnlySample.line)")
            #expect(questionsOnlyPages > 0 && questionsOnlyPages <= pages)
            #expect(questionsOnlySize <= PDFSizeBudget.examQuestionsOnly)
        }

        // Đọc lại vài trang (không đọc cả tài liệu: ~1.000 trang mất ~29 s).
        let reader = try #require(PDFDocument(url: url))
        #expect(reader.pageCount == pages)
        #expect(pages > 800)
        let first = reader.page(at: 0)?.string ?? ""
        #expect(first.contains(StandardExam.standard.exam.title), "trang đầu thiếu tên đề")
        #expect(first.contains("Đáp án đúng"))
        let lastFooter = ReportStrings.page(pages, of: pages)
        #expect(reader.page(at: pages - 1)?.string?.contains(lastFooter) == true, "\(lastFooter)")
        #expect(sample.isWithinLimit, "\(sample.line)")
    }
}
