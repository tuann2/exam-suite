import ExamKit
import Foundation

/// Đọc file `.oef` của Open Exam Suite (bản Protobuf) và chuyển thành đề, theo hợp đồng ở docs/product/exam-format.md
/// (mục File `.oef`; ADR 0014). Viết mới từ hiểu biết về định dạng, không chép code của Open Exam Suite (ADR 0001).
/// Kotlin (`android/core`) cài đặt cùng luật; oracle chung ở `fixtures/oef/`.
///
/// Thứ tự kiểm: kích thước file → bản cũ (zip, BinaryFormatter) → dây Protobuf và giới hạn → (chỉ `strict`) trường lạ,
/// ngưỡng đậu, từng câu theo thứ tự file (số lựa chọn, chữ cái trùng, đáp án, ảnh) → còn câu nào không → (chỉ
/// `strict`) `ExamValidator` không báo lỗi mức `error`. Đọc `lenient` (bản Admin) không ném ở các bước "chỉ `strict`"
/// mà sửa hoặc bỏ, kèm `OEFNote`.
public enum OEFReader {
    /// Đề đã chuyển và các chỗ đã sửa hoặc bỏ.
    public struct Conversion: Equatable, Sendable {
        /// Ở chế độ `lenient`, ngưỡng đậu không đọc được ghi là 0 (xem `passPercent`).
        public var package: ExamPackage
        /// Chỉ ở chế độ `lenient`; `strict` luôn rỗng.
        public var notes: [OEFNote]
        /// Ngưỡng đậu đọc được từ file; `nil` khi không phải số trong thang 0–1000.
        public var passPercent: Int?
        /// Thời gian đọc được từ file; `nil` khi ngoài 1–600 phút.
        public var timeLimitMinutes: Int?
        /// Số câu đứng trước phần thứ i trong file (kể cả phần và câu bị bỏ), để đổi `OEFPlace` thành thứ tự câu.
        public var questionsBeforeSection: [Int]

        /// Thứ tự (từ 1) của câu ở `place` trong cả file.
        public func questionNumber(_ place: OEFPlace) -> Int {
            questionsBeforeSection[place.section] + place.question + 1
        }
    }

    /// Đọc file và trả gói đề như `ExamPackageReader` (ảnh trong `media`).
    public static func read(
        contentsOf url: URL,
        mode: ReadMode,
        limits: OEFLimits = .default
    ) throws -> ExamPackage {
        try convert(contentsOf: url, mode: mode, limits: limits).package
    }

    public static func convert(
        contentsOf url: URL,
        mode: ReadMode,
        limits: OEFLimits = .default
    ) throws -> Conversion {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= limits.fileBytes else { throw ExamFileError.oef(.tooLarge(.file, limit: limits.fileBytes)) }
        return try convert(Data(contentsOf: url), mode: mode, limits: limits)
    }

    public static func convert(_ data: Data, mode: ReadMode, limits: OEFLimits = .default) throws -> Conversion {
        guard data.count <= limits.fileBytes else { throw ExamFileError.oef(.tooLarge(.file, limit: limits.fileBytes)) }
        let bytes = [UInt8](data)
        if isLegacy(bytes) { throw ExamFileError.oef(.legacyFormat) }
        var decoder = WireDecoder(bytes: bytes, limits: limits)
        let raw = try decoder.decodeExam()
        if mode == .strict, !decoder.unknownFields.isEmpty {
            throw ExamFileError.oef(.unknownFields(decoder.unknownFields))
        }
        var converter = Converter(bytes: bytes, raw: raw, mode: mode, limits: limits)
        converter.notes = decoder.unknownFields.map(OEFNote.unknownField)
        return try converter.convert()
    }

