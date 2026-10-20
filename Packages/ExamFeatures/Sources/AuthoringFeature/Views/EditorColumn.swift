import AuthoringData
import ExamKit
import SwiftUI

/// Trình soạn (cột giữa): thuộc tính đề, thuộc tính phần, hoặc câu, theo dòng đang chọn trên cây đề.
struct EditorColumn: View {
    let editor: AuthoringEditor
    var focus: FocusState<AuthoringFocus?>.Binding

    var body: some View {
        Group {
            switch editor.selection {
            case .exam, nil:
                ExamPropertiesEditor(editor: editor, focus: focus)
            case let .section(index):
                if editor.section(at: index) != nil {
                    SectionEditor(editor: editor, index: index, focus: focus)
                } else {
                    placeholder
                }
            case let .question(path):
                if editor.question(at: path) != nil {
                    QuestionEditor(editor: editor, path: path, focus: focus)
                        .id(path)
                } else {
                    placeholder
                }
            }
        }
        // Không khai báo độ rộng tối thiểu (cửa sổ tối thiểu giữ trình soạn đủ rộng; AuthoringStyle): độ rộng tối thiểu
        // ở đây làm split view rộng hơn cửa sổ và cắt cột cây đề.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var placeholder: some View {
        ContentUnavailableView(localized("Chọn đề, phần hoặc câu trên cây đề"), systemImage: "list.bullet.indent")
    }
}

// MARK: - Thuộc tính đề

/// Tiêu đề, mã đề, ngưỡng đậu (%, kèm thang 1000), thời gian Thi mặc định, Ẩn đáp án, hướng dẫn (authoring.md, mục
/// Thuộc tính đề). Giá trị ngoài ràng buộc vẫn nhập được nhưng hiện lỗi ngay dưới ô.
struct ExamPropertiesEditor: View {
    let editor: AuthoringEditor
    var focus: FocusState<AuthoringFocus?>.Binding
    /// Locale của ngôn ngữ giao diện (gốc scene gắn `.interfaceLocale()`): ô số hiện và đọc số theo nó.
    @Environment(\.locale) private var locale

