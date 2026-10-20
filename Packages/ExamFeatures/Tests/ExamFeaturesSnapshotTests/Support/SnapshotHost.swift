import AppKit
import Foundation
@testable import LibraryFeature
import SnapshotTesting
import SwiftUI
import Testing

/// Vị trí cuộn của nội dung chính khi chụp.
enum SnapshotScroll: Sendable {
    /// Như khi vừa mở màn.
    case top
    /// Cuộn vùng cuộn lớn nhất tới cuối (phần dưới của câu dài, lựa chọn cuối, giải thích).
    case bottom
}

/// Giao diện sáng/tối của một ảnh chụp.
enum SnapshotAppearance: String, CaseIterable, Sendable {
    case light
    case dark

    var appearanceName: NSAppearance.Name { self == .light ? .aqua : .darkAqua }
}

/// Chụp một màn SwiftUI trong cửa sổ AppKit thật (không hiện lên màn hình) ở 960×640, sáng và tối, rồi so với ảnh
/// tham chiếu trong `__Snapshots__/` bằng swift-snapshot-testing (ADR 0010). Cách ghi lại ảnh:
/// docs/process/snapshot-tests.md.
///
/// Để ảnh giống nhau giữa các lần chạy (cùng máy):
/// - Cài đặt hệ thống ảnh hưởng tới cách vẽ được ghim **trong bộ nhớ của tiến trình test** (miền tham số
///   `NSArgumentDomain`, không ghi gì xuống đĩa, không đụng `defaults` của app hay của máy): ngôn ngữ và vùng
///   `vi_VN`, màu nhấn/tô chọn xanh mặc định, thanh cuộn kiểu nổi, cỡ biểu tượng sidebar vừa. Múi giờ của tiến trình
///   là Asia/Ho_Chi_Minh. Đồng hồ, seed và ngày giờ trong dữ liệu là giá trị cố định.
/// - Không hoạt ảnh (`Transaction.disablesAnimations`), giao diện sáng/tối đặt trên cửa sổ (`NSAppearance`).
/// - Lớp được vẽ ở hệ số 2x bất kể màn hình chính (`SnapshotWindow.backingScaleFactor`; màn hình ngoài 1x hay Mac
///   mini với màn 1080p vẫn ra cùng ảnh), rồi thu về ảnh 1x (điểm ảnh = point) để file nhỏ và ít nhạy với khử răng
///   cưa. Không ép được 2x thì test báo lỗi rõ (`scaleProblem`).
/// - Cài đặt trợ năng hiển thị (Increase Contrast, Reduce Transparency, Differentiate Without Color) và cỡ chữ hệ
///   thống không ghim được trong tiến trình: khác mặc định thì test báo lỗi rõ thay vì so ảnh sai. Cài đặt không đọc
///   được bằng API công khai (Show toolbar button shapes, kiểu biểu tượng/widget, kiểu Liquid Glass Clear/Tinted):
///   giữ mặc định trên máy tham chiếu, liệt kê ở docs/process/snapshot-tests.md và trong thông báo khi ảnh lệch.
///
/// Liquid Glass (macOS 26+: nền sidebar/inspector nổi, nút thanh công cụ) do WindowServer ghép nên không vẽ được
/// trong tiến trình: khi chụp, kính được làm phẳng tạm thời (`GlassFlattener`); bản thân hiệu ứng kính không được kiểm
/// (test tay Dark Mode vẫn cần). Cửa sổ và app được coi là đang dùng (`SnapshotWindow`, `SnapshotApplication`,
/// `controlActiveState = .key`) để control vẽ như khi người dùng làm việc.
@MainActor
enum SnapshotHost {
    /// Cửa sổ tối thiểu của cửa sổ làm bài, Thư viện, soạn đề (exam-taking.md, library.md, authoring.md).
    static let minimumWindow = CGSize(width: 960, height: 640)

    /// Biến môi trường bật ghi lại ảnh tham chiếu: `all` (ghi mọi ảnh), `failed` (chỉ ảnh khác), `missing` (chỉ ảnh
    /// chưa có). Không đặt (mặc định) thì chỉ so, thiếu ảnh tham chiếu là thất bại.
    static let recordVariable = "EXAMSUITE_SNAPSHOT_RECORD"

    /// So theo độ chính xác cảm nhận (ADR 0010): mỗi điểm ảnh được lệch tới mức mắt thường khó thấy; mọi điểm ảnh
    /// phải đạt.
    static let precision: Float = 1
    static let perceptualPrecision: Float = 0.98

