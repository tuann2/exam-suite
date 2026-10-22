import Foundation
import Testing
@testable import ExamKit

// MARK: - Đề mẫu dựng bằng code

/// Đề hợp lệ, không có vấn đề nào, id cố định để so vị trí.
/// Phần 1: câu 1 single (A,B,C; đúng B), câu 2 multiple (A,B,C; đúng A,C).
/// Phần 2: câu 1 single có ảnh (A,B; đúng A).
private enum Sample {
    static let examID = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
    static let sectionIDs = [
        UUID(uuidString: "00000000-0000-4000-8000-000000000010")!,
        UUID(uuidString: "00000000-0000-4000-8000-000000000020")!,
    ]
    static let questionIDs = [
        [UUID(uuidString: "00000000-0000-4000-8000-000000000011")!,
         UUID(uuidString: "00000000-0000-4000-8000-000000000012")!],
        [UUID(uuidString: "00000000-0000-4000-8000-000000000021")!],
    ]
    static let image = "media/0123456789abcdef.png"

    static func options(_ count: Int) -> [Option] {
        (0 ..< count).map { Option(id: OptionID(index: $0)!, text: "Lựa chọn \($0 + 1)") }
    }

    static func ids(_ letters: String) -> [OptionID] { letters.map { OptionID($0)! } }

    static var exam: Exam {
        Exam(
            id: examID, title: "Đề kiểm tra validator", code: "VAL-01", passPercent: 70,
            timeLimitMinutes: 30, instructions: "Làm **hết** các câu.",
            sections: [
                ExamSection(id: sectionIDs[0], title: "Phần A", questions: [
                    Question(id: questionIDs[0][0], type: .single, text: "1 + 1 = ?",
                             options: options(3), correct: ids("B"), explanation: "Vì 1 + 1 = 2."),
                    Question(id: questionIDs[0][1], type: .multiple, text: "Số nào là số lẻ?",
                             options: options(3), correct: ids("AC")),
                ]),
                ExamSection(id: sectionIDs[1], title: "Phần B", questions: [
                    Question(id: questionIDs[1][0], type: .single, text: "Hình này là gì?", image: image,
                             options: options(2), correct: ids("A")),
                ]),
            ]
        )
    }

    static let examLoc = IssueLocation.exam
    static func sec(_ s: Int) -> IssueLocation { .section(index: s, id: sectionIDs[s]) }
    static func q(_ s: Int, _ i: Int) -> IssueLocation {
        .question(sectionIndex: s, questionIndex: i, id: questionIDs[s][i])
    }
    static func opt(_ s: Int, _ i: Int, _ o: Int) -> IssueLocation {
        .option(sectionIndex: s, questionIndex: i, optionIndex: o, questionID: questionIDs[s][i])
    }
}

private func text(_ n: Int, _ unit: String = "a") -> String { String(repeating: unit, count: n) }

/// Một tình huống: sửa đề mẫu rồi kỳ vọng đúng danh sách (mã, vị trí) theo thứ tự.
/// `expected` rỗng = tình huống dương (giá trị biên hợp lệ).
struct RuleCase: Sendable, CustomTestStringConvertible {
    let name: String
    let expected: [Expected]
    let mutate: @Sendable (inout Exam) -> Void

    struct Expected: Sendable, Equatable, CustomStringConvertible {
        let code: IssueCode
        let location: IssueLocation
        var description: String { "\(code.rawValue)@\(location)" }
    }

    init(_ name: String, _ expected: [(IssueCode, IssueLocation)] = [], _ mutate: @escaping @Sendable (inout Exam) -> Void) {
        self.name = name
        self.expected = expected.map { Expected(code: $0.0, location: $0.1) }
        self.mutate = mutate
    }

    var testDescription: String { name }
}

private func run(_ c: RuleCase, availableMedia: Set<String>? = nil) -> [RuleCase.Expected] {
    var exam = Sample.exam
    c.mutate(&exam)
    return ExamValidator.validate(exam, availableMedia: availableMedia)
        .map { RuleCase.Expected(code: $0.code, location: $0.location) }
}

// MARK: - Quy tắc cấp đề

@Suite("ExamValidator: cấp đề")
struct ExamValidatorExamLevelTests {
    @Test("Đề mẫu dựng bằng code không có vấn đề nào")
    func baselineIsClean() {
        #expect(ExamValidator.validate(Sample.exam).isEmpty)
        #expect(ExamValidator.validate(Sample.exam, availableMedia: [Sample.image]).isEmpty)
    }

