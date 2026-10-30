import AppKit
@testable import InterfaceCore
@testable import LibraryFeature
import SwiftUI
import Testing

/// Reduce Transparency (docs/product/accessibility-localization.md, mục Dark Mode và tương phản: "nền mờ thay bằng nền
/// đặc"; plan giai đoạn 5 bước 8b): nền có độ trong mà app tự đặt (`AdaptiveBackground`: `.bar`, vật liệu, nền nhạt pha
/// màu) đọc giá trị môi trường `accessibilityReduceTransparency` và thành nền đặc. Chụp thật một cửa sổ nhỏ có lớp đỏ phía
/// sau nền đó: bình thường thấy đỏ xuyên qua; bật Reduce Transparency (`_accessibilityReduceTransparency` của môi trường,
/// như macOS đặt) thì không còn đỏ, chỉ còn màu đặc của nền. Không so ảnh tham chiếu.
///
/// Ở trong `SnapshotSuite` (tuần tự, dùng `NSApplication` của tiến trình snapshot). Kính và vật liệu bị ẩn khi chụp
/// (`GlassFlattener`), còn lớp tô nhạt của vật liệu: với `.bar` bình thường lớp đỏ ánh qua thành hồng, đó chính là chỗ nền
/// đặc phải che.
extension SnapshotSuite {
    @MainActor
    @Suite("Reduce Transparency: nền có độ trong của app thành nền đặc")
    struct ReduceTransparencyTests {
        private static let size = CGSize(width: 200, height: 200)

        /// Màu ở giữa ảnh chụp của `background` phủ lên lớp đỏ, với Reduce Transparency tắt hoặc bật.
        private func centerColor(_ background: AdaptiveBackground, reduceTransparency: Bool) async throws -> NSColor {
            // Như ảnh snapshot: cài đặt hiển thị của máy phải là mặc định (Reduce Transparency của hệ thống tắt), không thì
            // vật liệu tự vẽ đặc và phép kiểm "bình thường thấy lớp phía sau" sai vì lý do khác.
            SnapshotHost.prepareProcess()
            if let problem = await SnapshotHost.environmentProblem() {
                Issue.record(Comment(rawValue: problem))
            }
            let content = ZStack {
                Color.red
                Color.clear.adaptiveBackground(background)
            }
            .frame(width: Self.size.width, height: Self.size.height)
            .environment(\._accessibilityReduceTransparency, reduceTransparency)
            let image = await SnapshotHost.image(of: content, appearance: .light, size: Self.size)
            let rep = try #require(image.representations.compactMap { $0 as? NSBitmapImageRep }.first)
            // Giữa ảnh nằm trong vùng nội dung dù gốc toạ độ ở trên hay dưới (thanh tiêu đề chỉ ~28 pt).
            let color = try #require(rep.colorAt(x: rep.pixelsWide / 2, y: rep.pixelsHigh / 2)?.usingColorSpace(.sRGB))
            return color
        }

        @Test("Vật liệu .bar: bình thường lớp phía sau xuyên qua; bật Reduce Transparency thì nền đặc của cửa sổ")
        func barBecomesSolid() async throws {
            let normal = try await centerColor(.bar, reduceTransparency: false)
            let reduced = try await centerColor(.bar, reduceTransparency: true)
            // Khi chụp, lớp làm mờ của vật liệu bị ẩn, còn lớp tô nhạt của nó: đỏ phía sau ánh qua thành hồng (~1; 0,84; 0,85).
            #expect(normal.redComponent - normal.greenComponent > 0.1, "bình thường phải thấy lớp đỏ phía sau: \(normal)")
            let window = LibraryPalette.windowBackground(dark: false)
            #expect(abs(reduced.greenComponent * 255 - CGFloat(window.green)) < 6, "nền đặc phải là nền cửa sổ: \(reduced)")
            #expect(abs(reduced.redComponent * 255 - CGFloat(window.red)) < 6, "\(reduced)")
        }

        @Test("Nền nhạt pha màu (dải cảnh báo): bật Reduce Transparency thì thành màu đã trộn sẵn trên nền cửa sổ")
        func tintBecomesSolid() async throws {
            let tint = AdaptiveBackground.tint(LibraryPalette.warning, opacity: LibraryPalette.tintedBackgroundOpacity)
            let normal = try await centerColor(tint, reduceTransparency: false)
            let reduced = try await centerColor(tint, reduceTransparency: true)
            #expect(normal.greenComponent < 0.5, "bình thường nền nhạt để lộ lớp đỏ: \(normal)")
            let solid = tint.solidRGB(dark: false)
            #expect(abs(reduced.greenComponent * 255 - CGFloat(solid.green)) < 6, "\(reduced) ≠ \(solid)")
            #expect(abs(reduced.blueComponent * 255 - CGFloat(solid.blue)) < 6, "\(reduced) ≠ \(solid)")
        }
    }
}
