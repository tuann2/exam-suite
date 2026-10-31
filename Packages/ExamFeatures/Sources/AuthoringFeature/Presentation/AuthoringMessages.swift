import AuthoringData
import ExamFile
import ExamImport
import ExamKit
import Foundation
import InterfaceCore

/// Câu báo lỗi và mục báo cáo của AuthoringData và ExamImport, dựng ở tầng giao diện bằng chữ của String Catalog của
/// AuthoringFeature từ mã + đối số (docs/product/accessibility-localization.md, phương án 2; bước 7b). Hai target dữ liệu
/// vẫn sinh câu tiếng Việt (`logMessage`, `logDescription`) cho nhật ký và test; giao diện không hiện các câu đó.
///
/// Bản tiếng Việt (ngôn ngữ nguồn) trùng từng chữ với `logMessage` cho cùng đầu vào, trừ số: số lượng, độ dài, số dòng có
/// ngăn nghìn theo ngôn ngữ giao diện; mã định danh (id phần, loại câu, cờ, loại bản ghi RVF) giữ chữ số trơn. Test:
/// `AuthoringMessagesTests`. Lỗi của lõi và Thư viện: `ErrorMessages` (InterfaceCore).
public enum AuthoringMessages {
    // MARK: - Lỗi bất kỳ

    /// Lỗi của soạn đề (`ExamEditError`), import (`ImportError`), rồi lõi và Thư viện (`ErrorMessages`); lỗi khác dùng câu
    /// của hệ thống.
    public static func message(for error: any Error) -> String {
        switch error {
        case let error as ExamEditError: message(for: error)
        case let error as ImportError: message(for: error)
        default: ErrorMessages.message(for: error)
        }
    }

    // MARK: - Sửa đề (AuthoringData)

    public static func message(for error: ExamEditError) -> String {
        switch error {
        case let .sectionNotFound(id):
            localized("Không tìm thấy phần \(id.uuidString.lowercased()) trong đề.")
        case let .questionNotFound(id):
            localized("Không tìm thấy câu \(id.uuidString.lowercased()) trong đề.")
        case let .invalidSectionIndex(index):
            localized("Không có phần thứ \(index + 1) trong đề.")
        case let .invalidQuestionPath(path):
            localized("Không có phần \(path.section + 1), câu \(path.question + 1) trong đề.")
        case let .invalidOptionIndex(index):
            localized("Không có lựa chọn thứ \(index + 1) trong câu.")
        case .invalidPermutation:
            localized("Thứ tự mới không hợp lệ.")
        case .tooManyOptions:
            localized("Câu đã có đủ 26 lựa chọn (A–Z), không thêm được nữa.")
        case let .unsupportedImageType(ext):
            localized("Loại ảnh \"\(ext)\" không được hỗ trợ (chỉ png, jpg, jpeg, gif, webp, heic).")
        case let .imageTooLarge(bytes, limit):
            localized("Ảnh nặng \(mebibytes(bytes)) MiB, vượt giới hạn \(mebibytes(limit)) MiB mỗi ảnh.")
        case let .packageTooLarge(limit):
            localized("Thêm ảnh này làm tổng dung lượng ảnh của đề vượt \(mebibytes(limit)) MiB.")
        case let .tooManyImages(limit):
            localized("Đề đã có quá nhiều ảnh (gói tối đa \(limit) mục).")
        case let .mediaNameCollision(path):
            localized("Trong đề đã có ảnh khác cùng tên \(path); không thay ảnh đã có.")
        }
    }

    /// Dung lượng theo MiB, tối đa một chữ số thập phân, theo ngôn ngữ giao diện ("12,5" ở tiếng Việt).
    static func mebibytes(_ bytes: Int, locale: Locale = InterfaceLocale.current) -> String {
        let value = Double(bytes) / Double(1 << 20)
        return value.formatted(.number.precision(.fractionLength(0 ... 1)).locale(locale))
    }

