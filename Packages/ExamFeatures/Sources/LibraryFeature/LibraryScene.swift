import LibraryData
import SwiftUI

/// Cửa sổ Thư viện của mỗi bản app (docs/product/library.md, mục Cửa sổ).
///
/// Dùng `Window` (một cửa sổ duy nhất) thay vì `WindowGroup`: không có mục "New Window"/⌘N, và
/// `openWindow(id:)` mở lại cửa sổ nếu đang đóng hoặc đưa nó lên trước nếu đang mở, không bao giờ tạo
/// cửa sổ thứ hai. Tối thiểu 960×640, co giãn được.
///
/// `decoration` là phần shell gắn thêm vào nội dung cửa sổ (sheet Trước khi thi, thông báo của phiên thi,
/// cách đóng cửa sổ của từng bản app), để LibraryFeature không phụ thuộc giao diện làm bài.
public struct LibraryWindow<Decoration: ViewModifier>: Scene {
    private let model: LibraryModel
    private let decoration: Decoration

    public init(model: LibraryModel, decoration: Decoration) {
        self.model = model
        self.decoration = decoration
    }

    public var body: some Scene {
        Window(localized("Thư viện"), id: LibraryModel.windowID) {
            LibraryRootView(model: model)
                .modifier(decoration)
        }
        .defaultSize(width: 1180, height: 760)
        .windowResizability(.contentMinSize)
        // Luôn mở Thư viện khi khởi động app, kể cả khi lần trước người dùng đã đóng cửa sổ.
        .defaultLaunchBehavior(.presented)
    }
}

extension LibraryWindow where Decoration == EmptyModifier {
    public init(model: LibraryModel) {
        self.init(model: model, decoration: EmptyModifier())
    }
}

struct LibraryCommandContextKey: FocusedValueKey {
    typealias Value = LibraryCommandContext
}

extension FocusedValues {
    /// Có giá trị khi cửa sổ Thư viện là cửa sổ đang dùng (`focusedSceneValue`).
    var libraryCommandContext: LibraryCommandContext? {
        get { self[LibraryCommandContextKey.self] }
        set { self[LibraryCommandContextKey.self] = newValue }
    }
}

/// Lệnh menu của Thư viện (docs/product/library.md, mục Bàn phím):
///
/// - **File > Thêm đề…** (⌘O): thay nhóm mục mở/tạo tài liệu mặc định, nên app chỉ có một mục ⌘O.
///   `documentItems` là các mục riêng của bản app đặt ngay sau (bản Admin: "Mở để sửa…" ⇧⌘O).
/// - **File > Thông tin** (⌘I), **Hiện trong Finder**, **Xem lịch sử thi**, **Sửa** (⌘E, bản Admin),
///   **Xoá khỏi thư viện**: tác động lên đề đang chọn, chỉ bật khi cửa sổ Thư viện đang được dùng
///   (`focusedSceneValue`). ⌫ không gắn ở menu (sẽ nuốt phím xoá chữ trong ô tìm kiếm): lưới và danh sách
///   nhận ⌫ bằng `onDeleteCommand` khi có tiêu điểm.
/// - **Sửa > Tìm** (⌘F, chỉ khi cửa sổ Thư viện đang dùng): đưa tiêu điểm vào ô tìm kiếm.
/// - **Trợ giúp > Khôi phục đề mẫu**.
///
/// Lệnh dùng `LibraryModel` truyền vào (một model cho cả app), không qua biến toàn cục.
public struct LibraryCommands<DocumentItems: View>: Commands {
    private let model: LibraryModel
    private let documentItems: DocumentItems

    @Environment(\.openWindow) private var openWindow
    @FocusedValue(\.libraryCommandContext) private var context

    public init(model: LibraryModel, @ViewBuilder documentItems: () -> DocumentItems) {
        self.model = model
        self.documentItems = documentItems()
    }

    public var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button(localized("Thêm đề…")) {
                model.requestAddExams()
                showLibrary()
            }
            .keyboardShortcut("o", modifiers: .command)
            documentItems
        }
        CommandGroup(after: .newItem) {
            Divider()
            Button(localized("Thông tin")) {
                if let examID = context?.selectedExamID { model.showInfo(examID) }
            }
            .keyboardShortcut("i", modifiers: .command)
            .disabled(context?.selectedExamID == nil)
            Button(localized("Hiện trong Finder")) {
                if let examID = context?.selectedExamID { model.revealInFinder(examID) }
            }
            .disabled(context?.canRevealSelection != true)
            Button(localized("Xem lịch sử thi")) {
                if let examID = context?.selectedExamID { model.showHistory(for: examID) }
            }
            .disabled(context?.selectedExamID == nil)
            if model.isAdmin {
                Button(localized("Sửa")) {
                    if let examID = context?.selectedExamID { model.requestEdit(examID) }
                }
                .keyboardShortcut("e", modifiers: .command)
                .disabled(context?.canEditSelection != true)
            }
            Button(localized("Xoá khỏi thư viện")) {
                if let examID = context?.selectedExamID { model.remove(examID) }
            }
            .disabled(context?.selectedExamID == nil)
        }
        CommandGroup(after: .textEditing) {
            // ⌘F chỉ gắn khi cửa sổ Thư viện đang dùng: mục tắt không giữ phím, để cửa sổ soạn đề (bản Admin) dùng
            // ⌘F cho ô tìm của cây đề.
            Button(localized("Tìm")) { model.requestSearchFocus() }
                .keyboardShortcut(context == nil ? nil : KeyboardShortcut("f", modifiers: .command))
                .disabled(context == nil)
        }
        CommandGroup(after: .help) {
            Button(localized("Khôi phục đề mẫu")) {
                showLibrary()
                model.restoreSamples()
            }
        }
    }

    private func showLibrary() {
        openWindow(id: LibraryModel.windowID)
    }
}

extension LibraryCommands where DocumentItems == EmptyView {
    /// Lệnh của bản Học viên (không có mục mở đề để sửa).
    public init(model: LibraryModel) {
        self.init(model: model) { EmptyView() }
    }
}
