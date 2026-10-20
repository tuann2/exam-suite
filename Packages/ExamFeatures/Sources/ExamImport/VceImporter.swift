import ExamKit
import Foundation

/// Chuyển file `.vce` (Avanset VCE, biến thể magic `85 A8 02 01`) thành đề theo docs/product/import.md mục `.vce`,
/// cùng mô hình như docx. ADR 0009: viết mới, chỉ Foundation, không chép hay đọc code của công cụ giải mã/chuyển đổi
/// VCE nào. Nguồn hiểu biết về định dạng: phân tích file mẫu tại máy (docs/notes/vce-format.md) và đặc tả RVF công
/// khai (`RVFReader`).
///
/// Bố cục (`xstr` = `i32` độ dài + `FF FF` + chuỗi đã che, `VceMask`):
///
/// ```text
/// magic 85 A8 02 01 | u8 ? | xstr mã | xstr tiêu đề | i32 điểm đậu | i32 phút | xstr phiên bản | 4 × i64 ngày
/// 6 byte ? | blob ? | blob mô tả (RVF) | i32 số phần, mỗi phần: i32 id + xstr tên
/// i32 số nhóm, mỗi nhóm: u8 ? + xstr tên nhóm | i32 số câu, mỗi câu: i32 kích thước + bản ghi câu
/// i32 kích thước file | 4 byte ? | u32 CRC-32 của mọi byte trước 8 byte cuối
/// ```
///
/// Bản ghi câu: `u8` cờ nhiều đáp án | `i32` id phần | `i32` loại câu (5) | `i32` ? | blob nội dung (đã che: dãy khối
/// `i32` độ dài + RVF: đề bài, từng lựa chọn, giải thích) | blob đáp án (đã che, chữ cái viết liền) | `i32` số lựa
/// chọn | 3 byte ? | xstr tiêu đề tình huống.
///
/// Mọi sai lệch ở mức file (magic, kích thước, CRC-32, độ dài vượt phần còn lại, bản ghi nhóm hỏng, thừa/thiếu byte) → `ImportError
/// .unreadableVCE`, không mở cửa sổ. Sai lệch trong một bản ghi câu (có kích thước riêng nên đọc tiếp được câu sau) →
/// bỏ câu đó và ghi báo cáo. Trường chưa rõ nghĩa: bỏ qua đúng số byte đã mô tả.
enum VceImporter {
    static let magic: [UInt8] = [0x85, 0xA8, 0x02, 0x01]
    /// Kích thước file (4) + 4 byte chưa rõ + CRC-32 (4).
    static let trailerLength = 12
    /// Loại câu duy nhất đã gặp ở các file mẫu (một và nhiều đáp án đều là 5).
    static let supportedQuestionType = 5
    /// Một bản ghi câu ngắn nhất: `i32` kích thước + 9 byte đầu bản ghi.
    static let minimumQuestionBytes = 13
    /// Kiểm huỷ mỗi chừng ấy vòng ở bảng phần/nhóm (file 64 MiB có thể có hàng triệu mục; review độc lập PR #38).
    static let cancellationStride = 4_096

    static func convert(
        _ data: Data, fileStem: String, limits: ImportLimits,
        sharedSectionTitle: String = ImportDefaults.sharedSectionTitle, progress: ProgressReporter
    ) throws -> ImportResult {
        guard data.count <= limits.vceBytes else { throw ImportError.tooLarge(what: .vceFile, limit: limits.vceBytes) }
        let bytes = [UInt8](data)
        let file: VceFile
        do {
            file = try VceFile.parse(bytes)
        } catch let error as VceFormatError {
            throw ImportError.unreadableVCE(error.problem)
        }
        try Task.checkCancellation()
        progress.report(.reading, fraction: 0.1)

        var converter = try VceConverter(file: file, fileStem: fileStem, sharedSectionTitle: sharedSectionTitle)
        let total = max(file.questions.count, 1)
        for (index, range) in file.questions.enumerated() {
            if index % 16 == 0 {
                try Task.checkCancellation()
                progress.report(.converting, fraction: 0.1 + 0.9 * Double(index) / Double(total))
            }
            converter.convertQuestion(number: index + 1, record: range)
        }
        try Task.checkCancellation()
        guard !converter.assembler.sections.isEmpty else {
            throw ImportError.unreadableVCE(converter.noQuestionsProblem(total: file.questions.count))
        }
        return ImportResult(
            examID: UUID(),
            sections: converter.assembler.sections,
            media: [:],
            report: converter.report.makeReport(),
            suggestions: converter.suggestions,
            sourceFormat: .vce
        )
    }
}