    static var recordMode: SnapshotTestingConfiguration.Record {
        switch ProcessInfo.processInfo.environment[recordVariable]?.lowercased() {
        case "all", "1", "true": .all
        case "failed": .failed
        case "missing": .missing
        default: .never
        }
    }

    // MARK: - Ngôn ngữ

    /// Chạy `body` (dựng model, chụp) với chữ của catalog và số/ngày ép theo `language` (giai đoạn 5 bước 7c: snapshot
    /// tiếng Anh). Ép cho cả tiến trình (`InterfaceStrings.processLanguageOverride`), vì SwiftUI dựng lại view cả ngoài
    /// task của test; an toàn vì `SnapshotSuite` chạy tuần tự **và** chạy trong tiến trình riêng. Kiểm tiến trình trước
    /// khi ép (review độc lập #52): runner chạy chung một tiến trình với test khác (song song) thì không ép gì, chỉ báo
    /// lỗi, để tiếng Anh không lọt sang test đang so chữ tiếng Việt. Gốc ảnh chụp gắn `.interfaceLocale()` nên
    /// `Text(_:bundle:)` và số trong view cũng theo `language`. Trả lại ngôn ngữ cũ khi xong.
    static func inLanguage(
        _ language: Locale,
        sourceLocation: SourceLocation = #_sourceLocation,
        _ body: @MainActor () async throws -> Void
    ) async rethrows {
        prepareProcess()
        if let problem = await environmentProblem() {
            Issue.record(Comment(rawValue: problem), sourceLocation: sourceLocation)
            return
        }
        let previous = InterfaceStrings.processLanguageOverride
        InterfaceStrings.processLanguageOverride = language
        defer { InterfaceStrings.processLanguageOverride = previous }
        try await body()
    }

    // MARK: - Môi trường của tiến trình

    private static var isPrepared = false

