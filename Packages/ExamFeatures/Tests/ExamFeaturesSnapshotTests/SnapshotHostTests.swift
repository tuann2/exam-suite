import AppKit
import SwiftUI
import Testing

/// Kiểm chính helper chụp: ảnh không phụ thuộc hệ số phóng của màn hình chính (review #41, P2-1).
extension SnapshotSuite {
    @MainActor
    @Suite("Snapshot: helper chụp")
    struct SnapshotHostTests {
        /// Cửa sổ chụp vẽ ở 2x trên máy này, bất kể màn hình chính.
        @Test func renderingIsForcedToReferenceScale() async {
            SnapshotHost.prepareProcess()
            #expect(await SnapshotHost.scaleProblem() == nil)
        }

        /// Mô phỏng màn 1x (cửa sổ lấy hệ số 1): `scaleProblem` báo rõ, và ảnh khác ảnh vẽ ở 2x, tức là hệ số của
        /// cửa sổ thật sự quyết định cách vẽ (ép 2x là cần và đủ).
        @Test func simulated1xIsReportedAndChangesPixels() async throws {
            SnapshotHost.prepareProcess()
            let sample = Text("Câu 1: Người mua chịu rủi ro kể từ khi hàng được giao lên tàu")
                .font(.title3)
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            let size = CGSize(width: 480, height: 120)
            let at2x = try #require(await SnapshotHost.image(of: sample, appearance: .light, size: size).tiffRepresentation)
            SnapshotWindow.forcedScale = 1
            defer { SnapshotWindow.forcedScale = SnapshotHost.referenceScale }
            let problem = try #require(await SnapshotHost.scaleProblem())
            #expect(problem.contains("cửa sổ 1.0x"))
            let at1x = try #require(await SnapshotHost.image(of: sample, appearance: .light, size: size).tiffRepresentation)
            #expect(at1x != at2x)
        }

        /// Máy chạy test đang ở cài đặt hiển thị mặc định (ảnh tham chiếu chụp với cài đặt đó).
        @Test func displaySettingsAreDefault() async {
            SnapshotHost.prepareProcess()
            #expect(SnapshotHost.DisplaySettings.current == SnapshotHost.DisplaySettings())
            #expect(await SnapshotHost.environmentProblem() == nil)
        }

        /// Cài đặt khác mặc định được báo rõ, từng cái (review #41, P3-4).
        @Test(arguments: [
            (SnapshotHost.DisplaySettings(increaseContrast: true), "Increase Contrast"),
            (SnapshotHost.DisplaySettings(reduceTransparency: true), "Reduce Transparency"),
            (SnapshotHost.DisplaySettings(differentiateWithoutColor: true), "Differentiate Without Color"),
            (SnapshotHost.DisplaySettings(invertColors: true), "Invert colors"),
            (SnapshotHost.DisplaySettings(bodyPointSize: 15), "cỡ chữ hệ thống 15.0 pt"),
        ])
        func nonDefaultDisplaySettingIsReported(settings: SnapshotHost.DisplaySettings, mention: String) {
            #expect(SnapshotHost.settingsProblem(SnapshotHost.DisplaySettings()) == nil)
            #expect(SnapshotHost.settingsProblem(settings)?.contains(mention) == true)
        }

        /// Gợi ý kèm thông báo ảnh lệch nhắc các cài đặt không đọc được và lệnh ghi lại ảnh.
        @Test func mismatchHintNamesUnreadableSettings() {
            let hint = SnapshotHost.mismatchHint
            for mention in ["Show toolbar button shapes", "biểu tượng/widget", "Liquid Glass", "EXAMSUITE_SNAPSHOT_RECORD"] {
                #expect(hint.contains(mention))
            }
        }
    }
}
