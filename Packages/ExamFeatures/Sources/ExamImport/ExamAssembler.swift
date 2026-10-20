import ExamKit
import Foundation

/// Một câu đã tách từ file gốc, trước khi chuẩn hoá thành `Question`. Nội dung đã ở dạng Markdown cơ bản.
struct ParsedQuestion {
    /// Sinh trước để mục báo cáo trỏ được tới câu; câu bị bỏ thì mục báo cáo bỏ liên kết.
    let id = UUID()
    /// Số câu như ghi trong file.
    var number: Int?
    /// Dòng đầu câu (txt).
    var line: Int?
    var text = ""
    var options: [String] = []
    /// `nil`: không có dòng đáp án hoặc không đọc được (đã ghi báo cáo).
    var answer: [OptionID]?
    var explanation: String?
    /// Tên phần (đã chọn theo quy tắc của từng định dạng).
    var sectionTitle = ""
    /// `media/<hash>.<ext>` nếu câu có ảnh.
    var image: String?
    /// Dòng/đoạn trong đề bài trông như lựa chọn nhưng sai thứ tự (ví dụ `B.` khi thiếu `A.`), để giải thích nếu câu
    /// bị bỏ vì không có lựa chọn.
    var misplacedOptionLabel: (letter: OptionID, line: Int?)?

    var location: ImportLocation { ImportLocation(questionNumber: number, line: line) }
}

/// Gom mục báo cáo theo thứ tự xuất hiện. **Mỗi mã** giữ chi tiết `detailedEntryLimit` mục đầu; các mục sau của mã đó chỉ
/// được đếm và thành một mục tóm tắt ("… và N mục tương tự"), để file dựng có chủ đích không sinh hàng triệu mục, và
/// cảnh báo của mã này không chiếm chỗ của mục bỏ câu hay cảnh báo mã khác (review độc lập PR #38; import.md, Giới hạn).
/// Chỉ một mục vượt trần thì giữ chi tiết mục đó (không có "… và 1 mục").
struct ReportBuilder {
    static let detailedEntryLimit = 1_000

    private(set) var entries: [ImportReportEntry] = []
    /// Số mục theo mã, kể cả mục không giữ chi tiết.
    private var totals: [ImportIssueCode: Int] = [:]
    /// Mục vượt trần theo mã, theo thứ tự gặp lần đầu: số mục và mục đầu tiên (giữ để xuất chi tiết khi chỉ có một).
    private var omitted: [(code: ImportIssueCode, count: Int, first: ImportReportEntry)] = []
    private var omittedIndex: [ImportIssueCode: Int] = [:]
    /// Vị trí các mục của từng câu, để `detach` không quét lại cả báo cáo (review độc lập PR #38: quét toàn bộ cho mỗi
    /// câu bị bỏ là bậc hai, 40k câu rỗng mất ~100 s).
    private var indicesByQuestion: [UUID: [Int]] = [:]

    mutating func add(_ code: ImportIssueCode, _ location: ImportLocation, question: UUID? = nil,
                      _ detail: ImportIssueDetail)
    {
        let total = totals[code, default: 0] + 1
        totals[code] = total
        let entry = ImportReportEntry(code: code, location: location, questionID: question, detail: detail)
        guard total <= Self.detailedEntryLimit else {
            if let index = omittedIndex[code] {
                omitted[index].count += 1
            } else {
                omittedIndex[code] = omitted.count
                omitted.append((code, 1, entry))
            }
            return
        }
        if let question { indicesByQuestion[question, default: []].append(entries.count) }
        entries.append(entry)
    }

    /// Tổng số mục của một mã (kể cả mục không giữ chi tiết).
    func count(_ code: ImportIssueCode) -> Int { totals[code] ?? 0 }

    /// Báo cáo hoàn chỉnh: các mục chi tiết, rồi với mỗi mã vượt trần: mục duy nhất vượt trần (chi tiết) hoặc một mục
    /// tóm tắt (`isSummary`).
    func makeReport() -> ImportReport {
        var all = entries
        for (code, count, first) in omitted {
            if count == 1 {
                all.append(first)
                continue
            }
            all.append(ImportReportEntry(
                code: code, location: ImportLocation(), questionID: nil,
                detail: .summary(code: code, count: count, limit: Self.detailedEntryLimit),
                occurrences: count, isSummary: true
            ))
        }
        return ImportReport(entries: all)
    }

    /// Câu bị bỏ: các mục đã ghi cho câu đó không còn trỏ tới câu nào.
    mutating func detach(_ questionID: UUID) {
        if let indices = indicesByQuestion.removeValue(forKey: questionID) {
            for i in indices { entries[i].questionID = nil }
        }
        // Mục đầu tiên vượt trần (tối đa một mỗi mã) có thể được xuất chi tiết.
        for i in omitted.indices where omitted[i].first.questionID == questionID {
            omitted[i].first.questionID = nil
        }
    }
}

/// Dựng các phần và câu của đề từ `ParsedQuestion` (import.md, Luồng): bỏ câu không có lựa chọn, loại câu theo
/// số đáp án đúng, chuỗi NFC và bỏ khoảng trắng hai đầu, phần theo thứ tự xuất hiện.
struct ExamAssembler {
    private(set) var sections: [ExamSection] = []
    /// Tên phần → vị trí trong `sections` (tìm theo từ điển, không quét tuyến tính mỗi câu; review độc lập PR #38).
    private var sectionIndex: [String: Int] = [:]

    mutating func add(_ parsed: ParsedQuestion, report: inout ReportBuilder) {
        guard !parsed.options.isEmpty else {
            report.detach(parsed.id)
            let misplaced = parsed.misplacedOptionLabel.map { MisplacedOption(letter: $0.letter, line: $0.line) }
            report.add(.noOptions, parsed.location, .noOptions(misplaced: misplaced))
            return
        }
        let options = parsed.options.enumerated().map { index, text in
            // Bộ tách câu không tạo quá 26 lựa chọn (A–Z): mục thứ 27 trở đi nối vào lựa chọn Z.
            Option(id: OptionID(index: index)!, text: TextNormalizer.clean(text))
        }
        let correct = parsed.answer ?? []
        let explanation = parsed.explanation.map(TextNormalizer.clean).flatMap { $0.isEmpty ? nil : $0 }
        let question = Question(
            id: parsed.id,
            type: correct.count >= 2 ? .multiple : .single,
            text: TextNormalizer.clean(parsed.text),
            image: parsed.image,
            options: options,
            correct: correct,
            explanation: explanation
        )
        let title = TextNormalizer.clean(parsed.sectionTitle)
        if let index = sectionIndex[title] {
            sections[index].questions.append(question)
        } else {
            sectionIndex[title] = sections.count
            sections.append(ExamSection(title: title, questions: [question]))
        }
    }
}

/// Đọc dòng đáp án `A`, `A,C`, `A C`, `AC`, `A, C` (import.md, `.txt` mục Đáp án). `nil` nếu rỗng hoặc có ký tự
/// khác chữ in hoa A–Z, dấu phẩy, khoảng trắng. Giữ nguyên thứ tự và chữ lặp: vi phạm (lặp, ngoài lựa chọn) để
/// thanh lỗi của đề chỉ ra (import.md, phương án 7).
enum AnswerParser {
    static func parse(_ raw: String) -> [OptionID]? {
        var letters: [OptionID] = []
        for c in raw {
            if c == "," || c.isWhitespace { continue }
            guard let id = OptionID(c) else { return nil }
            letters.append(id)
        }
        return letters.isEmpty ? nil : letters
    }
}
