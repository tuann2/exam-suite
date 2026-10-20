import AppKit
import ExamKit
import LibraryFeature
import SwiftUI

// Nền đọc của vùng nội dung câu (`ReadingBackground`, docs/product/accessibility-localization.md, mục Dark Mode và tương
// phản): cùng phạm vi với cỡ chữ nội dung (phương án 5): nội dung câu của cửa sổ làm bài, chi tiết câu của Xem lại bài, xem
// trước của Soạn đề. Bảng câu hỏi, thanh bên, thanh công cụ, thanh dưới, Rà soát, lớp phủ Tạm dừng, dải cảnh báo giờ giữ
// giao diện macOS; PDF và bản in luôn sáng (không qua đây).

extension ReadingBackground {
    /// Tên của nền (menu Xem › Nền đọc, ô chọn của Trước khi thi).
    public var title: String {
        switch self {
        case .system: localized("Theo hệ thống")
        case .white: localized("Trắng")
        case .sepia: localized("Giấy ngà")
        case .softGray: localized("Xám dịu")
        case .dark: localized("Tối")
        }
    }
}

extension LibraryPalette.RGB {
    /// Màu SwiftUI cố định (không đổi theo sáng/tối) của giá trị số.
    var fixedColor: Color { Color(nsColor: nsColor) }
}

// MARK: - Màu của vùng nội dung câu

/// Màu SwiftUI của vùng nội dung câu theo nền đọc. **Theo hệ thống** (`palette == nil`): đúng các màu trước khi có nền đọc
/// (màu ngữ nghĩa `.primary`, `.secondary`, `.separator`, `.background`; `SessionStyle`; nền có độ trong theo Reduce
/// Transparency), nên giao diện không đổi. Nền cố định: màu đặc của bộ màu (`ReadingPalette`), không màu ngữ nghĩa nào của
/// hệ thống (chữ `.secondary` của giao diện tối sẽ nằm trên nền Giấy ngà).
struct ReadingStyle: Equatable {
    /// Bộ màu cố định; `nil`: theo hệ thống.
    let palette: ReadingPalette?

    static let system = ReadingStyle(palette: nil)

    init(palette: ReadingPalette?) {
        self.palette = palette
    }

    init(_ background: ReadingBackground) {
        self.init(palette: background.fixedPalette)
    }

    var text: AnyShapeStyle { palette.map { AnyShapeStyle($0.text.fixedColor) } ?? AnyShapeStyle(.primary) }
    var secondaryText: AnyShapeStyle { palette.map { AnyShapeStyle($0.secondaryText.fixedColor) } ?? AnyShapeStyle(.secondary) }
    var border: AnyShapeStyle { palette.map { AnyShapeStyle($0.border.fixedColor) } ?? AnyShapeStyle(.separator) }
    /// Nền của lựa chọn chưa chọn (và hàng của Xem lại bài, xem trước).
    var optionBackground: AnyShapeStyle { palette.map { AnyShapeStyle($0.background.fixedColor) } ?? AnyShapeStyle(.background) }
    var accent: Color { palette?.accent.fixedColor ?? SessionStyle.accentForeground }
    var positive: Color { palette?.positive.fixedColor ?? SessionStyle.positive }
    var critical: Color { palette?.critical.fixedColor ?? SessionStyle.critical }
    var warning: Color { palette?.warning.fixedColor ?? SessionStyle.warning }

    /// Màu của kết quả một câu (Xem lại bài): Đúng, Sai, Chưa làm (chữ phụ).
    func color(for outcome: QuestionOutcome) -> AnyShapeStyle {
        guard let palette else { return AnyShapeStyle(SessionStyle.color(for: outcome)) }
        switch outcome {
        case .correct: return AnyShapeStyle(palette.positive.fixedColor)
        case .incorrect: return AnyShapeStyle(palette.critical.fixedColor)
        case .unanswered: return AnyShapeStyle(palette.secondaryText.fixedColor)
        }
    }

    /// Màu của nền đọc thay cho màu `pair` của bảng màu (dải báo, viền của dải); theo hệ thống: chính `pair`.
    func color(replacing pair: LibraryPalette.Pair, name: String) -> Color {
        palette?.color(replacing: pair)?.fixedColor ?? pair.color(name: name)
    }

