import ExamKit
import Foundation
import Testing
@testable import ExamFile

/// JSON thô dựng trong test (không dùng fixtures/invalid): đề tối thiểu một section, một
/// câu, hai lựa chọn; mỗi `extra…` là đoạn JSON chèn thêm vào cuối object tương ứng,
/// bắt đầu bằng dấu phẩy.
private func rawExam(root: String = "", question: String = "", option: String = "") -> Data {
    Data("""
    {
      "formatVersion": 1,
      "id": "11111111-2222-4333-8444-555555555555",
      "title": "Đề {thử} [\\"khoá\\"]",
      "passPercent": 50,
      "timeLimitMinutes": 5,
      "sections": [
        {
          "id": "22222222-3333-4444-8555-666666666666",
          "title": "Một section",
          "questions": [
            {
              "id": "33333333-4444-4555-8666-777777777777",
              "type": "single",
              "text": "1 + 1 = ? \\\\ \\" , } ]",
              "options": [
                { "id": "A", "text": "1" },
                { "id": "B", "text": "2"\(option) }
              ],
              "correct": ["B"]\(question)
            }
          ]
        }
      ]\(root)
    }
    """.utf8)
}

private func pack(_ json: Data) throws -> Data {
    try Zip.make([("exam.json", json)])
}

// Ca đọc nghiêm (khoá trùng kể cả qua escape và lồng nhau, null, dấu phẩy thừa kể cả có khoảng trắng) nằm ở
// fixtures/invalid-json, dùng chung với lõi Kotlin (SharedInvalidJSONTests). Ở đây chỉ còn test riêng của Swift.
@Suite("ExamPackageReader: khoá trùng trong JSON")
struct DuplicateJSONKeyTests {
    @Test("Không báo nhầm: đề mẫu và cùng khoá ở các object khác nhau", arguments: ["kien-thuc-chung", "toi-thieu"])
    func noFalsePositives(name: String) throws {
        #expect(StrictJSON.duplicateKeyPaths(in: try RepoPaths.examJSON(name)).isEmpty)
        #expect(StrictJSON.duplicateKeyPaths(in: rawExam()).isEmpty)
        _ = try ExamPackageReader.read(pack(rawExam()), mode: .strict)
    }

    @Test("JSON cụt không làm bộ quét crash")
    func truncatedInput() {
        let json = Data(#"{"a": 1, "a": "\u00"#.utf8)
        #expect(StrictJSON.duplicateKeyPaths(in: json) == ["a"])
        #expect(StrictJSON.duplicateKeyPaths(in: Data(#"{"a\"#.utf8)).isEmpty)
    }
}

@Suite("ExamPackageReader: giá trị null")
struct NullValueTests {
    @Test("Đề mẫu không có null")
    func samplesHaveNoNull() throws {
        for name in ["kien-thuc-chung", "toi-thieu"] {
            let object = try #require(JSONSerialization.jsonObject(with: RepoPaths.examJSON(name)) as? [String: Any])
            #expect(StrictJSON.nullValuePaths(in: object).isEmpty)
        }
    }

    @Test("errorDescription tiếng Việt nêu đường dẫn")
    func descriptions() {
        let dup = ExamFileError.duplicateJSONKeys(["title", "sections[0].title"]).errorDescription ?? ""
        #expect(dup.contains("title, sections[0].title"))
        #expect(dup.contains("lặp"))
        let null = ExamFileError.nullValues(["code"]).errorDescription ?? ""
        #expect(null.contains("null"))
        #expect(null.contains("code"))
    }
}

@Suite("ExamPackageReader: dấu phẩy thừa")
struct TrailingCommaTests {
    @Test("Đề mẫu không có dấu phẩy thừa hay khoá trùng", arguments: ["kien-thuc-chung", "toi-thieu", "bien-khoang-trang"])
    func samples(name: String) throws {
        #expect(StrictJSON.scan(try RepoPaths.examJSON(name)) == StrictJSON.ScanReport())
    }
}
