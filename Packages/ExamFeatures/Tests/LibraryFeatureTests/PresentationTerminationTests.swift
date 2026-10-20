import AppKit
import ExamKit
import LibraryData
@testable import LibraryFeature
import SwiftUI
import Testing

/// Sheet không chặn app thoát (plan giai đoạn 5, Decisions 2026-10-17; `scripts/check_quit_sheets.py` kiểm mọi sheet có
/// gắn `presentationAllowsAppTermination()`). Test đọc `NSWindow.preventsApplicationTerminationWhenModal` của cửa sổ sheet
/// SwiftUI thật trên một `NSWindow`: AppKit đọc cờ này khi ⌘Q và khi nhận Apple event thoát (Dock, đăng xuất); YES thì
/// từ chối thoát ngay mà không hỏi app delegate. Không gọi `terminate` trong tiến trình test.
@MainActor
@Suite("Sheet không chặn thoát app", .serialized, .timeLimit(.minutes(1)))
struct PresentationTerminationTests {
    @Observable
    @MainActor
    final class SheetState {
        var shown = false
    }

    struct SheetHost<Content: View>: View {
        @Bindable var state: SheetState
        @ViewBuilder let content: () -> Content

        var body: some View {
            Color.clear
                .frame(width: 480, height: 360)
                .sheet(isPresented: $state.shown, content: content)
        }
    }

    @Test("Đối chứng: sheet SwiftUI không gắn gì thì chặn thoát app (mặc định của SwiftUI)")
    func defaultSheetPreventsTermination() async throws {
        let prevents = try await sheetPreventsTermination { Text(verbatim: "Sheet") }
        #expect(prevents == true, "đối chứng hỏng: sheet mặc định phải chặn thoát, nếu không test dưới đây không chứng minh gì")
    }

    @Test("presentationAllowsAppTermination(): sheet không chặn thoát app")
    func modifierAllowsTermination() async throws {
        let prevents = try await sheetPreventsTermination {
            Text(verbatim: "Sheet").presentationAllowsAppTermination()
        }
        #expect(prevents == false)
    }

    /// Nhánh của macOS 15.0–15.3 (chưa có modifier của SwiftUI) chạy được ở mọi bản macOS, nên test thẳng.
    @Test("macOS 15.0–15.3: TerminationAllowingSheetWindow đặt cờ của AppKit trên cửa sổ sheet")
    func fallbackAllowsTermination() async throws {
        let prevents = try await sheetPreventsTermination {
            Text(verbatim: "Sheet").background(TerminationAllowingSheetWindow())
        }
        #expect(prevents == false)
    }

    @Test("Thư viện: sheet Thông tin và danh sách file không thêm được không chặn thoát app")
    func librarySheetsAllowTermination() async throws {
        let workspace = try FeatureWorkspace()
        let model = workspace.makeModel()
        let exam = makeExam(title: "Đề thử")
        let file = try workspace.write(exam, to: "de-thu.exam")
        let garbage = try workspace.writeGarbage(to: "hong.exam")
        #expect(await model.addExamFile(file) == .added(examID: exam.id))
        let window = host(LibraryRootView(model: model).defaultAppStorage(workspace.defaults), width: 960, height: 640)
        defer { window.close() }

        model.infoExamID = exam.id
        #expect(await waitFor { window.attachedSheet != nil }, "sheet Thông tin phải hiện")
        #expect(window.attachedSheet?.preventsApplicationTerminationWhenModal == false)
        model.infoExamID = nil
        #expect(await waitFor { window.attachedSheet == nil })

        guard case .rejected = await model.addExamFile(garbage) else {
            Issue.record("file hỏng phải bị từ chối")
            return
        }
        #expect(await waitFor { window.attachedSheet != nil }, "danh sách file không thêm được phải hiện")
        #expect(window.attachedSheet?.preventsApplicationTerminationWhenModal == false)
        for prompt in model.prompts { model.dismissPrompt(prompt.id) }
        #expect(await waitFor { window.attachedSheet == nil })
    }

    /// Review độc lập PR #45 (L1): trước đây binding bỏ qua lệnh đóng (`set: { _ in }`), nên khi SwiftUI đóng sheet lúc
    /// thoát rồi thoát bị huỷ, sheet hiện lại. Nay đóng như mọi sheet khác: bỏ đúng lời nhắc đang hiện.
    @Test("Danh sách file không thêm được: SwiftUI đóng sheet (khi thoát) thì bỏ đúng lời nhắc đang hiện")
    func importProblemsBindingAcceptsDismissal() async throws {
        let workspace = try FeatureWorkspace()
        let model = workspace.makeModel()
        let first = try workspace.writeGarbage(to: "hong-1.exam")
        let second = try workspace.writeGarbage(to: "hong-2.exam")
        _ = await model.addExamFile(first)
        _ = await model.addExamFile(second)
        #expect(model.prompts.count == 2)
        let shown = try #require(LibraryPromptPresenter.problemsTarget(model.prompts.first))
        #expect(shown.problems.map(\.fileName) == ["hong-1.exam"])
        let binding = LibraryPromptPresenter.problemsBinding(shown, model: model)
        #expect(binding.wrappedValue?.id == shown.id)

        // SwiftUI đặt nil: bỏ lời nhắc đang hiện, lời nhắc sau còn nguyên (sẽ hiện tiếp).
        binding.wrappedValue = nil
        #expect(model.prompts.count == 1)
        #expect(!model.prompts.contains { $0.id == shown.id })
        // Gọi lại muộn (lời nhắc đã bỏ): không bỏ nhầm lời nhắc khác.
        binding.wrappedValue = nil
        #expect(model.prompts.count == 1)
        // Không có sheet: đặt nil không làm gì.
        LibraryPromptPresenter.problemsBinding(nil, model: model).wrappedValue = nil
        #expect(model.prompts.count == 1)
        // Đặt một giá trị khác nil (SwiftUI không làm, nhưng binding phải chịu được): không bỏ gì.
        let next = try #require(LibraryPromptPresenter.problemsTarget(model.prompts.first))
        LibraryPromptPresenter.problemsBinding(next, model: model).wrappedValue = next
        #expect(model.prompts.count == 1)
    }

    // MARK: - Hỗ trợ

    /// Mở một sheet SwiftUI thật trên cửa sổ, đọc cờ của cửa sổ sheet, rồi đóng sheet và cửa sổ.
    private func sheetPreventsTermination<C: View>(@ViewBuilder _ content: @escaping () -> C) async throws -> Bool {
        let state = SheetState()
        let window = host(SheetHost(state: state, content: content), width: 480, height: 360)
        defer { window.close() }
        state.shown = true
        #expect(await waitFor { window.attachedSheet != nil }, "sheet phải hiện")
        let sheet = try #require(window.attachedSheet)
        #expect(!(sheet is NSPanel), "sheet SwiftUI là cửa sổ thường, không phải panel của AppKit")
        let prevents = sheet.preventsApplicationTerminationWhenModal
        state.shown = false
        #expect(await waitFor { window.attachedSheet == nil })
        return prevents
    }

    private func host<V: View>(_ view: V, width: CGFloat, height: CGFloat) -> NSWindow {
        _ = NSApplication.shared
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: view)
        window.orderFrontRegardless()
        return window
    }

    /// Chờ điều kiện (tối đa 3 giây) trên main actor.
    private func waitFor(_ condition: () -> Bool) async -> Bool {
        for _ in 0 ..< 150 {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return condition()
    }
}