    /// Nền của lựa chọn đang chọn.
    var selectedOptionBackground: ReadingFill {
        palette.map { .solid($0.selectedOptionBackground) } ?? .adaptive(SessionStyle.selectedOptionBackground)
    }

    /// Nền của khung giải thích.
    var explanationBackground: ReadingFill {
        palette.map { .solid($0.explanationBackground) } ?? .adaptive(SessionStyle.explanationBackground)
    }

    /// Nền của dòng báo có màu `tone` (Xem lại bài).
    func bannerBackground(tone: LibraryPalette.Pair) -> ReadingFill {
        guard let palette, let color = palette.color(replacing: tone) else {
            return .adaptive(.tint(tone, opacity: LibraryPalette.tintedBackgroundOpacity))
        }
        return .solid(palette.tinted(color))
    }

    /// Nền của cả vùng nội dung (theo hệ thống: không vẽ gì, nền cửa sổ như trước).
    var page: Color { palette?.background.fixedColor ?? .clear }
}

extension EnvironmentValues {
    /// Màu của vùng nội dung câu (`readingSurface`); ngoài vùng đó là theo hệ thống.
    @Entry var readingStyle = ReadingStyle.system
    /// Giao diện sáng/tối và màu nhấn của cửa sổ chứa vùng nội dung câu (trước khi nền đọc ép giao diện của vùng đó), để
    /// sheet mở từ trong vùng (ảnh phóng to) vẽ như cửa sổ.
    @Entry var readingWindowAppearance: ReadingWindowAppearance? = nil
}

/// Giao diện của cửa sổ chứa vùng nội dung câu (`readingSurface`).
struct ReadingWindowAppearance: Equatable {
    let colorScheme: ColorScheme
    let tint: Color
}

/// Nền của một hình trong vùng nội dung câu: nền có độ trong của app (theo hệ thống; theo Reduce Transparency) hoặc màu đặc
/// của nền đọc. Một cấu trúc view cho cả hai (`background(_:in:)`), để đổi nền khi đang làm bài không dựng lại nội dung.
enum ReadingFill: Equatable {
    case adaptive(AdaptiveBackground)
    case solid(LibraryPalette.RGB)

    func style(reduceTransparency: Bool) -> AnyShapeStyle {
        switch self {
        case let .adaptive(background): background.style(reduceTransparency: reduceTransparency)
        case let .solid(rgb): AnyShapeStyle(rgb.fixedColor)
        }
    }
}

private struct ReadingFillModifier<S: Shape>: ViewModifier {
    let fill: ReadingFill
    let shape: S

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content.background(fill.style(reduceTransparency: reduceTransparency), in: shape)
    }
}

extension View {
    /// Nền `fill` trong `shape` (vùng nội dung câu).
    func readingFill<S: Shape>(_ fill: ReadingFill, in shape: S) -> some View {
        modifier(ReadingFillModifier(fill: fill, shape: shape))
    }
}

// MARK: - Vùng nội dung câu

/// Vùng nội dung câu: nền đọc đã nhớ (`@AppStorage`, `defaults` của scene) cho mọi view bên trong. Mọi modifier luôn được
/// gắn (giá trị không đổi gì khi theo hệ thống), để đổi nền khi đang làm bài không dựng lại nội dung (vị trí cuộn giữ nguyên).
private struct ReadingSurface: ViewModifier {
    /// Màu nhấn của cửa sổ (teal của cửa sổ làm bài, burgundy của cửa sổ soạn đề): giữ nguyên khi theo hệ thống.
    let systemTint: Color

