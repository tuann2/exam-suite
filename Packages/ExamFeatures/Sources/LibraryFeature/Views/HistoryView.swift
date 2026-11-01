import ExamKit
import Foundation
import InterfaceCore
import LibraryData
import SwiftUI

extension Attempt {
    /// "Luyện tập" hoặc "Thi", cho cột Chế độ.
    var modeTitle: String { LibraryFormat.mode(mode) }
    /// Đậu xếp trước Trượt khi sắp theo cột Kết quả.
    var passedSortKey: Int { passed ? 1 : 0 }
}

/// **Lịch sử thi** (docs/product/library.md): mọi lần thi, mới nhất trước; ngày giờ, tên đề lúc thi,
/// thí sinh, chế độ, điểm %, thang 1000, đậu/trượt (biểu tượng + chữ), thời gian làm. **Xem lịch sử thi**
/// từ một đề thì chỉ hiện đề đó. Nhấp đúp hoặc Return trên một lần thi mở **Kết quả** của lần đó trong cửa
/// sổ làm bài (docs/product/exam-taking.md, mục Lịch sử thi).
struct HistoryView: View {
    let model: LibraryModel

    @State private var sortOrder = [KeyPathComparator(\Attempt.submittedAt, order: .reverse)]
    @State private var selection: Attempt.ID?

    var body: some View {
        let attempts = model.visibleAttempts()
        VStack(spacing: 0) {
            if let title = model.historyExamTitle {
                filterBar(title: title)
                Divider()
            }
            if attempts.isEmpty {
                emptyState
            } else {
                table(attempts.sorted(using: sortOrder), cells: Self.cells(of: attempts))
            }
        }
    }

    /// Cột của bảng, theo thứ tự của `LibraryAccessibility.historyRowCells`.
    enum Column: Int {
        case dateTime, examTitle, candidate, mode, percent, scale1000, result, duration
    }

    /// Chữ của mọi ô của từng dòng (`LibraryAccessibility.historyRowCells`), định dạng **một lần** mỗi dòng mỗi lần vẽ
    /// bảng (trước đây mỗi ô dựng lại cả 8 chữ của dòng; review độc lập #54).
    static func cells(of attempts: [Attempt]) -> [Attempt.ID: [String]] {
        Dictionary(attempts.map { ($0.id, LibraryAccessibility.historyRowCells($0)) }, uniquingKeysWith: { first, _ in first })
    }

    /// Chữ của ô cột `column` của `attempt` trong `cells` (dựng lại nếu thiếu dòng).
    static func cell(_ attempt: Attempt, _ column: Column, in cells: [Attempt.ID: [String]]) -> String {
        (cells[attempt.id] ?? LibraryAccessibility.historyRowCells(attempt))[column.rawValue]
    }

    /// Ô cột **Thang 1000**: số trơn ở mọi ngôn ngữ ("1000", không "1.000"/"1,000"), như Kết quả (Nt0 chốt 2026-10-17,
    /// `InterfaceLocale.scale1000`).
    static func scale1000Cell(_ value: Int) -> Text {
        Text(verbatim: InterfaceLocale.scale1000(value))
    }

