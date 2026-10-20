import Foundation

/// Kiểm tra một `Exam` đã giải mã: mọi ràng buộc của `schema/exam-v1.schema.json`
/// mà model biểu diễn được, cộng các ràng buộc liên trường trong
/// docs/product/exam-format.md. Phía Swift không cần thư viện JSON Schema.
///
/// Không kiểm `formatVersion` và trường lạ: đó là việc của ExamFile.
/// Phải cùng kết luận với `scripts/validate_exam.py` trên mọi fixture.
public enum ExamValidator {
    /// Giới hạn lấy từ schema. Độ dài đếm theo Unicode code point (`unicodeScalars`),
    /// đúng cách JSON Schema `minLength`/`maxLength` đếm.
    public enum Limits {
        public static let titleLength = 1 ... 200
        public static let codeLength = 1 ... 32
        public static let passPercent = 0 ... 100
        public static let timeLimitMinutes = 1 ... 600
        public static let instructionsMaxLength = 4000
        public static let questionTextLength = 1 ... 10000
        public static let explanationMaxLength = 10000
        public static let optionCount = 2 ... 26
        public static let optionTextLength = 1 ... 4000
        public static let imageHashLength = 16 ... 64
        public static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "gif", "webp", "heic"]
    }

    /// Kiểm tra đề và trả về mọi vấn đề, theo thứ tự xuất hiện trong đề
    /// (đề → section → câu → lựa chọn), ổn định giữa các lần gọi.
    ///
    /// - Parameter availableMedia: `nil` = không kiểm ảnh có tồn tại hay không;
    ///   khác `nil` = tập đường dẫn `"media/…"` có trong gói.
    public static func validate(_ exam: Exam, availableMedia: Set<String>? = nil) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        var seenIDs: [UUID: (place: String, location: IssueLocation)] = [:]

        func add(_ code: IssueCode, _ location: IssueLocation, _ message: String,
                 _ arguments: IssueArguments = IssueArguments())
        {
            issues.append(ValidationIssue(code: code, location: location, message: message, arguments: arguments))
        }

        /// Ghi nhận id; trả về nơi xuất hiện trước (mô tả và vị trí) nếu trùng.
        func registerID(_ id: UUID, at place: String, _ location: IssueLocation) -> (place: String, location: IssueLocation)? {
            if let first = seenIDs[id] { return first }
            seenIDs[id] = (place, location)
            return nil
        }

        // MARK: Đề
        _ = registerID(exam.id, at: "đề", .exam)
        checkTitle(exam.title, label: "Tên đề", location: .exam, add: add)
        if let code = exam.code, !isValidCode(code) {
            add(.codeInvalid, .exam,
                "Mã đề \"\(code)\" không hợp lệ. Dùng 1–32 ký tự gồm chữ không dấu, số, dấu chấm, gạch ngang hoặc gạch dưới.",
                IssueArguments(text: code))
        }
        if !Limits.passPercent.contains(exam.passPercent) {
            add(.passPercentOutOfRange, .exam,
                "Ngưỡng đậu \(exam.passPercent)% nằm ngoài khoảng cho phép. Nhập số nguyên từ 0 đến 100.",
                IssueArguments(value: exam.passPercent))
        }
        if !Limits.timeLimitMinutes.contains(exam.timeLimitMinutes) {
            add(.timeLimitOutOfRange, .exam,
                "Thời gian làm bài \(exam.timeLimitMinutes) phút nằm ngoài khoảng cho phép. Nhập từ 1 đến 600 phút.",
                IssueArguments(value: exam.timeLimitMinutes))
        }
        if let instructions = exam.instructions, textLength(instructions) > Limits.instructionsMaxLength {
            add(.instructionsTooLong, .exam,
                "Hướng dẫn dài \(textLength(instructions)) ký tự. Rút gọn còn tối đa \(Limits.instructionsMaxLength) ký tự.",
                IssueArguments(value: textLength(instructions), limit: Limits.instructionsMaxLength))
        }
        if exam.sections.isEmpty {
            add(.noSections, .exam, "Đề chưa có phần nào. Thêm ít nhất một phần có câu hỏi.")
        }

        // MARK: Section
        var seenSectionTitles: [String: Int] = [:]
        for (si, section) in exam.sections.enumerated() {
            let sectionLocation = IssueLocation.section(index: si, id: section.id)
            let sectionPlace = "Phần \(si + 1)"
            if let first = registerID(section.id, at: "phần \(si + 1)", sectionLocation) {
                let id = section.id.uuidString.lowercased()
                add(.duplicateID, sectionLocation,
                    "\(sectionPlace): id \(id) trùng với id của \(first.place). Mỗi đề, phần và câu phải có id riêng.",
                    IssueArguments(text: id, firstLocation: first.location))
            }
            checkTitle(section.title, label: "\(sectionPlace): tiêu đề", location: sectionLocation, add: add)
            let titleKey = trimmed(section.title).lowercased()
            if !titleKey.isEmpty {
                if let firstIndex = seenSectionTitles[titleKey] {
                    let title = trimmed(section.title)
                    add(.duplicateSectionTitle, sectionLocation,
                        "\(sectionPlace) trùng tiêu đề \"\(title)\" với phần \(firstIndex + 1). Đặt tên khác để học viên phân biệt khi xem kết quả.",
                        IssueArguments(
                            text: title,
                            firstLocation: .section(index: firstIndex, id: exam.sections[firstIndex].id)
                        ))
                } else {
                    seenSectionTitles[titleKey] = si
                }
            }
            if section.questions.isEmpty {
                add(.sectionHasNoQuestions, sectionLocation,
                    "\(sectionPlace) chưa có câu hỏi nào. Thêm ít nhất một câu hoặc xoá phần này.")
            }

            // MARK: Câu hỏi
            for (qi, question) in section.questions.enumerated() {
                let qLocation = IssueLocation.question(sectionIndex: si, questionIndex: qi, id: question.id)
                let qPlace = "Phần \(si + 1), câu \(qi + 1)"
                if let first = registerID(question.id, at: "phần \(si + 1), câu \(qi + 1)", qLocation) {
                    let id = question.id.uuidString.lowercased()
                    add(.duplicateID, qLocation,
                        "\(qPlace): id \(id) trùng với id của \(first.place). Mỗi đề, phần và câu phải có id riêng.",
                        IssueArguments(text: id, firstLocation: first.location))
                }
                checkQuestion(question, place: qPlace, location: qLocation,
                              availableMedia: availableMedia, add: add)

                // MARK: Lựa chọn
                for (oi, option) in question.options.enumerated() {
                    let oLocation = IssueLocation.option(sectionIndex: si, questionIndex: qi, optionIndex: oi, questionID: question.id)
                    let oPlace = "\(qPlace), lựa chọn thứ \(oi + 1)"
                    // Quá 26 lựa chọn đã báo `tooManyOptions`; không có chữ cái nào để so tiếp.
                    if let expected = OptionID(index: oi), option.id != expected {
                        add(.optionIDOutOfOrder, oLocation,
                            "\(oPlace) có mã \(option.id), phải là \(expected). Mã lựa chọn đi theo thứ tự A, B, C… theo vị trí.",
                            IssueArguments(optionID: option.id, expectedOptionID: expected))
                    }
                    let optionLength = textLength(option.text)
                    if isBlank(option.text) {
                        add(.optionTextEmpty, oLocation, "\(oPlace) (\(option.id)) chưa có nội dung. Nhập nội dung lựa chọn.",
                            IssueArguments(optionID: option.id))
                    } else if optionLength > Limits.optionTextLength.upperBound {
                        add(.optionTextTooLong, oLocation,
                            "\(oPlace) (\(option.id)) dài \(optionLength) ký tự. Rút gọn còn tối đa \(Limits.optionTextLength.upperBound) ký tự.",
                            IssueArguments(value: optionLength, limit: Limits.optionTextLength.upperBound, optionID: option.id))
                    }
                }
            }
        }
        return issues
    }

    // MARK: - Kiểm từng phần

    private static func checkTitle(
        _ title: String, label: String, location: IssueLocation,
        add: (IssueCode, IssueLocation, String, IssueArguments) -> Void
    ) {
        let count = textLength(title)
        let limit = Limits.titleLength.upperBound
        if isBlank(title) {
            add(.titleEmpty, location, "\(label) đang trống. Nhập 1–\(limit) ký tự.", IssueArguments(limit: limit))
        } else if count > limit {
            add(.titleTooLong, location,
                "\(label) dài \(count) ký tự. Rút gọn còn tối đa \(limit) ký tự.",
                IssueArguments(value: count, limit: limit))
        }
    }

    private static func checkQuestion(
        _ question: Question, place: String, location: IssueLocation,
        availableMedia: Set<String>?,
        add: (IssueCode, IssueLocation, String, IssueArguments) -> Void
    ) {
        let questionLength = textLength(question.text)
        if isBlank(question.text) {
            add(.questionTextEmpty, location, "\(place) chưa có nội dung. Nhập nội dung câu hỏi.", IssueArguments())
        } else if questionLength > Limits.questionTextLength.upperBound {
            add(.questionTextTooLong, location,
                "\(place): nội dung dài \(questionLength) ký tự. Rút gọn còn tối đa \(Limits.questionTextLength.upperBound) ký tự.",
                IssueArguments(value: questionLength, limit: Limits.questionTextLength.upperBound))
        }
        if let explanation = question.explanation, textLength(explanation) > Limits.explanationMaxLength {
            add(.explanationTooLong, location,
                "\(place): giải thích dài \(textLength(explanation)) ký tự. Rút gọn còn tối đa \(Limits.explanationMaxLength) ký tự.",
                IssueArguments(value: textLength(explanation), limit: Limits.explanationMaxLength))
        }
        if let image = question.image {
            if !isValidImagePath(image) {
                add(.imagePathInvalid, location,
                    "\(place): đường dẫn ảnh \"\(image)\" không hợp lệ. Phải có dạng media/<16–64 ký tự hex thường>.<png|jpg|jpeg|gif|webp|heic>; chọn lại ảnh để app đặt tên đúng.",
                    IssueArguments(text: image))
            } else if let availableMedia, !availableMedia.contains(image) {
                add(.imageNotFound, location,
                    "\(place): ảnh \"\(image)\" không có trong gói đề. Chọn lại ảnh hoặc bỏ ảnh khỏi câu.",
                    IssueArguments(text: image))
            }
        }

        let optionCount = question.options.count
        if optionCount < Limits.optionCount.lowerBound {
            add(.tooFewOptions, location,
                "\(place) có \(optionCount) lựa chọn. Cần ít nhất \(Limits.optionCount.lowerBound) lựa chọn.",
                IssueArguments(value: optionCount, limit: Limits.optionCount.lowerBound))
        } else if optionCount > Limits.optionCount.upperBound {
            add(.tooManyOptions, location,
                "\(place) có \(optionCount) lựa chọn. Tối đa \(Limits.optionCount.upperBound) lựa chọn (A–Z).",
                IssueArguments(value: optionCount, limit: Limits.optionCount.upperBound))
        }

        let correct = question.correct
        if correct.isEmpty {
            add(.noCorrectAnswer, location, "\(place) chưa có đáp án đúng. Đánh dấu ít nhất một lựa chọn là đúng.",
                IssueArguments())
        }
        var seen = Set<OptionID>()
        var duplicates: [OptionID] = []
        for id in correct where !seen.insert(id).inserted && !duplicates.contains(id) {
            duplicates.append(id)
        }
        if !duplicates.isEmpty {
            add(.duplicateCorrectAnswer, location,
                "\(place): đáp án đúng bị lặp (\(list(duplicates))). Mỗi lựa chọn chỉ ghi một lần trong đáp án.",
                IssueArguments(optionIDs: duplicates))
        }
        let optionIDs = Set(question.options.map(\.id))
        var missing: [OptionID] = []
        for id in correct where !optionIDs.contains(id) && !missing.contains(id) {
            missing.append(id)
        }
        if !missing.isEmpty {
            add(.correctAnswerNotInOptions, location,
                "\(place): đáp án đúng \(list(missing)) không có trong các lựa chọn của câu. Chọn lại đáp án đúng.",
                IssueArguments(optionIDs: missing))
        }
        switch question.type {
        case .single where correct.count > 1:
            add(.singleHasMultipleCorrect, location,
                "\(place) là câu một đáp án nhưng có \(correct.count) đáp án đúng (\(list(correct))). Giữ một đáp án hoặc đổi sang loại nhiều đáp án.",
                IssueArguments(value: correct.count, optionIDs: correct))
        case .multiple where seen.count == 1:
            add(.multipleHasSingleCorrect, location,
                "\(place) là câu nhiều đáp án nhưng chỉ có một đáp án đúng. Kiểm tra lại, hoặc đổi sang loại một đáp án.",
                IssueArguments())
        default:
            break
        }
    }

    // MARK: - Tiện ích

    /// Độ dài văn bản theo cách JSON Schema `minLength`/`maxLength` đếm: số Unicode code point
    /// (`unicodeScalars.count`), không phải số Character. Giao diện soạn đề dùng hàm này để
    /// đếm ký tự cùng cách với validator và schema.
    public static func textLength(_ s: String) -> Int { s.unicodeScalars.count }

    /// "Toàn khoảng trắng": mọi Unicode scalar có thuộc tính Unicode `White_Space`
    /// (`Unicode.Scalar.Properties.isWhitespace`); chuỗi rỗng cũng tính. Tập này gồm
    /// space, tab, xuống dòng, NBSP U+00A0, U+2028/U+2029, U+3000…; KHÔNG gồm
    /// zero-width space U+200B (không thuộc `White_Space`). `scripts/validate_exam.py`
    /// (bước 7) phải dùng đúng tập này.
    static func isBlank(_ s: String) -> Bool { s.unicodeScalars.allSatisfy(\.properties.isWhitespace) }

    /// Bỏ scalar `White_Space` (cùng định nghĩa với `isBlank`) ở hai đầu.
    static func trimmed(_ s: String) -> String {
        let scalars = s.unicodeScalars
        guard let start = scalars.firstIndex(where: { !$0.properties.isWhitespace }),
              let end = scalars.lastIndex(where: { !$0.properties.isWhitespace })
        else { return "" }
        return String(String.UnicodeScalarView(scalars[start ... end]))
    }

    private static func list(_ ids: [OptionID]) -> String { ids.map(\.description).joined(separator: ", ") }

    /// `^[A-Za-z0-9._-]{1,32}$`
    public static func isValidCode(_ code: String) -> Bool {
        let scalars = code.unicodeScalars
        return Limits.codeLength.contains(scalars.count) && scalars.allSatisfy { s in
            ("A" ... "Z").contains(s) || ("a" ... "z").contains(s) || ("0" ... "9").contains(s)
                || s == "." || s == "_" || s == "-"
        }
    }

    /// `^media/[a-f0-9]{16,64}\.(png|jpg|jpeg|gif|webp|heic)$`
    public static func isValidImagePath(_ path: String) -> Bool {
        let prefix = "media/"
        guard path.hasPrefix(prefix) else { return false }
        let name = path.dropFirst(prefix.count)
        guard let dot = name.lastIndex(of: ".") else { return false }
        let hash = name[..<dot].unicodeScalars
        let ext = String(name[name.index(after: dot)...])
        return Limits.imageHashLength.contains(hash.count)
            && hash.allSatisfy { ("a" ... "f").contains($0) || ("0" ... "9").contains($0) }
            && Limits.imageExtensions.contains(ext)
    }
}
