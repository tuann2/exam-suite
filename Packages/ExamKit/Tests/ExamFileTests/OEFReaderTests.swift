import ExamKit
import Foundation
import Testing
@testable import ExamFile

/// Bộ đọc `.oef` theo oracle chung `fixtures/oef/expected.json` (lõi Kotlin đọc cùng file) và các vector của nó
/// (docs/product/exam-format.md, mục File `.oef`).
@Suite("ExamFile: đọc .oef theo fixtures/oef/expected.json")
struct OEFReaderTests {
    static let directory = RepoPaths.fixtures.appendingPathComponent("oef", isDirectory: true)

    nonisolated(unsafe) static let oracle: [String: Any] = {
        let data = try! Data(contentsOf: directory.appendingPathComponent("expected.json"))
        return try! JSONSerialization.jsonObject(with: data) as! [String: Any]
    }()

    static var files: [String: [String: Any]] { oracle["files"] as! [String: [String: Any]] }
    static var vectors: [String: Any] { oracle["vectors"] as! [String: Any] }
    static func names() -> [String] { files.keys.sorted() }

    static func fixture(_ name: String) throws -> Data {
        try Data(contentsOf: directory.appendingPathComponent("\(name).oef"))
    }

    @Test("Mọi file .oef trong fixtures/oef có dòng trong expected.json và ngược lại")
    func everyFixtureHasExpectation() throws {
        let onDisk = try FileManager.default.contentsOfDirectory(atPath: Self.directory.path)
            .filter { $0.hasSuffix(".oef") }.map { String($0.dropLast(4)) }
        #expect(Set(onDisk) == Set(Self.names()))
        #expect(Self.names().count >= 32)
    }

    @Test("Đọc nghiêm: đề đã chuyển hoặc mã lỗi như oracle", arguments: names())
    func strict(_ name: String) throws {
        let expected = Self.files[name]!["strict"] as! [String: Any]
        let outcome = Result { try OEFReader.convert(Self.fixture(name), mode: .strict) }
        if let error = expected["error"] as? String {
            #expect(Self.code(outcome) == error)
            return
        }
        let conversion = try outcome.get()
        let examData = try JSONSerialization.data(withJSONObject: expected["exam"]!)
        #expect(conversion.package.exam == (try ExamJSON.decode(examData)))
        #expect(Set(conversion.package.media.keys) == Set(expected["media"] as! [String]))
        for (path, data) in conversion.package.media {
            #expect(path.hasPrefix("media/\(SHA256.hexDigest(data).prefix(16))."), "\(path)")
        }
        #expect(conversion.notes.isEmpty)
    }

    @Test("Đọc dễ: ghi chú, giá trị điền sẵn và câu như oracle", arguments: names())
    func lenient(_ name: String) throws {
        let expected = Self.files[name]!["lenient"] as! [String: Any]
        let outcome = Result { try OEFReader.convert(Self.fixture(name), mode: .lenient) }
        if let error = expected["error"] as? String {
            #expect(Self.code(outcome) == error)
            return
        }
        let conversion = try outcome.get()
        #expect(conversion.notes.map(Self.code) == expected["notes"] as! [String])
        if let strict = try? OEFReader.convert(Self.fixture(name), mode: .strict) {
            #expect(conversion.package == strict.package)
            #expect(conversion.passPercent == strict.package.exam.passPercent)
            return
        }
        #expect(conversion.passPercent == expected["passPercent"] as? Int)
        #expect(conversion.timeLimitMinutes == expected["timeLimitMinutes"] as? Int)
        let questions = conversion.package.exam.allQuestions.map { question -> [String: Any] in
            ["correct": question.correct.map(\.description).joined(separator: ","),
             "options": question.options.count, "image": question.image != nil]
        }
        let expectedQuestions = expected["questions"] as! [[String: Any]]
        #expect(questions.count == expectedQuestions.count)
        for (actual, wanted) in zip(questions, expectedQuestions) {
            #expect(actual["correct"] as! String == wanted["correct"] as! String)
            #expect(actual["options"] as! Int == wanted["options"] as! Int)
            #expect(actual["image"] as! Bool == wanted["image"] as! Bool)
        }
        if let zText = expected["zText"] as? String {
            #expect(conversion.package.exam.allQuestions.first?.options.last?.text == zText)
        }
    }

    // MARK: - Vector

    @Test("Id dẫn xuất: UUID phiên bản 8 từ SHA-256")
    func derivedIDs() {
        for vector in Self.vectors["ids"] as! [[String: String]] {
            #expect(OEFReader.derivedID(vector["name"]!).uuidString.lowercased() == vector["uuid"]!)
        }
        let id = OEFReader.derivedID("x").uuidString
        #expect(Array(id)[14] == "8", "phiên bản 8")
        #expect("89AB".contains(Array(id)[19]), "biến thể RFC 9562")
    }

    @Test("Chữ trơn → Markdown: NFC, cắt khoảng trắng, thoát ký hiệu")
    func markdownVectors() {
        for vector in Self.vectors["markdown"] as! [[String: String]] {
            #expect(OEFReader.markdown(vector["plain"]!) == vector["markdown"]!)
        }
    }

