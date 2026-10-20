import AppKit
import LibraryFeature
import SwiftUI

/// Cỡ chữ của **vùng nội dung câu** (docs/product/accessibility-localization.md, mục Cỡ chữ, phương án 5): bốn mức, chỉ
/// cho nội dung câu ở cửa sổ làm bài, Xem lại bài và xem trước của Soạn đề; thanh công cụ, thanh bên, bảng câu hỏi, thanh
/// nút giữ cỡ chữ của macOS.
public enum ContentZoomLevel: Int, CaseIterable, Comparable, Sendable {
    case actual = 100
    case large = 115
    case larger = 130
    case largest = 150

    /// Khoá `@AppStorage` (một mức cho cả app; `defaults` của bản app, UI test: suite trong thư mục tạm, `AppLaunchStorage`).
    public static let storageKey = "content.zoomPercent"

    /// Giá trị lưu không hợp lệ (sửa tay, bản sau đổi mức) thì về cỡ thật.
    public init(storedPercent: Int) {
        self = ContentZoomLevel(rawValue: storedPercent) ?? .actual
    }

    /// Hệ số nhân cỡ chữ.
    public var scale: CGFloat { CGFloat(rawValue) / 100 }

    /// Mức kế tiếp khi **Phóng to**; `nil` ở mức lớn nhất.
    public var zoomedIn: ContentZoomLevel? {
        Self.allCases.first { $0 > self }
    }

    /// Mức kế trước khi **Thu nhỏ**; `nil` ở cỡ thật.
    public var zoomedOut: ContentZoomLevel? {
        Self.allCases.last { $0 < self }
    }

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// **Phóng to** / **Thu nhỏ** / **Cỡ thật** của cửa sổ đang dùng (`focusedSceneValue`): mức hiện tại và cách đổi. Chỉ cửa
/// sổ đang hiện nội dung câu gửi giá trị này (làm bài, Xem lại bài, soạn đề khi xem trước đang mở); cửa sổ khác thì ba mục
/// menu tắt.
public struct ContentZoomControl: Equatable {
    public let level: ContentZoomLevel
    let set: @MainActor (ContentZoomLevel) -> Void

    public init(level: ContentZoomLevel, set: @escaping @MainActor (ContentZoomLevel) -> Void) {
        self.level = level
        self.set = set
    }

    public var canZoomIn: Bool { level.zoomedIn != nil }
    public var canZoomOut: Bool { level.zoomedOut != nil }
    public var canResetZoom: Bool { level != .actual }

    @MainActor public func zoomIn() { if let next = level.zoomedIn { set(next) } }
    @MainActor public func zoomOut() { if let previous = level.zoomedOut { set(previous) } }
    @MainActor public func resetZoom() { set(.actual) }

    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.level == rhs.level }
}

struct ContentZoomControlKey: FocusedValueKey {
    typealias Value = ContentZoomControl
}

extension FocusedValues {
    /// Cỡ chữ nội dung câu của cửa sổ đang dùng (`ContentZoomScope`).
    public var contentZoom: ContentZoomControl? {
        get { self[ContentZoomControlKey.self] }
        set { self[ContentZoomControlKey.self] = newValue }
    }
}

extension EnvironmentValues {
    /// Hệ số cỡ chữ của vùng nội dung câu (1 = cỡ thật). Chỉ chữ dùng `contentFont` đổi theo.
    @Entry public var questionContentScale: CGFloat = 1
}

/// Nơi một màn có nội dung câu đọc mức đã nhớ (`@AppStorage`), đưa hệ số vào môi trường và gửi lệnh menu
/// (`ContentZoomControl`). `isAvailable == false` (xem trước của Soạn đề đang ẩn) thì không gửi lệnh: menu tắt.
private struct ContentZoomScope: ViewModifier {
    let isAvailable: Bool

    @AppStorage(ContentZoomLevel.storageKey) private var storedPercent = ContentZoomLevel.actual.rawValue

