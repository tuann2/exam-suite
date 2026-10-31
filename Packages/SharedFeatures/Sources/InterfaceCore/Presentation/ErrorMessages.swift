import ExamFile
import ExamKit
import Foundation
import LibraryData

/// Câu báo lỗi và cảnh báo của lõi (ExamKit, ExamFile) và LibraryData, dựng ở tầng giao diện bằng chữ của String
/// Catalog từ mã + vị trí + đối số (docs/product/accessibility-localization.md, phương án 2; bước 7b của plan giai đoạn
/// 5). Lõi và LibraryData vẫn sinh câu tiếng Việt (`message`, `errorDescription`, `logMessage`) cho nhật ký, script và
/// test; giao diện không hiện các câu đó.
///
/// Bản tiếng Việt (ngôn ngữ nguồn) của mỗi câu ở đây trùng từng chữ với câu của lõi/LibraryData cho cùng đầu vào, trừ số:
/// số nội suy có ngăn nghìn theo ngôn ngữ giao diện ("10.001 ký tự"; lõi ghi "10001"). Test: `ErrorMessagesTests`.
/// LibraryFeature, SessionFeature, AuthoringFeature và bản iOS dùng chung các hàm này (catalog của InterfaceCore).
public enum ErrorMessages {
    // MARK: - Lỗi bất kỳ

    /// Câu báo cho một lỗi bất kỳ: lỗi của Exam Suite theo mã (`ExamFileError`, `LibraryError`); lỗi khác dùng câu của
    /// hệ thống (macOS đã dịch theo ngôn ngữ của app) hoặc `LocalizedError` của tầng giao diện (đã qua catalog).
    public static func message(for error: any Error) -> String {
        switch error {
        case let error as ExamFileError: message(for: error)
        case let error as LibraryError: message(for: error)
        default: systemDescription(of: error)
        }
    }

    /// Câu của hệ thống cho lỗi không phải của lõi/LibraryData (Cocoa, POSIX) hoặc lỗi của tầng giao diện có
    /// `LocalizedError` (chữ đã tra catalog). Chỗ duy nhất của InterfaceCore đọc `errorDescription`/
    /// `localizedDescription` (luật `core-text` của `scripts/check_localization.py`).
    public static func systemDescription(of error: any Error) -> String {
        (error as? any LocalizedError)?.errorDescription ?? error.localizedDescription // l10n-ignore: câu của hệ thống
    }

    // MARK: - Kiểm đề (ExamKit)

