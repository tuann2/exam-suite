import ExamKit
import Foundation

/// Chuyển file `.txt` thành đề theo docs/product/import.md, mục `.txt`:
///
/// ```text
/// Q1:                     (hoặc QUESTION 1; không phân biệt hoa thường; dòng chỉ gồm đầu câu)
/// <đề bài, nhiều dòng>
/// A. <lựa chọn, nhiều dòng>   (hoặc A) …; đúng thứ tự A, B, C…; không có A thì từ nhãn đầu tiên, đánh lại)
/// Correct Answer: A,C     (hoặc Answer:; A,C / A C / AC)
/// Explanation: <tuỳ chọn, tới câu kế tiếp>
/// ```
///
/// Một phần duy nhất, tên là tên file bỏ đuôi (phương án 8). Không có ảnh.
enum TextImporter {
    static func convert(
        _ data: Data,
        fileStem: String,
        limits: ImportLimits,
        sharedSectionTitle: String = ImportDefaults.sharedSectionTitle,
        progress: ProgressReporter
    ) throws -> ImportResult {
        guard data.count <= limits.textBytes else {
            throw ImportError.tooLarge(what: .textFile, limit: limits.textBytes)
        }
        var bytes = data
        if bytes.starts(with: [0xEF, 0xBB, 0xBF]) { bytes.removeFirst(3) }
        // Mã hoá khác UTF-8 (UTF-16 có BOM, Windows-1258…) không giải mã được. UTF-16 không BOM với chữ ASCII vẫn là
        // UTF-8 hợp lệ nhưng đầy byte 0, nên byte 0 cũng bị coi là sai mã hoá.
        guard !bytes.contains(0), let text = String(data: bytes, encoding: .utf8) else {
            throw ImportError.notUTF8
        }

        let sectionTitle = TextNormalizer.clean(fileStem).isEmpty ? sharedSectionTitle : fileStem
        var parser = TextParser(sectionTitle: sectionTitle)
        let lines = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        let total = max(lines.count, 1)
        for (index, raw) in lines.enumerated() {
            if index % 500 == 0 {
                try Task.checkCancellation()
                progress.report(.converting, fraction: Double(index) / Double(total))
            }
            let repaired = MojibakeRepair.repair(String(raw))
            parser.consume(TextNormalizer.trimWhitespace(repaired.text), lineNumber: index + 1,
                           mojibake: repaired.findings)
        }
        parser.finish()
        try Task.checkCancellation()
        guard !parser.assembler.sections.isEmpty else {
            throw ImportError.noQuestions(dropped: parser.report.count(.noOptions))
        }

        return ImportResult(
            examID: UUID(),
            sections: parser.assembler.sections,
            media: [:],
            report: parser.report.makeReport(),
            suggestions: ImportSuggestions(title: TextNormalizer.clean(fileStem)),
            sourceFormat: .txt
        )
    }
}

/// Máy trạng thái tách câu từ các dòng của file txt (đã bỏ khoảng trắng hai đầu).
struct TextParser {
    enum State {
        /// Trước câu đầu tiên.
        case preamble
        /// Sau đầu câu, chưa có lựa chọn.
        case questionText
        /// Đang ở lựa chọn (dòng nối thuộc lựa chọn cuối).
        case options
        /// Sau dòng đáp án, chưa có `Explanation:`.
        case answer
        /// Sau `Explanation:`.
        case explanation
    }

    private let sectionTitle: String
    private(set) var assembler = ExamAssembler()
    private(set) var report = ReportBuilder()

    private var state = State.preamble
    private var preambleLine: Int?
    private var question = ParsedQuestion()
    private var textLines: [String] = []
    private var optionLines: [[String]] = []
    private var explanationLines: [String] = []
    private var answerLine: Int?
    private var answerRaw = ""
    private var unrecognizedReported = false
    private var mojibakeFindings = MojibakeRepair.Findings()
    private var firstFixLine: Int?
    private var firstSuspectLine: Int?
    /// Dòng của câu đang đọc, xử lý khi hết câu.
    private var pending: [(line: String, number: Int, mojibake: MojibakeRepair.Findings)] = []
    /// Vị trí chữ lựa chọn đầu tiên (0 = A; khác 0 khi câu không có dòng `A.`).
    private var optionStartOffset = 0
    private var firstOptionLine: Int?

    init(sectionTitle: String) {
        self.sectionTitle = sectionTitle
    }