    /// `.oef` bản cũ: zip (v1, v2: XML và ảnh) hoặc header của .NET BinaryFormatter (MS-NRBF: bản ghi 0, root id,
    /// header id −1, phiên bản 1.0). Byte đầu 0 không thể mở một thông điệp Protobuf (số trường 0), nên không nhầm.
    static func isLegacy(_ bytes: [UInt8]) -> Bool {
        if bytes.starts(with: [0x50, 0x4B, 0x03, 0x04]) || bytes.starts(with: [0x50, 0x4B, 0x05, 0x06]) { return true }
        guard bytes.count >= 17, bytes[0] == 0 else { return false }
        return bytes[5 ..< 9].elementsEqual([0xFF, 0xFF, 0xFF, 0xFF])
            && bytes[9 ..< 13].elementsEqual([1, 0, 0, 0])
            && bytes[13 ..< 17].elementsEqual([0, 0, 0, 0])
    }

    // MARK: - Id dẫn xuất

    /// UUID phiên bản 8 (RFC 9562) từ 16 byte đầu của SHA-256(UTF-8 của `name`).
    static func derivedID(_ name: String) -> UUID {
        var b = Array(SHA256.digest(Data(name.utf8)).prefix(16))
        b[6] = (b[6] & 0x0F) | 0x80
        b[8] = (b[8] & 0x3F) | 0x80
        return UUID(uuid: (b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7],
                           b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]))
    }

    /// Id đề: mã (rỗng khi không có hoặc sai mẫu) và tiêu đề sau khi chuẩn hoá, ngăn bằng U+0000.
    static func examID(code: String?, title: String) -> UUID {
        derivedID("oef-exam\u{0}\(code ?? "")\u{0}\(title)")
    }

    /// Id phần thứ `section`, câu thứ `question` theo vị trí trong file (đếm từ 0, kể cả phần và câu bị bỏ).
    public static func sectionID(exam: UUID, section: Int) -> UUID {
        derivedID("\(exam.uuidString.lowercased())/s\(section)")
    }

    public static func questionID(exam: UUID, section: Int, question: Int) -> UUID {
        derivedID("\(exam.uuidString.lowercased())/s\(section)/q\(question)")
    }

    /// Ngưỡng đậu thang 1000 → phần trăm, làm tròn gần nhất, nửa lên (725 → 73; như `Passing Score` của import.md
    /// phương án 13); `nil` khi không phải số trong 0–1000.
    static func passPercent(fromPassmark passmark: Double) -> Int? {
        guard passmark.isFinite, (0 ... 1000).contains(passmark) else { return nil }
        return Int((passmark / 10).rounded(.toNearestOrAwayFromZero))
    }

    // MARK: - Chuỗi

    /// Ký tự được thoát bằng `\` trong chữ trơn của `.oef` (QO7 của docs/product/plan-oef.md): những dấu câu mở cú
    /// pháp inline mà bộ Markdown của cả hai nền tảng nhận dạng thoát. `&` không thoát (Android không nhận `\&`).
    static let markdownSpecials: Set<Unicode.Scalar> = ["\\", "`", "*", "_", "[", "]", "<", ">", "~"]

    /// NFC rồi bỏ scalar Unicode `White_Space` ở hai đầu (cùng định nghĩa khoảng trắng với `ExamValidator`).
    static func clean(_ s: String) -> String {
        let scalars = s.precomposedStringWithCanonicalMapping.unicodeScalars
        guard let start = scalars.firstIndex(where: { !$0.properties.isWhitespace }),
              let end = scalars.lastIndex(where: { !$0.properties.isWhitespace })
        else { return "" }
        return String(String.UnicodeScalarView(scalars[start ... end]))
    }

    /// Chữ trơn → Markdown cơ bản hiển thị đúng chữ gốc.
    static func markdown(_ plain: String) -> String {
        var out = String.UnicodeScalarView()
        for scalar in clean(plain).unicodeScalars {
            if markdownSpecials.contains(scalar) { out.append("\\") }
            out.append(scalar)
        }
        return String(out)
    }

    /// Chữ cái của lựa chọn/đáp án (mã UTF-16 trong file) để hiện trong câu báo: chính chữ đó nếu là ký tự in được,
    /// không thì `U+XXXX`.
    static func letterName(_ value: UInt64) -> String {
        if value >= 0x21, value <= 0x7E, let scalar = Unicode.Scalar(UInt32(value)) { return String(Character(scalar)) }
        return "U+" + String(value, radix: 16, uppercase: true).leftPadded(to: 4)
    }

    // MARK: - Ảnh

    /// Đuôi ảnh theo byte đầu (PNG, JPEG, GIF, WebP, HEIC); `nil` với loại khác.
    static func imageExtension(_ data: Data) -> String? {
        let head = [UInt8](data.prefix(12))
        if head.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) { return "png" }
        if head.starts(with: [0xFF, 0xD8, 0xFF]) { return "jpg" }
        if head.starts(with: Array("GIF87a".utf8)) || head.starts(with: Array("GIF89a".utf8)) { return "gif" }
        if head.count >= 12, head.starts(with: Array("RIFF".utf8)), head[8 ..< 12].elementsEqual("WEBP".utf8) {
            return "webp"
        }
        if head.count >= 12, head[4 ..< 8].elementsEqual("ftyp".utf8),
           heicBrands.contains(String(decoding: head[8 ..< 12], as: UTF8.self))
        {
            return "heic"
        }
        return nil
    }

    private static let heicBrands: Set<String> = ["heic", "heix", "heim", "heis", "hevc", "hevx"]
}