// MARK: - Khung file

/// Phần khung của file `.vce` đã kiểm: đầu đề, bảng phần, nhóm, vị trí các bản ghi câu. Nội dung câu đọc sau, từng
/// câu một.
struct VceFile {
    let bytes: [UInt8]
    var code: [UInt8]
    var title: [UInt8]
    var passingScore: Int
    var timeLimit: Int
    var sections: [(id: Int, name: [UInt8])]
    /// Tên các nhóm đề theo thứ tự (có thể rỗng).
    var groupNames: [[UInt8]]
    /// Vùng byte của từng bản ghi câu (không gồm `i32` kích thước).
    var questions: [Range<Int>]

    static func parse(_ bytes: [UInt8]) throws -> VceFile {
        // Kiểm toàn vẹn trước khi đọc nội dung: magic, kích thước khai báo, CRC-32.
        guard bytes.count >= VceImporter.magic.count else {
            throw VceFormatError(bytes.isEmpty ? .empty : .tooShort)
        }
        guard Array(bytes.prefix(4)) == VceImporter.magic else {
            throw VceFormatError(.unknownMagic)
        }
        guard bytes.count >= VceImporter.magic.count + VceImporter.trailerLength else {
            throw VceFormatError.truncated(.fileEnd)
        }
        let trailer = bytes.count - VceImporter.trailerLength
        let declaredSize = VceByteReader.int32(bytes, at: trailer)
        guard declaredSize == bytes.count else {
            throw VceFormatError(.sizeMismatch(declared: declaredSize, actual: bytes.count))
        }
        let storedCRC = VceByteReader.uint32(bytes, at: bytes.count - 4)
        guard VceCRC32.checksum(bytes[0 ..< bytes.count - 8]) == storedCRC else {
            throw VceFormatError(.checksumMismatch)
        }

        var reader = VceByteReader(bytes, range: VceImporter.magic.count ..< trailer)
        try reader.skip(1, .fileHeader)
        let code = try reader.xstr(.code)
        let title = try reader.xstr(.title)
        let passingScore = try reader.i32(.passingScore)
        let timeLimit = try reader.i32(.timeLimit)
        _ = try reader.blob(.examVersion)
        try reader.skip(32, .dates)
        try reader.skip(6, .fileHeader)
        _ = try reader.blob(.fileHeader)
        _ = try reader.blob(.examDescription)

        let sectionCount = try reader.i32(.sectionCount)
        // Mỗi phần ít nhất 8 byte (id + độ dài tên).
        guard sectionCount >= 0, sectionCount <= reader.remaining / 8 else {
            throw VceFormatError(.invalidSectionCount(sectionCount))
        }
        var sections: [(id: Int, name: [UInt8])] = []
        for index in 0 ..< sectionCount {
            if index % VceImporter.cancellationStride == 0 { try Task.checkCancellation() }
            let id = try reader.i32(.sectionID)
            sections.append((id, try reader.xstr(.sectionName)))
        }

        // Nhóm đề (như "Exam A" của bản docx): `i32` số nhóm, mỗi nhóm `u8` + `xstr` tên (bố cục ở
        // đầu file). Các file mẫu có đúng một nhóm; file nhiều nhóm vẫn đọc theo cùng bố cục (Nt0 chốt 2026-10-16,
        // import.md phương án 17), nhưng không đoán câu thuộc nhóm nào. Bản ghi nhóm không đọc được → lỗi.
        let groupCount = try reader.i32(.groupCount)
        // Mỗi nhóm ít nhất 5 byte (`u8` + độ dài tên).
        guard groupCount >= 0, groupCount <= reader.remaining / 5 else {
            throw VceFormatError(.invalidGroupCount(groupCount))
        }
        var groupNames: [[UInt8]] = []
        for index in 0 ..< groupCount {
            if index % VceImporter.cancellationStride == 0 { try Task.checkCancellation() }
            try reader.skip(1, .group)
            groupNames.append(try reader.xstr(.groupName))
        }

        let questionCount = try reader.i32(.questionCount)
        guard questionCount >= 0, questionCount <= reader.remaining / VceImporter.minimumQuestionBytes else {
            throw VceFormatError(.invalidQuestionCount(questionCount))
        }
        var questions: [Range<Int>] = []
        for index in 0 ..< questionCount {
            if index % 256 == 0 { try Task.checkCancellation() }
            let size = try reader.i32(.questionSize(index + 1))
            guard size >= 0, size <= reader.remaining else {
                throw VceFormatError.badLength(.questionRecord(index + 1), size)
            }
            let start = reader.position
            try reader.skip(size, .questionRecord(index + 1))
            questions.append(start ..< start + size)
        }
        guard reader.isAtEnd else {
            throw VceFormatError(.trailingBytes(reader.remaining))
        }
        return VceFile(bytes: bytes, code: code, title: title, passingScore: passingScore, timeLimit: timeLimit,
                       sections: sections, groupNames: groupNames, questions: questions)
    }
}