    var body: some View {
        let exam = editor.exam
        Form {
            Section(localized("Đề")) {
                TextField(localized("Tên đề"), text: Binding(get: { editor.exam.title }, set: { editor.setTitle($0) }))
                    .focused(focus, equals: .examTitle)
                    .accessibilityIdentifier("authoring.exam.title")
                FieldIssues(editor: editor, issues: editor.issues(for: .exam, field: .title))
                TextField(
                    localized("Mã đề"),
                    text: Binding(get: { editor.exam.code ?? "" }, set: { editor.setCode($0) }),
                    prompt: Text("Không bắt buộc", bundle: .module)
                )
                    .focused(focus, equals: .examCode)
                    .accessibilityIdentifier("authoring.exam.code")
                FieldIssues(editor: editor, issues: editor.issues(for: .exam, field: .code))
            }
            Section(localized("Làm bài")) {
                LabeledContent(localized("Ngưỡng đậu (%)")) {
                    HStack {
                        TextField(localized("Ngưỡng đậu (%)"), value: Binding(
                            get: { editor.exam.passPercent }, set: { editor.setPassPercent($0) }
                        ), format: .number.locale(locale))
                        .labelsHidden()
                        .frame(maxWidth: 80)
                        .focused(focus, equals: .passPercent)
                        .accessibilityIdentifier("authoring.exam.passPercent")
                        Text(AuthoringPresentation.passScale1000(exam.passPercent))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                FieldIssues(editor: editor, issues: editor.issues(for: .exam, field: .passPercent))
                LabeledContent(localized("Thời gian Thi (phút)")) {
                    TextField(localized("Thời gian Thi (phút)"), value: Binding(
                        get: { editor.exam.timeLimitMinutes }, set: { editor.setTimeLimitMinutes($0) }
                    ), format: .number.locale(locale))
                    .labelsHidden()
                    .frame(maxWidth: 80)
                    .focused(focus, equals: .timeLimit)
                    .accessibilityIdentifier("authoring.exam.timeLimit")
                }
                FieldIssues(editor: editor, issues: editor.issues(for: .exam, field: .timeLimitMinutes))
                Toggle(isOn: Binding(get: { editor.exam.hideAnswers }, set: { editor.setHideAnswers($0) })) {
                    Text("Ẩn đáp án", bundle: .module)
                    Text(
                        "Khoá Luyện tập; khi xem lại bài chỉ hiện đúng/sai, không hiện đáp án đúng và giải thích.",
                        bundle: .module
                    )
                }
                .focused(focus, equals: .hideAnswers)
                .accessibilityIdentifier("authoring.exam.hideAnswers")
            }
            Section {
                TextField(localized("Hướng dẫn"), text: Binding(
                    get: { editor.exam.instructions ?? "" }, set: { editor.setInstructions($0) }
                ),
                prompt: Text("Không bắt buộc. Markdown cơ bản: **đậm**, *nghiêng*, `mã`", bundle: .module),
                axis: .vertical)
                .labelsHidden()
                .lineLimit(3 ... 10)
                .focused(focus, equals: .instructions)
                .accessibilityLabel(Text("Hướng dẫn", bundle: .module))
                .accessibilityIdentifier("authoring.exam.instructions")
                FieldIssues(editor: editor, issues: editor.issues(for: .exam, field: .instructions))
            } header: {
                Text("Hướng dẫn", bundle: .module)
            }
            Section {
                LabeledContent(localized("Số phần"), value: "\(exam.sections.count)")
                LabeledContent(localized("Số câu"), value: "\(exam.questionCount)")
                FieldIssues(editor: editor, issues: editor.issues(for: .exam, field: .sections))
                Button(localized("Thêm phần")) { editor.addSection() }
                    .focused(focus, equals: .addSection)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Phần

/// Tên phần (trùng tên phần khác là cảnh báo), số câu, Thêm câu, Xoá phần (hỏi lại khi còn câu).
struct SectionEditor: View {
    let editor: AuthoringEditor
    let index: Int
    var focus: FocusState<AuthoringFocus?>.Binding

    var body: some View {
        let row = TreeRow.section(index: index)
        let section = editor.section(at: index)
        Form {
            Section(localized("Phần \(index + 1)")) {
                TextField(localized("Tên phần"), text: Binding(
                    get: { editor.section(at: index)?.title ?? "" }, set: { editor.renameSection(at: index, to: $0) }
                ))
                .focused(focus, equals: .sectionTitle)
                .accessibilityIdentifier("authoring.section.title")
                FieldIssues(editor: editor, issues: editor.issues(for: row, field: .title))
                LabeledContent(localized("Số câu"), value: "\(section?.questions.count ?? 0)")
                FieldIssues(editor: editor, issues: editor.issues(for: row, field: .questions))
            }
            DuplicateIDSection(editor: editor, row: row, focus: focus)
            Section {
                Button(localized("Thêm câu vào phần này")) {
                    editor.selection = row
                    editor.addQuestion()
                }
                .focused(focus, equals: .addQuestion)
                Button(localized("Xoá phần…"), role: .destructive) { editor.requestRemoveSection(at: index) }
            }
        }
        .formStyle(.grouped)
    }
}

/// Lỗi id trùng (đề đọc dễ): trình soạn không có ô id; nút **Cấp id mới** sửa đúng dòng này.
struct DuplicateIDSection: View {
    let editor: AuthoringEditor
    let row: TreeRow
    var focus: FocusState<AuthoringFocus?>.Binding

    var body: some View {
        let issues = editor.issues(for: row, field: .id)
        if !issues.isEmpty {
            Section(localized("Id trùng")) {
                FieldIssues(editor: editor, issues: issues)
                Text("Lịch sử thi theo id câu: câu được cấp id mới không còn nối với các lần thi cũ.", bundle: .module)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button(localized("Cấp id mới")) { editor.assignNewID(to: row) }
                    .focused(focus, equals: .newID)
            }
        }
    }
}
