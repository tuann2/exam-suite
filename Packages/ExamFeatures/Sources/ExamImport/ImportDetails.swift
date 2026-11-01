import ExamKit
import Foundation

// Chi tiết có mã của báo cáo import và lỗi import (giai đoạn 5, bước 7b; docs/product/accessibility-localization.md,
// phương án 2): giao diện (AuthoringFeature, `AuthoringMessages`) dựng câu bằng chữ của String Catalog từ các giá trị ở
// đây. `logMessage` là đúng câu tiếng Việt trước bước 7b, cho nhật ký và test; giao diện không hiện câu đó.

// MARK: - Mục báo cáo

/// Lý do và đối số của một mục báo cáo import (`ImportReportEntry`), theo từng loại câu báo.
public enum ImportIssueDetail: Equatable, Sendable {
    // Câu bị bỏ, đầu file, văn bản thừa
    /// `noOptions`: câu không có lựa chọn nào. `misplaced`: dòng/đoạn đầu tiên bắt đầu bằng chữ lựa chọn sai thứ tự
    /// (chữ, và dòng với txt).
    case noOptions(misplaced: MisplacedOption?)
    /// `textBeforeFirstQuestion` (txt): văn bản trước câu đầu tiên, từ dòng tới dòng.
    case textBeforeFirstQuestion(fromLine: Int, toLine: Int)
    /// `textBeforeFirstQuestion` (txt): văn bản từ dòng tới cuối file, không có câu nào.
    case textWithoutQuestions(fromLine: Int)
    /// `unrecognizedText` (txt): văn bản sau dòng đáp án không có nhãn `Explanation:`.
    case textAfterAnswerLine
    /// `unrecognizedText` (docx): văn bản sau dòng đáp án, trước `Explanation/Reference:`.
    case textAfterAnswerParagraph

    // Lựa chọn
    /// `optionLabelOutOfOrder`: dòng (txt) hoặc đoạn (docx) bắt đầu bằng chữ `label` không đúng thứ tự; `expected`
    /// (`nil`: không còn chữ nào); nối vào lựa chọn `appendedTo`.
    case optionLabelOutOfOrder(unit: SourceUnit, label: OptionID, expected: OptionID?, appendedTo: OptionID)
    /// `optionLabelsShifted`: lựa chọn không bắt đầu từ A, được đánh lại.
    case optionLabelsShifted(OptionShift)
    /// `tooManyOptions` (docx): danh sách lựa chọn quá 26 mục.
    case tooManyListOptions
    /// `tooManyOptions` (vce): câu có `count` lựa chọn.
    case tooManyOptions(count: Int)

    // Đáp án
    /// `missingAnswer` (txt, docx): không có dòng `Correct Answer:`.
    case missingAnswerLine
    /// `missingAnswer` (vce): không có đáp án đúng trong file.
    case missingAnswerInFile
    /// `answerUnreadable` (txt, docx): dòng đáp án không đọc được.
    case unreadableAnswer(String)
    /// `answerUnreadable` (vce): đáp án không đọc được thành chữ cái.
    case unreadableVceAnswer(String)
    /// `answerUnreadable` (vce): đáp án có byte ngoài ASCII in được.
    case answerHasStrangeCharacters
    /// `conflictingAnswer` (txt): thêm dòng đáp án khác; giữ đáp án ở dòng `keptLine`.
    case conflictingAnswerLine(value: String, keptLine: Int)
    /// `conflictingAnswer` (docx): thêm dòng đáp án khác; giữ đáp án đầu tiên `kept`.
    case conflictingAnswer(value: String, kept: String)
    /// `unexpectedAnswerFormat` (vce): đáp án có dấu phân cách, đã đọc thành `letters`.
    case answerWithSeparators(raw: String, letters: [OptionID])
    /// `unexpectedAnswerFormat` (vce): cờ nhiều đáp án không khớp số đáp án.
    case multipleFlagMismatch(flag: Int, answerCount: Int)

    // Đầu đề
    /// `invalidCode` (docx `Number:`).
    case invalidDocxCode(String)
    /// `invalidCode` (vce).
    case invalidVceCode(String)
    /// `invalidPassingScore` (docx `Passing Score:`).
    case unreadablePassingScore(String)
    /// `invalidPassingScore` (vce): điểm đậu ngoài 0–100 %.
    case passingScoreOutOfRange(Int)
    /// `invalidTimeLimit` (docx `Time Limit:`).
    case unreadableTimeLimit(String)
    /// `invalidTimeLimit` (vce).
    case invalidVceTimeLimit(Int)
    /// `invalidNumbering` (docx): `count` số bắt đầu danh sách ngoài 0–32767.
    case invalidNumbering(count: Int)
    /// `tableConverted` (docx).
    case tableConverted

