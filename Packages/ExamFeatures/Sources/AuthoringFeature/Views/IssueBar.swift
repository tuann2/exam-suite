import AuthoringData
import ExamKit
import LibraryFeature
import SessionFeature
import SwiftUI

/// Thanh lỗi ở đáy (authoring.md, mục Cửa sổ và Kiểm lỗi): số lỗi và cảnh báo; mở ra danh sách, bấm một dòng thì
/// chọn đúng đề/phần/câu và trường đó; dòng "Bản Học viên sẽ từ chối đề này" khi bản Học viên (đọc nghiêm) sẽ
/// không mở được. Không chặn lưu.
struct IssueBar: View {
    @Bindable var editor: AuthoringEditor

    var body: some View {
        let index = editor.issues
        VStack(spacing: 0) {
            Divider()
            if editor.isIssueListExpanded && !index.issues.isEmpty {
                List {
                    ForEach(Array(index.issues.enumerated()), id: \.offset) { _, issue in
                        Button {
                            editor.navigate(to: issue)
                        } label: {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                IssueMark(severity: issue.severity, compact: true)
                                Text(AuthoringPresentation.location(of: issue))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Text(editor.message(for: issue))
                                    .font(.callout)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                        .accessibilityHint(Text("Chọn chỗ có vấn đề", bundle: .module))
                    }
                }
                .listStyle(.plain)
                // Đang chờ kiểm lại: vị trí trong danh sách có thể đã lệch; bấm một dòng thì kiểm ngay rồi mới nhảy.
                .opacity(editor.issuesAreCurrent ? 1 : 0.6)
                .frame(height: AuthoringStyle.bottomListHeight(
                    rows: index.issues.count,
                    sharing: editor.importReport != nil && editor.showsImportReport
                ))
                .accessibilityIdentifier("authoring.issues.list")
                Divider()
            }
            HStack(spacing: 12) {
                Button {
                    editor.isIssueListExpanded.toggle()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: editor.isIssueListExpanded ? "chevron.down" : "chevron.up")
                            .accessibilityHidden(true)
                        if let severity = IssueIndex.worstSeverity(index.issues) {
                            Image(systemName: AuthoringPresentation.severitySymbol(severity))
                                .foregroundStyle(AuthoringStyle.color(for: severity))
                                .accessibilityHidden(true)
                        } else {
                            Image(systemName: "checkmark.circle")
                                .accessibilityHidden(true)
                        }
                        Text(AuthoringPresentation.issueBarSummary(errors: index.errorCount, warnings: index.warningCount))
                    }
                }
                .buttonStyle(.borderless)
                .disabled(index.issues.isEmpty)
                .help(editor.isIssueListExpanded ? localized("Thu gọn danh sách lỗi") : localized("Mở danh sách lỗi"))
                .accessibilityIdentifier("authoring.issues.summary")
                if editor.isValidating {
                    ProgressView().controlSize(.small)
                    Text("Đang kiểm tra…", bundle: .module).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                if let rejection = editor.studentRejection {
                    Label {
                        Text("Bản Học viên sẽ từ chối đề này: \(rejection)", bundle: .module)
                            .lineLimit(2)
                    } icon: {
                        Image(systemName: "nosign")
                            .foregroundStyle(AuthoringStyle.critical)
                    }
                    .font(.callout.weight(.semibold))
                    .textSelection(.enabled)
                    .accessibilityIdentifier("authoring.issues.studentRejection")
                }
            }
            .font(.callout)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .adaptiveBackground(.bar)
    }
}

/// Xem trước (cột phải, `.inspector`): câu đang chọn hiển thị như cửa sổ làm bài (dùng `QuestionPreview` của
/// SessionFeature), công tắc Luyện tập / Thi; cập nhật ngay khi gõ. Chỉ đọc.
struct PreviewPane: View {
    @Bindable var editor: AuthoringEditor

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Picker(localized("Kiểu xem trước"), selection: $editor.previewMode) {
                Text("Luyện tập", bundle: .module).tag(PreviewMode.practice)
                Text("Thi", bundle: .module).tag(PreviewMode.exam)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(12)
            .accessibilityLabel(Text("Kiểu xem trước", bundle: .module))
            .accessibilityIdentifier("authoring.preview.mode")
            Divider()
            if let path = editor.selectedQuestionPath, let question = editor.question(at: path) {
                ScrollView {
                    QuestionPreview(
                        question: question,
                        sectionTitle: AuthoringPresentation.sectionTitle(editor.section(at: path.section)?.title ?? ""),
                        positionText: localized("Câu \(editor.outline.question(path)?.number ?? path.question + 1)/\(editor.outline.questionCount)"),
                        imageData: editor.imageData(for: question),
                        mode: editor.previewMode == .practice ? .practice : .exam
                    )
                    .padding(16)
                }
                // Nền đọc (menu Xem › Nền đọc): xem trước vẽ như vùng câu hỏi của cửa sổ làm bài.
                .readingSurface(systemTint: AuthoringStyle.accentForeground)
                .accessibilityIdentifier("authoring.preview")
            } else {
                ContentUnavailableView(localized("Chọn một câu để xem trước"), systemImage: "eye")
                    .frame(maxHeight: .infinity)
            }
        }
    }
}
