import LibraryData
import SwiftUI

/// Hành động trên một đề, dùng chung cho thẻ, dòng bảng, menu chuột phải, nút "…", sheet Thông tin
/// và hành động trợ năng (docs/product/library.md, mục Thẻ đề).
@MainActor
struct ExamActions {
    let entry: LibraryEntry
    let presentation: EntryStatusPresentation
    let isAdmin: Bool
    let canReveal: Bool
    let canEdit: Bool
    /// Đề Sẵn sàng: **Luyện tập**, **Thi**, nhấp đúp và Return mở Trước khi thi (exam-taking.md, phương án 5).
    let canStartSession: Bool
    /// Nhấp đúp, Return: Trước khi thi với chế độ lần trước.
    let open: () -> Void
    let startPractice: () -> Void
    let startExam: () -> Void
    let showInfo: () -> Void
    let revealInFinder: () -> Void
    let showHistory: () -> Void
    let locate: () -> Void
    let remove: () -> Void
    let edit: () -> Void

    init(entry: LibraryEntry, model: LibraryModel) {
        let examID = entry.examID
        self.entry = entry
        presentation = EntryStatusPresentation(status: entry.status, isAdmin: model.isAdmin)
        isAdmin = model.isAdmin
        canReveal = entry.status != .missing
        canEdit = model.canEdit(entry)
        canStartSession = model.canStartSession(entry)
        open = { model.startSession(examID) }
        startPractice = { model.startSession(examID, mode: .practice) }
        startExam = { model.startSession(examID, mode: .exam) }
        showInfo = { model.showInfo(examID) }
        revealInFinder = { model.revealInFinder(examID) }
        showHistory = { model.showHistory(for: examID) }
        locate = { model.requestLocate(examID) }
        remove = { model.remove(examID) }
        edit = { model.requestEdit(examID) }
    }

    /// Hành động không làm gì, cho ảnh xem trước của thẻ.
    init(previewing entry: LibraryEntry, isAdmin: Bool) {
        self.entry = entry
        presentation = EntryStatusPresentation(status: entry.status, isAdmin: isAdmin)
        self.isAdmin = isAdmin
        canReveal = entry.status != .missing
        canEdit = isAdmin
        canStartSession = entry.status == .ready
        open = {}
        startPractice = {}
        startExam = {}
        showInfo = {}
        revealInFinder = {}
        showHistory = {}
        locate = {}
        remove = {}
        edit = {}
    }

    var canLocate: Bool {
        presentation.nextSteps.contains(.locateFile)
    }

    /// Một hành động trợ năng của thẻ.
    struct AccessibilityAction {
        let title: String
        let perform: () -> Void
    }

    /// Hành động trợ năng của thẻ (VoiceOver: VO-⌘-Space), tương ứng menu chuột phải (`ExamMenuItems`): mục bị tắt ở menu
    /// thì không có ở đây (Luyện tập, Thi khi đề chưa Sẵn sàng; Hiện trong Finder khi mất file; Sửa khi không sửa được).
    var accessibilityActions: [AccessibilityAction] {
        var list: [AccessibilityAction] = []
        if canStartSession {
            list.append(AccessibilityAction(title: localized("Luyện tập"), perform: startPractice))
            list.append(AccessibilityAction(title: localized("Thi"), perform: startExam))
        }
        list.append(AccessibilityAction(title: localized("Thông tin"), perform: showInfo))
        if canReveal {
            list.append(AccessibilityAction(title: localized("Hiện trong Finder"), perform: revealInFinder))
        }
        list.append(AccessibilityAction(title: localized("Xem lịch sử thi"), perform: showHistory))
        if canLocate {
            list.append(AccessibilityAction(title: localized("Tìm file…"), perform: locate))
        }
        if isAdmin, canEdit {
            list.append(AccessibilityAction(title: localized("Sửa"), perform: edit))
        }
        list.append(AccessibilityAction(title: localized("Xoá khỏi thư viện"), perform: remove))
        return list
    }
}

