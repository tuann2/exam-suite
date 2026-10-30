import AppKit
import ExamKit
@testable import InterfaceCore
@testable import LibraryFeature
@testable import SessionFeature
import SwiftUI
import Testing

/// Nhãn Đúng/Sai trên lựa chọn sau **Kiểm tra đáp án** đạt tương phản trên ảnh chụp thật (review độc lập #54 S1): nút của
/// lựa chọn bị khoá làm mờ nội dung, nhãn trước đây chỉ còn ~2,2:1 dù màu của bảng đạt 4,5:1. Đo trên ảnh sáng của màn làm
/// bài Luyện tập đã kiểm tra sai (như snapshot `attemptPracticeCheckedAnswer`): điểm ảnh đỏ đậm nhất (biểu tượng ✕ của
/// "Sai", trên hàng đã chọn nền nhạt teal) và xanh đậm nhất (✓ của "Đúng", trên nền cửa sổ) ở nửa phải vùng câu hỏi.
/// Không so ảnh tham chiếu.
extension SnapshotSuite {
    @MainActor
    @Suite("Nhãn Đúng/Sai sau Kiểm tra đáp án không bị làm mờ")
    struct CheckedAnswerContrastTests {
        @Test("Biểu tượng + chữ Đúng/Sai đạt 4,5:1 trên nền của hàng (ảnh chụp sáng)")
        func checkMarksKeepContrast() async throws {
            SnapshotHost.prepareProcess()
            if let problem = await SnapshotHost.environmentProblem() {
                Issue.record(Comment(rawValue: problem))
                return
            }
            let harness = SessionHarness()
            let attempt = try await harness.start(SnapshotContent.attemptPackage(), mode: .practice)
            _ = attempt.goTo(index: 2)
            attempt.answerWrongly()
            attempt.perform(.checkAnswer)
            let window = harness.window(for: attempt)
            let content = AttemptScreen(window: window, attempt: attempt)
                .environment(window)
                .frame(minWidth: SessionStyle.minWindowSize.width, minHeight: SessionStyle.minWindowSize.height)
                .tint(SessionStyle.accentForeground)
            let image = await SnapshotHost.image(of: content, appearance: .light)
            let rep = try #require(image.representations.compactMap { $0 as? NSBitmapImageRep }.first)

            var darkestRed: LibraryPalette.RGB?
            var darkestGreen: LibraryPalette.RGB?
            // Nửa phải vùng câu hỏi (cửa sổ 960, bảng câu hỏi bên phải từ ~700 pt): chỉ có nhãn Đúng/Sai của hàng lựa chọn.
            for x in 400 ..< 690 {
                for y in 0 ..< rep.pixelsHigh {
                    guard let color = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                    let rgb = Self.rgb(color)
                    let (r, g, b) = (Int(rgb.red), Int(rgb.green), Int(rgb.blue))
                    if r > g + 60, r > b + 60, rgb.luminance < (darkestRed?.luminance ?? 1) { darkestRed = rgb }
                    if g > r + 40, g > b + 20, rgb.luminance < (darkestGreen?.luminance ?? 1) { darkestGreen = rgb }
                }
            }
            let red = try #require(darkestRed, "không thấy nhãn Sai")
            let green = try #require(darkestGreen, "không thấy nhãn Đúng")
            let windowBackground = LibraryPalette.windowBackground(dark: false)
            let selectedRow = SessionStyle.selectedOptionBackground.solidRGB(dark: false)
            #expect(LibraryPalette.contrast(red, selectedRow) >= 4.5, "Sai \(red) trên hàng đã chọn \(selectedRow)")
            #expect(LibraryPalette.contrast(green, windowBackground) >= 4.5, "Đúng \(green) trên nền \(windowBackground)")
        }

        @Test("Đối chứng âm: nhãn Đúng/Sai đặt trong nút .plain bị khoá (cách cũ) đo dưới 4,5:1")
        func checkMarkInsideDisabledButtonFails() async throws {
            SnapshotHost.prepareProcess()
            if let problem = await SnapshotHost.environmentProblem() {
                Issue.record(Comment(rawValue: problem))
                return
            }
            let content = Button {} label: {
                OptionCheckMarkLabel(mark: .incorrect)
                    .padding(20)
            }
            .buttonStyle(.plain)
            .disabled(true)
            .frame(width: 200, height: 80)
            let image = await SnapshotHost.image(of: content, appearance: .light, size: CGSize(width: 200, height: 80))
            let rep = try #require(image.representations.compactMap { $0 as? NSBitmapImageRep }.first)
            var darkestRed: LibraryPalette.RGB?
            for x in 0 ..< rep.pixelsWide {
                for y in 0 ..< rep.pixelsHigh {
                    guard let color = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                    let rgb = Self.rgb(color)
                    let (r, g, b) = (Int(rgb.red), Int(rgb.green), Int(rgb.blue))
                    if r > g + 40, r > b + 40, rgb.luminance < (darkestRed?.luminance ?? 1) { darkestRed = rgb }
                }
            }
            let red = try #require(darkestRed, "không thấy nhãn Sai")
            let background = LibraryPalette.windowBackground(dark: false)
            #expect(LibraryPalette.contrast(red, background) < 4.5, "nút khoá phải làm mờ nhãn: \(red)")
        }

        private static func rgb(_ color: NSColor) -> LibraryPalette.RGB {
            func channel(_ value: CGFloat) -> UInt32 { UInt32((min(max(value, 0), 1) * 255).rounded()) }
            return LibraryPalette.RGB(hex: channel(color.redComponent) << 16 | channel(color.greenComponent) << 8 | channel(color.blueComponent))
        }
    }
}