// MARK: - Giải mã dây

private struct RawOption {
    var letter: UInt64 = 0
    var text = ""
}

private struct RawQuestion {
    var text = ""
    var image: Range<Int>?
    var answer: UInt64 = 0
    var isMultipleChoice = false
    var answers: [UInt64] = []
    var options: [RawOption] = []
    var explanation = ""
}

private struct RawSection {
    var title = ""
    var questions: [RawQuestion] = []
}

private struct RawExam {
    var title = ""
    var code = ""
    var passmark: Double = 0
    var timeLimit = 0
    var instructions = ""
    var hideAnswers = false
    var sections: [RawSection] = []
}

/// Dây Protobuf → `RawExam`. Trường không lặp xuất hiện nhiều lần: giá trị vô hướng lấy lần cuối, thông điệp
/// (Properties) gộp, như luật của Protobuf. Trường đã biết sai kiểu dây là dây hỏng.
private struct WireDecoder {
    let bytes: [UInt8]
    let limits: OEFLimits
    private(set) var unknownFields: [String] = []
    private var seenUnknown = Set<String>()
    private var elements = 0
    private var textBytes = 0

    init(bytes: [UInt8], limits: OEFLimits) {
        self.bytes = bytes
        self.limits = limits
    }

    mutating func decodeExam() throws -> RawExam {
        var exam = RawExam()
        var reader = ProtobufReader(bytes)
        while let tag = try reader.nextTag() {
            switch tag.field {
            case 1:
                let range = try message(tag, &reader)
                var nested = reader.nested(range)
                try decodeProperties(&nested, into: &exam)
            case 2:
                let range = try message(tag, &reader)
                var nested = reader.nested(range)
                try count()
                exam.sections.append(try decodeSection(&nested, path: "sections[\(exam.sections.count)]"))
            default:
                try unknown(tag, &reader, path: "")
            }
        }
        return exam
    }

    private mutating func decodeProperties(_ reader: inout ProtobufReader, into exam: inout RawExam) throws {
        while let tag = try reader.nextTag() {
            switch tag.field {
            case 1: exam.title = try string(tag, &reader)
            case 2: exam.code = try string(tag, &reader)
            case 3: _ = try varint(tag, &reader) // Version: số phiên bản đề của người soạn, `.exam` không có.
            case 4:
                guard tag.wireType == .fixed64 else { throw ExamFileError.oef(.malformed(offset: tag.offset)) }
                exam.passmark = Double(bitPattern: try reader.readFixed64())
            case 5: exam.timeLimit = Int(Int32(truncatingIfNeeded: try varint(tag, &reader)))
            case 6: exam.instructions = try string(tag, &reader)
            case 7: exam.hideAnswers = try varint(tag, &reader) != 0
            default: try unknown(tag, &reader, path: "properties.")
            }
        }
    }

