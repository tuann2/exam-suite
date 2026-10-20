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

@Suite("ExamPackageReader: khoá trùng trong JSON")
struct DuplicateJSONKeyTests {
    static let cases: [(name: String, json: Data, paths: [String])] = [
        ("gốc", rawExam(root: #", "title": "Tên khác""#), ["title"]),
        ("gốc, formatVersion", rawExam(root: #", "formatVersion": 1"#), ["formatVersion"]),
        ("câu hỏi", rawExam(question: #", "text": "Câu khác""#), ["sections[0].questions[0].text"]),
        ("lựa chọn", rawExam(option: #", "text": "3""#), ["sections[0].questions[0].options[1].text"]),
        ("qua escape \\u", rawExam(root: #", "\u0074itle": "Tên khác""#), ["title"]),
        ("qua nhiều escape \\u", rawExam(question: #", "\u0074\u0065xt": "x", "te\u0078t": "y""#),
         ["sections[0].questions[0].text"]),
        ("nhiều chỗ, theo thứ tự file, mỗi khoá một lần",
         rawExam(root: #", "code": "A", "code": "B", "code": "C""#, question: #", "type": "single""#),
         ["sections[0].questions[0].type", "code"]),
    ]

    @Test("Strict từ chối, nêu đúng đường dẫn; lenient vẫn đọc được", arguments: cases.indices)
    func rejectsInStrict(index: Int) throws {
        let item = Self.cases[index]
        let data = try pack(item.json)
        #expect(throws: ExamFileError.duplicateJSONKeys(item.paths), "\(item.name)") {
            try ExamPackageReader.read(data, mode: .strict)
        }
        _ = try ExamPackageReader.read(data, mode: .lenient)
    }

    @Test("Bộ quét: cặp surrogate, escape trong khoá (\\\", \\/, hex hoa/thường), dấu ngoặc trong chuỗi")
    func scannerEscapes() {
        let json = #"""
        {"\ud83d\ude00": 1, "😀": 2,
         "a\"b": "}", "a\u0022b": "]",
         "x": {"k": "\\", "k": [1, {"k": 1}]},
         "list": [{"q": 1}, {"q": 2, "q": 3}, [], {"q": null}],
         "\u006A": 1, "\u006a": 2, "j": 3,
         "a\/b": 1, "a/b": 2}
        """#
        #expect(StrictJSON.duplicateKeyPaths(in: Data(json.utf8)) == ["😀", "a\"b", "x.k", "list[1].q", "j", "a/b"])
    }

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
    static let cases: [(json: Data, path: String)] = [
        (rawExam(root: #", "code": null"#), "code"),
        (rawExam(root: #", "hideAnswers": null"#), "hideAnswers"),
        (rawExam(root: #", "instructions": null"#), "instructions"),
        (rawExam(question: #", "image": null"#), "sections[0].questions[0].image"),
        (rawExam(question: #", "explanation": null"#), "sections[0].questions[0].explanation"),
    ]

    @Test("Strict từ chối null ở trường tuỳ chọn, nêu đường dẫn; lenient coi như vắng mặt",
          arguments: cases.indices)
    func optionalNull(index: Int) throws {
        let item = Self.cases[index]
        let data = try pack(item.json)
        #expect(throws: ExamFileError.nullValues([item.path])) {
            try ExamPackageReader.read(data, mode: .strict)
        }
        let lenient = try ExamPackageReader.read(data, mode: .lenient)
        let plain = try ExamPackageReader.read(pack(rawExam()), mode: .lenient)
        #expect(lenient == plain)
    }

    @Test("Nhiều null: theo thứ tự cấu trúc, trong một object xếp theo tên khoá")
    func manyNulls() throws {
        let json = rawExam(root: #", "instructions": null, "code": null"#,
                           question: #", "image": null, "explanation": null"#)
        #expect(throws: ExamFileError.nullValues([
            "code", "instructions",
            "sections[0].questions[0].explanation", "sections[0].questions[0].image",
        ])) {
            try ExamPackageReader.read(pack(json), mode: .strict)
        }
    }

    @Test("Null trong mảng và ở trường bắt buộc: strict báo nullValues trước khi giải mã")
    func nullElsewhere() throws {
        let json = Data(String(decoding: rawExam(), as: UTF8.self)
            .replacingOccurrences(of: #""correct": ["B"]"#, with: #""correct": ["B", null]"#).utf8)
        #expect(throws: ExamFileError.nullValues(["sections[0].questions[0].correct[1]"])) {
            try ExamPackageReader.read(pack(json), mode: .strict)
        }
    }

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
    /// Thay một đoạn trong JSON mẫu `rawExam()`; đoạn cần thay phải có thật.
    private static func edited(_ old: String, _ new: String) -> Data {
        let text = String(decoding: rawExam(), as: UTF8.self)
        precondition(text.contains(old), "không thấy \(old)")
        return Data(text.replacingOccurrences(of: old, with: new).utf8)
    }

    static let cases: [(name: String, json: Data, paths: [String])] = [
        ("cuối object gốc {…,}", rawExam(root: ","), [StrictJSON.rootName]),
        ("cuối object câu hỏi", rawExam(question: ","), ["sections[0].questions[0]"]),
        (#"cuối mảng correct ["B",]"#, edited(#""correct": ["B"]"#, #""correct": ["B",]"#),
         ["sections[0].questions[0].correct"]),
        ("cuối mảng options …},]", edited(#""text": "2" }"#, #""text": "2" },"#),
         ["sections[0].questions[0].options"]),
        ("nhiều chỗ, theo thứ tự dấu đóng", edited(#""correct": ["B"]"#, #""correct": ["B" , ],"#),
         ["sections[0].questions[0].correct", "sections[0].questions[0]"]),
    ]

    @Test("Strict từ chối (invalidJSON nêu đường dẫn); lenient đọc như không có dấu phẩy",
          arguments: cases.indices)
    func rejectsInStrict(index: Int) throws {
        let item = Self.cases[index]
        let data = try pack(item.json)
        #expect(throws: ExamFileError.invalidJSON(.trailingCommas(item.paths)), "\(item.name)") {
            try ExamPackageReader.read(data, mode: .strict)
        }
        let lenient = try ExamPackageReader.read(data, mode: .lenient)
        #expect(lenient == (try ExamPackageReader.read(pack(rawExam()), mode: .lenient)), "\(item.name)")
    }

    @Test("Bộ quét: dấu phẩy trong chuỗi không tính; khoảng trắng giữa dấu phẩy và dấu đóng vẫn tính")
    func scanner() {
        let lf = String(UnicodeScalar(UInt8(10)))
        let cr = String(UnicodeScalar(UInt8(13)))
        let tab = String(UnicodeScalar(UInt8(9)))
        #expect(StrictJSON.scan(Data(#"{"a": ",}", "b": [",]", 1]}"#.utf8)).trailingCommas.isEmpty)
        let spaced = #"{"a": [1,"# + lf + tab + #" ], "b": {"c": 1 ,"# + cr + lf + "}}"
        #expect(StrictJSON.scan(Data(spaced.utf8)).trailingCommas == ["a", "b"])
        #expect(StrictJSON.scan(Data(#"[[1,],{"x":[],},]"#.utf8)).trailingCommas == ["[0]", "[1]", StrictJSON.rootName])
    }

    @Test("Đề mẫu không có dấu phẩy thừa hay khoá trùng", arguments: ["kien-thuc-chung", "toi-thieu", "bien-khoang-trang"])
    func samples(name: String) throws {
        #expect(StrictJSON.scan(try RepoPaths.examJSON(name)) == StrictJSON.ScanReport())
    }
}