    /// Câu của một vấn đề kiểm đề (`ExamValidator`): theo mã, vị trí (số thứ tự từ 1) và đối số. Switch đủ case của
    /// `IssueCode` (không `default`) và `IssueLocation` (`Position`): mã hay loại vị trí mới thì trình biên dịch buộc thêm
    /// câu ở đây (review độc lập #51 N-c).
    public static func message(for issue: ValidationIssue) -> String {
        let a = issue.arguments
        let at = Position(issue.location)
        switch issue.code {
        // Cấp đề (tiêu đề: của đề hoặc của phần)
        case .titleEmpty:
            guard let limit = a.limit else { break }
            if let section = at.section {
                return localized("Phần \(section): tiêu đề đang trống. Nhập 1–\(limit) ký tự.")
            }
            return localized("Tên đề đang trống. Nhập 1–\(limit) ký tự.")
        case .titleTooLong:
            guard let value = a.value, let limit = a.limit else { break }
            if let section = at.section {
                return localized("Phần \(section): tiêu đề dài \(value) ký tự. Rút gọn còn tối đa \(limit) ký tự.")
            }
            return localized("Tên đề dài \(value) ký tự. Rút gọn còn tối đa \(limit) ký tự.")
        case .codeInvalid:
            guard let code = a.text else { break }
            return localized("Mã đề \"\(code)\" không hợp lệ. Dùng 1–32 ký tự gồm chữ không dấu, số, dấu chấm, gạch ngang hoặc gạch dưới.")
        case .passPercentOutOfRange:
            guard let value = a.value else { break }
            return localized("Ngưỡng đậu \(InterfaceLocale.percent(value)) nằm ngoài khoảng cho phép. Nhập số nguyên từ 0 đến 100.")
        case .timeLimitOutOfRange:
            guard let value = a.value else { break }
            return localized("Thời gian làm bài \(value) phút nằm ngoài khoảng cho phép. Nhập từ 1 đến 600 phút.")
        case .instructionsTooLong:
            guard let value = a.value, let limit = a.limit else { break }
            return localized("Hướng dẫn dài \(value) ký tự. Rút gọn còn tối đa \(limit) ký tự.")
        case .noSections:
            return localized("Đề chưa có phần nào. Thêm ít nhất một phần có câu hỏi.")
        // id trùng: ở phần hoặc câu, nơi xuất hiện trước là đề, phần hoặc câu.
        case .duplicateID:
            guard let id = a.text, let first = a.firstLocation.map(firstPlace) else { break }
            if case let (s, q)? = at.question {
                return localized("Phần \(s), câu \(q): id \(id) trùng với id của \(first). Mỗi đề, phần và câu phải có id riêng.")
            }
            guard let section = at.section else { break }
            return localized("Phần \(section): id \(id) trùng với id của \(first). Mỗi đề, phần và câu phải có id riêng.")
        // Cấp phần
        case .duplicateSectionTitle:
            guard let title = a.text, let section = at.section,
                  case let .section(firstIndex, _)? = a.firstLocation else { break }
            return localized("Phần \(section) trùng tiêu đề \"\(title)\" với phần \(firstIndex + 1). Đặt tên khác để học viên phân biệt khi xem kết quả.")
        case .sectionHasNoQuestions:
            guard let section = at.section else { break }
            return localized("Phần \(section) chưa có câu hỏi nào. Thêm ít nhất một câu hoặc xoá phần này.")
        // Cấp câu
        case .questionTextEmpty:
            guard case let (s, q)? = at.question else { break }
            return localized("Phần \(s), câu \(q) chưa có nội dung. Nhập nội dung câu hỏi.")
        case .questionTextTooLong:
            guard case let (s, q)? = at.question, let value = a.value, let limit = a.limit else { break }
            return localized("Phần \(s), câu \(q): nội dung dài \(value) ký tự. Rút gọn còn tối đa \(limit) ký tự.")
        case .explanationTooLong:
            guard case let (s, q)? = at.question, let value = a.value, let limit = a.limit else { break }
            return localized("Phần \(s), câu \(q): giải thích dài \(value) ký tự. Rút gọn còn tối đa \(limit) ký tự.")
        case .imagePathInvalid:
            guard case let (s, q)? = at.question, let image = a.text else { break }
            return localized("Phần \(s), câu \(q): đường dẫn ảnh \"\(image)\" không hợp lệ. Phải có dạng media/<16–64 ký tự hex thường>.<png|jpg|jpeg|gif|webp|heic>; chọn lại ảnh để app đặt tên đúng.")
        case .imageNotFound:
            guard case let (s, q)? = at.question, let image = a.text else { break }
            return localized("Phần \(s), câu \(q): ảnh \"\(image)\" không có trong gói đề. Chọn lại ảnh hoặc bỏ ảnh khỏi câu.")
        case .tooFewOptions:
            guard case let (s, q)? = at.question, let value = a.value, let limit = a.limit else { break }
            return localized("Phần \(s), câu \(q) có \(value) lựa chọn. Cần ít nhất \(limit) lựa chọn.")
        case .tooManyOptions:
            guard case let (s, q)? = at.question, let value = a.value, let limit = a.limit else { break }
            return localized("Phần \(s), câu \(q) có \(value) lựa chọn. Tối đa \(limit) lựa chọn (A–Z).")
        case .noCorrectAnswer:
            guard case let (s, q)? = at.question else { break }
            return localized("Phần \(s), câu \(q) chưa có đáp án đúng. Đánh dấu ít nhất một lựa chọn là đúng.")
        case .duplicateCorrectAnswer:
            guard case let (s, q)? = at.question, !a.optionIDs.isEmpty else { break }
            return localized("Phần \(s), câu \(q): đáp án đúng bị lặp (\(letters(a.optionIDs))). Mỗi lựa chọn chỉ ghi một lần trong đáp án.")
        case .correctAnswerNotInOptions:
            guard case let (s, q)? = at.question, !a.optionIDs.isEmpty else { break }
            return localized("Phần \(s), câu \(q): đáp án đúng \(letters(a.optionIDs)) không có trong các lựa chọn của câu. Chọn lại đáp án đúng.")
        case .singleHasMultipleCorrect:
            guard case let (s, q)? = at.question, let count = a.value else { break }
            return localized("Phần \(s), câu \(q) là câu một đáp án nhưng có \(count) đáp án đúng (\(letters(a.optionIDs))). Giữ một đáp án hoặc đổi sang loại nhiều đáp án.")
        case .multipleHasSingleCorrect:
            guard case let (s, q)? = at.question else { break }
            return localized("Phần \(s), câu \(q) là câu nhiều đáp án nhưng chỉ có một đáp án đúng. Kiểm tra lại, hoặc đổi sang loại một đáp án.")
        // Cấp lựa chọn
        case .optionIDOutOfOrder:
            guard case let (s, q, o)? = at.option, let id = a.optionID, let expected = a.expectedOptionID else { break }
            return localized("Phần \(s), câu \(q), lựa chọn thứ \(o) có mã \(id.description), phải là \(expected.description). Mã lựa chọn đi theo thứ tự A, B, C… theo vị trí.")
        case .optionTextEmpty:
            guard case let (s, q, o)? = at.option, let id = a.optionID else { break }
            return localized("Phần \(s), câu \(q), lựa chọn thứ \(o) (\(id.description)) chưa có nội dung. Nhập nội dung lựa chọn.")
        case .optionTextTooLong:
            guard case let (s, q, o)? = at.option, let id = a.optionID, let value = a.value, let limit = a.limit else { break }
            return localized("Phần \(s), câu \(q), lựa chọn thứ \(o) (\(id.description)) dài \(value) ký tự. Rút gọn còn tối đa \(limit) ký tự.")
        }
        // Không xảy ra với vấn đề do `ExamValidator` sinh (mỗi mã luôn ở đúng loại vị trí và có đủ đối số; test
        // `ErrorMessagesTests.everyIssueCodeMatchesCore`). Vấn đề dựng tay thiếu đối số: câu chung theo mã.
        return localized("Đề có lỗi (\(issue.code.rawValue)).")
    }

