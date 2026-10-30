import ExamFile
import ExamKit
import Foundation
@testable import InterfaceCore
import LibraryData
import Testing

/// Câu báo lỗi của lõi (ExamKit, ExamFile) và LibraryData dựng ở tầng giao diện bằng chữ của catalog theo mã (bước 7b,
/// accessibility-localization.md phương án 2). Tiến trình test khoá tiếng Việt (ngôn ngữ nguồn): mỗi câu phải trùng từng
/// chữ với câu tiếng Việt của lõi/LibraryData cho cùng đầu vào (chữ người dùng thấy không đổi qua bước 7b), trừ số từ
/// 1.000 trở lên: có ngăn nghìn theo ngôn ngữ giao diện.
@Suite("Lỗi của lõi và Thư viện: chữ của catalog theo mã")
struct ErrorMessagesTests {
    // MARK: - Đề mẫu sinh đủ mọi mã kiểm đề

    private static let ids = (0 ..< 16).map { UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", $0 + 1))! }

    private static func options(_ count: Int) -> [Option] {
        (0 ..< count).map { Option(id: OptionID(index: min($0, 25))!, text: "Lựa chọn \($0 + 1)") }
    }

    private static func letters(_ text: String) -> [OptionID] { text.map { OptionID($0)! } }

    private static func question(_ id: Int, type: QuestionType = .single, text: String = "Câu?", image: String? = nil,
                                 options: [Option] = options(3), correct: String = "A", explanation: String? = nil)
        -> Question
    {
        Question(id: ids[id], type: type, text: text, image: image, options: options, correct: letters(correct),
                 explanation: explanation)
    }

    /// Các đề, mỗi đề vi phạm một nhóm quy tắc; gộp lại đủ mọi `IssueCode`.
    static var invalidExams: [Exam] {
        let base = Exam(id: ids[0], title: "Đề", code: "KTC-01", passPercent: 70, timeLimitMinutes: 30, sections: [
            ExamSection(id: ids[1], title: "Phần A", questions: [question(2)]),
        ])
        var exams: [Exam] = []
        var exam = base
        exam.title = ""
        exam.code = "KTC 01"
        exam.passPercent = 150
        exam.timeLimitMinutes = 0
        exams.append(exam)
        exam = base
        exam.title = String(repeating: "a", count: 201)
        exam.code = ""
        exam.passPercent = -5
        exam.instructions = String(repeating: "h", count: 4001)
        exams.append(exam)
        exam = base
        exam.sections = []
        exams.append(exam)
        // Phần: tiêu đề trống, quá dài, trùng; phần không có câu; id trùng với đề và với câu.
        exam = base
        exam.sections = [
            ExamSection(id: ids[1], title: " ", questions: [question(2)]),
            ExamSection(id: ids[3], title: String(repeating: "b", count: 201), questions: []),
            ExamSection(id: ids[4], title: "Phần A", questions: [question(5)]),
            ExamSection(id: ids[6], title: "  phần a ", questions: [question(7)]),
            ExamSection(id: ids[0], title: "Phần id trùng đề", questions: [question(2), question(5)]),
        ]
        exams.append(exam)
        // Câu và lựa chọn.
        var tooMany = options(27)
        tooMany[26] = Option(id: OptionID("Z")!, text: "Lựa chọn 27")
        var outOfOrder = options(3)
        outOfOrder[1] = Option(id: OptionID("E")!, text: "")
        outOfOrder[2] = Option(id: OptionID("C")!, text: String(repeating: "o", count: 4001))
        exam = base
        exam.sections = [ExamSection(id: ids[1], title: "Phần A", questions: [
            question(2, text: " ", explanation: String(repeating: "g", count: 10001)),
            question(3, text: String(repeating: "q", count: 10001), image: "anh.png", options: options(1), correct: ""),
            question(4, image: "media/0123456789abcdef.png", options: tooMany, correct: "AAD"),
            question(5, type: .multiple, correct: "B"),
            question(6, options: outOfOrder, correct: "AB"),
            question(7, correct: "BXX"),
        ])]
        exams.append(exam)
        return exams
    }

    static var allIssues: [ValidationIssue] {
        invalidExams.flatMap { ExamValidator.validate($0, availableMedia: []) }
    }

    @Test("Các đề thử sinh đủ mọi mã kiểm đề, cả hai loại vị trí của tiêu đề")
    func issuesCoverEveryCode() {
        let issues = Self.allIssues
        #expect(Set(issues.map(\.code)) == Set(IssueCode.allCases))
        #expect(issues.contains { $0.code == .titleEmpty && $0.location == .exam })
        #expect(issues.contains { $0.code == .titleEmpty && $0.location != .exam })
        #expect(issues.contains { $0.code == .titleTooLong && $0.location != .exam })
        #expect(issues.contains { $0.code == .duplicateID && $0.arguments.firstLocation == .exam })
        #expect(issues.contains {
            guard $0.code == .duplicateID, case .question? = $0.arguments.firstLocation else { return false }
            return true
        })
    }

    /// Mọi số trong vấn đề nhỏ hơn 1.000 (không có ngăn nghìn): câu của catalog trùng câu của lõi.
    private static func hasLargeNumber(_ issue: ValidationIssue) -> Bool {
        [issue.arguments.value, issue.arguments.limit].contains { ($0 ?? 0) >= 1000 }
    }

    @Test("Mỗi mã kiểm đề: tiếng Việt trùng message của ExamValidator (số < 1.000)")
    func everyIssueCodeMatchesCore() {
        let issues = Self.allIssues.filter { !Self.hasLargeNumber($0) }
        // Bốn mã độ dài luôn có giới hạn từ 1.000 (4.000, 10.000 ký tự): kiểm ở `largeNumbersAreGrouped`.
        let lengthCodes: Set<IssueCode> = [.instructionsTooLong, .questionTextTooLong, .explanationTooLong, .optionTextTooLong]
        #expect(Set(issues.map(\.code)).union(lengthCodes) == Set(IssueCode.allCases))
        for issue in issues {
            #expect(ErrorMessages.message(for: issue) == issue.message, "\(issue.code.rawValue)")
        }
    }

    @Test("Số từ 1.000 trong câu kiểm đề có ngăn nghìn theo ngôn ngữ giao diện")
    func largeNumbersAreGrouped() {
        let large = Self.allIssues.filter(Self.hasLargeNumber)
        #expect(Set(large.map(\.code)) == [.instructionsTooLong, .questionTextTooLong, .explanationTooLong, .optionTextTooLong])
        for issue in large {
            let message = ErrorMessages.message(for: issue)
            #expect(message != issue.message, "\(issue.code.rawValue)")
            #expect(message == Self.groupingThousands(issue.message), "\(issue.code.rawValue)")
        }
        let instructions = Self.allIssues.first { $0.code == .instructionsTooLong }
        #expect(instructions.map(ErrorMessages.message) == "Hướng dẫn dài 4.001 ký tự. Rút gọn còn tối đa 4.000 ký tự.")
    }

    /// Thêm dấu chấm ngăn nghìn vào mọi dãy chữ số từ 4 chữ số (câu của lõi chỉ có số đếm, không có số thập phân).
    private static func groupingThousands(_ text: String) -> String {
        text.replacing(#/\d{4,}/#) { match in
            Int(match.output).map { InterfaceLocale.number($0, locale: Locale(identifier: "vi")) } ?? String(match.output)
        }
    }

    /// Review độc lập #51 N-d: nơi xuất hiện trước là một phần (`firstPlace(.section)`).
    @Test("id trùng với id của một phần: \"trùng với id của phần N\", trùng câu của lõi")
    func duplicateIDFirstSeenAtSection() {
        let exam = Exam(id: Self.ids[0], title: "Đề", passPercent: 70, timeLimitMinutes: 30, sections: [
            ExamSection(id: Self.ids[1], title: "Phần A", questions: [Self.question(2)]),
            ExamSection(id: Self.ids[1], title: "Phần B", questions: [Self.question(1)]),
        ])
        let duplicates = ExamValidator.validate(exam).filter { $0.code == .duplicateID }
        #expect(duplicates.count == 2)
        for issue in duplicates {
            #expect(issue.arguments.firstLocation == .section(index: 0, id: Self.ids[1]))
            #expect(ErrorMessages.message(for: issue) == issue.message)
            #expect(ErrorMessages.message(for: issue).contains("trùng với id của phần 1."))
        }
        #expect(duplicates.map { ErrorMessages.message(for: $0) }.first?.hasPrefix("Phần 2: id ") == true)
        #expect(duplicates.map { ErrorMessages.message(for: $0) }.last?.hasPrefix("Phần 2, câu 1: id ") == true)
    }

    @Test("Vấn đề dựng tay thiếu đối số: câu chung theo mã, không lộ message")
    func issueWithoutArgumentsFallsBack() {
        let issue = ValidationIssue(code: .codeInvalid, location: .exam, message: "chữ trơn")
        #expect(ErrorMessages.message(for: issue) == "Đề có lỗi (codeInvalid).")
    }

    // MARK: - ExamFile

    static let examFileErrors: [ExamFileError] = {
        let issues = ExamValidator.validate(invalidExams[0])
        return [
            .notAZipArchive, .missingManifest, .corruptedEntry("media/a.png"),
            .invalidJSON(.notUTF8), .invalidJSON(.unparsable(systemDescription: "Lỗi hệ thống.")),
            .invalidJSON(.rootNotObject), .invalidJSON(.missingFormatVersion), .invalidJSON(.formatVersionNotInteger),
            .invalidJSON(.trailingCommas([JSONProblem.rootPath, "sections[0]"])),
            .invalidJSON(.missingKey(path: "sections[0].questions[1]", key: "text")),
            .invalidJSON(.missingKey(path: JSONProblem.rootPath, key: "title")),
            .invalidJSON(.typeMismatch(path: "passPercent", expectedType: "Int")),
            .invalidJSON(.valueMissing(path: "title", expectedType: "String")),
            .invalidJSON(.invalidValue(path: "sections[0].questions[0].type", detail: "Sai giá trị.")),
            .invalidJSON(.other("Lỗi lạ")),
            .unsupportedVersion(found: 7, supported: 1), .invalidVersion(-3), .invalidVersion(0),
            .unknownFields(["ghiChu", "sections[0].questions[0].hint"]), .duplicateJSONKeys(["title"]),
            .nullValues(["code", "sections[0].title"]), .missingMedia(["media/0123456789abcdef.png"]),
            .invalidMediaPath(["anh.png"]),
            .validationFailed([]), .validationFailed(Array(issues.prefix(1))), .validationFailed(issues),
            .duplicateEntry("exam.json"),
            .tooLarge(entry: ExamPackageLimits.entryCountName, limit: 20),
            .tooLarge(entry: ExamPackageLimits.totalSizeName, limit: 100),
            .tooLarge(entry: "media/a.png", limit: 50),
            .tooDeep(limit: 32),
            .migrationFailed(from: 1, reason: .missingStep), .migrationFailed(from: 2, reason: .invalidResult),
            .migrationFailed(from: 3, reason: .stepFailed("Boom()")),
            .unsupportedImageType("bmp"),
            .writeFailed(.encodingFailed("E")), .writeFailed(.archiveUnavailable), .writeFailed(.archiveFailed("Z")),
            .writeFailed(.replaceFailed(fileName: "de.exam", systemReason: "Permission denied")),
        ]
    }()

    @Test("Mỗi lỗi đọc/ghi gói đề: tiếng Việt trùng errorDescription của ExamFile")
    func everyExamFileErrorMatchesCore() {
        for error in Self.examFileErrors {
            #expect(ErrorMessages.message(for: error) == error.errorDescription, "\(error)")
        }
        #expect(ErrorMessages.message(for: ExamFileError.tooLarge(entry: "exam.json", limit: 33_554_432))
            == "Gói đề vượt giới hạn ở exam.json (tối đa 33.554.432).")
    }

    /// Review độc lập #51 N-a: số phiên bản định dạng là mã, không ngăn nghìn (như mã định danh).
    @Test("Phiên bản định dạng từ 1.000: chữ số trơn, trùng câu của lõi")
    func formatVersionsArePlainDigits() {
        let errors: [ExamFileError] = [
            .unsupportedVersion(found: 1000, supported: 1), .invalidVersion(-1000),
            .migrationFailed(from: 1000, reason: .missingStep), .migrationFailed(from: 1234, reason: .invalidResult),
        ]
        for error in errors {
            #expect(ErrorMessages.message(for: error) == error.errorDescription, "\(error)")
        }
        #expect(ErrorMessages.message(for: errors[0]) == "Đề cần phiên bản app mới hơn (định dạng v1000, app này hiểu tới v1).")
        #expect(ErrorMessages.message(for: errors[1]) == "formatVersion không hợp lệ: -1000 (phải từ 1 trở lên).")
        #expect(ErrorMessages.message(for: LibraryFileProblem.needsNewerApp(found: 1000, supported: 1))
            == "Đề cần phiên bản app mới hơn (định dạng v1000, app này hiểu tới v1).")
    }

    // MARK: - LibraryData

    static let fileReasons: [FileProblemReason] = [
        .package(.notAZipArchive), .package(.unknownFields(["la"])),
        .validationFailed(errorCount: 0, first: nil),
        .validationFailed(errorCount: 1, first: allIssues.first),
        .validationFailed(errorCount: 3, first: allIssues.first),
        .unreadable(systemDescription: "Không có quyền."),
        .fileNotFound(fileName: "de.exam"), .inTrash(fileName: "de.exam"), .bookmarkFailed(fileName: "de.exam"),
        .readTimedOut(fileName: "de.exam"), .sampleUnreadable("Lỗi."), .sampleNotWritten(fileName: "Đề mẫu.exam"),
        .stored("Chữ lưu từ lần trước."),
    ]

    @Test("Lý do file của Thư viện, sự cố kho, lỗi lệnh: tiếng Việt trùng logMessage của LibraryData")
    func libraryMessagesMatchData() {
        for reason in Self.fileReasons {
            #expect(ErrorMessages.message(for: reason) == reason.logMessage, "\(reason)")
            #expect(ErrorMessages.message(for: LibraryFileProblem.corrupt(reason: reason)) == reason.logMessage)
            #expect(ErrorMessages.message(for: LibraryFileProblem.invalid(reason: reason)) == reason.logMessage)
        }
        #expect(FileProblemReason(ExamFileError.validationFailed(Self.allIssues))
            == .validationFailed(errorCount: Self.allIssues.count, first: Self.allIssues.first))
        let newer = LibraryFileProblem.needsNewerApp(found: 2, supported: 1)
        #expect(ErrorMessages.message(for: newer) == newer.logMessage)
        let errors: [LibraryError] = [
            .entryNotFound(examID: Self.ids[0]), .notAnExamFile(URL(fileURLWithPath: "/tmp/ghi chú.txt")),
            .unusableFile(.corrupt(reason: .package(.notAZipArchive))), .unusableFile(newer),
            .differentExam(expectedTitle: "Đề gốc", foundTitle: "Đề khác"), .alreadyInLibrary(examID: Self.ids[0]),
            .duplicateAttempt(id: Self.ids[1]), .storage("Đĩa đầy."),
        ]
        for error in errors {
            #expect(ErrorMessages.message(for: error) == error.logMessage, "\(error)")
            #expect(ErrorMessages.message(for: error as any Error) == error.logMessage)
        }
        let issues: [LibraryStoreIssue] = [
            .recoveredFromBrokenStore(brokenStoreURL: URL(fileURLWithPath: "/tmp/kho/Library.store.broken-1")),
            .temporaryStore(reason: "Không có quyền."),
        ]
        for issue in issues {
            #expect(ErrorMessages.message(for: issue) == issue.logMessage, "\(issue)")
        }
    }

    @Test("Lỗi bất kỳ: lỗi của Exam Suite theo mã, lỗi khác dùng câu của hệ thống")
    func anyErrorDispatch() {
        #expect(ErrorMessages.message(for: ExamFileError.missingManifest as any Error)
            == "Gói đề thiếu file exam.json ở gốc.")
        let cocoa = CocoaError(.fileReadNoPermission)
        #expect(ErrorMessages.message(for: cocoa) == cocoa.localizedDescription)
    }

    // MARK: - Đường tra theo ngôn ngữ cố định

    /// Khoá của câu báo nằm trong catalog nguồn của LibraryFeature (đã đồng bộ bằng `-exportLocalizations`), và tra khoá
    /// ngôn ngữ `en` ra câu tiếng Anh đủ đối số (bước 7c), kể cả substitution ("1 option" / "3 options").
    @Test("Khoá có trong catalog; tra en ra câu tiếng Anh đủ đối số")
    func englishLookupPath() throws {
        let keys = try Self.catalogKeys()
        for key in [
            "Gói đề thiếu file exam.json ở gốc.",
            "Phần %lld, câu %lld chưa có đáp án đúng. Đánh dấu ít nhất một lựa chọn là đúng.",
            "Đề có %lld lỗi, không mở được. Lỗi đầu tiên: %@",
            "Không dùng được file này: %@",
        ] {
            #expect(keys.contains(key), "\(key)")
        }
        #expect(catalogText("Phần \(1), câu \(12) chưa có đáp án đúng. Đánh dấu ít nhất một lựa chọn là đúng.", language: "en")
            == "Section 1, question 12 has no correct answer. Mark at least one option as correct.")
        #expect(catalogText("Gói đề thiếu file exam.json ở gốc.", language: "en") == "The exam package has no exam.json file at its root.")
        #expect(catalogText("Phần \(1), câu \(2) có \(1) lựa chọn. Cần ít nhất \(2) lựa chọn.", language: "en")
            == "Section 1, question 2 has 1 option. At least 2 options are required.")
        #expect(catalogText("Phần \(1), câu \(2) có \(0) lựa chọn. Cần ít nhất \(2) lựa chọn.", language: "en")
            == "Section 1, question 2 has 0 options. At least 2 options are required.")
        #expect(catalogText("Đề có \(3) lỗi, không mở được. Lỗi đầu tiên: \("X")", language: "en")
            == "The exam has 3 errors and can’t be opened. First error: X")
    }

    /// Khoá của catalog InterfaceCore (`ErrorMessages` tách từ LibraryFeature sang đó ở bước I1 của plan iOS).
    static func catalogKeys() throws -> Set<String> {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("SharedFeatures/Sources/InterfaceCore/Resources/Localizable.xcstrings")
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        return Set((object?["strings"] as? [String: Any] ?? [:]).keys)
    }
}
