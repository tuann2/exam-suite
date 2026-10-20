import ExamKit
import Foundation

/// Lựa chọn không bắt đầu từ A (import.md, `.txt` mục Lựa chọn; Nt0 chốt 2026-10-16): khi khối câu không có dòng
/// `A.`/`A)` nào trước dòng đáp án, lựa chọn đầu tiên là dòng nhãn đầu tiên (chữ bất kỳ), các lựa chọn sau phải liên
/// tiếp từ chữ đó; lựa chọn được đánh lại A, B, C… theo vị trí và chữ đáp án (đọc theo chữ gốc) đổi theo vị trí.
/// Dùng cho txt và cho lựa chọn dạng `A.` của docx.
enum OptionRelettering {
    /// Vị trí (0 = A) của chữ lựa chọn đầu tiên. `labels`: chữ của các dòng nhãn lựa chọn trước dòng đáp án, theo thứ
    /// tự. Có `A` → 0 (như cũ); không có nhãn nào → 0.
    static func startOffset(labels: [OptionID]) -> Int {
        guard let first = labels.first, !labels.contains(where: { $0.index == 0 }) else { return 0 }
        return first.index
    }

    /// Đổi chữ đáp án gốc sang chữ mới: chữ gốc ở vị trí `offset + i` thành chữ thứ `i`. Chữ không khớp lựa chọn nào
    /// vẫn là vi phạm (thanh lỗi chỉ ra): giữ chữ gốc nếu nó nằm ngoài các lựa chọn mới, không thì dùng chữ trống đầu
    /// tiên sau lựa chọn cuối, để không vô tình khớp một lựa chọn khác.
    static func remap(_ answer: [OptionID], offset: Int, optionCount: Int)
        -> (letters: [OptionID], unmatched: [OptionID])
    {
        func mapped(_ letter: OptionID) -> OptionID? {
            let index = letter.index - offset
            return (0 ..< optionCount).contains(index) ? OptionID(index: index) : nil
        }
        var used = Set(answer.compactMap(mapped))
        var nextFree = optionCount
        var letters: [OptionID] = []
        var unmatched: [OptionID] = []
        for letter in answer {
            if let id = mapped(letter) {
                letters.append(id)
                continue
            }
            unmatched.append(letter)
            if letter.index >= optionCount, !used.contains(letter) {
                letters.append(letter)
                used.insert(letter)
                continue
            }
            while let candidate = OptionID(index: nextFree), used.contains(candidate) { nextFree += 1 }
            let placeholder = OptionID(index: nextFree) ?? letter
            letters.append(placeholder)
            used.insert(placeholder)
            nextFree += 1
        }
        return (letters, unmatched)
    }

    /// Đổi đáp án của câu đã tách và trả chi tiết cho cảnh báo `optionLabelsShifted`.
    /// - Parameter firstLine: dòng của lựa chọn đầu tiên (txt), để cảnh báo nêu đúng dòng được lấy làm lựa chọn A.
    static func apply(to question: inout ParsedQuestion, offset: Int, firstLine: Int? = nil) -> OptionShift {
        let count = question.options.count
        var shift = OptionShift(
            originalFirst: OptionID(index: offset).map(\.description) ?? "?",
            originalLast: OptionID(index: offset + count - 1).map(\.description) ?? "?",
            newLast: OptionID(index: max(count - 1, 0)).map(\.description) ?? "?",
            firstLine: firstLine,
            answerBefore: nil,
            answerAfter: nil,
            unmatched: []
        )
        if let answer = question.answer {
            let result = remap(answer, offset: offset, optionCount: count)
            question.answer = result.letters
            shift.answerBefore = answer
            shift.answerAfter = result.letters
            shift.unmatched = result.unmatched
        }
        return shift
    }
}