    // Ảnh (docx)
    /// `extraImage`: ảnh thứ hai trở đi trong đề bài.
    case extraImage
    /// `imageOutsideQuestionText`: ảnh trong đầu đề, lựa chọn, giải thích (hoặc đề bài khi không nhận ảnh).
    case imageOutsideQuestionText(DocxPart)
    /// `unsupportedImageFormat`: đuôi ảnh (`nil`: không có đuôi).
    case unsupportedImageFormat(fileExtension: String?)
    /// `imageNotFound`: ảnh liên kết ra ngoài hoặc không có quan hệ.
    case externalImage
    /// `imageNotFound`: ảnh nằm ngoài `word/media/`.
    case imageOutsideMediaFolder
    /// `imageNotFound`: không có file ảnh trong tài liệu.
    case missingImage(fileName: String)
    /// `imageTooLarge`.
    case imageTooLarge(fileName: String)

    // Mã hoá
    /// `mojibakeFixed`.
    case mojibakeFixed(MojibakeSummary)
    /// `mojibakeSuspected`.
    case mojibakeSuspected(MojibakeSummary)
    /// `assumedEncoding` (vce): trường có chữ ngoài ASCII đọc theo Windows-1252; có ký tự điều khiển vô hình hay không.
    case assumedEncoding(field: VceField, hasControlCharacters: Bool)

    // Riêng vce
    /// `unsupportedQuestionType`.
    case unsupportedQuestionType(Int)
    /// `unreadableQuestion`: bản ghi câu sai bố cục (`nil`: lỗi không rõ).
    case unreadableQuestion(VceProblem?)
    /// `unsupportedContent`: nội dung RVF bị bỏ qua trong một trường của câu.
    case unsupportedContent(field: VceField, skipped: [RVFSkip])
    /// `formattingDropped`: các trường có chữ định dạng.
    case formattingDropped(fields: [VceField])
    /// `multipleGroups`: số nhóm và phần nhận câu không thuộc phần nào.
    case multipleGroups(count: Int, fallbackSection: String)
    /// `unknownSection`: phần id có trong bảng nhưng không tên.
    case unnamedSection(id: Int, fallbackSection: String)
    /// `unknownSection`: câu trỏ tới phần id không có trong bảng.
    case unknownSectionID(id: Int, fallbackSection: String)

    // Riêng oef (chỗ `OEFReader` đã sửa hoặc bỏ khi đọc dễ; docs/product/import.md mục `.oef`)
    /// `unknownField`: trường lạ của file `.oef`, bị bỏ qua. Tham số: đường dẫn như `sections[0].questions[2].#9`.
    case oefUnknownField(String)
    /// `invalidCode`: mã đề của file `.oef` sai mẫu, bị bỏ.
    case invalidOefCode(String)
    /// `invalidPassingScore`: ngưỡng đậu của file `.oef` không nằm trong thang 0–1000.
    case oefPassmarkOutOfRange
    /// `invalidTimeLimit`: thời gian của file `.oef` ngoài 1–600 phút. Tham số: giá trị trong file.
    case invalidOefTimeLimit(Int)
    /// `emptySection`: phần thứ `section` (từ 1) không có câu nào, bị bỏ.
    case oefEmptySection(section: Int)
    /// `untitledSection`: phần thứ `section` (từ 1) không có tên, đặt tên `fallbackSection`.
    case oefUntitledSection(section: Int, fallbackSection: String)
    /// `duplicateOptionLetter`: hai lựa chọn cùng chữ; đáp án theo lựa chọn đầu tiên mang chữ đó.
    case oefDuplicateOptionLetter(String)
    /// `answerNotInOptions`: các chữ đáp án không khớp lựa chọn nào, bị bỏ.
    case oefAnswerNotInOptions([String])
    /// `imageTooLarge`: ảnh của câu trong file `.oef` vượt giới hạn, bị bỏ.
    case oefImageTooLarge

    /// Mục tóm tắt của một loại vượt trần chi tiết: `count` mục, báo cáo ghi `limit` mục đầu.
    case summary(code: ImportIssueCode, count: Int, limit: Int)

