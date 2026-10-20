import AppKit
import UniformTypeIdentifiers

/// Hộp của macOS cho Xuất PDF… và In… (docs/product/export-print.md): hộp lưu chuẩn (`NSSavePanel`, kiểu `.pdf`, thư
/// mục lần trước do macOS nhớ), hộp In chuẩn (`PDFDocument.printOperation`, co vừa khổ giấy), hộp báo lỗi. Mỗi hộp là
/// sheet trên cửa sổ đang xuất (nil: hộp riêng). Không unit test được (hộp thật); luồng gọi chúng có test với bản giả.
///
/// Lần xuất đã bị huỷ (Huỷ, đóng cửa sổ, thoát app) thì không mở hộp nào: cửa sổ có thể đã đóng, và hộp riêng của cả app
/// (`runModal`) cho một cửa sổ không còn là sai.
@MainActor
public enum ReportPanels {
    /// Chờ sheet SwiftUI (hộp chọn, tiến độ) đóng hẳn rồi mới mở sheet AppKit trên cùng cửa sổ. Dừng ngay khi task bị huỷ
    /// (`Task.sleep` của task đã huỷ trả về ngay, nên không kiểm thì vòng lặp quay liền trên main actor tới hết hạn).
    static func waitUntilNoSheet(on window: NSWindow, timeout: Duration = .seconds(2)) async {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout
        while window.attachedSheet != nil, clock.now < deadline, !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(20))
        }
    }

    /// Hộp lưu PDF với tên gợi ý; nil khi người dùng Huỷ. Không đặt `directoryURL`: macOS mở thư mục lần trước.
    public static func chooseDestination(suggestedName: String, for window: NSWindow?) async -> URL? {
        guard !Task.isCancelled else { return nil }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = suggestedName
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        guard let window, window.isVisible else {
            return panel.runModal() == .OK ? panel.url : nil
        }
        await waitUntilNoSheet(on: window)
        guard !Task.isCancelled else { return nil }
        return await withCheckedContinuation { continuation in
            panel.beginSheetModal(for: window) { response in
                continuation.resume(returning: response == .OK ? panel.url : nil)
            }
        }
    }

    /// Hộp In chuẩn cho PDF đã dựng (`ReportPrinting`, co vừa khổ giấy); chờ tới khi hộp In và lần in xong. `false` khi
    /// PDFKit không tạo được thao tác In (người dùng Huỷ hộp In, hay lần xuất đã bị huỷ, vẫn là `true`).
    public static func print(_ pdf: ReportPDF, jobTitle: String, for window: NSWindow?) async -> Bool {
        guard !Task.isCancelled else { return true }
        guard let operation = ReportPrinting.printOperation(for: pdf, jobTitle: jobTitle) else { return false }
        operation.showsPrintPanel = true
        operation.showsProgressPanel = true
        guard let window, window.isVisible else {
            operation.run()
            return true
        }
        await waitUntilNoSheet(on: window)
        guard !Task.isCancelled else { return true }
        let completion = PrintCompletion()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            completion.continuation = continuation
            operation.runModal(
                for: window,
                delegate: completion,
                didRun: #selector(PrintCompletion.printOperationDidRun(_:success:contextInfo:)),
                contextInfo: nil
            )
        }
        return true
    }

    /// Hộp báo lỗi (tiêu đề + lý do); chờ người dùng đóng.
    public static func presentFailure(title: String, message: String, for window: NSWindow?) async {
        guard !Task.isCancelled else { return }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        guard let window, window.isVisible else {
            alert.runModal()
            return
        }
        await waitUntilNoSheet(on: window)
        guard !Task.isCancelled else { return }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            alert.beginSheetModal(for: window) { _ in continuation.resume() }
        }
    }
}

/// Nhận `didRun` của `NSPrintOperation.runModal(for:delegate:didRun:contextInfo:)` (API dạng selector).
@MainActor
private final class PrintCompletion: NSObject {
    var continuation: CheckedContinuation<Void, Never>?

    @objc func printOperationDidRun(_ operation: NSPrintOperation, success: Bool, contextInfo: UnsafeMutableRawPointer?) {
        continuation?.resume()
        continuation = nil
    }
}