    static let cases: [RuleCase] = [
        // title 1–200, không chỉ khoảng trắng
        RuleCase("title rỗng", [(.titleEmpty, Sample.examLoc)]) { $0.title = "" },
        RuleCase("title chỉ khoảng trắng và xuống dòng", [(.titleEmpty, Sample.examLoc)]) { $0.title = "  \n\t " },
        RuleCase("title chỉ NBSP U+00A0 (White_Space)", [(.titleEmpty, Sample.examLoc)]) { $0.title = "\u{00A0}\u{00A0}" },
        RuleCase("title chỉ khoảng trắng ý tự U+3000 (White_Space)", [(.titleEmpty, Sample.examLoc)]) { $0.title = "\u{3000}" },
        RuleCase("title chỉ LINE SEPARATOR U+2028 (White_Space)", [(.titleEmpty, Sample.examLoc)]) { $0.title = "\u{2028} " },
        RuleCase("title chỉ ZWSP U+200B: không thuộc White_Space nên không bị coi là rỗng") { $0.title = "\u{200B}" },
        RuleCase("title 1 ký tự hợp lệ") { $0.title = "A" },
        RuleCase("title 200 ký tự hợp lệ") { $0.title = text(200) },
        RuleCase("title 200 chữ tiếng Việt dựng sẵn hợp lệ") { $0.title = text(200, "ệ") },
        RuleCase("title 201 ký tự", [(.titleTooLong, Sample.examLoc)]) { $0.title = text(201) },
        RuleCase("title 100 chữ tổ hợp (300 code point) vượt giới hạn như schema",
                 [(.titleTooLong, Sample.examLoc)]) { $0.title = text(100, "e\u{0302}\u{0323}") },
        // code ^[A-Za-z0-9._-]{1,32}$
        RuleCase("code vắng mặt hợp lệ") { $0.code = nil },
        RuleCase("code đủ loại ký tự cho phép") { $0.code = "Ab9.-_" },
        RuleCase("code 32 ký tự hợp lệ") { $0.code = text(32, "K") },
        RuleCase("code 33 ký tự", [(.codeInvalid, Sample.examLoc)]) { $0.code = text(33, "K") },
        RuleCase("code rỗng", [(.codeInvalid, Sample.examLoc)]) { $0.code = "" },
        RuleCase("code có khoảng trắng", [(.codeInvalid, Sample.examLoc)]) { $0.code = "KTC 01" },
        RuleCase("code có chữ có dấu", [(.codeInvalid, Sample.examLoc)]) { $0.code = "Đề01" },
        RuleCase("code có xuống dòng cuối", [(.codeInvalid, Sample.examLoc)]) { $0.code = "KTC01\n" },
        // passPercent 0–100
        RuleCase("passPercent 0 hợp lệ") { $0.passPercent = 0 },
        RuleCase("passPercent 100 hợp lệ") { $0.passPercent = 100 },
        RuleCase("passPercent -1", [(.passPercentOutOfRange, Sample.examLoc)]) { $0.passPercent = -1 },
        RuleCase("passPercent 101", [(.passPercentOutOfRange, Sample.examLoc)]) { $0.passPercent = 101 },
        // timeLimitMinutes 1–600
        RuleCase("timeLimitMinutes 1 hợp lệ") { $0.timeLimitMinutes = 1 },
        RuleCase("timeLimitMinutes 600 hợp lệ") { $0.timeLimitMinutes = 600 },
        RuleCase("timeLimitMinutes 0", [(.timeLimitOutOfRange, Sample.examLoc)]) { $0.timeLimitMinutes = 0 },
        RuleCase("timeLimitMinutes 601", [(.timeLimitOutOfRange, Sample.examLoc)]) { $0.timeLimitMinutes = 601 },
        // instructions ≤ 4000
        RuleCase("instructions vắng mặt hợp lệ") { $0.instructions = nil },
        RuleCase("instructions rỗng hợp lệ (schema không có minLength)") { $0.instructions = "" },
        RuleCase("instructions 4000 ký tự hợp lệ") { $0.instructions = text(4000) },
        RuleCase("instructions 4001 ký tự", [(.instructionsTooLong, Sample.examLoc)]) { $0.instructions = text(4001) },
        // sections ≥ 1
        RuleCase("không có section nào", [(.noSections, Sample.examLoc)]) { $0.sections = [] },
        // formatVersion là việc của ExamFile
        RuleCase("formatVersion khác hiện hành không phải việc của validator") { $0.formatVersion = 99 },
        // id không trùng trong toàn đề
        RuleCase("section trùng id với đề", [(.duplicateID, .section(index: 1, id: Sample.examID))]) {
            $0.sections[1].id = Sample.examID
        },
        RuleCase("hai câu trùng id (khác section)",
                 [(.duplicateID, .question(sectionIndex: 1, questionIndex: 0, id: Sample.questionIDs[0][0]))]) {
            $0.sections[1].questions[0].id = Sample.questionIDs[0][0]
        },
        RuleCase("câu trùng id với section",
                 [(.duplicateID, .question(sectionIndex: 0, questionIndex: 1, id: Sample.sectionIDs[0]))]) {
            $0.sections[0].questions[1].id = Sample.sectionIDs[0]
        },
        RuleCase("câu trùng id với đề",
                 [(.duplicateID, .question(sectionIndex: 0, questionIndex: 0, id: Sample.examID))]) {
            $0.sections[0].questions[0].id = Sample.examID
        },
        RuleCase("hai section trùng id",
                 [(.duplicateID, .section(index: 1, id: Sample.sectionIDs[0]))]) {
            $0.sections[1].id = Sample.sectionIDs[0]
        },
    ]

    @Test("Quy tắc cấp đề", arguments: cases)
    func rule(_ c: RuleCase) {
        #expect(run(c) == c.expected)
    }
}

// MARK: - Quy tắc cấp section

@Suite("ExamValidator: cấp section")
struct ExamValidatorSectionTests {
    static let cases: [RuleCase] = [
        RuleCase("tiêu đề section rỗng", [(.titleEmpty, Sample.sec(1))]) { $0.sections[1].title = "" },
        RuleCase("tiêu đề section chỉ khoảng trắng", [(.titleEmpty, Sample.sec(0))]) { $0.sections[0].title = "   " },
        RuleCase("tiêu đề section 200 ký tự hợp lệ") { $0.sections[0].title = text(200) },
        RuleCase("tiêu đề section 201 ký tự", [(.titleTooLong, Sample.sec(0))]) { $0.sections[0].title = text(201) },
        RuleCase("section không có câu nào", [(.sectionHasNoQuestions, Sample.sec(1))]) { $0.sections[1].questions = [] },
        RuleCase("hai section trùng tiêu đề (sau trim, không phân biệt hoa thường) → warning",
                 [(.duplicateSectionTitle, Sample.sec(1))]) { $0.sections[1].title = "  phần a " },
        RuleCase("tiêu đề trùng sau khi bỏ NBSP và U+3000 ở hai đầu → warning",
                 [(.duplicateSectionTitle, Sample.sec(1))]) { $0.sections[1].title = "\u{00A0}Phần A\u{3000}" },
        RuleCase("tiêu đề khác dấu không bị coi là trùng") {
            $0.sections[0].title = "Toán"
            $0.sections[1].title = "Toan"
        },
        RuleCase("hai section cùng trống chỉ báo titleEmpty, không báo trùng",
                 [(.titleEmpty, Sample.sec(0)), (.titleEmpty, Sample.sec(1))]) {
            $0.sections[0].title = ""
            $0.sections[1].title = " "
        },
    ]

