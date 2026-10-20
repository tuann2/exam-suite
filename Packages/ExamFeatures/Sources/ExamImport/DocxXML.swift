import Foundation

// Đọc các phần XML của `.docx` bằng `XMLParser` (Foundation; ADR 0006: không thêm thư viện).
// Chỉ lấy đúng những gì import.md cần: đoạn, chữ (đậm/nghiêng), ngắt dòng, danh sách, bảng, ảnh.

/// Không gian tên XML của Office Open XML (bản Transitional mà Word ghi, và bản Strict).
enum OOXMLNamespace {
    static let word: Set<String> = [
        "http://schemas.openxmlformats.org/wordprocessingml/2006/main",
        "http://purl.oclc.org/ooxml/wordprocessingml/main",
    ]
    static let drawing: Set<String> = [
        "http://schemas.openxmlformats.org/drawingml/2006/main",
        "http://purl.oclc.org/ooxml/drawingml/main",
    ]
    static let vml = "urn:schemas-microsoft-com:vml"
    static let markupCompatibility = "http://schemas.openxmlformats.org/markup-compatibility/2006"
}

/// Nhận sự kiện của `LimitedXMLParser`. Tên phần tử là tên cục bộ (không tiền tố); thuộc tính giữ tên có tiền tố
/// như `XMLParser` trả về, đọc bằng `attribute(_:in:)`.
protocol XMLEventHandler: AnyObject {
    func start(_ name: String, namespace: String, attributes: [String: String])
    func end(_ name: String, namespace: String)
    func text(_ string: String)
}

/// Giá trị thuộc tính theo tên cục bộ (`w:val`, `r:embed` → `val`, `embed`), không phụ thuộc tiền tố.
func attribute(_ local: String, in attributes: [String: String]) -> String? {
    if let value = attributes[local] { return value }
    for (key, value) in attributes {
        if let colon = key.lastIndex(of: ":"), key[key.index(after: colon)...] == local { return value }
    }
    return nil
}

/// `XMLParser` có giới hạn: từ chối DTD/khai báo thực thể (chống "billion laughs" và thực thể ngoài), giới hạn độ sâu
/// lồng, kiểm huỷ task định kỳ.
enum LimitedXMLParser {
    static func parse(_ data: Data, part: String, maxDepth: Int, handler: XMLEventHandler) throws {
        // Word không ghi DTD; có DTD nghĩa là file bất thường. Từ chối trước khi libxml2 xử lý thực thể.
        if data.range(of: Data("<!DOCTYPE".utf8)) != nil || data.range(of: Data("<!ENTITY".utf8)) != nil {
            throw ImportError.invalidXML(part: part, detail: .declaresDTD)
        }
        let driver = Driver(part: part, maxDepth: maxDepth, handler: handler)
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true
        parser.shouldReportNamespacePrefixes = false
        parser.shouldResolveExternalEntities = false
        parser.delegate = driver
        let ok = parser.parse()
        if let failure = driver.failure { throw failure }
        if !ok {
            let detail = parser.parserError.map { ($0 as NSError).localizedDescription }
            throw ImportError.invalidXML(part: part, detail: .parser(detail))
        }
    }

    private final class Driver: NSObject, XMLParserDelegate {
        let part: String
        let maxDepth: Int
        let handler: XMLEventHandler
        var depth = 0
        var elementCount = 0
        var failure: Error?

        init(part: String, maxDepth: Int, handler: XMLEventHandler) {
            self.part = part
            self.maxDepth = maxDepth
            self.handler = handler
        }

        func parser(
            _ parser: XMLParser,
            didStartElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?,
            attributes attributeDict: [String: String] = [:]
        ) {
            guard failure == nil else { return }
            depth += 1
            if depth > maxDepth {
                failure = ImportError.tooDeep(part: part, limit: maxDepth)
                parser.abortParsing()
                return
            }
            elementCount += 1
            if elementCount % 2000 == 0, Task.isCancelled {
                failure = CancellationError()
                parser.abortParsing()
                return
            }
            handler.start(elementName, namespace: namespaceURI ?? "", attributes: attributeDict)
        }

        func parser(
            _ parser: XMLParser,
            didEndElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?
        ) {
            guard failure == nil else { return }
            depth -= 1
            handler.end(elementName, namespace: namespaceURI ?? "")
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            guard failure == nil else { return }
            handler.text(string)
        }

        func parser(_ parser: XMLParser, foundInternalEntityDeclarationWithName name: String, value: String?) {
            failure = ImportError.invalidXML(part: part, detail: .declaresEntity)
            parser.abortParsing()
        }

