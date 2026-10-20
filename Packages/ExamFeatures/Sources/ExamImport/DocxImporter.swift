import ExamFile
import ExamKit
import Foundation

/// Chuyển file `.docx` thành đề theo docs/product/import.md, mục `.docx` (bố cục xuất từ VCE):
///
/// ```text
/// <Tiêu đề>                       đầu đề: đoạn đầu tiên; Number:, Passing Score:, Time Limit:
/// Exam A                          tiêu đề nhóm
/// QUESTION 1
/// <đề bài: đoạn, danh sách, bảng, ảnh>
///   A. <lựa chọn>                 danh sách Word kiểu upperLetter cấp đầu, hoặc đoạn "A. …"/"A) …"
/// Correct Answer: D
/// Section: Part 2                 nhãn có thể dính nhau trong một đoạn
/// Explanation
/// Explanation/Reference:
/// <giải thích> tới câu kế tiếp
/// ```
enum DocxImporter {
    static let mainDocumentType = "/officeDocument"
    static let numberingType = "/numbering"
    static let defaultMainDocument = "word/document.xml"

    static func convert(
        _ data: Data, fileStem: String, limits: ImportLimits,
        sharedSectionTitle: String = ImportDefaults.sharedSectionTitle, progress: ProgressReporter
    ) throws -> ImportResult {
        try DocxArchive.withTemporaryFile(data) { url in
            try convert(contentsOf: url, fileStem: fileStem, limits: limits, sharedSectionTitle: sharedSectionTitle,
                        progress: progress)
        }
    }

    static func convert(
        contentsOf url: URL, fileStem: String, limits: ImportLimits,
        sharedSectionTitle: String = ImportDefaults.sharedSectionTitle, progress: ProgressReporter
    ) throws -> ImportResult {
        let archive = try DocxArchive(url: url, limits: limits)
        try Task.checkCancellation()

        // Phần văn bản chính: theo `_rels/.rels`, mặc định `word/document.xml`.
        var mainPart = defaultMainDocument
        if let rels = try relationships(at: "_rels/.rels", in: archive, limits: limits),
           let main = rels.values.first(where: { $0.type.hasSuffix(mainDocumentType) && !$0.isExternal }),
           let path = PackagePath.resolve(main.target, relativeTo: "")
        {
            mainPart = path
        }
        guard let documentData = try archive.data(mainPart, limit: limits.xmlPartBytes) else {
            throw ImportError.notADocx
        }
        let documentRels = try relationships(at: PackagePath.relationships(of: mainPart), in: archive, limits: limits)
            ?? [:]
        var numbering = NumberingDefinitions.empty
        if let rel = documentRels.values.first(where: { $0.type.hasSuffix(numberingType) && !$0.isExternal }),
           let path = PackagePath.resolve(rel.target, relativeTo: mainPart),
           let numberingData = try archive.data(path, limit: limits.xmlPartBytes)
        {
            let handler = NumberingHandler()
            try LimitedXMLParser.parse(numberingData, part: path, maxDepth: limits.maxXMLDepth, handler: handler)
            numbering = handler.definitions
        }
        progress.report(.reading, fraction: 0.1)

        let document = DocumentHandler()
        try LimitedXMLParser.parse(documentData, part: mainPart, maxDepth: limits.maxXMLDepth, handler: document)
        try Task.checkCancellation()
        progress.report(.converting, fraction: 0.5)

        let images = ImageResolver(archive: archive, relationships: documentRels, mainPart: mainPart, limits: limits)
        var parser = DocxParser(fileStem: fileStem, numbering: numbering, images: images,
                                sharedSectionTitle: sharedSectionTitle)
        parser.noteInvalidNumbering()
        let blocks = document.blocks
        for (index, block) in blocks.enumerated() {
            if index % 200 == 0 {
                try Task.checkCancellation()
                progress.report(.converting, fraction: 0.5 + 0.5 * Double(index) / Double(max(blocks.count, 1)))
            }
            try parser.consume(block)
        }
        try parser.finish()
        try Task.checkCancellation()
        guard !parser.assembler.sections.isEmpty else {
            throw ImportError.noQuestions(dropped: parser.report.count(.noOptions))
        }

        return ImportResult(
            examID: UUID(),
            sections: parser.assembler.sections,
            media: parser.images.media,
            report: parser.report.makeReport(),
            suggestions: parser.suggestions,
            sourceFormat: .docx
        )
    }

    private static func relationships(at path: String, in archive: DocxArchive, limits: ImportLimits) throws
        -> [String: Relationship]?
    {
        guard let data = try archive.data(path, limit: limits.xmlPartBytes) else { return nil }
        let handler = RelationshipsHandler()
        try LimitedXMLParser.parse(data, part: path, maxDepth: limits.maxXMLDepth, handler: handler)
        return handler.relationships
    }
}

// MARK: - Ảnh

/// Lấy ảnh theo id quan hệ, đặt tên `media/<sha256>.<ext>` (`MediaNaming`).
struct ImageResolver {
    enum Outcome {
        case image(path: String)
        case dropped(ImportIssueCode, ImportIssueDetail)
    }

