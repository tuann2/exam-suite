import XCTest

/// Luồng 5 của docs/product/overview.md (Sửa, bản Admin) với hành vi **mặc định** của macOS (authoring.md, mục Lưu,
/// hoàn tác, khôi phục; phương án 15, Nt0 chốt 2026-10-17):
///
/// - Đề **đã có file** (đề mẫu, ⌘E): kéo thả sắp xếp → ⌘Z → ⇧⌘Z → ⌘W đóng **không hỏi** (macOS tự lưu tại chỗ) và file
///   trên đĩa có thay đổi (mở lại thấy thứ tự mới). Đề mẫu nằm trong thư mục tạm của test.
/// - Đề **chưa từng lưu** (Đề mới) có thay đổi: ⌘W hỏi; Huỷ (Esc) giữ cửa sổ và thay đổi; dọn: bỏ, không lưu.
///   Test này mở đầu bằng kiểm chế độ cô lập của bản Admin (trước là `AdminLaunchUITests`).
///
/// Không đổi cài đặt "Hỏi giữ thay đổi khi đóng tài liệu" của macOS (miền chung của người dùng). Khôi phục sau crash và
/// Versions là test tay.
final class EditExamFlowUITests: XCTestCase {
    @MainActor
    func testSavedExamReorderUndoRedoThenCloseAutosavesWithoutAsking() throws {
        continueAfterFailure = false
        let isolated = try IsolatedApp(for: self)
        let app = isolated.app
        // Kiểm hành vi MẶC ĐỊNH của macOS (cài đặt "Hỏi giữ thay đổi khi đóng tài liệu" tắt) bất kể máy chạy test bật hay
        // tắt cài đặt đó: `-NSCloseAlwaysConfirmsChanges NO` chỉ nằm ở miền tham số của lần chạy này (đè miền chung của
        // người dùng), không ghi vào defaults nào và hết khi app thoát.
        app.launchArguments += ["-NSCloseAlwaysConfirmsChanges", "NO"]
        let flow = AdminFlow(isolated)
        flow.registerCleanup(self)
        app.launch()
        flow.waitForLibrary()
        let samplesBefore = flow.sampleFiles()
        XCTAssertEqual(samplesBefore.count, 2, "Thư mục tạm phải có hai file đề mẫu: \(flow.samplesDirectory.path)")

        // ⌘E (Sửa) trên thẻ đề mẫu: mở file đề mẫu (trong thư mục tạm) vào cửa sổ soạn đề.
        flow.selectCard(Samples.lamQuen)
        app.press("e", .command)
        flow.waitForAuthoringWindow()
        let first = flow.row("question.0.0")
        let third = flow.row("question.0.2")
        XCTAssertTrue(first.waitForExistence(timeout: 10), "Cây đề không có câu 1")
        XCTAssertTrue(third.waitForExistence(timeout: 5), "Cây đề không có câu 3")
        let original = first.label
        XCTAssertFalse(original.isEmpty)

        // Kéo câu 1 xuống dưới (thả trên câu 3): câu ở vị trí đầu đổi.
        first.click(forDuration: 0.8, thenDragTo: third)
        let moved = waitUntil(5) { first.label != original }
        if !moved { flow.dumpTree() }
        XCTAssertTrue(moved, "Kéo thả không sắp xếp câu trên cây đề")
        let reordered = first.label

        // ⌘Z: về thứ tự cũ. ⇧⌘Z: làm lại.
        app.press("z", .command)
        XCTAssertTrue(waitUntil(5) { first.label == original }, "⌘Z không hoàn tác sắp xếp: \(first.label)")
        app.press("z", [.command, .shift])
        XCTAssertTrue(waitUntil(5) { first.label == reordered }, "⇧⌘Z không làm lại sắp xếp: \(first.label)")

        // ⌘W: đề đã có file → macOS tự lưu tại chỗ rồi đóng, không hỏi.
        app.press("w", .command)
        let closed = waitUntil(10) { !flow.tree.exists || flow.hasAlert }
        if flow.hasAlert { flow.dumpTree() }
        XCTAssertFalse(flow.hasAlert, "⌘W với đề đã có file không được hỏi (authoring.md phương án 15)")
        XCTAssertTrue(closed && !flow.tree.exists, "⌘W không đóng cửa sổ soạn đề")

        // File trên đĩa đã đổi: đúng một file đề mẫu khác byte so với lúc đầu.
        let changed: () -> [String] = {
            let now = flow.sampleFiles()
            return samplesBefore.keys.filter { now[$0] != samplesBefore[$0] }
        }
        XCTAssertTrue(waitUntil(10) { changed().count == 1 }, "File đề mẫu trên đĩa không có thay đổi: \(changed())")

        // Mở lại: thứ tự mới còn (đọc từ file).
        flow.selectCard(Samples.lamQuen)
        app.press("e", .command)
        flow.waitForAuthoringWindow()
        XCTAssertTrue(waitUntil(10) { first.label == reordered }, "Mở lại không thấy thay đổi đã tự lưu: \(first.label)")

        // Dọn: không sửa gì, ⌘W đóng, ⌘Q.
        app.press("w", .command)
        XCTAssertTrue(flow.tree.waitForNonExistence(within: 10), "⌘W không đóng cửa sổ soạn đề")
        XCTAssertFalse(flow.hasAlert)
        flow.quit()
    }