    // MARK: - Import (ExamImport): lỗi file

    public static func message(for error: ImportError) -> String {
        switch error {
        case let .unsupportedFileType(ext):
            return localized("Không import được file \".\(ext)\". Chỉ hỗ trợ .txt, .docx, .vce và .oef.")
        case let .unreadableFile(.system(description)):
            return localized("Không đọc được file: \(description)")
        case let .unreadableFile(.cannotOpen(fileName)):
            return localized("Không đọc được file: không mở được \(fileName).")
        case .notUTF8:
            return localized("File .txt phải mã hoá UTF-8. Mở file bằng trình soạn thảo, lưu lại với mã hoá UTF-8 rồi import lại.")
        case .notADocx:
            return localized("File không phải tài liệu Word .docx hợp lệ (zip hỏng hoặc thiếu nội dung văn bản).")
        case let .corruptedPart(path):
            return localized("Tài liệu Word bị hỏng: không giải nén được \(path).")
        case let .invalidXML(part, .declaresDTD):
            return localized("Tài liệu Word bị hỏng: \(part) không hợp lệ (có khai báo DTD/thực thể).")
        case let .invalidXML(part, .declaresEntity):
            return localized("Tài liệu Word bị hỏng: \(part) không hợp lệ (có khai báo thực thể).")
        case let .invalidXML(part, .parser(description?)):
            return localized("Tài liệu Word bị hỏng: \(part) không hợp lệ (\(description)).")
        case let .invalidXML(part, .parser(nil)):
            return localized("Tài liệu Word bị hỏng: \(part) không hợp lệ (lỗi không rõ).")
        case let .tooLarge(.textFile, limit):
            return localized("File vượt giới hạn ở file .txt (tối đa \(limit) byte).")
        case let .tooLarge(.vceFile, limit):
            return localized("File vượt giới hạn ở file .vce (tối đa \(limit) byte).")
        case let .tooLarge(.oefFile, limit):
            return localized("File vượt giới hạn ở file .oef (tối đa \(limit) byte).")
        case let .tooLarge(.docxEntryCount, limit):
            return localized("File vượt giới hạn ở số entry trong file .docx (tối đa \(limit) entry).")
        case let .tooLarge(.docxTotalSize, limit):
            return localized("File vượt giới hạn ở tổng giải nén của file .docx (tối đa \(limit) byte).")
        case let .tooLarge(.docxPart(path), limit):
            return localized("File vượt giới hạn ở \(path) (tối đa \(limit) byte).")
        case let .tooDeep(part, limit):
            return localized("Tài liệu Word bất thường: \(part) lồng quá \(limit) cấp.")
        case let .noQuestions(dropped):
            if dropped > 0 {
                return localized("Không có câu hỏi nào dùng được: \(dropped) câu đều không có lựa chọn. Kiểm tra bố cục file (A. …, B. …).")
            }
            return localized("Không tìm thấy câu hỏi nào. Mỗi câu phải bắt đầu bằng dòng \"Q1:\" hoặc \"QUESTION 1\".")
        case let .unreadableVCE(problem):
            return localized("File .vce không đọc được: \(phrase(problem)). Nếu có bản .docx xuất từ VCE thì import file đó.")
        case let .unreadableOEF(problem):
            // Cùng câu với bản Học viên khi mở thẳng file (InterfaceCore).
            return ErrorMessages.message(for: ExamFileError.oef(problem))
        }
    }

    // MARK: - Import: vị trí trong file gốc

    /// "Câu 12, dòng 345", "Câu 3", "Dòng 2", "Đầu file" (cột vị trí của báo cáo import).
    public static func location(_ location: ImportLocation) -> String {
        switch (location.questionNumber, location.line) {
        case let (question?, line?): localized("Câu \(question), dòng \(line)")
        case let (question?, nil): localized("Câu \(question)")
        case let (nil, line?): localized("Dòng \(line)")
        case (nil, nil): localized("Đầu file")
        }
    }