    /// Chỉ nhận ảnh trong thư mục này của gói docx.
    static let mediaDirectory = "word/media/"

    let archive: DocxArchive
    let relationships: [String: Relationship]
    let mainPart: String
    let limits: ImportLimits
    private(set) var media: [String: Data] = [:]
    private var cache: [String: Outcome] = [:]

    init(archive: DocxArchive, relationships: [String: Relationship], mainPart: String, limits: ImportLimits) {
        self.archive = archive
        self.relationships = relationships
        self.mainPart = mainPart
        self.limits = limits
    }

    mutating func resolve(_ relationshipID: String) throws -> Outcome {
        if let cached = cache[relationshipID] { return cached }
        let outcome = try load(relationshipID)
        cache[relationshipID] = outcome
        return outcome
    }

    private mutating func load(_ relationshipID: String) throws -> Outcome {
        guard let rel = relationships[relationshipID], !rel.isExternal,
              let path = PackagePath.resolve(rel.target, relativeTo: mainPart)
        else {
            return .dropped(.imageNotFound, .externalImage)
        }
        // import.md: ảnh lấy từ `word/media/`; đường dẫn khác (gốc zip, thư mục khác) không nhận.
        guard path.hasPrefix(Self.mediaDirectory) else {
            return .dropped(.imageNotFound, .imageOutsideMediaFolder)
        }
        let fileExtension = (path as NSString).pathExtension.lowercased()
        guard MediaNaming.allowedExtensions.contains(fileExtension) else {
            return .dropped(.unsupportedImageFormat,
                            .unsupportedImageFormat(fileExtension: fileExtension.isEmpty ? nil : fileExtension))
        }
        let data: Data?
        do {
            data = try archive.data(path, limit: limits.mediaEntryBytes)
        } catch ImportError.tooLarge {
            return .dropped(.imageTooLarge, .imageTooLarge(fileName: (path as NSString).lastPathComponent))
        }
        guard let data else {
            return .dropped(.imageNotFound, .missingImage(fileName: (path as NSString).lastPathComponent))
        }
        let mediaPath = try MediaNaming.path(for: data, fileExtension: fileExtension)
        media[mediaPath] = data
        return .image(path: mediaPath)
    }
}

// MARK: - Tách câu

/// Một đơn vị nội dung để ghép vào đề bài/lựa chọn/giải thích.
private struct Piece {
    enum Separator {
        /// Đoạn mới (`\n\n`).
        case paragraph
        /// Xuống dòng (`\n`): dòng sau ngắt dòng trong cùng đoạn Word, mục danh sách liền nhau, đoạn nối của lựa chọn.
        case line
    }

    var separator: Separator
    var isListItem: Bool
    /// Ký hiệu danh sách (`- `, `1. `, kèm thụt lề theo cấp), không thoát Markdown.
    var marker: String
    var runs: [DocxRun]
}

/// Gom các đơn vị của một trường (đề bài, một lựa chọn, giải thích) rồi xuất Markdown cơ bản.
private struct FieldBuilder {
    private(set) var pieces: [Piece] = []

    var isEmpty: Bool { pieces.isEmpty }

    mutating func append(_ runs: [DocxRun], marker: String = "", isListItem: Bool = false,
                         separator: Piece.Separator = .paragraph)
    {
        guard !runs.allSatisfy({ TextNormalizer.isBlank($0.text) }) else { return }
        var separator = separator
        if isListItem, pieces.last?.isListItem == true { separator = .line }
        pieces.append(Piece(separator: separator, isListItem: isListItem, marker: marker, runs: runs))
    }

    /// Thoát Markdown (khi cần) quyết định trên chữ trơn của cả trường, vì cú pháp inline có thể vắt qua dòng.
    func render() -> String {
        let plain = joined { $0.runs.map(\.text).joined() }
        let escape = TextNormalizer.needsMarkdownEscaping(plain)
        return joined { Self.markdown($0.runs, escape: escape) }
    }

    /// Ghép các đơn vị: ký hiệu danh sách (giữ thụt lề) + nội dung đã bỏ khoảng trắng hai đầu.
    private func joined(_ body: (Piece) -> String) -> String {
        var out = ""
        for (index, piece) in pieces.enumerated() {
            if index > 0 { out += piece.separator == .line ? "\n" : "\n\n" }
            out += piece.marker + TextNormalizer.trimWhitespace(body(piece))
        }
        return out
    }