    @AppStorage(ReadingBackground.storageKey) private var storedBackground = ReadingBackground.system.rawValue
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let style = ReadingStyle(ReadingBackground(storedValue: storedBackground))
        let palette = style.palette
        content
            .environment(\.readingStyle, style)
            .environment(\.readingWindowAppearance, ReadingWindowAppearance(colorScheme: colorScheme, tint: systemTint))
            // Chữ không đặt màu riêng (nội dung câu, lựa chọn) mang màu chữ của nền; `.tint` cho liên kết trong Markdown.
            .foregroundStyle(style.text)
            .tint(palette?.accent.fixedColor ?? systemTint)
            // Thanh cuộn, chữ đang được chọn và màu ngữ nghĩa còn sót vẽ theo độ sáng của nền (Tối: giao diện tối) dù macOS
            // đang sáng hay tối.
            .environment(\.colorScheme, palette.map { $0.isDark ? .dark : .light } ?? colorScheme)
            // Chỉ trong khung của vùng (không lấn vùng an toàn): trên macOS 26 thanh bên và bảng câu hỏi (inspector) nổi trên
            // nội dung, nền mặc định của `.background` sẽ tràn xuống dưới chúng.
            .background(style.page, ignoresSafeAreaEdges: [])
    }
}

/// Sheet mở từ trong vùng nội dung câu (ảnh phóng to): vẽ như cửa sổ (giao diện, chữ, màu nhấn), không theo nền đọc.
private struct ReadingSurfaceExit: ViewModifier {
    @Environment(\.readingWindowAppearance) private var window
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .environment(\.readingStyle, .system)
            .foregroundStyle(Color.primary)
            .environment(\.colorScheme, window?.colorScheme ?? colorScheme)
            .tint(window?.tint ?? SessionStyle.accentForeground)
    }
}

extension View {
    /// Vùng nội dung câu (cửa sổ làm bài, chi tiết của Xem lại bài, xem trước của Soạn đề): nền đọc đã chọn phủ hết vùng,
    /// chữ và màu theo bộ màu của nền. `systemTint`: màu nhấn của cửa sổ.
    public func readingSurface(systemTint: Color) -> some View {
        modifier(ReadingSurface(systemTint: systemTint))
    }

    /// Nội dung của sheet mở từ vùng nội dung câu: trả lại giao diện của cửa sổ.
    func leavingReadingSurface() -> some View {
        modifier(ReadingSurfaceExit())
    }
}

// MARK: - Menu Xem › Nền đọc

/// **Nền đọc** của cửa sổ đang dùng (`focusedSceneValue`): nền đang chọn và cách đổi. Gửi cùng chỗ với cỡ chữ nội dung
/// (`readingBackgroundScope`): cửa sổ làm bài, Xem lại bài, cửa sổ soạn đề khi xem trước đang mở; cửa sổ khác thì menu tắt.
/// Lựa chọn là của cả app (một khoá trong `defaults` của app), ghi qua `@AppStorage` của scene đang dùng.
public struct ReadingBackgroundControl: Equatable {
    public let background: ReadingBackground
    let set: @MainActor (ReadingBackground) -> Void

    public init(background: ReadingBackground, set: @escaping @MainActor (ReadingBackground) -> Void) {
        self.background = background
        self.set = set
    }

    @MainActor public func choose(_ background: ReadingBackground) { set(background) }

    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.background == rhs.background }
}

struct ReadingBackgroundControlKey: FocusedValueKey {
    typealias Value = ReadingBackgroundControl
}

extension FocusedValues {
    /// Nền đọc của cửa sổ đang dùng (`readingBackgroundScope`).
    public var readingBackground: ReadingBackgroundControl? {
        get { self[ReadingBackgroundControlKey.self] }
        set { self[ReadingBackgroundControlKey.self] = newValue }
    }
}

private struct ReadingBackgroundScope: ViewModifier {
    let isAvailable: Bool

    @AppStorage(ReadingBackground.storageKey) private var storedBackground = ReadingBackground.system.rawValue

    func body(content: Content) -> some View {
        let control = ReadingBackgroundControl(background: ReadingBackground(storedValue: storedBackground)) {
            storedBackground = $0.rawValue
        }
        content.focusedSceneValue(\.readingBackground, isAvailable ? control : nil)
    }
}

extension View {
    /// Màn có vùng nội dung câu: nhận **Xem › Nền đọc** khi cửa sổ đang dùng (cùng chỗ với `contentZoomScope`).
    /// `isAvailable == false` (xem trước của Soạn đề đang ẩn) thì menu tắt.
    public func readingBackgroundScope(isAvailable: Bool = true) -> some View {
        modifier(ReadingBackgroundScope(isAvailable: isAvailable))
    }
}