    func body(content: Content) -> some View {
        let level = ContentZoomLevel(storedPercent: storedPercent)
        let control = ContentZoomControl(level: level) { storedPercent = $0.rawValue }
        content
            .environment(\.questionContentScale, level.scale)
            .focusedSceneValue(\.contentZoom, isAvailable ? control : nil)
            .background(ZoomInEqualsKey(isEnabled: isAvailable && control.canZoomIn) { control.zoomIn() })
    }
}

/// ⌘= cũng là **Phóng to** (như Safari: trên bàn phím Mỹ, ⌘+ cần giữ ⇧; review độc lập #54 S4). Menu SwiftUI không có mục
/// ẩn thứ hai cho cùng lệnh, nên cửa sổ có vùng nội dung câu bắt phím ⌘= của chính nó (theo dõi sự kiện phím của app, chỉ
/// khi cửa sổ này là cửa sổ đang nhận phím); ⌘+ vẫn đi qua menu Xem.
struct ZoomInEqualsKey: NSViewRepresentable {
    let isEnabled: Bool
    let zoomIn: @MainActor () -> Void

    func makeNSView(context: Context) -> MonitorView {
        let view = MonitorView()
        view.update(isEnabled: isEnabled, zoomIn: zoomIn)
        return view
    }

    func updateNSView(_ view: MonitorView, context: Context) {
        view.update(isEnabled: isEnabled, zoomIn: zoomIn)
    }

    /// Phím ⌘= (chỉ ⌘, không ⇧/⌥/⌃).
    static func isZoomInEquals(characters: String?, modifiers: NSEvent.ModifierFlags) -> Bool {
        characters == "=" && modifiers.intersection(.deviceIndependentFlagsMask) == .command
    }

    final class MonitorView: NSView {
        private var isEnabled = false
        private var zoomIn: @MainActor () -> Void = {}
        nonisolated(unsafe) private var monitor: Any?

        func update(isEnabled: Bool, zoomIn: @escaping @MainActor () -> Void) {
            self.isEnabled = isEnabled
            self.zoomIn = zoomIn
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                let characters = event.charactersIgnoringModifiers
                let modifiers = event.modifierFlags
                let windowNumber = event.windowNumber
                let handled = MainActor.assumeIsolated {
                    self?.handleKey(characters: characters, modifiers: modifiers, windowNumber: windowNumber) ?? false
                }
                return handled ? nil : event
            }
        }

        private func handleKey(characters: String?, modifiers: NSEvent.ModifierFlags, windowNumber: Int) -> Bool {
            guard isEnabled, let window, window.windowNumber == windowNumber, window.isKeyWindow, window.attachedSheet == nil,
                  ZoomInEqualsKey.isZoomInEquals(characters: characters, modifiers: modifiers)
            else { return false }
            zoomIn()
            return true
        }

        deinit {
            if let monitor { NSEvent.removeMonitor(monitor) }
        }
    }
}

extension View {
    /// Màn có vùng nội dung câu: cỡ chữ theo mức đã nhớ, nhận **Phóng to** / **Thu nhỏ** / **Cỡ thật** khi cửa sổ đang dùng.
    public func contentZoomScope(isAvailable: Bool = true) -> some View {
        modifier(ContentZoomScope(isAvailable: isAvailable))
    }

    /// Phông chữ của vùng nội dung câu: như `.font(style)` (kèm `weight`, `design`) ở cỡ thật, nhân `questionContentScale`
    /// khi phóng to.
    func contentFont(_ style: Font.TextStyle, weight: Font.Weight? = nil, design: Font.Design? = nil) -> some View {
        modifier(ContentFontModifier(style: style, weight: weight, design: design))
    }

    /// Chữ thường của vùng nội dung câu (không đặt phông riêng): ở cỡ thật giữ phông mặc định của view như trước (chỉ đổi
    /// `weight` nếu có; đặt `.font(.body)` làm khoảng cách dòng khác phông mặc định), phóng to thì body × hệ số.
    func contentBodyFont(weight: Font.Weight? = nil) -> some View {
        modifier(ContentFontModifier(style: nil, weight: weight, design: nil))
    }
}