    @Test("Quy tắc cấp section", arguments: cases)
    func rule(_ c: RuleCase) {
        #expect(run(c) == c.expected)
    }
}

// MARK: - Quy tắc cấp câu hỏi và lựa chọn

@Suite("ExamValidator: cấp câu hỏi và lựa chọn")
struct ExamValidatorQuestionTests {
    static let cases: [RuleCase] = [
        // text 1–10000, không chỉ khoảng trắng
        RuleCase("nội dung câu rỗng", [(.questionTextEmpty, Sample.q(0, 0))]) { $0.sections[0].questions[0].text = "" },
        RuleCase("nội dung câu chỉ khoảng trắng", [(.questionTextEmpty, Sample.q(0, 1))]) {
            $0.sections[0].questions[1].text = " \n\t"
        },
        RuleCase("nội dung câu 10000 ký tự hợp lệ") { $0.sections[0].questions[0].text = text(10000) },
        RuleCase("nội dung câu 10001 ký tự", [(.questionTextTooLong, Sample.q(0, 0))]) {
            $0.sections[0].questions[0].text = text(10001)
        },
        // explanation ≤ 10000
        RuleCase("giải thích rỗng hợp lệ") { $0.sections[0].questions[0].explanation = "" },
        RuleCase("giải thích 10000 ký tự hợp lệ") { $0.sections[0].questions[0].explanation = text(10000) },
        RuleCase("giải thích 10001 ký tự", [(.explanationTooLong, Sample.q(0, 0))]) {
            $0.sections[0].questions[0].explanation = text(10001)
        },
        // image ^media/[a-f0-9]{16,64}\.(png|jpg|jpeg|gif|webp|heic)$
        RuleCase("ảnh 64 hex .heic hợp lệ") { $0.sections[1].questions[0].image = "media/\(text(64, "f")).heic" },
        RuleCase("ảnh .jpeg hợp lệ") { $0.sections[1].questions[0].image = "media/\(text(16, "0")).jpeg" },
        RuleCase("ảnh hex chữ hoa", [(.imagePathInvalid, Sample.q(1, 0))]) {
            $0.sections[1].questions[0].image = "media/0123456789ABCDEF.png"
        },
        RuleCase("ảnh 15 hex", [(.imagePathInvalid, Sample.q(1, 0))]) {
            $0.sections[1].questions[0].image = "media/\(text(15, "a")).png"
        },
        RuleCase("ảnh 65 hex", [(.imagePathInvalid, Sample.q(1, 0))]) {
            $0.sections[1].questions[0].image = "media/\(text(65, "a")).png"
        },
        RuleCase("ảnh đuôi .bmp", [(.imagePathInvalid, Sample.q(1, 0))]) {
            $0.sections[1].questions[0].image = "media/0123456789abcdef.bmp"
        },
        RuleCase("ảnh đuôi chữ hoa .PNG", [(.imagePathInvalid, Sample.q(1, 0))]) {
            $0.sections[1].questions[0].image = "media/0123456789abcdef.PNG"
        },
        RuleCase("ảnh ngoài thư mục media/", [(.imagePathInvalid, Sample.q(1, 0))]) {
            $0.sections[1].questions[0].image = "images/0123456789abcdef.png"
        },
        RuleCase("ảnh trong thư mục con của media/", [(.imagePathInvalid, Sample.q(1, 0))]) {
            $0.sections[1].questions[0].image = "media/sub/0123456789abcdef.png"
        },
        RuleCase("ảnh có xuống dòng cuối đường dẫn", [(.imagePathInvalid, Sample.q(1, 0))]) {
            $0.sections[1].questions[0].image = "media/0123456789abcdef.png\n"
        },
        RuleCase("ảnh không có đuôi", [(.imagePathInvalid, Sample.q(1, 0))]) {
            $0.sections[1].questions[0].image = "media/0123456789abcdef"
        },
        RuleCase("ảnh tên không phải hash (fixture image-bad-name)", [(.imagePathInvalid, Sample.q(1, 0))]) {
            $0.sections[1].questions[0].image = "media/missing-file.png"
        },
        // options 2–26
        RuleCase("2 lựa chọn hợp lệ") { $0.sections[0].questions[0].options = Sample.options(2) },
        RuleCase("26 lựa chọn hợp lệ") { $0.sections[0].questions[0].options = Sample.options(26) },
        RuleCase("1 lựa chọn", [(.tooFewOptions, Sample.q(1, 0))]) {
            $0.sections[1].questions[0].options = Sample.options(1)
        },
        RuleCase("0 lựa chọn: thiếu lựa chọn và đáp án không nằm trong lựa chọn",
                 [(.tooFewOptions, Sample.q(1, 0)), (.correctAnswerNotInOptions, Sample.q(1, 0))]) {
            $0.sections[1].questions[0].options = []
        },
        RuleCase("27 lựa chọn (không báo sai thứ tự cho lựa chọn thứ 27)", [(.tooManyOptions, Sample.q(0, 0))]) {
            $0.sections[0].questions[0].options = Sample.options(26) + [Option(id: OptionID("Z")!, text: "thừa")]
        },
        // options[].id theo thứ tự A, B, C…
        RuleCase("mã lựa chọn đảo B, A, C",
                 [(.optionIDOutOfOrder, Sample.opt(0, 0, 0)), (.optionIDOutOfOrder, Sample.opt(0, 0, 1))]) {
            $0.sections[0].questions[0].options = [
                Option(id: OptionID("B")!, text: "x"), Option(id: OptionID("A")!, text: "y"), Option(id: OptionID("C")!, text: "z"),
            ]
        },
        RuleCase("mã lựa chọn nhảy cóc A, C (thiếu B)", [(.optionIDOutOfOrder, Sample.opt(1, 0, 1))]) {
            $0.sections[1].questions[0].options = [Option(id: OptionID("A")!, text: "x"), Option(id: OptionID("C")!, text: "y")]
        },
        RuleCase("mã lựa chọn trùng A, A",
                 [(.optionIDOutOfOrder, Sample.opt(1, 0, 1))]) {
            $0.sections[1].questions[0].options = [Option(id: OptionID("A")!, text: "x"), Option(id: OptionID("A")!, text: "y")]
        },
        // option text 1–4000, không chỉ khoảng trắng
        RuleCase("nội dung lựa chọn rỗng", [(.optionTextEmpty, Sample.opt(0, 1, 2))]) {
            $0.sections[0].questions[1].options[2].text = ""
        },
        RuleCase("nội dung lựa chọn chỉ khoảng trắng", [(.optionTextEmpty, Sample.opt(0, 0, 0))]) {
            $0.sections[0].questions[0].options[0].text = "  "
        },
        RuleCase("nội dung lựa chọn chỉ NBSP", [(.optionTextEmpty, Sample.opt(1, 0, 1))]) {
            $0.sections[1].questions[0].options[1].text = "\u{00A0}"
        },
        RuleCase("nội dung câu chỉ U+3000 và U+2028", [(.questionTextEmpty, Sample.q(1, 0))]) {
            $0.sections[1].questions[0].text = "\u{3000}\u{2028}"
        },
        RuleCase("nội dung lựa chọn 4000 ký tự hợp lệ") { $0.sections[0].questions[0].options[0].text = text(4000) },
        RuleCase("nội dung lựa chọn 4001 ký tự", [(.optionTextTooLong, Sample.opt(0, 0, 0))]) {
            $0.sections[0].questions[0].options[0].text = text(4001)
        },
        // correct ≥ 1, không trùng, có trong options, single đúng 1
        RuleCase("không có đáp án đúng", [(.noCorrectAnswer, Sample.q(0, 0))]) { $0.sections[0].questions[0].correct = [] },
        RuleCase("đáp án đúng lặp trong câu multiple", [(.duplicateCorrectAnswer, Sample.q(0, 1))]) {
            $0.sections[0].questions[1].correct = Sample.ids("ACA")
        },
        RuleCase("đáp án đúng không có trong lựa chọn", [(.correctAnswerNotInOptions, Sample.q(0, 0))]) {
            $0.sections[0].questions[0].correct = Sample.ids("D")
        },
        RuleCase("đáp án đúng lặp và không có trong lựa chọn: báo mỗi loại một lần",
                 [(.duplicateCorrectAnswer, Sample.q(0, 1)), (.correctAnswerNotInOptions, Sample.q(0, 1))]) {
            $0.sections[0].questions[1].correct = Sample.ids("ADDA")
        },
        RuleCase("câu single có hai đáp án đúng", [(.singleHasMultipleCorrect, Sample.q(0, 0))]) {
            $0.sections[0].questions[0].correct = Sample.ids("AB")
        },
        RuleCase("câu single có đáp án B lặp hai lần: báo cả lặp lẫn quá một đáp án (như schema)",
                 [(.duplicateCorrectAnswer, Sample.q(0, 0)), (.singleHasMultipleCorrect, Sample.q(0, 0))]) {
            $0.sections[0].questions[0].correct = Sample.ids("BB")
        },
        RuleCase("câu multiple có đủ ba đáp án đúng hợp lệ") { $0.sections[0].questions[1].correct = Sample.ids("ABC") },
        RuleCase("câu multiple chỉ có một đáp án đúng → warning", [(.multipleHasSingleCorrect, Sample.q(0, 1))]) {
            $0.sections[0].questions[1].correct = Sample.ids("B")
        },
    ]

