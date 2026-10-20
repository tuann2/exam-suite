import ExamKit
import Foundation
import Testing
@testable import ExamFile

@Suite("Tập khoá hợp lệ khớp schema và model")
struct ExamSchemaKeysTests {
    private func schema() throws -> [String: Any] {
        let data = try Data(contentsOf: RepoPaths.schema)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func propertyKeys(_ object: Any?) throws -> Set<String> {
        let dict = try #require(object as? [String: Any])
        let properties = try #require(dict["properties"] as? [String: Any])
        return Set(properties.keys)
    }

    @Test("Khoá ở mọi cấp trùng `properties` của schema/exam-v1.schema.json")
    func matchesSchema() throws {
        let schema = try schema()
        let defs = try #require(schema["$defs"] as? [String: Any])
        #expect(try propertyKeys(schema) == ExamSchemaKeys.exam)
        #expect(try propertyKeys(defs["section"]) == ExamSchemaKeys.section)
        #expect(try propertyKeys(defs["question"]) == ExamSchemaKeys.question)
        #expect(try propertyKeys(defs["option"]) == ExamSchemaKeys.option)
    }

    @Test("Schema cấm trường lạ ở mọi cấp (additionalProperties: false)")
    func schemaForbidsAdditionalProperties() throws {
        let schema = try schema()
        let defs = try #require(schema["$defs"] as? [String: Any])
        for object in [schema, defs["section"], defs["question"], defs["option"]] {
            let dict = try #require(object as? [String: Any])
            #expect(dict["additionalProperties"] as? Bool == false)
        }
    }

    @Test("Model ghi ra đúng các khoá này khi mọi trường tuỳ chọn có giá trị")
    func matchesModelEncoding() throws {
        let exam = Exam(
            title: "Đủ trường", code: "FULL", passPercent: 50, timeLimitMinutes: 10,
            hideAnswers: true, instructions: "Hướng dẫn",
            sections: [ExamSection(title: "S", questions: [Question(
                type: .single, text: "Câu?", image: "media/0123456789abcdef.png",
                options: [Option(id: OptionID("A")!, text: "a"), Option(id: OptionID("B")!, text: "b")],
                correct: [OptionID("A")!], explanation: "Vì vậy"
            )])]
        )
        let json = try #require(JSONSerialization.jsonObject(with: ExamJSON.encode(exam)) as? [String: Any])
        let section = try #require((json["sections"] as? [[String: Any]])?.first)
        let question = try #require((section["questions"] as? [[String: Any]])?.first)
        let option = try #require((question["options"] as? [[String: Any]])?.first)
        #expect(Set(json.keys) == ExamSchemaKeys.exam)
        #expect(Set(section.keys) == ExamSchemaKeys.section)
        #expect(Set(question.keys) == ExamSchemaKeys.question)
        #expect(Set(option.keys) == ExamSchemaKeys.option)
    }

    @Test("Đề hợp lệ không có trường lạ")
    func noUnknownInFixtures() throws {
        for name in ["toi-thieu", "kien-thuc-chung"] {
            let json = try #require(JSONSerialization.jsonObject(with: RepoPaths.examJSON(name)) as? [String: Any])
            #expect(ExamSchemaKeys.unknownFieldPaths(in: json).isEmpty)
        }
    }
}