    /// Câu tiếng Việt (nhật ký, test): đúng câu trước bước 7b.
    public var logMessage: String {
        switch self {
        case let .noOptions(misplaced):
            var message = "Câu không có lựa chọn nào nên bị bỏ."
            if let misplaced {
                let place = misplaced.line.map { " (dòng \($0))" } ?? ""
                message += " Có dòng bắt đầu bằng \"\(misplaced.letter).\"\(place) nhưng lựa chọn phải bắt đầu từ A theo đúng thứ tự."
            } else {
                message += " Kiểm tra các dòng lựa chọn (A. …, B. …) trong file gốc."
            }
            return message
        case let .textBeforeFirstQuestion(from, to):
            return "Văn bản trước câu đầu tiên (từ dòng \(from) tới dòng \(to)) bị bỏ qua."
        case let .textWithoutQuestions(from):
            return "Văn bản từ dòng \(from) tới cuối file không thuộc câu hỏi nào nên bị bỏ qua."
        case .textAfterAnswerLine:
            return "Văn bản sau dòng đáp án không có nhãn \"Explanation:\" nên bị bỏ qua."
        case .textAfterAnswerParagraph:
            return "Văn bản sau dòng đáp án, trước \"Explanation/Reference:\", không thuộc phần nào nên bị bỏ qua."
        case let .optionLabelOutOfOrder(unit, label, expected, appendedTo):
            let start = unit == .line ? "Dòng" : "Đoạn"
            let expectedText = expected.map { "\($0)" } ?? "không còn chữ nào"
            return "\(start) bắt đầu bằng \"\(label)\" không đúng thứ tự (đang chờ \(expectedText)) nên được nối vào lựa chọn \(appendedTo). Kiểm tra lựa chọn bị thiếu hoặc sai chữ."
        case let .optionLabelsShifted(shift):
            return shift.logMessage
        case .tooManyListOptions:
            return "Câu có hơn 26 lựa chọn; từ lựa chọn thứ 27 được nối vào lựa chọn Z."
        case let .tooManyOptions(count):
            return "Câu có \(count) lựa chọn; từ lựa chọn thứ 27 được nối vào lựa chọn Z."
        case .missingAnswerLine:
            return "Câu không có dòng \"Correct Answer:\". Câu chưa có đáp án đúng."
        case .missingAnswerInFile:
            return "Câu không có đáp án đúng trong file."
        case let .unreadableAnswer(value):
            return "Không đọc được đáp án \"\(value)\" (cần chữ cái A–Z, ví dụ A hoặc A,C). Câu chưa có đáp án đúng."
        case let .unreadableVceAnswer(raw):
            return "Không đọc được đáp án \"\(raw)\" (cần chữ cái A–Z). Câu chưa có đáp án đúng."
        case .answerHasStrangeCharacters:
            return "Không đọc được đáp án (có ký tự lạ). Câu chưa có đáp án đúng."
        case let .conflictingAnswerLine(value, line):
            return "Câu có thêm một dòng đáp án khác (\"\(value)\"); giữ đáp án ở dòng \(line)."
        case let .conflictingAnswer(value, kept):
            return "Câu có thêm một dòng đáp án khác (\"\(value)\"); giữ đáp án đầu tiên (\"\(kept)\")."
        case let .answerWithSeparators(raw, letters):
            return "Đáp án \"\(raw)\" có dấu phân cách, khác các file mẫu (viết liền như AC). Đã đọc thành \(letters.map(\.description).joined(separator: ",")); kiểm tra lại."
        case let .multipleFlagMismatch(flag, count):
            return "Cờ nhiều đáp án trong file (\(flag)) không khớp số đáp án đúng (\(count)). Kiểm tra lại loại câu và đáp án."
        case let .invalidDocxCode(number):
            return "Mã đề \"\(number)\" (Number:) không hợp lệ (1–32 ký tự chữ không dấu, số, . _ -) nên bị bỏ."
        case let .invalidVceCode(code):
            return "Mã đề \"\(code)\" không hợp lệ (1–32 ký tự chữ không dấu, số, . _ -) nên bị bỏ."
        case let .unreadablePassingScore(raw):
            return "Không đọc được ngưỡng đậu \"\(raw)\" (Passing Score:); hãy nhập khi import."
        case let .passingScoreOutOfRange(score):
            return "Điểm đậu trong file (\(score)) ngoài 0–100 % nên để trống; hãy nhập khi import."
        case let .unreadableTimeLimit(raw):
            return "Không đọc được thời gian \"\(raw)\" (Time Limit:); hãy nhập khi import."
        case let .invalidVceTimeLimit(value):
            return "Thời gian trong file (\(value)) không hợp lệ nên để trống; hãy nhập khi import."
        case let .invalidNumbering(count):
            return "numbering.xml có \(count) số bắt đầu danh sách ngoài 0–32767 nên bị bỏ qua (đánh số từ 1). Kiểm tra số thứ tự trong danh sách."
        case .tableConverted:
            return "Bảng được chuyển thành văn bản (mỗi hàng một dòng, ô cách nhau bằng \" | \"). Kiểm tra lại cách trình bày."
        case .extraImage:
            return "Ảnh thứ hai trở đi trong đề bài bị bỏ (mỗi câu một ảnh)."
        case let .imageOutsideQuestionText(part):
            return "Ảnh trong \(part.logName) bị bỏ (chỉ giữ một ảnh trong đề bài mỗi câu)."
        case let .unsupportedImageFormat(fileExtension):
            return "Ảnh định dạng \(fileExtension ?? "không rõ") không được hỗ trợ (chỉ png, jpg, jpeg, gif, webp, heic) nên bị bỏ."
        case .externalImage:
            return "Ảnh liên kết ra ngoài hoặc không có trong file nên bị bỏ."
        case .imageOutsideMediaFolder:
            return "Ảnh nằm ngoài thư mục word/media/ của tài liệu nên bị bỏ."
        case let .missingImage(fileName):
            return "Ảnh \(fileName) không có trong file nên bị bỏ."
        case let .imageTooLarge(fileName):
            return "Ảnh \(fileName) vượt giới hạn kích thước nên bị bỏ."
        case let .mojibakeFixed(summary):
            return "Đã tự sửa \(summary.total) chỗ lỗi mã hoá (mojibake): \(summary.logPairs(suspected: false)). Kiểm tra lại nội dung câu."
        case let .mojibakeSuspected(summary):
            return "Có \(summary.total) chỗ nghi lỗi mã hoá, không tự sửa: \(summary.logPairs(suspected: true)). "
                + "Nếu đúng là lỗi thì sửa tay; chữ có dấu hợp lệ thì bỏ qua."
        case let .assumedEncoding(field, hasControl):
            let name = field.logName
            let capitalized = name.prefix(1).uppercased() + name.dropFirst()
            var message = "\(capitalized) có ký tự ngoài ASCII, đã đọc theo bảng mã Windows-1252 (chưa kiểm trên file mẫu)."
            if hasControl {
                message += " Có ký tự điều khiển vô hình (byte 0x81, 0x8D, 0x8F, 0x90 hoặc 0x9D không có trong Windows-1252): "
                    + "xoá hoặc sửa các ký tự đó."
            }
            return message + " Kiểm tra lại chữ."
        case let .unsupportedQuestionType(type):
            return "Câu có loại \(type) chưa hỗ trợ (chỉ đọc được câu trắc nghiệm một/nhiều đáp án) nên bị bỏ. Soạn lại câu này bằng tay nếu cần."
        case let .unreadableQuestion(problem):
            guard let problem else { return "Không đọc được câu nên câu bị bỏ." }
            return "Không đọc được câu: \(problem.logMessage). Câu bị bỏ; kiểm tra lại với file gốc."
        case let .unsupportedContent(field, skipped):
            return "Bỏ qua nội dung chưa hỗ trợ trong \(field.logName): \(skipped.map(\.logMessage).joined(separator: "; ")). Kiểm tra lại với file gốc."
        case let .formattingDropped(fields):
            return "Chữ có định dạng (đậm, nghiêng…) trong \(fields.map(\.logName).joined(separator: ", ")) được giữ dạng chữ thường; định dạng bị bỏ. Kiểm tra lại với file gốc."
        case let .multipleGroups(count, fallback):
            return "File có \(count) nhóm đề; câu không thuộc phần nào được xếp vào phần \"\(fallback)\", có thể khác cách nhóm câu trong VCE. Kiểm tra lại các phần."
        case let .unnamedSection(id, fallback):
            return "Phần id \(id) trong bảng phần không có tên; câu được xếp vào phần \"\(fallback)\"."
        case let .unknownSectionID(id, fallback):
            return "Câu trỏ tới phần id \(id) không có trong bảng phần; xếp vào phần \"\(fallback)\"."
        case let .oefUnknownField(path):
            return "Trường \(path) của file .oef không được hỗ trợ nên bị bỏ qua."
        case let .invalidOefCode(code):
            return "Mã đề \"\(code)\" không hợp lệ (1–32 ký tự chữ không dấu, số, . _ -) nên bị bỏ."
        case .oefPassmarkOutOfRange:
            return "Ngưỡng đậu trong file không nằm trong thang 0–1000 nên để trống; hãy nhập khi import."
        case let .invalidOefTimeLimit(value):
            return "Thời gian trong file (\(value)) không hợp lệ nên để trống; hãy nhập khi import."
        case let .oefEmptySection(section):
            return "Phần thứ \(section) không có câu nào nên bị bỏ."
        case let .oefUntitledSection(section, fallback):
            return "Phần thứ \(section) không có tên; đặt tên \"\(fallback)\"."
        case let .oefDuplicateOptionLetter(letter):
            return "Hai lựa chọn cùng chữ \(letter); đáp án theo lựa chọn đầu tiên mang chữ đó."
        case let .oefAnswerNotInOptions(letters):
            return "Đáp án \(letters.joined(separator: ", ")) không khớp lựa chọn nào nên bị bỏ."
        case .oefImageTooLarge:
            return "Ảnh của câu vượt giới hạn kích thước nên bị bỏ."
        case let .summary(code, count, limit):
            return "… và \(count) mục tương tự (\(code.rawValue)) không liệt kê chi tiết: báo cáo chỉ ghi "
                + "\(limit) mục đầu của mỗi loại."
        }
    }
}

