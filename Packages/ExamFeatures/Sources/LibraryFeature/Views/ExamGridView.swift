import LibraryData
import SwiftUI

/// Lưới thẻ đề. Cả lưới là một vùng nhận tiêu điểm bàn phím: phím mũi tên đổi đề đang chọn, Return mở
/// **Trước khi thi** (đề Sẵn sàng), ⌫ **Xoá khỏi thư viện**; đề đang chọn có viền teal, đậm hơn khi lưới có tiêu điểm.
struct ExamGridView: View {
    let model: LibraryModel
    let entries: [LibraryEntry]

    @FocusState private var isFocused: Bool
    @State private var width: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var columnCount: Int {
        GridNavigation.columns(
            forWidth: width - 2 * LibraryStyle.gridPadding,
            minItemWidth: LibraryStyle.cardMinWidth,
            spacing: LibraryStyle.gridSpacing
        )
    }

    var body: some View {
        let columns = Array(
            repeating: GridItem(.flexible(), spacing: LibraryStyle.gridSpacing, alignment: .top),
            count: columnCount
        )
        ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(columns: columns, alignment: .leading, spacing: LibraryStyle.gridSpacing) {
                    ForEach(entries) { entry in
                        card(for: entry)
                    }
                }
                .padding(LibraryStyle.gridPadding)
                // Nhóm thẻ có tên (kiểm trợ năng: nhóm không tên, bước 8b).
                .accessibilityElement(children: .contain)
                .accessibilityLabel(Text("Đề trong thư viện", bundle: .module))
            }
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { newWidth in
                width = newWidth
            }
            .onChange(of: model.selection) { _, selection in
                guard let selection else { return }
                // Reduce Motion: cuộn tới thẻ đang chọn không có hiệu ứng (accessibility-localization.md, bước 8b).
                withAnimation(reduceMotion ? nil : .default) { proxy.scrollTo(selection) }
            }
        }
        .focusable()
        .focused($isFocused)
        .focusEffectDisabled()
        .overlay {
            // Vòng tiêu điểm của cả lưới khi chưa có đề nào được chọn (có đề chọn thì viền của thẻ đó đậm
            // lên): tiêu điểm luôn nhìn thấy được (docs/product/library.md).
            if isFocused, !entries.contains(where: { $0.examID == model.selection }) {
                RoundedRectangle(cornerRadius: LibraryStyle.cornerRadius)
                    .strokeBorder(LibraryStyle.accentForeground, lineWidth: 3)
                    .padding(4)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .defaultFocus($isFocused, true)
        .onMoveCommand { direction in
            guard let direction = GridNavigation.Direction(direction) else { return }
            model.moveSelection(direction, in: entries.map(\.examID), columns: columnCount)
        }
        .onKeyPress(.return) {
            guard let selection = model.selection else { return .ignored }
            // Đề chưa Sẵn sàng: hành động tắt (exam-taking.md, phương án 5).
            return model.startSession(selection) ? .handled : .ignored
        }
        .onDeleteCommand {
            if let selection = model.selection { model.remove(selection) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Lưới đề", bundle: .module))
        .accessibilityIdentifier("library.grid")
    }

    private func card(for entry: LibraryEntry) -> some View {
        let examID = entry.examID
        let actions = ExamActions(entry: entry, model: model)
        return ExamCardView(
            entry: entry,
            latestAttempt: model.store.latestAttempts[examID],
            actions: actions,
            isSelected: model.selection == examID,
            showsFocus: isFocused
        )
        .id(examID)
        .onTapGesture(count: 2) { model.startSession(examID) }
        .simultaneousGesture(TapGesture().onEnded {
            model.selection = examID
            isFocused = true
        })
        .contextMenu { ExamMenuItems(actions: actions, showsShortcuts: true) }
    }
}

extension GridNavigation.Direction {
    init?(_ direction: MoveCommandDirection) {
        switch direction {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        @unknown default: return nil
        }
    }
}