    /// Mở đầu (giai đoạn 5 bước 10, T3 của notes/g5-ui-test-trung-lap.md; trước là lần mở app riêng `AdminLaunchUITests`):
    /// bản Admin mở ở chế độ cô lập (bundle ID `vn.io.nt0.examsuite.admin.uitest`), cửa sổ Thư viện có hai đề mẫu, kho và
    /// cài đặt nằm trong thư mục tạm của test, không dùng kho của bản Học viên. Cuối test ⌘Q thoát app ngay (không còn đề
    /// chưa lưu).
    @MainActor
    func testIsolatedLaunchThenClosingUnsavedNewExamAsksAndCancelKeepsWindow() throws {
        continueAfterFailure = false
        let isolated = try IsolatedApp(for: self)
        let app = isolated.app
        let flow = AdminFlow(isolated)
        flow.registerCleanup(self)
        app.launch()

        XCTContext.runActivity(named: "Mở bản Admin ở chế độ cô lập (trước là AdminLaunchUITests)") { _ in
            // Cửa sổ Thư viện nhận theo định danh trợ năng của lưới/bảng đề bên trong, không theo tiêu đề (đổi theo ngôn ngữ).
            let content = NSPredicate(
                format: "identifier BEGINSWITH %@ OR identifier BEGINSWITH %@", "library.grid", "library.table"
            )
            let library = app.windows.containing(content).firstMatch
            XCTAssertTrue(library.waitForExistence(timeout: 20), "Không thấy cửa sổ Thư viện")
            XCTAssertTrue(app.element(Samples.lamQuen.cardID).waitForExistence(timeout: 20), "Thư viện không hiện đề mẫu")
            XCTAssertTrue(app.element(Samples.attt.cardID).waitForExistence(timeout: 5))
            let support = isolated.directory.appendingPathComponent("Application Support", isDirectory: true)
            let store = support.appendingPathComponent("vn.io.nt0.examsuite.admin/Library.store")
            XCTAssertTrue(FileManager.default.fileExists(atPath: store.path), "kho Admin phải nằm trong thư mục tạm")
            XCTAssertFalse(
                FileManager.default.fileExists(atPath: support.appendingPathComponent("vn.io.nt0.examsuite").path),
                "bản Admin không được dùng kho của bản Học viên"
            )
            // Cài đặt (cờ đề mẫu) ghi vào suite trong thư mục tạm: AdminShell nối `storage.defaults`, không dùng
            // UserDefaults.standard.
            XCTAssertTrue(
                isolated.waitForIsolatedDefault(IsolatedApp.samplesSeededKey),
                "cờ đề mẫu phải nằm trong \(isolated.defaultsFileURL.path)"
            )
        }
        flow.waitForLibrary()

        // Đề mới (chưa từng lưu) có sửa.
        app.press("n", .command)
        flow.waitForAuthoringWindow()
        flow.select("exam")
        flow.fill("authoring.exam.title", "De chua luu")
        XCTAssertTrue(flow.row("exam").waitForText("De chua luu", within: 5), flow.row("exam").text)

        // ⌘W: macOS hỏi. Esc = Huỷ: cửa sổ vẫn mở, thay đổi còn nguyên.
        app.press("w", .command)
        let sheet = flow.expectCloseSheet()
        app.press(.escape)
        XCTAssertTrue(sheet.waitForNonExistence(within: 5), "Esc không đóng hộp hỏi")
        XCTAssertTrue(flow.tree.exists, "Huỷ phải giữ cửa sổ soạn đề")
        XCTAssertTrue(flow.row("exam").text.contains("De chua luu"), "Huỷ phải giữ thay đổi: \(flow.row("exam").text)")

        // Dọn: ⌘W, bỏ (không lưu) → cửa sổ đóng; ⌘Q: không có bài đang làm, không có đề chưa lưu, nên app thoát ngay.
        app.press("w", .command)
        flow.discardChanges(in: flow.expectCloseSheet())
        XCTAssertTrue(flow.tree.waitForNonExistence(within: 5), "Bỏ thay đổi phải đóng cửa sổ soạn đề")
        flow.quit()
    }
}