// MARK: - Câu

/// Ánh xạ câu `.vce` sang mô hình chung (import.md mục `.vce`, như docx).
struct VceConverter {
    let file: VceFile
    let fileStem: String
    private(set) var assembler = ExamAssembler()
    private(set) var report = ReportBuilder()
    private(set) var suggestions: ImportSuggestions
    /// id phần → tên (lần xuất hiện đầu); tên rỗng dùng phần thay thế.
    private let sectionNames: [Int: String]
    /// Mọi id có trong bảng phần (kể cả phần không tên).
    private let sectionIDs: Set<Int>
    /// Tên các phần trong bảng: nhãn `Section: <tên>` ở đầu giải thích chỉ bị bỏ khi tên khớp (hoặc là `(none)`).
    private let sectionTitles: Set<String>
    /// Phần của câu không thuộc phần nào (id −1, id lạ): tên nhóm đề khi file có đúng một nhóm có tên, không thì
    /// "Phần chung" (import.md mục `.vce`, phương án 17).
    private let fallbackSection: String
    private var droppedByCode: [ImportIssueCode: Int] = [:]

    init(file: VceFile, fileStem: String, sharedSectionTitle: String = ImportDefaults.sharedSectionTitle) throws {
        self.file = file
        self.fileStem = fileStem
        var report = ReportBuilder()
        var headerFindings = MojibakeRepair.Findings()
        var assumed: [(what: VceField, hasControl: Bool)] = []

        func text(_ bytes: [UInt8], _ what: VceField) -> String {
            let decoded = Windows1252.decode(bytes)
            if decoded.usedNonASCII { assumed.append((what, Self.containsC1Control(decoded.text))) }
            let repaired = MojibakeRepair.repair(decoded.text)
            headerFindings += repaired.findings
            return TextNormalizer.clean(repaired.text)
        }

        let title = text(file.title, .title)
        let rawCode = text(file.code, .code)
        var code: String?
        if !rawCode.isEmpty {
            if ExamValidator.isValidCode(rawCode) {
                code = rawCode
            } else {
                report.add(.invalidCode, ImportLocation(), .invalidVceCode(rawCode))
            }
        }
        // Cùng quy tắc docx (import.md phương án 13): N > 100 → N/10 làm tròn gần nhất, nửa lên.
        var passPercent: Int?
        if (0 ... 999_999).contains(file.passingScore),
           let percent = HeaderFields.passPercent(fromScore: file.passingScore)
        {
            passPercent = percent
        } else {
            report.add(.invalidPassingScore, ImportLocation(), .passingScoreOutOfRange(file.passingScore))
        }
        var timeLimit: Int?
        if (0 ... 999_999).contains(file.timeLimit) {
            timeLimit = file.timeLimit
        } else {
            report.add(.invalidTimeLimit, ImportLocation(), .invalidVceTimeLimit(file.timeLimit))
        }
        let fallbackStem = TextNormalizer.clean(fileStem)
        suggestions = ImportSuggestions(title: title.isEmpty ? fallbackStem : title, code: code,
                                        passPercent: passPercent, timeLimitMinutes: timeLimit)

        var names: [Int: String] = [:]
        var ids = Set<Int>()
        for (index, section) in file.sections.enumerated() {
            if index % VceImporter.cancellationStride == 0 { try Task.checkCancellation() }
            guard !ids.contains(section.id) else { continue }
            ids.insert(section.id)
            let name = text(section.name, .sectionNameWithID(section.id))
            if !name.isEmpty { names[section.id] = name }
        }
        sectionNames = names
        sectionIDs = ids
        sectionTitles = Set(names.values)
        var groups: [String] = []
        for (index, name) in file.groupNames.enumerated() {
            if index % VceImporter.cancellationStride == 0 { try Task.checkCancellation() }
            groups.append(text(name, .groupNameNumber(index + 1)))
        }
        let named = groups.filter { !$0.isEmpty }
        fallbackSection = named.count == 1 ? named[0] : sharedSectionTitle
        if groups.count > 1 {
            report.add(.multipleGroups, ImportLocation(),
                       .multipleGroups(count: groups.count, fallbackSection: fallbackSection))
        }

        for (what, hasControl) in assumed {
            report.add(.assumedEncoding, ImportLocation(), .assumedEncoding(field: what, hasControlCharacters: hasControl))
        }
        report.addMojibake(headerFindings, ImportLocation(), question: nil)
        self.report = report
    }

