import AuthoringData
@testable import AuthoringFeature
import ExamImport
import ExamKit
import Foundation
import InterfaceCore
import Testing

/// Câu báo của AuthoringData và ExamImport dựng ở tầng giao diện bằng chữ của catalog theo mã (bước 7b,
/// accessibility-localization.md phương án 2). Tiến trình test khoá tiếng Việt: mỗi câu trùng từng chữ với `logMessage`
/// của target dữ liệu cho cùng đầu vào (số dưới 1.000), nên chữ người dùng thấy không đổi qua bước 7b.
@Suite("Lỗi soạn đề và import: chữ của catalog theo mã")
struct AuthoringMessagesTests {
    // MARK: - Sửa đề

    static let editErrors: [ExamEditError] = [
        .sectionNotFound(UUID(uuidString: "AAAAAAAA-0000-4000-8000-000000000001")!),
        .questionNotFound(UUID(uuidString: "AAAAAAAA-0000-4000-8000-000000000002")!),
        .invalidSectionIndex(2), .invalidQuestionPath(QuestionPath(section: 1, question: 4)), .invalidOptionIndex(3),
        .invalidPermutation, .tooManyOptions, .unsupportedImageType("bmp"),
        .imageTooLarge(bytes: 13_107_200, limit: 52_428_800), .imageTooLarge(bytes: 52_428_801, limit: 52_428_800),
        .packageTooLarge(limit: 1 << 30), .tooManyImages(limit: 500), .mediaNameCollision("media/0123456789abcdef.png"),
    ]

