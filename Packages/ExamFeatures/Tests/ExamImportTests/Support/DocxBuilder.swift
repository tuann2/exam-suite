import Foundation
import ZIPFoundation

/// Dựng file `.docx` tối thiểu trong test (nội dung tự soạn, không dùng file thật): `[Content_Types].xml`,
/// `_rels/.rels`, `word/document.xml`, `word/_rels/document.xml.rels`, `word/numbering.xml`, ảnh trong `word/media/`.
struct DocxBuilder {
    static let wordNamespace = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"

    /// Các khối XML trong `w:body`.
    var body: [String] = []
    /// `nil` = không có `numbering.xml`.
    var numbering: String? = DocxBuilder.defaultNumbering
    var relationships: [(id: String, type: String, target: String, external: Bool)] = []
    var files: [String: Data] = [:]
    /// Ghi `document.xml` không nén (để test sửa byte).
    var storeUncompressed = false
    /// Thay toàn bộ `document.xml`.
    var documentOverride: String?
    /// Thay toàn bộ `document.xml` bằng byte (ví dụ XML UTF-16).
    var documentBytes: Data?
    /// Target của quan hệ officeDocument trong `_rels/.rels`.
    var mainDocumentTarget = "word/document.xml"

    /// numId 1, 4: chữ in hoa (lựa chọn); 2: gạch đầu dòng; 3: số; 5: cấp 0 số, cấp 1 chữ in hoa.
    static let defaultNumbering = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <w:numbering xmlns:w="\(wordNamespace)">
    <w:abstractNum w:abstractNumId="10"><w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="upperLetter"/><w:lvlText w:val="%1."/></w:lvl></w:abstractNum>
    <w:abstractNum w:abstractNumId="11"><w:lvl w:ilvl="0"><w:numFmt w:val="bullet"/><w:lvlText w:val="•"/></w:lvl><w:lvl w:ilvl="1"><w:numFmt w:val="bullet"/></w:lvl></w:abstractNum>
    <w:abstractNum w:abstractNumId="12"><w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="decimal"/><w:lvlText w:val="%1."/></w:lvl></w:abstractNum>
    <w:abstractNum w:abstractNumId="13"><w:lvl w:ilvl="0"><w:numFmt w:val="decimal"/></w:lvl><w:lvl w:ilvl="1"><w:numFmt w:val="upperLetter"/></w:lvl></w:abstractNum>
    <w:num w:numId="1"><w:abstractNumId w:val="10"/></w:num>
    <w:num w:numId="2"><w:abstractNumId w:val="11"/></w:num>
    <w:num w:numId="3"><w:abstractNumId w:val="12"/></w:num>
    <w:num w:numId="4"><w:abstractNumId w:val="10"/></w:num>
    <w:num w:numId="5"><w:abstractNumId w:val="13"/></w:num>
    </w:numbering>
    """

    // MARK: Khối

    mutating func paragraph(_ text: String, style: String? = nil) {
        body.append(Self.p(runs: [Self.run(text)], style: style))
    }

    mutating func paragraphs(_ texts: String...) {
        for text in texts { paragraph(text) }
    }

    mutating func runs(_ runs: String...) {
        body.append(Self.p(runs: runs))
    }

    mutating func listItem(_ text: String, numID: Int, level: Int = 0) {
        body.append(Self.p(runs: [Self.run(text)], numID: numID, level: level))
    }

    mutating func raw(_ xml: String) {
        body.append(xml)
    }

    mutating func table(_ rows: [[String]]) {
        let rowsXML = rows.map { row in
            "<w:tr>" + row.map { "<w:tc><w:p><w:r><w:t>\(Self.escape($0))</w:t></w:r></w:p></w:tc>" }.joined() + "</w:tr>"
        }.joined()
        body.append("<w:tbl>\(rowsXML)</w:tbl>")
    }

    /// Đoạn chứa ảnh (DrawingML) với id quan hệ `rID`, kèm chữ tuỳ chọn.
    mutating func imageParagraph(_ rID: String, text: String = "") {
        let drawing = """
        <w:r><w:drawing><wp:inline xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing">\
        <a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><a:graphicData>\
        <pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"><pic:blipFill>\
        <a:blip r:embed="\(rID)"/></pic:blipFill></pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing></w:r>
        """
        body.append("<w:p>\(text.isEmpty ? "" : Self.run(text))\(drawing)</w:p>")
    }

    /// Thêm ảnh `word/media/<name>` và quan hệ `rID`.
    mutating func addImage(_ rID: String, name: String, data: Data) {
        files["word/media/\(name)"] = data
        relationships.append((rID, "http://schemas.openxmlformats.org/officeDocument/2006/relationships/image",
                              "media/\(name)", false))
    }

    // MARK: XML

    static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    static func run(_ text: String, bold: Bool = false, italic: Bool = false) -> String {
        var props = ""
        if bold { props += "<w:b/>" }
        if italic { props += "<w:i/>" }
        let rPr = props.isEmpty ? "" : "<w:rPr>\(props)</w:rPr>"
        return "<w:r>\(rPr)<w:t xml:space=\"preserve\">\(escape(text))</w:t></w:r>"
    }

    static func p(runs: [String], style: String? = nil, numID: Int? = nil, level: Int = 0) -> String {
        var pPr = ""
        if let style { pPr += "<w:pStyle w:val=\"\(style)\"/>" }
        if let numID { pPr += "<w:numPr><w:ilvl w:val=\"\(level)\"/><w:numId w:val=\"\(numID)\"/></w:numPr>" }
        return "<w:p>\(pPr.isEmpty ? "" : "<w:pPr>\(pPr)</w:pPr>")\(runs.joined())</w:p>"
    }

    var documentXML: String {
        documentOverride ?? """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="\(Self.wordNamespace)" \
        xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" \
        xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" \
        xmlns:v="urn:schemas-microsoft-com:vml"><w:body>\(body.joined())<w:sectPr/></w:body></w:document>
        """
    }

    // MARK: Zip

    func data() throws -> Data {
        var rels = relationships
        if numbering != nil {
            rels.append(("rIdNumbering", "http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering",
                         "numbering.xml", false))
        }
        let relsXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\
        \(rels.map { "<Relationship Id=\"\($0.id)\" Type=\"\($0.type)\" Target=\"\(Self.escape($0.target))\"\($0.external ? " TargetMode=\"External\"" : "")/>" }.joined())\
        </Relationships>
        """
        var parts: [(String, Data)] = [
            ("[Content_Types].xml", Data("""
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">\
            <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>\
            <Default Extension="xml" ContentType="application/xml"/></Types>
            """.utf8)),
            ("_rels/.rels", Data("""
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\
            <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="\(Self.escape(mainDocumentTarget))"/>\
            </Relationships>
            """.utf8)),
            ("word/document.xml", documentBytes ?? Data(documentXML.utf8)),
            ("word/_rels/document.xml.rels", Data(relsXML.utf8)),
        ]
        if let numbering { parts.append(("word/numbering.xml", Data(numbering.utf8))) }
        for (path, data) in files.sorted(by: { $0.key < $1.key }) { parts.append((path, data)) }
        return try Self.zip(parts, storedPaths: storeUncompressed ? ["word/document.xml"] : [])
    }

    static func zip(_ parts: [(String, Data)], storedPaths: Set<String> = []) throws -> Data {
        let archive = try Archive(data: Data(), accessMode: .create)
        for (path, data) in parts {
            try archive.addEntry(
                with: path,
                type: .file,
                uncompressedSize: Int64(data.count),
                compressionMethod: storedPaths.contains(path) ? .none : .deflate,
                provider: { position, size in data.subdata(in: Int(position) ..< Int(position) + size) }
            )
        }
        guard let data = archive.data else { throw CocoaError(.fileWriteUnknown) }
        return data
    }
}

