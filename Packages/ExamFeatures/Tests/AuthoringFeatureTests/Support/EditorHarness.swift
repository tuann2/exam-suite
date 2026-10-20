import AuthoringData
@testable import AuthoringFeature
import ExamFile
import ExamKit
import Foundation

/// Id cố định cho test: `00000000-0000-0000-0000-0000000000NN`.
func fixedID(_ n: Int) -> UUID {
    UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", n))!
}

/// Byte "ảnh" giả (đầu PNG + dãy theo `seed`): bộ soạn đề giữ nguyên byte, không giải mã.
func imageBytes(_ seed: UInt8, count: Int = 64) -> Data {
    Data([0x89, 0x50, 0x4e, 0x47] + (0 ..< count).map { UInt8(truncatingIfNeeded: Int(seed) &* 31 &+ $0) })
}

func makeQuestion(_ id: Int, _ text: String, options: [String] = ["Đúng", "Sai"], correct: [Int] = [0],
                  type: QuestionType = .single) -> Question {
    Question(
        id: fixedID(id), type: type, text: text,
        options: options.enumerated().map { Option(id: OptionID(index: $0.offset)!, text: $0.element) },
        correct: correct.map { OptionID(index: $0)! }
    )
}

/// Đề mẫu cho test: "Phần 1" có Q1, Q2, Q3; "Phần 2" có Q4. Không có lỗi.
func sampleDraft() -> ExamDraft {
    ExamDraft(exam: Exam(
        id: fixedID(1), title: "Đề thử", passPercent: 70, timeLimitMinutes: 30,
        sections: [
            ExamSection(id: fixedID(2), title: "Phần 1", questions: [
                makeQuestion(11, "Q1"), makeQuestion(12, "Q2"), makeQuestion(13, "Q3"),
            ]),
            ExamSection(id: fixedID(3), title: "Phần 2", questions: [makeQuestion(14, "Q4")]),
        ]
    ))
}

/// Đề lớn để đo: `count` câu chia đều vào 20 phần, mỗi câu 4 lựa chọn và nội dung khoảng 200 ký tự.
func largeDraft(questions count: Int) -> ExamDraft {
    let sections = 20
    var number = 0
    let exam = Exam(
        id: fixedID(1), title: "Đề lớn", passPercent: 70, timeLimitMinutes: 120,
        sections: (0 ..< sections).map { s in
            ExamSection(id: UUID(), title: "Phần \(s + 1)", questions: (0 ..< count / sections).map { _ in
                number += 1
                return Question(
                    id: UUID(), type: number % 5 == 0 ? .multiple : .single,
                    text: "Câu \(number): " + String(repeating: "Nội dung câu hỏi dài vừa phải để đo. ", count: 5),
                    options: (0 ..< 4).map { Option(id: OptionID(index: $0)!, text: "Lựa chọn \($0 + 1) của câu \(number)") },
                    correct: number % 5 == 0 ? [OptionID(index: 0)!, OptionID(index: 2)!] : [OptionID(index: 1)!],
                    explanation: "Giải thích câu \(number)."
                )
            })
        }
    )
    return ExamDraft(exam: exam)
}

/// Document không cửa sổ + `UndoManager` thật. Mỗi `step` là một sự kiện người dùng: như vòng lặp sự kiện của
/// AppKit (`groupsByEvent`), lần đăng ký đầu mở nhóm Hoàn tác và cuối sự kiện thì đóng nhóm; sự kiện không đăng ký
/// gì thì không có nhóm. (`groupsByEvent` thật cần vòng lặp sự kiện, test không có, nên tắt và tự mở nhóm.)
@MainActor
final class EditorHarness {
    let document: ExamAuthoringDocument
    let editor: AuthoringEditor
    let undo = UndoManager()

    init(_ draft: ExamDraft = sampleDraft()) {
        document = ExamAuthoringDocument(draft: draft)
        editor = document.editor
        undo.groupsByEvent = false
        editor.undoManager = undo
        editor.willRegisterUndo = { manager in
            if manager.groupingLevel == 0 && !manager.isUndoing && !manager.isRedoing { manager.beginUndoGrouping() }
        }
    }

    var exam: Exam { editor.exam }

    func step(_ body: () -> Void) {
        body()
        endEvent()
    }

    /// Cuối một sự kiện: đóng nhóm Hoàn tác mà lần đăng ký đầu đã tự mở (không có vòng lặp sự kiện trong test).
    func endEvent() {
        while undo.groupingLevel > 0 { undo.endUndoGrouping() }
    }

    /// Gõ từng phần của `text` (mỗi lần gõ một sự kiện), như ô chữ gửi chuỗi mới sau mỗi phím.
    func type(_ text: String, into set: (String) -> Void) {
        var typed = ""
        for character in text {
            typed.append(character)
            let value = typed
            step { set(value) }
        }
    }

    /// Số bước Hoàn tác còn lại.
    var undoCount: Int {
        var count = 0
        while undo.canUndo {
            undo.undo()
            count += 1
        }
        for _ in 0 ..< count { undo.redo() }
        return count
    }
}