/// Menu con **Nền đọc** (menu Xem/View, ngay sau Phóng to / Thu nhỏ / Cỡ thật): năm nền, dấu ✓ ở nền đang chọn (VoiceOver
/// đọc trạng thái chọn của mục menu). Tắt khi cửa sổ đang dùng không có vùng nội dung câu; khi đó không mục nào có dấu.
struct ReadingBackgroundMenu: View {
    let control: ReadingBackgroundControl?

    var body: some View {
        Picker(localized("Nền đọc"), selection: Binding<ReadingBackground?>(
            get: { control?.background },
            set: { if let background = $0 { control?.choose(background) } }
        )) {
            ForEach(ReadingBackground.allCases) { background in
                Text(background.title).tag(Optional(background))
            }
        }
        .pickerStyle(.menu)
        .disabled(control == nil)
    }
}

// MARK: - Ô chọn của Trước khi thi

/// Ô chọn **Nền đọc** của Trước khi thi: nhóm nút radio (như "Chọn câu"), mỗi nền có mẫu màu nhỏ (nền, hai vạch màu chữ);
/// VoiceOver đọc tên nền và trạng thái chọn của nút radio. Không dùng menu bật lên: nút menu của SwiftUI chỉ có hành động mở
/// menu, kiểm trợ năng báo thiếu hành động bấm. Ghi cùng khoá `@AppStorage` với menu Xem (sheet nằm trên cửa sổ Thư
/// viện, cùng `defaults` của app).
struct ReadingBackgroundPicker: View {
    @AppStorage(ReadingBackground.storageKey) private var storedBackground = ReadingBackground.system.rawValue

    var body: some View {
        Picker(localized("Nền đọc"), selection: Binding(
            get: { ReadingBackground(storedValue: storedBackground) },
            set: { storedBackground = $0.rawValue }
        )) {
            ForEach(ReadingBackground.allCases) { background in
                Label {
                    Text(background.title)
                } icon: {
                    Image(nsImage: ReadingSwatch.image(for: background))
                        .accessibilityHidden(true)
                }
                .tag(background)
            }
        }
        .pickerStyle(.radioGroup)
        .help(localized("Nền của vùng câu hỏi khi làm bài và xem lại bài. Đổi được khi đang làm bài: Xem › Nền đọc."))
        .accessibilityIdentifier("preExam.readingBackground")
    }
}

/// Mẫu màu của một nền đọc (ảnh nhỏ cố định màu, không theo sáng/tối): nền, viền, hai vạch màu chữ và chữ phụ. **Theo hệ
/// thống**: nửa trái là bộ màu sáng, nửa phải là bộ màu tối của macOS.
@MainActor
enum ReadingSwatch {
    static let size = NSSize(width: 22, height: 14)

    static func image(for background: ReadingBackground) -> NSImage {
        let halves: [ReadingPalette] = background == .system
            ? [ReadingPalette.system(dark: false), ReadingPalette.system(dark: true)]
            : [background.palette(systemDark: false)]
        let image = NSImage(size: size, flipped: false) { rect in
            let shape = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: 3, yRadius: 3)
            NSGraphicsContext.saveGraphicsState()
            shape.addClip()
            let width = rect.width / CGFloat(halves.count)
            for (index, palette) in halves.enumerated() {
                let part = NSRect(x: rect.minX + width * CGFloat(index), y: rect.minY, width: width, height: rect.height)
                palette.background.nsColor.setFill()
                part.fill()
                palette.text.nsColor.setFill()
                NSRect(x: part.minX + 3, y: rect.midY + 1, width: part.width - 6, height: 2).fill()
                palette.secondaryText.nsColor.setFill()
                NSRect(x: part.minX + 3, y: rect.midY - 3, width: (part.width - 6) * 0.7, height: 2).fill()
            }
            NSGraphicsContext.restoreGraphicsState()
            NSColor.separatorColor.setStroke()
            shape.lineWidth = 1
            shape.stroke()
            return true
        }
        image.accessibilityDescription = background.title
        return image
    }
}