    // MARK: - Import: mục báo cáo

    /// Lý do của một mục báo cáo import (không gồm vị trí).
    public static func message(for detail: ImportIssueDetail) -> String {
        switch detail {
        case .noOptions(nil):
            return localized("Câu không có lựa chọn nào nên bị bỏ. Kiểm tra các dòng lựa chọn (A. …, B. …) trong file gốc.")
        case let .noOptions(misplaced?):
            let letter = misplaced.letter.description
            if let line = misplaced.line {
                return localized("Câu không có lựa chọn nào nên bị bỏ. Có dòng bắt đầu bằng \"\(letter).\" (dòng \(line)) nhưng lựa chọn phải bắt đầu từ A theo đúng thứ tự.")
            }
            return localized("Câu không có lựa chọn nào nên bị bỏ. Có dòng bắt đầu bằng \"\(letter).\" nhưng lựa chọn phải bắt đầu từ A theo đúng thứ tự.")
        case let .textBeforeFirstQuestion(from, to):
            return localized("Văn bản trước câu đầu tiên (từ dòng \(from) tới dòng \(to)) bị bỏ qua.")
        case let .textWithoutQuestions(from):
            return localized("Văn bản từ dòng \(from) tới cuối file không thuộc câu hỏi nào nên bị bỏ qua.")
        case .textAfterAnswerLine:
            return localized("Văn bản sau dòng đáp án không có nhãn \"Explanation:\" nên bị bỏ qua.")
        case .textAfterAnswerParagraph:
            return localized("Văn bản sau dòng đáp án, trước \"Explanation/Reference:\", không thuộc phần nào nên bị bỏ qua.")
        case let .optionLabelOutOfOrder(unit, label, expected, appendedTo):
            return optionOutOfOrder(unit: unit, label: label.description, expected: expected?.description,
                                    appendedTo: appendedTo.description)
        case let .optionLabelsShifted(shift):
            return optionsShifted(shift)
        case .tooManyListOptions:
            return localized("Câu có hơn 26 lựa chọn; từ lựa chọn thứ 27 được nối vào lựa chọn Z.")
        case let .tooManyOptions(count):
            return localized("Câu có \(count) lựa chọn; từ lựa chọn thứ 27 được nối vào lựa chọn Z.")
        case .missingAnswerLine:
            return localized("Câu không có dòng \"Correct Answer:\". Câu chưa có đáp án đúng.")
        case .missingAnswerInFile:
            return localized("Câu không có đáp án đúng trong file.")
        case let .unreadableAnswer(value):
            return localized("Không đọc được đáp án \"\(value)\" (cần chữ cái A–Z, ví dụ A hoặc A,C). Câu chưa có đáp án đúng.")
        case let .unreadableVceAnswer(raw):
            return localized("Không đọc được đáp án \"\(raw)\" (cần chữ cái A–Z). Câu chưa có đáp án đúng.")
        case .answerHasStrangeCharacters:
            return localized("Không đọc được đáp án (có ký tự lạ). Câu chưa có đáp án đúng.")
        case let .conflictingAnswerLine(value, line):
            return localized("Câu có thêm một dòng đáp án khác (\"\(value)\"); giữ đáp án ở dòng \(line).")
        case let .conflictingAnswer(value, kept):
            return localized("Câu có thêm một dòng đáp án khác (\"\(value)\"); giữ đáp án đầu tiên (\"\(kept)\").")
        case let .answerWithSeparators(raw, letters):
            let read = letters.map(\.description).joined(separator: ",")
            return localized("Đáp án \"\(raw)\" có dấu phân cách, khác các file mẫu (viết liền như AC). Đã đọc thành \(read); kiểm tra lại.")
        case let .multipleFlagMismatch(flag, count):
            return localized("Cờ nhiều đáp án trong file (\(String(flag))) không khớp số đáp án đúng (\(count)). Kiểm tra lại loại câu và đáp án.")
        case let .invalidDocxCode(number):
            return localized("Mã đề \"\(number)\" (Number:) không hợp lệ (1–32 ký tự chữ không dấu, số, . _ -) nên bị bỏ.")
        case let .invalidVceCode(code):
            return localized("Mã đề \"\(code)\" không hợp lệ (1–32 ký tự chữ không dấu, số, . _ -) nên bị bỏ.")
        case let .unreadablePassingScore(raw):
            return localized("Không đọc được ngưỡng đậu \"\(raw)\" (Passing Score:); hãy nhập khi import.")
        case let .passingScoreOutOfRange(score):
            return localized("Điểm đậu trong file (\(score)) ngoài 0–100 % nên để trống; hãy nhập khi import.")
        case let .unreadableTimeLimit(raw):
            return localized("Không đọc được thời gian \"\(raw)\" (Time Limit:); hãy nhập khi import.")
        case let .invalidVceTimeLimit(value):
            return localized("Thời gian trong file (\(value)) không hợp lệ nên để trống; hãy nhập khi import.")
        case let .invalidNumbering(count):
            return localized("numbering.xml có \(count) số bắt đầu danh sách ngoài 0–32767 nên bị bỏ qua (đánh số từ 1). Kiểm tra số thứ tự trong danh sách.")
        case .tableConverted:
            return localized("Bảng được chuyển thành văn bản (mỗi hàng một dòng, ô cách nhau bằng \" | \"). Kiểm tra lại cách trình bày.")
        case .extraImage:
            return localized("Ảnh thứ hai trở đi trong đề bài bị bỏ (mỗi câu một ảnh).")
        case .imageOutsideQuestionText(.header):
            return localized("Ảnh trong đầu đề bị bỏ (chỉ giữ một ảnh trong đề bài mỗi câu).")
        case .imageOutsideQuestionText(.options):
            return localized("Ảnh trong lựa chọn bị bỏ (chỉ giữ một ảnh trong đề bài mỗi câu).")
        case .imageOutsideQuestionText(.explanation):
            return localized("Ảnh trong giải thích bị bỏ (chỉ giữ một ảnh trong đề bài mỗi câu).")
        case .imageOutsideQuestionText(.questionText):
            return localized("Ảnh trong đề bài bị bỏ (chỉ giữ một ảnh trong đề bài mỗi câu).")
        case let .unsupportedImageFormat(fileExtension?):
            return localized("Ảnh định dạng \(fileExtension) không được hỗ trợ (chỉ png, jpg, jpeg, gif, webp, heic) nên bị bỏ.")
        case .unsupportedImageFormat(nil):
            return localized("Ảnh định dạng không rõ không được hỗ trợ (chỉ png, jpg, jpeg, gif, webp, heic) nên bị bỏ.")
        case .externalImage:
            return localized("Ảnh liên kết ra ngoài hoặc không có trong file nên bị bỏ.")
        case .imageOutsideMediaFolder:
            return localized("Ảnh nằm ngoài thư mục word/media/ của tài liệu nên bị bỏ.")
        case let .missingImage(fileName):
            return localized("Ảnh \(fileName) không có trong file nên bị bỏ.")
        case let .imageTooLarge(fileName):
            return localized("Ảnh \(fileName) vượt giới hạn kích thước nên bị bỏ.")
        case let .mojibakeFixed(summary):
            return localized("Đã tự sửa \(summary.total) chỗ lỗi mã hoá (mojibake): \(pairs(summary, suspected: false)). Kiểm tra lại nội dung câu.")
        case let .mojibakeSuspected(summary):
            return localized("Có \(summary.total) chỗ nghi lỗi mã hoá, không tự sửa: \(pairs(summary, suspected: true)). Nếu đúng là lỗi thì sửa tay; chữ có dấu hợp lệ thì bỏ qua.")
        case let .assumedEncoding(field, hasControl):
            var sentences = [encodingSentence(field)]
            if hasControl {
                sentences.append(localized("Có ký tự điều khiển vô hình (byte 0x81, 0x8D, 0x8F, 0x90 hoặc 0x9D không có trong Windows-1252): xoá hoặc sửa các ký tự đó."))
            }
            sentences.append(localized("Kiểm tra lại chữ."))
            return sentences.joined(separator: " ")
        case let .unsupportedQuestionType(type):
            return localized("Câu có loại \(String(type)) chưa hỗ trợ (chỉ đọc được câu trắc nghiệm một/nhiều đáp án) nên bị bỏ. Soạn lại câu này bằng tay nếu cần.")
        case .unreadableQuestion(nil):
            return localized("Không đọc được câu nên câu bị bỏ.")
        case let .unreadableQuestion(problem?):
            return localized("Không đọc được câu: \(phrase(problem)). Câu bị bỏ; kiểm tra lại với file gốc.")
        case let .unsupportedContent(field, skipped):
            let note = name(field) + ": " + skipped.map(phrase).joined(separator: "; ")
            return localized("Bỏ qua nội dung chưa hỗ trợ trong \(note). Kiểm tra lại với file gốc.")
        case let .formattingDropped(fields):
            let parts = fields.map(name).joined(separator: ", ")
            return localized("Chữ có định dạng (đậm, nghiêng…) trong \(parts) được giữ dạng chữ thường; định dạng bị bỏ. Kiểm tra lại với file gốc.")
        case let .multipleGroups(count, fallback):
            return localized("File có \(count) nhóm đề; câu không thuộc phần nào được xếp vào phần \"\(fallback)\", có thể khác cách nhóm câu trong VCE. Kiểm tra lại các phần.")
        case let .unnamedSection(id, fallback):
            return localized("Phần id \(String(id)) trong bảng phần không có tên; câu được xếp vào phần \"\(fallback)\".")
        case let .unknownSectionID(id, fallback):
            return localized("Câu trỏ tới phần id \(String(id)) không có trong bảng phần; xếp vào phần \"\(fallback)\".")
        case let .oefUnknownField(path):
            return localized("Trường \(path) của file .oef không được hỗ trợ nên bị bỏ qua.")
        case let .invalidOefCode(code):
            return localized("Mã đề \"\(code)\" không hợp lệ (1–32 ký tự chữ không dấu, số, . _ -) nên bị bỏ.")
        case .oefPassmarkOutOfRange:
            return localized("Ngưỡng đậu trong file không nằm trong thang 0–1000 nên để trống; hãy nhập khi import.")
        case let .invalidOefTimeLimit(value):
            return localized("Thời gian trong file (\(value)) không hợp lệ nên để trống; hãy nhập khi import.")
        case let .oefEmptySection(section):
            return localized("Phần thứ \(section) không có câu nào nên bị bỏ.")
        case let .oefUntitledSection(section, fallback):
            return localized("Phần thứ \(section) không có tên; đặt tên \"\(fallback)\".")
        case let .oefDuplicateOptionLetter(letter):
            return localized("Hai lựa chọn cùng chữ \(letter); đáp án theo lựa chọn đầu tiên mang chữ đó.")
        case let .oefAnswerNotInOptions(letters):
            return localized("Đáp án \(letters.joined(separator: ", ")) không khớp lựa chọn nào nên bị bỏ.")
        case .oefImageTooLarge:
            return localized("Ảnh của câu vượt giới hạn kích thước nên bị bỏ.")
        case let .summary(code, count, limit):
            return localized("… và \(count) mục tương tự (\(code.rawValue)) không liệt kê chi tiết: báo cáo chỉ ghi \(limit) mục đầu của mỗi loại.")
        }
    }

