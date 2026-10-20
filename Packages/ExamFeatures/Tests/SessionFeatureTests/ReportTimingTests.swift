import AppKit
import ExamFile
import ExamKit
import Foundation
import LargeExamSupport
import LibraryData
import PDFKit
import ReportFeature
@testable import SessionFeature
import Testing

/// PDF kết quả của đề chuẩn (docs/product/large-exams.md: "PDF kết quả không có phần xem lại" ≤ 1 s, giới hạn chặn Debug
/// ≤ 3 s; "PDF kết quả có Xem lại tất cả 2.000 câu" ≤ 30 s, Debug ≤ 120 s, main actor chặn ≤ 100 ms; ngân sách ở
/// `TimingBudget` của LargeExamSupport). Đề chuẩn có 200 ảnh khác nhau (~300 KB), nên Core Graphics không gộp được ảnh
/// như khi dùng một ảnh lặp lại (review độc lập #43). Làm bài và nộp qua `SessionCoordinator` như app. Mỗi lần đo gồm
/// cả việc dựng `ResultsReport` và `document()` (chạy liền trên main actor trước lần nhường đầu, như Xuất PDF… của bước
/// 5b) rồi dựng trang, ghi thẳng ra file tạm.
///
/// Cùng suite `.serialized` với các test đo khác của SessionFeatureTests (xem `LibraryScaleTimingTests`).
extension SessionTimingTests {
    @Test("PDF kết quả của đề chuẩn: không có phần xem lại; Xem lại tất cả 2.000 câu", .timeLimit(.minutes(5)))
    func standardExamResultsPDF() async throws {
        let workspace = try SessionWorkspace()
        let package = StandardExam.standard
        let examID = package.exam.id
        let file = try workspace.write(package, to: "Đề/Đề chuẩn.exam")
        let store = LibraryStore.inMemory(configuration: workspace.configuration(), defaults: workspace.defaults)
        store.load()
        #expect(await store.importFiles([file]).addedExamIDs == [examID])
        let clock = FakeClock()
        let environment = SessionEnvironment(
            library: LibraryStoreSessionLibrary(store: store),
            preferences: UserDefaultsSessionPreferences(defaults: workspace.defaults),
            makeSeed: { 7 },
            makeClock: { [clock] in clock }
        )
        let coordinator = SessionCoordinator(environment: environment)
        #expect(await coordinator.openPreExam(examID: examID, mode: .exam) == .opened)
        let preExam = try #require(coordinator.preExam)
        preExam.candidateName = "Nguyễn Văn Đức"
        #expect(await coordinator.startPreExam())
        let attempt = try #require(coordinator.window?.attempt)
        // Trả lời 3/4 số câu (lựa chọn đầu) để có đủ Đúng/Sai/Chưa làm và dấu "Bạn chọn".
        for index in 0 ..< attempt.questionCount where index % 4 != 3 {
            attempt.goTo(index: index)
            attempt.selectOption(atPosition: 0)
        }
        attempt.openReview()
        coordinator.window?.requestSubmit()
        coordinator.window?.confirmSubmit()
        let results = try #require(coordinator.window?.results)
        let review = try #require(await results.makeAnswerReview())

        // Không có phần xem lại: dựng model + trang, 3 lần.
        var summaryPages = 0
        let resultsOnly = try await Timing.measure(.reportResults, runs: 3) {
            let summary = ResultsReport(results: results, review: nil, level: .none, appVersion: "1.0")
            summaryPages = try await ReportRenderer().render(summary.document()).pageCount
        }
        #expect(summaryPages == 1)

        // Xem lại tất cả 2.000 câu: 3 lần (thao tác nặng, large-exams.md "Cách đo"), mỗi lần dựng model + trang và ghi
        // thẳng ra file; nhịp main actor bao cả phần dựng model.
        let url = workspace.url("Kết quả.pdf")
        let timer = ContinuousClock()
        var runs: [Duration] = []
        var longestGap: Duration = .zero
        var pages = 0
        var questions = 0
        var rendered: ReportPDFFile?
        for _ in 0 ..< 3 {
            try? FileManager.default.removeItem(at: url)
            let probe = MainActorGapProbe()
            await probe.start()
            let began = timer.now
            let full = ResultsReport(results: results, review: review, level: .all, appVersion: "1.0")
            rendered = try await ReportRenderer().render(full.document(), to: url)
            pages = rendered?.pageCount ?? 0
            runs.append(timer.now - began)
            await probe.stop()
            longestGap = max(longestGap, probe.longestGap)
            questions = full.review?.questions.count ?? 0
        }
        #expect(questions == 2_000)
        // Số trang và cỡ file đi vào tên mục để vào bảng của measure_large.sh (dòng `Timing:` đúng dạng).
        let size = (try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue ?? 0
        let base = TimingBudget.reportResultsReviewAll
        let labeled = TimingBudget(
            id: base.id, label: "\(base.label) (\(pages) trang, PDF \(size / 1_000_000) MB)",
            budget: base.budget, limit: base.limit)
        let reviewAll = Timing.record(TimingSample(budget: labeled, runs: runs))
        Timing.record(TimingSample(budget: .reportResultsReviewAllMainActor, runs: [longestGap]))

        // Đọc lại vài trang (không đọc cả tài liệu: ~1.000 trang mất ~29 s).
        let reader = try #require(PDFDocument(url: url))
        #expect(reader.pageCount == pages)
        #expect(pages > 900)
        #expect(reader.page(at: 0)?.string?.contains("Nguyễn Văn Đức") == true)
        // Số trang theo định dạng số của locale của ngôn ngữ giao diện (accessibility-localization.md, Nt0 giữ quy tắc
        // 2026-10-17): "Trang 1.175/1.175" khi giao diện tiếng Việt. Trong `swift test`, `InterfaceStrings` khoá vi nên
        // ra dạng đó trên mọi máy; trong app, tới bước 7 định dạng số vẫn theo Region của macOS (bước 7 sửa cho mọi màn).
        let lastFooter = ReportStrings.page(pages, of: pages)
        #expect(reader.page(at: pages - 1)?.string?.contains(lastFooter) == true, "\(lastFooter)")

        // Cỡ file trong ngân sách (Nt0 chốt 2026-10-18: giữ ảnh 2× không mất, bắt cỡ file tăng).
        #expect(size <= PDFSizeBudget.resultsReviewAll, "PDF Xem lại tất cả \(size) byte > \(PDFSizeBudget.resultsReviewAll)")

        // In… (bước 9 của plan giai đoạn 5, chỉ ghi số): sau khi dựng, app mở PDF bằng PDFKit và tạo thao tác In trên main
        // actor (`ReportPrinting`, `ReportPanels.print`) trước khi hộp In hiện; đo phần đó. Rồi in ra file (không hộp
        // thoại, khổ A4 như PDF; chỉ khi measure_large.sh, `Timing.recordsExtraMeasurements`): `NSPrintOperation.run()`
        // chạy đồng bộ trên main actor, nên đó là thời gian main actor bận khi in tài liệu 1.000+ trang (trong app AppKit
        // chạy nó trong vòng lặp của bảng tiến độ In, test tay).
        let renderedFile = try #require(rendered)
        let printed = workspace.url("In.pdf")
        let info = NSPrintInfo()
        info.paperSize = NSSize(width: 595, height: 842)
        info.jobDisposition = .save
        info.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = printed
        var operation: NSPrintOperation?
        Timing.measure(.reportPrintPrepare, runs: 3) {
            operation = ReportPrinting.printOperation(for: renderedFile, jobTitle: "Kết quả", printInfo: info)
        }
        let printOperation = try #require(operation)
        if Timing.recordsExtraMeasurements {
            printOperation.showsPrintPanel = false
            printOperation.showsProgressPanel = false
            var printSucceeded = false
            Timing.measure(.reportPrintRun, runs: 1) { printSucceeded = printOperation.run() }
            #expect(printSucceeded)
            #expect(PDFDocument(url: printed)?.pageCount == pages)
        }

        #expect(resultsOnly.isWithinLimit, "\(resultsOnly.line)")
        #expect(reviewAll.isWithinLimit, "\(reviewAll.line)")
    }
}
