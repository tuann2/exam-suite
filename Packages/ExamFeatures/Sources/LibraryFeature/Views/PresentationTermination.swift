import AppKit
import SwiftUI

extension View {
    /// Sheet (hay popover) này **không chặn app thoát**: ⌘Q, ⌥⌘Q, Thoát từ Dock, đăng xuất/khởi động lại/tắt máy và lệnh
    /// thoát của AppleScript đi qua quy trình thoát chuẩn của AppKit như khi không có sheet: hỏi lưu đề chưa lưu, tự lưu
    /// (bản Admin), rồi `applicationShouldTerminate` của app delegate (hỏi Bỏ bài khi có bài chưa nộp). Gắn trong **nội
    /// dung** của mọi `.sheet` của hai app; `scripts/check_quit_sheets.py` (trong `check.sh`) kiểm.
    ///
    /// Vì sao: sheet SwiftUI mặc định chặn app thoát (SDK: `presentationPreventsAppTermination(_:)`; AppKit:
    /// `NSWindow.preventsApplicationTerminationWhenModal` mặc định YES). Khi một cửa sổ còn sheet như vậy, `terminate(_:)`
    /// trả về ngay mà không hỏi app delegate (⌘Q không làm gì; UI test PR #42 thấy app kẹt), và Apple event thoát (Dock,
    /// đăng xuất) bị trả `userCanceledErr` ngay nên đăng xuất bị huỷ. Thử trên app SwiftUI tối giản (macOS 26.6, plan
    /// giai đoạn 5, Decisions 2026-10-17): có modifier này thì cả hai đường đều hỏi app delegate; SwiftUI đóng sheet (binding
    /// về nil/false) **trước** khi hỏi; app delegate huỷ thì Apple event được trả `userCanceledErr` (đăng xuất bị huỷ gọn),
    /// đồng ý thì app thoát. Huỷ thoát (Tiếp tục làm, Huỷ ở hộp hỏi lưu) thì sheet đã đóng: không mất dữ liệu đã lưu hay
    /// bài đang làm, nhưng lựa chọn đang điền trên sheet (ví dụ Trước khi thi) phải chọn lại.
    ///
    /// Hộp hỏi hai nút hay có nút huỷ hoại (`.alert`, `.confirmationDialog`: "Vẫn nộp?", hộp xác nhận xoá) không gắn gì,
    /// vẫn chặn thoát như mặc định của macOS (Nt0 chốt 2026-10-17): người dùng trả lời hộp hỏi trước.
    ///
    /// macOS 15.4 trở lên dùng modifier của SwiftUI; macOS 15.0–15.3 (chưa có modifier) đặt thẳng cờ của AppKit trên cửa
    /// sổ sheet (`TerminationAllowingSheetWindow`).
    public func presentationAllowsAppTermination() -> some View {
        modifier(AllowsAppTermination())
    }
}

/// Phần thân của `presentationAllowsAppTermination()`.
struct AllowsAppTermination: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 15.4, *) {
            content.presentationPreventsAppTermination(false)
        } else {
            content.background(TerminationAllowingSheetWindow())
        }
    }
}

/// macOS 15.0–15.3: đặt `preventsApplicationTerminationWhenModal = false` cho cửa sổ chứa view (cửa sổ của sheet) mỗi khi
/// view vào cửa sổ hay được cập nhật. Không dùng ở macOS 15.4 trở lên, nơi SwiftUI tự quản cờ này theo modifier của nó.
/// View trơ: không vẽ, không nhận chuột, không vào cây trợ năng.
struct TerminationAllowingSheetWindow: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowFlagView {
        let view = WindowFlagView()
        view.setAccessibilityElement(false)
        return view
    }

    func updateNSView(_ view: WindowFlagView, context: Context) {
        view.allowTermination()
    }

    final class WindowFlagView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            allowTermination()
        }

        func allowTermination() {
            window?.preventsApplicationTerminationWhenModal = false
        }

        /// Không nhận chuột: view chỉ để đặt cờ, nằm dưới nội dung sheet.
        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }
    }
}