    private static func optionOutOfOrder(unit: SourceUnit, label: String, expected: String?, appendedTo: String) -> String {
        switch (unit, expected) {
        case let (.line, expected?):
            localized("Dòng bắt đầu bằng \"\(label)\" không đúng thứ tự (đang chờ \(expected)) nên được nối vào lựa chọn \(appendedTo). Kiểm tra lựa chọn bị thiếu hoặc sai chữ.")
        case (.line, nil):
            localized("Dòng bắt đầu bằng \"\(label)\" không đúng thứ tự (đang chờ không còn chữ nào) nên được nối vào lựa chọn \(appendedTo). Kiểm tra lựa chọn bị thiếu hoặc sai chữ.")
        case let (.paragraph, expected?):
            localized("Đoạn bắt đầu bằng \"\(label)\" không đúng thứ tự (đang chờ \(expected)) nên được nối vào lựa chọn \(appendedTo). Kiểm tra lựa chọn bị thiếu hoặc sai chữ.")
        case (.paragraph, nil):
            localized("Đoạn bắt đầu bằng \"\(label)\" không đúng thứ tự (đang chờ không còn chữ nào) nên được nối vào lựa chọn \(appendedTo). Kiểm tra lựa chọn bị thiếu hoặc sai chữ.")
        }
    }

