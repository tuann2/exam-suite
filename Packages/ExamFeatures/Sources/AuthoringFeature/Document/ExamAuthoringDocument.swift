import AuthoringData
import ExamFile
import ExamKit
import Foundation
import LibraryData
import os
import SwiftUI
import UniformTypeIdentifiers

/// Document `.exam` của cửa sổ soạn đề (bản Admin; docs/product/authoring.md, mục Mở cửa sổ soạn đề và
/// Lưu, hoàn tác, khôi phục). Lưu, Lưu thành, Đổi tên, Versions, tự lưu và khôi phục sau crash là của macOS
/// (`DocumentGroup` + `ReferenceFileDocument`).
///
/// - Đọc chế độ **dễ** (exam-format.md): đề có lỗi vẫn mở và sửa được. Đọc thêm một lần chế độ nghiêm để
///   biết bản Học viên có từ chối **file đang lưu** không (trường lạ, khoá trùng, dấu phẩy thừa… không còn
///   thấy được sau khi giải mã).
/// - Ghi bằng `ExamPackageWriter` qua `ExamDraft.packageForSaving`: ảnh không còn câu nào dùng không được ghi.
/// - Nội dung đề nằm ở `AuthoringEditor` (main actor, mọi thao tác sửa và Hoàn tác); document giữ bản sao
///   mới nhất sau khóa để `snapshot(contentType:)` và `fileWrapper(snapshot:configuration:)` đọc được từ bất
///   kỳ luồng nào. Sao chép `ExamDraft` là O(1) (copy-on-write).
public final class ExamAuthoringDocument: ReferenceFileDocument, @unchecked Sendable {
    public typealias Snapshot = ExamPackage

    public static var readableContentTypes: [UTType] { [.examPackage] }

    private static let log = Logger(subsystem: "vn.io.nt0.examsuite.admin", category: "authoring.document")

    private struct State: Sendable {
        var draft: ExamDraft
        var fileRejection: String?
        var misnamedImages: Set<String>
        /// Tăng mỗi lần macOS chụp đề để lưu (lưu tay, tự lưu): lần gõ tiếp theo mở bước Hoàn tác mới để
        /// document được đánh dấu "Đã sửa" lại (`AuthoringEditor`, gộp gõ chữ).
        var saveGeneration = 0
    }

    private let state: OSAllocatedUnfairLock<State>
    @MainActor private var loadedEditor: AuthoringEditor?
    /// Báo cáo import của document mở từ **Import đề…** (chỉ trong bộ nhớ, không ghi vào file).
    private let importReport: ImportReportState?

    /// Đề mới (⌘N): `ExamDraft.newExam` (authoring.md, phương án 2), chưa lưu; tên đề và tên phần đầu theo ngôn ngữ
    /// giao diện lúc tạo (`DefaultContentNames.interface`).
    public convenience init() {
        self.init(names: .interface())
    }

    /// Đề mới với tên mặc định cho trước (test kiểm theo ngôn ngữ cố định).
    convenience init(names: DefaultContentNames) {
        self.init(draft: .newExam(names: names))
    }

    /// Document chưa lưu với nội dung cho trước. **Import đề…** mở kết quả import bằng
    /// `newDocument(ExamAuthoringDocument(imported:))`.
    public init(
        draft: ExamDraft,
        fileRejection: String? = nil,
        misnamedImages: Set<String> = [],
        importReport: ImportReportState? = nil
    ) {
        state = OSAllocatedUnfairLock(initialState: State(
            draft: draft, fileRejection: fileRejection, misnamedImages: misnamedImages
        ))
        self.importReport = importReport
    }

    /// Document chưa lưu chứa đề vừa import, kèm báo cáo import (docs/product/import.md, Luồng bước 4–5). Đề import
    /// chưa có file nên không có lý do từ chối ở mức file hay ảnh sai tên trong file (`fileRejection` nil,
    /// `misnamedImages` rỗng): ảnh của đề import đã được đặt tên theo SHA-256.
    public convenience init(imported: ImportedExam) {
        self.init(draft: imported.draft, fileRejection: nil, misnamedImages: [], importReport: imported.report)
    }

