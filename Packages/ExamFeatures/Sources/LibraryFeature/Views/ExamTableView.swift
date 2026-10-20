import Foundation
import LibraryData
import SwiftUI

/// Một dòng của danh sách đề, với khoá sắp xếp cho từng cột.
struct LibraryRow: Identifiable, Hashable {
    let entry: LibraryEntry
    let latestAttempt: Attempt?
    let status: EntryStatusPresentation

    var id: UUID { entry.examID }
    var title: String { entry.title }
    var code: String { entry.code ?? "" }
    var questionCount: Int { entry.summary.questionCount }
    var sectionCount: Int { entry.summary.sectionCount }
    var timeLimitMinutes: Int { entry.summary.timeLimitMinutes }
    var passPercent: Int { entry.summary.passPercent }
    /// Điểm thang 1000 của lần thi gần nhất; chưa thi xếp sau mọi điểm.
    var lastScoreSortKey: Int { latestAttempt?.score1000 ?? -1 }
    var statusSortKey: Int { status.sortRank }
}

/// So chuỗi theo thứ tự tiếng Việt, số theo giá trị (`LibraryQuery.compareTitles`), cho cột của `Table`.
struct VietnameseComparator: SortComparator {
    var order: SortOrder = .forward

    func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let result = LibraryQuery.compareTitles(lhs, rhs)
        guard order == .reverse else { return result }
        switch result {
        case .orderedAscending: return .orderedDescending
        case .orderedDescending: return .orderedAscending
        case .orderedSame: return .orderedSame
        }
    }
}

/// Danh sách đề dạng `Table` (docs/product/library.md: các cột tương ứng thẻ, Trạng thái ngay sau Tên đề, sắp xếp được
/// theo cột).
/// Thứ tự mặc định là cách sắp xếp trên thanh công cụ; bấm tiêu đề cột thì sắp theo cột đó cho tới khi
/// đổi cách sắp xếp trên thanh công cụ. Nhấp đúp hoặc Return mở **Trước khi thi** (đề Sẵn sàng), ⌫ xoá khỏi
/// thư viện.
struct ExamTableView: View {
    @Bindable var model: LibraryModel
    let entries: [LibraryEntry]
    let sortOrder: LibrarySortOrder

    @State private var columnSort: [KeyPathComparator<LibraryRow>] = []

    var body: some View {
        let rows = entries.map { entry in
            LibraryRow(
                entry: entry,
                latestAttempt: model.store.latestAttempts[entry.examID],
                status: EntryStatusPresentation(status: entry.status, isAdmin: model.isAdmin)
            )
        }
        let sortedRows = columnSort.isEmpty ? rows : rows.sorted(using: columnSort)
        Table(sortedRows, selection: $model.selection, sortOrder: $columnSort) {
            TableColumn(localized("Tên đề"), value: \.title, comparator: VietnameseComparator()) { row in
                TitleCell(row: row)
            }
            .width(min: 180, ideal: 260)
            // Trạng thái ngay sau Tên đề (Nt0 chốt 2026-10-18, library.md): ở cửa sổ 960 có thanh bên, tám cột không vừa
            // (~742 pt cho ~863 pt ở độ rộng tối thiểu), đề cần xử lý ("Không tìm thấy file"…) vẫn thấy trạng thái không
            // phải cuộn ngang; các cột sau có thể phải cuộn ở cửa sổ hẹp.
            TableColumn(localized("Trạng thái"), value: \.statusSortKey) { row in
                StatusLabel(presentation: row.status)
                    .help(Text(row.status.detail ?? row.status.title))
            }
            .width(min: 120, ideal: 160)
            TableColumn(localized("Mã đề"), value: \.code, comparator: VietnameseComparator()) { row in
                Text(row.code).monospaced()
            }
            .width(min: 60, ideal: 90)
            TableColumn(localized("Số câu"), value: \.questionCount) { row in
                Text(row.questionCount, format: .number)
            }
            .width(min: 50, ideal: 60)
            TableColumn(localized("Số phần"), value: \.sectionCount) { row in
                Text(row.sectionCount, format: .number)
            }
            .width(min: 50, ideal: 60)
            TableColumn(localized("Thời gian"), value: \.timeLimitMinutes) { row in
                Text(LibraryFormat.minutes(row.timeLimitMinutes))
            }
            .width(min: 60, ideal: 70)
            TableColumn(localized("Ngưỡng đậu"), value: \.passPercent) { row in
                Text(LibraryFormat.percent(row.passPercent))
            }
            .width(min: 60, ideal: 80)
            TableColumn(localized("Lần thi gần nhất"), value: \.lastScoreSortKey) { row in
                LastAttemptCell(attempt: row.latestAttempt)
            }
            .width(min: 140, ideal: 190)
        }
        .contextMenu(forSelectionType: UUID.self) { ids in
            if let examID = ids.first, let entry = model.store.entry(examID) {
                ExamMenuItems(actions: ExamActions(entry: entry, model: model), showsShortcuts: true)
            }
        } primaryAction: { ids in
            if let examID = ids.first { model.startSession(examID) }
        }
        .onDeleteCommand {
            if let selection = model.selection { model.remove(selection) }
        }
        .onChange(of: sortOrder) {
            columnSort = []
        }
        .accessibilityLabel(Text("Danh sách đề", bundle: .module))
        .accessibilityIdentifier("library.table")
        // Dòng đang chọn có chữ trắng trên nền màu nhấn (nếu theo tint): dùng #017777 (5,38:1). Ô trong bảng
        // không có nút; nhãn Đề mẫu và biểu tượng trạng thái đặt màu riêng.
        .tint(LibraryStyle.accent)
    }
}

private struct TitleCell: View {
    let row: LibraryRow

    var body: some View {
        HStack(spacing: 6) {
            Text(row.title)
                .lineLimit(1)
                .help(Text(row.title))
            if row.entry.isSample {
                SampleBadge()
            }
        }
    }
}

private struct LastAttemptCell: View {
    let attempt: Attempt?

    var body: some View {
        if let attempt {
            HStack(spacing: 4) {
                Image(systemName: LibraryFormat.resultSymbol(passed: attempt.passed))
                    .paletteForeground(attempt.passed ? LibraryStyle.positive : LibraryStyle.critical)
                    .accessibilityHidden(true)
                Text(LibraryFormat.lastAttempt(attempt))
            }
        } else {
            Text(LibraryFormat.lastAttempt(nil))
                .foregroundStyle(.secondary)
        }
    }
}