    @Test("Quy tắc cấp câu hỏi và lựa chọn", arguments: cases)
    func rule(_ c: RuleCase) {
        #expect(run(c) == c.expected)
    }
}

// MARK: - Ảnh tồn tại trong gói

@Suite("ExamValidator: ảnh có trong gói")
struct ExamValidatorMediaTests {
    let noop = RuleCase("đề mẫu") { _ in }

    @Test("availableMedia nil: không kiểm ảnh tồn tại")
    func nilSkipsCheck() {
        #expect(run(noop, availableMedia: nil).isEmpty)
    }

    @Test("Ảnh có trong gói: hợp lệ")
    func presentImage() {
        #expect(run(noop, availableMedia: [Sample.image, "media/ffffffffffffffff.jpg"]).isEmpty)
    }

    @Test("Ảnh không có trong gói: error imageNotFound")
    func missingImage() {
        #expect(run(noop, availableMedia: []) == [.init(code: .imageNotFound, location: Sample.q(1, 0))])
        #expect(run(noop, availableMedia: ["media/ffffffffffffffff.png"]) == [.init(code: .imageNotFound, location: Sample.q(1, 0))])
    }

    @Test("Đường dẫn ảnh sai dạng chỉ báo imagePathInvalid, không báo thêm imageNotFound")
    func badPathReportedOnce() {
        let c = RuleCase("ảnh sai dạng") { $0.sections[1].questions[0].image = "media/missing-file.png" }
        #expect(run(c, availableMedia: []) == [.init(code: .imagePathInvalid, location: Sample.q(1, 0))])
    }
}

// MARK: - Mức độ, thứ tự, thông báo

@Suite("ExamValidator: mức độ, thứ tự và thông báo")
struct ExamValidatorReportTests {
    @Test("Chỉ duplicateSectionTitle và multipleHasSingleCorrect là warning")
    func severities() {
        let warnings = IssueCode.allCases.filter { $0.severity == .warning }
        #expect(Set(warnings) == [.duplicateSectionTitle, .multipleHasSingleCorrect])
    }

    @Test("Mức độ của issue lấy theo mã; hasErrors chỉ tính error")
    func hasErrors() {
        let warning = ValidationIssue(code: .multipleHasSingleCorrect, location: .exam, message: "x")
        let error = ValidationIssue(code: .titleEmpty, location: .exam, message: "x")
        #expect(warning.severity == .warning)
        #expect(error.severity == .error)
        #expect([ValidationIssue]().hasErrors == false)
        #expect([warning].hasErrors == false)
        #expect([warning, error].hasErrors)
    }