    /// - Parameter fixes: chỗ đã sửa mojibake trên dòng này (`MojibakeRepair`).
    mutating func consume(_ line: String, lineNumber: Int, mojibake: MojibakeRepair.Findings = .init()) {
        if let number = Patterns.questionHead(line) {
            if state == .preamble {
                if let preambleLine {
                    report.add(.textBeforeFirstQuestion, ImportLocation(line: preambleLine),
                               .textBeforeFirstQuestion(fromLine: preambleLine, toLine: lineNumber - 1))
                }
            } else {
                finishQuestion()
            }
            startQuestion(number: number, line: lineNumber)
            return
        }

        switch state {
        case .preamble:
            // Văn bản trước câu đầu bị bỏ qua nên chỗ sửa mojibake ở đó không cần báo.
            if !line.isEmpty, preambleLine == nil { preambleLine = lineNumber }
            return
        case .questionText, .options, .answer, .explanation:
            // Giữ dòng tới hết câu: chữ lựa chọn đầu tiên phụ thuộc cả khối câu (có dòng `A.` hay không).
            pending.append((line, lineNumber, mojibake))
        }
    }

    /// Đọc một dòng của câu (sau khi đã biết chữ lựa chọn đầu tiên).
    private mutating func process(_ line: String, lineNumber: Int, mojibake: MojibakeRepair.Findings) {
        if !mojibake.fixed.isEmpty, firstFixLine == nil { firstFixLine = lineNumber }
        if !mojibake.suspected.isEmpty, firstSuspectLine == nil { firstSuspectLine = lineNumber }
        mojibakeFindings += mojibake

        // Dòng đáp án: ở mọi chỗ trong câu, trừ khi đã có đáp án và đang ở giải thích (giải thích có thể có dòng
        // "Answer: …" là nội dung).
        if let value = Patterns.answerValue(line), !(state == .explanation && answerLine != nil) {
            recordAnswer(value, lineNumber: lineNumber)
            if state != .explanation { state = .answer }
            return
        }

        if state != .explanation, let rest = Patterns.explanationValue(line) {
            state = .explanation
            explanationLines.append(rest)
            return
        }

        switch state {
        case .preamble:
            break
        case .questionText, .options:
            if let label = Patterns.optionLabel(line) {
                let expected = OptionID(index: optionStartOffset + optionLines.count)
                if label.letter == expected {
                    if optionLines.isEmpty { firstOptionLine = lineNumber }
                    optionLines.append([label.rest])
                    state = .options
                    return
                }
                if state == .questionText, question.misplacedOptionLabel == nil {
                    question.misplacedOptionLabel = (label.letter, lineNumber)
                }
                if state == .options {
                    let previous = OptionID(index: optionStartOffset + optionLines.count - 1)!
                    report.add(.optionLabelOutOfOrder, ImportLocation(questionNumber: question.number, line: lineNumber),
                               question: question.id,
                               .optionLabelOutOfOrder(unit: .line, label: label.letter, expected: expected,
                                                      appendedTo: previous))
                }
            }
            if state == .options {
                optionLines[optionLines.count - 1].append(line)
            } else {
                textLines.append(line)
            }
        case .answer:
            if !line.isEmpty, !unrecognizedReported {
                unrecognizedReported = true
                report.add(.unrecognizedText, ImportLocation(questionNumber: question.number, line: lineNumber),
                           question: question.id, .textAfterAnswerLine)
            }
        case .explanation:
            explanationLines.append(line)
        }
    }

    mutating func finish() {
        if state == .preamble {
            if let preambleLine {
                report.add(.textBeforeFirstQuestion, ImportLocation(line: preambleLine),
                           .textWithoutQuestions(fromLine: preambleLine))
            }
            return
        }
        finishQuestion()
    }

    private mutating func startQuestion(number: Int, line: Int) {
        question = ParsedQuestion()
        question.number = number
        question.line = line
        question.sectionTitle = sectionTitle
        textLines = []
        optionLines = []
        explanationLines = []
        answerLine = nil
        answerRaw = ""
        unrecognizedReported = false
        mojibakeFindings = .init()
        firstFixLine = nil
        firstSuspectLine = nil
        pending = []
        optionStartOffset = 0
        firstOptionLine = nil
        state = .questionText
    }

    /// Chữ của các dòng nhãn lựa chọn trước dòng đáp án/giải thích đầu tiên của câu.
    private static func optionLabels(in lines: [(line: String, number: Int, mojibake: MojibakeRepair.Findings)])
        -> [OptionID]
    {
        var labels: [OptionID] = []
        for entry in lines {
            if Patterns.answerValue(entry.line) != nil || Patterns.explanationValue(entry.line) != nil { break }
            if let label = Patterns.optionLabel(entry.line) { labels.append(label.letter) }
        }
        return labels
    }

    private mutating func recordAnswer(_ value: String, lineNumber: Int) {
        let location = ImportLocation(questionNumber: question.number, line: lineNumber)
        if let first = answerLine {
            if Patterns.compact(value) != Patterns.compact(answerRaw) {
                report.add(.conflictingAnswer, location, question: question.id,
                           .conflictingAnswerLine(value: value, keptLine: first))
            }
            return
        }
        answerLine = lineNumber
        answerRaw = value
        if let letters = AnswerParser.parse(value) {
            question.answer = letters
        } else {
            report.add(.answerUnreadable, location, question: question.id, .unreadableAnswer(value))
        }
    }

