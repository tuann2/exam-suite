import AppKit
import SwiftUI

/// Nối bộ soạn đề với `NSDocument` của **chính cửa sổ** chứa nó (không dùng document "hiện tại" của AppKit, có thể là
/// cửa sổ khác):
///
/// - **Thử đề này** lưu đúng document đó (`AuthoringEditor.saveForTrial`, `TryExamDocumentSaver`).
/// - Document mở từ **Import đề…** được đánh dấu "Đã sửa" ngay khi có cửa sổ: document chưa lưu mà chưa sửa gì thì
///   macOS đóng (⌘W, ⌘Q) không hỏi, làm mất đề vừa import (import.md, Luồng bước 4: admin xem, sửa rồi Lưu).
/// - VoiceOver đọc "Đã lưu “tên file”" khi **Lưu**/**Lưu thành…** của cửa sổ này xong (`SaveAnnouncementObserver`).
struct AuthoringDocumentBridge: NSViewRepresentable {
    let editor: AuthoringEditor

    func makeNSView(context: Context) -> BridgeView {
        let view = BridgeView()
        view.editor = editor
        return view
    }

    func updateNSView(_ view: BridgeView, context: Context) {
        // SwiftUI có thể dựng document (và bộ soạn đề) mới trong cùng cửa sổ (Hoàn lại > Bản đã lưu).
        if view.editor !== editor {
            view.editor = editor
            view.attach()
        }
    }

    /// Document của cửa sổ vừa gắn với bộ soạn đề: gắn bước lưu của Thử đề này; đánh dấu "Đã sửa" nếu đề là kết quả
    /// import chưa đánh dấu.
    @MainActor
    static func attach(_ editor: AuthoringEditor, to document: @escaping @MainActor () -> NSDocument?) {
        editor.saveForTrial = {
            guard let document = document() else { return .cancelled }
            return await TryExamDocumentSaver.save(document)
        }
        if let current = document(), editor.takePendingImportChange() {
            current.updateChangeCount(.changeDone)
        }
    }

    final class BridgeView: NSView {
        weak var editor: AuthoringEditor?
        private var retried = false
        private var saveObserver: SaveAnnouncementObserver?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window == nil {
                saveObserver?.stop()
                saveObserver = nil
            }
            attach()
        }

        private var document: NSDocument? {
            window?.windowController?.document as? NSDocument
        }

        func attach() {
            guard let editor, let window else { return }
            AuthoringDocumentBridge.attach(editor) { [weak self] in self?.document }
            saveObserver?.stop()
            saveObserver = SaveAnnouncementObserver(
                window: window,
                document: { [weak self] in self?.document },
                announce: { [weak editor] text in editor?.announce(text) }
            )
            if document == nil, !retried {
                // Bộ điều khiển cửa sổ có thể chưa gắn document ở lượt này.
                retried = true
                DispatchQueue.main.async { [weak self] in self?.attach() }
            }
        }
    }
}