    /// Vị trí của vấn đề, đánh số từ 1. Switch đủ case của `IssueLocation`.
    private struct Position {
        /// Phần (cả với câu và lựa chọn); `nil` ở cấp đề.
        var section: Int?
        /// (phần, câu) với vị trí câu hoặc lựa chọn.
        var question: (Int, Int)?
        /// (phần, câu, lựa chọn) với vị trí lựa chọn.
        var option: (Int, Int, Int)?

        init(_ location: IssueLocation) {
            switch location {
            case .exam:
                break
            case let .section(index, _):
                section = index + 1
            case let .question(s, q, _):
                section = s + 1
                question = (s + 1, q + 1)
            case let .option(s, q, o, _):
                section = s + 1
                question = (s + 1, q + 1)
                option = (s + 1, q + 1, o + 1)
            }
        }
    }

    /// Nơi xuất hiện trước của id trùng, viết thường: "đề", "phần 2", "phần 1, câu 3".
    private static func firstPlace(_ location: IssueLocation) -> String {
        switch location {
        case .exam: localized("đề")
        case let .section(index, _): localized("phần \(index + 1)")
        case let .question(s, q, _), let .option(s, q, _, _): localized("phần \(s + 1), câu \(q + 1)")
        }
    }

    /// "A, D": chữ cái lựa chọn không dịch.
    private static func letters(_ ids: [OptionID]) -> String {
        ids.map(\.description).joined(separator: ", ")
    }

    // MARK: - Đọc/ghi gói đề (ExamFile)