    /// Ghim cài đặt ảnh hưởng tới cách vẽ, một lần cho tiến trình, trước khi AppKit đọc chúng. Chỉ trong bộ nhớ.
    static func prepareProcess() {
        guard !isPrepared else { return }
        isPrepared = true
        var arguments = UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain)
        arguments.merge([
            "AppleLanguages": ["vi"],
            "AppleLocale": "vi_VN",
            // Xanh mặc định của macOS (4) cho màu nhấn và màu tô chọn chữ.
            "AppleAccentColor": 4,
            "AppleHighlightColor": "0.698039 0.843137 1.000000 Blue",
            // Thanh cuộn nổi (không phụ thuộc chuột có cắm hay không).
            "AppleShowScrollBars": "WhenScrolling",
            // Cỡ biểu tượng sidebar: vừa.
            "NSTableViewDefaultSizeMode": 2,
        ]) { _, pinned in pinned }
        UserDefaults.standard.setVolatileDomain(arguments, forName: UserDefaults.argumentDomain)
        NSTimeZone.default = TimeZone(identifier: "Asia/Ho_Chi_Minh")!
        // App "đang dùng" để control vẽ trạng thái hoạt động (cửa sổ không hiện lên màn hình, app không thật sự
        // được kích hoạt). Phải tạo trước mọi chỗ khác gọi `NSApplication.shared`.
        let app = SnapshotApplication.shared
        // Không biểu tượng Dock, không chiếm tiêu điểm của người đang dùng máy.
        app.setActivationPolicy(.prohibited)
    }

    /// Lý do không chụp được ảnh so sánh được trên máy này; nil nếu được.
    static func environmentProblem() async -> String? {
        // Cài đặt ghim chỉ có tác dụng nếu chưa ai đọc chúng trước (ví dụ test khác trong cùng tiến trình đã tạo
        // `NSApplication` hay đọc `Locale.current`): khi đó ảnh sẽ lệch, báo rõ thay vì so ảnh sai.
        guard NSApp is SnapshotApplication, Locale.current.identifier == "vi_VN",
              NSScroller.preferredScrollerStyle == .overlay
        else {
            return "Cài đặt ghim của snapshot test không có tác dụng (NSApp \(type(of: NSApp as Any)), "
                + "Locale \(Locale.current.identifier), thanh cuộn \(NSScroller.preferredScrollerStyle.rawValue)): "
                + "target ExamFeaturesSnapshotTests phải chạy trong tiến trình riêng (docs/process/snapshot-tests.md)."
        }
        if let problem = await scaleProblem() { return problem }
        return settingsProblem(DisplaySettings.current)
    }

    /// Cài đặt hiển thị đọc được bằng API công khai, ảnh hưởng tới ảnh chụp.
    struct DisplaySettings: Equatable, Sendable {
        var increaseContrast = false
        var reduceTransparency = false
        var differentiateWithoutColor = false
        var invertColors = false
        /// Cỡ chữ body (Accessibility › Display › Text size thay đổi nó); mặc định 13 pt.
        var bodyPointSize = SnapshotHost.referenceBodyPointSize
        var systemFontSize = SnapshotHost.referenceBodyPointSize

        @MainActor static var current: DisplaySettings {
            let workspace = NSWorkspace.shared
            return DisplaySettings(
                increaseContrast: workspace.accessibilityDisplayShouldIncreaseContrast,
                reduceTransparency: workspace.accessibilityDisplayShouldReduceTransparency,
                differentiateWithoutColor: workspace.accessibilityDisplayShouldDifferentiateWithoutColor,
                invertColors: workspace.accessibilityDisplayShouldInvertColors,
                bodyPointSize: NSFont.preferredFont(forTextStyle: .body).pointSize,
                systemFontSize: NSFont.systemFontSize
            )
        }
    }

    /// Thông báo khi `settings` khác mặc định (ảnh tham chiếu chụp với cài đặt mặc định); nil nếu giống.
    static func settingsProblem(_ settings: DisplaySettings) -> String? {
        var problems: [String] = []
        if settings.increaseContrast { problems.append("Increase Contrast") }
        if settings.reduceTransparency { problems.append("Reduce Transparency") }
        if settings.differentiateWithoutColor { problems.append("Differentiate Without Color") }
        if settings.invertColors { problems.append("Invert colors") }
        if settings.bodyPointSize != referenceBodyPointSize || settings.systemFontSize != referenceBodyPointSize {
            problems.append("cỡ chữ hệ thống \(settings.bodyPointSize) pt (mặc định \(referenceBodyPointSize) pt)")
        }
        guard !problems.isEmpty else { return nil }
        return "Snapshot test cần đưa về mặc định: \(problems.joined(separator: ", ")) (System Settings › "
            + "Accessibility › Display; ảnh tham chiếu chụp với cài đặt mặc định; docs/process/snapshot-tests.md)."
    }

    /// Cỡ chữ body của macOS ở cài đặt mặc định.
    nonisolated static let referenceBodyPointSize: CGFloat = 13

    /// Hệ số vẽ của mọi ảnh tham chiếu.
    static let referenceScale: CGFloat = 2

    /// Lý do không vẽ được ở `referenceScale`; nil nếu được. Dựng một cửa sổ chụp nhỏ (không lên màn hình) và đọc
    /// hệ số của cửa sổ và của lớp chữ SwiftUI thật sự được vẽ.
    static func scaleProblem() async -> String? {
        let window = SnapshotWindow(
            contentRect: NSRect(x: 0, y: 0, width: 120, height: 40),
            styleMask: [.titled], backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
        defer {
            window.contentView = nil
            window.close()
        }
        let host = NSHostingView(rootView: Text(verbatim: "2x").padding())
        window.contentView = host
        await pump(rounds: 4)
        host.layoutSubtreeIfNeeded()
        host.displayIfNeeded()
        func contentScales(_ layer: CALayer) -> [CGFloat] {
            (layer.contents != nil ? [layer.contentsScale] : []) + (layer.sublayers ?? []).flatMap(contentScales)
        }
        let scales = host.layer.map(contentScales) ?? []
        guard window.backingScaleFactor == referenceScale, !scales.isEmpty,
              scales.allSatisfy({ $0 == referenceScale })
        else {
            return "Không vẽ được ở \(referenceScale)x như ảnh tham chiếu: cửa sổ \(window.backingScaleFactor)x, lớp "
                + "\(scales.isEmpty ? "chưa vẽ" : scales.map { "\($0)x" }.joined(separator: "/")), màn hình chính "
                + "\(NSScreen.main?.backingScaleFactor ?? 0)x (docs/process/snapshot-tests.md)."
        }
        return nil
    }

    /// Thêm vào thông báo khi ảnh lệch: những gì có thể làm lệch ảnh mà không phải lỗi giao diện.
    static var mismatchHint: String {
        let os = ProcessInfo.processInfo.operatingSystemVersionString
        return """
            Nếu giao diện không đổi: kiểm macOS/Xcode (đang chạy \(os)) có khác máy ghi ảnh tham chiếu, và các cài đặt \
            không đọc được (Show toolbar button shapes, kiểu biểu tượng/widget, Liquid Glass Clear/Tinted) đang ở mặc \
            định. Cố ý đổi giao diện thì ghi lại: EXAMSUITE_SNAPSHOT_RECORD=failed swift test --package-path \
            Packages/ExamFeatures --filter ExamFeaturesSnapshotTests (docs/process/snapshot-tests.md).
            """
    }

    // MARK: - Chụp

    /// Chụp `content` trong cửa sổ có nội dung `size`, giao diện `appearance`, kèm thanh tiêu đề/thanh công cụ.
    ///
    /// - Parameter settle: chạy sau khi cửa sổ dựng xong, trước khi chụp (chờ kiểm đề chạy nền, chọn dòng…).
    /// - Parameter inspect: nhận khung cửa sổ (`contentView.superview`, gốc của ảnh) ngay trước khi chụp, để test đọc khung
    ///   view AppKit trong đúng lần chụp đó (ô chữ của hộp xác nhận Import đề).
    static func image<Content: View>(
        of content: Content,
        appearance: SnapshotAppearance,
        size: CGSize = minimumWindow,
        scroll: SnapshotScroll = .top,
        settle: @MainActor () async -> Void = {},
        inspect: (NSView) -> Void = { _ in },
        sourceLocation: SourceLocation = #_sourceLocation
    ) async -> NSImage {
        prepareProcess()
        let window = SnapshotWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.animationBehavior = .none
        window.appearance = NSAppearance(named: appearance.appearanceName)
        let host = NSHostingView(rootView: root(content))
        host.sceneBridgingOptions = [.toolbars, .title]
        window.contentView = host
        await pump()
        await settle()
        // Thanh công cụ được gắn sau lần dựng đầu và làm đổi cỡ vùng nội dung: đặt lại đúng `size`.
        window.setContentSize(size)
        await pump()
        if host.frame.size != size {
            Issue.record(
                "Vùng nội dung \(host.frame.size) khác \(size): màn có kích thước tối thiểu lớn hơn?",
                sourceLocation: sourceLocation
            )
        }
        if scroll == .bottom {
            scrollMainContentToEnd(in: host, sourceLocation: sourceLocation)
            await pump()
        }
        if let frameView = window.contentView?.superview {
            frameView.layoutSubtreeIfNeeded()
            inspect(frameView)
        }
        let image = render(window)
        window.contentView = nil
        window.close()
        await pump(rounds: 2)
        return image
    }

    /// Gốc của mọi ảnh chụp.
    private static func root<Content: View>(_ content: Content) -> some View {
        content
            // Như gốc mọi scene của app: số, phần trăm, ngày giờ theo ngôn ngữ giao diện (tiến trình test khoá vi).
            .interfaceLocale()
            // Như cửa sổ đang dùng: nút nổi bật có màu nhấn, control không mờ.
            .environment(\.controlActiveState, .key)
            .transaction { transaction in
                transaction.disablesAnimations = true
                transaction.animation = nil
            }
    }

    /// Cỡ vùng nội dung của cửa sổ cỡ theo nội dung (`.windowResizability(.contentSize)`, như cửa sổ Import đề): cửa sổ
    /// mở ở cỡ nhỏ nhất của nội dung (lỗi beta G6.2). Đo trong cửa sổ chụp, cùng gốc với `image(of:)`: thu cửa sổ về
    /// 1×1 rồi đọc cỡ AppKit giữ lại theo cỡ nhỏ nhất của nội dung (đo ngoài cửa sổ lệch vài điểm).
    static func minimumContentSize<Content: View>(of content: Content) async -> CGSize {
        prepareProcess()
        let window = SnapshotWindow(
            contentRect: NSRect(origin: .zero, size: minimumWindow),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.animationBehavior = .none
        let host = NSHostingView(rootView: root(content))
        window.contentView = host
        await pump()
        window.setContentSize(CGSize(width: 1, height: 1))
        await pump()
        let size = host.frame.size
        window.contentView = nil
        window.close()
        await pump(rounds: 2)
        return size
    }

    /// Cuộn vùng cuộn lớn nhất (nội dung chính: câu hỏi, Kết quả, chi tiết Xem lại) tới cuối.
    private static func scrollMainContentToEnd(in root: NSView, sourceLocation: SourceLocation) {
        func scrollViews(_ view: NSView) -> [NSScrollView] {
            (view as? NSScrollView).map { [$0] } ?? view.subviews.flatMap(scrollViews)
        }
        let candidates = scrollViews(root).filter { scrollView in
            guard let document = scrollView.documentView else { return false }
            return document.frame.height > scrollView.contentView.bounds.height + 1
        }
        guard let main = candidates.max(by: { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }),
              let document = main.documentView
        else {
            Issue.record("Không có vùng cuộn nào dài hơn cửa sổ để cuộn tới cuối", sourceLocation: sourceLocation)
            return
        }
        let clip = main.contentView
        let maxY = document.frame.height - clip.bounds.height
        clip.scroll(to: NSPoint(x: clip.bounds.origin.x, y: document.isFlipped ? maxY : 0))
        main.reflectScrolledClipView(clip)
    }

    /// Cho SwiftUI/AppKit chạy hết việc đang chờ (dựng view, `.task`, ảnh giải mã, bố cục).
    static func pump(rounds: Int = 12) async {
        for _ in 0 ..< rounds {
            spinRunLoop()
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    private static func spinRunLoop() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))
    }

    /// Vẽ cả khung cửa sổ (thanh tiêu đề, thanh công cụ, nội dung) vào ảnh 1x, các lớp kính ẩn tạm.
    private static func render(_ window: NSWindow) -> NSImage {
        guard let frameView = window.contentView?.superview else { return NSImage() }
        frameView.layoutSubtreeIfNeeded()
        frameView.displayIfNeeded()
        let bounds = frameView.bounds
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(bounds.width),
            pixelsHigh: Int(bounds.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        rep.size = bounds.size
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let restore = frameView.layer.map(GlassFlattener.flatten) ?? {}
        // Vẽ cây lớp (không qua `cacheDisplay`: view kính của AppKit tự vẽ khối trắng khi được yêu cầu vẽ trực tiếp).
        if let layer = frameView.layer, let context = NSGraphicsContext(bitmapImageRep: rep) {
            layer.render(in: context.cgContext)
        }
        restore()
        CATransaction.commit()
        let image = NSImage(size: bounds.size)
        image.addRepresentation(rep)
        return image
    }

    // MARK: - So ảnh

    /// Chụp `content` ở giao diện sáng và tối (hoặc chỉ `appearances`), so với
    /// `<tên test>.<light|dark>-960x640[-end].png` (`-end`: đã cuộn nội dung chính tới cuối).
    static func assertLightAndDark<Content: View>(
        _ content: @MainActor () -> Content,
        appearances: [SnapshotAppearance] = SnapshotAppearance.allCases,
        size: CGSize = minimumWindow,
        scroll: SnapshotScroll = .top,
        settle: @MainActor () async -> Void = {},
        fileID: StaticString = #fileID,
        filePath: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) async {
        // Mọi lỗi (môi trường, hệ số vẽ, kích thước, ảnh lệch) chỉ vào dòng của test gọi, không vào helper này.
        let sourceLocation = SourceLocation(
            fileID: String(describing: fileID), filePath: String(describing: filePath),
            line: Int(line), column: Int(column)
        )
        prepareProcess()
        if let problem = await environmentProblem() {
            Issue.record(Comment(rawValue: problem), sourceLocation: sourceLocation)
            return
        }
        for appearance in appearances {
            let image = await image(
                of: content(), appearance: appearance, size: size, scroll: scroll, settle: settle,
                sourceLocation: sourceLocation
            )
            let name = "\(appearance.rawValue)-\(Int(size.width))x\(Int(size.height))" + (scroll == .bottom ? "-end" : "")
            // `verifySnapshot` (không phải `assertSnapshot`) để thêm gợi ý vào thông báo; ảnh đính kèm vẫn do thư viện ghi.
            let failure = verifySnapshot(
                of: image,
                as: .image(precision: precision, perceptualPrecision: perceptualPrecision),
                named: name,
                record: recordMode,
                fileID: fileID,
                file: filePath,
                testName: testName,
                line: line,
                column: column
            )
            if let failure {
                let message = recordMode == .never ? failure + "\n\n" + mismatchHint : failure
                Issue.record(Comment(rawValue: message), sourceLocation: sourceLocation)
            }
        }
    }
}

// MARK: - Trang PDF

extension SnapshotHost {
    /// Cỡ trang A4 dọc của PDF (export-print.md, Trình bày chung).
    static let a4Page = CGSize(width: 595, height: 842)

    /// Trang `index` của PDF vẽ ra ảnh 1x (điểm ảnh = point) trên nền trắng, bằng Core Graphics (`drawPDFPage`): không
    /// qua cửa sổ, không phụ thuộc giao diện sáng/tối hay màn hình. PDF luôn sáng (export-print.md).
    static func pageImage(of pdf: Data, page index: Int = 0, sourceLocation: SourceLocation = #_sourceLocation) -> NSImage? {
        guard let document = CGPDFDocument(CGDataProvider(data: pdf as CFData)!),
              let page = document.page(at: index + 1)
        else {
            Issue.record("PDF không có trang \(index + 1)", sourceLocation: sourceLocation)
            return nil
        }
        let box = page.getBoxRect(.mediaBox)
        let width = Int(box.width.rounded()), height = Int(box.height.rounded())
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        )!
        rep.size = box.size
        guard let context = NSGraphicsContext(bitmapImageRep: rep)?.cgContext else { return nil }
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.translateBy(x: -box.minX, y: -box.minY)
        context.drawPDFPage(page)
        let image = NSImage(size: box.size)
        image.addRepresentation(rep)
        return image
    }

    /// So trang `index` (mặc định trang 1) của `pdf` với `<tên test>.light-a4-page<N>.png` (cùng độ chính xác như ảnh
    /// cửa sổ; export-print.md, Kiểm chứng: "Snapshot trang đầu (sáng, A4)"). Trang phải đúng khổ A4.
    static func assertPDFPage(
        _ pdf: Data,
        page index: Int = 0,
        fileID: StaticString = #fileID,
        filePath: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) async {
        let sourceLocation = SourceLocation(
            fileID: String(describing: fileID), filePath: String(describing: filePath),
            line: Int(line), column: Int(column)
        )
        prepareProcess()
        if let problem = await environmentProblem() {
            Issue.record(Comment(rawValue: problem), sourceLocation: sourceLocation)
            return
        }
        guard let image = pageImage(of: pdf, page: index, sourceLocation: sourceLocation) else { return }
        if image.size != a4Page {
            Issue.record("Trang \(index + 1) cỡ \(image.size), không phải A4 \(a4Page)", sourceLocation: sourceLocation)
        }
        let failure = verifySnapshot(
            of: image,
            as: .image(precision: precision, perceptualPrecision: perceptualPrecision),
            named: "light-a4-page\(index + 1)",
            record: recordMode,
            fileID: fileID,
            file: filePath,
            testName: testName,
            line: line,
            column: column
        )
        if let failure {
            let message = recordMode == .never ? failure + "\n\n" + mismatchHint : failure
            Issue.record(Comment(rawValue: message), sourceLocation: sourceLocation)
        }
    }
}

