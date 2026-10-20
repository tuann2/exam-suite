import Foundation
import Testing
@testable import ExamKit

@Suite("Exam model: giải mã fixture, ghi lại không mất dữ liệu")
struct ExamModelTests {
    @Test("Giải mã đề mẫu kien-thuc-chung đúng cấu trúc")
    func decodesSampleExam() throws {
        let exam = try ExamJSON.decode(Fixtures.data(Fixtures.exam("kien-thuc-chung")))
        #expect(exam.formatVersion == 1)
        #expect(exam.id == UUID(uuidString: "0b6c1f8e-4d2a-4c1b-9f3e-2a7d5e8c1b40"))
        #expect(exam.title == "Kiến thức chung")
        #expect(exam.code == "KTC01")
        #expect(exam.passPercent == 70)
        #expect(exam.timeLimitMinutes == 30)
        #expect(exam.hideAnswers == false)
        #expect(exam.sections.map(\.title) == ["Vật lý", "Toán"])
        #expect(exam.questionCount == 5)

        let q1 = exam.sections[0].questions[0]
        #expect(q1.type == .single)
        #expect(q1.image == "media/9d5dc894e10f060d.png")
        #expect(q1.options.map(\.id.description) == ["A", "B", "C", "D"])
        #expect(q1.correct == [OptionID("B")!])
        #expect(q1.explanation?.hasPrefix("Ampe") == true)

        let q2 = exam.sections[0].questions[1]
        #expect(q2.type == .multiple)
        #expect(q2.correctSet == [OptionID("A")!, OptionID("C")!])

        let q3 = exam.sections[0].questions[2]
        #expect(q3.explanation == nil)
        #expect(q3.image == nil)
    }

    @Test("hideAnswers vắng mặt → false; code và instructions tuỳ chọn")
    func optionalFieldsDefault() throws {
        let exam = try ExamJSON.decode(Fixtures.data(Fixtures.exam("toi-thieu")))
        #expect(exam.hideAnswers == false)
        #expect(exam.code == nil)
        #expect(exam.instructions == nil)
        #expect(exam.questionCount == 1)
    }

    @Test("Ghi rồi đọc lại ra cùng dữ liệu", arguments: ["kien-thuc-chung", "toi-thieu"])
    func roundTrip(fixture: String) throws {
        let original = try ExamJSON.decode(Fixtures.data(Fixtures.exam(fixture)))
        let reencoded = try ExamJSON.encode(original)
        let again = try ExamJSON.decode(reencoded)
        #expect(again == original)
    }

    @Test("JSON ghi ra giữ nguyên mọi trường của fixture (so sánh ngữ nghĩa)", arguments: ["kien-thuc-chung", "toi-thieu"])
    func reencodedJSONMatchesFixture(fixture: String) throws {
        let source = try Fixtures.data(Fixtures.exam(fixture))
        let exam = try ExamJSON.decode(source)
        var expected = try JSONSerialization.jsonObject(with: source) as! [String: Any]
        // hideAnswers vắng mặt trong fixture tối thiểu; model luôn ghi ra giá trị tường minh.
        if expected["hideAnswers"] == nil { expected["hideAnswers"] = false }
        let actual = try JSONSerialization.jsonObject(with: ExamJSON.encode(exam)) as! [String: Any]
        #expect(JSONCompare.equal(actual, expected))
    }

    @Test("UUID ghi ra là chữ thường, khoá sắp xếp, không escape dấu /")
    func encodingStyle() throws {
        let exam = try ExamJSON.decode(Fixtures.data(Fixtures.exam("kien-thuc-chung")))
        let text = String(decoding: try ExamJSON.encode(exam), as: UTF8.self)
        #expect(text.contains("\"id\" : \"0b6c1f8e-4d2a-4c1b-9f3e-2a7d5e8c1b40\""))
        #expect(!text.contains("0B6C1F8E"))
        #expect(text.contains("media/9d5dc894e10f060d.png"))
        #expect(!text.contains("\\/"))
    }

    @Test("Tra cứu câu và section theo id")
    func lookups() throws {
        let exam = try ExamJSON.decode(Fixtures.data(Fixtures.exam("kien-thuc-chung")))
        let qid = UUID(uuidString: "d34f5a6b-7c8d-4e9f-9a0b-2c3d4e5f6a7b")!
        #expect(exam.question(id: qid)?.text.contains("2^10") == true)
        #expect(exam.section(containing: qid)?.title == "Toán")
        #expect(exam.question(id: UUID()) == nil)
        #expect(exam.section(containing: UUID()) == nil)
        #expect(exam.allQuestions.count == exam.questionCount)
    }
}