    public static func message(for error: ExamFileError) -> String {
        switch error {
        case .notAZipArchive:
            localized("File không phải gói đề .exam hợp lệ (không đọc được dạng zip).")
        case .missingManifest:
            localized("Gói đề thiếu file exam.json ở gốc.")
        case let .corruptedEntry(path):
            localized("Gói đề bị hỏng: không giải nén được \(path).")
        case let .invalidJSON(problem):
            message(for: problem)
        // Số phiên bản định dạng là mã, giữ chữ số trơn (không ngăn nghìn; review độc lập #51 N-a).
        case let .unsupportedVersion(found, supported):
            localized("Đề cần phiên bản app mới hơn (định dạng v\(String(found)), app này hiểu tới v\(String(supported))).")
        case let .invalidVersion(version):
            localized("formatVersion không hợp lệ: \(String(version)) (phải từ 1 trở lên).")
        case let .unknownFields(paths):
            localized("Đề có trường không được hỗ trợ: \(pathList(paths)).")
        case let .duplicateJSONKeys(paths):
            localized("exam.json có khoá bị lặp lại trong cùng một object: \(pathList(paths)). Mỗi khoá chỉ được ghi một lần.")
        case let .nullValues(paths):
            localized("exam.json có giá trị null (không được phép): \(pathList(paths)). Bỏ hẳn trường tuỳ chọn thay vì ghi null.")
        case let .missingMedia(paths):
            localized("Gói đề thiếu ảnh: \(pathList(paths)).")
        case let .invalidMediaPath(paths):
            localized("Đường dẫn ảnh không hợp lệ: \(pathList(paths)).")
        case let .validationFailed(issues):
            validationFailed(errorCount: issues.count, first: issues.first)
        case let .duplicateEntry(path):
            localized("Gói đề bị hỏng: có nhiều entry cùng tên \(path).")
        case let .tooLarge(entry, limit):
            localized("Gói đề vượt giới hạn ở \(limitName(entry)) (tối đa \(limit)).")
        case let .tooDeep(limit):
            localized("exam.json lồng object/mảng quá sâu (tối đa \(limit) cấp). File có thể bị hỏng hoặc không phải đề thi.")
        case let .migrationFailed(from, reason):
            migrationMessage(from: from, reason: reason)
        case let .unsupportedImageType(ext):
            localized("Loại ảnh \"\(ext)\" không được hỗ trợ (chỉ png, jpg, jpeg, gif, webp, heic).")
        case let .writeFailed(problem):
            writeMessage(problem)
        case let .oef(problem):
            message(for: problem)
        }
    }

    /// File `.oef` của Open Exam Suite. Vị trí byte là mã kỹ thuật, giữ chữ số trơn như số phiên bản định dạng.
    private static func message(for problem: OEFProblem) -> String {
        switch problem {
        case .legacyFormat:
            localized("File .oef không đọc được: file .oef bản cũ (trước Open Exam Suite 4). Mở file bằng Open Exam Suite rồi lưu lại để có bản mới.")
        case let .malformed(offset):
            localized("File .oef không đọc được: dữ liệu hỏng ở byte \(String(offset)), hoặc file không phải đề của Open Exam Suite.")
        case .noQuestions:
            localized("File .oef không đọc được: file không có câu hỏi nào.")
        case let .tooLarge(.file, limit):
            localized("File .oef không đọc được: file vượt giới hạn \(limit) byte.")
        case let .tooLarge(.text, limit):
            localized("File .oef không đọc được: phần chữ của file vượt giới hạn \(limit) byte.")
        case let .tooLarge(.elements, limit):
            localized("File .oef không đọc được: file có quá \(limit) phần, câu, lựa chọn và đáp án.")
        case let .imageTooLarge(place, limit):
            localized("File .oef không đọc được: ảnh của \(oefPlace(place)) vượt giới hạn \(limit) byte.")
        case let .unknownFields(paths):
            localized("File .oef không đọc được: file có trường không được hỗ trợ: \(paths.joined(separator: ", ")).")
        case .passmarkOutOfRange:
            localized("File .oef không đọc được: ngưỡng đậu không nằm trong thang 0–1000.")
        case let .unsupportedImage(place):
            localized("File .oef không đọc được: ảnh của \(oefPlace(place)) không thuộc loại được hỗ trợ (png, jpg, gif, webp, heic).")
        case let .tooManyOptions(place, count):
            localized("File .oef không đọc được: \(oefPlace(place)) có \(count) lựa chọn (tối đa 26).")
        case let .duplicateOptionLetter(place, letter):
            localized("File .oef không đọc được: \(oefPlace(place)) có hai lựa chọn cùng chữ \(letter).")
        case let .answerNotInOptions(place, letters):
            localized("File .oef không đọc được: đáp án \(letters.joined(separator: ", ")) của \(oefPlace(place)) không khớp lựa chọn nào.")
        }
    }