/// Dòng (txt) hay đoạn (docx) của file gốc.
public enum SourceUnit: Equatable, Sendable {
    case line
    case paragraph
}

/// Chữ lựa chọn đầu tiên sai thứ tự trong đề bài của câu không có lựa chọn (`noOptions`).
public struct MisplacedOption: Equatable, Sendable {
    public var letter: OptionID
    /// Dòng (txt); `nil` với docx.
    public var line: Int?

    public init(letter: OptionID, line: Int?) {
        self.letter = letter
        self.line = line
    }
}

/// Phần của câu docx chứa ảnh bị bỏ (`imageOutsideQuestionText`).
public enum DocxPart: Equatable, Sendable {
    case header
    case options
    case explanation
    case questionText

    var logName: String {
        switch self {
        case .header: "đầu đề"
        case .options: "lựa chọn"
        case .explanation: "giải thích"
        case .questionText: "đề bài"
        }
    }
}

/// Lựa chọn không bắt đầu từ A được đánh lại (`optionLabelsShifted`, import.md).
public struct OptionShift: Equatable, Sendable {
    /// Chữ gốc của lựa chọn đầu và cuối ("?" nếu vượt Z), chữ mới của lựa chọn cuối.
    public var originalFirst: String
    public var originalLast: String
    public var newLast: String
    /// Dòng của lựa chọn đầu tiên (txt).
    public var firstLine: Int?
    /// Đáp án trước và sau khi đổi (cùng `nil` nếu câu chưa có đáp án).
    public var answerBefore: [OptionID]?
    public var answerAfter: [OptionID]?
    /// Chữ đáp án không khớp lựa chọn nào.
    public var unmatched: [OptionID]

