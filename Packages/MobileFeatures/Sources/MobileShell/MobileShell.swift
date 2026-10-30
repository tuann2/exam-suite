import Foundation
import InterfaceCore
import LibraryData
import MobileFeature
import SwiftUI

// Bản iOS (bản Học viên trên iPhone). Không import AuthoringFeature, AuthoringData, ExamImport (ADR 0003, kiểm bằng
// scripts/check_boundaries.py và scripts/check_bundle_boundary.sh).

/// Scene của bản iOS: Thư viện, phiên thi, file `.exam` mở từ app khác (`onOpenURL`). Nơi lưu theo `AppLaunchStorage`
/// (kho, đề mẫu, cài đặt trong container của app; build Debug với `-ExamSuiteUITest <thư mục>` thì trong thư mục tạm
/// của UI test). `@AppStorage` của mọi view đọc/ghi `defaults` của app; số, ngày giờ theo ngôn ngữ giao diện, không
/// theo Region (`.interfaceLocale()`, như hai bản macOS; luật `scene-locale` của scripts/check_localization.py).
public struct MobileScenes: Scene {
    /// Một lần cho cả app (như app delegate của bản macOS): tạo lần đầu cần, không tạo lại khi SwiftUI dựng lại scene
    /// (mở kho SwiftData và tạo đề mẫu chỉ một lần).
    @MainActor private static let sharedApp = MobileAppModel(storage: resolveStorage())

    private let app: MobileAppModel

    public init() {
        app = Self.sharedApp
    }

    public var body: some Scene {
        WindowGroup {
            MobileRootView(app: app)
                .onOpenURL { url in app.open(url) }
        }
        .defaultAppStorage(app.storage.defaults)
        .interfaceLocale()
    }

    /// Tham số cô lập sai (chỉ build Debug): dừng app ngay, để không bao giờ rơi về kho và cài đặt thật.
    private static func resolveStorage() -> AppLaunchStorage {
        do {
            return try AppLaunchStorage.resolve(.student)
        } catch {
            FileHandle.standardError.write(Data("Exam Suite: không bật được chế độ cô lập của UI test: \(error)\n".utf8)) // l10n-ignore: log
            exit(EX_USAGE)
        }
    }
}