    @Test("Đề chỉ có warning vẫn mở được ở bản Học viên (hasErrors == false)")
    func warningsOnlyDoNotBlock() {
        var exam = Sample.exam
        exam.sections[1].title = "PHẦN A"
        exam.sections[0].questions[1].correct = Sample.ids("C")
        let issues = ExamValidator.validate(exam)
        #expect(issues.map(\.code) == [.multipleHasSingleCorrect, .duplicateSectionTitle])
        #expect(!issues.hasErrors)
    }

    @Test("Kết quả theo thứ tự xuất hiện: đề → section → câu → lựa chọn, ổn định giữa các lần gọi")
    func ordering() {
        var exam = Sample.exam
        exam.sections[1].questions[0].options[1].text = ""   // phần 2, câu 1, lựa chọn 2
        exam.sections[1].title = ""                           // phần 2
        exam.sections[0].questions[1].correct = []            // phần 1, câu 2
        exam.sections[0].questions[0].options[0].text = ""    // phần 1, câu 1, lựa chọn 1
        exam.sections[0].questions[0].text = ""               // phần 1, câu 1
        exam.passPercent = 200                                // đề
        exam.title = ""                                       // đề
        let issues = ExamValidator.validate(exam)
        let expected: [(IssueCode, IssueLocation)] = [
            (.titleEmpty, .exam),
            (.passPercentOutOfRange, .exam),
            (.questionTextEmpty, Sample.q(0, 0)),
            (.optionTextEmpty, Sample.opt(0, 0, 0)),
            (.noCorrectAnswer, Sample.q(0, 1)),
            (.titleEmpty, Sample.sec(1)),
            (.optionTextEmpty, Sample.opt(1, 0, 1)),
        ]
        #expect(issues.map { RuleCase.Expected(code: $0.code, location: $0.location) }
            == expected.map { RuleCase.Expected(code: $0.0, location: $0.1) })
        #expect(ExamValidator.validate(exam) == issues)
    }

    @Test("Thông báo tiếng Việt nêu vị trí 1-based và giá trị sai")
    func messages() {
        var exam = Sample.exam
        exam.sections[0].questions[1].correct = Sample.ids("AD")
        exam.sections[1].questions[0].options[1].text = ""
        exam.code = "KTC 01"
        let issues = ExamValidator.validate(exam)
        #expect(issues.count == 3)
        #expect(issues.allSatisfy { !$0.message.isEmpty })
        #expect(issues[0].message.contains("KTC 01"))
        #expect(issues[1].message.contains("Phần 1, câu 2"))
        #expect(issues[1].message.contains("D"))
        #expect(issues[2].message.contains("Phần 2, câu 1, lựa chọn thứ 2"))
    }
}

// MARK: - Khoảng trắng, id khác hoa/thường, hàm công khai

/// Đối số có mã (`IssueArguments`) để giao diện dựng câu báo bằng chữ của catalog (accessibility-localization.md,
/// phương án 2): mỗi giá trị trong `arguments` có trong `message`, và đủ để dựng lại đúng `message`.
@Suite("ExamValidator: đối số của vấn đề")
struct ExamValidatorArgumentTests {
    /// Mọi vấn đề của mọi tình huống trong các bảng quy tắc (kể cả ảnh không có trong gói).
    static var allIssues: [ValidationIssue] {
        let cases = ExamValidatorExamLevelTests.cases + ExamValidatorSectionTests.cases + ExamValidatorQuestionTests.cases
        return cases.flatMap { c -> [ValidationIssue] in
            var exam = Sample.exam
            c.mutate(&exam)
            return ExamValidator.validate(exam, availableMedia: [])
        }
    }

    @Test("Các bảng quy tắc sinh đủ mọi mã (để kiểm đối số của từng mã)")
    func everyCodeIsCovered() {
        #expect(Set(Self.allIssues.map(\.code)) == Set(IssueCode.allCases))
    }

