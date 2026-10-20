import AuthoringData
@testable import AuthoringFeature
import ExamFile
import ExamKit
import Foundation
import LargeExamSupport
import Testing

/// Soạn đề với đề chuẩn (2.000 câu, 200 ảnh; docs/product/large-exams.md): mở cửa sổ, kiểm đề, gõ (cả khi đang tìm),
/// lần gõ đầu vào ô tìm (chỉ mục dựng nền khi mở cửa sổ), lưu. Document không cửa sổ + `UndoManager` thật (`EditorHarness`). Bổ sung
/// cho `ValidationPerformanceTests` (đề 2.000 câu không ảnh, kiểm gộp thay đổi) bằng đề chuẩn và bảng ngân sách chung.
@MainActor
@Suite("Timing: Soạn đề với đề chuẩn", .serialized)
struct AuthoringTimingTests {
    @Test("Mở, kiểm đề, gõ, tìm, lưu đề chuẩn", .timeLimit(.minutes(3)))
    func standardExamAuthoring() async throws {
        let package = StandardExam.standard
        let draft = ExamDraft(package: package)
        let timer = ContinuousClock()

        // Mở cửa sổ: document + bộ soạn đề + cây đề (dòng của cây đề là thứ cửa sổ vẽ đầu tiên).
        var harnesses: [EditorHarness] = []
        let open = Timing.measure(.authoringOpen) {
            let harness = EditorHarness(draft)
            _ = harness.editor.visibleRows
            harnesses.append(harness)
        }

        // Lần gõ đầu vào ô tìm của mỗi cửa sổ vừa mở. Chỉ mục tìm của cả đề dựng nền khi mở cửa sổ (bước 9 của plan giai
        // đoạn 5), xong trước khi người dùng kịp bấm ⌘F và gõ (~40 ms ngoài main actor): chờ nó ngoài vùng đo, rồi đo
        // lần gõ đầu (chỉ lọc).
        var firstSearches: [Duration] = []
        for harness in harnesses {
            await harness.editor.waitForSearchIndex()
            #expect(harness.editor.hasSearchIndex)
            harness.editor.searchText = "c"
            firstSearches.append(timer.measure { _ = harness.editor.visibleRows })
        }
        let firstSearch = Timing.record(TimingSample(budget: .authoringFirstSearch, runs: firstSearches))
        let h = harnesses[0]

        // Kiểm đề (chạy nền trong app) + gom theo dòng, có ảnh.
        let media = Set(package.media.keys)
        let validate = Timing.measure(.authoringValidate) {
            let index = IssueIndex(ExamValidator.validate(h.editor.exam, availableMedia: media))
            #expect(index.errorCount == 0)
        }

        // Gõ vào câu ở giữa đề, không tìm: mỗi phím là một sự kiện (áp thay đổi, cập nhật cây đề, ghi bản sao cho
        // document, hẹn kiểm đề) rồi cây đề vẽ lại. 5 đợt 40 phím, mỗi đợt một đoạn gõ mới.
        h.editor.searchText = ""
        let p = QuestionPath(section: 10, question: 40)
        let original = h.editor.exam.sections[10].questions[40].text
        let typing = Self.typingSample(.authoringTyping, harness: h, path: p, base: original, letter: "a")

        // Gõ vào ô tìm khi chỉ mục đã có: mỗi chữ tìm đo 5 lần (lần nào cũng lọc lại), lấy lần nhanh nhất của mỗi chữ
        // (ít phụ thuộc máy đang bận); test so chữ **chậm nhất** trong các chữ đó với giới hạn chặn (`gate: .slowest`).
        var queries: [Duration] = []
        for query in ["câu 199", "câu 19", "cau 1", "mật khẩu", "backup"] {
            var runs: [Duration] = []
            for round in 0 ..< 5 {
                h.editor.searchText = query + String(repeating: " ", count: round)
                runs.append(timer.measure { _ = h.editor.visibleRows })
            }
            queries.append(runs.min() ?? .zero)
        }
        let searchQuery = Timing.record(TimingSample(budget: .authoringSearchQuery, runs: queries, gate: .slowest))

        // Gõ vào câu khi ô tìm có chữ: mỗi phím chuẩn hoá lại câu vừa sửa và lọc lại cây đề.
        h.editor.searchText = "câu 1"
        let searchTyping = Self.typingSample(
            .authoringSearchTyping, harness: h, path: p, base: original, letter: "b")
        #expect(h.editor.visibleRows.contains(.question(p)))

        // Lưu: chụp đề của document + ghi gói (ExamPackageWriter, có ảnh) + ghi file.
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AuthoringTimingTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("Đề chuẩn.exam")
        let save = try Timing.measure(.authoringSave, runs: 3) {
            let snapshot = try h.document.snapshot(contentType: .examPackage)
            try h.document.write(snapshot).write(to: file, options: .atomic)
        }
        let saved = try ExamPackageReader.read(contentsOf: file, mode: .strict)
        #expect(saved.media == package.media)
        #expect(saved.exam.questionCount == 2_000)

        #expect(open.isWithinLimit, "\(open.line)")
        #expect(firstSearch.isWithinLimit, "\(firstSearch.line)")
        #expect(validate.isWithinLimit, "\(validate.line)")
        #expect(typing.isWithinLimit, "\(typing.line)")
        #expect(searchQuery.isWithinLimit, "\(searchQuery.line)")
        #expect(searchTyping.isWithinLimit, "\(searchTyping.line)")
        #expect(save.isWithinLimit, "\(save.line)")
    }

    /// 5 đợt 40 phím vào câu `path` (mỗi phím một sự kiện, cây đề vẽ lại sau mỗi phím); mỗi lần đo là trung bình
    /// một phím của một đợt, kèm phím chậm nhất.
    private static func typingSample(
        _ budget: TimingBudget,
        harness h: EditorHarness,
        path: QuestionPath,
        base: String,
        letter: String
    ) -> TimingSample {
        let keystrokes = 40
        return Timing.measureEvents(budget, events: keystrokes, before: { _ in h.editor.endTyping() }) { batch, event in
            let text = base + String(repeating: letter, count: batch * keystrokes + event + 1)
            h.step {
                h.editor.setQuestionText(at: path, text)
                _ = h.editor.visibleRows
            }
        }
    }
}