/// Mục của menu chuột phải và nút "…": **Luyện tập**, **Thi** (tắt khi đề chưa Sẵn sàng), **Thông tin** (⌘I), **Hiện trong Finder**, **Xem lịch sử thi**,
/// **Xoá khỏi thư viện** (⌫); bản Admin thêm **Sửa** (⌘E). Đề mất file thêm **Tìm file…**.
///
/// Phím tắt chỉ để hiện trong menu chuột phải (`showsShortcuts`): phím thật nằm ở menu File (⌘I, ⌘E) và
/// `onDeleteCommand` (⌫). Nút "…" của mỗi thẻ không gắn phím, vì menu của nút bật lên vẫn nhận phím tắt khi
/// đóng và sẽ tác động lên thẻ đầu tiên thay vì đề đang chọn.
struct ExamMenuItems: View {
    let actions: ExamActions
    let showsShortcuts: Bool

    var body: some View {
        Button(localized("Luyện tập"), systemImage: "pencil.and.list.clipboard") { actions.startPractice() }
            .disabled(!actions.canStartSession)
        Button(localized("Thi"), systemImage: "timer") { actions.startExam() }
            .disabled(!actions.canStartSession)
        Divider()
        Button(localized("Thông tin"), systemImage: "info.circle") { actions.showInfo() }
            .keyboardShortcut(showsShortcuts ? KeyboardShortcut("i", modifiers: .command) : nil)
        Button(localized("Hiện trong Finder"), systemImage: "folder") { actions.revealInFinder() }
            .disabled(!actions.canReveal)
        Button(localized("Xem lịch sử thi"), systemImage: "list.bullet.rectangle") { actions.showHistory() }
        if actions.canLocate {
            Button(localized("Tìm file…"), systemImage: "magnifyingglass") { actions.locate() }
        }
        if actions.isAdmin {
            Button(localized("Sửa"), systemImage: "pencil") { actions.edit() }
                .keyboardShortcut(showsShortcuts ? KeyboardShortcut("e", modifiers: .command) : nil)
                .disabled(!actions.canEdit)
        }
        Divider()
        Button(localized("Xoá khỏi thư viện"), systemImage: "trash", role: .destructive) { actions.remove() }
            .keyboardShortcut(showsShortcuts ? KeyboardShortcut(.delete, modifiers: []) : nil)
    }
}

/// Hành động trợ năng của một thẻ, tương ứng menu chuột phải (`ExamActions.accessibilityActions`, có test).
struct ExamAccessibilityActions: View {
    let actions: ExamActions

    var body: some View {
        ForEach(Array(actions.accessibilityActions.enumerated()), id: \.offset) { _, action in
            Button(action.title, action: action.perform)
        }
    }
}

/// Nút cho các bước tiếp theo của trạng thái (Tìm file…, Xoá khỏi thư viện, Sửa) và lời nhắc cập nhật app.
struct NextStepButtons: View {
    let actions: ExamActions

    var body: some View {
        let steps = actions.presentation.nextSteps
        if !steps.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                if steps.contains(.updateApp) {
                    Text(EntryStatusPresentation.updateAppHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 8) {
                    ForEach(steps.filter { $0 != .updateApp }, id: \.self) { step in
                        button(for: step)
                    }
                }
                .controlSize(.small)
                .buttonStyle(.bordered)
            }
        }
    }

    @ViewBuilder
    private func button(for step: EntryNextStep) -> some View {
        switch step {
        case .locateFile:
            Button(localized("Tìm file…")) { actions.locate() }
        case .removeFromLibrary:
            Button(localized("Xoá khỏi thư viện")) { actions.remove() }
        case .edit:
            if actions.isAdmin {
                Button(localized("Sửa")) { actions.edit() }
                    .disabled(!actions.canEdit)
            }
        case .updateApp:
            EmptyView()
        }
    }
}