    public init(
        originalFirst: String,
        originalLast: String,
        newLast: String,
        firstLine: Int?,
        answerBefore: [OptionID]?,
        answerAfter: [OptionID]?,
        unmatched: [OptionID]
    ) {
        self.originalFirst = originalFirst
        self.originalLast = originalLast
        self.newLast = newLast
        self.firstLine = firstLine
        self.answerBefore = answerBefore
        self.answerAfter = answerAfter
        self.unmatched = unmatched
    }

    var logMessage: String {
        let place = firstLine.map { " (lựa chọn đầu tiên là dòng \($0))" } ?? ""
        var message = "Câu không có lựa chọn A: lựa chọn \(originalFirst)–\(originalLast)\(place) được đánh lại A–\(newLast) theo vị trí."
        if let answerBefore, let answerAfter {
            let before = answerBefore.map(\.description).joined(separator: ",")
            let after = answerAfter.map(\.description).joined(separator: ",")
            message += " Đáp án \(before) → \(after)."
            if !unmatched.isEmpty {
                message += " Đáp án \(unmatched.map(\.description).joined(separator: ", ")) không khớp lựa chọn nào, cần sửa."
            }
        }
        return message + " Kiểm tra lại với file gốc."
    }
}

/// Các chỗ lỗi mã hoá (mojibake) của một câu: tổng số chỗ, tối đa 10 cặp trước/sau đã gộp, và số dạng không liệt kê.
public struct MojibakeSummary: Equatable, Sendable {
    public struct Pair: Equatable, Sendable {
        public var before: String
        public var after: String
        /// Số lần cặp này xuất hiện.
        public var count: Int