    private mutating func decodeSection(_ reader: inout ProtobufReader, path: String) throws -> RawSection {
        var section = RawSection()
        while let tag = try reader.nextTag() {
            switch tag.field {
            case 1: section.title = try string(tag, &reader)
            case 2:
                let range = try message(tag, &reader)
                var nested = reader.nested(range)
                try count()
                let questionPath = "\(path).questions[\(section.questions.count)]"
                section.questions.append(try decodeQuestion(&nested, path: questionPath))
            default: try unknown(tag, &reader, path: "\(path).")
            }
        }
        return section
    }

    private mutating func decodeQuestion(_ reader: inout ProtobufReader, path: String) throws -> RawQuestion {
        var question = RawQuestion()
        while let tag = try reader.nextTag() {
            switch tag.field {
            case 1: _ = try varint(tag, &reader) // No: số thứ tự, không dùng.
            case 2: question.text = try string(tag, &reader)
            case 3: question.image = try message(tag, &reader)
            case 4: question.answer = try varint(tag, &reader)
            case 5: question.isMultipleChoice = try varint(tag, &reader) != 0
            case 6:
                // Answers: char lặp, nhận cả dạng packed lẫn từng phần tử.
                // Mỗi đáp án tính vào giới hạn số phần tử (chặn file dựng có hàng triệu đáp án).
                if tag.wireType == .lengthDelimited {
                    let range = try reader.readLengthDelimited()
                    var packed = reader.nested(range)
                    while !packed.isAtEnd {
                        try count()
                        question.answers.append(try packed.readVarint())
                    }
                } else {
                    guard tag.wireType == .varint else { throw ExamFileError.oef(.malformed(offset: tag.offset)) }
                    try count()
                    question.answers.append(try reader.readVarint())
                }
            case 7:
                let range = try message(tag, &reader)
                var nested = reader.nested(range)
                try count()
                let optionPath = "\(path).options[\(question.options.count)]"
                question.options.append(try decodeOption(&nested, path: optionPath))
            case 8: question.explanation = try string(tag, &reader)
            default: try unknown(tag, &reader, path: "\(path).")
            }
        }
        return question
    }

    private mutating func decodeOption(_ reader: inout ProtobufReader, path: String) throws -> RawOption {
        var option = RawOption()
        while let tag = try reader.nextTag() {
            switch tag.field {
            case 1: option.letter = try varint(tag, &reader)
            case 2: option.text = try string(tag, &reader)
            default: try unknown(tag, &reader, path: "\(path).")
            }
        }
        return option
    }

    // Trường độ dài (thông điệp con, ảnh): vùng byte.
    private func message(_ tag: ProtobufReader.Tag, _ reader: inout ProtobufReader) throws -> Range<Int> {
        guard tag.wireType == .lengthDelimited else { throw ExamFileError.oef(.malformed(offset: tag.offset)) }
        return try reader.readLengthDelimited()
    }

    private mutating func string(_ tag: ProtobufReader.Tag, _ reader: inout ProtobufReader) throws -> String {
        let range = try message(tag, &reader)
        textBytes += range.count
        guard textBytes <= limits.textBytes else { throw ExamFileError.oef(.tooLarge(.text, limit: limits.textBytes)) }
        return try reader.string(in: range)
    }

    private func varint(_ tag: ProtobufReader.Tag, _ reader: inout ProtobufReader) throws -> UInt64 {
        guard tag.wireType == .varint else { throw ExamFileError.oef(.malformed(offset: tag.offset)) }
        return try reader.readVarint()
    }

    private mutating func count() throws {
        elements += 1
        guard elements <= limits.elementCount else {
            throw ExamFileError.oef(.tooLarge(.elements, limit: limits.elementCount))
        }
    }

    private mutating func unknown(_ tag: ProtobufReader.Tag, _ reader: inout ProtobufReader, path: String) throws {
        try reader.skip(tag.wireType)
        guard unknownFields.count < limits.listedItems else { return }
        let fieldPath = "\(path)#\(tag.field)"
        if seenUnknown.insert(fieldPath).inserted { unknownFields.append(fieldPath) }
    }
}