        func parser(
            _ parser: XMLParser,
            foundExternalEntityDeclarationWithName name: String,
            publicID: String?,
            systemID: String?
        ) {
            failure = ImportError.invalidXML(part: part, detail: .declaresEntity)
            parser.abortParsing()
        }
    }
}

// MARK: - Quan hệ (`*.rels`)

struct Relationship: Equatable {
    var id: String
    var type: String
    var target: String
    var isExternal: Bool
}

final class RelationshipsHandler: XMLEventHandler {
    private(set) var relationships: [String: Relationship] = [:]

    func start(_ name: String, namespace: String, attributes: [String: String]) {
        guard name == "Relationship",
              let id = attribute("Id", in: attributes),
              let target = attribute("Target", in: attributes)
        else { return }
        relationships[id] = Relationship(
            id: id,
            type: attribute("Type", in: attributes) ?? "",
            target: target,
            isExternal: attribute("TargetMode", in: attributes) == "External"
        )
    }

    func end(_ name: String, namespace: String) {}
    func text(_ string: String) {}
}

// MARK: - Đánh số (`numbering.xml`)

/// Kiểu đánh số của từng danh sách (`w:num` → `w:abstractNum` → `w:lvl`), kể cả `w:lvlOverride`.
struct NumberingDefinitions {
    struct Level: Equatable {
        /// `w:numFmt` (`upperLetter`, `decimal`, `bullet`…).
        var format: String
        var start: Int
    }

    fileprivate var abstractLevels: [String: [Int: Level]] = [:]
    fileprivate var numAbstract: [Int: String] = [:]
    fileprivate var overrides: [Int: [Int: Level]] = [:]
    fileprivate var startOverrides: [Int: [Int: Int]] = [:]
    /// Số giá trị `w:start`/`w:startOverride` ngoài `startRange` (bỏ qua, coi như không có).
    fileprivate(set) var invalidStartCount = 0

    /// Khoảng số bắt đầu hợp lệ của danh sách (giới hạn của Word); ngoài khoảng thì bỏ qua để không tràn số khi đếm.
    static let startRange = 0 ... 32767

    /// Số bắt đầu đọc được và nằm trong `startRange`; `nil` (và tăng `invalidStartCount`) nếu không.
    fileprivate mutating func start(_ raw: String?) -> Int? {
        guard let raw else { return nil }
        if raw.count <= 6, let value = Int(raw), Self.startRange.contains(value) { return value }
        invalidStartCount += 1
        return nil
    }

    static let empty = NumberingDefinitions()

    func level(numID: Int, ilvl: Int) -> Level? {
        var level = overrides[numID]?[ilvl]
            ?? numAbstract[numID].flatMap { abstractLevels[$0]?[ilvl] }
        if let start = startOverrides[numID]?[ilvl] { level?.start = start }
        return level
    }
}

final class NumberingHandler: XMLEventHandler {
    private(set) var definitions = NumberingDefinitions()

    private var abstractID: String?
    private var numID: Int?
    private var overrideLevel: Int?
    private var level: Int?
    private var levelFormat = "decimal"
    private var levelStart = 1

    func start(_ name: String, namespace: String, attributes: [String: String]) {
        guard OOXMLNamespace.word.contains(namespace) else { return }
        let value = attribute("val", in: attributes)
        switch name {
        case "abstractNum":
            abstractID = attribute("abstractNumId", in: attributes)
        case "num":
            numID = attribute("numId", in: attributes).flatMap { Int($0) }
        case "abstractNumId":
            if let numID, let value { definitions.numAbstract[numID] = value }
        case "lvlOverride":
            overrideLevel = attribute("ilvl", in: attributes).flatMap { Int($0) }
        case "startOverride":
            if let numID, let overrideLevel, let start = definitions.start(value) {
                definitions.startOverrides[numID, default: [:]][overrideLevel] = start
            }
        case "lvl":
            level = attribute("ilvl", in: attributes).flatMap { Int($0) }
            levelFormat = "decimal"
            levelStart = 1
        case "numFmt":
            if level != nil, let value { levelFormat = value }
        case "start":
            if level != nil, let start = definitions.start(value) { levelStart = start }
        default:
            break
        }
    }

