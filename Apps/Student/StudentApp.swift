import StudentShell
import SwiftUI

/// Bản Học viên (`vn.io.nt0.examsuite`). Chỉ chứa điểm vào; mọi giao diện nằm
/// trong Packages/ExamFeatures. Target này không link AuthoringFeature.
@main
struct StudentApp: App {
    /// Giữ thư viện và phiên thi của app, nhận file `.exam` mở từ Finder, hỏi trước khi thoát khi có bài
    /// chưa nộp (xem StudentAppDelegate).
    @NSApplicationDelegateAdaptor(StudentAppDelegate.self) private var appDelegate

    var body: some Scene {
        StudentScenes(delegate: appDelegate)
    }
}