    /// Lý do khi không còn câu nào: số câu bị bỏ theo loại.
    func noQuestionsProblem(total: Int) -> VceProblem {
        guard total > 0 else { return .noQuestions }
        return .noUsableQuestions(
            total: total,
            unsupportedType: droppedByCode[.unsupportedQuestionType],
            unreadable: droppedByCode[.unreadableQuestion],
            noOptions: droppedByCode[.noOptions]
        )
    }

    private mutating func drop(_ code: ImportIssueCode, _ location: ImportLocation, _ detail: ImportIssueDetail) {
        droppedByCode[code, default: 0] += 1
        report.add(code, location, detail)
    }

    mutating func convertQuestion(number: Int, record: Range<Int>) {
        let location = ImportLocation(questionNumber: number)
        var reader = VceByteReader(file.bytes, range: record)
        let multiFlag: UInt8
        let sectionID: Int
        let blocks: [ArraySlice<UInt8>]
        let answerBytes: [UInt8]
        do {
            multiFlag = try reader.u8(.questionHeader)
            sectionID = try reader.i32(.questionSection)
            let type = try reader.i32(.questionType)
            guard type == VceImporter.supportedQuestionType else {
                drop(.unsupportedQuestionType, location, .unsupportedQuestionType(type))
                return
            }
            try reader.skip(4, .questionHeader)
            let content = VceMask.unmask(try reader.blob(.questionContent))
            answerBytes = VceMask.unmask(try reader.blob(.answer))
            let optionCount = try reader.i32(.optionCount)
            try reader.skip(3, .questionEnd)
            _ = try reader.blob(.caseTitle)
            guard reader.isAtEnd else {
                throw VceFormatError(.questionTrailingBytes(reader.remaining))
            }
            blocks = try Self.splitBlocks(content)
            guard blocks.count >= 2, blocks.count - 2 == optionCount else {
                throw VceFormatError(.blockCountMismatch(blocks: blocks.count, options: optionCount))
            }
        } catch let error as VceFormatError {
            drop(.unreadableQuestion, location, .unreadableQuestion(error.problem))
            return
        } catch {
            drop(.unreadableQuestion, location, .unreadableQuestion(nil))
            return
        }

        var question = ParsedQuestion()
        question.number = number
        var findings = MojibakeRepair.Findings()
        var notes: [(field: VceField, skipped: [RVFSkip])] = []
        var assumedEncoding = false
        var controlCharacters = false
        var formattedParts: [VceField] = []

        func field(_ block: ArraySlice<UInt8>, _ name: VceField) -> [String] {
            let rvf = RVFReader.read(block)
            if rvf.assumedEncoding { assumedEncoding = true }
            if rvf.droppedFormatting { formattedParts.append(name) }
            if !rvf.skipped.isEmpty { notes.append((name, rvf.skipped)) }
            return rvf.paragraphs.compactMap { paragraph in
                if rvf.assumedEncoding, Self.containsC1Control(paragraph) { controlCharacters = true }
                let repaired = MojibakeRepair.repair(paragraph)
                findings += repaired.findings
                let trimmed = TextNormalizer.trimWhitespace(repaired.text)
                return trimmed.isEmpty ? nil : trimmed
            }
        }

        question.text = Self.markdown(field(blocks[0], .questionText), separator: "\n\n")
        var options: [String] = []
        for (index, block) in blocks.dropFirst().dropLast().enumerated() {
            // Đoạn nối của lựa chọn ghép bằng xuống dòng, như docx (import.md phương án 14).
            let text = Self.markdown(field(block, .option(index: index)), separator: "\n")
            if index < 26 {
                options.append(text)
            } else {
                options[25] += text.isEmpty ? "" : "\n" + text
            }
        }
        if options.count == 26, blocks.count - 2 > 26 {
            report.add(.tooManyOptions, location, question: question.id, .tooManyOptions(count: blocks.count - 2))
        }
        question.options = options
        let explanation = Self.markdown(Self.strippingLabels(field(blocks[blocks.count - 1], .explanation),
                                                             sectionTitles: sectionTitles),
                                        separator: "\n\n")
        question.explanation = explanation.isEmpty ? nil : explanation

        if let name = sectionNames[sectionID] {
            question.sectionTitle = name
        } else {
            question.sectionTitle = fallbackSection
            if sectionIDs.contains(sectionID) {
                report.add(.unknownSection, location, question: question.id,
                           .unnamedSection(id: sectionID, fallbackSection: fallbackSection))
            } else if sectionID != -1 {
                report.add(.unknownSection, location, question: question.id,
                           .unknownSectionID(id: sectionID, fallbackSection: fallbackSection))
            }
        }

        readAnswer(answerBytes, multiFlag: multiFlag, into: &question)

        for note in notes {
            report.add(.unsupportedContent, location, question: question.id,
                       .unsupportedContent(field: note.field, skipped: note.skipped))
        }
        if !formattedParts.isEmpty {
            report.add(.formattingDropped, location, question: question.id, .formattingDropped(fields: formattedParts))
        }
        if assumedEncoding {
            report.add(.assumedEncoding, location, question: question.id,
                       .assumedEncoding(field: .questionANSIText, hasControlCharacters: controlCharacters))
        }
        report.addMojibake(findings, location, question: question.id)
        if !question.options.isEmpty, question.answer == nil, !answerBytes.contains(where: { $0 > 0x20 }) {
            report.add(.missingAnswer, location, question: question.id, .missingAnswerInFile)
        }
        // Câu không có lựa chọn nào: ExamAssembler bỏ và ghi `noOptions` (import.md phương án 7).
        if question.options.isEmpty { droppedByCode[.noOptions, default: 0] += 1 }
        assembler.add(question, report: &report)
    }