    /// Đậm → `**…**`, nghiêng → `*…*`, cả hai → `***…***`; khoảng trắng hai đầu đặt ngoài dấu.
    private static func markdown(_ runs: [DocxRun], escape: Bool) -> String {
        let merged = DocxParser.mergeRuns(runs)
        let texts = merged.map { escape ? TextNormalizer.escapeMarkdown($0.text) : $0.text }
        var out = ""
        for (index, run) in merged.enumerated() {
            let text = texts[index]
            let delimiter = (run.bold ? "**" : "") + (run.italic ? "*" : "")
            var core = TextNormalizer.trimWhitespace(text)
            guard !delimiter.isEmpty, !core.isEmpty else {
                out += text
                continue
            }
            let leading = String(text.prefix { $0.isWhitespace })
            let trailing = String(text.reversed().prefix { $0.isWhitespace }.reversed())
            // CommonMark (quy tắc "flanking"): dấu `**` kề trong là dấu câu thì kề ngoài phải là khoảng trắng/dấu câu,
            // không thì không thành đậm (`**(chú ý)**tiếp` hiện nguyên dấu sao). Khi đó đưa dấu câu ở mép ra ngoài
            // dấu: `**(chú ý**)tiếp` vẫn hiện đậm phần chữ.
            let before = leading.isEmpty ? out.last : leading.last
            let after = trailing.isEmpty ? texts[(index + 1)...].lazy.compactMap(\.first).first : trailing.first
            var outsideLeading = ""
            var outsideTrailing = ""
            if let before, isWordCharacter(before), let first = core.first, isPunctuation(first) {
                outsideLeading = String(core.prefix(while: isPunctuation))
                core.removeFirst(outsideLeading.count)
            }
            if let after, isWordCharacter(after), let last = core.last, isPunctuation(last) {
                outsideTrailing = String(core.reversed().prefix(while: isPunctuation).reversed())
                core.removeLast(outsideTrailing.count)
            }
            if core.isEmpty {
                out += leading + outsideLeading + outsideTrailing + trailing
            } else {
                out += leading + outsideLeading + delimiter + core + delimiter + outsideTrailing + trailing
            }
        }
        return out
    }

    private static func isPunctuation(_ c: Character) -> Bool { c.isPunctuation || c.isSymbol }

    private static func isWordCharacter(_ c: Character) -> Bool { !c.isWhitespace && !isPunctuation(c) }
}

/// Máy trạng thái tách câu từ các khối của tài liệu Word.
struct DocxParser {
    private enum State {
        case header
        case questionText
        case options
        case answer
        case explanation
    }

    /// Một dòng của đoạn (đoạn Word tách ở ngắt dòng) hoặc một bảng.
    private struct Unit {
        var runs: [DocxRun]
        /// Chữ trơn đã bỏ khoảng trắng hai đầu.
        var plain: String
        /// Số ký tự khoảng trắng đầu dòng trong chữ trơn gốc (để bỏ nhãn khỏi các run).
        var leadingWhitespace: Int
        var isTable = false
        /// Dòng sau ngắt dòng trong cùng một đoạn Word.
        var continuesParagraph = false
        var list: ListItem?
        var images: [String] = []
    }

    private struct ListItem {
        /// Mục danh sách `upperLetter` cấp đầu: là lựa chọn.
        var isOption: Bool
        var marker: String
    }

    private let fileStem: String
    /// Tên phần của câu không có `Section:` và không có tiêu đề nhóm (`ImportDefaults.sharedSectionTitle`).
    private let sharedSectionTitle: String
    private let numbering: NumberingDefinitions
    private(set) var images: ImageResolver
    private(set) var assembler = ExamAssembler()
    private(set) var report = ReportBuilder()

    // Đầu đề
    private var title: String?
    private var titleDecided = false
    private var code: String?
    private var passPercent: Int?
    private var timeLimit: Int?
    private var groupTitle: String?

    // Câu đang đọc
    private var state = State.header
    private var question = ParsedQuestion()
    private var questionGroup: String?
    private var sectionValue: String?
    private var text = FieldBuilder()
    private var options: [FieldBuilder] = []
    private var explanation = FieldBuilder()
    private var answerRaw: String?
    private var unrecognizedReported = false
    private var headerFixes = MojibakeRepair.Findings()
    private var questionFixes = MojibakeRepair.Findings()
    /// Nội dung của câu đang đọc, xử lý khi hết câu.
    private var pending: [(unit: Unit, fixes: MojibakeRepair.Findings)] = []
    /// Vị trí chữ lựa chọn đầu tiên (0 = A; khác 0 khi câu không có đoạn `A.` và không dùng danh sách).
    private var optionStartOffset = 0
    /// Nhận đoạn `A.`/`A)` làm lựa chọn. Tắt khi câu dùng danh sách upperLetter cho lựa chọn (import.md: dạng chữ chỉ
    /// dùng khi không có danh sách); khi đó đoạn `A.` là chữ của đề bài hoặc phần nối của lựa chọn.
    private var textLabelOptions = true
    /// Số đơn vị đã xử lý, để kiểm huỷ định kỳ (cả khi xử lý lại nội dung một câu dài).
    private var unitCount = 0

    // Bộ đếm danh sách đánh số: numId → cấp → số hiện tại.
    private var counters: [Int: [Int: Int]] = [:]

    init(
        fileStem: String, numbering: NumberingDefinitions, images: ImageResolver,
        sharedSectionTitle: String = ImportDefaults.sharedSectionTitle
    ) {
        self.fileStem = fileStem
        self.sharedSectionTitle = sharedSectionTitle
        self.numbering = numbering
        self.images = images
    }

