import AppKit
import AuthoringData
@testable import AuthoringFeature
import ExamImport
import SwiftUI
import Testing

/// Cửa sổ soạn đề (authoring.md, mục Cửa sổ): ba cột (cây đề, trình soạn, xem trước) phải nằm trọn trong cửa sổ ở cỡ
/// tối thiểu 960×640 và ở cỡ mặc định của cửa sổ mới, xem trước đang mở. UI test PR #42: dòng Đề của cây đề nằm ở
/// x = −16,5 (cột cây đề bị đẩy ra ngoài mép trái) vì tổng độ rộng lý tưởng của các cột (~1.448 pt) lớn hơn cửa sổ.
///
/// Dựng `AuthoringWindow` trong `NSHostingView` làm nội dung của một `NSWindow` không lên màn hình, rồi đo khung các
/// ô của `NSSplitView` do SwiftUI tạo.
@Suite("Cửa sổ soạn đề: ba cột vừa cửa sổ ở cỡ tối thiểu và cỡ mặc định")
@MainActor
struct WindowLayoutTests {
    /// Khung (trong toạ độ nội dung cửa sổ) của mọi ô đang hiện của mọi `NSSplitView` trong cửa sổ, và độ rộng nội dung.
    private func paneFrames(contentSize size: CGSize) async throws -> (content: CGFloat, panes: [NSRect], window: NSWindow) {
        let document = ExamAuthoringDocument()
        let host = NSHostingView(rootView: AuthoringWindow(document: document))
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.setContentSize(size)
        for _ in 0 ..< 6 {
            host.layoutSubtreeIfNeeded()
            window.layoutIfNeeded()
            await Task.yield()
            try await Task.sleep(for: .milliseconds(20))
        }
        let content = try #require(window.contentView)
        var panes: [NSRect] = []
        func visit(_ view: NSView) {
            if let split = view as? NSSplitView {
                for pane in split.arrangedSubviews where !pane.isHidden && pane.frame.width > 1 {
                    panes.append(pane.convert(pane.bounds, to: content))
                }
            }
            view.subviews.forEach(visit)
        }
        visit(content)
        return (content.bounds.width, panes, window)
    }

    @Test(
        "Mọi cột nằm trọn trong cửa sổ (cỡ tối thiểu, cỡ mặc định), cột cây đề và xem trước không bị co dưới tối thiểu",
        arguments: [AuthoringStyle.minWindowSize, AuthoringStyle.defaultWindowSize]
    )
    func columnsFitWindow(size: CGSize) async throws {
        let (width, panes, window) = try await paneFrames(contentSize: size)
        defer { window.close() }
        #expect(width <= size.width + 0.5, "nội dung rộng \(width) > cửa sổ \(size.width): cột bị đẩy ra ngoài")
        #expect(panes.count >= 3, "phải thấy cây đề, trình soạn và xem trước: \(panes)")
        for pane in panes {
            #expect(pane.minX >= -0.5, "cột bắt đầu ngoài mép trái: \(pane) trong \(width)")
            #expect(pane.maxX <= width + 0.5, "cột vượt mép phải: \(pane) trong \(width)")
        }
        // Cột cây đề: ô hẹp nhất bắt đầu ở mép trái; xem trước: ô bắt đầu xa nhất bên phải (nội dung cột giữa kéo dài
        // dưới hai cột bên nên có ô rộng bằng cả cửa sổ).
        let tree = try #require(panes.filter { $0.minX < 1 }.min { $0.width < $1.width })
        let preview = try #require(panes.max { $0.minX < $1.minX })
        #expect(tree.width >= AuthoringStyle.treeColumnWidth.min - 0.5, "cột cây đề \(tree)")
        #expect(preview.width >= AuthoringStyle.previewColumnWidth.min - 0.5, "cột xem trước \(preview)")
        // Trình soạn (giữa hai cột bên) đủ rộng.
        #expect(preview.minX - tree.maxX >= 300, "trình soạn chỉ còn \(preview.minX - tree.maxX) pt")
    }