    /// Đáp án: chữ cái theo vị trí lựa chọn (A = khối lựa chọn đầu tiên). Các file mẫu viết liền (`AC`); nhận cả
    /// `A,C`/`A C` nhưng cảnh báo vì khác mẫu. Cờ nhiều đáp án của bản ghi (byte đầu) phải khớp số chữ.
    private mutating func readAnswer(_ bytes: [UInt8], multiFlag: UInt8, into question: inout ParsedQuestion) {
        let location = question.location
        guard bytes.allSatisfy({ (0x20 ... 0x7E).contains($0) }) else {
            report.add(.answerUnreadable, location, question: question.id, .answerHasStrangeCharacters)
            return
        }
        let raw = String(decoding: bytes, as: UTF8.self)
        guard !TextNormalizer.isBlank(raw) else { return }
        guard let letters = AnswerParser.parse(raw) else {
            report.add(.answerUnreadable, location, question: question.id, .unreadableVceAnswer(raw))
            return
        }
        question.answer = letters
        if raw.contains(where: { $0 == "," || $0.isWhitespace }) {
            report.add(.unexpectedAnswerFormat, location, question: question.id,
                       .answerWithSeparators(raw: raw, letters: letters))
        }
        if multiFlag > 1 || (multiFlag == 1) != (letters.count >= 2) {
            report.add(.unexpectedAnswerFormat, location, question: question.id,
                       .multipleFlagMismatch(flag: Int(multiFlag), answerCount: letters.count))
        }
    }

