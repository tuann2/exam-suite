import ExamFile
import ExamKit
import Foundation
import LargeExamSupport
@testable import LibraryData
import Testing

/// Thêm một đề chuẩn (2.000 câu, 200 ảnh ~60 MB) vào Thư viện: đọc nghiêm ở nền tới khi thẻ Sẵn sàng, main actor
/// không bị chặn (docs/product/large-exams.md). Kho SwiftData trong bộ nhớ, file trong thư mục tạm.
@MainActor
@Suite("Timing: Thư viện với đề chuẩn", .serialized)
struct LibraryTimingTests {
    @Test("Thêm một đề chuẩn tới khi Sẵn sàng; main actor chặn dài nhất", .timeLimit(.minutes(3)))
    func importStandardExam() async throws {
        let workspace = try TestWorkspace()
        let package = StandardExam.standard
        let file = try workspace.write(package, to: "Đề chuẩn.exam")

        // Mỗi lần một kho mới (SwiftData trong bộ nhớ), như thêm đề lần đầu. Tạo và nạp kho nằm ngoài vùng đo; chỉ đo
        // từ lúc thêm file tới khi thẻ Sẵn sàng.
        var durations: [Duration] = []
        var gaps: [Duration] = []
        let clock = ContinuousClock()
        for _ in 0 ..< 3 {
            let store = workspace.makeStore()
            store.load()
            let probe = MainActorGapProbe()
            await probe.start()
            let began = clock.now
            let report = await store.importFiles([file])
            durations.append(clock.now - began)
            await probe.stop()
            gaps.append(probe.longestGap)
            #expect(report.addedExamIDs == [package.exam.id])
            #expect(store.entry(package.exam.id)?.status == .ready)
            #expect(store.entry(package.exam.id)?.summary.questionCount == 2_000)
        }
        let importing = Timing.record(TimingSample(budget: .libraryImport, runs: durations))
        let blocking = Timing.record(TimingSample(budget: .libraryImportMainActor, runs: gaps))
        #expect(importing.isWithinLimit, "\(importing.line)")
        #expect(blocking.isWithinLimit, "\(blocking.line)")
    }
}
