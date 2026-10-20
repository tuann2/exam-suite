import LibraryData
import SwiftUI

/// Thẻ đề trong lưới (docs/product/library.md, mục Thẻ đề): tiêu đề, mã, số câu, số phần, thời gian,
/// ngưỡng đậu, lần thi gần nhất, trạng thái (biểu tượng + chữ) kèm bước tiếp theo, nút Luyện tập/Thi
/// (chỉ bật khi đề Sẵn sàng) và nút "…". VoiceOver đọc cả thẻ thành một câu và có hành động như menu;
/// hành động mặc định (như nhấp đúp) mở Trước khi thi khi đề Sẵn sàng.
struct ExamCardView: View {
    let entry: LibraryEntry
    let latestAttempt: Attempt?
    let actions: ExamActions
    let isSelected: Bool
    /// Lưới đang có tiêu điểm bàn phím: viền chọn đậm hơn để tiêu điểm luôn nhìn thấy được.
    let showsFocus: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            Text(LibraryFormat.facts(entry.summary))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            lastAttempt
            Divider()
            status
            Spacer(minLength: 0)
            practiceButtons
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.background, in: RoundedRectangle(cornerRadius: LibraryStyle.cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: LibraryStyle.cornerRadius)
                .strokeBorder(borderStyle, lineWidth: borderWidth)
        }
        .contentShape(RoundedRectangle(cornerRadius: LibraryStyle.cornerRadius))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(LibraryAccessibility.cardSummary(
            entry: entry,
            latestAttempt: latestAttempt,
            isAdmin: actions.isAdmin
        )))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("library.card.\(entry.examID.uuidString)")
        .accessibilityAction {
            if actions.canStartSession { actions.open() }
        }
        .accessibilityActions { ExamAccessibilityActions(actions: actions) }
    }

    private var borderStyle: AnyShapeStyle {
        isSelected ? AnyShapeStyle(LibraryStyle.accentForeground) : AnyShapeStyle(.separator)
    }

    private var borderWidth: CGFloat {
        guard isSelected else { return 1 }
        return showsFocus ? 3 : 2
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.title)
                    .font(.headline)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                if let code = entry.code, !code.isEmpty {
                    Text(code)
                        .font(.subheadline.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 4)
            if entry.isSample {
                SampleBadge()
            }
            Menu {
                ExamMenuItems(actions: actions, showsShortcuts: false)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .imageScale(.large)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help(Text("Thao tác khác", bundle: .module))
            .accessibilityLabel(Text("Thao tác khác", bundle: .module))
        }
    }

    private var lastAttempt: some View {
        HStack(spacing: 6) {
            if let latestAttempt {
                Image(systemName: LibraryFormat.resultSymbol(passed: latestAttempt.passed))
                    .foregroundStyle(latestAttempt.passed ? LibraryStyle.positive : LibraryStyle.critical)
                Text("Lần gần nhất: \(LibraryFormat.lastAttempt(latestAttempt))", bundle: .module)
            } else {
                Image(systemName: "circle.dashed")
                    .foregroundStyle(.secondary)
                Text(LibraryFormat.lastAttempt(nil))
                    .foregroundStyle(.secondary)
            }
        }
        .font(.callout)
    }

    private var status: some View {
        VStack(alignment: .leading, spacing: 6) {
            StatusLabel(presentation: actions.presentation)
                .font(.callout.weight(.semibold))
            if let detail = actions.presentation.detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .help(Text(detail))
            }
            NextStepButtons(actions: actions)
        }
    }

    private var practiceButtons: some View {
        HStack(spacing: 8) {
            Button(localized("Luyện tập")) { actions.startPractice() }
                .accessibilityIdentifier("library.card.practice")
            Button(localized("Thi")) { actions.startExam() }
                .accessibilityIdentifier("library.card.exam")
        }
        .disabled(!actions.canStartSession)
        .controlSize(.small)
    }
}
