import Accessibility
import InterfaceCore
import LibraryData
import SwiftUI

/// Dải thông báo ở đầu vùng nội dung: không chặn, đóng được. Nền nhạt pha màu `tone` (độ tương phản của chữ có test;
/// Reduce Transparency: nền đặc, `AdaptiveBackground`).
struct BannerView: View {
    let systemImage: String
    /// Màu của dải (`LibraryPalette.warning`, `.critical`, `.accentForeground`): biểu tượng, viền, nền nhạt.
    let tone: LibraryPalette.Pair
    let title: String?
    let message: String
    let closeTitle: String
    /// Độ rộng tối thiểu của chữ (xem chú thích trong `body`). Chỉ test đổi (`TiledWindowLayoutTests`: `nil` làm đối chứng
    /// âm, đo đúng view thật không có độ rộng tối thiểu).
    var textMinWidth: CGFloat? = LibraryStyle.bannerTextMinWidth
    let onClose: () -> Void

    var body: some View {
        let tint = tone.color(name: "LibraryBannerTone")
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                if let title {
                    Text(title)
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                }
                Text(message)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            // Độ rộng tối thiểu cho chữ: chữ không co theo chiều cao (`fixedSize` dọc), nên khi SwiftUI đo cỡ nhỏ nhất
            // của nội dung với độ rộng ~0 (macOS 26 khôi phục cửa sổ đã xếp lát) đoạn chữ dài cao ~2.200 pt, kéo cả
            // khung chia cột cao theo và đẩy thanh bên, danh sách đề ra ngoài cửa sổ (LibraryWindowRestoreUITests).
            .frame(minWidth: textMinWidth, alignment: .leading)
            Spacer(minLength: 8)
            Button(closeTitle, action: onClose)
        }
        .padding(12)
        .adaptiveBackground(.tint(tone, opacity: LibraryPalette.tintedBackgroundOpacity), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8).strokeBorder(tint.opacity(LibraryPalette.libraryBannerBorderOpacity))
        }
        .accessibilityElement(children: .contain)
    }
}

/// Các dải ở đầu vùng nội dung: sự cố kho (kho hỏng đã được thay, kho tạm), lỗi lưu, dải chào mừng.
struct LibraryBanners: View {
    let model: LibraryModel
    @Binding var welcomeBanner: WelcomeBannerState

    var body: some View {
        let store = model.store
        let showsWelcome = welcomeBanner == .visible && model.section != .history
        if store.storeIssue != nil || store.lastStorageError != nil || showsWelcome {
            VStack(spacing: 8) {
                if let issue = store.storeIssue {
                    BannerView(
                        systemImage: "externaldrive.badge.exclamationmark",
                        tone: LibraryPalette.warning,
                        title: localized("Dữ liệu thư viện có sự cố"),
                        message: ErrorMessages.message(for: issue),
                        closeTitle: localized("Đã hiểu"),
                        onClose: { store.dismissStoreIssue() }
                    )
                }
                if let error = store.lastStorageError {
                    BannerView(
                        systemImage: "exclamationmark.triangle.fill",
                        tone: LibraryPalette.critical,
                        title: nil,
                        message: ErrorMessages.message(for: error),
                        closeTitle: localized("Đóng"),
                        onClose: { store.clearStorageError() }
                    )
                }
                if showsWelcome {
                    BannerView(
                        systemImage: "sparkles",
                        tone: LibraryPalette.accentForeground,
                        title: localized("Chào mừng bạn đến với Exam Suite"),
                        message: localized("Thư viện có sẵn đề mẫu để bạn làm quen. Thêm đề của bạn bằng nút Thêm đề (⌘O) hoặc kéo file .exam vào cửa sổ này. Xoá đề mẫu thì lấy lại được bằng Trợ giúp > Khôi phục đề mẫu."),
                        closeTitle: localized("Đóng"),
                        onClose: { welcomeBanner = .dismissed }
                    )
                }
            }
            .padding(.horizontal, LibraryStyle.gridPadding)
            .padding(.top, 12)
        }
    }
}

/// Thông báo không chặn ở chân cửa sổ ("Đã xoá … khỏi thư viện" kèm **Hoàn tác**, kết quả thêm đề…).
/// Tự ẩn sau `LibraryNotice.displayDuration`; VoiceOver đọc ngay khi hiện.
struct NoticeOverlay: View {
    let model: LibraryModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if let notice = model.notice {
                NoticeView(
                    notice: notice,
                    onUndo: { model.undoRemoval($0) },
                    onClose: { model.dismissNotice() }
                )
                .padding(.bottom, 18)
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                .task(id: notice.id) {
                    AccessibilityNotification.Announcement(notice.message).post()
                    try? await Task.sleep(for: LibraryNotice.displayDuration)
                    model.expireNotice(notice.id)
                }
            }
        }
        .animation(reduceMotion ? nil : .snappy, value: model.notice)
    }
}

struct NoticeView: View {
    let notice: LibraryNotice
    let onUndo: (UUID) -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(notice.message)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            if let removalID = notice.undoRemovalID {
                Button(localized("Hoàn tác")) { onUndo(removalID) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .help(Text("Đóng thông báo", bundle: .module))
            .accessibilityLabel(Text("Đóng thông báo", bundle: .module))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: 560)
        .adaptiveBackground(.material, in: Capsule())
        .overlay { Capsule().strokeBorder(.separator) }
        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
        .accessibilityElement(children: .contain)
    }
}

/// Lớp phủ khi kéo file vào cửa sổ.
struct DropTargetOverlay: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(LibraryStyle.accentForeground, style: StrokeStyle(lineWidth: 3, dash: [10, 6]))
            .adaptiveBackground(
                .tint(LibraryPalette.accentForeground, opacity: LibraryPalette.dropTargetOpacity),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay {
                Label(localized("Thả file .exam vào đây để thêm vào thư viện"), systemImage: "square.and.arrow.down")
                    .font(.title3.weight(.semibold))
                    .padding(16)
                    .adaptiveBackground(.material, in: RoundedRectangle(cornerRadius: 10))
            }
            .padding(8)
            .allowsHitTesting(false)
    }
}
