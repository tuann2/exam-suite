import ExamImport
import LibraryFeature
import SwiftUI

/// Bảng báo cáo import ở đáy cột giữa, trên thanh lỗi (docs/product/import.md, Luồng bước 5): từng câu bị bỏ hoặc có
/// cảnh báo, kèm vị trí trong file gốc và lý do; bấm dòng gắn với một câu thì chọn câu đó. Ẩn/hiện bằng nút trên thanh
/// công cụ hoặc nút đóng của bảng.
struct ImportReportPanel: View {
    @Bindable var editor: AuthoringEditor
    let report: ImportReportState

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 8) {
                Image(systemName: "doc.text.magnifyingglass")
                    .accessibilityHidden(true)
                Text(report.summary)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                Button {
                    editor.showsImportReport = false
                } label: {
                    Label(localized("Ẩn báo cáo import"), systemImage: "xmark")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .help(Text("Ẩn báo cáo import", bundle: .module))
                .accessibilityIdentifier("authoring.importReport.hide")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            if !report.rows.isEmpty {
                List(report.rows) { row in
                    ImportReportRowView(row: row, destination: row.destination(containsQuestion: editor.containsQuestion)) {
                        if let id = row.questionID { editor.navigate(toQuestion: id) }
                    }
                }
                .listStyle(.plain)
                .accessibilityLabel(Text("Mục của báo cáo import", bundle: .module))
                .frame(height: AuthoringStyle.bottomListHeight(
                    rows: report.rows.count,
                    sharing: editor.isIssueListExpanded && !editor.issues.issues.isEmpty
                ))
                .accessibilityIdentifier("authoring.importReport.list")
            }
        }
        .adaptiveBackground(.bar)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("authoring.importReport")
    }
}

private struct ImportReportRowView: View {
    let row: ImportReportRow
    let destination: ImportReportRow.Destination
    let select: () -> Void

    var body: some View {
        let content = HStack(alignment: .firstTextBaseline, spacing: 8) {
            Label {
                Text(row.severityTitle)
            } icon: {
                Image(systemName: row.severitySymbol)
                    .foregroundStyle(row.severity == .dropped ? AuthoringStyle.critical : AuthoringStyle.warning)
            }
            .font(.caption.weight(.semibold))
            .frame(width: 92, alignment: .leading)
            Text(row.location)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.message)
                    .font(.callout)
                if destination == .deletedQuestion {
                    Text("Câu này đã bị xoá khỏi đề.", bundle: .module)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())

        if case .question = destination {
            Button(action: select) { content }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(row.accessibilityLabel))
                .accessibilityHint(Text("Chọn câu này", bundle: .module))
                .accessibilityAddTraits(.isButton)
                // Gộp phần tử bỏ hành động bấm của nút: thêm lại (kiểm trợ năng "Action is missing", bước 8b).
                .accessibilityAction(.default, select)
                .accessibilityIdentifier("authoring.importReport.entry.\(row.id)")
        } else {
            content
                .accessibilityElement(children: .ignore)
                // Vai trò chữ tĩnh: phần tử gộp không có vai trò thì kiểm trợ năng báo "Unknown role" (bước 8b).
                .accessibilityAddTraits(.isStaticText)
                .accessibilityLabel(Text(destination == .deletedQuestion
                    ? localized("\(row.accessibilityLabel) Câu này đã bị xoá khỏi đề.")
                    : row.accessibilityLabel))
                .accessibilityIdentifier("authoring.importReport.entry.\(row.id)")
        }
    }
}