    var suggestions: ImportSuggestions {
        let fallback = TextNormalizer.clean(fileStem)
        let cleanTitle = title.map(TextNormalizer.clean) ?? ""
        return ImportSuggestions(
            title: cleanTitle.isEmpty ? fallback : cleanTitle,
            code: code,
            passPercent: passPercent,
            timeLimitMinutes: timeLimit
        )
    }

    // MARK: Khối → đơn vị

    mutating func consume(_ block: DocxBlock) throws {
        switch block.content {
        case let .table(rows):
            let repaired = MojibakeRepair.repair(rows.map { $0.joined(separator: " | ") }.joined(separator: "\n"))
            let unit = Unit(runs: [DocxRun(text: repaired.text, bold: false, italic: false)],
                            plain: TextNormalizer.trimWhitespace(repaired.text), leadingWhitespace: 0, isTable: true,
                            images: block.imageRelationshipIDs)
            try ingest(unit, repaired.findings)
        case let .paragraph(lines, numID, ilvl):
            let list = numID.map { listItem(numID: $0, ilvl: ilvl) }
            for (index, original) in lines.enumerated() {
                // Sửa mojibake trên từng đoạn chữ cùng định dạng (gộp run liền nhau trước, vì Word có thể tách một
                // từ thành nhiều run).
                var fixes = MojibakeRepair.Findings()
                let runs = Self.mergeRuns(original).map { run in
                    let repaired = MojibakeRepair.repair(run.text)
                    fixes += repaired.findings
                    return DocxRun(text: repaired.text, bold: run.bold, italic: run.italic)
                }
                let raw = runs.map(\.text).joined()
                let plain = TextNormalizer.trimWhitespace(raw)
                let leading = raw.prefix { $0.isWhitespace }.count
                let unit = Unit(runs: runs, plain: plain, leadingWhitespace: leading, continuesParagraph: index > 0,
                                list: index == 0 ? list : nil, images: index == 0 ? block.imageRelationshipIDs : [])
                try ingest(unit, fixes)
            }
        }
    }

    /// Đầu đề và đoạn `QUESTION n` xử lý ngay; nội dung của câu giữ tới hết câu, vì chữ lựa chọn đầu tiên (dạng
    /// `A.`) phụ thuộc cả khối câu.
    private mutating func ingest(_ unit: Unit, _ fixes: MojibakeRepair.Findings) throws {
        let isHead = !unit.isTable && unit.list == nil && Patterns.docxQuestionHead(unit.plain) != nil
        if state == .header || isHead {
            try consume(unit)
            recordMojibake(fixes)
        } else {
            pending.append((unit, fixes))
        }
    }

    /// Chữ của các đoạn nhãn lựa chọn (`A.`/`A)`) trước đoạn nhãn đầu tiên (đáp án, phần, giải thích); không có gì
    /// nếu câu dùng danh sách upperLetter cho lựa chọn.
    private static func optionLabels(in units: [(unit: Unit, fixes: MojibakeRepair.Findings)]) -> [OptionID] {
        var labels: [OptionID] = []
        for (unit, _) in units where !unit.isTable {
            if unit.list?.isOption == true { return [] }
            if DocxLabels.parse(unit.plain) != nil { break }
            if let label = Patterns.optionLabel(unit.plain) { labels.append(label.letter) }
        }
        return labels
    }

    /// Gộp các run liền nhau cùng định dạng.
    static func mergeRuns(_ runs: [DocxRun]) -> [DocxRun] {
        var merged: [DocxRun] = []
        for run in runs {
            if var last = merged.last, last.bold == run.bold, last.italic == run.italic {
                last.text += run.text
                merged[merged.count - 1] = last
            } else {
                merged.append(run)
            }
        }
        return merged
    }

    /// Chỗ sửa mojibake thuộc câu đang đọc (kể cả đoạn `QUESTION n` vừa mở câu), hoặc đầu đề nếu chưa có câu nào.
    private mutating func recordMojibake(_ fixes: MojibakeRepair.Findings) {
        guard !fixes.isEmpty else { return }
        if state == .header {
            headerFixes += fixes
        } else {
            questionFixes += fixes
        }
    }

    private mutating func reportHeaderMojibake() {
        reportMojibake(headerFixes, ImportLocation(), question: nil)
        headerFixes = .init()
    }

    private mutating func reportMojibake(_ findings: MojibakeRepair.Findings, _ location: ImportLocation, question: UUID?) {
        if !findings.fixed.isEmpty {
            report.add(.mojibakeFixed, location, question: question, .mojibakeFixed(MojibakeRepair.summary(findings.fixed)))
        }
        if !findings.suspected.isEmpty {
            report.add(.mojibakeSuspected, location, question: question,
                       .mojibakeSuspected(MojibakeRepair.summary(findings.suspected)))
        }
    }

