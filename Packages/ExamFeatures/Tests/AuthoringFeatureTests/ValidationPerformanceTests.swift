import AuthoringData
@testable import AuthoringFeature
import ExamKit
import Foundation
import os
import Testing

@MainActor
@Suite("Kiểm đề chạy nền, gộp thay đổi; đo với đề 2.000 câu", .serialized)
struct ValidationPerformanceTests {
    /// Đếm số lần chạy `ExamValidator` (gọi ngoài main actor).
    private final class Counter: Sendable {
        private let value = OSAllocatedUnfairLock(initialState: 0)
        func increment() { value.withLock { $0 += 1 } }
        var count: Int { value.withLock { $0 } }
    }

    @Test("Gõ liên tục chỉ kiểm một lần khi ngừng gõ; kết quả là của đề mới nhất")
    func debounceCoalescesEdits() async {
        let counter = Counter()
        let scheduler = ValidationScheduler(debounce: .milliseconds(150)) { exam, media in
            counter.increment()
            return ExamValidator.validate(exam, availableMedia: media)
        }
        let editor = AuthoringEditor(draft: sampleDraft(), storage: nil, validation: scheduler, requiresUndoManager: false)
        await editor.waitForValidation()
        #expect(counter.count == 1)
        #expect(editor.issues.issues.isEmpty)
        #expect(!editor.isValidating)

        let p = QuestionPath(section: 0, question: 0)
        var typed = ""
        for character in "Nội dung mới" {
            typed.append(character)
            editor.setQuestionText(at: p, typed)
        }
        editor.setQuestionText(at: p, "")
        #expect(editor.isValidating)
        await editor.waitForValidation()
        #expect(counter.count == 2)
        #expect(editor.issues.issues.map(\.code) == [.questionTextEmpty])
        #expect(!editor.isValidating)
    }

    @Test("Đề 2.000 câu: kiểm đề (nền) và mỗi lần gõ (main actor) đủ nhanh; in số đo")
    func largeExamStaysResponsive() async throws {
        let clock = ContinuousClock()
        let draft = largeDraft(questions: 2_000)
        #expect(draft.exam.questionCount == 2_000)

        // Kiểm đề + gom theo dòng (chạy nền trong app): trung vị 5 lần.
        var validations: [Duration] = []
        for _ in 0 ..< 5 {
            validations.append(clock.measure {
                let index = IssueIndex(ExamValidator.validate(draft.exam, availableMedia: []))
                #expect(index.errorCount == 0)
            })
        }
        let validation = validations.sorted()[2]

        // Mở cửa sổ (dựng cây đề) và một thao tác cấu trúc (dựng lại cây đề) trên main actor.
        var harness: EditorHarness?
        let open = clock.measure { harness = EditorHarness(draft) }
        let h = try #require(harness)
        let structural = clock.measure {
            h.editor.selection = .question(QuestionPath(section: 10, question: 50))
            h.step { h.editor.addQuestion() }
        }

        // Gõ 200 ký tự vào một câu ở giữa đề: mỗi lần gõ là một sự kiện (áp thay đổi, cập nhật dòng của cây đề,
        // ghi bản sao cho document, hẹn kiểm đề).
        let p = QuestionPath(section: 10, question: 40)
        let keystrokes = 200
        let typing = clock.measure {
            h.type(String(repeating: "a", count: keystrokes)) { h.editor.setQuestionText(at: p, $0) }
        }
        let perKeystroke = typing / keystrokes
        #expect(h.undoCount == 2)

        // Kết quả kiểm đề cuối khớp đề mới nhất.
        await h.editor.waitForValidation()
        #expect(h.editor.issues.issues.map(\.code) == [.questionTextEmpty, .noCorrectAnswer] + Array(repeating: .optionTextEmpty, count: 4))

        // Cây đề khi đang tìm (⌘F): lần tìm đầu chuẩn hoá cả đề; gõ vào ô tìm và gõ vào một câu (mỗi lần gõ cây đề
        // vẽ lại) chỉ lọc trên chữ đã chuẩn hoá và chuẩn hoá lại câu vừa sửa.
        h.editor.searchText = "câu 1999"
        let firstSearch = clock.measure { _ = h.editor.visibleRows }
        #expect(h.editor.visibleRows.count == 2)
        // Đổi chữ tìm: mỗi chữ đo 5 lần (lần nào cũng lọc lại, không dùng kết quả nhớ), lấy lần nhanh nhất để test
        // không phụ thuộc máy đang bận (các suite khác chạy song song); báo chữ chậm nhất.
        var queries: [Duration] = []
        for query in ["câu 199", "câu 19", "cau 1"] {
            var runs: [Duration] = []
            for round in 0 ..< 5 {
                h.editor.searchText = query + String(repeating: " ", count: round)
                runs.append(clock.measure { _ = h.editor.visibleRows })
            }
            queries.append(runs.min() ?? .zero)
        }
        let perQuery = queries.max() ?? .zero
        // Gõ vào câu lúc đang tìm: 5 đợt 40 phím (mỗi đợt một đoạn gõ mới), lấy trung bình của đợt nhanh nhất.
        h.editor.searchText = "câu 1999"
        var batches: [Duration] = []
        for batch in 0 ..< 5 {
            h.editor.endTyping()
            let prefix = String(repeating: "b", count: batch * 40)
            batches.append(clock.measure {
                h.type(String(repeating: "b", count: 40)) { text in
                    h.editor.setQuestionText(at: p, prefix + text)
                    _ = h.editor.visibleRows
                }
            } / 40)
        }
        let perSearchKeystroke = batches.min() ?? .zero
        #expect(h.editor.visibleRows == [.section(index: 19), .question(QuestionPath(section: 19, question: 98))])
        // Không đổi gì thì vẽ lại dùng kết quả đã nhớ.
        let memoized = clock.measure { _ = h.editor.visibleRows }

        func ms(_ duration: Duration) -> String {
            let value = Double(duration.components.seconds) * 1_000 + Double(duration.components.attoseconds) / 1e15
            return String(format: "%.2f ms", value)
        }
        print("""
            [g44a-perf] Ngân sách mỗi lần gõ/lọc: 16 ms (một khung hình); ngưỡng của test: 50 ms.
            """)
        print("""
            [g44a-perf] Đề 2.000 câu: kiểm đề (ExamValidator + IssueIndex, nền) \(ms(validation)); \
            mở cửa sổ (cây đề) \(ms(open)); thêm câu (dựng lại cây đề) \(ms(structural)); \
            mỗi lần gõ trên main actor \(ms(perKeystroke)) (trung bình \(keystrokes) lần, không gồm vẽ lại cây đề); \
            đang tìm: lần tìm đầu (chuẩn hoá cả đề) \(ms(firstSearch)), đổi chữ tìm \(ms(perQuery)), \
            mỗi lần gõ vào câu kèm lọc lại cây đề \(ms(perSearchKeystroke)) (đợt 40 phím nhanh nhất), \
            vẽ lại không đổi \(ms(memoized))
            """)
        // Ngưỡng rộng cho build Debug trên máy chậm; số đo thật in ở trên.
        // Ngân sách là một khung hình (16 ms, in ở trên). Ngưỡng của test rộng hơn (50 ms, bản Debug, lần đo nhanh
        // nhất) vì `verify_local.sh` chạy các suite song song và cùng lúc với Docker Linux: máy chậm khoảng 5 lần.
        #expect(perKeystroke < .milliseconds(50))
        #expect(perSearchKeystroke < .milliseconds(50))
        #expect(perQuery < .milliseconds(50))
        #expect(validation < .seconds(2))
    }
}
