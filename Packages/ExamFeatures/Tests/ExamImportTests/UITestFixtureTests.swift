@testable import ExamImport
import ExamKit
import Foundation
import Testing

/// File `.txt` tự soạn mà UI test Import đề… của bản Admin dùng (Apps/AdminUITests/Fixtures/nhap-thu.txt). UI test
/// chỉ chạy trên Mac của người điều phối (`verify_local.sh --uitest`); test này giữ đúng những gì UI test dựa vào (số
/// câu, câu bị bỏ, cảnh báo gắn câu 2, tiêu đề gợi ý) để sửa bộ đọc txt mà làm lệch file thì đỏ ngay ở `check.sh`.
@Suite("File import tự soạn của UI test bản Admin")
struct UITestFixtureTests {
    static let fixtureURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // ExamImportTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // ExamFeatures
        .deletingLastPathComponent() // Packages
        .deletingLastPathComponent() // repo root
        .appendingPathComponent("Apps/AdminUITests/Fixtures/nhap-thu.txt")

    @Test("nhap-thu.txt: một phần, hai câu, câu 3 bị bỏ, hai cảnh báo (đầu file, câu 2), tiêu đề theo tên file")
    func adminImportFixture() async throws {
        let data = try Data(contentsOf: Self.fixtureURL)
        let result = try await ExamImporter.importData(data, fileName: "nhap-thu.txt", limits: .default)
        #expect(result.sections.count == 1)
        #expect(result.sections.first?.title == "nhap-thu")
        #expect(result.questionCount == 2)
        #expect(result.report.droppedCount == 1)
        #expect(result.report.warningCount == 2)
        #expect(result.suggestions.title == "nhap-thu")
        #expect(result.suggestions.code == nil)
        #expect(result.suggestions.passPercent == nil)
        #expect(result.suggestions.timeLimitMinutes == nil)

        let questions = result.sections.flatMap(\.questions)
        let second = try #require(questions.last)
        #expect(second.text.contains("email"))
        #expect(second.type == .multiple)
        // Dòng báo cáo UI test bấm: cảnh báo có vị trí "câu 2" và gắn với câu 2 trong đề.
        let entries = result.report.entries.filter { $0.location.logDescription.hasPrefix("câu 2") }
        #expect(entries.count == 1)
        #expect(entries.first?.questionID == second.id)
        #expect(entries.first?.severity == .warning)
        // Câu bị bỏ không gắn câu nào (dòng báo cáo không bấm được).
        let dropped = result.report.entries.filter { $0.severity == .dropped }
        #expect(dropped.count == 1)
        #expect(dropped.first?.questionID == nil)
        #expect(dropped.first?.location.logDescription.hasPrefix("câu 3") == true)
    }
}