    /// Ký hiệu Markdown của mục danh sách và bộ đếm (import.md: `- ` gạch đầu dòng, `1. ` đánh số).
    private mutating func listItem(numID: Int, ilvl: Int) -> ListItem {
        let level = numbering.level(numID: numID, ilvl: ilvl)
        var levels = counters[numID] ?? [:]
        // Số bắt đầu ≤ 32767 (`NumberingDefinitions.startRange`) và số mục ≤ số đoạn nên không tràn; vẫn chặn trần.
        let number = levels[ilvl].map { $0 < Int.max ? $0 + 1 : $0 } ?? level?.start ?? 1
        levels[ilvl] = number
        for deeper in levels.keys where deeper > ilvl { levels[deeper] = nil }
        counters[numID] = levels

        let format = level?.format ?? "bullet"
        let indent = String(repeating: "  ", count: max(0, min(ilvl, 8)))
        let marker: String
        switch format {
        case "bullet": marker = indent + "- "
        case "none": marker = indent
        default: marker = indent + "\(number). "
        }
        return ListItem(isOption: format == "upperLetter" && ilvl == 0, marker: marker)
    }

    // MARK: Đơn vị → câu

    private mutating func consume(_ unit: Unit) throws {
        unitCount += 1
        if unitCount % 256 == 0 { try Task.checkCancellation() }
        if unit.isTable {
            report.add(.tableConverted, currentLocation, question: currentQuestionID, .tableConverted)
        }

        if !unit.isTable, unit.list == nil, let number = Patterns.docxQuestionHead(unit.plain) {
            if state != .header { try finishQuestion() }
            startQuestion(number: number)
            try placeImages(unit.images, inQuestionText: true)
            return
        }

        // Tiêu đề nhóm ("Exam A") nằm giữa các câu; trong đề bài thì coi là chữ của đề bài.
        if !unit.isTable, unit.list == nil, state != .questionText, Patterns.isGroupHeading(unit.plain)
        {
            groupTitle = unit.plain
            try placeImages(unit.images, inQuestionText: false)
            return
        }

        if state == .header {
            if !unit.isTable { readHeader(unit.plain) }
            try placeImages(unit.images, inQuestionText: false)
            return
        }

        if !unit.isTable, let labels = DocxLabels.parse(unit.plain), applyLabels(labels.labels) {
            if state == .explanation, labels.remainderOffset < unit.plain.count {
                explanation.append(Self.dropping(unit.leadingWhitespace + labels.remainderOffset, from: unit.runs))
            }
            try placeImages(unit.images, inQuestionText: false)
            return
        }

        switch state {
        case .header:
            break
        case .questionText, .options:
            let expected = OptionID(index: optionStartOffset + options.count)
            let textLabel = unit.isTable || !textLabelOptions ? nil : Patterns.optionLabel(unit.plain)
            if unit.list?.isOption == true {
                if options.count < 26 {
                    startOption(unit.runs)
                    try placeImages(unit.images, inQuestionText: false)
                    return
                }
                report.add(.tooManyOptions, currentLocation, question: currentQuestionID, .tooManyListOptions)
            } else if let textLabel, textLabel.letter == expected {
                startOption(Self.dropping(unit.leadingWhitespace + textLabel.prefixLength, from: unit.runs))
                try placeImages(unit.images, inQuestionText: false)
                return
            } else if let textLabel, state == .questionText {
                if question.misplacedOptionLabel == nil { question.misplacedOptionLabel = (textLabel.letter, nil) }
            } else if let textLabel, state == .options {
                report.add(.optionLabelOutOfOrder, currentLocation, question: currentQuestionID,
                           .optionLabelOutOfOrder(unit: .paragraph, label: textLabel.letter, expected: expected,
                                                  appendedTo: OptionID(index: optionStartOffset + options.count - 1)!))
            }
            if state == .options {
                let marker = unit.list?.marker ?? ""
                options[options.count - 1].append(unit.runs, marker: marker, isListItem: unit.list != nil,
                                                  separator: .line)
                try placeImages(unit.images, inQuestionText: false)
            } else {
                text.append(unit.runs, marker: unit.list?.marker ?? "", isListItem: unit.list != nil,
                            separator: unit.continuesParagraph ? .line : .paragraph)
                try placeImages(unit.images, inQuestionText: true)
            }
        case .answer:
            if !unit.plain.isEmpty, !unrecognizedReported {
                unrecognizedReported = true
                report.add(.unrecognizedText, currentLocation, question: currentQuestionID, .textAfterAnswerParagraph)
            }
            try placeImages(unit.images, inQuestionText: false)
        case .explanation:
            explanation.append(unit.runs, marker: unit.list?.marker ?? "", isListItem: unit.list != nil,
                               separator: unit.continuesParagraph ? .line : .paragraph)
            try placeImages(unit.images, inQuestionText: false)
        }
    }

    mutating func finish() throws {
        if state == .header {
            reportHeaderMojibake()
        } else {
            try finishQuestion()
        }
    }

    private var currentLocation: ImportLocation {
        state == .header ? ImportLocation() : question.location
    }

    private var currentQuestionID: UUID? {
        state == .header ? nil : question.id
    }

    private mutating func startQuestion(number: Int) {
        if state == .header { reportHeaderMojibake() }
        question = ParsedQuestion()
        question.number = number
        questionGroup = groupTitle
        sectionValue = nil
        text = FieldBuilder()
        options = []
        explanation = FieldBuilder()
        answerRaw = nil
        unrecognizedReported = false
        questionFixes = .init()
        pending = []
        optionStartOffset = 0
        textLabelOptions = true
        state = .questionText
    }