        public init(before: String, after: String, count: Int) {
            self.before = before
            self.after = after
            self.count = count
        }
    }

    public var total: Int
    public var pairs: [Pair]
    /// Số dạng ngoài 10 cặp đầu.
    public var moreKinds: Int

    public init(total: Int, pairs: [Pair], moreKinds: Int) {
        self.total = total
        self.pairs = pairs
        self.moreKinds = moreKinds
    }

    func logPairs(suspected: Bool) -> String {
        let shown = pairs.map { pair in
            let text = suspected ? "\"\(pair.before)\" (có thể là \"\(pair.after)\")" : "\"\(pair.before)\" → \"\(pair.after)\""
            return text + (pair.count > 1 ? " (\(pair.count) lần)" : "")
        }
        let more = moreKinds > 0 ? "; và \(moreKinds) dạng khác" : ""
        return shown.joined(separator: "; ") + more
    }
}

// MARK: - .vce

/// Trường của file `.vce` nêu trong lỗi cấu trúc, cảnh báo mã hoá và nội dung RVF.
public indirect enum VceField: Equatable, Sendable {
    case fileHeader
    case fileEnd
    case code
    case title
    case passingScore
    case timeLimit
    case examVersion
    case dates
    case examDescription
    case sectionCount
    case sectionID
    case sectionName
    /// Tên phần có id (cảnh báo mã hoá).
    case sectionNameWithID(Int)
    case groupCount
    case group
    case groupName
    /// Tên nhóm đề thứ N, từ 1 (cảnh báo mã hoá).
    case groupNameNumber(Int)
    case questionCount
    /// Kích thước bản ghi câu thứ N, từ 1.
    case questionSize(Int)
    /// Bản ghi câu thứ N, từ 1.
    case questionRecord(Int)
    case questionHeader
    case questionSection
    case questionType
    case questionContent
    case answer
    case optionCount
    case questionEnd
    case caseTitle
    case contentBlock
    /// Đề bài của câu (RVF).
    case questionText
    /// Lựa chọn ở vị trí (từ 0): "lựa chọn A"…"lựa chọn Z", rồi "lựa chọn thứ 27".
    case option(index: Int)
    /// Giải thích của câu (RVF).
    case explanation
    /// Chữ ANSI của nội dung câu (cảnh báo mã hoá).
    case questionANSIText
    /// Độ dài (`i32`) đứng trước một trường.
    case lengthOf(VceField)

    /// Tên tiếng Việt (nhật ký, test), viết thường.
    public var logName: String {
        switch self {
        case .fileHeader: "đầu file"
        case .fileEnd: "cuối file"
        case .code: "mã đề"
        case .title: "tiêu đề"
        case .passingScore: "điểm đậu"
        case .timeLimit: "thời gian"
        case .examVersion: "phiên bản đề"
        case .dates: "ngày tạo/sửa"
        case .examDescription: "mô tả đề"
        case .sectionCount: "số phần"
        case .sectionID: "id phần"
        case .sectionName: "tên phần"
        case let .sectionNameWithID(id): "tên phần id \(id)"
        case .groupCount: "số nhóm đề"
        case .group: "nhóm đề"
        case .groupName: "tên nhóm đề"
        case let .groupNameNumber(number): "tên nhóm đề thứ \(number)"
        case .questionCount: "số câu"
        case let .questionSize(number): "kích thước câu \(number)"
        case let .questionRecord(number): "câu \(number)"
        case .questionHeader: "đầu câu"
        case .questionSection: "phần của câu"
        case .questionType: "loại câu"
        case .questionContent: "nội dung câu"
        case .answer: "đáp án"
        case .optionCount: "số lựa chọn"
        case .questionEnd: "cuối câu"
        case .caseTitle: "tiêu đề tình huống"
        case .contentBlock: "khối nội dung"
        case .questionText: "đề bài"
        case let .option(index): index < 26 ? "lựa chọn \(OptionID(index: index)!)" : "lựa chọn thứ \(index + 1)"
        case .explanation: "giải thích"
        case .questionANSIText: "chữ lưu dạng ANSI của câu"
        case let .lengthOf(field): "độ dài \(field.logName)"
        }
    }
}

