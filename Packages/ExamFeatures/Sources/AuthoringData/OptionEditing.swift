import ExamKit
import Foundation

/// Lựa chọn theo vị trí: nội dung và có phải đáp án đúng không. Thao tác trên lựa chọn sửa danh
/// sách này rồi dựng lại `options`/`correct`, nên chữ cái luôn theo vị trí và đáp án đúng đi
/// theo nội dung (docs/product/authoring.md, mục Phần và câu; exam-format.md ràng buộc 2).
struct OptionEntry: Equatable {
    var text: String
    var isCorrect: Bool
    /// Mã cũ, chỉ dùng cho lựa chọn thứ 27 trở đi (đề đọc dễ có hơn 26 lựa chọn): không còn chữ
    /// cái theo vị trí cho chúng nên giữ mã cũ (validator vẫn báo lỗi `tooManyOptions`).
    var originalID: OptionID
}

extension Question {
    /// Lựa chọn theo vị trí. Một lựa chọn là đúng khi mã của nó có trong `correct`.
    var optionEntries: [OptionEntry] {
        let correctSet = correctSet
        return options.map { OptionEntry(text: $0.text, isCorrect: correctSet.contains($0.id), originalID: $0.id) }
    }

    /// Dựng lại `options` (mã A, B, C… theo vị trí) và `correct` (mã của các lựa chọn đúng, theo
    /// thứ tự vị trí, không lặp) từ `entries`.
    ///
    /// Hệ quả với đề đọc dễ có lỗi: mã đáp án đúng không trỏ tới lựa chọn nào (`correctAnswerNotInOptions`)
    /// bị bỏ, vì sau khi đổi chữ cái nó có thể trỏ nhầm sang lựa chọn khác; đáp án lặp gộp làm một.
    mutating func setOptionEntries(_ entries: [OptionEntry]) {
        var newOptions: [Option] = []
        var newCorrect: [OptionID] = []
        newOptions.reserveCapacity(entries.count)
        for (index, entry) in entries.enumerated() {
            guard let id = OptionID(index: index) else {
                newOptions.append(Option(id: entry.originalID, text: entry.text))
                continue
            }
            newOptions.append(Option(id: id, text: entry.text))
            if entry.isCorrect { newCorrect.append(id) }
        }
        options = newOptions
        correct = newCorrect
    }
}

extension Array {
    /// Như `move(fromOffsets:toOffset:)` của SwiftUI (kéo thả trong `List`): các phần tử ở
    /// `source` (giữ thứ tự tương đối) được đặt trước phần tử đang ở vị trí `destination` của
    /// mảng gốc; `destination == count` là cuối mảng. Trả về hoán vị `order` (mới[i] = cũ[order[i]]).
    static func moveOrder(count: Int, fromOffsets source: IndexSet, toOffset destination: Int) -> [Int]? {
        guard (0 ... count).contains(destination), source.allSatisfy({ (0 ..< count).contains($0) }) else {
            return nil
        }
        let moved = source.sorted()
        let before = (0 ..< destination).filter { !source.contains($0) }
        let after = (destination ..< count).filter { !source.contains($0) }
        return before + moved + after
    }
}
