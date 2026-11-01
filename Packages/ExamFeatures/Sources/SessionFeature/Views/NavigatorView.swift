import ExamKit
import InterfaceCore
import LibraryFeature
import SessionModel
import SwiftUI

/// Bảng câu hỏi (`.inspector`, ⌃⌘I): tiến độ "Đã làm 12/60", chú thích, các ô nhóm theo phần trong lưới lười
/// (đề 2.000 câu chỉ dựng ô đang thấy). Bấm ô để tới câu đó; ở Rà soát chưa khoá thì quay lại làm bài tại câu đó.
struct NavigatorView: View {
    let attempt: AttemptModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text(attempt.progressText)
                    .font(.headline)
                    .monospacedDigit()
                ProgressView(value: Double(attempt.answeredCount), total: Double(max(1, attempt.questionCount)))
                    .tint(SessionStyle.accentForeground)
                    .accessibilityHidden(true)
                NavigatorLegend()
            }
            .padding([.horizontal, .top], 12)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("navigator.progress")
            Divider()
            NavigatorGrid(attempt: attempt)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Bảng câu hỏi", bundle: .module))
        .accessibilityIdentifier("navigator")
    }
}

/// Chú thích hình dạng của ô (không chỉ dựa vào màu).
private struct NavigatorLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(localized("Đã làm"), systemImage: "circle.fill")
            Label(localized("Chưa làm"), systemImage: "circle")
            Label(localized("Đánh dấu"), systemImage: "flag.fill")
            Label(localized("Đang xem: viền đậm"), systemImage: "square.dashed")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

/// Lưới ô số câu, nhóm theo phần. Dùng cả ở Rà soát khi bảng bên phải đang ẩn.
struct NavigatorGrid: View {
    let attempt: AttemptModel

    private let columns = [GridItem(.adaptive(minimum: 44, maximum: 56), spacing: 6)]

    var body: some View {
        let sections = attempt.navigatorSections
        let canNavigate = attempt.phase == .inProgress || attempt.phase == .reviewing(locked: false)
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10, pinnedViews: [.sectionHeaders]) {
                    ForEach(sections) { section in
                        Section {
                            LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
                                ForEach(section.cells) { cell in
                                    NavigatorCellButton(cell: cell, enabled: canNavigate) {
                                        select(cell.index)
                                    }
                                    .id(cell.index)
                                }
                            }
                            // Nhóm ô của một phần có tên (kiểm trợ năng: nhóm không tên, bước 8b).
                            .accessibilityElement(children: .contain)
                            .accessibilityLabel(Text(section.title))
                            .padding(.horizontal, 12)
                        } header: {
                            Text(section.title)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(2)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .adaptiveBackground(.bar)
                                .accessibilityAddTraits(.isHeader)
                        }
                    }
                }
                .padding(.bottom, 12)
                .accessibilityElement(children: .contain)
                .accessibilityLabel(Text("Các câu theo phần", bundle: .module))
            }
            .onChange(of: attempt.currentIndex) { _, index in
                proxy.scrollTo(index)
            }
        }
    }

    private func select(_ index: Int) {
        switch attempt.phase {
        case .inProgress:
            attempt.goTo(index: index)
        case .reviewing(locked: false):
            attempt.returnToAttempt(at: index)
        default:
            break
        }
    }
}

