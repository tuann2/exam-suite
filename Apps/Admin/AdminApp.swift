import AdminShell
import SwiftUI

/// Bản Admin (`vn.io.nt0.examsuite.admin`): thư viện, luyện tập/thi và soạn đề.
/// Scene đầu (cửa sổ Thư viện) mở khi khởi động; DocumentGroup nhận file `.exam`
/// mở từ Finder vào cửa sổ soạn đề. Spike giai đoạn 0: docs/plans/completed/giai-doan-0-chuan-bi.md.
@main
struct AdminApp: App {
    /// Giữ thư viện và phiên thi của app, hỏi trước khi thoát khi có bài chưa nộp (xem AdminAppDelegate).
    @NSApplicationDelegateAdaptor(AdminAppDelegate.self) private var appDelegate

    var body: some Scene {
        AdminScenes(delegate: appDelegate)
    }
}
