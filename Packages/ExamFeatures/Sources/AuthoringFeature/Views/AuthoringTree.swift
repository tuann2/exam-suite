import AuthoringData
import ExamKit
import LibraryFeature
import SwiftUI

/// Cây đề (cột trái, authoring.md mục Cửa sổ và "Cây đề: sắp xếp, nhân bản, xoá"): dòng Đề, rồi mỗi phần và các câu
/// của nó trong **một danh sách phẳng**, để kéo thả (`onMove`) sắp xếp câu trong phần, chuyển câu sang phần khác và
/// sắp xếp phần (kéo dòng phần là kéo cả phần). Đang tìm thì tắt kéo thả. ⌫ xoá dòng đang chọn (xoá phần còn câu
/// thì hỏi lại).
struct AuthoringTree: View {
    @Bindable var editor: AuthoringEditor

    var body: some View {
        let rows = editor.visibleRows
        let isFiltering = !editor.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        List(selection: $editor.selection) {
            ExamTreeRow(editor: editor)
                .tag(TreeRow.exam)
                .moveDisabled(true)
            ForEach(rows, id: \.self) { row in
                TreeRowView(editor: editor, row: row)
                    .contextMenu { TreeRowMenu(editor: editor, row: row) }
            }
            .onMove(perform: isFiltering ? nil : { source, destination in
                editor.moveTreeRows(rows, fromOffsets: source, toOffset: destination)
            })
            if isFiltering && rows.isEmpty {
                Text("Không có câu nào khớp", bundle: .module)
                    .foregroundStyle(.secondary)
                    .selectionDisabled()
            }
        }
        .onDeleteCommand { editor.removeSelection() }
        // Dòng đang chọn có chữ trắng trên nền màu nhấn (nếu theo tint): burgundy `#801638` ở cả hai giao diện (chữ trắng
        // ~10:1); tint của cửa sổ (`accentForeground`) ở giao diện tối là `#F7A1B8`, chữ trắng trên đó chỉ ~1,9:1.
        .tint(AuthoringStyle.accentFill)
        .accessibilityLabel(Text("Cây đề", bundle: .module))
        .accessibilityIdentifier("authoring.tree")
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack(spacing: 8) {
                Button {
                    editor.addSection()
                } label: {
                    Label(localized("Thêm phần"), systemImage: "rectangle.stack.badge.plus")
                }
                .help(Text("Thêm phần sau phần đang chọn", bundle: .module))
                .accessibilityIdentifier("authoring.addSection")
                Button {
                    editor.addQuestion()
                } label: {
                    Label(localized("Thêm câu"), systemImage: "plus")
                }
                .help(Text("Thêm câu vào phần đang chọn (⌥⌘N)", bundle: .module))
                .accessibilityIdentifier("authoring.addQuestion")
                Spacer(minLength: 0)
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .adaptiveBackground(.bar)
        }
    }
}

private struct ExamTreeRow: View {
    let editor: AuthoringEditor

    var body: some View {
        let issues = editor.issues.examIssues
        HStack(spacing: 6) {
            Label {
                Text(editor.exam.title.isEmpty ? localized("(Đề chưa có tên)") : editor.exam.title)
                    .lineLimit(1)
            } icon: {
                Image(systemName: "doc.text")
                    .paletteForeground(AuthoringStyle.accentForeground)
            }
            Spacer(minLength: 4)
            if let severity = IssueIndex.worstSeverity(issues) {
                IssueMark(severity: severity, compact: true)
            }
        }
        .font(.headline)
        .accessibilityElement(children: .ignore)
        // Vai trò nút có hành động chọn dòng: phần tử gộp không có vai trò thì kiểm trợ năng báo "Unknown role"; vai trò chữ
        // tĩnh đưa câu đọc sang giá trị (nhãn rỗng). Nút giữ câu đọc ở nhãn, cùng phần tử với định danh (bước 8b).
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { editor.selection = .exam }
        .accessibilityLabel(Text(examLabel(issues)))
        .accessibilityIdentifier("authoring.tree.exam")
    }