    func end(_ name: String, namespace: String) {
        guard OOXMLNamespace.word.contains(namespace) else { return }
        switch name {
        case "lvl":
            guard let level else { break }
            let definition = NumberingDefinitions.Level(format: levelFormat, start: levelStart)
            if let numID, let overrideLevel, overrideLevel == level {
                definitions.overrides[numID, default: [:]][level] = definition
            } else if let abstractID {
                definitions.abstractLevels[abstractID, default: [:]][level] = definition
            }
            self.level = nil
        case "lvlOverride":
            overrideLevel = nil
        case "abstractNum":
            abstractID = nil
        case "num":
            numID = nil
        default:
            break
        }
    }

    func text(_ string: String) {}
}

// MARK: - Nội dung (`document.xml`)

/// Một đoạn chữ cùng định dạng.
struct DocxRun: Equatable {
    var text: String
    var bold: Bool
    var italic: Bool
}

/// Khối cấp thân văn bản: đoạn hoặc bảng, theo thứ tự trong tài liệu.
struct DocxBlock: Equatable {
    enum Content: Equatable {
        /// Đoạn: các dòng (tách ở ngắt dòng `w:br`), danh sách nếu có (`numId`, `ilvl`).
        case paragraph(lines: [[DocxRun]], numID: Int?, ilvl: Int)
        /// Bảng: mỗi hàng một danh sách ô (chữ trơn).
        case table(rows: [[String]])
    }

    var content: Content
    /// Id quan hệ (`r:embed`/`r:id`) của ảnh trong khối, theo thứ tự.
    var imageRelationshipIDs: [String]
}

/// Dựng `[DocxBlock]` từ `word/document.xml`.
///
/// - Bỏ: chữ đã xoá khi theo dõi thay đổi (`w:del`, `w:moveFrom`), mã trường (`w:instrText`), lịch sử định dạng
///   (`w:pPrChange`, `w:rPrChange`), nhánh `mc:Fallback` (bản sao của `mc:Choice`).
/// - Đậm/nghiêng lấy từ `w:rPr` của run (không lấy từ kiểu đoạn).
/// - Hộp chữ (đoạn lồng trong đoạn) thành dòng mới của đoạn ngoài.
/// - Bảng: ô lấy chữ trơn của các đoạn trong ô; bảng lồng được trải phẳng vào ô ngoài.
final class DocumentHandler: XMLEventHandler {
    private(set) var blocks: [DocxBlock] = []

    private enum Tag: Equatable {
        case word(String)
        case other
    }

    private var stack: [Tag] = []
    private var skipDepth = 0

    // Đoạn đang đọc (cấp ngoài cùng).
    private var paragraphDepth = 0
    private var lines: [[DocxRun]] = [[]]
    private var images: [String] = []
    private var numID: Int?
    private var ilvl = 0
    private var inParagraphProperties = false
    private var inNumberingProperties = false

    // Run đang đọc (ngăn xếp vì hộp chữ nằm trong run).
    private struct OpenRun {
        var text = ""
        var bold = false
        var italic = false
    }

    private var runs: [OpenRun] = []
    private var inRunProperties = false
    private var inText = false

    // Bảng ngoài cùng đang đọc. Bảng nằm trong đoạn (trong hộp chữ) không tính là bảng: chữ của nó thành các dòng
    // của đoạn ngoài.
    private var tableDepth = 0
    private var tablesInsideParagraph = 0
    private var rows: [[String]] = []
    private var row: [String] = []
    private var cell: [String] = []
    private var tableImages: [String] = []

    private static let skippedWordElements: Set<String> = [
        "del", "moveFrom", "instrText", "delText", "delInstrText", "pPrChange", "rPrChange", "numberingChange",
    ]

