import ExamKit
import Foundation
import Testing
@testable import ExamFile

/// `fixtures/expected-verdicts.json` ràng buộc cả script lẫn app. `ExamValidatorParityTests`
/// (ExamKitTests) kiểm model + ExamValidator; suite này kiểm ExamFile: đóng gói từng fixture
/// thành `.exam` trong test rồi đọc ở cả hai chế độ. Đặc biệt nhãn `examfile` ("chỉ ExamFile
/// chế độ nghiêm từ chối") phải thật sự bị `strict` từ chối, nếu không nhãn đó là giả xanh.
@Suite("ExamFile: kết luận theo fixtures/expected-verdicts.json")
struct ExamFileVerdictTests {
    struct Expected: Decodable {
        let verdicts: [String: String]
    }

    /// Đọc hỏng thì trả rỗng để `verdictFileLoaded` báo đỏ thay vì crash cả bộ test.
    static let verdicts: [String: String] = {
        let url = RepoPaths.fixtures.appendingPathComponent("expected-verdicts.json")
        guard let data = try? Data(contentsOf: url),
              let doc = try? JSONDecoder().decode(Expected.self, from: data)
        else { return [:] }
        return doc.verdicts
    }()

    static func keys(_ verdict: String) -> [String] {
        verdicts.filter { $0.value == verdict }.keys.sorted()
    }

    /// Đóng gói fixture như `scripts/pack_exam.py`: `exams/<tên>` kèm `media/`, `invalid/<tên>`
    /// chỉ có `exam.json`.
    static func pack(_ key: String) throws -> Data {
        let parts = key.split(separator: "/", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { throw CocoaError(.fileReadInvalidFileName) }
        switch parts[0] {
        case "exams": return try Zip.packFixture(parts[1])
        case "invalid": return try Zip.make([("exam.json", RepoPaths.invalidJSON(parts[1]))])
        default: throw CocoaError(.fileReadInvalidFileName)
        }
    }

    private static func readError(_ data: Data, mode: ReadMode) -> (any Error)? {
        do {
            _ = try ExamPackageReader.read(data, mode: mode)
            return nil
        } catch {
            return error
        }
    }

    @Test("Đọc được file kỳ vọng; có đủ các nhóm, gồm các fixture examfile đã biết")
    func verdictFileLoaded() {
        #expect(!Self.verdicts.isEmpty, "Không đọc được fixtures/expected-verdicts.json")
        #expect(Set(Self.keys("examfile")).isSuperset(of: [
            "invalid/future-version", "invalid/unknown-question-field", "invalid/unknown-top-level-field",
        ]))
        #expect(!Self.keys("valid").isEmpty && !Self.keys("error").isEmpty && !Self.keys("undecodable").isEmpty)
    }

    @Test("examfile: strict từ chối; lenient đọc được trường lạ, lỗi phiên bản thì cả hai cùng từ chối",
          arguments: keys("examfile"))
    func examfileRejectedByStrict(key: String) throws {
        let data = try Self.pack(key)
        let strictError = Self.readError(data, mode: .strict)
        #expect(strictError != nil, "\(key): nhãn examfile nhưng strict đọc được")
        let fileError = try #require(strictError as? ExamFileError, "\(key): \(String(describing: strictError))")

        let lenientError = Self.readError(data, mode: .lenient)
        switch fileError {
        case .unknownFields, .duplicateJSONKeys, .nullValues, .invalidJSON:
            // Lỗi chỉ có ở strict: bản Admin bỏ qua trường lạ (exam-format.md, mục Trường lạ),
            // khoá trùng, null và dấu phẩy thừa (invalidJSON: model đã giải mã được theo
            // định nghĩa nhãn examfile, nên invalidJSON ở đây chỉ có thể là dấu phẩy thừa).
            #expect(lenientError == nil, "\(key): lenient phải đọc được, lỗi \(String(describing: lenientError))")
        case .unsupportedVersion, .invalidVersion:
            #expect(lenientError as? ExamFileError == fileError, "\(key)")
        default:
            Issue.record("\(key): nhãn examfile nhưng strict từ chối vì lỗi không thuộc nhóm của ExamFile: \(fileError)")
        }
    }

    @Test("valid: strict đọc được, không có error", arguments: keys("valid"))
    func validReadByStrict(key: String) throws {
        let package = try ExamPackageReader.read(Self.pack(key), mode: .strict)
        #expect(!package.validationIssues.hasErrors, "\(key): \(package.validationIssues.map(\.message))")
    }

    @Test("error: strict từ chối; lenient đọc được và validationIssues có error", arguments: keys("error"))
    func errorRejectedByStrict(key: String) throws {
        let data = try Self.pack(key)
        #expect(Self.readError(data, mode: .strict) is ExamFileError, "\(key): strict phải từ chối")
        let package = try ExamPackageReader.read(data, mode: .lenient)
        #expect(package.validationIssues.hasErrors, "\(key)")
    }

    @Test("undecodable: cả hai chế độ báo invalidJSON", arguments: keys("undecodable"))
    func undecodableRejected(key: String) throws {
        let data = try Self.pack(key)
        for mode in [ReadMode.strict, .lenient] {
            let error = Self.readError(data, mode: mode)
            guard case .invalidJSON? = error as? ExamFileError else {
                Issue.record("\(key) (\(mode)): cần invalidJSON, nhận \(String(describing: error))")
                continue
            }
        }
    }
}