    /// Dãy khối `i32` độ dài + RVF của vùng nội dung.
    static func splitBlocks(_ content: [UInt8]) throws -> [ArraySlice<UInt8>] {
        var reader = VceByteReader(content)
        var blocks: [ArraySlice<UInt8>] = []
        while !reader.isAtEnd {
            blocks.append(try reader.blob(.contentBlock))
        }
        return blocks
    }

    /// Ký tự điều khiển C1 (U+0080–U+009F): byte Windows-1252 chưa định nghĩa (0x81, 0x8D, 0x8F, 0x90, 0x9D) giải ra
    /// mã C1 cùng giá trị (quy ước của import.md), vô hình khi hiển thị.
    static func containsC1Control(_ text: String) -> Bool {
        text.unicodeScalars.contains { (0x80 ... 0x9F).contains($0.value) }
    }

    /// Bỏ các đoạn nhãn lặp ở đầu giải thích (`Explanation`, `Explanation/Reference:`, `Section: …`), như docx
    /// (import.md mục `.docx`, Giải thích; giải thích của file mẫu `.vce` có cùng các nhãn). Chữ sau nhãn trong cùng
    /// đoạn được giữ.
    /// `Section: X` chỉ là nhãn lặp khi X là `(none)`, rỗng, hoặc trùng tên một phần trong bảng phần của file; khác thì
    /// đó là chữ của giải thích (review độc lập PR #38) và được giữ nguyên. Đoạn có nhãn đáp án: dừng.
    static func strippingLabels(_ paragraphs: [String], sectionTitles: Set<String>) -> [String] {
        func isRepeatedLabel(_ label: DocxLabels.Label) -> Bool {
            switch label {
            case .explanation:
                return true
            case .answer:
                return false
            case let .section(value):
                let name = TextNormalizer.clean(value)
                return name.isEmpty || name.lowercased() == "(none)" || sectionTitles.contains(name)
            }
        }
        var index = 0
        while index < paragraphs.count, let parsed = DocxLabels.parse(paragraphs[index]),
              parsed.labels.allSatisfy(isRepeatedLabel)
        {
            let remainder = TextNormalizer.trimWhitespace(String(paragraphs[index].dropFirst(parsed.remainderOffset)))
            if !remainder.isEmpty {
                return [remainder] + paragraphs[(index + 1)...]
            }
            index += 1
        }
        return Array(paragraphs[index...])
    }

    /// Các đoạn → Markdown cơ bản; chỉ thoát ký tự khi hiển thị sẽ khác văn bản gốc (import.md, Luồng).
    static func markdown(_ paragraphs: [String], separator: String) -> String {
        TextNormalizer.markdown(fromPlain: paragraphs.joined(separator: separator))
    }
}

extension ReportBuilder {
    /// Một mục `mojibakeFixed` và/hoặc một mục `mojibakeSuspected` (import.md phương án 10).
    mutating func addMojibake(_ findings: MojibakeRepair.Findings, _ location: ImportLocation, question: UUID?) {
        if !findings.fixed.isEmpty {
            add(.mojibakeFixed, location, question: question, .mojibakeFixed(MojibakeRepair.summary(findings.fixed)))
        }
        if !findings.suspected.isEmpty {
            add(.mojibakeSuspected, location, question: question, .mojibakeSuspected(MojibakeRepair.summary(findings.suspected)))
        }
    }
}
