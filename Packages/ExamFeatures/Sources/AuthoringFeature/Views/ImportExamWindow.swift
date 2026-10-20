import Accessibility
import AppKit
import ExamKit
import SwiftUI
import UniformTypeIdentifiers

/// Cửa sổ của **Import đề…** (docs/product/import.md, Luồng bước 2–3): tiến độ đọc file kèm **Huỷ**, rồi hộp thoại
/// xác nhận (tiêu đề, mã đề, ngưỡng đậu, thời gian Thi, tóm tắt) với **Import** / **Huỷ**. **Import** mở cửa sổ soạn
/// đề chưa lưu (`newDocument`), không ghi file nào.
///
/// `Window` (một bản duy nhất, mỗi lúc một lần import): không mở khi khởi động, không khôi phục khi mở lại app; không
/// có lần import nào thì cửa sổ tự đóng. Đóng cửa sổ (nút đóng, ⌘W) là **Huỷ**.
public struct ImportExamWindow: Scene {
    /// Id của scene (`openWindow(id:)`).
    public static let windowID = "authoring.import"

    private let model: ImportFlowModel

    public init(model: ImportFlowModel) {
        self.model = model
    }

    public var body: some Scene {
        Window(localized("Import đề"), id: Self.windowID) {
            ImportExamRoot(model: model)
        }
        // Cỡ cửa sổ theo cỡ nhỏ nhất và lớn nhất của nội dung: nội dung phải có cỡ nhỏ nhất bằng cỡ lý tưởng
        // (`fixedSize` dọc ở `ImportExamRoot`), không thì cửa sổ mở ở cỡ nhỏ nhất và vùng cuộn (`Form`) co về 0 (lỗi beta
        // G6.2).
        .windowResizability(.contentSize)
        .windowStyle(.titleBar)
        .defaultPosition(.center)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)
        .commandsRemoved()
    }
}

/// Nội dung cửa sổ Import đề theo `model.phase`.
struct ImportExamRoot: View {
    @Bindable var model: ImportFlowModel
    /// Cao đúng cỡ lý tưởng ở mọi bước (cỡ nhỏ nhất bằng cỡ lý tưởng; lỗi beta G6.2). Chỉ test đổi
    /// (`ContentSizedWindowTests`: `false` làm đối chứng âm, đo đúng view thật như trước khi sửa).
    var fitsIdealHeight = true

    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.newDocument) private var newDocument

    var body: some View {
        Group {
            switch model.phase {
            case .idle:
                Color.clear.frame(width: 1, height: 1)
            case .reading:
                ImportProgressView(model: model)
            case .confirming:
                ImportConfirmView(model: model) { imported in
                    newDocument { ExamAuthoringDocument(imported: imported) }
                }
            }
        }
        // Lỗi beta G6.2: cửa sổ `.contentSize` lấy cỡ nhỏ nhất và lớn nhất của nội dung làm giới hạn và mở ở cỡ nhỏ nhất.
        // Hộp xác nhận đặt bốn ô trong `Form` kiểu `.grouped` (vùng cuộn, cỡ nhỏ nhất gần như 0): cửa sổ cao ~170 pt,
        // `Form` co về cao 0 (bốn ô không thấy), dòng ghi chú bị cắt còn một dòng, **Import** khoá mà không điền được. Ép
        // cao đúng cỡ lý tưởng ở gốc (mọi bước: tiến độ, xác nhận): cỡ nhỏ nhất = lớn nhất = lý tưởng, cửa sổ vừa khít nội
        // dung kể cả khi mọi ô báo lỗi hay chữ tiếng Anh dài, và đổi cỡ theo khi dòng báo lỗi hiện/ẩn. Kiểm:
        // `ContentSizedWindowTests`, ảnh `importConfirmProblems*`, `ImportExamUITests`.
        .fixedSize(horizontal: false, vertical: fitsIdealHeight)
        .tint(AuthoringStyle.accentForeground)
        .onChange(of: model.phase, initial: true) { _, phase in
            // Xong (Import), huỷ, lỗi, hoặc cửa sổ mở lại khi không có lần import nào: đóng cửa sổ.
            if phase == .idle { dismissWindow(id: ImportExamWindow.windowID) }
        }
        .onDisappear {
            // Đóng cửa sổ bằng nút đóng hoặc ⌘W khi đang đọc/chờ xác nhận: như **Huỷ**.
            model.cancel()
        }
    }
}

/// Tiến độ đọc và chuyển đổi file, kèm **Huỷ** (Esc).
struct ImportProgressView: View {
    let model: ImportFlowModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Đang đọc “\(model.fileName)”…", bundle: .module)
                .font(.headline)
                .lineLimit(2)
                .truncationMode(.middle)
                .accessibilityAddTraits(.isHeader)
            ProgressView(value: model.progress)
                .progressViewStyle(.linear)
                .accessibilityLabel(Text("Tiến độ import", bundle: .module))
                .accessibilityValue(Text("\(Int((model.progress * 100).rounded())) phần trăm", bundle: .module))
                .accessibilityIdentifier("import.progress")
            HStack {
                Spacer()
                Button(localized("Huỷ"), role: .cancel) { model.cancel() }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("import.cancel")
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}

/// Hộp thoại xác nhận (import.md, Luồng bước 3).
struct ImportConfirmView: View {
    @Bindable var model: ImportFlowModel
    let open: (ImportedExam) -> Void