    private mutating func startOption(_ runs: [DocxRun]) {
        var field = FieldBuilder()
        field.append(runs)
        options.append(field)
        state = .options
    }

    private mutating func finishQuestion() throws {
        let units = pending
        pending = []
        textLabelOptions = !units.contains { $0.unit.list?.isOption == true }
        optionStartOffset = OptionRelettering.startOffset(labels: Self.optionLabels(in: units))
        for (unit, fixes) in units {
            try consume(unit)
            recordMojibake(fixes)
        }

        question.text = text.render()
        question.options = options.map { $0.render() }
        if optionStartOffset > 0, !question.options.isEmpty {
            let shift = OptionRelettering.apply(to: &question, offset: optionStartOffset)
            report.add(.optionLabelsShifted, question.location, question: question.id, .optionLabelsShifted(shift))
        }
        let explanationText = explanation.render()
        question.explanation = explanationText.isEmpty ? nil : explanationText
        // import.md: `Section: <tên>`; `(none)` hoặc thiếu → tiêu đề nhóm gần nhất, không có thì "Phần chung".
        if let sectionValue, !sectionValue.isEmpty, sectionValue.lowercased() != "(none)" {
            question.sectionTitle = sectionValue
        } else {
            question.sectionTitle = questionGroup ?? sharedSectionTitle
        }
        reportMojibake(questionFixes, question.location, question: question.id)
        if answerRaw == nil, !question.options.isEmpty {
            report.add(.missingAnswer, question.location, question: question.id, .missingAnswerLine)
        }
        assembler.add(question, report: &report)
    }

    /// Áp các nhãn đầu đoạn. Trả `false` nếu đoạn nên coi là nội dung (đang ở giải thích, đoạn chỉ có một dòng đáp
    /// án khác đáp án đã có: chữ trong giải thích, không phải nhãn lặp).
    private mutating func applyLabels(_ labels: [DocxLabels.Label]) -> Bool {
        if state == .explanation, let answerRaw {
            for case let .answer(value) in labels where Patterns.compact(value) != Patterns.compact(answerRaw) {
                return false
            }
        }
        for label in labels {
            switch label {
            case let .answer(value):
                recordAnswer(value)
                if state == .questionText || state == .options { state = .answer }
            case let .section(value):
                if sectionValue == nil { sectionValue = TextNormalizer.trimWhitespace(value) }
                if state == .questionText || state == .options { state = .answer }
            case .explanation:
                state = .explanation
            }
        }
        return true
    }

    private mutating func recordAnswer(_ value: String) {
        if let answerRaw {
            if Patterns.compact(value) != Patterns.compact(answerRaw) {
                report.add(.conflictingAnswer, question.location, question: question.id,
                           .conflictingAnswer(value: value, kept: answerRaw))
            }
            return
        }
        answerRaw = value
        if let letters = AnswerParser.parse(value) {
            question.answer = letters
        } else {
            report.add(.answerUnreadable, question.location, question: question.id, .unreadableAnswer(value))
        }
    }

    // MARK: Đầu đề

    /// Cảnh báo một lần nếu `numbering.xml` có số bắt đầu ngoài khoảng (đã bỏ qua).
    mutating func noteInvalidNumbering() {
        let count = numbering.invalidStartCount
        guard count > 0 else { return }
        report.add(.invalidNumbering, ImportLocation(), .invalidNumbering(count: count))
    }

    private mutating func readHeader(_ plain: String) {
        guard !plain.isEmpty else { return }
        let header = HeaderFields.parse(plain)
        if !titleDecided {
            titleDecided = true
            if !header.hasLabel { title = plain }
        }
        if let number = header.number {
            if ExamValidator.isValidCode(number) {
                if code == nil { code = number }
            } else {
                report.add(.invalidCode, ImportLocation(), .invalidDocxCode(number))
            }
        }
        if let raw = header.passingScore {
            if let value = HeaderFields.boundedInt(raw), let percent = HeaderFields.passPercent(fromScore: value) {
                if passPercent == nil { passPercent = percent }
            } else {
                report.add(.invalidPassingScore, ImportLocation(), .unreadablePassingScore(raw))
            }
        }
        if let raw = header.timeLimit {
            if let minutes = HeaderFields.boundedInt(raw) {
                if timeLimit == nil { timeLimit = minutes }
            } else {
                report.add(.invalidTimeLimit, ImportLocation(), .unreadableTimeLimit(raw))
            }
        }
    }

    // MARK: Ảnh

    /// import.md: ảnh trong đề bài thành ảnh của câu (một ảnh mỗi câu); ảnh khác, ảnh ngoài đề bài, ảnh sai định
    /// dạng bị bỏ và ghi báo cáo. Ảnh đầu tiên dùng được (đúng định dạng, có trong file) được giữ.
    private mutating func placeImages(_ ids: [String], inQuestionText: Bool) throws {
        for id in ids {
            let location = currentLocation
            let questionID = currentQuestionID
            guard inQuestionText, state == .questionText else {
                let part: DocxPart = switch state {
                case .header: .header
                case .options: .options
                case .answer, .explanation: .explanation
                case .questionText: .questionText
                }
                report.add(.imageOutsideQuestionText, location, question: questionID, .imageOutsideQuestionText(part))
                continue
            }
            if question.image != nil {
                report.add(.extraImage, location, question: questionID, .extraImage)
                continue
            }
            switch try images.resolve(id) {
            case let .image(path):
                question.image = path
            case let .dropped(code, detail):
                report.add(code, location, question: questionID, detail)
            }
        }
    }