    @Test("Lỗi sửa đề: tiếng Việt trùng logMessage của AuthoringData")
    func editErrorsMatchData() {
        for error in Self.editErrors {
            #expect(AuthoringMessages.message(for: error) == error.logMessage, "\(error)")
            #expect(AuthoringMessages.message(for: error as any Error) == error.logMessage)
        }
        #expect(AuthoringMessages.message(for: ExamEditError.imageTooLarge(bytes: 13_107_200, limit: 52_428_800))
            == "Ảnh nặng 12,5 MiB, vượt giới hạn 50 MiB mỗi ảnh.")
        #expect(AuthoringMessages.mebibytes(13_107_200, locale: Locale(identifier: "en")) == "12.5")
        // Số mục từ 1.000 có ngăn nghìn theo ngôn ngữ giao diện (AuthoringData ghi số trơn).
        #expect(AuthoringMessages.message(for: ExamEditError.tooManyImages(limit: 20_000))
            == "Đề đã có quá nhiều ảnh (gói tối đa 20.000 mục).")
    }

    // MARK: - Import: lỗi file

    static let importErrors: [ImportError] = [
        .unsupportedFileType("pdf"), .unreadableFile(.system("Không có quyền.")),
        .unreadableFile(.cannotOpen(fileName: "de.docx")), .notUTF8, .notADocx, .corruptedPart("word/document.xml"),
        .invalidXML(part: "word/document.xml", detail: .declaresDTD),
        .invalidXML(part: "word/document.xml", detail: .declaresEntity),
        .invalidXML(part: "word/numbering.xml", detail: .parser("Lỗi cú pháp.")),
        .invalidXML(part: "word/numbering.xml", detail: .parser(nil)),
        .tooLarge(what: .textFile, limit: 10), .tooLarge(what: .vceFile, limit: 100),
        .tooLarge(what: .docxEntryCount, limit: 20), .tooLarge(what: .docxTotalSize, limit: 512),
        .tooLarge(what: .docxPart("word/document.xml"), limit: 512),
        .tooDeep(part: "word/document.xml", limit: 128),
        .noQuestions(dropped: 0), .noQuestions(dropped: 2), .tooLarge(what: .oefFile, limit: 300),
        .unreadableOEF(.legacyFormat), .unreadableOEF(.malformed(offset: 12)), .unreadableOEF(.noQuestions),
        .unreadableOEF(.tooLarge(.elements, limit: 9)),
    ] + allVceProblems.map { ImportError.unreadableVCE($0) }

    @Test("Lỗi import: tiếng Việt trùng logMessage của ExamImport")
    func importErrorsMatchData() {
        for error in Self.importErrors {
            #expect(AuthoringMessages.message(for: error) == error.logMessage, "\(error)")
        }
        #expect(AuthoringMessages.message(for: ImportError.tooLarge(what: .textFile, limit: 33_554_432))
            == "File vượt giới hạn ở file .txt (tối đa 33.554.432 byte).")
        // Review độc lập #51 N-b: giới hạn số entry của .docx đếm entry, không phải byte.
        #expect(AuthoringMessages.message(for: ImportError.tooLarge(what: .docxEntryCount, limit: 20_000))
            == "File vượt giới hạn ở số entry trong file .docx (tối đa 20.000 entry).")
    }

    // MARK: - .vce

    static let allVceFields: [VceField] = [
        .fileHeader, .fileEnd, .code, .title, .passingScore, .timeLimit, .examVersion, .dates, .examDescription,
        .sectionCount, .sectionID, .sectionName, .sectionNameWithID(12345), .groupCount, .group, .groupName,
        .groupNameNumber(2), .questionCount, .questionSize(7), .questionRecord(7), .questionHeader, .questionSection,
        .questionType, .questionContent, .answer, .optionCount, .questionEnd, .caseTitle, .contentBlock, .questionText,
        .option(index: 0), .option(index: 25), .option(index: 26), .explanation, .questionANSIText,
        .lengthOf(.code), .lengthOf(.lengthOf(.questionContent)),
    ]

    static let allVceProblems: [VceProblem] = [
        .empty, .tooShort, .unknownMagic, .sizeMismatch(declared: 512, actual: 300), .checksumMismatch,
        .badString(.title), .invalidSectionCount(-1), .invalidGroupCount(999), .invalidQuestionCount(-2),
        .trailingBytes(3), .questionTrailingBytes(5), .blockCountMismatch(blocks: 4, options: 3), .noQuestions,
        .noUsableQuestions(total: 2, unsupportedType: 1, unreadable: nil, noOptions: 1),
        .noUsableQuestions(total: 3, unsupportedType: nil, unreadable: 3, noOptions: nil),
        .badLength(.answer, -5), .badLength(.questionRecord(2), 700),
    ] + allVceFields.map { VceProblem.truncated($0) }

    @Test("Tên trường .vce: mọi loại, tiếng Việt trùng logName (id phần giữ chữ số trơn)")
    func vceFieldNamesMatchData() {
        for field in Self.allVceFields {
            #expect(AuthoringMessages.name(field) == field.logName, "\(field)")
        }
        #expect(AuthoringMessages.name(.sectionNameWithID(12345)) == "tên phần id 12345")
    }

    static let allRVFItems: [RVFSkip.Item] = [
        .unknownData, .negativeLineCount, .documentProperties, .textMissingFields, .hexUnicodeText,
        .unsupportedTextStorage(query: 2), .textShorterThanDeclared, .nonText(type: -1), .nonText(type: -3),
        .nonText(type: -4), .nonText(type: -6), .nonText(type: -12),
    ]

    static var allRVFSkips: [RVFSkip] {
        let causes: [RVFSkip.Cause] = [.none, .fewerLinesThanSpecification(1), .blockEndedEarly, .crossedNextRecord]
        return allRVFItems.flatMap { item in
            causes.flatMap { cause in [false, true].map { RVFSkip(item, cause: cause, stopped: $0) } }
        }
    }

    // MARK: - Import: mục báo cáo

    static let shift = OptionShift(
        originalFirst: "B", originalLast: "E", newLast: "D", firstLine: 3,
        answerBefore: OptionID.list("CF"), answerAfter: OptionID.list("BF"), unmatched: OptionID.list("F")
    )
    static let mojibake = MojibakeSummary(total: 14, pairs: [
        .init(before: "â€™", after: "’", count: 2),
        .init(before: "Ã©", after: "é", count: 1),
    ], moreKinds: 3)

    static var allDetails: [ImportIssueDetail] {
        var details: [ImportIssueDetail] = [
            .noOptions(misplaced: nil), .noOptions(misplaced: MisplacedOption(letter: OptionID("B")!, line: 12)),
            .noOptions(misplaced: MisplacedOption(letter: OptionID("C")!, line: nil)),
            .textBeforeFirstQuestion(fromLine: 1, toLine: 4), .textWithoutQuestions(fromLine: 2),
            .textAfterAnswerLine, .textAfterAnswerParagraph,
            .optionLabelOutOfOrder(unit: .line, label: OptionID("D")!, expected: OptionID("C")!, appendedTo: OptionID("B")!),
            .optionLabelOutOfOrder(unit: .line, label: OptionID("D")!, expected: nil, appendedTo: OptionID("Z")!),
            .optionLabelOutOfOrder(unit: .paragraph, label: OptionID("D")!, expected: OptionID("C")!, appendedTo: OptionID("B")!),
            .optionLabelOutOfOrder(unit: .paragraph, label: OptionID("A")!, expected: nil, appendedTo: OptionID("Z")!),
            .optionLabelsShifted(shift),
            .optionLabelsShifted(OptionShift(originalFirst: "C", originalLast: "?", newLast: "Z", firstLine: nil,
                                             answerBefore: nil, answerAfter: nil, unmatched: [])),
            .optionLabelsShifted(OptionShift(originalFirst: "B", originalLast: "D", newLast: "C", firstLine: nil,
                                             answerBefore: OptionID.list("B"), answerAfter: OptionID.list("A"), unmatched: [])),
            .tooManyListOptions, .tooManyOptions(count: 30),
            .missingAnswerLine, .missingAnswerInFile, .unreadableAnswer("1, 2"), .unreadableVceAnswer("A-C"),
            .answerHasStrangeCharacters, .conflictingAnswerLine(value: "B", keptLine: 7),
            .conflictingAnswer(value: "B", kept: "A"), .answerWithSeparators(raw: "A, C", letters: OptionID.list("AC")),
            .multipleFlagMismatch(flag: 255, answerCount: 1),
            .invalidDocxCode("KTC 01"), .invalidVceCode("Mã sai"), .unreadablePassingScore("abc"),
            .passingScoreOutOfRange(-1), .unreadableTimeLimit("1h"), .invalidVceTimeLimit(-5), .invalidNumbering(count: 2),
            .tableConverted, .extraImage,
            .imageOutsideQuestionText(.header), .imageOutsideQuestionText(.options),
            .imageOutsideQuestionText(.explanation), .imageOutsideQuestionText(.questionText),
            .unsupportedImageFormat(fileExtension: "emf"), .unsupportedImageFormat(fileExtension: nil),
            .externalImage, .imageOutsideMediaFolder, .missingImage(fileName: "image1.png"),
            .imageTooLarge(fileName: "image2.jpg"),
            .mojibakeFixed(mojibake), .mojibakeSuspected(mojibake),
            .mojibakeFixed(MojibakeSummary(total: 1, pairs: [.init(before: "Ã©", after: "é", count: 1)], moreKinds: 0)),
            .unsupportedQuestionType(7), .unsupportedQuestionType(12345), .unreadableQuestion(nil),
            .formattingDropped(fields: [.questionText, .option(index: 1), .option(index: 30), .explanation]),
            .multipleGroups(count: 3, fallbackSection: "Phần chung"),
            .unnamedSection(id: 4, fallbackSection: "Exam A"), .unknownSectionID(id: 12345, fallbackSection: "Phần chung"),
            .summary(code: .noOptions, count: 500, limit: 100),
            .oefUnknownField("sections[0].questions[2].#9"), .invalidOefCode("MÃ CÓ DẤU"), .oefPassmarkOutOfRange,
            .invalidOefTimeLimit(0), .oefEmptySection(section: 2),
            .oefUntitledSection(section: 3, fallbackSection: "Phần chung"), .oefDuplicateOptionLetter("A"),
            .oefAnswerNotInOptions(["D", "U+0000"]), .oefImageTooLarge,
        ]
        for field in [VceField.title, .code, .sectionNameWithID(3), .groupNameNumber(2), .questionANSIText, .answer] {
            details.append(.assumedEncoding(field: field, hasControlCharacters: false))
            details.append(.assumedEncoding(field: field, hasControlCharacters: true))
        }
        details += allVceProblems.map { ImportIssueDetail.unreadableQuestion($0) }
        details += allRVFSkips.map { ImportIssueDetail.unsupportedContent(field: .option(index: 2), skipped: [$0]) }
        details.append(.unsupportedContent(field: .questionText, skipped: Array(allRVFSkips.prefix(3))))
        return details
    }

    /// Tên case của mục báo cáo (switch đủ case: thêm case mới thì phải thêm vào đây và vào `allDetails`).
    static func caseName(_ detail: ImportIssueDetail) -> String {
        switch detail {
        case .noOptions: "noOptions"
        case .textBeforeFirstQuestion: "textBeforeFirstQuestion"
        case .textWithoutQuestions: "textWithoutQuestions"
        case .textAfterAnswerLine: "textAfterAnswerLine"
        case .textAfterAnswerParagraph: "textAfterAnswerParagraph"
        case .optionLabelOutOfOrder: "optionLabelOutOfOrder"
        case .optionLabelsShifted: "optionLabelsShifted"
        case .tooManyListOptions: "tooManyListOptions"
        case .tooManyOptions: "tooManyOptions"
        case .missingAnswerLine: "missingAnswerLine"
        case .missingAnswerInFile: "missingAnswerInFile"
        case .unreadableAnswer: "unreadableAnswer"
        case .unreadableVceAnswer: "unreadableVceAnswer"
        case .answerHasStrangeCharacters: "answerHasStrangeCharacters"
        case .conflictingAnswerLine: "conflictingAnswerLine"
        case .conflictingAnswer: "conflictingAnswer"
        case .answerWithSeparators: "answerWithSeparators"
        case .multipleFlagMismatch: "multipleFlagMismatch"
        case .invalidDocxCode: "invalidDocxCode"
        case .invalidVceCode: "invalidVceCode"
        case .unreadablePassingScore: "unreadablePassingScore"
        case .passingScoreOutOfRange: "passingScoreOutOfRange"
        case .unreadableTimeLimit: "unreadableTimeLimit"
        case .invalidVceTimeLimit: "invalidVceTimeLimit"
        case .invalidNumbering: "invalidNumbering"
        case .tableConverted: "tableConverted"
        case .extraImage: "extraImage"
        case .imageOutsideQuestionText: "imageOutsideQuestionText"
        case .unsupportedImageFormat: "unsupportedImageFormat"
        case .externalImage: "externalImage"
        case .imageOutsideMediaFolder: "imageOutsideMediaFolder"
        case .missingImage: "missingImage"
        case .imageTooLarge: "imageTooLarge"
        case .mojibakeFixed: "mojibakeFixed"
        case .mojibakeSuspected: "mojibakeSuspected"
        case .assumedEncoding: "assumedEncoding"
        case .unsupportedQuestionType: "unsupportedQuestionType"
        case .unreadableQuestion: "unreadableQuestion"
        case .unsupportedContent: "unsupportedContent"
        case .formattingDropped: "formattingDropped"
        case .multipleGroups: "multipleGroups"
        case .unnamedSection: "unnamedSection"
        case .unknownSectionID: "unknownSectionID"
        case .oefUnknownField: "oefUnknownField"
        case .invalidOefCode: "invalidOefCode"
        case .oefPassmarkOutOfRange: "oefPassmarkOutOfRange"
        case .invalidOefTimeLimit: "invalidOefTimeLimit"
        case .oefEmptySection: "oefEmptySection"
        case .oefUntitledSection: "oefUntitledSection"
        case .oefDuplicateOptionLetter: "oefDuplicateOptionLetter"
        case .oefAnswerNotInOptions: "oefAnswerNotInOptions"
        case .oefImageTooLarge: "oefImageTooLarge"
        case .summary: "summary"
        }
    }

    @Test("Mục báo cáo import: đủ mọi loại, tiếng Việt trùng logMessage của ExamImport")
    func reportDetailsMatchData() {
        let details = Self.allDetails
        #expect(Set(details.map(Self.caseName)).count == 53)
        for detail in details {
            #expect(AuthoringMessages.message(for: detail) == detail.logMessage, "\(detail)")
        }
    }

    @Test("Mục báo cáo có số từ 1.000: ngăn nghìn theo ngôn ngữ giao diện; mã định danh giữ chữ số trơn")
    func reportNumbers() {
        #expect(AuthoringMessages.message(for: .textBeforeFirstQuestion(fromLine: 1, toLine: 1234))
            == "Văn bản trước câu đầu tiên (từ dòng 1 tới dòng 1.234) bị bỏ qua.")
        #expect(AuthoringMessages.message(for: .summary(code: .noOptions, count: 1500, limit: 1000))
            == "… và 1.500 mục tương tự (noOptions) không liệt kê chi tiết: báo cáo chỉ ghi 1.000 mục đầu của mỗi loại.")
        #expect(AuthoringMessages.message(for: .unknownSectionID(id: 12345, fallbackSection: "Phần chung"))
            == ImportIssueDetail.unknownSectionID(id: 12345, fallbackSection: "Phần chung").logMessage)
    }

    @Test("Vị trí trong file gốc: viết hoa chữ đầu như trước")
    func locations() {
        let cases: [(ImportLocation, String)] = [
            (ImportLocation(questionNumber: 12, line: 345), "Câu 12, dòng 345"),
            (ImportLocation(questionNumber: 3), "Câu 3"),
            (ImportLocation(line: 2), "Dòng 2"),
            (ImportLocation(), "Đầu file"),
        ]
        for (location, expected) in cases {
            #expect(AuthoringMessages.location(location) == expected)
            let old = location.logDescription
            #expect(AuthoringMessages.location(location) == old.prefix(1).uppercased() + old.dropFirst())
        }
    }

    /// Báo cáo thật của bộ chuyển đổi: mọi mục ra chữ của catalog trùng câu của ExamImport.
    @Test("Báo cáo của file .txt nhiều vấn đề: mọi dòng trùng câu của ExamImport")
    func realTextReport() async throws {
        let text = """
        Ghi chú đầu file
        Q1:
        Thủ đô?
        B. Hà Nội
        C. Huế
        D. Đà Nẵng
        Correct Answer: C
        Q2:
        Câu không có lựa chọn
        C. sai thứ tự
        Correct Answer: A
        Q3:
        Hai đáp án
        A. Một
        B. Hai
        Correct Answer: X?
        Correct Answer: B
        Q4:
        Ký tự lỗi itâ€™s
        A. Có
        B. Không
        """
        let result = try await ExamImporter.importData(Data(text.utf8), fileName: "de.txt")
        let state = ImportReportState(fileName: "de.txt", report: result.report)
        #expect(state.rows.count >= 5)
        for (row, entry) in zip(state.rows, result.report.entries) {
            #expect(row.message == entry.logMessage)
            let old = entry.location.logDescription
            #expect(row.location == old.prefix(1).uppercased() + old.dropFirst())
        }
    }

    // MARK: - Đường tra theo ngôn ngữ cố định

    @Test("Khoá có trong catalog của AuthoringFeature; tra en ra chữ (tiếng Việt tới bước 7c) đủ đối số")
    func englishLookupPath() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/AuthoringFeature/Resources/Localizable.xcstrings")
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        let keys = Set((object?["strings"] as? [String: Any] ?? [:]).keys)
        for key in [
            "Câu không có dòng \"Correct Answer:\". Câu chưa có đáp án đúng.",
            "File .vce không đọc được: %@. Nếu có bản .docx xuất từ VCE thì import file đó.",
            "Câu %lld, dòng %lld",
        ] {
            #expect(keys.contains(key), "\(key)")
        }
        let english = InterfaceStrings.resolve(
            "Câu \(12), dòng \(345)", bundle: AuthoringFeature.ModuleStrings.bundle, locale: Locale(identifier: "en")
        )
        #expect(english == "Question 12, line 345")
    }
}

private extension OptionID {
    static func list(_ letters: String) -> [OptionID] { letters.map { OptionID($0)! } }
}
