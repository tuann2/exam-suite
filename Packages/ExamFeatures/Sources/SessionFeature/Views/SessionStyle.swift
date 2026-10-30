import AppKit
import ExamKit
import InterfaceCore
import LibraryFeature
import SessionModel
import SwiftUI

/// Màu và kích thước của cửa sổ làm bài. Màu dựng từ `LibraryPalette` (độ tương phản có test, phương án 8 của
/// docs/product/library.md): teal cho Luyện tập/Thi như Thư viện.
enum SessionStyle {
    /// Nền nút có chữ trắng (nút mặc định, ô đã làm của bảng câu hỏi): `#017777` ở cả hai giao diện.
    static let accentFill = LibraryPalette.accentFill.color(name: "SessionAccentFill")
    /// Chữ, biểu tượng, viền teal trên nền; cũng là `tint` của cửa sổ làm bài.
    static let accentForeground = LibraryPalette.accentForeground.color(name: "SessionAccentForeground")
    static let positive = LibraryPalette.positive.color(name: "SessionPositive")
    static let warning = LibraryPalette.warning.color(name: "SessionWarning")
    static let critical = LibraryPalette.critical.color(name: "SessionCritical")

    /// Nền nhạt teal của hàng lựa chọn đã chọn (độ tương phản của chữ đặt lên có test).
    static let selectedOptionBackground = AdaptiveBackground.tint(
        LibraryPalette.accentForeground, opacity: LibraryPalette.tintedBackgroundOpacity
    )
    /// Nền trung tính của khung giải thích (cửa sổ làm bài, Xem lại bài, xem trước của Soạn đề).
    static let explanationBackground = AdaptiveBackground.neutral(opacity: LibraryPalette.explanationFillOpacity)

    /// Cửa sổ làm bài tối thiểu 960×640 (docs/product/exam-taking.md).
    static let minWindowSize = CGSize(width: 960, height: 640)
    static let cornerRadius: CGFloat = 8
    /// Bề rộng tối đa của cột nội dung câu hỏi (dễ đọc khi cửa sổ toàn màn hình).
    static let readableWidth: CGFloat = 860
    /// Độ rộng tối thiểu của chữ nhiều dòng nằm ngoài vùng cuộn (dải thông báo, lý do ở thanh nút Kết quả): khi macOS 26
    /// khôi phục cửa sổ xếp lát, SwiftUI đo cỡ nhỏ nhất của nội dung ở độ rộng ~0; chữ có `fixedSize` dọc thì cao hàng
    /// nghìn điểm và đẩy nội dung ra ngoài cửa sổ (như `LibraryStyle.bannerTextMinWidth`; plan giai đoạn 5, Decisions
    /// 2026-10-17 Thư viện trống). Nhỏ hơn mọi chỗ đặt chữ ở cửa sổ tối thiểu 960×640, nên không đổi giao diện.
    static let wrappingTextMinWidth: CGFloat = 320

    static func color(for level: ClockLevel) -> Color {
        switch level {
        case .normal: .primary
        case .warning: warning
        case .urgent: critical
        }
    }

    static func color(for outcome: QuestionOutcome) -> Color {
        switch outcome {
        case .correct: positive
        case .incorrect: critical
        case .unanswered: .secondary
        }
    }
}

/// Markdown cơ bản (đậm, nghiêng, mã, liên kết) của nội dung câu, lựa chọn, hướng dẫn, giải thích; giữ xuống
/// dòng. Chuỗi không phân tích được thì hiện nguyên văn.
struct MarkdownText: View {
    let source: String

    init(_ source: String) {
        self.source = source
    }

    var body: some View {
        Text(Self.attributed(source))
    }

    static func attributed(_ source: String) -> AttributedString {
        PlainMarkdown.attributed(source)
    }

    /// Chữ trơn (bỏ ký hiệu Markdown) cho nhãn VoiceOver (`PlainMarkdown`).
    static func plain(_ source: String) -> String {
        PlainMarkdown.text(source)
    }
}

/// Dải thông báo trên đầu nội dung: biểu tượng + chữ, không chặn. Nền nhạt pha màu `tone` (độ tương phản của chữ có test;
/// Reduce Transparency: nền đặc, `AdaptiveBackground`). Trong vùng nội dung câu (dòng báo của Xem lại bài) màu và nền theo
/// nền đọc (`readingStyle`).
struct SessionBannerView: View {
    let systemImage: String
    /// Màu của dải (`LibraryPalette.warning`, `.critical`): biểu tượng, viền, nền nhạt.
    let tone: LibraryPalette.Pair
    let message: String
    /// Độ rộng tối thiểu của chữ (`SessionStyle.wrappingTextMinWidth`). Chỉ test đổi (`TiledWindowLayoutTests`: `nil` làm
    /// đối chứng âm, đo đúng view thật không có độ rộng tối thiểu).
    var textMinWidth: CGFloat? = SessionStyle.wrappingTextMinWidth
    /// Dải nằm trong vùng nội dung câu (dòng báo của Xem lại bài): chữ đổi cỡ theo Phóng to/Thu nhỏ. Dải cảnh báo giờ của
    /// cửa sổ làm bài và dải của Kết quả thì không.
    var scalesWithContent = false
    var onClose: (() -> Void)?

