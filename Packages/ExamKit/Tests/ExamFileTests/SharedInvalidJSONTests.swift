import ExamKit
import Foundation
import Testing
@testable import ExamFile

/// `fixtures/invalid-json/`: ca `exam.json` sai cú pháp hoặc sai thứ chỉ chế độ đọc nghiêm bắt (khoá trùng, dấu phẩy
/// thừa, null, độ sâu, NaN, surrogate lẻ, UTF-8 hỏng, BOM…), dùng chung với lõi Kotlin của bản Android
/// (android/core). Mỗi ca đóng gói thành `.exam` chỉ có `exam.json`, đọc `strict` và so tên lỗi, đường dẫn với
/// `expected.json`. Thêm ca thì thêm file và dòng kỳ vọng; cả hai lõi cùng phải xanh.
@Suite("ExamPackageReader: ca JSON dùng chung (fixtures/invalid-json)")
struct SharedInvalidJSONTests {
    struct Expected: Decodable {
        struct Case: Decodable {
            let error: String?
            let paths: [String]?
        }

        let cases: [String: Case]
    }

    static let directory = RepoPaths.fixtures.appendingPathComponent("invalid-json", isDirectory: true)

    /// Đọc hỏng thì trả rỗng để `expectedFileLoaded` báo đỏ thay vì crash cả bộ test.
    static let expected: [String: Expected.Case] = {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent("expected.json")),
              let doc = try? JSONDecoder().decode(Expected.self, from: data)
        else { return [:] }
        return doc.cases
    }()

    static func pack(_ name: String) throws -> Data {
        try Zip.make([("exam.json", Data(contentsOf: directory.appendingPathComponent("\(name).json")))])
    }

    /// Tên lỗi và đường dẫn theo cách ghi của `expected.json`.
    static func describe(_ error: ExamFileError) -> (name: String, paths: [String]?) {
        switch error {
        case let .duplicateJSONKeys(paths): ("duplicateJSONKeys", paths)
        case let .nullValues(paths): ("nullValues", paths)
        case let .unknownFields(paths): ("unknownFields", paths)
        case let .invalidJSON(.trailingCommas(paths)): ("trailingCommas", paths)
        case .invalidJSON(.unparsable): ("unparsable", nil)
        case .invalidJSON(.notUTF8): ("notUTF8", nil)
        case .invalidJSON(.rootNotObject): ("rootNotObject", nil)
        case .invalidJSON(.missingFormatVersion): ("missingFormatVersion", nil)
        case .invalidJSON(.formatVersionNotInteger): ("formatVersionNotInteger", nil)
        case let .invalidJSON(.invalidValue(path, _)): ("invalidValue", [path])
        case let .invalidJSON(.typeMismatch(path, _)): ("typeMismatch", [path])
        case let .invalidJSON(.valueMissing(path, _)): ("valueMissing", [path])
        case let .invalidJSON(.missingKey(path, key)): ("missingKey", [path, key])
        case .invalidVersion: ("invalidVersion", nil)
        case .tooDeep: ("tooDeep", nil)
        default: ("\(error)", nil)
        }
    }

    @Test("Đọc được expected.json; mỗi file có đúng một dòng kỳ vọng")
    func expectedFileLoaded() throws {
        #expect(Self.expected.count >= 50, "Không đọc được fixtures/invalid-json/expected.json")
        let files = try FileManager.default.contentsOfDirectory(atPath: Self.directory.path)
            .filter { $0.hasSuffix(".json") && $0 != "expected.json" }
            .map { String($0.dropLast(5)) }
        #expect(Set(files) == Set(Self.expected.keys))
    }

    @Test("Đọc nghiêm ra đúng lỗi và đường dẫn", arguments: expected.keys.sorted())
    func strictOutcome(name: String) throws {
        let expected = try #require(Self.expected[name])
        let data = try Self.pack(name)
        do {
            _ = try ExamPackageReader.read(data, mode: .strict)
            #expect(expected.error == nil, "\(name): đọc được, cần \(expected.error ?? "")")
        } catch let error as ExamFileError {
            let actual = Self.describe(error)
            #expect(actual.name == expected.error, "\(name): \(error)")
            #expect(actual.paths == expected.paths, "\(name): \(String(describing: actual.paths))")
        }
    }

    @Test("Bản Admin (lenient): khoá trùng, dấu phẩy thừa, null ở trường tuỳ chọn vẫn đọc được; hai loại sau đọc như đề gốc",
          arguments: expected.keys.sorted())
    func lenientReadsStrictOnlyProblems(name: String) throws {
        let expected = try #require(Self.expected[name])
        let kind = expected.error
        guard ["duplicateJSONKeys", "trailingCommas", "nullValues"].contains(kind) else { return }
        // null trong mảng (phần tử của trường bắt buộc) thì model cũng không giải mã được, cả ở bản Admin.
        if kind == "nullValues", expected.paths?.contains(where: { $0.hasSuffix("]") }) == true { return }
        let package = try ExamPackageReader.read(Self.pack(name), mode: .lenient)
        if kind != "duplicateJSONKeys" {
            #expect(package == (try ExamPackageReader.read(Self.pack("base"), mode: .lenient)), "\(name)")
        }
    }
}

/// `fixtures/packages/`: gói `.exam` nhị phân dùng chung với lõi Kotlin (gói do `pack_exam.py` đóng; gói có entry lạ mang
/// tên không phải UTF-8, zip tạo trên Windows). Cả hai lõi phải đọc nghiêm được hoặc từ chối đúng lỗi.
@Suite("ExamPackageReader: gói dùng chung (fixtures/packages)")
struct SharedPackageTests {
    struct Expected: Decodable {
        struct Case: Decodable {
            let error: String?
            let questions: Int?
        }

        let cases: [String: Case]
    }

    static let directory = RepoPaths.fixtures.appendingPathComponent("packages", isDirectory: true)

    static let expected: [String: Expected.Case] = {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent("expected.json")),
              let doc = try? JSONDecoder().decode(Expected.self, from: data)
        else { return [:] }
        return doc.cases
    }()

    @Test("Đọc được expected.json; mỗi gói có đúng một dòng kỳ vọng")
    func expectedFileLoaded() throws {
        #expect(!Self.expected.isEmpty, "Không đọc được fixtures/packages/expected.json")
        let files = try FileManager.default.contentsOfDirectory(atPath: Self.directory.path)
            .filter { $0.hasSuffix(".exam") }.map { String($0.dropLast(5)) }
        #expect(Set(files) == Set(Self.expected.keys))
    }

    @Test("Đọc nghiêm đúng kỳ vọng", arguments: expected.keys.sorted())
    func strictOutcome(name: String) throws {
        let expected = try #require(Self.expected[name])
        let data = try Data(contentsOf: Self.directory.appendingPathComponent("\(name).exam"))
        do {
            let package = try ExamPackageReader.read(data, mode: .strict)
            #expect(expected.error == nil, "\(name)")
            if let count = expected.questions { #expect(package.exam.questionCount == count, "\(name)") }
        } catch {
            #expect(expected.error != nil, "\(name): \(error)")
        }
    }
}