@Suite("Exam model: đầu vào sai hoặc ngoài phạm vi model")
struct ExamModelEdgeTests {
    @Test("passPercent thập phân bị từ chối ở tầng Swift (không chỉ schema)")
    func decimalPassPercentRejected() {
        #expect(throws: DecodingError.self) {
            try ExamJSON.decode(Fixtures.data(Fixtures.invalid("pass-percent-decimal")))
        }
    }

    @Test("Thiếu trường bắt buộc → keyNotFound")
    func missingRequiredField() throws {
        var obj = try JSONSerialization.jsonObject(with: Fixtures.data(Fixtures.exam("toi-thieu"))) as! [String: Any]
        obj.removeValue(forKey: "passPercent")
        let data = try JSONSerialization.data(withJSONObject: obj)
        do {
            _ = try ExamJSON.decode(data)
            Issue.record("Lẽ ra phải ném keyNotFound")
        } catch DecodingError.keyNotFound(let key, _) {
            #expect(key.stringValue == "passPercent")
        }
    }

    @Test("Model giải mã được formatVersion lớn hơn; từ chối là việc của ExamFile (bước 6)")
    func futureVersionDecodesInModel() throws {
        let exam = try ExamJSON.decode(Fixtures.data(Fixtures.invalid("future-version")))
        #expect(exam.formatVersion == 2)
        #expect(exam.formatVersion > Exam.currentFormatVersion)
    }

    @Test("Model bỏ qua trường lạ và không giữ khi ghi lại (hành vi bản Admin; bản Học viên từ chối ở ExamFile)")
    func unknownFieldIgnoredAndDropped() throws {
        let exam = try ExamJSON.decode(Fixtures.data(Fixtures.invalid("unknown-top-level-field")))
        let text = String(decoding: try ExamJSON.encode(exam), as: UTF8.self)
        #expect(!text.contains("\"extra\""))
    }

    @Test("UUID chữ hoa đọc được và ghi ra chữ thường")
    func uppercaseUUIDNormalized() throws {
        let source = String(decoding: try Fixtures.data(Fixtures.exam("toi-thieu")), as: UTF8.self)
            .replacingOccurrences(of: "11111111-2222-4333-8444-555555555555", with: "AAAAAAAA-2222-4333-8444-BBBBBBBBBBBB")
        let exam = try ExamJSON.decode(Data(source.utf8))
        #expect(exam.id == UUID(uuidString: "aaaaaaaa-2222-4333-8444-bbbbbbbbbbbb"))
        let out = String(decoding: try ExamJSON.encode(exam), as: UTF8.self)
        #expect(out.contains("aaaaaaaa-2222-4333-8444-bbbbbbbbbbbb"))
    }

    @Test("Round-trip giữ hideAnswers=true, trường tuỳ chọn và thứ tự correct")
    func roundTripOptionalFieldsAndOrder() throws {
        let q = Question(
            type: .multiple, text: "Chọn hai",
            options: [Option(id: OptionID("A")!, text: "x"), Option(id: OptionID("B")!, text: "y"), Option(id: OptionID("C")!, text: "z")],
            correct: [OptionID("C")!, OptionID("A")!],
            explanation: "*vì*"
        )
        let exam = Exam(
            title: "Đề ẩn đáp án", code: "HID-1", passPercent: 80, timeLimitMinutes: 15,
            hideAnswers: true, instructions: "**Đọc kỹ**",
            sections: [ExamSection(title: "S", questions: [q])]
        )
        let again = try ExamJSON.decode(ExamJSON.encode(exam))
        #expect(again == exam)
        #expect(again.hideAnswers)
        #expect(again.sections[0].questions[0].correct == [OptionID("C")!, OptionID("A")!])
    }
}

@Suite("OptionID")
struct OptionIDTests {
    @Test("Chỉ nhận một chữ cái in hoa A–Z")
    func validation() {
        #expect(OptionID("A") != nil)
        #expect(OptionID("Z") != nil)
        #expect(OptionID("a") == nil)
        #expect(OptionID("AA") == nil)
        #expect(OptionID("1") == nil)
        #expect(OptionID("") == nil)
        #expect(OptionID("Ă") == nil)
    }

    @Test("Chuyển đổi index ↔ chữ cái")
    func indexMapping() {
        #expect(OptionID(index: 0) == OptionID("A"))
        #expect(OptionID(index: 25) == OptionID("Z"))
        #expect(OptionID(index: 26) == nil)
        #expect(OptionID(index: -1) == nil)
        #expect(OptionID("C")!.index == 2)
        #expect(OptionID("B")! < OptionID("C")!)
    }

    @Test("Giải mã mã lựa chọn sai báo lỗi dataCorrupted")
    func decodingRejectsBadID() {
        let json = Data(#"["A", "ab"]"#.utf8)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode([OptionID].self, from: json)
        }
    }

    @Test("Loại câu hỏi lạ bị từ chối khi giải mã")
    func unknownQuestionTypeRejected() {
        let json = Data(#"{"id":"33333333-4444-4555-8666-777777777777","type":"hotspot","text":"?","options":[{"id":"A","text":"1"},{"id":"B","text":"2"}],"correct":["A"]}"#.utf8)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(Question.self, from: json)
        }
    }
}