    @Test("Giá trị trong arguments có trong message; mã cần đối số thì có đủ")
    func argumentsAppearInMessage() {
        for issue in Self.allIssues {
            let a = issue.arguments
            let label = "\(issue.code.rawValue): \(issue.message)"
            // Chuỗi rỗng (mã đề rỗng): `contains("")` luôn sai, nên so cả cặp ngoặc kép.
            if let text = a.text { #expect(issue.message.contains(text.isEmpty ? "\"\"" : text), "\(label)") }
            if let value = a.value { #expect(issue.message.contains("\(value)"), "\(label)") }
            if let limit = a.limit { #expect(issue.message.contains("\(limit)"), "\(label)") }
            if let id = a.optionID { #expect(issue.message.contains(id.description), "\(label)") }
            if let id = a.expectedOptionID { #expect(issue.message.contains(id.description), "\(label)") }
            if !a.optionIDs.isEmpty {
                #expect(issue.message.contains(a.optionIDs.map(\.description).joined(separator: ", ")), "\(label)")
            }
            switch issue.code {
            case .codeInvalid, .duplicateID, .duplicateSectionTitle, .imagePathInvalid, .imageNotFound:
                #expect(a.text != nil, "\(label)")
            case .passPercentOutOfRange, .timeLimitOutOfRange:
                #expect(a.value != nil, "\(label)")
            case .titleEmpty:
                #expect(a.limit != nil, "\(label)")
            case .titleTooLong, .instructionsTooLong, .questionTextTooLong, .explanationTooLong, .tooFewOptions,
                 .tooManyOptions:
                #expect(a.value != nil && a.limit != nil, "\(label)")
            case .optionTextTooLong:
                #expect(a.value != nil && a.limit != nil && a.optionID != nil, "\(label)")
            case .optionTextEmpty:
                #expect(a.optionID != nil, "\(label)")
            case .optionIDOutOfOrder:
                #expect(a.optionID != nil && a.expectedOptionID != nil, "\(label)")
            case .duplicateCorrectAnswer, .correctAnswerNotInOptions:
                #expect(!a.optionIDs.isEmpty, "\(label)")
            case .singleHasMultipleCorrect:
                #expect(a.value == a.optionIDs.count && a.optionIDs.count > 1, "\(label)")
            case .noSections, .sectionHasNoQuestions, .questionTextEmpty, .noCorrectAnswer, .multipleHasSingleCorrect:
                #expect(a == IssueArguments(), "\(label)")
            }
        }
    }

    @Test("Nơi xuất hiện trước của id và tiêu đề phần trùng")
    func firstLocations() {
        var exam = Sample.exam
        exam.sections[1].title = " phần a "
        exam.sections[1].id = Sample.examID
        exam.sections[1].questions[0].id = Sample.questionIDs[0][1]
        let issues = ExamValidator.validate(exam)
        let sectionID = issues.first { $0.code == .duplicateID && $0.location == .section(index: 1, id: Sample.examID) }
        #expect(sectionID?.arguments.firstLocation == .exam)
        #expect(sectionID?.arguments.text == Sample.examID.uuidString.lowercased())
        let questionID = issues.first { $0.code == .duplicateID && $0.arguments.firstLocation != .exam }
        #expect(questionID?.arguments.firstLocation == Sample.q(0, 1))
        let title = issues.first { $0.code == .duplicateSectionTitle }
        #expect(title?.arguments.firstLocation == Sample.sec(0))
        #expect(title?.arguments.text == "phần a")
    }

    @Test("Đối số cụ thể: mã đề, ngưỡng, đáp án lặp và thiếu, mã lựa chọn sai thứ tự")
    func specificArguments() {
        var exam = Sample.exam
        exam.code = "KTC 01"
        exam.passPercent = -5
        exam.sections[0].questions[0].correct = Sample.ids("BBD")
        exam.sections[0].questions[1].options[2] = Option(id: OptionID("E")!, text: "x")
        let issues = ExamValidator.validate(exam)
        func arguments(_ code: IssueCode) -> IssueArguments? { issues.first { $0.code == code }?.arguments }
        #expect(arguments(.codeInvalid) == IssueArguments(text: "KTC 01"))
        #expect(arguments(.passPercentOutOfRange) == IssueArguments(value: -5))
        #expect(arguments(.duplicateCorrectAnswer) == IssueArguments(optionIDs: Sample.ids("B")))
        #expect(arguments(.correctAnswerNotInOptions) == IssueArguments(optionIDs: Sample.ids("D")))
        #expect(arguments(.singleHasMultipleCorrect) == IssueArguments(value: 3, optionIDs: Sample.ids("BBD")))
        #expect(arguments(.optionIDOutOfOrder) == IssueArguments(optionID: OptionID("E")!, expectedOptionID: OptionID("C")!))
    }

    @Test("Khởi tạo cũ (không đối số) vẫn dùng được: arguments rỗng")
    func legacyInitializer() {
        let issue = ValidationIssue(code: .titleEmpty, location: .exam, message: "x")
        #expect(issue.arguments == IssueArguments())
    }
}

@Suite("ExamValidator: định nghĩa khoảng trắng, id và hàm công khai")
struct ExamValidatorDefinitionTests {
    @Test("Khoảng trắng = thuộc tính Unicode White_Space: NBSP, U+3000, U+2028 có; ZWSP U+200B không")
    func whiteSpaceDefinition() {
        for scalar: Unicode.Scalar in [" ", "\t", "\n", "\u{00A0}", "\u{3000}", "\u{2028}", "\u{2029}"] {
            #expect(scalar.properties.isWhitespace, "U+\(String(scalar.value, radix: 16, uppercase: true))")
            #expect(ExamValidator.isBlank(String(scalar)))
        }
        let zwsp: Unicode.Scalar = "\u{200B}"
        #expect(!zwsp.properties.isWhitespace)
        #expect(!ExamValidator.isBlank("\u{200B}"))
        #expect(ExamValidator.isBlank(""))
        #expect(ExamValidator.trimmed("\u{00A0} Phần A\u{3000}\n") == "Phần A")
    }

    @Test("Hai id chỉ khác hoa/thường trong file là trùng (UUID so theo giá trị)")
    func caseInsensitiveDuplicateIDs() throws {
        // Đề dùng id chữ thường, section dùng cùng id viết hoa: hai chuỗi khác nhau trong file.
        let examIDText = "aaaaaaaa-2222-4333-8444-555555555555"
        let sectionIDText = "AAAAAAAA-2222-4333-8444-555555555555"
        #expect(examIDText != sectionIDText, "Hai chuỗi id phải khác nhau thì test mới có ý nghĩa")
        #expect(examIDText.lowercased() == sectionIDText.lowercased())
        let source = String(decoding: try Fixtures.data(Fixtures.exam("toi-thieu")), as: UTF8.self)
            .replacingOccurrences(of: "11111111-2222-4333-8444-555555555555", with: examIDText)
            .replacingOccurrences(of: "22222222-3333-4444-8555-666666666666", with: sectionIDText)
        #expect(source.contains("\"\(examIDText)\"") && source.contains("\"\(sectionIDText)\""))
        let exam = try ExamJSON.decode(Data(source.utf8))
        let issues = ExamValidator.validate(exam)
        #expect(issues.map(\.code) == [.duplicateID])
        #expect(issues.first?.location == .section(index: 0, id: UUID(uuidString: examIDText)!))
    }

    @Test("Hàm công khai cho giao diện soạn đề: textLength đếm code point, isValidCode, isValidImagePath")
    func publicHelpers() {
        #expect(ExamValidator.textLength("ệ") == 1)
        #expect(ExamValidator.textLength("e\u{0302}\u{0323}") == 3)
        #expect(ExamValidator.isValidCode("KTC-01"))
        #expect(!ExamValidator.isValidCode("KTC 01"))
        #expect(ExamValidator.isValidImagePath("media/0123456789abcdef.png"))
        #expect(!ExamValidator.isValidImagePath("media/0123456789abcdef.png\n"))
    }
}

// MARK: - Fixture dùng chung với scripts/validate_exam.py

@Suite("ExamValidator: fixture dùng chung với scripts/validate_exam.py")
struct ExamValidatorFixtureTests {
    /// Tập "media/<tên>" có trong thư mục gói đã giải nén.
    static func mediaSet(of packageDir: URL) -> Set<String> {
        let dir = packageDir.appendingPathComponent("media", isDirectory: true)
        let names = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        return Set(names.map { "media/\($0)" })
    }

    static func validExamDirectories() throws -> [URL] {
        let examsDir = Fixtures.root.appendingPathComponent("exams", isDirectory: true)
        return try FileManager.default.contentsOfDirectory(atPath: examsDir.path).sorted()
            .map { examsDir.appendingPathComponent($0, isDirectory: true) }
            .filter { FileManager.default.fileExists(atPath: $0.appendingPathComponent("exam.json").path) }
    }

    @Test("Hai đề mẫu không có vấn đề nào (kể cả warning), có kiểm ảnh trong gói",
          arguments: ["kien-thuc-chung", "toi-thieu"])
    func namedValidFixtures(name: String) throws {
        let url = Fixtures.exam(name)
        let exam = try ExamJSON.decode(Fixtures.data(url))
        let issues = ExamValidator.validate(exam, availableMedia: Self.mediaSet(of: url.deletingLastPathComponent()))
        #expect(issues.isEmpty, "\(issues.map(\.message))")
    }

    @Test("Bất biến đồng bộ với script: mọi fixtures/exams/*/exam.json không có error")
    func everyValidFixtureHasNoErrors() throws {
        let dirs = try Self.validExamDirectories()
        #expect(dirs.count >= 2)
        for dir in dirs {
            let exam = try ExamJSON.decode(Fixtures.data(dir.appendingPathComponent("exam.json")))
            let issues = ExamValidator.validate(exam, availableMedia: Self.mediaSet(of: dir))
            #expect(!issues.hasErrors, "\(dir.lastPathComponent): \(issues.map(\.message))")
        }
    }

    @Test("Ảnh của đề mẫu bị thiếu trong gói → imageNotFound")
    func sampleWithoutMedia() throws {
        let exam = try ExamJSON.decode(Fixtures.data(Fixtures.exam("kien-thuc-chung")))
        #expect(ExamValidator.validate(exam, availableMedia: []).map(\.code) == [.imageNotFound])
    }

    /// Fixture sai mà model giải mã được và validator phải bắt, với mã mong đợi theo thứ tự: khoá `issueCodes` của
    /// fixtures/expected-verdicts.json, dùng chung với lõi Kotlin của bản Android. Đọc hỏng thì rỗng, test
    /// `expectationsCoverAllFixtures` báo đỏ.
    static let caughtByValidator: [String: [IssueCode]] = {
        struct Doc: Decodable { let issueCodes: [String: [String]] }
        let url = Fixtures.root.appendingPathComponent("expected-verdicts.json")
        guard let data = try? Data(contentsOf: url), let doc = try? JSONDecoder().decode(Doc.self, from: data) else { return [:] }
        var result: [String: [IssueCode]] = [:]
        for (key, codes) in doc.issueCodes where key.hasPrefix("invalid/") {
            result[String(key.dropFirst("invalid/".count))] = codes.compactMap(IssueCode.init(rawValue:))
        }
        return result
    }()
    /// Model không giải mã được: bản Học viên đã từ chối ở bước đọc.
    static let rejectedByDecoder = ["missing-correct", "pass-percent-decimal"]
    /// Việc của ExamFile (bước 6): phiên bản mới hơn và trường lạ. Validator bỏ qua.
    /// Fixture là việc của ExamFile (phiên bản, trường lạ), nhận theo quy ước tên để PR
    /// khác thêm fixture `unknown-*` mà không phải sửa danh sách này:
    /// `future-version` và mọi `unknown-*`. Chỉ lấy file thật sự có trong fixtures/invalid.
    static let handledByExamFile: [String] = {
        let dir = Fixtures.root.appendingPathComponent("invalid", isDirectory: true)
        let names = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        return names
            .filter { $0.hasSuffix(".json") }
            .map { String($0.dropLast(".json".count)) }
            .filter { $0 == "future-version" || $0.hasPrefix("unknown-") }
            .sorted()
    }()

    @Test("Fixture sai mà model giải mã được → đúng mã lỗi mong đợi",
          arguments: caughtByValidator.keys.sorted())
    func invalidFixtureCaught(name: String) throws {
        let exam = try ExamJSON.decode(Fixtures.data(Fixtures.invalid(name)))
        let issues = ExamValidator.validate(exam)
        #expect(issues.map(\.code) == Self.caughtByValidator[name])
        #expect(issues.hasErrors)
    }

    @Test("Fixture sai mà model không giải mã được → DecodingError", arguments: rejectedByDecoder)
    func invalidFixtureRejectedByDecoder(name: String) {
        #expect(throws: DecodingError.self) {
            try ExamJSON.decode(Fixtures.data(Fixtures.invalid(name)))
        }
    }

    @Test("Fixture thuộc phần ExamFile: validator không báo gì", arguments: handledByExamFile)
    func invalidFixtureLeftToExamFile(name: String) throws {
        let exam = try ExamJSON.decode(Fixtures.data(Fixtures.invalid(name)))
        #expect(ExamValidator.validate(exam).isEmpty)
    }

    @Test("Mọi fixtures/invalid/*.json đều được phân loại ở một trong ba nhóm trên")
    func everyInvalidFixtureClassified() throws {
        let dir = Fixtures.root.appendingPathComponent("invalid", isDirectory: true)
        let names = try FileManager.default.contentsOfDirectory(atPath: dir.path)
            .filter { $0.hasSuffix(".json") }
            .map { String($0.dropLast(".json".count)) }
        let known = Set(Self.caughtByValidator.keys).union(Self.rejectedByDecoder).union(Self.handledByExamFile)
        #expect(Set(names) == known)
        // Bằng chứng quy ước tên không rỗng: hai fixture ExamFile có sẵn phải được nhận.
        #expect(Set(Self.handledByExamFile).isSuperset(of: ["future-version", "unknown-top-level-field"]))
    }
}

// MARK: - Bảng kỳ vọng chung với scripts/check_validator_parity.py

/// `fixtures/expected-verdicts.json` ràng buộc cả script lẫn app: script parity kiểm
/// `validate_exam.py`, suite này kiểm model + ExamValidator trên cùng file kỳ vọng.
@Suite("ExamValidator: cùng kết luận với validate_exam.py (fixtures/expected-verdicts.json)")
struct ExamValidatorParityTests {
    struct Expected: Decodable {
        let whiteSpace: [String]
        let verdicts: [String: String]
    }

    static let expected: Expected = {
        let url = Fixtures.root.appendingPathComponent("expected-verdicts.json")
        // Đọc hỏng thì trả rỗng để test bên dưới báo đỏ thay vì crash cả bộ test.
        guard let data = try? Data(contentsOf: url),
              let doc = try? JSONDecoder().decode(Expected.self, from: data)
        else { return Expected(whiteSpace: [], verdicts: [:]) }
        return doc
    }()

    /// Khoá `exams/<tên>` và `invalid/<tên>` của mọi fixture có thật trên đĩa.
    static func fixtureKeys() throws -> Set<String> {
        let exams = try ExamValidatorFixtureTests.validExamDirectories().map { "exams/\($0.lastPathComponent)" }
        let invalidDir = Fixtures.root.appendingPathComponent("invalid", isDirectory: true)
        let invalid = try FileManager.default.contentsOfDirectory(atPath: invalidDir.path)
            .filter { $0.hasSuffix(".json") }
            .map { "invalid/\($0.dropLast(".json".count))" }
        return Set(exams + invalid)
    }

    /// Tên fixture (bỏ tiền tố thư mục) trong `folder` có kết luận `verdict`.
    static func names(_ verdict: String, in folder: String) -> Set<String> {
        Set(expected.verdicts.filter { $0.value == verdict && $0.key.hasPrefix("\(folder)/") }
            .map { String($0.key.dropFirst(folder.count + 1)) })
    }

    @Test("File kỳ vọng đọc được, liệt kê đúng mọi fixture, chỉ dùng 4 kết luận đã định")
    func coversEveryFixture() throws {
        #expect(!Self.expected.verdicts.isEmpty, "Không đọc được fixtures/expected-verdicts.json")
        #expect(Set(Self.expected.verdicts.keys) == (try Self.fixtureKeys()))
        #expect(Set(Self.expected.verdicts.values).isSubset(of: ["valid", "error", "undecodable", "examfile"]))
    }

    @Test("Khoảng trắng của app (Unicode White_Space của Swift) trùng khoá whiteSpace mà script dùng")
    func whiteSpaceMatchesScript() {
        var listed = Set<UInt32>()
        for item in Self.expected.whiteSpace {
            let bounds = item.split(separator: "-").compactMap { UInt32($0, radix: 16) }
            #expect((1 ... 2).contains(bounds.count), "\(item)")
            if let lo = bounds.first, let hi = bounds.last { listed.formUnion(lo ... hi) }
        }
        var swift = Set<UInt32>()
        for value in UInt32(0) ... 0x10FFFF {
            if let scalar = Unicode.Scalar(value), scalar.properties.isWhitespace { swift.insert(value) }
        }
        #expect(!listed.isEmpty)
        #expect(listed == swift)
    }

    @Test("Mỗi fixture: model + ExamValidator cho đúng kết luận trong file kỳ vọng",
          arguments: expected.verdicts.keys.sorted())
    func appVerdict(key: String) throws {
        let verdict = try #require(Self.expected.verdicts[key])
        let isPackage = key.hasPrefix("exams/")
        let url = isPackage
            ? Fixtures.root.appendingPathComponent("\(key)/exam.json")
            : Fixtures.root.appendingPathComponent("\(key).json")
        // Đề trong exams/ là gói đã giải nén: kiểm cả ảnh có trong media/ như script.
        let media = isPackage ? ExamValidatorFixtureTests.mediaSet(of: url.deletingLastPathComponent()) : nil
        let data = try Fixtures.data(url)
        switch verdict {
        case "undecodable":
            #expect(throws: DecodingError.self) { try ExamJSON.decode(data) }
        case "valid":
            let issues = ExamValidator.validate(try ExamJSON.decode(data), availableMedia: media)
            #expect(!issues.hasErrors, "\(issues.map(\.message))")
        case "error":
            let issues = ExamValidator.validate(try ExamJSON.decode(data), availableMedia: media)
            #expect(issues.hasErrors)
        case "examfile":
            // Phần ExamFile (phiên bản, trường lạ): validator không báo gì; ExamFileTests kiểm việc từ chối.
            #expect(ExamValidator.validate(try ExamJSON.decode(data), availableMedia: media).isEmpty)
        default:
            Issue.record("Kết luận lạ \(verdict) cho \(key)")
        }
    }

    @Test("Bảng kỳ vọng khớp ba nhóm phân loại fixtures/invalid của ExamValidatorFixtureTests")
    func consistentWithClassification() {
        #expect(Self.names("error", in: "invalid") == Set(ExamValidatorFixtureTests.caughtByValidator.keys))
        #expect(Self.names("undecodable", in: "invalid") == Set(ExamValidatorFixtureTests.rejectedByDecoder))
        #expect(Self.names("examfile", in: "invalid") == Set(ExamValidatorFixtureTests.handledByExamFile))
        #expect(Self.names("valid", in: "invalid").isEmpty, "Fixture trong invalid/ không được là valid")
    }

    @Test("Đề biên khoảng trắng: ZWSP, U+001C, U+180E, U+FEFF không phải trống; chỉ có hai warning")
    func whiteSpaceBoundaryFixture() throws {
        let exam = try ExamJSON.decode(Fixtures.data(Fixtures.exam("bien-khoang-trang")))
        let issues = ExamValidator.validate(exam, availableMedia: [])
        #expect(issues.map(\.code) == [.duplicateSectionTitle, .multipleHasSingleCorrect])
        #expect(!issues.hasErrors)
    }
}