    @Environment(\.readingStyle) private var reading

    var body: some View {
        let tint = reading.color(replacing: tone, name: "SessionBannerTone")
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            messageText
                .fixedSize(horizontal: false, vertical: true)
                .frame(minWidth: textMinWidth, alignment: .leading)
            Spacer(minLength: 8)
            if let onClose {
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .help(Text("Đóng thông báo", bundle: .module))
                .accessibilityLabel(Text("Đóng thông báo", bundle: .module))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .readingFill(reading.bannerBackground(tone: tone), in: RoundedRectangle(cornerRadius: SessionStyle.cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: SessionStyle.cornerRadius)
                .strokeBorder(tint.opacity(LibraryPalette.sessionBannerBorderOpacity))
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var messageText: some View {
        if scalesWithContent {
            Text(message).contentBodyFont(weight: .semibold)
        } else {
            Text(message).fontWeight(.semibold)
        }
    }
}

/// Ảnh của câu: vừa khung, bấm để phóng to trong sheet (Esc hoặc Return đóng). Giải mã khi cần, chỉ ảnh đang
/// hiện. Sheet đang mở thì cửa sổ làm bài biết (`SessionModal.imageZoom`) để phím không tác dụng lên bài.
struct QuestionImageView: View {
    let data: Data

    @Environment(SessionWindowModel.self) private var window: SessionWindowModel?
    @Environment(\.readingStyle) private var reading
    @State private var image: NSImage?
    @State private var isZoomed = false

    var body: some View {
        Group {
            if let image {
                Button {
                    // Đang có sheet/hộp thoại hay một lần Xuất PDF/In đang chạy trên cửa sổ làm bài: không mở ảnh phóng to
                    // (sheet thứ hai không trình bày được). Xem trước của Soạn đề không có cửa sổ làm bài.
                    if window?.canPresentSheet ?? true { isZoomed = true }
                } label: {
                    // Bo góc và viền bao đúng ảnh (đặt trước khung): ảnh hẹp hơn khung (ảnh cao, giới hạn cao 320) thì phần
                    // trống bên phải không có viền (plan giai đoạn 5, bước 3 mục (d)).
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay {
                            RoundedRectangle(cornerRadius: 6).strokeBorder(reading.border)
                        }
                        .frame(maxWidth: min(image.size.width, SessionStyle.readableWidth), maxHeight: 320, alignment: .leading)
                }
                .buttonStyle(.plain)
                .help(Text("Bấm để phóng to", bundle: .module))
                .accessibilityLabel(Text("Ảnh của câu hỏi", bundle: .module))
                .accessibilityHint(Text("Bấm để phóng to", bundle: .module))
                .accessibilityIdentifier("question.image")
                .sheet(isPresented: $isZoomed) {
                    ZoomedImageSheet(image: image)
                        // Sheet vẽ như cửa sổ, không theo nền đọc của vùng nội dung câu.
                        .leavingReadingSurface()
                        .presentationAllowsAppTermination()
                }
            } else {
                Label(localized("Không hiện được ảnh của câu này"), systemImage: "photo.badge.exclamationmark")
                    .foregroundStyle(reading.secondaryText)
                    .opacity(decoded ? 1 : 0)
            }
        }
        .task(id: data) {
            image = NSImage(data: data)
            decoded = true
        }
        .onChange(of: isZoomed) { _, zoomed in
            window?.setModal(.imageZoom, presented: zoomed)
        }
        .onDisappear {
            if isZoomed { window?.setModal(.imageZoom, presented: false) }
        }
    }

    @State private var decoded = false
}

private struct ZoomedImageSheet: View {
    let image: NSImage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 12) {
            ScrollView([.horizontal, .vertical]) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: max(image.size.width, 600), maxHeight: max(image.size.height, 400))
                    .accessibilityLabel(Text("Ảnh của câu hỏi, phóng to", bundle: .module))
            }
            HStack {
                Spacer()
                // Esc và Return đều đóng; ←/→ không làm gì (menu Bài thi tắt khi sheet mở).
                Button(localized("Đóng")) { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("question.image.close")
                Button(localized("Đóng")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .frame(width: 0, height: 0)
                    .opacity(0)
                    .accessibilityHidden(true)
            }
        }
        .padding(16)
        .frame(minWidth: 640, idealWidth: 900, minHeight: 480, idealHeight: 700)
        .onExitCommand { dismiss() }
    }
}
