import AppKit
import XCTest

/// Đọc điểm ảnh trên màn hình tại một điểm theo toạ độ của XCUITest, đúng cả khi máy có nhiều màn hình và cửa sổ nằm trên
/// màn hình phụ.
///
/// `XCUIElement.screenshot()` của cửa sổ nằm trên màn hình không phải màn hình chính hỏng ("Failed to create screenshot.
/// Image creation failed"; cổng G3 2026-10-19: màn hình ngoài 3840×2160 đặt bên trái màn hình Retina, cửa sổ làm bài mở ở
/// (-1550, -44), plan giai đoạn 6, Decisions). Vì vậy chụp **cả màn hình** chứa điểm (`XCUIScreen`) rồi đọc điểm ảnh, tỉ lệ
/// điểm ảnh lấy từ chính ảnh chụp so với khung màn hình.
///
/// `XCUIScreen` không có khung công khai: khung lấy từ `NSScreen` của tiến trình chạy test (cùng phiên đăng nhập, cùng
/// màn hình). Hai danh sách cùng bắt đầu bằng màn hình chính (màn hình có thanh menu); màn hình khác ghép theo vị trí trong
/// danh sách khi hai danh sách cùng số màn hình, kiểm bằng tỉ lệ khung hình của ảnh chụp; lệch thì tìm màn hình duy nhất
/// có cùng tỉ lệ. Điểm không nằm trên màn hình nào thì thử màn hình chính. Không ghép được hay điểm ra ngoài ảnh thì trả
/// `nil` và ghi lý do vào `lastProblem` (test đưa vào thông báo lỗi), không đoán.
@MainActor
enum ScreenPixels {
    /// Lý do của lần đọc gần nhất không ra màu (`nil` khi lần gần nhất đọc được).
    static var lastProblem: String?

    /// Màu sRGB (0–255) của điểm ảnh tại `point` (toạ độ XCUITest: điểm, gốc ở góc trên trái màn hình chính, trục y hướng
    /// xuống, như `XCUIElement.frame`).
    static func color(at point: CGPoint) -> (red: Int, green: Int, blue: Int)? {
        lastProblem = nil
        let frames = screenFrames()
        guard !frames.isEmpty else { return fail("NSScreen.screens rỗng: không biết khung màn hình nào") }
        let index = frames.firstIndex { $0.contains(point) } ?? 0
        let frame = frames[index]
        guard let captured = capture(screenAt: index, frame: frame, screenCount: frames.count) else { return nil }
        let (screen, rep) = captured
        let scale = CGFloat(rep.pixelsWide) / frame.width
        let x = Int(((point.x - frame.minX) * scale).rounded(.down))
        let y = Int(((point.y - frame.minY) * scale).rounded(.down))
        let place = "điểm \(point) trên màn hình \(index + 1)/\(frames.count) khung \(frame), ảnh \(rep.pixelsWide)×"
            + "\(rep.pixelsHigh) px"
        guard (0 ..< rep.pixelsWide).contains(x), (0 ..< rep.pixelsHigh).contains(y) else {
            return fail("\(place): điểm ảnh (\(x), \(y)) ngoài ảnh (không màn hình nào chứa điểm)")
        }
        guard let color = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else {
            return fail("\(place): không đọc được màu điểm ảnh (\(x), \(y))")
        }
        let rgb = (Int((color.redComponent * 255).rounded()), Int((color.greenComponent * 255).rounded()),
                   Int((color.blueComponent * 255).rounded()))
        XCTContext.runActivity(named: "Màu tại \(place) (\(screen)): \(rgb)") { _ in }
        return rgb
    }

    /// Ảnh chụp màn hình chứa `point` (đính vào kết quả test để chẩn đoán); `nil` khi không ghép được màn hình.
    static func screenshot(containing point: CGPoint) -> XCUIScreenshot? {
        let frames = screenFrames()
        guard !frames.isEmpty else { return nil }
        let index = frames.firstIndex { $0.contains(point) } ?? 0
        return screen(at: index, frame: frames[index], screenCount: frames.count)?.shot
    }

    // MARK: - Nội bộ

    /// Khung các màn hình theo toạ độ của XCUITest, thứ tự của `NSScreen.screens` (màn hình chính trước).
    private static func screenFrames() -> [CGRect] {
        let screens = NSScreen.screens
        guard let primary = screens.first else { return [] }
        let top = primary.frame.maxY
        return screens.map { CGRect(x: $0.frame.minX, y: top - $0.frame.maxY, width: $0.frame.width, height: $0.frame.height) }
    }

    /// Chụp màn hình thứ `index` (theo `NSScreen.screens`) và giải mã ảnh.
    private static func capture(
        screenAt index: Int, frame: CGRect, screenCount: Int
    ) -> (XCUIScreen, NSBitmapImageRep)? {
        guard let found = screen(at: index, frame: frame, screenCount: screenCount) else { return nil }
        guard let rep = NSBitmapImageRep(data: found.shot.pngRepresentation) else {
            return fail("không giải mã được ảnh chụp màn hình \(index + 1)/\(screenCount)")
        }
        return (found.screen, rep)
    }

    /// `XCUIScreen` ứng với màn hình thứ `index` của `NSScreen.screens` cùng ảnh chụp của nó.
    private static func screen(
        at index: Int, frame: CGRect, screenCount: Int
    ) -> (screen: XCUIScreen, shot: XCUIScreenshot)? {
        let screens = XCUIScreen.screens
        func matches(_ shot: XCUIScreenshot) -> Bool {
            guard let rep = NSBitmapImageRep(data: shot.pngRepresentation), rep.pixelsHigh > 0, frame.height > 0 else {
                return false
            }
            let ratio = CGFloat(rep.pixelsWide) / CGFloat(rep.pixelsHigh)
            return abs(ratio - frame.width / frame.height) < 0.01
        }
        if screens.count == screenCount, screens.indices.contains(index) {
            let shot = screens[index].screenshot()
            if matches(shot) { return (screens[index], shot) }
        }
        let candidates = screens.map { ($0, $0.screenshot()) }.filter { matches($0.1) }
        guard candidates.count == 1, let only = candidates.first else {
            return fail("không ghép được XCUIScreen với màn hình \(index + 1)/\(screenCount) khung \(frame): "
                + "\(screens.count) XCUIScreen, \(candidates.count) màn hình cùng tỉ lệ khung hình")
        }
        return (only.0, only.1)
    }

    private static func fail<T>(_ problem: String) -> T? {
        lastProblem = problem
        XCTContext.runActivity(named: "ScreenPixels: \(problem)") { _ in }
        return nil
    }
}
