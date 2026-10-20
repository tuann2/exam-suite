import Foundation

/// Lỗi khi tạo đề cho phiên.
public enum CompositionError: Error, Equatable {
    /// Lựa chọn ra 0 câu (đề rỗng, tập section rỗng hoặc chỉ gồm section rỗng,
    /// danh sách câu rỗng). UI dùng để khoá nút Bắt đầu.
    case noQuestions
    /// `random(count:)` với N ngoài khoảng `1...available` (kể cả đề rỗng: `available == 0`).
    case countOutOfRange(requested: Int, available: Int)
    /// Id section không thuộc đề.
    case unknownSection(UUID)
    /// Id câu không thuộc đề.
    case unknownQuestion(UUID)
}

/// Chọn câu và xáo cho một phiên thi (docs/product/scoring.md, mục "Chọn câu cho một phiên").
///
/// Tính tái lập: dùng MỘT `SeededGenerator(seed: options.seed)` cho cả lần tạo,
/// tiêu thụ số ngẫu nhiên đúng theo thứ tự sau. Không được đổi thứ tự này, nếu
/// không seed đã lưu trong Attempt cũ sẽ ra đề khác:
///
/// 1. Nếu `selection == .random(count: N)`: Fisher–Yates trên TOÀN BỘ câu của đề
///    (thứ tự file, các section nối tiếp), lấy N câu đầu, giữ nguyên thứ tự sau xáo
///    (như bản gốc Open Exam Suite).
/// 2. Nếu `shuffleQuestions`: Fisher–Yates trên danh sách đã chọn.
/// 3. Nếu `shuffleOptions`: lần lượt từng câu theo thứ tự cuối cùng sau bước 2,
///    Fisher–Yates trên `optionOrder` (khởi đầu là thứ tự lựa chọn trong file).
///
/// Bước nào không bật thì không tiêu thụ số nào. Fisher–Yates và cách lấy số
/// nguyên đều: xem `SeededGenerator`.
public enum ExamComposer {
    public static func compose(_ exam: Exam, options: CompositionOptions) throws -> ExamPaper {
        var generator = SeededGenerator(seed: options.seed)

        // Bước 1: chọn câu (chỉ `.random` tiêu thụ số ngẫu nhiên).
        var picked = try select(exam, options.selection, using: &generator)
        guard !picked.isEmpty else { throw CompositionError.noQuestions }

        // Bước 2: xáo câu.
        if options.shuffleQuestions {
            generator.shuffle(&picked)
        }

        // Bước 3: xáo đáp án từng câu, theo thứ tự cuối cùng.
        var items: [PaperItem] = []
        items.reserveCapacity(picked.count)
        for entry in picked {
            var order = entry.question.options.map(\.id)
            if options.shuffleOptions {
                generator.shuffle(&order)
            }
            items.append(PaperItem(questionID: entry.question.id, sectionID: entry.sectionID, optionOrder: order))
        }

        return ExamPaper(examID: exam.id, options: options, items: items)
    }

    /// Một câu kèm id section gốc.
    private struct Entry {
        let question: Question
        let sectionID: UUID
    }

    /// Câu của các section đã cho, theo thứ tự file, kèm section gốc.
    private static func entries(of sections: [ExamSection]) -> [Entry] {
        sections.flatMap { section in
            section.questions.map { Entry(question: $0, sectionID: section.id) }
        }
    }

    private static func select(
        _ exam: Exam,
        _ selection: QuestionSelection,
        using generator: inout SeededGenerator
    ) throws -> [Entry] {
        switch selection {
        case .all:
            return entries(of: exam.sections)

        case let .sections(ids):
            let known = Set(exam.sections.map(\.id))
            // Set không có thứ tự: báo id lạ nhỏ nhất (theo chuỗi) để lỗi ổn định giữa các lần chạy.
            if let unknown = ids.filter({ !known.contains($0) }).min(by: { $0.uuidString < $1.uuidString }) {
                throw CompositionError.unknownSection(unknown)
            }
            // Giữ thứ tự section trong file, không theo thứ tự trong Set.
            return entries(of: exam.sections.filter { ids.contains($0.id) })

        case let .random(count):
            var all = entries(of: exam.sections)
            guard count >= 1, count <= all.count else {
                throw CompositionError.countOutOfRange(requested: count, available: all.count)
            }
            generator.shuffle(&all)
            return Array(all.prefix(count))

        case let .questions(ids):
            // Trùng id câu trong đề là lỗi soạn đề (việc của ExamValidator); ở đây lấy lần xuất hiện đầu.
            var lookup: [UUID: Entry] = [:]
            for entry in entries(of: exam.sections) where lookup[entry.question.id] == nil {
                lookup[entry.question.id] = entry
            }
            var seen = Set<UUID>()
            var result: [Entry] = []
            for id in ids {
                guard let entry = lookup[id] else { throw CompositionError.unknownQuestion(id) }
                if seen.insert(id).inserted {
                    result.append(entry)
                }
            }
            return result
        }
    }
}
