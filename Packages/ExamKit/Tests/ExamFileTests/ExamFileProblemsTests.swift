@testable import ExamFile
import ExamKit
import Foundation
import Testing

/// Chi tiết có mã của `invalidJSON`, `migrationFailed`, `writeFailed` (giai đoạn 5, bước 7b): câu tiếng Việt của
/// `errorDescription` giữ đúng như khi các lỗi này còn mang chuỗi (nhật ký, script, test cũ).
@Suite("ExamFileError: chi tiết có mã, câu tiếng Việt không đổi")
struct ExamFileProblemsTests {
    @Test("invalidJSON: từng loại chi tiết ra đúng câu cũ")
    func invalidJSONMessages() {
        let cases: [(JSONProblem, String)] = [
            (.notUTF8, "exam.json phải mã hoá UTF-8."),
            (.unparsable(systemDescription: "Lỗi X"), "không phân tích được JSON (Lỗi X)."),
            (.rootNotObject, "gốc của exam.json phải là một object."),
            (.missingFormatVersion, "thiếu khoá bắt buộc \"formatVersion\"."),
            (.formatVersionNotInteger, "formatVersion phải là số nguyên."),
            (.trailingCommas([JSONProblem.rootPath, "sections[0]"]),
             "dấu phẩy thừa trước dấu đóng } hoặc ] ở <gốc>, sections[0]. Xoá dấu phẩy sau phần tử cuối."),
            (.missingKey(path: "sections[0].questions[1]", key: "text"),
             "sections[0].questions[1]: thiếu khoá bắt buộc \"text\"."),
            (.typeMismatch(path: "passPercent", expectedType: "Int"), "passPercent: sai kiểu dữ liệu, cần Int."),
            (.valueMissing(path: "title", expectedType: "String"), "title: thiếu giá trị (null), cần String."),
            (.invalidValue(path: "sections[0].questions[0].type", detail: "Không hợp lệ"),
             "sections[0].questions[0].type: giá trị không hợp lệ (Không hợp lệ)."),
            (.other("Lỗi lạ"), "Lỗi lạ"),
        ]
        for (problem, message) in cases {
            #expect(problem.logMessage == message)
            #expect(ExamFileError.invalidJSON(problem).errorDescription == "exam.json không hợp lệ: \(message)")
        }
    }

    @Test("Lỗi giải mã: đường dẫn và loại chi tiết; gốc là <gốc>")
    func decodingErrors() {
        struct Key: CodingKey {
            var stringValue: String
            var intValue: Int?
            init(_ string: String) { stringValue = string }
            init?(stringValue: String) { self.stringValue = stringValue }
            init?(intValue: Int) {
                stringValue = "\(intValue)"
                self.intValue = intValue
            }
        }
        let path: [CodingKey] = [Key("sections"), Key(intValue: 0)!, Key("title")]
        #expect(ExamPackageReader.describe(.keyNotFound(Key("text"), .init(codingPath: path, debugDescription: "")))
            == .missingKey(path: "sections[0].title", key: "text"))
        #expect(ExamPackageReader.describe(.typeMismatch(Int.self, .init(codingPath: [], debugDescription: "")))
            == .typeMismatch(path: JSONProblem.rootPath, expectedType: "Int"))
        #expect(ExamPackageReader.describe(.valueNotFound(String.self, .init(codingPath: path, debugDescription: "")))
            == .valueMissing(path: "sections[0].title", expectedType: "String"))
        #expect(ExamPackageReader.describe(.dataCorrupted(.init(codingPath: path, debugDescription: "Sai")))
            == .invalidValue(path: "sections[0].title", detail: "Sai"))
    }

    @Test("migrationFailed và writeFailed: câu cũ")
    func migrationAndWriteMessages() {
        #expect(ExamFileError.migrationFailed(from: 3, reason: .missingStep).errorDescription
            == "Không chuyển được đề từ định dạng v3 lên v4: chưa có bộ chuyển đổi v3 → v4.")
        #expect(ExamFileError.migrationFailed(from: 1, reason: .invalidResult).errorDescription
            == "Không chuyển được đề từ định dạng v1 lên v2: kết quả chuyển đổi không phải JSON hợp lệ.")
        #expect(ExamFileError.migrationFailed(from: 1, reason: .stepFailed("Boom()")).errorDescription
            == "Không chuyển được đề từ định dạng v1 lên v2: Boom()")
        let writes: [(WriteProblem, String)] = [
            (.encodingFailed("E"), "không mã hoá được exam.json (E)."),
            (.archiveUnavailable, "không lấy được dữ liệu zip trong bộ nhớ."),
            (.archiveFailed("Z"), "lỗi tạo zip (Z)."),
            (.replaceFailed(fileName: "de.exam", systemReason: "Permission denied"),
             "không thay được file de.exam (Permission denied)."),
        ]
        for (problem, message) in writes {
            #expect(ExamFileError.writeFailed(problem).errorDescription == "Không ghi được gói đề: \(message)")
        }
    }

    @Test("Ghi đè file đích không được: writeFailed(.replaceFailed) nêu tên file")
    func replaceFailedNamesFile() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("examfile-problems-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        // Đích là thư mục không rỗng: rename(2) một file lên đó thất bại.
        let target = directory.appendingPathComponent("de.exam", isDirectory: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        try Data([1]).write(to: target.appendingPathComponent("x"))
        let package = ExamPackage(exam: try ExamJSON.decode(RepoPaths.examJSON("toi-thieu")))
        do {
            try ExamPackageWriter.write(package, to: target)
            Issue.record("Mong đợi lỗi ghi")
        } catch let ExamFileError.writeFailed(.replaceFailed(fileName, reason)) {
            #expect(fileName == "de.exam")
            #expect(!reason.isEmpty)
        } catch {
            Issue.record("Mong đợi writeFailed(.replaceFailed), nhận \(error)")
        }
    }
}
