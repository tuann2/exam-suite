@testable import ExamImport
import Foundation
import Testing

/// Thời gian tuyến tính với file dựng có chủ đích (review độc lập PR #38, phát hiện 1 và 2): nhiều câu bị bỏ, nhiều phần
/// khác tên. Lấy thời gian nhỏ nhất của vài lần chạy và đặt trần rộng (bản Debug, test chạy song song) để test không chập
/// chờn; bản bậc hai cũ mất 9–25 s ở cùng kích thước (đo trong review).
@Suite("Import: hiệu năng với file lớn dựng có chủ đích")
struct PerformanceTests {
    static func fastest(_ runs: Int = 3, _ body: () async throws -> Void) async rethrows -> Duration {
        let clock = ContinuousClock()
        var best = Duration.seconds(1_000)
        for _ in 0 ..< runs {
            let start = clock.now
            try await body()
            best = min(best, clock.now - start)
        }
        return best
    }

    @Test(".vce: 20.000 câu không có lựa chọn (bị bỏ) đọc dưới 2 s")
    func manyDroppedVce() async throws {
        var writer = VceTestWriter()
        writer.questions = Array(repeating: .init("", options: [], answer: ""), count: 20_000)
        writer.questions.append(.init("Câu dùng được", options: ["1", "2"], answer: "A"))
        let data = writer.data()
        var result: ImportResult?
        let elapsed = try await Self.fastest {
            result = try await ExamImporter.importData(data, fileName: "a.vce")
        }
        #expect(elapsed < .seconds(2), "\(elapsed)")
        #expect(result?.questionCount == 1)
        #expect(result?.report.droppedCount == 20_000)
    }

    @Test(".txt: 20.000 câu không có lựa chọn (bị bỏ) đọc dưới 4 s (ExamAssembler dùng chung từ #32; bản cũ ~25 s)")
    func manyDroppedText() async throws {
        let text = (1 ... 20_000).map { "Q\($0):\nKhông có lựa chọn\n" }.joined() + "Q0:\nCâu\nA. Có\nB. Không\nCorrect Answer: A\n"
        let data = Data(text.utf8)
        var result: ImportResult?
        let elapsed = try await Self.fastest {
            result = try await ExamImporter.importData(data, fileName: "a.txt")
        }
        #expect(elapsed < .seconds(4), "\(elapsed)")
        #expect(result?.questionCount == 1)
        #expect(result?.report.droppedCount == 20_000)
    }

    @Test(".vce: 16.000 câu, mỗi câu một phần khác tên, đọc dưới 4 s (bản cũ ~9 s)")
    func manySections() async throws {
        var writer = VceTestWriter()
        writer.sections = (1 ... 16_000).map { (Int32($0), "P\($0)") }
        writer.questions = (1 ... 16_000).map { .init("C", options: ["1", "2"], answer: "A", sectionID: Int32($0)) }
        let data = writer.data()
        var result: ImportResult?
        let elapsed = try await Self.fastest {
            result = try await ExamImporter.importData(data, fileName: "a.vce")
        }
        #expect(elapsed < .seconds(4), "\(elapsed)")
        #expect(result?.sections.count == 16_000)
        #expect(result?.sections.last?.title == "P16000")
    }
}