    /// Các câu của cảnh báo lựa chọn được đánh lại, nối bằng dấu cách.
    private static func optionsShifted(_ shift: OptionShift) -> String {
        let first = shift.originalFirst, last = shift.originalLast, newLast = shift.newLast
        var sentences: [String] = []
        if let line = shift.firstLine {
            sentences.append(localized("Câu không có lựa chọn A: lựa chọn \(first)–\(last) (lựa chọn đầu tiên là dòng \(line)) được đánh lại A–\(newLast) theo vị trí."))
        } else {
            sentences.append(localized("Câu không có lựa chọn A: lựa chọn \(first)–\(last) được đánh lại A–\(newLast) theo vị trí."))
        }
        if let before = shift.answerBefore, let after = shift.answerAfter {
            let beforeText = before.map(\.description).joined(separator: ",")
            let afterText = after.map(\.description).joined(separator: ",")
            sentences.append(localized("Đáp án \(beforeText) → \(afterText)."))
            if !shift.unmatched.isEmpty {
                let list = shift.unmatched.map(\.description).joined(separator: ", ")
                sentences.append(localized("Đáp án \(list) không khớp lựa chọn nào, cần sửa."))
            }
        }
        sentences.append(localized("Kiểm tra lại với file gốc."))
        return sentences.joined(separator: " ")
    }