    /// "phần 2, câu 3": vị trí câu trong file `.oef`, đếm từ 1.
    public static func oefPlace(_ place: OEFPlace) -> String {
        localized("phần \(place.section + 1), câu \(place.question + 1)")
    }

    private static func message(for problem: JSONProblem) -> String {
        switch problem {
        case .notUTF8:
            localized("exam.json không hợp lệ: exam.json phải mã hoá UTF-8.")
        case let .unparsable(description):
            localized("exam.json không hợp lệ: không phân tích được JSON (\(description)).")
        case .rootNotObject:
            localized("exam.json không hợp lệ: gốc của exam.json phải là một object.")
        case .missingFormatVersion:
            localized("exam.json không hợp lệ: thiếu khoá bắt buộc \"formatVersion\".")
        case .formatVersionNotInteger:
            localized("exam.json không hợp lệ: formatVersion phải là số nguyên.")
        case let .trailingCommas(paths):
            localized("exam.json không hợp lệ: dấu phẩy thừa trước dấu đóng } hoặc ] ở \(pathList(paths)). Xoá dấu phẩy sau phần tử cuối.")
        case let .missingKey(path, key):
            localized("exam.json không hợp lệ: \(displayPath(path)): thiếu khoá bắt buộc \"\(key)\".")
        case let .typeMismatch(path, type):
            localized("exam.json không hợp lệ: \(displayPath(path)): sai kiểu dữ liệu, cần \(type).")
        case let .valueMissing(path, type):
            localized("exam.json không hợp lệ: \(displayPath(path)): thiếu giá trị (null), cần \(type).")
        case let .invalidValue(path, detail):
            localized("exam.json không hợp lệ: \(displayPath(path)): giá trị không hợp lệ (\(detail)).")
        case let .other(description):
            localized("exam.json không hợp lệ: \(description)")
        }
    }

    /// Số phiên bản định dạng giữ chữ số trơn như mã định danh.
    private static func migrationMessage(from version: Int, reason: MigrationProblem) -> String {
        let from = String(version), to = String(version + 1)
        return switch reason {
        case .missingStep:
            localized("Không chuyển được đề từ định dạng v\(from) lên v\(to): chưa có bộ chuyển đổi v\(from) → v\(to).")
        case .invalidResult:
            localized("Không chuyển được đề từ định dạng v\(from) lên v\(to): kết quả chuyển đổi không phải JSON hợp lệ.")
        case let .stepFailed(description):
            localized("Không chuyển được đề từ định dạng v\(from) lên v\(to): \(description)")
        }
    }

    private static func writeMessage(_ problem: WriteProblem) -> String {
        switch problem {
        case let .encodingFailed(description):
            localized("Không ghi được gói đề: không mã hoá được exam.json (\(description)).")
        case .archiveUnavailable:
            localized("Không ghi được gói đề: không lấy được dữ liệu zip trong bộ nhớ.")
        case let .archiveFailed(description):
            localized("Không ghi được gói đề: lỗi tạo zip (\(description)).")
        case let .replaceFailed(fileName, reason):
            localized("Không ghi được gói đề: không thay được file \(fileName) (\(reason)).")
        }
    }

    /// "Đề có 3 lỗi, không mở được. Lỗi đầu tiên: …" (bản Học viên từ chối đề có lỗi kiểm đề).
    static func validationFailed(errorCount: Int, first: ValidationIssue?) -> String {
        guard let first else { return localized("Đề có lỗi, không mở được.") }
        if errorCount == 1 { return localized("Đề có 1 lỗi, không mở được: \(message(for: first))") }
        return localized("Đề có \(errorCount) lỗi, không mở được. Lỗi đầu tiên: \(message(for: first))")
    }

