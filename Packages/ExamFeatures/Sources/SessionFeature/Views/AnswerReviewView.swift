import ExamKit
import InterfaceCore
import LibraryFeature
import SessionModel
import SwiftUI

/// **Xem lại bài** (docs/product/exam-taking.md): `NavigationSplitView` với bộ lọc kèm số lượng và danh sách câu
/// bên trái; câu, ảnh, lựa chọn (Bạn chọn / Đáp án đúng bằng biểu tượng + chữ), giải thích, các dòng báo bên
/// phải. ←/→ đi trong bộ lọc đang chọn. **Kết quả** quay lại màn Kết quả; **Luyện lại câu sai** mở Trước khi thi.
struct AnswerReviewScreen: View {
    let window: SessionWindowModel
    let review: AnswerReviewModel
    let onPracticeIncorrect: () -> Void

    @FocusState private var listFocused: Bool

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 240, ideal: 300, max: 420)
        } detail: {
            detail
        }
        .onKeyPress(phases: .down) { press in
            guard press.modifiers.isDisjoint(with: [.command, .control, .option]), !window.hasModal else {
                return .ignored
            }
            switch press.key {
            case .leftArrow:
                guard review.canGoPrevious else { return .ignored }
                review.previous()
                return .handled
            case .rightArrow:
                guard review.canGoNext else { return .ignored }
                review.next()
                return .handled
            default:
                return .ignored
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    window.showResults()
                } label: {
                    Label(localized("Kết quả"), systemImage: "chevron.backward")
                }
                .help(Text("Về màn Kết quả", bundle: .module))
                .accessibilityIdentifier("answerReview.results")
            }
            if review.practiceIncorrectPreset != nil {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        onPracticeIncorrect()
                    } label: {
                        Label(localized("Luyện lại câu sai"), systemImage: "arrow.counterclockwise")
                    }
                    .labelStyle(.titleAndIcon)
                    .accessibilityIdentifier("answerReview.practiceIncorrect")
                }
            }
        }
        // Phóng to / Thu nhỏ / Cỡ thật (menu Xem): chỉ chữ của chi tiết câu (`ReviewDetailView`, `contentFont`) đổi cỡ.
        .contentZoomScope()
        // Xem › Nền đọc: nền chỉ phủ chi tiết câu (`readingSurface`); danh sách câu, thanh nút giữ giao diện macOS.
        .readingBackgroundScope()
        .onAppear { listFocused = true }
        .onChange(of: review.selectedIndex) { _, index in
            guard let index else { return }
            let detail = review.detail(at: index)
            SessionAnnouncer.post(localized("Câu \(detail.number) trên \(detail.total), \(detail.status.title)"))
        }
    }

    // MARK: - Trái: bộ lọc, danh sách

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Picker(localized("Bộ lọc"), selection: Binding(get: { review.filter }, set: { review.setFilter($0) })) {
                ForEach(AnswerReviewFilter.allCases) { filter in
                    Text(review.filterTitle(filter)).tag(filter)
                }
            }
            .pickerStyle(.radioGroup)
            .padding(12)
            .accessibilityIdentifier("answerReview.filter")
            Divider()
            let rows = review.rows
            if rows.isEmpty {
                ContentUnavailableView {
                    Label(localized("Không có câu nào"), systemImage: "line.3.horizontal.decrease.circle")
                } description: {
                    Text("Bộ lọc này không có câu nào.", bundle: .module)
                }
                .frame(maxHeight: .infinity)
            } else {
                List(selection: Binding(
                    get: { review.selectedIndex },
                    set: { if let index = $0 { review.select(index: index) } }
                )) {
                    ForEach(rows) { row in
                        ReviewRowView(row: row)
                            .tag(row.index)
                    }
                }
                .focused($listFocused)
                // Dòng đang chọn có chữ trắng trên nền màu nhấn: #017777 (5,38:1).
                .tint(SessionStyle.accentFill)
                // Không lặp vai trò "danh sách" trong nhãn (kiểm trợ năng: "Label duplicates role description").
                .accessibilityLabel(Text("Các câu của bài", bundle: .module))
                .accessibilityIdentifier("answerReview.list")
            }
        }
    }

    // MARK: - Phải: chi tiết

    @ViewBuilder
    private var detail: some View {
        if let detail = review.detail {
            VStack(spacing: 0) {
                ScrollView {
                    ReviewDetailView(detail: detail, media: review.media, answersHidden: review.answersHidden)
                        .frame(maxWidth: SessionStyle.readableWidth, alignment: .leading)
                        .padding(24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .id(detail.index)
                }
                .readingSurface(systemTint: SessionStyle.accentForeground)
                Divider()
                HStack {
                    Button {
                        review.previous()
                    } label: {
                        Label(localized("Câu trước"), systemImage: "chevron.left")
                    }
                    .disabled(!review.canGoPrevious)
                    .help(Text("Câu trước trong bộ lọc (←)", bundle: .module))
                    .accessibilityIdentifier("answerReview.previous")
                    Button {
                        review.next()
                    } label: {
                        Label(localized("Câu sau"), systemImage: "chevron.right")
                    }
                    .disabled(!review.canGoNext)
                    .help(Text("Câu sau trong bộ lọc (→)", bundle: .module))
                    .accessibilityIdentifier("answerReview.next")
                    Spacer()
                    Text("Câu \(detail.number)/\(detail.total)", bundle: .module)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("answerReview.position")
                }
                .labelStyle(.titleAndIcon)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        } else {
            ContentUnavailableView(localized("Chọn một câu để xem lại"), systemImage: "doc.text.magnifyingglass")
        }
    }
}

/// Dòng của danh sách: số câu, trạng thái (biểu tượng + chữ), đánh dấu, câu đã sửa/xoá, đoạn đầu nội dung.
private struct ReviewRowView: View {
    let row: AnswerReviewRow

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Text("Câu \(row.number)", bundle: .module)
                    .font(.headline)
                    .monospacedDigit()
                // Màu của bảng; trên dòng đang chọn (nền teal) thành chữ trắng của hệ thống (`paletteForeground`).
                Label(row.status.title, systemImage: row.status.systemImage)
                    .font(.callout)
                    .paletteForeground(SessionStyle.color(for: row.status.outcome))
                if row.isFlagged {
                    Label(localized("Đánh dấu"), systemImage: "flag.fill")
                        .labelStyle(.iconOnly)
                        .paletteForeground(SessionStyle.warning)
                }
                switch row.change {
                case .unchanged:
                    EmptyView()
                case .edited:
                    Label(localized("Đã sửa"), systemImage: "pencil.circle")
                        .labelStyle(.iconOnly)
                        .paletteForeground(SessionStyle.warning)
                case .deleted:
                    Label(localized("Đã xoá"), systemImage: "trash.circle")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.secondary)
                }
            }
            Text(MarkdownText.plain(row.preview))
                .lineLimit(2)
                .foregroundStyle(.secondary)
                .font(.callout)
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .ignore)
        // Vai trò chữ tĩnh: phần tử gộp không có vai trò thì kiểm trợ năng báo "Unknown role" (bước 8b).
        .accessibilityAddTraits(.isStaticText)
        .accessibilityLabel(Text(row.accessibilityLabel))
    }
}