/// Phông của vùng nội dung câu theo `questionContentScale`. Cỡ thật dùng đúng phông như trước (kiểu chữ của macOS, hoặc phông
/// mặc định khi `style == nil`; ảnh snapshot không đổi); phóng to dùng phông hệ thống với cỡ của kiểu chữ đó × hệ số (macOS
/// không có Dynamic Type).
struct ContentFontModifier: ViewModifier {
    /// `nil`: phông mặc định (body) của view.
    let style: Font.TextStyle?
    let weight: Font.Weight?
    let design: Font.Design?

    @Environment(\.questionContentScale) private var scale

    func body(content: Content) -> some View {
        if scale != 1 {
            content.font(Self.font(style ?? .body, weight: weight, design: design, scale: scale))
        } else if let style {
            content.font(Self.font(style, weight: weight, design: design, scale: 1))
        } else if let weight {
            content.fontWeight(weight)
        } else {
            content
        }
    }

    static func font(_ style: Font.TextStyle, weight: Font.Weight?, design: Font.Design?, scale: CGFloat) -> Font {
        if scale == 1 {
            var font = textStyleFont(style)
            if let weight { font = font.weight(weight) }
            if design == .monospaced { font = font.monospaced() }
            return font
        }
        return Font.system(
            size: pointSize(style) * scale,
            weight: weight ?? defaultWeight(style),
            design: design ?? .default
        )
    }

    /// Phông kiểu chữ của SwiftUI (`.title3`, `.headline`…), đúng như trước khi có phóng to.
    static func textStyleFont(_ style: Font.TextStyle) -> Font {
        switch style {
        case .largeTitle: .largeTitle
        case .title: .title
        case .title2: .title2
        case .title3: .title3
        case .headline: .headline
        case .subheadline: .subheadline
        case .callout: .callout
        case .footnote: .footnote
        case .caption: .caption
        case .caption2: .caption2
        default: .body
        }
    }

    /// Cỡ của kiểu chữ trên macOS (body 13, title3 15, headline 13 đậm, callout 12…).
    static func pointSize(_ style: Font.TextStyle) -> CGFloat {
        NSFont.preferredFont(forTextStyle: nsStyle(style)).pointSize
    }

    static func defaultWeight(_ style: Font.TextStyle) -> Font.Weight {
        style == .headline ? .bold : .regular
    }

    private static func nsStyle(_ style: Font.TextStyle) -> NSFont.TextStyle {
        switch style {
        case .largeTitle: .largeTitle
        case .title: .title1
        case .title2: .title2
        case .title3: .title3
        case .headline: .headline
        case .subheadline: .subheadline
        case .callout: .callout
        case .footnote: .footnote
        case .caption: .caption1
        case .caption2: .caption2
        default: .body
        }
    }
}

/// Menu **Xem** (View): **Phóng to** (⌘+), **Thu nhỏ** (⌘−), **Cỡ thật** (⌘0) cho vùng nội dung câu (phương án 5), tắt ở
/// giới hạn (Phóng to ở 150%, Thu nhỏ và Cỡ thật ở 100%) và khi cửa sổ đang dùng không có nội dung câu (Thư viện, Kết quả,
/// Import đề, soạn đề khi ẩn xem trước). Ngay sau là menu con **Nền đọc** (`ReadingBackgroundMenu`, plan giai đoạn 6 bước
/// 1), bật ở cùng các cửa sổ đó. Đi kèm scene cửa sổ làm bài, có ở cả hai bản app.
public struct ContentZoomCommands: Commands {
    @FocusedValue(\.contentZoom) private var zoom
    @FocusedValue(\.readingBackground) private var reading

    public init() {}

    public var body: some Commands {
        CommandGroup(after: .toolbar) {
            Divider()
            Button(localized("Phóng to")) { zoom?.zoomIn() }
                .keyboardShortcut("+", modifiers: .command)
                .disabled(zoom?.canZoomIn != true)
            Button(localized("Thu nhỏ")) { zoom?.zoomOut() }
                .keyboardShortcut("-", modifiers: .command)
                .disabled(zoom?.canZoomOut != true)
            Button(localized("Cỡ thật")) { zoom?.resetZoom() }
                .keyboardShortcut("0", modifiers: .command)
                .disabled(zoom?.canResetZoom != true)
            ReadingBackgroundMenu(control: reading)
        }
    }
}