/// Một ô: số câu + biểu tượng trạng thái; Đã làm nền đặc, Đang xem viền đậm. VoiceOver đọc số câu + trạng thái.
private struct NavigatorCellButton: View {
    let cell: NavigatorCell
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Text(cell.number, format: .number)
                    .font(.callout.weight(cell.isCurrent ? .bold : .regular).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Image(systemName: cell.systemImage)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(iconStyle)
            }
            .foregroundStyle(cell.isAnswered ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            .frame(maxWidth: .infinity, minHeight: 36)
            .background(
                cell.isAnswered ? AnyShapeStyle(SessionStyle.accentFill) : AnyShapeStyle(.background),
                in: RoundedRectangle(cornerRadius: 6)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(
                        cell.isCurrent ? AnyShapeStyle(SessionStyle.accentForeground) : AnyShapeStyle(.separator),
                        lineWidth: cell.isCurrent ? 3 : 1
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(Text(cell.accessibilityLabel))
        .accessibilityAddTraits(cell.isCurrent ? .isSelected : [])
        .accessibilityIdentifier("navigator.cell.\(cell.number)")
        .help(Text(cell.accessibilityLabel))
    }

    private var iconStyle: AnyShapeStyle {
        if cell.isFlagged { return AnyShapeStyle(cell.isAnswered ? Color.white : SessionStyle.warning) }
        return cell.isAnswered ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary)
    }
}

// MARK: - Rà soát & nộp

/// **Rà soát & nộp** (docs/product/exam-taking.md): ba số Đã làm / Chưa làm / Đánh dấu, hai danh sách nút số câu
/// (bấm để quay lại làm bài tại câu đó, không có khi rà soát khoá), bảng câu hỏi để tham khảo; **Quay lại làm
/// bài** (Esc) và **Nộp bài** (nút chính, Return).
struct ReviewSubmitView: View {
    let window: SessionWindowModel
    let attempt: AttemptModel
    let summary: ReviewSummary

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    Text("Rà soát & nộp", bundle: .module)
                        .font(.title.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                    HStack(spacing: 12) {
                        StatBox(title: localized("Đã làm"), value: summary.answeredCount, systemImage: "circle.fill")
                            .accessibilityIdentifier("review.answered")
                        StatBox(title: localized("Chưa làm"), value: summary.unansweredCount, systemImage: "circle")
                            .accessibilityIdentifier("review.unanswered")
                        StatBox(title: localized("Đánh dấu"), value: summary.flaggedCount, systemImage: "flag.fill")
                            .accessibilityIdentifier("review.flagged")
                    }
                    QuestionNumberList(
                        title: localized("Câu chưa làm"),
                        empty: localized("Không còn câu chưa làm."),
                        indices: summary.unansweredIndices,
                        enabled: summary.canReturnToAttempt
                    ) { attempt.returnToAttempt(at: $0) }
                    QuestionNumberList(
                        title: localized("Câu đã đánh dấu"),
                        empty: localized("Không có câu đánh dấu."),
                        indices: summary.flaggedIndices,
                        enabled: summary.canReturnToAttempt
                    ) { attempt.returnToAttempt(at: $0) }
                    if !attempt.isNavigatorVisible {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Bảng câu hỏi", bundle: .module)
                                .font(.headline)
                                .accessibilityAddTraits(.isHeader)
                            NavigatorGrid(attempt: attempt)
                                .frame(minHeight: 160, maxHeight: 320)
                        }
                    }
                }
                .frame(maxWidth: SessionStyle.readableWidth, alignment: .leading)
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .contain)
                .accessibilityLabel(Text("Rà soát & nộp", bundle: .module))
            }
            Divider()
            HStack(spacing: 12) {
                if summary.canReturnToAttempt {
                    Button {
                        attempt.perform(.returnToAttempt)
                    } label: {
                        Label(localized("Quay lại làm bài"), systemImage: "arrow.uturn.backward")
                    }
                    .keyboardShortcut(.cancelAction)
                    .help(Text("Quay lại làm bài (Esc)", bundle: .module))
                    .accessibilityIdentifier("review.back")
                } else {
                    Label(localized("Đã hết giờ: không sửa được đáp án."), systemImage: "lock.fill")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    window.requestSubmit()
                } label: {
                    Label(localized("Nộp bài"), systemImage: "paperplane.fill")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                // Nền màu nhấn có chữ trắng: #017777 (5,38:1).
                .tint(SessionStyle.accentFill)
                .accessibilityIdentifier("review.submit")
            }
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }
}

private struct StatBox: View {
    let title: String
    let value: Int
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Chữ .primary: nhãn đặt trên nền trung tính của app (quy tắc tương phản áp cho nền của app; .secondary trên nền
            // này chỉ ~3,7:1, kiểm trợ năng báo, bước 8b).
            Label(title, systemImage: systemImage)
                .font(.callout)
            Text(value, format: .number)
                .font(.largeTitle.weight(.semibold).monospacedDigit())
        }
        .padding(12)
        .frame(minWidth: 140, alignment: .leading)
        .adaptiveBackground(
            .neutral(opacity: LibraryPalette.statFillOpacity), in: RoundedRectangle(cornerRadius: SessionStyle.cornerRadius)
        )
        .accessibilityElement(children: .combine)
    }
}

/// Danh sách nút số câu (lưới lười).
private struct QuestionNumberList: View {
    let title: String
    let empty: String
    let indices: [Int]
    let enabled: Bool
    let onSelect: (Int) -> Void

    private let columns = [GridItem(.adaptive(minimum: 48, maximum: 64), spacing: 6)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            if indices.isEmpty {
                Text(empty).foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
                    ForEach(indices, id: \.self) { index in
                        Button {
                            onSelect(index)
                        } label: {
                            Text(index + 1, format: .number)
                        }
                            .monospacedDigit()
                            .frame(maxWidth: .infinity)
                            .disabled(!enabled)
                            .accessibilityLabel(Text("Câu \(index + 1)", bundle: .module))
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel(Text(title))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(title))
    }
}
