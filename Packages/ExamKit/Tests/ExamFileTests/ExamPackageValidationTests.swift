import ExamKit
import Foundation
import Testing
@testable import ExamFile

/// ExamFile gọi `ExamValidator` (docs/product/exam-format.md, mục Ràng buộc liên trường):
/// bản Học viên (`strict`) từ chối đề có lỗi, bản Admin (`lenient`) mở được và báo qua
/// `ExamPackage.validationIssues`.
@Suite("ExamPackageReader: ràng buộc liên trường")
struct ExamPackageValidationTests {
    /// Đề mẫu hợp lệ trong fixtures/exams.
    static let validFixtures = ["kien-thuc-chung", "toi-thieu"]

    /// Fixture sai mà model giải mã được, với mã lỗi validator mong đợi (theo thứ tự).
    /// Liệt kê tên cụ thể thay vì duyệt cả thư mục: fixture mới phải được thêm có chủ ý.
    static let invalidFixtures: [String: [IssueCode]] = [
        "correct-not-in-options": [.correctAnswerNotInOptions],
        "single-with-two-correct": [.singleHasMultipleCorrect],
        "option-ids-out-of-order": [.optionIDOutOfOrder, .optionIDOutOfOrder],
        "duplicate-question-id": [.duplicateID],
        "one-option": [.tooFewOptions, .correctAnswerNotInOptions],
    ]

    private static func packInvalid(_ name: String) throws -> Data {
        try Zip.make([("exam.json", RepoPaths.invalidJSON(name))])
    }

    @Test("Đề mẫu: strict đọc được, validationIssues không có error", arguments: validFixtures)
    func validFixture(name: String) throws {
        let data = try Zip.packFixture(name)
        let strict = try ExamPackageReader.read(data, mode: .strict)
        #expect(!strict.validationIssues.hasErrors, "\(strict.validationIssues.map(\.message))")
        let lenient = try ExamPackageReader.read(data, mode: .lenient)
        #expect(!lenient.validationIssues.hasErrors)
    }

    @Test("Fixture sai: strict ném validationFailed đúng mã lỗi", arguments: invalidFixtures.keys.sorted())
    func strictRejects(name: String) throws {
        let data = try Self.packInvalid(name)
        do {
            _ = try ExamPackageReader.read(data, mode: .strict)
            Issue.record("\(name): strict phải từ chối")
        } catch let ExamFileError.validationFailed(issues) {
            #expect(issues.map(\.code) == Self.invalidFixtures[name])
            #expect(issues.allSatisfy { $0.severity == .error })
        }
    }

    @Test("Fixture sai: lenient đọc được, validationIssues chứa đúng mã lỗi", arguments: invalidFixtures.keys.sorted())
    func lenientReports(name: String) throws {
        let package = try ExamPackageReader.read(Self.packInvalid(name), mode: .lenient)
        #expect(package.validationIssues.map(\.code) == Self.invalidFixtures[name])
        #expect(package.validationIssues.hasErrors)
    }

    @Test("Lỗi strict giống hệt danh sách error của validator, theo đúng thứ tự")
    func strictIssuesMatchValidator() throws {
        let data = try Self.packInvalid("one-option")
        let expected = try ExamPackageReader.read(data, mode: .lenient).validationIssues
            .filter { $0.severity == .error }
        #expect(throws: ExamFileError.validationFailed(expected)) {
            try ExamPackageReader.read(data, mode: .strict)
        }
    }

    @Test("Chỉ có warning thì strict vẫn mở; warning không nằm trong lỗi")
    func warningsDoNotBlock() throws {
        // Hai section cùng tiêu đề → duplicateSectionTitle (warning).
        let json = try JSONEdit.modify(RepoPaths.examJSON("toi-thieu")) { exam in
            var sections = exam["sections"] as! [[String: Any]]
            var copy = sections[0]
            copy["id"] = "44444444-5555-4666-8777-888888888888"
            var questions = copy["questions"] as! [[String: Any]]
            questions[0]["id"] = "55555555-6666-4777-8888-999999999999"
            copy["questions"] = questions
            sections.append(copy)
            exam["sections"] = sections
        }
        let package = try ExamPackageReader.read(Zip.make([("exam.json", json)]), mode: .strict)
        #expect(package.validationIssues.map(\.code) == [.duplicateSectionTitle])
        #expect(!package.validationIssues.hasErrors)
    }

    @Test("Strict thiếu ảnh: vẫn báo missingMedia như trước, không báo lại qua validator")
    func missingMediaReportedOnce() throws {
        let data = try Zip.make([("exam.json", RepoPaths.examJSON("kien-thuc-chung"))])
        #expect(throws: ExamFileError.missingMedia(["media/9d5dc894e10f060d.png"])) {
            try ExamPackageReader.read(data, mode: .strict)
        }
        let lenient = try ExamPackageReader.read(data, mode: .lenient)
        #expect(lenient.missingMedia == ["media/9d5dc894e10f060d.png"])
        #expect(lenient.validationIssues.map(\.code) == [.imageNotFound])
    }

    @Test("validationIssues không tham gia ==")
    func issuesNotPartOfEquality() throws {
        let valid = try ExamPackageReader.read(Zip.packFixture("kien-thuc-chung"), mode: .lenient)
        var stripped = valid
        stripped.media = [:]
        #expect(stripped.validationIssues != valid.validationIssues)
        stripped.media = valid.media
        #expect(stripped == valid)
    }

    @Test("Writer không gọi validator: đề có lỗi vẫn ghi được, đọc lại lenient giữ nguyên lỗi")
    func writerDoesNotValidate() throws {
        let package = try ExamPackageReader.read(Self.packInvalid("correct-not-in-options"), mode: .lenient)
        let data = try ExamPackageWriter.write(package)
        let reread = try ExamPackageReader.read(data, mode: .lenient)
        #expect(reread == package)
        #expect(reread.validationIssues.map(\.code) == [.correctAnswerNotInOptions])
    }

    @Test("errorDescription nêu số lỗi và lỗi đầu tiên")
    func errorDescription() throws {
        let issues = try ExamPackageReader.read(Self.packInvalid("one-option"), mode: .lenient).validationIssues
        #expect(issues.count == 2)
        let description = try #require(ExamFileError.validationFailed(issues).errorDescription)
        #expect(description.contains("2 lỗi"))
        #expect(description.contains(issues[0].message))

        let single = try #require(ExamFileError.validationFailed([issues[0]]).errorDescription)
        #expect(single.contains("1 lỗi"))
        #expect(single.contains(issues[0].message))
    }
}