/// Vì sao file `.vce` (hoặc một bản ghi câu) không đọc được (docs/product/import.md mục `.vce`).
public enum VceProblem: Equatable, Sendable {
    case empty
    case tooShort
    /// Mã nhận dạng đầu file lạ: không phải `.vce` hoặc phiên bản chưa hỗ trợ.
    case unknownMagic
    /// Hết dữ liệu khi đọc trường.
    case truncated(VceField)
    /// Kích thước ghi trong file khác kích thước thật.
    case sizeMismatch(declared: Int, actual: Int)
    /// Sai CRC-32.
    case checksumMismatch
    /// Độ dài của trường âm hoặc vượt phần còn lại.
    case badLength(VceField, Int)
    /// Chuỗi `xstr` không đúng dạng.
    case badString(VceField)
    case invalidSectionCount(Int)
    case invalidGroupCount(Int)
    case invalidQuestionCount(Int)
    /// Byte lạ sau danh sách câu.
    case trailingBytes(Int)
    /// Byte lạ cuối bản ghi câu.
    case questionTrailingBytes(Int)
    /// Số khối nội dung không khớp số lựa chọn.
    case blockCountMismatch(blocks: Int, options: Int)
    /// File không có câu nào.
    case noQuestions
    /// Mọi câu đều bị bỏ: tổng số và số theo loại (`nil`: không có câu nào loại đó).
    case noUsableQuestions(total: Int, unsupportedType: Int?, unreadable: Int?, noOptions: Int?)

    /// Câu tiếng Việt (nhật ký, test), viết thường, không dấu chấm cuối.
    public var logMessage: String {
        switch self {
        case .empty: "file rỗng"
        case .tooShort: "file quá ngắn"
        case .unknownMagic: "không phải file .vce hoặc phiên bản chưa hỗ trợ (mã nhận dạng đầu file lạ)"
        case let .truncated(field): "file bị cắt cụt hoặc hỏng (hết dữ liệu khi đọc \(field.logName))"
        case let .sizeMismatch(declared, actual):
            "kích thước ghi trong file (\(declared) byte) khác kích thước thật (\(actual) byte): file bị cắt cụt hoặc hỏng"
        case .checksumMismatch: "sai mã kiểm tra CRC-32: file bị hỏng hoặc đã bị sửa"
        case let .badLength(field, length):
            "độ dài \(field.logName) không hợp lệ (\(length) byte, vượt phần dữ liệu còn lại)"
        case let .badString(field): "chuỗi \(field.logName) không đúng dạng đã biết"
        case let .invalidSectionCount(count): "số phần không hợp lệ (\(count))"
        case let .invalidGroupCount(count): "số nhóm đề không hợp lệ (\(count))"
        case let .invalidQuestionCount(count): "số câu không hợp lệ (\(count))"
        case let .trailingBytes(count): "còn \(count) byte lạ sau danh sách câu hỏi (bố cục chưa biết)"
        case let .questionTrailingBytes(count): "bản ghi câu còn \(count) byte lạ"
        case let .blockCountMismatch(blocks, options): "số khối nội dung (\(blocks)) không khớp số lựa chọn (\(options))"
        case .noQuestions: "file không có câu hỏi nào"
        case let .noUsableQuestions(total, unsupported, unreadable, noOptions):
            "không có câu hỏi nào dùng được (\(total) câu đều bị bỏ: "
                + [
                    unsupported.map { "\($0) câu có loại chưa hỗ trợ" },
                    unreadable.map { "\($0) câu có bố cục chưa biết" },
                    noOptions.map { "\($0) câu không có lựa chọn" },
                ].compactMap { $0 }.joined(separator: ", ") + ")"
        }
    }
}

/// Một mục RVF bị bỏ qua (`RVFReader`): loại mục, vì sao dừng giữa chừng, và có dừng đọc phần
/// còn lại của khối không.
public struct RVFSkip: Equatable, Sendable {
    public enum Item: Equatable, Sendable {
        /// Dữ liệu không đúng dạng bản ghi RVF đã biết.
        case unknownData
        /// Bản ghi có số dòng âm.
        case negativeLineCount
        /// Bản ghi thuộc tính tài liệu (`-9`).
        case documentProperties
        /// Mục văn bản thiếu trường.
        case textMissingFields
        /// Chữ Unicode lưu dạng hex (query 3).
        case hexUnicodeText
        /// Văn bản lưu dạng khác (query khác 0, 3).
        case unsupportedTextStorage(query: Int)
        /// Mục văn bản ngắn hơn số dòng khai báo.
        case textShorterThanDeclared
        /// Mục không phải văn bản: đường kẻ (-1), ảnh (-3), hotspot (-4), bullet (-6), loại khác.
        case nonText(type: Int)
    }

