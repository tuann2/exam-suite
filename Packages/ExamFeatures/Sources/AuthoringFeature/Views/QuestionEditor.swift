import AppKit
import AuthoringData
import ExamKit
import SwiftUI

/// Trình soạn câu (authoring.md, mục Phần và câu, Ảnh): loại Một/Nhiều đáp án, nội dung (Markdown cơ bản), ảnh
/// (chọn file hoặc kéo thả vào trình soạn), lựa chọn, giải thích.
///
/// Ô chữ nhiều dòng là `TextField(axis: .vertical)` (⌥↩ xuống dòng): trình soạn chữ của ô tự bỏ các bước Hoàn tác
/// riêng của nó khi rời ô, nên ⌘Z sau khi gõ là Hoàn tác của đề (gộp theo đoạn gõ).
struct QuestionEditor: View {
    let editor: AuthoringEditor
    let path: QuestionPath
    var focus: FocusState<AuthoringFocus?>.Binding

    @State private var isPickingImage = false
    @State private var isDropTargeted = false

    var body: some View {
        if let question = editor.question(at: path) {
            let row = TreeRow.question(path)
            let number = editor.outline.question(path)?.number ?? path.question + 1
            Form {
                Section {
                    Picker(localized("Loại câu"), selection: Binding(
                        get: { editor.question(at: path)?.type ?? .single },
                        set: { editor.setQuestionType(at: path, $0) }
                    )) {
                        Text("Một đáp án", bundle: .module).tag(QuestionType.single)
                        Text("Nhiều đáp án", bundle: .module).tag(QuestionType.multiple)
                    }
                    .pickerStyle(.segmented)
                    .focused(focus, equals: .questionType)
                    .accessibilityIdentifier("authoring.question.type")
                    TextField(localized("Nội dung câu"), text: Binding(
                        get: { editor.question(at: path)?.text ?? "" },
                        set: { editor.setQuestionText(at: path, $0) }
                    ),
                    prompt: Text("Nội dung câu hỏi. Markdown cơ bản: **đậm**, *nghiêng*, `mã`", bundle: .module),
                    axis: .vertical)
                    .labelsHidden()
                    .lineLimit(3 ... 12)
                    .focused(focus, equals: .questionText)
                    .accessibilityLabel(Text("Nội dung câu", bundle: .module))
                    .accessibilityIdentifier("authoring.question.text")
                    FieldIssues(editor: editor, issues: editor.issues(for: row, field: .text))
                } header: {
                    Text("Câu \(number) · \(AuthoringPresentation.sectionTitle(editor.section(at: path.section)?.title ?? ""))", bundle: .module)
                }

                ImageSection(
                    editor: editor, path: path, question: question, isPickingImage: $isPickingImage, focus: focus
                )

                OptionListSection(editor: editor, path: path, question: question, focus: focus)

                Section(localized("Giải thích")) {
                    TextField(localized("Giải thích"), text: Binding(
                        get: { editor.question(at: path)?.explanation ?? "" },
                        set: { editor.setExplanation(at: path, $0) }
                    ),
                    prompt: Text("Không bắt buộc. Hiện sau Kiểm tra đáp án và khi xem lại bài.", bundle: .module),
                    axis: .vertical)
                    .labelsHidden()
                    .lineLimit(2 ... 10)
                    .focused(focus, equals: .explanation)
                    .accessibilityLabel(Text("Giải thích", bundle: .module))
                    .accessibilityIdentifier("authoring.question.explanation")
                    FieldIssues(editor: editor, issues: editor.issues(for: row, field: .explanation))
                }

                DuplicateIDSection(editor: editor, row: row, focus: focus)
            }
            .formStyle(.grouped)
            .fileImporter(isPresented: $isPickingImage, allowedContentTypes: ImageFileLoader.contentTypes) { result in
                guard case let .success(url) = result else { return }
                Task { await editor.importImage(from: url, to: path) }
            }
            .dropDestination(for: URL.self) { urls, _ in
                guard let url = urls.first else { return false }
                Task { await editor.importImage(from: url, to: path) }
                return true
            } isTargeted: { isDropTargeted = $0 }
            .overlay {
                if isDropTargeted {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(AuthoringStyle.accentForeground, style: StrokeStyle(lineWidth: 3, dash: [8, 6]))
                        .padding(6)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
        }
    }
}

/// Ảnh của câu: xem nhỏ, **Thêm/Thay ảnh…**, **Xoá ảnh**; báo ảnh thiếu trong gói.
private struct ImageSection: View {
    let editor: AuthoringEditor
    let path: QuestionPath
    let question: Question
    @Binding var isPickingImage: Bool
    var focus: FocusState<AuthoringFocus?>.Binding

    @Environment(\.authoringHooks) private var hooks

    var body: some View {
        Section(localized("Ảnh")) {
            if let data = editor.imageData(for: question) {
                ImageThumbnail(data: data)
            } else if let message = editor.missingImageMessage(for: question) {
                Label(message, systemImage: "photo.badge.exclamationmark")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            FieldIssues(editor: editor, issues: editor.issues(for: .question(path), field: .image))
            HStack {
                Button(question.image == nil ? localized("Thêm ảnh…") : localized("Thay ảnh…")) { chooseImage() }
                    .focused(focus, equals: .image)
                    .accessibilityIdentifier("authoring.question.image.choose")
                if question.image != nil {
                    Button(localized("Xoá ảnh")) { editor.removeImage(of: path) }
                        .accessibilityIdentifier("authoring.question.image.remove")
                }
                Spacer()
                Text("png, jpg, gif, webp, heic; hoặc kéo thả file ảnh vào đây", bundle: .module)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

extension ImageSection {
    /// **Thêm/Thay ảnh…**: hộp chọn file của macOS. Riêng UI test (build Debug, chế độ cô lập) dùng file shell đưa qua
    /// `AuthoringHooks.uiTestChooseImageFile` (kiểm lại file ngay lúc gọi), như khi người dùng chọn đúng file đó.
    private func chooseImage() {
        #if DEBUG
        if let choose = hooks.uiTestChooseImageFile {
            if let url = choose() {
                Task { await editor.importImage(from: url, to: path) }
            } else {
                NSSound.beep()
            }
            return
        }
        #endif
        isPickingImage = true
    }
}

private struct ImageThumbnail: View {
    let data: Data
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 360, maxHeight: 180, alignment: .leading)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    // Nhãn chung của ảnh câu hỏi (accessibility-localization.md, VoiceOver: "Ảnh của câu hỏi"; đề v1 không có
                    // chữ thay thế cho ảnh).
                    .accessibilityLabel(Text("Ảnh của câu hỏi", bundle: .module))
            } else {
                Label(localized("Không hiện được ảnh này"), systemImage: "photo.badge.exclamationmark")
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: data) { image = NSImage(data: data) }
    }
}

// MARK: - Lựa chọn

/// Danh sách lựa chọn: chữ cái theo vị trí, ô chữ, nút đánh dấu đúng (radio khi một đáp án, ô đánh dấu khi nhiều
/// đáp án), nút xoá; kéo thả để sắp xếp (và Lên trên/Xuống dưới trong menu chuột phải, hành động trợ năng);
/// **Thêm lựa chọn** (⌥⌘↩). Giữ bố cục với 8+ lựa chọn (mỗi lựa chọn một hàng của danh sách cuộn).
private struct OptionListSection: View {
    let editor: AuthoringEditor
    let path: QuestionPath
    let question: Question
    var focus: FocusState<AuthoringFocus?>.Binding

    var body: some View {
        let row = TreeRow.question(path)
        Section {
            ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                OptionRowEditor(
                    editor: editor, path: path, index: index, option: option,
                    count: question.options.count,
                    isMultiple: question.type == .multiple,
                    isCorrect: question.correctSet.contains(option.id),
                    focus: focus
                )
            }
            .onMove { source, destination in
                editor.moveOptions(of: path, fromOffsets: source, toOffset: destination)
            }
            FieldIssues(editor: editor, issues: editor.issues(for: row, field: .options) + editor.issues(for: row, field: .correct))
            Button {
                editor.addOption(to: path)
            } label: {
                Label(localized("Thêm lựa chọn"), systemImage: "plus.circle")
            }
            .disabled(question.options.count >= ExamValidator.Limits.optionCount.upperBound)
            .help(Text("Thêm lựa chọn (⌥⌘↩)", bundle: .module))
            .focused(focus, equals: .addOption)
            .accessibilityIdentifier("authoring.option.add")
        } header: {
            Text(question.type == .multiple
                    ? localized("Lựa chọn (đánh dấu mọi đáp án đúng)")
                    : localized("Lựa chọn (đánh dấu một đáp án đúng)"))
        }
    }
}

private struct OptionRowEditor: View {
    let editor: AuthoringEditor
    let path: QuestionPath
    let index: Int
    let option: Option
    let count: Int
    let isMultiple: Bool
    let isCorrect: Bool
    var focus: FocusState<AuthoringFocus?>.Binding

    private var letter: String { OptionID(index: index)?.description ?? option.id.description }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(.tertiary)
                    .help(Text("Kéo để sắp xếp", bundle: .module))
                    .accessibilityHidden(true)
                Text(letter)
                    .font(.body.weight(.semibold).monospaced())
                    .frame(minWidth: 18, alignment: .leading)
                    .accessibilityHidden(true)
                TextField(localized("Lựa chọn \(letter)"), text: Binding(
                    get: { editor.question(at: path)?.options[safe: index]?.text ?? "" },
                    set: { editor.setOptionText(of: path, at: index, $0) }
                ), axis: .vertical)
                .labelsHidden()
                .lineLimit(1 ... 6)
                .focused(focus, equals: .optionText(index))
                .accessibilityLabel(Text("Lựa chọn \(letter)", bundle: .module))
                .accessibilityIdentifier("authoring.option.\(index).text")
                correctControl
                Button {
                    editor.removeOption(of: path, at: index)
                } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.borderless)
                .help(Text("Xoá lựa chọn \(letter)", bundle: .module))
                .accessibilityLabel(Text("Xoá lựa chọn \(letter)", bundle: .module))
                .accessibilityIdentifier("authoring.option.\(index).remove")
            }
            FieldIssues(editor: editor, issues: editor.issues(for: .question(path), option: index))
        }
        .contextMenu {
            Button(localized("Lên trên")) { editor.moveOption(of: path, at: index, by: -1) }
                .disabled(index == 0)
            Button(localized("Xuống dưới")) { editor.moveOption(of: path, at: index, by: 1) }
                .disabled(index >= count - 1)
            Divider()
            Button(localized("Xoá lựa chọn \(letter)"), role: .destructive) { editor.removeOption(of: path, at: index) }
        }
        .accessibilityAction(named: Text("Lên trên", bundle: .module)) {
            editor.moveOption(of: path, at: index, by: -1)
        }
        .accessibilityAction(named: Text("Xuống dưới", bundle: .module)) {
            editor.moveOption(of: path, at: index, by: 1)
        }
    }

    @ViewBuilder
    private var correctControl: some View {
        if isMultiple {
            Toggle(
                localized("Đúng"),
                isOn: Binding(get: { isCorrect }, set: { editor.setCorrect(of: path, at: index, $0) })
            )
                .toggleStyle(.checkbox)
                .focused(focus, equals: .optionCorrect(index))
                .accessibilityLabel(Text("Lựa chọn \(letter) là đáp án đúng", bundle: .module))
                .accessibilityIdentifier("authoring.option.\(index).correct")
        } else {
            Button {
                editor.setCorrect(of: path, at: index, !isCorrect)
            } label: {
                Label(localized("Đúng"), systemImage: isCorrect ? "largecircle.fill.circle" : "circle")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(isCorrect ? AuthoringStyle.accentForeground : .secondary)
            .focused(focus, equals: .optionCorrect(index))
            .accessibilityLabel(Text("Lựa chọn \(letter) là đáp án đúng", bundle: .module))
            .accessibilityValue(isCorrect ? localized("Đã chọn") : localized("Chưa chọn"))
            .accessibilityAddTraits(isCorrect ? [.isSelected] : [])
            .accessibilityIdentifier("authoring.option.\(index).correct")
        }
    }
}