/// App của tiến trình test: luôn coi là đang hoạt động (không gọi `activate`, không lấy tiêu điểm của người dùng).
final class SnapshotApplication: NSApplication {
    override var isActive: Bool { true }
}

/// Cửa sổ chụp: luôn coi là cửa sổ chính/đang dùng để control vẽ ở trạng thái hoạt động như khi người dùng làm việc
/// (cửa sổ không hiện lên màn hình nên AppKit mặc định vẽ trạng thái không hoạt động), và vẽ ở hệ số cố định thay
/// vì hệ số của màn hình chính (`contentsScale` của các lớp đi theo `backingScaleFactor` của cửa sổ).
final class SnapshotWindow: NSWindow {
    /// Hệ số vẽ; chỉ test kiểm `scaleProblem` đổi tạm (mô phỏng màn 1x).
    nonisolated(unsafe) static var forcedScale: CGFloat = 2

    override var backingScaleFactor: CGFloat { Self.forcedScale }
    override var isKeyWindow: Bool { true }
    override var isMainWindow: Bool { true }
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    // Selector riêng của AppKit quyết định cách vẽ thanh tiêu đề (nút đóng/thu nhỏ có màu, tiêu đề đậm) khi cửa sổ
    // đang dùng; không có thì chỉ khác thanh tiêu đề.
    @objc func _hasActiveAppearance() -> Bool { true }
    @objc func _hasActiveAppearanceIgnoringKeyFocus() -> Bool { true }
    @objc func _hasKeyAppearance() -> Bool { true }
}