/// Sửa byte của zip để giả file hỏng.
enum ZipPatcher {
    /// Đổi trường "kích thước giải nén" của entry `path` (cả local header và central directory) thành `size`.
    static func setUncompressedSize(of path: String, to size: UInt32, in data: Data) -> Data {
        var bytes = [UInt8](data)
        let name = [UInt8](path.utf8)
        for offset in 0 ..< max(0, bytes.count - 46) {
            if matches(bytes, offset, [0x50, 0x4B, 0x03, 0x04]), nameAt(bytes, offset + 30, length(bytes, offset + 26)) == name {
                write(size, into: &bytes, at: offset + 22)
            }
            if matches(bytes, offset, [0x50, 0x4B, 0x01, 0x02]), nameAt(bytes, offset + 46, length(bytes, offset + 28)) == name {
                write(size, into: &bytes, at: offset + 24)
            }
        }
        return Data(bytes)
    }

    /// Đổi một byte dữ liệu (không nén) của entry `path`: CRC không còn khớp.
    static func corruptStoredContent(of path: String, in data: Data) -> Data {
        var bytes = [UInt8](data)
        let name = [UInt8](path.utf8)
        for offset in 0 ..< max(0, bytes.count - 30) where matches(bytes, offset, [0x50, 0x4B, 0x03, 0x04]) {
            let nameLength = length(bytes, offset + 26)
            guard nameAt(bytes, offset + 30, nameLength) == name else { continue }
            let extraLength = length(bytes, offset + 28)
            let content = offset + 30 + nameLength + extraLength + 60
            bytes[content] ^= 0xFF
            break
        }
        return Data(bytes)
    }

    private static func matches(_ bytes: [UInt8], _ offset: Int, _ signature: [UInt8]) -> Bool {
        Array(bytes[offset ..< offset + 4]) == signature
    }

    private static func length(_ bytes: [UInt8], _ offset: Int) -> Int {
        Int(bytes[offset]) | Int(bytes[offset + 1]) << 8
    }

    private static func nameAt(_ bytes: [UInt8], _ offset: Int, _ length: Int) -> [UInt8] {
        guard offset + length <= bytes.count else { return [] }
        return Array(bytes[offset ..< offset + length])
    }

    private static func write(_ value: UInt32, into bytes: inout [UInt8], at offset: Int) {
        for i in 0 ..< 4 { bytes[offset + i] = UInt8(truncatingIfNeeded: value >> (8 * UInt32(i))) }
    }
}