    /// Bỏ `count` ký tự đầu (theo chữ trơn ghép từ các run) khỏi danh sách run.
    private static func dropping(_ count: Int, from runs: [DocxRun]) -> [DocxRun] {
        var remaining = count
        var out: [DocxRun] = []
        for run in runs {
            if remaining <= 0 {
                out.append(run)
            } else if run.text.count <= remaining {
                remaining -= run.text.count
            } else {
                var trimmed = run
                trimmed.text = String(run.text.dropFirst(remaining))
                remaining = 0
                out.append(trimmed)
            }
        }
        return out
    }
}

// MARK: - Nhãn và đầu đề

/// Nhãn ở đầu đoạn sau phần lựa chọn: `Correct Answer:`/`Answer:`, `Section:`, `Explanation`,
/// `Explanation/Reference:`, `Explanation:`; có thể dính nhau trong một đoạn ("Correct Answer: C Section: Part 2
/// Explanation").
enum DocxLabels {
    enum Label: Equatable {
        case answer(String)
        case section(String)
        case explanation
    }

    /// `remainderOffset`: số ký tự (trong chữ trơn đã bỏ khoảng trắng hai đầu) trước phần nội dung sau nhãn cuối.
    static func parse(_ plain: String) -> (labels: [Label], remainderOffset: Int)? {
        var labels: [Label] = []
        var index = plain.startIndex
        while index < plain.endIndex {
            let rest = plain[index...]
            if let match = rest.prefixMatch(of: valueLabelRegex) {
                let valueStart = match.range.upperBound
                let valueEnd = nextLabelStart(in: plain, from: valueStart)
                let value = TextNormalizer.trimWhitespace(String(plain[valueStart ..< valueEnd]))
                let name = match.output.1.lowercased()
                labels.append(name == "section" ? .section(value) : .answer(value))
                index = valueEnd
            } else if let match = rest.prefixMatch(of: explanationLabelRegex) {
                labels.append(.explanation)
                index = match.range.upperBound
            } else {
                break
            }
            index = plain[index...].firstIndex { !$0.isWhitespace } ?? plain.endIndex
        }
        guard !labels.isEmpty else { return nil }
        return (labels, plain.distance(from: plain.startIndex, to: index))
    }

    /// Nhãn có giá trị tới nhãn kế tiếp hoặc hết đoạn.
    nonisolated(unsafe) private static let valueLabelRegex =
        /(?i)(Correct[ \t]+Answer|Answer|Section)[ \t]*:/
    /// Nhãn mở giải thích: `Explanation/Reference:`, `Explanation:`, hoặc `Explanation` đứng riêng (hết đoạn hay
    /// liền sau là nhãn khác).
    nonisolated(unsafe) private static let explanationLabelRegex =
        /(?i)Explanation[ \t]*\/[ \t]*Reference[ \t]*:|Explanation[ \t]*:|Explanation(?=\s*$|\s+(?:Correct[ \t]+Answer|Answer|Section|Explanation)\b)/
    /// Nhãn bắt đầu tại vị trí đang xét (chỉ dùng `prefixMatch`, không có lượng từ ở đầu mẫu).
    nonisolated(unsafe) private static let labelStartRegex =
        /(?i)(?:Correct[ \t]+Answer|Answer|Section)[ \t]*:|Explanation(?:[ \t]*\/[ \t]*Reference)?[ \t]*:|Explanation(?=\s|$)/

    /// Đầu dãy khoảng trắng đứng ngay trước nhãn kế tiếp (giá trị kết thúc ở đó), hoặc hết đoạn. Quét tuyến tính: chỉ
    /// thử khớp nhãn tại ký tự đầu tiên sau mỗi dãy khoảng trắng (review PR #32: mẫu `\s+(?=…)` chạy theo bình phương
    /// với dãy khoảng trắng dài).
    static func nextLabelStart(in plain: String, from start: String.Index) -> String.Index {
        var index = start
        var whitespaceStart: String.Index?
        while index < plain.endIndex {
            if plain[index].isWhitespace {
                if whitespaceStart == nil { whitespaceStart = index }
            } else {
                if let whitespaceStart, plain[index...].prefixMatch(of: labelStartRegex) != nil { return whitespaceStart }
                whitespaceStart = nil
            }
            index = plain.index(after: index)
        }
        return plain.endIndex
    }
}

/// Các trường đầu đề docx: `Number:`, `Passing Score:`, `Time Limit: N min` (có thể dính nhau trong một đoạn).
struct HeaderFields {
    var number: String?
    var passingScore: String?
    var timeLimit: String?
    /// Đoạn bắt đầu bằng một trong các nhãn trên (không phải tiêu đề).
    var hasLabel = false