    private func filterBar(title: String) -> some View {
        HStack(spacing: 12) {
            Label {
                Text("Lịch sử thi của đề “\(title)”", bundle: .module)
            } icon: {
                Image(systemName: "line.3.horizontal.decrease.circle")
            }
            .lineLimit(1)
            Spacer()
            Button(localized("Xem mọi lần thi")) { model.showAllHistory() }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func table(_ attempts: [Attempt], cells: [Attempt.ID: [String]]) -> some View {
        // Chữ của từng ô lấy từ `LibraryAccessibility.historyRowCells` (có test): VoiceOver đọc dòng bằng đúng các chữ đó
        // (review độc lập #54 S5).
        Table(attempts, selection: $selection, sortOrder: $sortOrder) {
            TableColumn(localized("Ngày giờ"), value: \.submittedAt) { attempt in
                Text(Self.cell(attempt, .dateTime, in: cells))
            }
            .width(min: 120, ideal: 140)
            TableColumn(localized("Tên đề"), value: \.examTitle, comparator: VietnameseComparator()) { attempt in
                Text(Self.cell(attempt, .examTitle, in: cells)).help(Text(attempt.examTitle))
            }
            .width(min: 160, ideal: 240)
            TableColumn(localized("Thí sinh"), value: \.candidateName, comparator: VietnameseComparator()) { attempt in
                Text(Self.cell(attempt, .candidate, in: cells))
            }
            .width(min: 100, ideal: 150)
            TableColumn(localized("Chế độ"), value: \.modeTitle, comparator: VietnameseComparator()) { attempt in
                Text(Self.cell(attempt, .mode, in: cells))
            }
            .width(min: 70, ideal: 80)
            TableColumn(localized("Điểm"), value: \.percent) { attempt in
                Text(Self.cell(attempt, .percent, in: cells))
            }
            .width(min: 50, ideal: 60)
            TableColumn(localized("Thang 1000"), value: \.score1000) { attempt in
                Self.scale1000Cell(attempt.score1000)
                    .accessibilityLabel(Text(Self.cell(attempt, .scale1000, in: cells)))
            }
            .width(min: 70, ideal: 80)
            TableColumn(localized("Kết quả"), value: \.passedSortKey) { attempt in
                ResultLabel(passed: attempt.passed)
                    .accessibilityLabel(Text(Self.cell(attempt, .result, in: cells)))
            }
            .width(min: 70, ideal: 90)
            TableColumn(localized("Thời gian làm"), value: \.elapsedSeconds) { attempt in
                Text(Self.cell(attempt, .duration, in: cells))
            }
            .width(min: 90, ideal: 110)
        }
        .contextMenu(forSelectionType: Attempt.ID.self) { ids in
            if let attempt = attempt(ids.first, in: attempts) {
                Button(localized("Xem kết quả"), systemImage: "chart.bar.doc.horizontal") { model.openAttempt(attempt) }
                    .disabled(model.sessionActions == nil)
            }
        } primaryAction: { ids in
            if let attempt = attempt(ids.first, in: attempts) { model.openAttempt(attempt) }
        }
        .accessibilityLabel(Text("Lịch sử thi", bundle: .module))
        .accessibilityIdentifier("library.history")
        // Dòng đang chọn có chữ trắng trên nền màu nhấn (nếu theo tint): dùng #017777 (5,38:1).
        .tint(LibraryStyle.accent)
    }

    private func attempt(_ id: Attempt.ID?, in attempts: [Attempt]) -> Attempt? {
        guard let id else { return nil }
        return attempts.first { $0.id == id }
    }

    @ViewBuilder
    private var emptyState: some View {
        if !model.searchText.isEmpty, !model.store.attempts(examID: model.historyExamID).isEmpty {
            ContentUnavailableView.search(text: model.searchText)
        } else if model.historyExamID != nil {
            ContentUnavailableView {
                Label(localized("Đề này chưa có lần thi nào"), systemImage: "list.bullet.rectangle")
            } description: {
                Text("Mỗi lần bạn nộp bài Luyện tập hoặc Thi đề này sẽ được ghi ở đây.", bundle: .module)
            } actions: {
                Button(localized("Xem mọi lần thi")) { model.showAllHistory() }
            }
        } else {
            ContentUnavailableView {
                Label(localized("Chưa có lần thi nào"), systemImage: "list.bullet.rectangle")
            } description: {
                Text(
                    "Mỗi lần bạn nộp bài Luyện tập hoặc Thi sẽ được ghi ở đây, mới nhất trước: ngày giờ, đề, thí sinh, điểm và kết quả.", bundle: .module
                )
            }
        }
    }
}
