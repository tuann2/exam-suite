import Foundation

/// Kết quả nhập một file (docs/product/library.md, mục Thêm đề và "Phương án chờ Nt0 chốt").
public enum ImportOutcome: Hashable, Sendable {
    /// Đã thêm vào thư viện.
    case added(examID: UUID)
    /// Cùng file với một mục đã có: chọn mục đó, báo "Đề đã có trong thư viện". Thông tin thẻ được
    /// cập nhật theo lần đọc vừa rồi.
    case alreadyInLibrary(examID: UUID)
    /// Cùng id đề với một mục đã có nhưng khác file: hỏi "Đề này đã có trong thư viện từ file khác"
    /// với **Dùng file mới** (`LibraryStore.confirmReplace`) / **Huỷ** (không làm gì).
    case needsReplaceConfirmation(PendingReplacement)
    /// Không thêm: lý do và bước tiếp theo theo loại vấn đề.
    case rejected(LibraryFileProblem)
    /// Không phải file `.exam`: bỏ qua và báo.
    case skippedNotExam
}

/// Báo cáo của một lần nhập nhiều file, theo đúng thứ tự file đưa vào.
public struct ImportReport: Hashable, Sendable {
    public struct Item: Hashable, Sendable {
        public let url: URL
        public let outcome: ImportOutcome
    }

    public let items: [Item]

    public init(items: [Item]) {
        self.items = items
    }

    public var addedExamIDs: [UUID] {
        items.compactMap { if case let .added(id) = $0.outcome { id } else { nil } }
    }

    public var alreadyInLibraryExamIDs: [UUID] {
        items.compactMap { if case let .alreadyInLibrary(id) = $0.outcome { id } else { nil } }
    }

    public var pendingReplacements: [PendingReplacement] {
        items.compactMap { if case let .needsReplaceConfirmation(pending) = $0.outcome { pending } else { nil } }
    }

    /// File không thêm được kèm vấn đề, để báo gọn ở cuối.
    public var rejected: [Item] {
        items.filter { if case .rejected = $0.outcome { true } else { false } }
    }

    public var skippedURLs: [URL] {
        items.compactMap { if case .skippedNotExam = $0.outcome { $0.url } else { nil } }
    }

    /// Đề giao diện nên chọn sau khi nhập: đề cuối cùng vừa thêm hoặc đã có sẵn.
    public var examIDToSelect: UUID? {
        items.reversed().lazy.compactMap { item -> UUID? in
            switch item.outcome {
            case let .added(id), let .alreadyInLibrary(id): id
            default: nil
            }
        }.first
    }
}

/// File cùng id đề với một mục đã có, chờ người dùng chọn **Dùng file mới**.
public struct PendingReplacement: Identifiable, Hashable, Sendable {
    public var id: URL { file.url }
    public var examID: UUID { file.examID }
    /// Tên đề trong file mới.
    public var title: String { file.summary.title }
    public var newFileURL: URL { file.url }
    /// File mục đang dùng (đường dẫn biết gần nhất).
    public let existingFileURL: URL
    let file: ReadableFile
}

/// Đủ để hoàn tác **Xoá khỏi thư viện**: khôi phục y nguyên (bookmark, ngày thêm, cờ đề mẫu…).
public struct RemovedEntry: Hashable, Sendable {
    /// Mục như lúc bị xoá, để hiện "Đã xoá … khỏi thư viện".
    public let entry: LibraryEntry
    let record: LibraryRecord

    public var examID: UUID { entry.examID }
}

/// Kết quả tạo hoặc khôi phục đề mẫu.
public struct SampleReport: Hashable, Sendable {
    public struct Failure: Hashable, Sendable {
        /// Tên thư mục đề mẫu trong nguồn.
        public let sampleName: String
        /// Lý do dạng mã (giao diện dựng câu của catalog).
        public let reason: FileProblemReason
    }

    /// Số đề mẫu tìm thấy trong nguồn (0: chưa có đề mẫu, không làm gì).
    public var sampleCount: Int = 0
    /// Đề mẫu vừa được thêm vào thư viện (hoặc được ghi lại file khi khôi phục).
    public var addedExamIDs: [UUID] = []
    /// Đề mẫu đã có trong thư viện, giữ nguyên.
    public var keptExamIDs: [UUID] = []
    public var failures: [Failure] = []

    public init() {}

    /// Có thêm đề mẫu nào không: giao diện hiện dải chào mừng sau lần tạo đầu tiên.
    public var didAddSamples: Bool { !addedExamIDs.isEmpty }
}
