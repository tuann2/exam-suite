import XCTest

/// Ngôn ngữ giao diện của app trong một lần chạy UI test (`-AppleLanguages`, miền tham số; không ghi `defaults`).
enum UITestLanguage: String {
    case vietnamese = "vi"
    case english = "en"
}

/// Bản app đang test (Học viên ở target `ExamSuiteUITests`, Admin ở `ExamSuiteAdminUITests`; dùng chung file này)
/// chạy ở chế độ cô lập của UI test (chỉ build Debug; LibraryData/AppLaunchStorage.swift): kho, đề mẫu và cài đặt
/// nằm trong một thư mục tạm riêng của từng test, xoá khi test xong. Không bao giờ mở kho hay ghi `defaults` của
/// bản cài.
///
/// - `-ExamSuiteUITest <thư mục>`: thư mục có file đánh dấu `.examsuite-uitest` (app từ chối thư mục thiếu nó).
/// - `-ExamSuiteUITestTimeScale <hệ số>`: đồng hồ phiên thi nhanh gấp <hệ số> lần (luồng 2–3).
/// - `-ExamSuiteUITestChosenFile <file>` (bản Admin, `useChosenFile`): file dùng thay hộp chọn file của macOS khi
///   thêm ảnh cho câu và khi Import đề…; phải nằm trong thư mục tạm của test.
/// - `-ApplePersistenceIgnoreState YES`: không khôi phục cửa sổ của lần chạy trước.
/// - `-AppleLanguages (vi)`: app chọn tiếng Việt dù máy ưu tiên ngôn ngữ khác (test tìm phần tử theo chữ tiếng Việt);
///   `language: .english` cho `-AppleLanguages (en)` (luồng 1 tiếng Anh, giai đoạn 5 bước 7c).
/// - `CFFIXED_USER_HOME`: thư mục nhà của app trỏ vào thư mục tạm, thêm một lớp chặn cho mọi đường dẫn tính từ
///   `~` (Application Support, Saved Application State).
///
/// App build cho UI test có bundle ID `vn.io.nt0.examsuite.uitest` hoặc `vn.io.nt0.examsuite.admin.uitest`
/// (`EXAMSUITE_BUNDLE_ID_SUFFIX=.uitest`), nên vị trí cửa sổ do AppKit tự ghi cũng không vào defaults của bản thật.
@MainActor
final class IsolatedApp {
    let app: XCUIApplication
    let directory: URL

    /// Tạo thư mục tạm của test (dưới `/private/tmp/`, xem UITests.entitlements) và đăng ký dọn dẹp:
    /// khi test xong, thoát app và xoá thư mục.
    init(for testCase: XCTestCase, timeScale: Double? = nil, language: UITestLanguage = .vietnamese) throws {
        let base = URL(fileURLWithPath: "/private/tmp", isDirectory: true)
            .appendingPathComponent("ExamSuiteUITests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        directory = base
        try Data().write(to: base.appendingPathComponent(".examsuite-uitest"))
        let home = base.appendingPathComponent("Home", isDirectory: true)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)

        app = XCUIApplication()
        var arguments = [
            "-ExamSuiteUITest", base.path,
            "-ApplePersistenceIgnoreState", "YES",
            // Giao diện tiếng Việt bất kể ngôn ngữ của máy chạy test: test tìm phần tử theo chữ tiếng Việt của app,
            // và từ khi catalog có `en` (giai đoạn 5, bước 7c) máy ưu tiên tiếng Anh sẽ chọn `en`. Tham số dòng lệnh
            // (miền tham số), không ghi `defaults`. Không đặt `-AppleLocale` (Region như máy chạy test): số, phần trăm,
            // ngày giờ theo ngôn ngữ giao diện, không theo Region (bước 7a; PracticeFlowUITests, có đoạn Xuất PDF kết
            // quả, chạy với Region en_US). Luồng tiếng Anh truyền `language: .english`.
            "-AppleLanguages", "(\(language.rawValue))",
        ]
        if let timeScale {
            arguments += ["-ExamSuiteUITestTimeScale", String(timeScale)]
        }
        app.launchArguments = arguments
        app.launchEnvironment["CFFIXED_USER_HOME"] = home.path
        testCase.addTeardownBlock { @MainActor [self] in
            tearDown()
        }
    }

    /// Tham số file thay hộp chọn file (`UITestLaunchOptions.chosenFileArgument`; AppLaunchStorageTests kiểm hai giá
    /// trị khớp nhau).
    static let chosenFileArgument = "-ExamSuiteUITestChosenFile"

    /// Ghi `data` thành `<thư mục tạm>/Files/<name>` và trả đường dẫn. Gọi trước `app.launch()` nếu file dùng cho
    /// `useChosenFile` (app kiểm file có thật khi khởi động).
    func writeFile(_ name: String, _ data: Data) throws -> URL {
        let files = directory.appendingPathComponent("Files", isDirectory: true)
        try FileManager.default.createDirectory(at: files, withIntermediateDirectories: true)
        let url = files.appendingPathComponent(name)
        try data.write(to: url)
        return url
    }

    /// Bản Admin dùng `file` thay hộp chọn file (ảnh của câu, Import đề…) trong lần chạy này. Gọi trước `app.launch()`.
    func useChosenFile(_ file: URL) {
        app.launchArguments += [Self.chosenFileArgument, file.path]
    }

    /// Thư mục con mới trong thư mục tạm (ví dụ nơi lưu đề trong hộp Lưu).
    func makeSubdirectory(_ name: String) throws -> URL {
        let url = directory.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Khoá "đã tạo đề mẫu" (`LibraryStore.samplesSeededKey`; AppLaunchStorageTests kiểm hai giá trị khớp nhau).
    static let samplesSeededKey = "library.samplesSeeded"

    /// File cài đặt của lần chạy (`UITestLaunchOptions.defaultsFileURL`: `<thư mục>/Preferences/defaults.plist`).
    var defaultsFileURL: URL {
        directory.appendingPathComponent("Preferences/defaults.plist")
    }

    /// Chờ tới khi file cài đặt trong thư mục tạm có `key`: chứng tỏ app ghi cài đặt vào suite cô lập chứ không vào
    /// `UserDefaults.standard` (cfprefsd ghi file không đồng bộ nên phải chờ).
    func waitForIsolatedDefault(_ key: String, timeout: TimeInterval = 15) -> Bool {
        waitUntil(timeout) { NSDictionary(contentsOf: self.defaultsFileURL)?[key] != nil }
    }

    /// Thoát app và xoá thư mục tạm.
    func tearDown() {
        if app.state != .notRunning {
            app.terminate()
        }
        try? FileManager.default.removeItem(at: directory)
    }
}