    func start(_ name: String, namespace: String, attributes: [String: String]) {
        if skipDepth > 0 {
            skipDepth += 1
            return
        }
        let isWord = OOXMLNamespace.word.contains(namespace)
        if namespace == OOXMLNamespace.markupCompatibility, name == "Fallback" {
            skipDepth = 1
            return
        }
        if isWord, Self.skippedWordElements.contains(name) {
            skipDepth = 1
            return
        }
        let parent = stack.last
        stack.append(isWord ? .word(name) : .other)

        if OOXMLNamespace.drawing.contains(namespace), name == "blip" {
            if let id = attribute("embed", in: attributes) ?? attribute("link", in: attributes) { addImage(id) }
            return
        }
        if namespace == OOXMLNamespace.vml, name == "imagedata" {
            if let id = attribute("id", in: attributes) { addImage(id) }
            return
        }
        guard isWord else { return }

        switch name {
        case "tbl":
            if paragraphDepth > 0 || tablesInsideParagraph > 0 {
                tablesInsideParagraph += 1
            } else {
                tableDepth += 1
                if tableDepth == 1 {
                    rows = []
                    tableImages = []
                }
            }
        case "tr":
            if tableDepth == 1, tablesInsideParagraph == 0 { row = [] }
        case "tc":
            if tableDepth == 1, tablesInsideParagraph == 0 { cell = [] }
        case "p":
            paragraphDepth += 1
            if paragraphDepth == 1 {
                lines = [[]]
                images = []
                numID = nil
                ilvl = 0
            } else {
                newLine()
            }
        case "pPr":
            inParagraphProperties = paragraphDepth == 1 && parent == .word("p")
        case "numPr":
            inNumberingProperties = inParagraphProperties
        case "ilvl":
            if inNumberingProperties { ilvl = attribute("val", in: attributes).flatMap { Int($0) } ?? 0 }
        case "numId":
            if inNumberingProperties { numID = attribute("val", in: attributes).flatMap { Int($0) } }
        case "r":
            flushRunText()
            runs.append(OpenRun())
        case "rPr":
            inRunProperties = parent == .word("r")
        case "b":
            if inRunProperties, !runs.isEmpty { runs[runs.count - 1].bold = Self.isOn(attributes) }
        case "i":
            if inRunProperties, !runs.isEmpty { runs[runs.count - 1].italic = Self.isOn(attributes) }
        case "t":
            inText = parent == .word("r")
        case "tab":
            if parent == .word("r") { appendText(" ") }
        case "noBreakHyphen":
            if parent == .word("r") { appendText("-") }
        case "br", "cr":
            if parent == .word("r") {
                flushRunText()
                newLine()
            }
        default:
            break
        }
    }

    func end(_ name: String, namespace: String) {
        if skipDepth > 0 {
            skipDepth -= 1
            return
        }
        stack.removeLast()
        guard OOXMLNamespace.word.contains(namespace) else { return }
        switch name {
        case "t":
            inText = false
        case "rPr":
            inRunProperties = false
        case "r":
            flushRunText()
            if !runs.isEmpty { runs.removeLast() }
        case "numPr":
            inNumberingProperties = false
        case "pPr":
            inParagraphProperties = false
        case "p":
            paragraphDepth -= 1
            if paragraphDepth == 0 { finishParagraph() }
        case "tc":
            if tableDepth == 1, tablesInsideParagraph == 0 {
                row.append(cell.filter { !$0.isEmpty }.joined(separator: " "))
            }
        case "tr":
            if tableDepth == 1, tablesInsideParagraph == 0 { rows.append(row) }
        case "tbl":
            if tablesInsideParagraph > 0 {
                tablesInsideParagraph -= 1
            } else {
                if tableDepth == 1 {
                    blocks.append(DocxBlock(content: .table(rows: rows), imageRelationshipIDs: tableImages))
                }
                tableDepth -= 1
            }
        default:
            break
        }
    }

    func text(_ string: String) {
        if skipDepth == 0, inText { appendText(string) }
    }

    // MARK: Trợ giúp

    private static func isOn(_ attributes: [String: String]) -> Bool {
        guard let value = attribute("val", in: attributes) else { return true }
        return !["0", "false", "off", "none"].contains(value.lowercased())
    }

    private func appendText(_ string: String) {
        guard paragraphDepth > 0, !runs.isEmpty else { return }
        runs[runs.count - 1].text += string
    }

    /// Đưa chữ đã gom của run đang mở vào dòng hiện tại (giữ định dạng cho phần chữ sau đó).
    private func flushRunText() {
        guard paragraphDepth > 0, let open = runs.last, !open.text.isEmpty else { return }
        lines[lines.count - 1].append(DocxRun(text: open.text, bold: open.bold, italic: open.italic))
        runs[runs.count - 1].text = ""
    }

    private func newLine() {
        guard paragraphDepth > 0 else { return }
        if !(lines.last?.isEmpty ?? true) { lines.append([]) }
    }

    private func addImage(_ id: String) {
        if paragraphDepth > 0 {
            images.append(id)
        } else if tableDepth > 0 {
            tableImages.append(id)
        }
    }

    private func finishParagraph() {
        flushRunText()
        if tableDepth > 0 {
            let text = lines.map { $0.map(\.text).joined() }.joined(separator: " ")
            cell.append(TextNormalizer.trimWhitespace(text))
            tableImages += images
        } else {
            while lines.count > 1, lines.last?.isEmpty == true { lines.removeLast() }
            blocks.append(DocxBlock(content: .paragraph(lines: lines, numID: numID == 0 ? nil : numID, ilvl: ilvl),
                                    imageRelationshipIDs: images))
        }
        lines = [[]]
        images = []
    }
}