    private func examLabel(_ issues: [ValidationIssue]) -> String {
        let status = AuthoringPresentation.issueStatus(issues)
        return [localized("Đề: \(editor.exam.title)"), status].filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

private struct TreeRowView: View {
    let editor: AuthoringEditor
    let row: TreeRow

    var body: some View {
        switch row {
        case .exam:
            EmptyView()
        case let .section(index):
            if let section = editor.outline.sections[safe: index] {
                let issues = editor.issues.issues(for: row)
                HStack(spacing: 6) {
                    Text(AuthoringPresentation.sectionTitle(section.title))
                        .font(.headline)
                        .lineLimit(1)
                    Text(section.questions.count, format: .number)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 4)
                    if let severity = IssueIndex.worstSeverity(issues) {
                        IssueMark(severity: severity, compact: true)
                    }
                }
                .padding(.top, 4)
                .accessibilityElement(children: .ignore)
                // Vai trò nút có hành động chọn dòng (như dòng Đề ở trên).
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { editor.selection = row }
                .accessibilityLabel(Text(AuthoringPresentation.sectionAccessibilityLabel(section, issues: issues)))
                .accessibilityIdentifier("authoring.tree.section.\(index)")
            }
        case let .question(path):
            if let summary = editor.outline.question(path) {
                let issues = editor.issues.issues(for: row)
                HStack(spacing: 6) {
                    Text(verbatim: "\(InterfaceLocale.number(summary.number)).")
                        .font(.body.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 28, alignment: .trailing)
                    Text(AuthoringPresentation.firstLine(summary))
                        .lineLimit(1)
                        .foregroundStyle(summary.firstLine.isEmpty ? .secondary : .primary)
                    Spacer(minLength: 4)
                    if summary.hasImage {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                            .help(Text("Có ảnh", bundle: .module))
                    }
                    if summary.isMultiple {
                        Image(systemName: "checklist")
                            .foregroundStyle(.secondary)
                            .help(Text("Nhiều đáp án", bundle: .module))
                    }
                    if let severity = IssueIndex.worstSeverity(issues) {
                        IssueMark(severity: severity, compact: true)
                    }
                }
                .padding(.leading, AuthoringStyle.questionIndent)
                .accessibilityElement(children: .ignore)
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { editor.selection = row }
                .accessibilityLabel(Text(AuthoringPresentation.questionAccessibilityLabel(summary, issues: issues)))
                .accessibilityIdentifier("authoring.tree.question.\(path.section).\(path.question)")
            }
        }
    }
}

/// Menu chuột phải: câu có **Nhân bản**, **Chuyển tới phần ▸**, **Xoá**; phần có **Đổi tên**, **Xoá phần**.
private struct TreeRowMenu: View {
    let editor: AuthoringEditor
    let row: TreeRow

    var body: some View {
        switch row {
        case .exam:
            EmptyView()
        case let .section(index):
            Button(localized("Thêm câu vào phần này")) {
                editor.selection = row
                editor.addQuestion()
            }
            Button(localized("Đổi tên")) { editor.beginRenamingSection(at: index) }
            Divider()
            Button(localized("Xoá phần…"), role: .destructive) { editor.requestRemoveSection(at: index) }
        case let .question(path):
            Button(localized("Nhân bản")) { editor.duplicateQuestion(at: path) }
            Menu(localized("Chuyển tới phần")) {
                ForEach(editor.outline.sections, id: \.index) { section in
                    Button(AuthoringPresentation.sectionTitle(section.title)) {
                        editor.moveQuestion(at: path, toSection: section.index)
                    }
                    .disabled(section.index == path.section)
                }
            }
            Divider()
            Button(localized("Xoá"), role: .destructive) { editor.removeQuestion(at: path) }
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