    private mutating func finishQuestion() {
        let lines = pending
        pending = []
        optionStartOffset = OptionRelettering.startOffset(labels: Self.optionLabels(in: lines))
        for entry in lines { process(entry.line, lineNumber: entry.number, mojibake: entry.mojibake) }

        question.text = TextNormalizer.markdown(fromPlain: TextNormalizer.joinLines(textLines))
        question.options = optionLines.map { TextNormalizer.markdown(fromPlain: TextNormalizer.joinLines($0)) }
        if optionStartOffset > 0, !question.options.isEmpty {
            let shift = OptionRelettering.apply(to: &question, offset: optionStartOffset, firstLine: firstOptionLine)
            report.add(.optionLabelsShifted, ImportLocation(questionNumber: question.number, line: firstOptionLine),
                       question: question.id, .optionLabelsShifted(shift))
        }
        let explanation = TextNormalizer.joinLines(explanationLines)
        question.explanation = explanation.isEmpty ? nil : TextNormalizer.markdown(fromPlain: explanation)
        if !mojibakeFindings.fixed.isEmpty {
            report.add(.mojibakeFixed, ImportLocation(questionNumber: question.number, line: firstFixLine),
                       question: question.id, .mojibakeFixed(MojibakeRepair.summary(mojibakeFindings.fixed)))
        }
        if !mojibakeFindings.suspected.isEmpty {
            report.add(.mojibakeSuspected, ImportLocation(questionNumber: question.number, line: firstSuspectLine),
                       question: question.id, .mojibakeSuspected(MojibakeRepair.summary(mojibakeFindings.suspected)))
        }
        if answerLine == nil, !question.options.isEmpty {
            report.add(.missingAnswer, question.location, question: question.id, .missingAnswerLine)
        }
        assembler.add(question, report: &report)
    }
}

/// Mẫu dòng/đoạn dùng chung cho txt và docx.
enum Patterns {
    /// `Q<số>:` hoặc `QUESTION <số>` chiếm cả dòng (không phân biệt hoa thường) → số câu.
    static func questionHead(_ line: String) -> Int? {
        guard let match = line.wholeMatch(of: questionHeadRegex) else { return nil }
        return Int(match.output.1 ?? match.output.2 ?? "")
    }

    nonisolated(unsafe) private static let questionHeadRegex =
        /(?i:Q(\d{1,9}):|QUESTION[ \t\u{00A0}]+(\d{1,9}))/

    /// Dòng lựa chọn: chữ in hoa A–Z liền sau là `.` hoặc `)`, rồi khoảng trắng (hoặc hết dòng).
    static func optionLabel(_ line: String) -> (letter: OptionID, rest: String, prefixLength: Int)? {
        guard let match = line.prefixMatch(of: optionLabelRegex),
              let letter = OptionID(String(match.output.1))
        else { return nil }
        let prefixLength = line.distance(from: line.startIndex, to: match.range.upperBound)
        return (letter, TextNormalizer.trimWhitespace(String(line[match.range.upperBound...])), prefixLength)
    }

    nonisolated(unsafe) private static let optionLabelRegex = /([A-Z])[.)](?:\s+|$)/

    /// `Correct Answer:` hoặc `Answer:` (không phân biệt hoa thường) ở đầu dòng → phần còn lại.
    static func answerValue(_ line: String) -> String? {
        guard let match = line.prefixMatch(of: answerRegex) else { return nil }
        return TextNormalizer.trimWhitespace(String(line[match.range.upperBound...]))
    }

    nonisolated(unsafe) private static let answerRegex = /(?i:(?:Correct[ \t]+)?Answer[ \t]*:)/

    /// `Explanation:` ở đầu dòng (không phân biệt hoa thường) → phần còn lại.
    static func explanationValue(_ line: String) -> String? {
        guard let match = line.prefixMatch(of: explanationRegex) else { return nil }
        return TextNormalizer.trimWhitespace(String(line[match.range.upperBound...]))
    }

    nonisolated(unsafe) private static let explanationRegex = /(?i:Explanation[ \t]*:)/

    /// Bỏ dấu phẩy và khoảng trắng để so hai dòng đáp án.
    static func compact(_ s: String) -> String {
        String(s.filter { $0 != "," && !$0.isWhitespace })
    }
}

public enum ImportDefaults {
    /// Tên phần khi file không cho tên nào (import.md, `.docx` mục Phần; `.vce` phương án 17), tiếng Việt (ngôn ngữ
    /// nguồn). Là nội dung đề: giao diện truyền tên theo ngôn ngữ giao diện lúc import (`sharedSectionTitle:` của
    /// `ExamImporter`; Nt0 chốt 2026-10-17, plan giai đoạn 5 Decisions), sau đó không dịch lại. Mặc định này cho test và
    /// nơi gọi không có giao diện.
    public static let sharedSectionTitle = "Phần chung"
}
