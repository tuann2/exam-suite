import MobileFeature
import SwiftUI

// Bản iOS (bản Học viên trên iPhone). Không import AuthoringFeature, AuthoringData, ExamImport (ADR 0003, kiểm bằng
// scripts/check_boundaries.py và scripts/check_bundle_boundary.sh).

/// Scene của bản iOS. Bước I0: chỉ màn gốc. Từ bước I2: nơi lưu theo `AppLaunchStorage` (kho trong container của app;
/// build Debug với `-ExamSuiteUITest <thư mục>` thì trong thư mục tạm của UI test), thư viện, tự tạm dừng khi xuống nền.
public struct MobileScenes: Scene {
    public init() {}

    public var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