    /// Tên giới hạn của `tooLarge`: số entry, tổng dung lượng giải nén, hoặc đường dẫn entry trong gói.
    private static func limitName(_ entry: String) -> String {
        switch entry {
        case ExamPackageLimits.entryCountName: localized("<số entry>")
        case ExamPackageLimits.totalSizeName: localized("<tổng giải nén>")
        default: entry
        }
    }

    /// Đường dẫn JSON; gốc ("<gốc>") theo ngôn ngữ giao diện.
    private static func displayPath(_ path: String) -> String {
        path == JSONProblem.rootPath ? localized("<gốc>") : path
    }

    private static func pathList(_ paths: [String]) -> String {
        paths.map(displayPath).joined(separator: ", ")
    }

    // MARK: - Thư viện (LibraryData)

    public static func message(for error: LibraryError) -> String {
        switch error {
        case .entryNotFound:
            localized("Đề không còn trong thư viện.")
        case let .notAnExamFile(url):
            localized("\"\(url.lastPathComponent)\" không phải file đề .exam.")
        case let .unusableFile(problem):
            localized("Không dùng được file này: \(message(for: problem))")
        case let .differentExam(expectedTitle, foundTitle):
            localized("File chọn là đề \"\(foundTitle)\", không phải đề \"\(expectedTitle)\". Hãy chọn đúng file của đề này.")
        case .alreadyInLibrary:
            localized("Đề đã có lại trong thư viện nên không hoàn tác được.")
        case .duplicateAttempt:
            localized("Lần thi này đã được lưu.")
        case let .storage(detail):
            localized("Không lưu được thư viện: \(detail)")
        }
    }

    public static func message(for issue: LibraryStoreIssue) -> String {
        switch issue {
        case let .recoveredFromBrokenStore(url):
            localized("Không mở được dữ liệu thư viện cũ nên app đã tạo thư viện mới. Dữ liệu cũ được giữ ở \"\(url.lastPathComponent)\" trong \(url.deletingLastPathComponent().path).")
        case let .temporaryStore(reason):
            localized("Không lưu được thư viện vào đĩa (\(reason)). Thay đổi trong lần mở app này sẽ mất khi thoát.")
        }
    }

    public static func message(for problem: LibraryFileProblem) -> String {
        switch problem {
        case let .corrupt(reason), let .invalid(reason):
            message(for: reason)
        case let .needsNewerApp(found, supported):
            message(for: ExamFileError.unsupportedVersion(found: found, supported: supported))
        }
    }

    public static func message(for reason: FileProblemReason) -> String {
        switch reason {
        case let .package(error):
            message(for: error)
        case let .validationFailed(count, first):
            validationFailed(errorCount: count, first: first)
        case let .unreadable(description):
            localized("Không đọc được file: \(description)")
        case let .fileNotFound(fileName):
            localized("Không tìm thấy file \"\(fileName)\".")
        case let .inTrash(fileName):
            localized("File \"\(fileName)\" đang nằm trong Thùng rác. Hãy chuyển file ra khỏi Thùng rác rồi thêm lại.")
        case let .bookmarkFailed(fileName):
            localized("Không tạo được liên kết tới file \"\(fileName)\".")
        case let .readTimedOut(fileName):
            localized("Đọc file \"\(fileName)\" quá lâu.")
        case let .sampleUnreadable(detail):
            localized("Không đọc được đề mẫu: \(detail)")
        case let .sampleNotWritten(fileName):
            localized("Không ghi được file đề mẫu \(fileName).")
        case let .stored(text):
            // Chữ lưu từ lần chạy trước (tiếng Việt), hiện nguyên như trước bước 7b. Thực tế không lên giao diện: kết luận
            // mang lý do này không được dùng lại, file được đọc lại trước khi có trạng thái (`FileVerdict.isReusable`).
            text
        }
    }
}