    /// Các cặp mojibake: `"â€™" → "’" (2 lần)`; nghi lỗi: `"Ã©" (có thể là "é")`; nối bằng "; ".
    private static func pairs(_ summary: MojibakeSummary, suspected: Bool) -> String {
        var items = summary.pairs.map { pair -> String in
            let before = pair.before, after = pair.after, count = pair.count
            switch (suspected, count > 1) {
            case (false, false): return localized("\"\(before)\" → \"\(after)\"")
            case (false, true): return localized("\"\(before)\" → \"\(after)\" (\(count) lần)")
            case (true, false): return localized("\"\(before)\" (có thể là \"\(after)\")")
            case (true, true): return localized("\"\(before)\" (có thể là \"\(after)\") (\(count) lần)")
            }
        }
        if summary.moreKinds > 0 { items.append(localized("và \(summary.moreKinds) dạng khác")) }
        return items.joined(separator: "; ")
    }

    /// Câu đầu của cảnh báo mã hoá, theo trường.
    private static func encodingSentence(_ field: VceField) -> String {
        switch field {
        case .title:
            localized("Tiêu đề có ký tự ngoài ASCII, đã đọc theo bảng mã Windows-1252 (chưa kiểm trên file mẫu).")
        case .code:
            localized("Mã đề có ký tự ngoài ASCII, đã đọc theo bảng mã Windows-1252 (chưa kiểm trên file mẫu).")
        case let .sectionNameWithID(id):
            localized("Tên phần id \(String(id)) có ký tự ngoài ASCII, đã đọc theo bảng mã Windows-1252 (chưa kiểm trên file mẫu).")
        case let .groupNameNumber(number):
            localized("Tên nhóm đề thứ \(number) có ký tự ngoài ASCII, đã đọc theo bảng mã Windows-1252 (chưa kiểm trên file mẫu).")
        case .questionANSIText:
            localized("Chữ lưu dạng ANSI của câu có ký tự ngoài ASCII, đã đọc theo bảng mã Windows-1252 (chưa kiểm trên file mẫu).")
        default:
            // Bộ đọc chỉ báo các trường trên; trường khác: tên trường viết hoa chữ đầu, như câu của ExamImport.
            localized("\(capitalized(name(field))) có ký tự ngoài ASCII, đã đọc theo bảng mã Windows-1252 (chưa kiểm trên file mẫu).")
        }
    }