    @Test("Ngưỡng đậu thang 1000 → phần trăm, nửa lên")
    func passmarkVectors() {
        for pair in Self.vectors["passmark"] as! [[Double]] {
            #expect(OEFReader.passPercent(fromPassmark: pair[0]) == Int(pair[1]), "\(pair[0])")
        }
        for value in Self.vectors["passmarkOutOfRange"] as! [Double] {
            #expect(OEFReader.passPercent(fromPassmark: value) == nil, "\(value)")
        }
        #expect(OEFReader.passPercent(fromPassmark: .nan) == nil)
        #expect(OEFReader.passPercent(fromPassmark: .infinity) == nil)
    }

    @Test("Loại ảnh theo byte đầu")
    func imageKinds() {
        for vector in Self.vectors["imageKinds"] as! [[String: Any]] {
            let head = Self.bytes(hex: vector["head"] as! String)
            #expect(OEFReader.imageExtension(head) == vector["ext"] as? String, "\(vector["head"]!)")
        }
    }

    @Test("Tên chữ cái trong câu báo")
    func letterNames() {
        for pair in Self.vectors["letters"] as! [[Any]] {
            #expect(OEFReader.letterName(UInt64(pair[0] as! Int)) == pair[1] as! String)
        }
    }

    // MARK: - Ngoài oracle

    @Test("ExamSourceReader chọn bộ đọc theo đuôi; .oef đọc qua file như qua dữ liệu")
    func sourceReaderDispatch() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("OEFReaderTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let data = try Self.fixture("co-ban")
        let oef = directory.appendingPathComponent("de.OEF")
        try data.write(to: oef)
        #expect(ExamSourceReader.isOEF(oef))
        #expect(try ExamSourceReader.read(contentsOf: oef, mode: .strict)
            == OEFReader.convert(data, mode: .strict).package)
        // Cùng byte mà đuôi .exam thì đọc như gói zip: không phải zip.
        let exam = directory.appendingPathComponent("de.exam")
        try data.write(to: exam)
        #expect(throws: ExamFileError.notAZipArchive) { try ExamSourceReader.read(contentsOf: exam, mode: .strict) }
    }

    @Test("Đọc lại cùng file ra cùng đề (id không ngẫu nhiên)")
    func deterministic() throws {
        let data = try Self.fixture("co-ban")
        #expect(try OEFReader.convert(data, mode: .strict) == OEFReader.convert(data, mode: .strict))
    }

    // MARK: - Mã cho oracle

    static func code(_ outcome: Result<OEFReader.Conversion, any Error>) -> String {
        switch outcome {
        case .success: return "ok"
        case let .failure(error): return code(error)
        }
    }

    static func code(_ error: any Error) -> String {
        switch error as? ExamFileError {
        case let .oef(problem)?: return "oef." + code(problem)
        case let .validationFailed(issues)?: return "validationFailed:" + issues.map(\.code.rawValue).joined(separator: ",")
        default: return "\(error)"
        }
    }

    static func code(_ problem: OEFProblem) -> String {
        switch problem {
        case .legacyFormat: "legacyFormat"
        case let .malformed(offset): "malformed:\(offset)"
        case .noQuestions: "noQuestions"
        case let .tooLarge(limit, value): "tooLarge:\(limit.rawValue):\(value)"
        case let .imageTooLarge(place, limit): "imageTooLarge:\(place.oracle):\(limit)"
        case let .unknownFields(paths): "unknownFields:" + paths.joined(separator: ",")
        case .passmarkOutOfRange: "passmarkOutOfRange"
        case let .unsupportedImage(place): "unsupportedImage:\(place.oracle)"
        case let .tooManyOptions(place, count): "tooManyOptions:\(place.oracle):\(count)"
        case let .duplicateOptionLetter(place, letter): "duplicateOptionLetter:\(place.oracle):\(letter)"
        case let .answerNotInOptions(place, letters): "answerNotInOptions:\(place.oracle):" + letters.joined(separator: ",")
        }
    }

    static func code(_ note: OEFNote) -> String {
        switch note {
        case let .unknownField(path): "unknownField:\(path)"
        case let .invalidCode(code): "invalidCode:\(code)"
        case .passmarkOutOfRange: "passmarkOutOfRange"
        case let .timeLimitOutOfRange(value): "timeLimitOutOfRange:\(value)"
        case let .emptySection(section): "emptySection:\(section)"
        case let .untitledSection(section): "untitledSection:\(section)"
        case let .noOptions(place): "noOptions:\(place.oracle)"
        case let .tooManyOptions(place, count): "tooManyOptions:\(place.oracle):\(count)"
        case let .duplicateOptionLetter(place, letter): "duplicateOptionLetter:\(place.oracle):\(letter)"
        case let .answerNotInOptions(place, letters): "answerNotInOptions:\(place.oracle):" + letters.joined(separator: ",")
        case let .unsupportedImage(place): "unsupportedImage:\(place.oracle)"
        case let .imageTooLarge(place, limit): "imageTooLarge:\(place.oracle):\(limit)"
        }
    }

    static func bytes(hex: String) -> Data {
        var data = Data()
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            data.append(UInt8(hex[index ..< next], radix: 16)!)
            index = next
        }
        return data
    }
}

extension OEFPlace {
    var oracle: String { "\(section)/\(question)" }
}