    @Test("Ngân sách độ rộng: lý tưởng vừa cửa sổ tối thiểu; kéo cây đề và xem trước hết cỡ vẫn vừa và trình soạn ≥ 300 pt")
    func columnBudget() {
        let tree = AuthoringStyle.treeColumnWidth
        let preview = AuthoringStyle.previewColumnWidth
        let extra = AuthoringStyle.sidebarExtra
        let window = AuthoringStyle.minWindowSize.width
        #expect(tree.ideal + extra + AuthoringStyle.editorIdealWidth + preview.ideal <= window)
        // Độ rộng tối thiểu split view tự tính (cây đề tính hai lần, xem trước một lần, cột giữa 0) ở cỡ hết cỡ.
        #expect(2 * (tree.max + extra) + preview.max <= window)
        #expect(AuthoringStyle.editorMinimumAtMinWindow >= 300)
        #expect(AuthoringStyle.defaultWindowSize.width >= window)
        #expect(AuthoringStyle.defaultWindowSize.height >= AuthoringStyle.minWindowSize.height)
    }

    // MARK: - Đáy cột giữa: danh sách lỗi, báo cáo import

    /// Dựng cửa sổ cho `document`, trả khung (toạ độ của `NSHostingView`) của mọi `NSScrollView`: danh sách (`List`) và
    /// vùng cuộn khác (Form của trình soạn, xem trước).
    private func scrollViewFrames(
        _ document: ExamAuthoringDocument, contentSize size: CGSize
    ) async throws -> (lists: [NSRect], others: [(frame: NSRect, visibleHeight: CGFloat)], window: NSWindow) {
        let host = NSHostingView(rootView: AuthoringWindow(document: document))
        // Như cửa sổ SwiftUI thật: nội dung kéo dài dưới thanh công cụ (thanh công cụ của AuthoringWindow được SwiftUI
        // gắn vào cửa sổ qua NSHostingView).
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView, .unifiedTitleAndToolbar],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.setContentSize(size)
        for _ in 0 ..< 6 {
            host.layoutSubtreeIfNeeded()
            window.layoutIfNeeded()
            await Task.yield()
            try await Task.sleep(for: .milliseconds(20))
        }
        var lists: [NSRect] = []
        var others: [(frame: NSRect, visibleHeight: CGFloat)] = []
        func visit(_ view: NSView, insideScrollView: Bool) {
            var inside = insideScrollView
            if let scroll = view as? NSScrollView, !insideScrollView, scroll.frame.width > 1, scroll.frame.height > 1 {
                let frame = scroll.convert(scroll.bounds, to: host)
                if String(describing: type(of: scroll)).contains("List") {
                    lists.append(frame)
                } else {
                    // Phần nhìn thấy: trừ phần nằm dưới thanh công cụ/thanh tiêu đề (content insets).
                    let insets = scroll.contentView.contentInsets
                    others.append((frame, frame.height - insets.top - insets.bottom))
                }
                inside = true
            }
            view.subviews.forEach { visit($0, insideScrollView: inside) }
        }
        visit(host, insideScrollView: false)
        return (lists, others, window)
    }

    /// Đề import có báo cáo `reportRows` dòng và `errors` lỗi (phần trống), danh sách lỗi mở.
    private func importedDocumentWithIssues(reportRows: Int = 3, errors: Int = 1) throws -> ExamAuthoringDocument {
        var draft = ExamDraft.newExam()
        for _ in 1 ..< errors { _ = try draft.addSection(at: draft.exam.sections.count) }
        let entries = (1 ... reportRows).map { number in
            ImportReportEntry(code: .unrecognizedText, location: ImportLocation(questionNumber: number, line: number * 5),
                              questionID: nil, detail: .textAfterAnswerLine)
        }
        let document = ExamAuthoringDocument(imported: ImportedExam(
            draft: draft,
            report: ImportReportState(fileName: "de.txt", report: ExamImport.ImportReport(entries: entries))
        ))
        document.editor.validateNow()
        document.editor.isIssueListExpanded = true
        return document
    }

    @Test(
        "Danh sách lỗi và báo cáo import nằm dưới trình soạn, không chồng lên vùng cuộn nào; trình soạn còn chỗ",
        arguments: [AuthoringStyle.minWindowSize, AuthoringStyle.defaultWindowSize]
    )
    func bottomListsDoNotOverlapEditor(size: CGSize) async throws {
        try await checkBottomLists(try importedDocumentWithIssues(), size: size, minimumEditorHeight: 200)
    }

    /// Trường hợp xấu nhất (review lại PR #42): báo cáo 8 dòng và 8 lỗi, cả hai danh sách mở ở cửa sổ tối thiểu, thanh
    /// công cụ thật: hai danh sách cùng có trần thấp hơn (`bottomListSharedMaxHeight`), trình soạn còn ≥ 240 pt nhìn thấy.
    @Test("Báo cáo 8 dòng + 8 lỗi ở 960×640: hai danh sách cùng có trần, trình soạn còn ≥ 240 pt")
    func bothBottomListsFullAtMinimumSize() async throws {
        let document = try importedDocumentWithIssues(reportRows: 8, errors: 8)
        #expect(document.editor.issues.errorCount >= 8)
        try await checkBottomLists(document, size: AuthoringStyle.minWindowSize, minimumEditorHeight: 240)
    }

    private func checkBottomLists(
        _ document: ExamAuthoringDocument, size: CGSize, minimumEditorHeight: CGFloat
    ) async throws {
        #expect(document.editor.importReport != nil && document.editor.showsImportReport)
        #expect(!document.editor.issues.issues.isEmpty, "đề phải có lỗi (phần trống) để danh sách lỗi hiện")
        let (lists, others, window) = try await scrollViewFrames(document, contentSize: size)
        defer { window.close() }
        // Danh sách ở đáy cột giữa: thấp (cây đề là danh sách cao cả cột).
        let bottomLists = lists.filter { $0.height <= AuthoringStyle.bottomListMaxHeight + 1 }
        #expect(bottomLists.count == 2, "phải thấy danh sách lỗi và báo cáo import: \(lists)")
        let editor = try #require(
            others.max { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }, "không thấy Form của trình soạn"
        )
        for list in bottomLists {
            for other in others.map(\.frame) where other.minX < list.maxX && list.minX < other.maxX {
                let overlap = min(list.maxY, other.maxY) - max(list.minY, other.minY)
                #expect(overlap <= 0.5, "danh sách \(list) chồng lên vùng cuộn \(other) \(overlap) pt")
            }
        }
        #expect(
            editor.visibleHeight >= minimumEditorHeight,
            "trình soạn chỉ còn \(editor.visibleHeight) pt nhìn thấy (khung \(editor.frame), danh sách \(bottomLists))"
        )
    }

    @Test("Chiều cao danh sách ở đáy theo số dòng, có trần")
    func bottomListHeight() {
        let row = AuthoringStyle.bottomListRowHeight
        #expect(AuthoringStyle.bottomListHeight(rows: 0) == row + 8)
        #expect(AuthoringStyle.bottomListHeight(rows: 1) == row + 8)
        #expect(AuthoringStyle.bottomListHeight(rows: 3) == 3 * row + 8)
        #expect(AuthoringStyle.bottomListHeight(rows: 1000) == AuthoringStyle.bottomListMaxHeight)
        #expect(AuthoringStyle.bottomListHeight(rows: 1000, sharing: true) == AuthoringStyle.bottomListSharedMaxHeight)
        #expect(AuthoringStyle.bottomListHeight(rows: 2, sharing: true) == 2 * row + 8)
    }
}