    public convenience init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw Self.cocoaError(
                .fileReadCorruptFile,
                reason: localized("File đề không đọc được (không phải file thường).")
            )
        }
        try self.init(fileData: data)
    }

    /// Mở từ byte của file `.exam` (dễ), kèm lý do bản Học viên từ chối file nếu có.
    public convenience init(fileData data: Data) throws {
        let package: ExamPackage
        do {
            package = try ExamPackageReader.read(data, mode: .lenient)
        } catch {
            Self.log.error("Cannot open .exam package: \(String(describing: error), privacy: .public)")
            throw Self.cocoaError(.fileReadCorruptFile, reason: Self.describe(error))
        }
        let rejection = Self.fileLevelRejection(for: data)
        let referenced = Set(package.exam.allQuestions.compactMap(\.image)).subtracting(package.media.keys)
        let misnamed = Self.misnamedImages(in: data, referenced: referenced)
        Self.log.info("""
            Opened .exam for editing: \(package.exam.questionCount) questions, \(package.media.count) media, \
            file-level student rejection: \(rejection != nil), misnamed images: \(misnamed.count)
            """)
        self.init(draft: ExamDraft(package: package), fileRejection: rejection, misnamedImages: misnamed)
    }

    // MARK: - Trạng thái dùng chung với cửa sổ

    /// Bộ soạn đề của document (một cho mỗi document, tạo khi cửa sổ cần lần đầu).
    @MainActor public var editor: AuthoringEditor {
        if let loadedEditor { return loadedEditor }
        let current = state.withLock { $0 }
        let editor = AuthoringEditor(
            draft: current.draft, fileRejection: current.fileRejection, misnamedImages: current.misnamedImages,
            importReport: importReport,
            storage: self
        )
        loadedEditor = editor
        return editor
    }

    /// Đề hiện tại (bản sao mới nhất mà bộ soạn đề đã ghi vào).
    public var draft: ExamDraft { state.withLock { $0.draft } }

    // MARK: - Lưu

    public func snapshot(contentType: UTType) throws -> ExamPackage {
        state.withLock { state in
            state.saveGeneration += 1
            return state.draft.packageForSaving
        }
    }

    public func fileWrapper(snapshot: ExamPackage, configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try write(snapshot))
    }

    /// Byte file của bản chụp. Lỗi chỉ có ở file cũ (`fileRejection`, ảnh sai tên) **không** xoá ở đây: macOS ghi
    /// byte này sau khi hàm trả về và có thể thất bại. Bộ soạn đề đọc lại file trên đĩa sau đó (`recheckFile(at:)`).
    func write(_ snapshot: ExamPackage) throws -> Data {
        let data = try Self.fileData(for: snapshot)
        Task { @MainActor [weak self] in self?.loadedEditor?.fileMayHaveBeenWritten() }
        return data
    }

    /// Byte của file `.exam` cho một bản chụp (ghi bằng `ExamPackageWriter`).
    public static func fileData(for snapshot: ExamPackage) throws -> Data {
        do {
            return try ExamPackageWriter.write(snapshot)
        } catch {
            log.error("Cannot write .exam package: \(String(describing: error), privacy: .public)")
            throw cocoaError(.fileWriteUnknown, reason: describe(error))
        }
    }

    // MARK: - Đọc nghiêm như bản Học viên

    /// Lý do bản Học viên (đọc nghiêm) từ chối **file** này, ngoài lỗi kiểm đề: lỗi kiểm đề đã có trong thanh
    /// lỗi và đổi theo từng lần sửa, nên không lặp ở đây. `nil` nếu đọc nghiêm chỉ có thể rớt vì lỗi kiểm đề.
    static func fileLevelRejection(for data: Data) -> String? {
        do {
            _ = try ExamPackageReader.read(data, mode: .strict)
            return nil
        } catch ExamFileError.validationFailed {
            return nil
        } catch ExamFileError.missingMedia, ExamFileError.invalidMediaPath {
            // Ảnh thiếu, đường dẫn ảnh sai cũng là lỗi kiểm đề (`imageNotFound`, `imagePathInvalid`) trong thanh lỗi.
            return nil
        } catch {
            return describe(error)
        }
    }

    /// Ảnh trong `referenced` (câu tham chiếu nhưng bộ đọc không nạp) có entry cùng tên trong file: ảnh sai tên mà
    /// ExamFile bỏ qua (exam-format.md, mục Gói), sẽ mất khi lưu (authoring.md, mục Ảnh).
    static func misnamedImages(in data: Data, referenced: Set<String>) -> Set<String> {
        guard !referenced.isEmpty, let names = ZipEntryNames.names(in: data) else { return [] }
        return referenced.intersection(names)
    }

    /// Câu báo của lỗi đọc/ghi gói đề theo ngôn ngữ giao diện (`ErrorMessages`); lỗi khác dùng câu của hệ thống.
    static func describe(_ error: any Error) -> String {
        AuthoringMessages.message(for: error)
    }

    /// Lỗi Cocoa kèm lý do (chữ của catalog) để hộp thoại của macOS nói rõ vì sao không mở/lưu được.
    private static func cocoaError(_ code: CocoaError.Code, reason: String) -> CocoaError {
        CocoaError(code, userInfo: [NSLocalizedFailureReasonErrorKey: reason])
    }
}

extension ExamAuthoringDocument: AuthoringDraftStorage {
    func store(_ draft: ExamDraft) {
        state.withLock { $0.draft = draft }
    }

    var saveGeneration: Int { state.withLock { $0.saveGeneration } }
}