    public enum Cause: Equatable, Sendable {
        case none
        /// Số dòng khai báo ít hơn bố cục của đặc tả.
        case fewerLinesThanSpecification(Int)
        /// Khối hết trước số dòng khai báo.
        case blockEndedEarly
        /// Số dòng khai báo lấn sang bản ghi kế tiếp.
        case crossedNextRecord
    }

    public var item: Item
    public var cause: Cause
    /// Dừng đọc phần còn lại của khối.
    public var stopped: Bool

    public init(_ item: Item, cause: Cause = .none, stopped: Bool = false) {
        self.item = item
        self.cause = cause
        self.stopped = stopped
    }

    /// Câu tiếng Việt (nhật ký, test).
    public var logMessage: String {
        let base = switch item {
        case .unknownData: "dữ liệu RVF không đúng dạng đã biết"
        case .negativeLineCount: "bản ghi RVF có số dòng âm"
        case .documentProperties: "bản ghi thuộc tính tài liệu RVF"
        case .textMissingFields: "mục văn bản RVF thiếu trường"
        case .hexUnicodeText: "chữ Unicode lưu dạng hex chưa hỗ trợ"
        case let .unsupportedTextStorage(query): "văn bản lưu dạng chưa hỗ trợ (query \(query))"
        case .textShorterThanDeclared: "mục văn bản RVF ngắn hơn số dòng khai báo"
        case let .nonText(type): Self.itemName(type) + " chưa hỗ trợ"
        }
        let cause = switch cause {
        case .none: ""
        case let .fewerLinesThanSpecification(count): " (số dòng khai báo \(count) ít hơn bố cục của đặc tả)"
        case .blockEndedEarly: " (khối hết trước số dòng khai báo)"
        case .crossedNextRecord: " (số dòng khai báo không khớp bố cục: lấn sang bản ghi kế tiếp)"
        }
        return base + cause + (stopped ? "; phần còn lại bị bỏ qua" : "")
    }

    /// Tên loại mục theo hằng số công khai của TRichView (`rvsBreak`, `rvsPicture`…; tài liệu trực tuyến của TRichView).
    static func itemName(_ type: Int) -> String {
        switch type {
        case -1: "đường kẻ ngang (bản ghi RVF -1)"
        case -3: "ảnh (bản ghi RVF -3)"
        case -4: "hotspot (bản ghi RVF -4)"
        case -6: "bullet (bản ghi RVF -6)"
        default: "nội dung RVF loại \(type) (có thể là bảng hoặc đối tượng khác)"
        }
    }
}

// MARK: - Lỗi file

/// Không đọc được file import (`ImportError.unreadableFile`).
public enum ImportReadProblem: Equatable, Sendable {
    /// Lỗi của hệ thống (mô tả của macOS, đã theo ngôn ngữ của app).
    case system(String)
    /// Không mở được file (không có quyền đọc).
    case cannotOpen(fileName: String)

    var logMessage: String {
        switch self {
        case let .system(description): description
        case let .cannotOpen(fileName): "không mở được \(fileName)."
        }
    }
}

/// Vì sao một phần XML của `.docx` không hợp lệ (`ImportError.invalidXML`).
public enum XMLProblem: Equatable, Sendable {
    /// Có khai báo DTD/thực thể (từ chối trước khi phân tích).
    case declaresDTD
    /// Có khai báo thực thể (gặp khi phân tích).
    case declaresEntity
    /// Bộ phân tích XML báo lỗi. Tham số: mô tả của hệ thống (`nil`: không rõ).
    case parser(String?)

    var logMessage: String {
        switch self {
        case .declaresDTD: "có khai báo DTD/thực thể"
        case .declaresEntity: "có khai báo thực thể"
        case let .parser(description): description ?? "lỗi không rõ"
        }
    }
}

/// Giới hạn bị vượt khi import (`ImportError.tooLarge`).
public enum ImportSizeLimit: Equatable, Sendable {
    case textFile
    case vceFile
    case oefFile
    case docxEntryCount
    case docxTotalSize
    /// Một phần của `.docx` (đường dẫn trong zip).
    case docxPart(String)

    var logName: String {
        switch self {
        case .textFile: "file .txt"
        case .vceFile: "file .vce"
        case .oefFile: "file .oef"
        case .docxEntryCount: "số entry trong file .docx"
        case .docxTotalSize: "tổng giải nén của file .docx"
        case let .docxPart(path): path
        }
    }
}
