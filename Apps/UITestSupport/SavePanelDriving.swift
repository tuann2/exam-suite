import XCTest

/// Hộp Lưu của macOS (sheet `NSSavePanel` trên cửa sổ của app), lái bằng bàn phím, chỉ lưu vào thư mục tạm của test.
/// Dùng chung: bản Admin lưu đề (⌘S, luồng 4), bản Học viên Xuất PDF… kết quả (export-print.md).
///
/// Không có móc thay hộp Lưu: app mở với `-NSNavLastRootDirectory <thư mục>` (miền tham số của lần chạy, không ghi
/// defaults; `prepareFolder`) để chỗ lưu mặc định đã là thư mục tạm; ô vị trí chưa đúng thì ⇧⌘G. Chỉ bấm Lưu khi ô vị
/// trí là thư mục tạm; không thì Huỷ hộp Lưu (không lưu đi đâu cả) và báo lỗi.
@MainActor
struct SavePanelDriver {
    let app: XCUIApplication
    /// Thư mục tạm của test (tìm file lưu nhầm chỗ khi hỏng).
    let isolatedDirectory: URL
    /// Defaults của bản `.uitest` nơi hộp Lưu nhớ thư mục cuối (ghi trong thông báo lỗi).
    let defaultsDomain: String
    /// In cây cửa sổ vào log khi hỏng.
    let dumpTree: () -> Void

    /// Thư mục con `name` trong thư mục tạm làm chỗ lưu mặc định của hộp Lưu (tên riêng để nhận ra trên ô vị trí). Mở
    /// app với `-NSNavLastRootDirectory <thư mục>` (miền tham số của lần chạy, không ghi defaults). Gọi trước
    /// `app.launch()`.
    static func prepareFolder(_ name: String, in isolated: IsolatedApp) throws -> URL {
        let folder = try isolated.makeSubdirectory(name)
        isolated.app.launchArguments += ["-NSNavLastRootDirectory", folder.path]
        return folder
    }

    /// Số hộp/sheet/cửa sổ đang mở (để biết hộp "Đi tới thư mục" đã mở hay đã đóng, không chờ cứng).
    private var overlayCount: Int {
        app.sheets.count + app.dialogs.count + app.popovers.count + app.windows.count
    }

    /// Ô vị trí của hộp Lưu đang là thư mục `name`.
    private func saveLocation(is name: String, in panel: XCUIElement) -> Bool {
        panel.descendants(matching: .popUpButton)
            .matching(NSPredicate(format: "value == %@ OR title == %@", name, name)).firstMatch.exists
    }

    /// Hộp Lưu `panel` đang mở: gõ tên `name`; ô vị trí chưa là `folder` thì ⇧⌘G, chờ hộp Đi tới thư mục mở, gõ đường
    /// dẫn, Return, chờ hộp đóng. Chỉ bấm Lưu (Return) khi ô vị trí là `folder`; không thì Huỷ hộp Lưu và báo lỗi. Trả
    /// file đã lưu (`<folder>/<name>.<fileExtension>`), kiểm file có thật.
    @discardableResult
    func save(
        _ panel: XCUIElement,
        named name: String,
        fileExtension: String,
        in folder: URL,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> URL {
        let saved = folder.appendingPathComponent("\(name).\(fileExtension)")
        // Ô tên có tiêu điểm khi hộp Lưu mở; tên gợi ý đang được chọn.
        app.press("a", .command)
        app.typeText(name)
        let folderName = folder.lastPathComponent
        if !waitUntil(3, { saveLocation(is: folderName, in: panel) }) {
            // Đi tới thư mục (⇧⌘G): chờ hộp mở, gõ đường dẫn đầy đủ, Return, chờ hộp đóng.
            let before = overlayCount
            app.press("g", [.command, .shift])
            if !waitUntil(5, { overlayCount > before }) {
                abandon(panel, "⇧⌘G không mở hộp Đi tới thư mục", file: file, line: line)
            }
            app.press("a", .command)
            app.typeText(folder.path)
            app.press(.return)
            if !waitUntil(5, { overlayCount == before }) {
                app.press(.escape)
                abandon(panel, "Hộp Đi tới thư mục không đóng sau Return", file: file, line: line)
            }
        }
        if !waitUntil(5, { saveLocation(is: folderName, in: panel) }) {
            abandon(panel, "Ô vị trí của hộp Lưu không phải thư mục tạm \(folderName)", file: file, line: line)
        }
        // Return = Lưu (nút mặc định).
        app.press(.return)
        XCTAssertTrue(panel.waitForNonExistence(within: 10), "Hộp Lưu chưa đóng", file: file, line: line)
        if !waitUntil(15, { FileManager.default.fileExists(atPath: saved.path) }) {
            dumpTree()
            let suffix = "\(name).\(fileExtension)"
            let strays = (FileManager.default.enumerator(atPath: isolatedDirectory.path)?.allObjects as? [String] ?? [])
                .filter { $0.hasSuffix(suffix) }
            XCTFail(
                """
                Không thấy file đã lưu \(saved.path). File có thể đã lưu ra chỗ khác: trong thư mục tạm \
                (\(strays.isEmpty ? "không thấy" : strays.joined(separator: ", "))), hoặc ngoài thư mục tạm: \
                ~/Documents, ~/Desktop, ~/Downloads, thư mục cuối của hộp Lưu (NSNavLastRootDirectory trong defaults \
                \(defaultsDomain)). Tìm tay file "\(suffix)" và xoá.
                """,
                file: file, line: line
            )
        }
        return saved
    }

    /// Huỷ hộp Lưu (Esc: không lưu file nào) rồi báo lỗi; dừng test (`continueAfterFailure = false`).
    private func abandon(_ panel: XCUIElement, _ reason: String, file: StaticString, line: UInt) {
        dumpTree()
        app.press(.escape)
        _ = panel.waitForNonExistence(within: 5)
        XCTFail("\(reason); đã Huỷ hộp Lưu, không lưu file nào.", file: file, line: line)
    }
}