// MARK: - Chuyển thành đề

private struct Converter {
    let bytes: [UInt8]
    let raw: RawExam
    let mode: ReadMode
    let limits: OEFLimits
    var notes: [OEFNote] = []

    init(bytes: [UInt8], raw: RawExam, mode: ReadMode, limits: OEFLimits) {
        self.bytes = bytes
        self.raw = raw
        self.mode = mode
        self.limits = limits
    }

    private var strict: Bool { mode == .strict }

    mutating func convert() throws -> OEFReader.Conversion {
        let title = OEFReader.clean(raw.title)
        var code: String? = OEFReader.clean(raw.code)
        if let value = code, value.isEmpty {
            code = nil
        } else if let value = code, !ExamValidator.isValidCode(value) {
            code = nil
            note(.invalidCode(value))
        }

        let passPercent = OEFReader.passPercent(fromPassmark: raw.passmark)
        if passPercent == nil {
            if strict { throw ExamFileError.oef(.passmarkOutOfRange) }
            note(.passmarkOutOfRange)
        }
        let timeLimit: Int? = (1 ... 600).contains(raw.timeLimit) ? raw.timeLimit : nil
        if timeLimit == nil { note(.timeLimitOutOfRange(raw.timeLimit)) }

        let examID = OEFReader.examID(code: code, title: title)
        var media: [String: Data] = [:]
        var sections: [ExamSection] = []
        for (sectionIndex, rawSection) in raw.sections.enumerated() {
            guard !rawSection.questions.isEmpty else {
                note(.emptySection(section: sectionIndex))
                continue
            }
            let sectionTitle = OEFReader.clean(rawSection.title)
            let firstQuestionNote = notes.count
            var questions: [Question] = []
            for (questionIndex, rawQuestion) in rawSection.questions.enumerated() {
                let place = OEFPlace(section: sectionIndex, question: questionIndex)
                let id = OEFReader.questionID(exam: examID, section: sectionIndex, question: questionIndex)
                if let question = try convertQuestion(rawQuestion, place: place, id: id, media: &media) {
                    questions.append(question)
                }
            }
            // Bản Admin bỏ câu không có lựa chọn; phần còn trống sau đó cũng bỏ, không thêm ghi chú (mỗi câu đã có).
            guard !questions.isEmpty else { continue }
            if sectionTitle.isEmpty, !strict { notes.insert(.untitledSection(section: sectionIndex), at: firstQuestionNote) }
            sections.append(ExamSection(
                id: OEFReader.sectionID(exam: examID, section: sectionIndex),
                title: sectionTitle,
                questions: questions
            ))
        }
        guard !sections.isEmpty else { throw ExamFileError.oef(.noQuestions) }

        let instructions = OEFReader.markdown(raw.instructions)
        let exam = Exam(
            id: examID,
            title: title,
            code: code,
            passPercent: passPercent ?? 0,
            timeLimitMinutes: raw.timeLimit,
            hideAnswers: raw.hideAnswers,
            instructions: instructions.isEmpty ? nil : instructions,
            sections: sections
        )
        let package = ExamPackage(exam: exam, media: media)
        if strict {
            let errors = package.validationIssues.filter { $0.severity == .error }
            if !errors.isEmpty { throw ExamFileError.validationFailed(errors) }
        }
        var before: [Int] = []
        before.reserveCapacity(raw.sections.count)
        var total = 0
        for section in raw.sections {
            before.append(total)
            total += section.questions.count
        }
        return OEFReader.Conversion(package: package, notes: notes, passPercent: passPercent, timeLimitMinutes: timeLimit,
                                    questionsBeforeSection: before)
    }

