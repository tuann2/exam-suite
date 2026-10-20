import AppKit
import OSLog

/// Bước lưu của **Thử đề này** bằng `NSDocument` của **chính cửa sổ** soạn đề đã bấm (document SwiftUI của
/// `DocumentGroup` là `NSDocument` bên dưới; `AuthoringDocumentBridge` gắn nó vào bộ soạn đề): có thay đổi chưa lưu hoặc
/// chưa từng lưu thì lưu như ⌘S; chưa từng lưu thì macOS hỏi chỗ lưu (hộp Lưu, như Lưu thành). Huỷ hộp Lưu, hoặc lưu
/// lỗi (macOS đã báo), là không thử.
@MainActor
public enum TryExamDocumentSaver {
    private static let log = Logger(subsystem: "vn.io.nt0.examsuite.admin", category: "authoring.tryExam")

    /// Lưu document của cửa sổ chứa `editor`. Bộ soạn đề chưa gắn với document nào (cửa sổ chưa hiện xong) thì không
    /// thử, không lưu nhầm document khác.
    public static func save(for editor: AuthoringEditor) async -> TryExamSaveOutcome {
        guard let save = editor.saveForTrial else {
            log.error("Try exam: editor has no document yet")
            NSSound.beep()
            return .cancelled
        }
        return await save()
    }

    /// Lưu `document` nếu cần. Không có thay đổi và đã có file thì không ghi lại.
    static func save(_ document: NSDocument) async -> TryExamSaveOutcome {
        if let url = document.fileURL, !document.isDocumentEdited {
            return .saved(url)
        }
        let didSave = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            let receiver = SaveReceiver { continuation.resume(returning: $0) }
            document.save(
                withDelegate: receiver,
                didSave: #selector(SaveReceiver.document(_:didSave:contextInfo:)),
                contextInfo: Unmanaged.passRetained(receiver).toOpaque()
            )
        }
        guard didSave, let url = document.fileURL else {
            log.info("Try exam: document not saved")
            return .cancelled
        }
        return .saved(url)
    }
}

/// Đích của `save(withDelegate:didSave:contextInfo:)` (API kiểu selector của AppKit). Tự giữ mình qua `contextInfo`
/// tới khi AppKit gọi lại.
private final class SaveReceiver: NSObject {
    private let completion: (Bool) -> Void

    init(completion: @escaping (Bool) -> Void) {
        self.completion = completion
    }

    @objc func document(_ document: NSDocument, didSave: Bool, contextInfo: UnsafeMutableRawPointer?) {
        if let contextInfo { Unmanaged<SaveReceiver>.fromOpaque(contextInfo).release() }
        completion(didSave)
    }
}