    private static func capitalized(_ text: String) -> String {
        text.prefix(1).uppercased(with: InterfaceLocale.current) + text.dropFirst()
    }

    // MARK: - .vce: tên trường, lý do, mục RVF

    /// Tên trường của file `.vce`, viết thường.
    static func name(_ field: VceField) -> String {
        switch field {
        case .fileHeader: localized("đầu file")
        case .fileEnd: localized("cuối file")
        case .code: localized("mã đề")
        case .title: localized("tiêu đề")
        case .passingScore: localized("điểm đậu")
        case .timeLimit: localized("thời gian")
        case .examVersion: localized("phiên bản đề")
        case .dates: localized("ngày tạo/sửa")
        case .examDescription: localized("mô tả đề")
        case .sectionCount: localized("số phần")
        case .sectionID: localized("id phần")
        case .sectionName: localized("tên phần")
        case let .sectionNameWithID(id): localized("tên phần id \(String(id))")
        case .groupCount: localized("số nhóm đề")
        case .group: localized("nhóm đề")
        case .groupName: localized("tên nhóm đề")
        case let .groupNameNumber(number): localized("tên nhóm đề thứ \(number)")
        case .questionCount: localized("số câu")
        case let .questionSize(number): localized("kích thước câu \(number)")
        case let .questionRecord(number): localized("câu \(number)")
        case .questionHeader: localized("đầu câu")
        case .questionSection: localized("phần của câu")
        case .questionType: localized("loại câu")
        case .questionContent: localized("nội dung câu")
        case .answer: localized("đáp án")
        case .optionCount: localized("số lựa chọn")
        case .questionEnd: localized("cuối câu")
        case .caseTitle: localized("tiêu đề tình huống")
        case .contentBlock: localized("khối nội dung")
        case .questionText: localized("đề bài")
        case let .option(index):
            if let letter = OptionID(index: index) {
                localized("lựa chọn \(letter.description)")
            } else {
                localized("lựa chọn thứ \(index + 1)")
            }
        case .explanation: localized("giải thích")
        case .questionANSIText: localized("chữ lưu dạng ANSI của câu")
        case let .lengthOf(inner): localized("độ dài \(name(inner))")
        }
    }