    /// `nil`: câu bị bỏ (chỉ `lenient`: không có lựa chọn).
    private mutating func convertQuestion(
        _ raw: RawQuestion, place: OEFPlace, id: UUID, media: inout [String: Data]
    ) throws -> Question? {
        if raw.options.isEmpty {
            // Bản Học viên: `ExamValidator` báo câu thiếu lựa chọn và đáp án; bản Admin: bỏ câu như import.md.
            guard strict else {
                note(.noOptions(place))
                return nil
            }
            return Question(id: id, type: raw.isMultipleChoice ? .multiple : .single,
                            text: OEFReader.markdown(raw.text), options: [], correct: [])
        }
        let maxOptions = 26
        if raw.options.count > maxOptions {
            if strict { throw ExamFileError.oef(.tooManyOptions(place, count: raw.options.count)) }
            note(.tooManyOptions(place, count: raw.options.count))
        }
        var texts = raw.options.prefix(maxOptions).map { OEFReader.markdown($0.text) }
        if raw.options.count > maxOptions {
            let parts = [texts[maxOptions - 1]] + raw.options.dropFirst(maxOptions).map { OEFReader.markdown($0.text) }
            texts[maxOptions - 1] = parts.filter { !$0.isEmpty }.joined(separator: "\n")
        }

        // Chữ cái → vị trí lựa chọn đầu tiên mang chữ đó; lựa chọn nối vào Z mang vị trí của Z.
        // Chữ trùng theo thứ tự lần trùng đầu tiên của mỗi chữ.
        var position: [UInt64: Int] = [:]
        var duplicates: [UInt64] = []
        var duplicated = Set<UInt64>()
        for (index, option) in raw.options.enumerated() {
            if position[option.letter] == nil {
                position[option.letter] = min(index, maxOptions - 1)
            } else if duplicated.insert(option.letter).inserted {
                duplicates.append(option.letter)
            }
        }
        for letter in duplicates {
            let name = OEFReader.letterName(letter)
            if strict { throw ExamFileError.oef(.duplicateOptionLetter(place, letter: name)) }
            note(.duplicateOptionLetter(place, letter: name))
        }

        let answerLetters = raw.isMultipleChoice ? raw.answers : (raw.answer == 0 ? [] : [raw.answer])
        var correctPositions = Set<Int>()
        var unmatched: [String] = []
        var unmatchedLetters = Set<UInt64>()
        for letter in answerLetters {
            if let index = position[letter] {
                correctPositions.insert(index)
            } else if unmatched.count < limits.listedItems, unmatchedLetters.insert(letter).inserted {
                unmatched.append(OEFReader.letterName(letter))
            }
        }
        if !unmatched.isEmpty {
            if strict { throw ExamFileError.oef(.answerNotInOptions(place, letters: unmatched)) }
            note(.answerNotInOptions(place, letters: unmatched))
        }

        var imagePath: String?
        if let range = raw.image, !range.isEmpty {
            if range.count > limits.imageBytes {
                if strict { throw ExamFileError.oef(.imageTooLarge(place, limit: limits.imageBytes)) }
                note(.imageTooLarge(place, limit: limits.imageBytes))
            } else {
                let data = Data(bytes[range])
                if let ext = OEFReader.imageExtension(data) {
                    let path = try MediaNaming.path(for: data, fileExtension: ext)
                    media[path] = data
                    imagePath = path
                } else {
                    if strict { throw ExamFileError.oef(.unsupportedImage(place)) }
                    note(.unsupportedImage(place))
                }
            }
        }

        let options = texts.enumerated().compactMap { index, text in
            OptionID(index: index).map { Option(id: $0, text: text) }
        }
        let explanation = OEFReader.markdown(raw.explanation)
        return Question(
            id: id,
            type: raw.isMultipleChoice ? .multiple : .single,
            text: OEFReader.markdown(raw.text),
            image: imagePath,
            options: options,
            correct: correctPositions.sorted().compactMap { OptionID(index: $0) },
            explanation: explanation.isEmpty ? nil : explanation
        )
    }

    private mutating func note(_ note: OEFNote) {
        if !strict { notes.append(note) }
    }
}

private extension String {
    func leftPadded(to length: Int) -> String {
        count >= length ? self : String(repeating: "0", count: length - count) + self
    }
}