    @FocusState private var focusedField: ImportConfirmForm.Field?

    var body: some View {
        // Đọc `form` một lần cho lượt dựng này; các ô dùng binding an toàn của model (không ép mở `Binding($model.form)`),
        // vì sau Import/Huỷ `form` về nil trong khi ô có thể còn được cập nhật một lượt.
        if let form = model.form {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Import “\(model.fileName)”", bundle: .module)
                        .font(.headline)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .accessibilityAddTraits(.isHeader)
                    Text(form.summary.text)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("import.confirm.summary")
                }
                Form {
                    field(.title, label: localized("Tiêu đề"), identifier: "import.confirm.title")
                    field(.code, label: localized("Mã đề (tuỳ chọn)"), identifier: "import.confirm.code")
                    field(.passPercent, label: localized("Ngưỡng đậu (%)"), identifier: "import.confirm.passPercent")
                    field(.timeLimitMinutes, label: localized("Thời gian Thi (phút)"), identifier: "import.confirm.timeLimit")
                }
                .formStyle(.grouped)
                .scrollDisabled(true)
                Text("Đề mở trong cửa sổ soạn đề chưa lưu; xem, sửa rồi Lưu thành file .exam.", bundle: .module)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("import.confirm.note")
                HStack {
                    Spacer()
                    Button(localized("Huỷ"), role: .cancel) { model.cancel() }
                        .keyboardShortcut(.cancelAction)
                        .accessibilityIdentifier("import.confirm.cancel")
                    Button(localized("Import")) {
                        if let imported = model.confirm() {
                            open(imported)
                            // Cửa sổ soạn đề mới nhận tiêu điểm; câu đọc ưu tiên cao để không bị tên cửa sổ cắt ngang.
                            var text = AttributedString(imported.announcement)
                            text.accessibilitySpeechAnnouncementPriority = .high
                            AccessibilityNotification.Announcement(text).post()
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!form.canImport)
                    .accessibilityIdentifier("import.confirm.import")
                }
            }
            .padding(20)
            .frame(width: 480)
            .onAppear {
                // Tiêu điểm vào ô đầu tiên còn phải nhập (thường là ngưỡng đậu hoặc thời gian).
                focusedField = ImportConfirmForm.Field.allCases.first { form.problem($0) != nil } ?? .title
            }
        }
    }

    /// Độ rộng của ô (mọi dòng như nhau): đủ cho tiêu đề dài vừa phải, chừa chỗ cho nhãn tiếng Anh dài nhất xuống hai dòng.
    private static let fieldWidth: CGFloat = 200

    private func field(
        _ field: ImportConfirmForm.Field,
        label: String,
        identifier: String
    ) -> some View {
        let problem = model.form?.problem(field)
        let model = model
        let text = Binding(get: { model.text(of: field) }, set: { model.setText($0, of: field) })
        return VStack(alignment: .leading, spacing: 4) {
            // Ô có viền, chữ canh trái, cùng độ rộng ở mọi dòng (Nt0 chốt 2026-10-19, lỗi beta G6.2, review #60 S1): ô
            // chữ mặc định của `Form` `.grouped` không viền và canh phải, ô trống trông như không có ô. Không có chữ gợi ý.
            // Nhãn bên trái chiếm phần còn lại và xuống dòng khi dài (tiếng Anh), ô bên phải; xếp bằng `HStack` vì
            // `TextField` có nhãn hay `LabeledContent` trong `Form` `.grouped` đẩy ô xuống dòng riêng khi nhãn dài. Ô ẩn nhãn
            // nhưng vẫn mang nhãn cho trợ năng, nên chữ nhãn ẩn với VoiceOver (không đọc hai lần).
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(label)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityHidden(true)
                TextField(label, text: text)
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.leading)
                    .frame(width: Self.fieldWidth)
                    .focused($focusedField, equals: field)
                    .accessibilityIdentifier(identifier)
            }
            if let problem {
                Label {
                    Text(problem)
                } icon: {
                    Image(systemName: "exclamationmark.circle")
                }
                .font(.caption)
                .foregroundStyle(AuthoringStyle.critical)
                .accessibilityIdentifier("\(identifier).problem")
            }
        }
    }
}

// MARK: - AppKit: chọn file, báo lỗi

/// Hộp chọn file của **Import đề…**: một file `.txt`, `.docx` hoặc `.vce`.
@MainActor
public enum ImportFilePanel {
    /// Hiện hộp chọn file (modal); trả file đã chọn, `nil` nếu Huỷ.
    public static func chooseFile() -> URL? {
        let panel = NSOpenPanel()
        panel.title = localized("Import đề")
        panel.message = localized("Chọn một file .txt, .docx hoặc .vce để chuyển thành đề.")
        panel.prompt = localized("Chọn")
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = ImportFlowModel.selectableExtensions.compactMap { UTType(filenameExtension: $0) }
        panel.identifier = NSUserInterfaceItemIdentifier("import.openPanel")
        NSApp.activate()
        return panel.runModal() == .OK ? panel.url : nil
    }

    /// Hộp thông báo lỗi import (không mở cửa sổ soạn đề nào).
    public static func present(_ failure: ImportFailure) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = failure.title
        alert.informativeText = failure.message
        alert.addButton(withTitle: localized("OK"))
        NSApp.activate()
        alert.runModal()
    }
}