/// Chi tiết một câu khi xem lại.
private struct ReviewDetailView: View {
    let detail: AnswerReviewDetail
    let media: [String: Data]
    let answersHidden: Bool

    @Environment(\.readingStyle) private var reading

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(detail.sectionTitle)
                    .contentFont(.headline)
                    .foregroundStyle(reading.secondaryText)
                Text("Câu \(detail.number)/\(detail.total)", bundle: .module)
                    .contentFont(.headline)
                    .monospacedDigit()
                Label(detail.status.title, systemImage: detail.status.systemImage)
                    .contentFont(.headline)
                    .foregroundStyle(reading.color(for: detail.status.outcome))
                    .accessibilityIdentifier("answerReview.status")
                if detail.isFlagged {
                    Label(localized("Đã đánh dấu"), systemImage: "flag.fill")
                        .foregroundStyle(reading.warning)
                }
                Spacer()
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            ForEach(Array(detail.notices.enumerated()), id: \.offset) { offset, notice in
                SessionBannerView(
                    systemImage: offset == 0 ? "exclamationmark.triangle.fill" : "info.circle",
                    tone: LibraryPalette.warning,
                    message: notice,
                    scalesWithContent: true
                )
            }
            if let text = detail.text {
                MarkdownText(text)
                    .contentFont(.title3)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            if let path = detail.imagePath, let data = media[path] {
                QuestionImageView(data: data)
            }
            if answersHidden, detail.text != nil {
                Label(
                    localized("Đề này ẩn đáp án: chỉ hiện lựa chọn của bạn và kết quả đúng/sai."),
                    systemImage: "eye.slash"
                )
                    .contentFont(.callout)
                    .foregroundStyle(reading.secondaryText)
            }
            VStack(alignment: .leading, spacing: 8) {
                ForEach(detail.options) { option in
                    ReviewOptionRow(option: option)
                }
            }
            if let explanation = detail.explanation, !explanation.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Giải thích", bundle: .module).contentFont(.headline)
                    MarkdownText(explanation)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .readingFill(reading.explanationBackground, in: RoundedRectangle(cornerRadius: SessionStyle.cornerRadius))
                .accessibilityElement(children: .combine)
                // Vai trò chữ tĩnh: phần tử gộp không có vai trò thì kiểm trợ năng báo "Unknown role" (bước 8b).
                .accessibilityAddTraits(.isStaticText)
            }
        }
        // Cỡ chữ của vùng nội dung câu (Phóng to/Thu nhỏ, phương án 5): chữ không đặt phông riêng là body theo hệ số.
        .contentBodyFont()
    }
}

private struct ReviewOptionRow: View {
    let option: ReviewOption

    @Environment(\.questionContentScale) private var scale
    @Environment(\.readingStyle) private var reading

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(option.label)
                .contentFont(.body, weight: .semibold, design: .monospaced)
                .frame(minWidth: 18 * scale, alignment: .leading)
            MarkdownText(option.text)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: 2) {
                if option.isSelected {
                    Label(localized("Bạn chọn"), systemImage: "hand.point.up.left.fill")
                        .foregroundStyle(reading.accent)
                }
                if option.isCorrectAnswer == true {
                    Label(localized("Đáp án đúng"), systemImage: "checkmark.circle.fill")
                        .foregroundStyle(reading.positive)
                }
            }
            .contentFont(.callout, weight: .semibold)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(reading.optionBackground, in: RoundedRectangle(cornerRadius: SessionStyle.cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: SessionStyle.cornerRadius)
                .strokeBorder(borderStyle, lineWidth: option.isCorrectAnswer == true || option.isSelected ? 2 : 1)
        }
        .accessibilityElement(children: .ignore)
        // Vai trò chữ tĩnh: phần tử gộp không có vai trò thì kiểm trợ năng báo "Unknown role" (bước 8b).
        .accessibilityAddTraits(.isStaticText)
        .accessibilityLabel(Text(option.accessibilityLabel))
    }

    private var borderStyle: AnyShapeStyle {
        if option.isCorrectAnswer == true { return AnyShapeStyle(reading.positive) }
        if option.isSelected { return AnyShapeStyle(reading.accent) }
        return reading.border
    }

}