    /// Quét tuyến tính cả đoạn (không cắt, không regex có quay lui): nhãn có thể đứng sau một tiêu đề dài trong
    /// cùng đoạn. Mỗi trường lấy lần xuất hiện đầu tiên; nhãn không phân biệt hoa thường, phải đứng đầu từ.
    static func parse(_ plain: String) -> HeaderFields {
        let chars = Array(plain)
        var fields = HeaderFields()
        fields.hasLabel = [["number"], ["passing", "score"], ["time", "limit"]]
            .contains { label(chars, at: 0, words: $0) != nil }
        if let start = firstLabel(chars, words: ["number"], requireValue: true) {
            fields.number = token(chars, from: start)
        }
        if let start = firstLabel(chars, words: ["passing", "score"], requireValue: false) {
            fields.passingScore = token(chars, from: start)
        }
        if let start = firstLabel(chars, words: ["time", "limit"], requireValue: false) {
            // Giá trị là số phút đứng trước `min`; không có `min` thì lấy cả chữ để báo không đọc được.
            var end = start
            while end < chars.count, chars[end].isASCII, chars[end].isNumber { end += 1 }
            var unit = end
            while unit < chars.count, chars[unit] == " " || chars[unit] == "\t" { unit += 1 }
            let hasMin = end > start && unit + 3 <= chars.count
                && String(chars[unit ..< unit + 3]).lowercased() == "min"
            fields.timeLimit = hasMin ? String(chars[start ..< end]) : token(chars, from: start)
        }
        return fields
    }

    /// Vị trí giá trị (sau `:` và khoảng trắng) của lần đầu nhãn `words` xuất hiện ở đầu một từ; `requireValue`:
    /// bỏ qua nhãn không có giá trị (như mẫu `\S+`).
    private static func firstLabel(_ chars: [Character], words: [String], requireValue: Bool) -> Int? {
        let first = words[0].first!
        var index = 0
        while index < chars.count {
            defer { index += 1 }
            guard chars[index].lowercased() == String(first) else { continue }
            if index > 0, chars[index - 1].isLetter || chars[index - 1].isNumber || chars[index - 1] == "_" { continue }
            guard let start = label(chars, at: index, words: words) else { continue }
            if requireValue, start >= chars.count || chars[start].isWhitespace { continue }
            return start
        }
        return nil
    }

    /// Khớp `word1[ \t]+word2…[ \t]*:[ \t]*` tại `index` (không phân biệt hoa thường) → vị trí sau phần đó.
    private static func label(_ chars: [Character], at index: Int, words: [String]) -> Int? {
        var i = index
        func skipBlanks() -> Int {
            let from = i
            while i < chars.count, chars[i] == " " || chars[i] == "\t" { i += 1 }
            return i - from
        }
        for (n, word) in words.enumerated() {
            if n > 0, skipBlanks() == 0 { return nil }
            for letter in word {
                guard i < chars.count, chars[i].lowercased() == String(letter) else { return nil }
                i += 1
            }
        }
        _ = skipBlanks()
        guard i < chars.count, chars[i] == ":" else { return nil }
        i += 1
        _ = skipBlanks()
        return i
    }

    /// Dãy ký tự không phải khoảng trắng từ `start` (có thể rỗng).
    private static func token(_ chars: [Character], from start: Int) -> String {
        var end = start
        while end < chars.count, !chars[end].isWhitespace { end += 1 }
        return String(chars[start ..< end])
    }

    /// Số nguyên không âm tối đa 6 chữ số; dài hơn hoặc không phải số → `nil` (coi như không có, ghi cảnh báo), để
    /// không tràn số với giá trị dị dạng như `9223372036854775807`.
    static func boundedInt(_ raw: String) -> Int? {
        guard (1 ... 6).contains(raw.count), raw.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        return Int(raw)
    }

    /// `Passing Score: N` → N/10 % làm tròn gần nhất, nửa lên (725 → 73, 724 → 72) nếu N > 100, ngược lại N %
    /// (import.md, phương án 13).
    /// `nil` nếu ngoài 0–100 %.
    static func passPercent(fromScore score: Int) -> Int? {
        let percent = score > 100 ? (score + 5) / 10 : score
        return (0 ... 100).contains(percent) ? percent : nil
    }
}

extension Patterns {
    /// docx: đoạn `QUESTION <số>` (không phân biệt hoa thường).
    static func docxQuestionHead(_ plain: String) -> Int? {
        guard let match = plain.wholeMatch(of: docxQuestionRegex) else { return nil }
        return Int(match.output.1)
    }

    nonisolated(unsafe) private static let docxQuestionRegex = /(?i)QUESTION[ \t\u{00A0}]+(\d{1,9})/

    /// Tiêu đề nhóm của bố cục VCE: `Exam A`, `Exam B`…
    static func isGroupHeading(_ plain: String) -> Bool {
        plain.wholeMatch(of: groupHeadingRegex) != nil
    }

    nonisolated(unsafe) private static let groupHeadingRegex = /Exam[ \t]+[A-Z]/
}