    /// Lý do file `.vce` (hoặc bản ghi câu) không đọc được, viết thường, không dấu chấm cuối.
    static func phrase(_ problem: VceProblem) -> String {
        switch problem {
        case .empty:
            localized("file rỗng")
        case .tooShort:
            localized("file quá ngắn")
        case .unknownMagic:
            localized("không phải file .vce hoặc phiên bản chưa hỗ trợ (mã nhận dạng đầu file lạ)")
        case let .truncated(field):
            localized("file bị cắt cụt hoặc hỏng (hết dữ liệu khi đọc \(name(field)))")
        case let .sizeMismatch(declared, actual):
            localized("kích thước ghi trong file (\(declared) byte) khác kích thước thật (\(actual) byte): file bị cắt cụt hoặc hỏng")
        case .checksumMismatch:
            localized("sai mã kiểm tra CRC-32: file bị hỏng hoặc đã bị sửa")
        case let .badLength(field, length):
            localized("độ dài \(name(field)) không hợp lệ (\(length) byte, vượt phần dữ liệu còn lại)")
        case let .badString(field):
            localized("chuỗi \(name(field)) không đúng dạng đã biết")
        case let .invalidSectionCount(count):
            localized("số phần không hợp lệ (\(count))")
        case let .invalidGroupCount(count):
            localized("số nhóm đề không hợp lệ (\(count))")
        case let .invalidQuestionCount(count):
            localized("số câu không hợp lệ (\(count))")
        case let .trailingBytes(count):
            localized("còn \(count) byte lạ sau danh sách câu hỏi (bố cục chưa biết)")
        case let .questionTrailingBytes(count):
            localized("bản ghi câu còn \(count) byte lạ")
        case let .blockCountMismatch(blocks, options):
            localized("số khối nội dung (\(blocks)) không khớp số lựa chọn (\(options))")
        case .noQuestions:
            localized("file không có câu hỏi nào")
        case let .noUsableQuestions(total, unsupported, unreadable, noOptions):
            noUsableQuestions(total: total, unsupported: unsupported, unreadable: unreadable, noOptions: noOptions)
        }
    }

    private static func noUsableQuestions(total: Int, unsupported: Int?, unreadable: Int?, noOptions: Int?) -> String {
        let parts = [
            unsupported.map { localized("\($0) câu có loại chưa hỗ trợ") },
            unreadable.map { localized("\($0) câu có bố cục chưa biết") },
            noOptions.map { localized("\($0) câu không có lựa chọn") },
        ].compactMap { $0 }.joined(separator: ", ")
        return localized("không có câu hỏi nào dùng được (\(total) câu đều bị bỏ: \(parts))")
    }

    /// Một mục RVF bị bỏ qua: loại mục, lý do dừng (nếu có), "phần còn lại bị bỏ qua" (nếu dừng đọc khối).
    static func phrase(_ skip: RVFSkip) -> String {
        var text = switch skip.item {
        case .unknownData: localized("dữ liệu RVF không đúng dạng đã biết")
        case .negativeLineCount: localized("bản ghi RVF có số dòng âm")
        case .documentProperties: localized("bản ghi thuộc tính tài liệu RVF")
        case .textMissingFields: localized("mục văn bản RVF thiếu trường")
        case .hexUnicodeText: localized("chữ Unicode lưu dạng hex chưa hỗ trợ")
        case let .unsupportedTextStorage(query): localized("văn bản lưu dạng chưa hỗ trợ (query \(String(query)))")
        case .textShorterThanDeclared: localized("mục văn bản RVF ngắn hơn số dòng khai báo")
        case .nonText(type: -1): localized("đường kẻ ngang (bản ghi RVF -1) chưa hỗ trợ")
        case .nonText(type: -3): localized("ảnh (bản ghi RVF -3) chưa hỗ trợ")
        case .nonText(type: -4): localized("hotspot (bản ghi RVF -4) chưa hỗ trợ")
        case .nonText(type: -6): localized("bullet (bản ghi RVF -6) chưa hỗ trợ")
        case let .nonText(type): localized("nội dung RVF loại \(String(type)) (có thể là bảng hoặc đối tượng khác) chưa hỗ trợ")
        }
        switch skip.cause {
        case .none: break
        case let .fewerLinesThanSpecification(count):
            text += " " + localized("(số dòng khai báo \(count) ít hơn bố cục của đặc tả)")
        case .blockEndedEarly:
            text += " " + localized("(khối hết trước số dòng khai báo)")
        case .crossedNextRecord:
            text += " " + localized("(số dòng khai báo không khớp bố cục: lấn sang bản ghi kế tiếp)")
        }
        if skip.stopped { text += "; " + localized("phần còn lại bị bỏ qua") }
        return text
    }
}
