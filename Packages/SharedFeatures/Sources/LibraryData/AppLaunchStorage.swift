import Foundation

/// Nơi một bản app lưu dữ liệu khi chạy: kho thư viện + đề mẫu (`configuration`) và cài đặt nhỏ (`defaults`,
/// gồm cờ đề mẫu, cài đặt Thư viện của `@AppStorage`, tên thí sinh và chế độ lần trước).
///
/// Bình thường là kho dưới `~/Library/Application Support/<bundle ID>/` và `UserDefaults.standard`. Riêng build
/// Debug có thêm chế độ cô lập cho UI test (`UITestLaunchOptions`): mọi thứ nằm trong thư mục tạm do test tạo.
public struct AppLaunchStorage {
    public var configuration: LibraryConfiguration
    public var defaults: UserDefaults
    /// Hệ số thời gian của đồng hồ phiên thi: 1 là thời gian thật; khác 1 chỉ ở chế độ cô lập của UI test.
    public var sessionTimeScale: Double
    /// Đang chạy ở chế độ cô lập của UI test (chỉ có ở build Debug).
    public var isUITest: Bool
    #if DEBUG
    /// File dùng thay hộp chọn file của bản Admin (ảnh của câu, **Import đề…**), từ `-ExamSuiteUITestChosenFile`.
    /// Chỉ build Debug và chỉ ở chế độ cô lập của UI test (`UITestLaunchOptions.chosenFile`); bản Release không có
    /// thuộc tính này, chạy bình thường thì luôn `nil`. Đã kiểm lúc khởi động; mỗi lần dùng phải lấy qua
    /// `revalidatedUITestChosenFile()` (kiểm lại ngay trước khi đọc).
    public var uiTestChosenFile: URL?
    /// Thư mục cô lập của lần chạy (chỉ build Debug, chế độ cô lập); `nil` khi chạy bình thường.
    public var uiTestDirectory: URL?

    /// File thay hộp chọn file, **kiểm lại ngay lúc dùng** (như lúc khởi động: `realpath` vẫn trong thư mục cô lập,
    /// file thường, chỉ một liên kết cứng), để file bị thay bằng liên kết ra ngoài sau khi app khởi động không bao giờ
    /// được đọc. `nil`: không có móc, hoặc file không còn hợp lệ (lý do ghi ra stderr); người gọi khi đó không đọc gì và
    /// cũng không mở hộp chọn file.
    public func revalidatedUITestChosenFile() -> URL? {
        guard let file = uiTestChosenFile, let directory = uiTestDirectory else { return nil }
        return UITestLaunchOptions.revalidatedChosenFile(file, in: directory)
    }
    #endif

    public init(configuration: LibraryConfiguration, defaults: UserDefaults, sessionTimeScale: Double = 1, isUITest: Bool = false) {
        self.configuration = configuration
        self.defaults = defaults
        self.sessionTimeScale = sessionTimeScale
        self.isUITest = isUITest
    }

    /// Kho và cài đặt thật của bản app: `configuration` (`.student` / `.admin`) và `UserDefaults.standard`.
    public static func standard(_ configuration: LibraryConfiguration) -> AppLaunchStorage {
        AppLaunchStorage(configuration: configuration, defaults: .standard)
    }

    /// Chọn nơi lưu theo tham số dòng lệnh của tiến trình.
    ///
    /// Build Release: luôn là kho và cài đặt thật của `configuration` (code cô lập không được biên dịch). Build
    /// Debug: có `-ExamSuiteUITest <thư mục>` thì dùng chế độ cô lập (cùng bản app, cùng chế độ đọc, nhưng mọi
    /// thứ trong thư mục đó); tham số sai (thiếu file đánh dấu, đường dẫn tương đối, chạy dưới bundle ID thật…)
    /// thì ném lỗi để app dừng, **không** rơi về kho thật.
    /// - Parameters:
    ///   - configuration: cấu hình thật của bản app (`.student` / `.admin`).
    ///   - bundleIdentifier: bundle ID của tiến trình đang chạy (`Bundle.main.bundleIdentifier`).
    public static func resolve(
        _ configuration: LibraryConfiguration,
        arguments: [String] = ProcessInfo.processInfo.arguments,
        bundleIdentifier: String? = Bundle.main.bundleIdentifier
    ) throws -> AppLaunchStorage {
        #if DEBUG
        if let options = try UITestLaunchOptions.parse(arguments: arguments, bundleIdentifier: bundleIdentifier) {
            let appIdentifier = configuration.isAdmin
                ? LibraryConfiguration.adminBundleIdentifier
                : LibraryConfiguration.studentBundleIdentifier
            return options.storage(bundleIdentifier: appIdentifier, isAdmin: configuration.isAdmin)
        }
        // Bản build cho UI test (bundle ID `vn.io.nt0.examsuite…` khác bản thật, ví dụ `.uitest`) mà thiếu tham số
        // cô lập: dừng, không rơi về kho thật. Xảy ra khi một UI test gọi thẳng `XCUIApplication().launch()`, hoặc
        // LaunchServices chọn bản `.uitest` trong DerivedData để mở file `.exam` từ Finder.
        if let bundleIdentifier, UITestLaunchOptions.isTestBuild(bundleIdentifier: bundleIdentifier) {
            throw UITestLaunchOptions.Failure.testBuildWithoutDirectory(bundleIdentifier)
        }
        #endif
        return .standard(configuration)
    }
}

#if DEBUG
/// Chế độ cô lập cho UI test, **chỉ có ở build Debug** (bản Release không biên dịch phần này).
///
/// Vì sao: bản Debug mặc định dùng chung kho `~/Library/Application Support/<bundle ID>/` và `defaults` với bản
/// cài, nên UI test lái app Debug sẽ ghi lần thi vào kho thật. Với `-ExamSuiteUITest <thư mục>`:
///
/// - kho SwiftData và đề mẫu ghi vào `<thư mục>/Application Support/<bundle ID>/`;
/// - mọi cài đặt nhỏ (cờ đề mẫu, `@AppStorage` của Thư viện, tên thí sinh, chế độ lần trước) ghi vào
///   `<thư mục>/Preferences/defaults.plist` (`UserDefaults(suiteName:)` với đường dẫn tuyệt đối);
/// - `-ExamSuiteUITestTimeScale <hệ số>` (tuỳ chọn) làm đồng hồ phiên thi chạy nhanh hơn để kiểm cảnh báo 5/1
///   phút và hết giờ mà không chờ thật;
/// - `-ExamSuiteUITestChosenFile <file>` (tuỳ chọn, bản Admin) là file dùng thay hộp chọn file của macOS khi thêm ảnh
///   cho câu và khi **Import đề…** (UI test không lái `NSOpenPanel`); file phải nằm trong thư mục cô lập.
///
/// Rào chắn: thư mục phải là đường dẫn tuyệt đối, đã có, và chứa file đánh dấu `.examsuite-uitest` do test tạo
/// (để không trỏ nhầm vào thư mục thật); app phải chạy dưới bundle ID khác bản thật (UI test build với
/// `EXAMSUITE_BUNDLE_ID_SUFFIX=.uitest`), vì AppKit tự ghi vị trí cửa sổ, thanh chia… vào `UserDefaults.standard`
/// của bundle ID đang chạy và không đổi hướng được. Sai một điều kiện thì `parse` ném lỗi và app dừng.
public struct UITestLaunchOptions: Sendable, Equatable {
    /// `-ExamSuiteUITest <thư mục>`: bật chế độ cô lập, dữ liệu trong thư mục đó.
    public static let directoryArgument = "-ExamSuiteUITest"
    /// `-ExamSuiteUITestTimeScale <hệ số>`: đồng hồ phiên thi nhanh gấp <hệ số> lần (1…3600).
    public static let timeScaleArgument = "-ExamSuiteUITestTimeScale"
    /// File test tạo trong thư mục tạm để chứng tỏ đó là thư mục của test.
    public static let markerFileName = ".examsuite-uitest"
    /// `-ExamSuiteUITestChosenFile <file>`: file dùng thay hộp chọn file (ảnh của câu, Import đề…) của bản Admin.
    public static let chosenFileArgument = "-ExamSuiteUITestChosenFile"
    /// Khoảng hệ số thời gian chấp nhận.
    public static let timeScaleRange: ClosedRange<Double> = 1 ... 3600

    /// Thư mục tạm của lần chạy (đường dẫn chuẩn hoá).
    public let directory: URL
    public let timeScale: Double
    /// File dùng thay hộp chọn file (đường dẫn chuẩn hoá, trong `directory`); `nil` nếu không có tham số.
    public let chosenFile: URL?

    public enum Failure: Error, Equatable, CustomStringConvertible {
        case missingValue(String)
        case relativePath(String)
        case notADirectory(String)
        case missingMarker(String)
        case invalidTimeScale(String)
        case timeScaleWithoutDirectory
        case chosenFileWithoutDirectory
        case chosenFileOutsideDirectory(String)
        case chosenFileMissing(String)
        case chosenFileNotPlainFile(String)
        case productionBundleIdentifier(String)
        case testBuildWithoutDirectory(String)

        public var description: String {
            switch self {
            case let .missingValue(argument):
                "\(argument) thiếu giá trị"
            case let .relativePath(path):
                "thư mục cô lập phải là đường dẫn tuyệt đối: \(path)"
            case let .notADirectory(path):
                "không có thư mục cô lập: \(path)"
            case let .missingMarker(path):
                "thư mục cô lập thiếu file đánh dấu \(UITestLaunchOptions.markerFileName): \(path)"
            case let .invalidTimeScale(value):
                "hệ số thời gian phải trong \(UITestLaunchOptions.timeScaleRange): \(value)"
            case .timeScaleWithoutDirectory:
                "\(UITestLaunchOptions.timeScaleArgument) chỉ dùng cùng \(UITestLaunchOptions.directoryArgument)"
            case .chosenFileWithoutDirectory:
                "\(UITestLaunchOptions.chosenFileArgument) chỉ dùng cùng \(UITestLaunchOptions.directoryArgument)"
            case let .chosenFileOutsideDirectory(path):
                "file thay hộp chọn file phải là đường dẫn tuyệt đối trong thư mục cô lập: \(path)"
            case let .chosenFileMissing(path):
                "không có file thay hộp chọn file: \(path)"
            case let .chosenFileNotPlainFile(path):
                "file thay hộp chọn file phải là file thường, chỉ một liên kết cứng: \(path)"
            case let .productionBundleIdentifier(identifier):
                "chế độ cô lập không chạy dưới bundle ID thật \(identifier); build với EXAMSUITE_BUNDLE_ID_SUFFIX=.uitest"
            case let .testBuildWithoutDirectory(identifier):
                "bản build cho UI test (\(identifier)) chỉ chạy với \(UITestLaunchOptions.directoryArgument) <thư mục>"
            }
        }
    }

    /// Bundle ID của một bản build cho UI test: cùng họ `vn.io.nt0.examsuite` nhưng không phải bản thật.
    public static func isTestBuild(bundleIdentifier: String) -> Bool {
        bundleIdentifier.hasPrefix(LibraryConfiguration.studentBundleIdentifier + ".")
            && !LibraryConfiguration.productionBundleIdentifiers.contains(bundleIdentifier)
    }

    public init(directory: URL, timeScale: Double = 1, chosenFile: URL? = nil) {
        self.directory = directory
        self.timeScale = timeScale
        self.chosenFile = chosenFile
    }

    /// Đọc tham số dòng lệnh. `nil`: không có tham số cô lập (chạy bình thường).
    /// - Parameter bundleIdentifier: bundle ID đang chạy; trùng bản thật
    ///   (`LibraryConfiguration.productionBundleIdentifiers`) thì từ chối.
    public static func parse(
        arguments: [String],
        bundleIdentifier: String?,
        fileManager: FileManager = .default
    ) throws -> UITestLaunchOptions? {
        let directoryValue = try value(of: directoryArgument, in: arguments)
        let scaleValue = try value(of: timeScaleArgument, in: arguments)
        let chosenValue = try value(of: chosenFileArgument, in: arguments)
        guard let directoryValue else {
            if scaleValue != nil { throw Failure.timeScaleWithoutDirectory }
            if chosenValue != nil { throw Failure.chosenFileWithoutDirectory }
            return nil
        }
        if let bundleIdentifier, LibraryConfiguration.productionBundleIdentifiers.contains(bundleIdentifier) {
            throw Failure.productionBundleIdentifier(bundleIdentifier)
        }
        guard directoryValue.hasPrefix("/") else { throw Failure.relativePath(directoryValue) }
        // Đường dẫn thật (`realpath`, `/var` → `/private/var`), như đường dẫn bookmark của đề mẫu.
        let given = URL(fileURLWithPath: directoryValue, isDirectory: true)
        let resolved = ExamFileInspector.canonical(given)
        let directory = URL(fileURLWithPath: resolved.path, isDirectory: true)
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw Failure.notADirectory(directoryValue)
        }
        guard fileManager.fileExists(atPath: directory.appendingPathComponent(markerFileName).path) else {
            throw Failure.missingMarker(directoryValue)
        }
        var timeScale = 1.0
        if let scaleValue {
            guard let scale = Double(scaleValue), scale.isFinite, timeScaleRange.contains(scale) else {
                throw Failure.invalidTimeScale(scaleValue)
            }
            timeScale = scale
        }
        var chosenFile: URL?
        if let chosenValue {
            chosenFile = try Self.validatedChosenFile(chosenValue, in: directory, fileManager: fileManager)
        }
        return UITestLaunchOptions(directory: directory, timeScale: timeScale, chosenFile: chosenFile)
    }

    /// File thay hộp chọn file: đường dẫn tuyệt đối, sau khi chuẩn hoá (`..`, liên kết tượng trưng) vẫn nằm trong thư
    /// mục cô lập, là file thường có thật (không phải thư mục) và chỉ có một liên kết cứng (liên kết cứng tới file ngoài
    /// thư mục không lộ qua `realpath`). Không thì từ chối, để UI test không bao giờ đưa vào đề một file ngoài thư mục
    /// tạm của nó. Kiểm lúc khởi động (`parse`) và lại ngay trước mỗi lần đọc (`revalidatedChosenFile`).
    static func validatedChosenFile(_ value: String, in directory: URL, fileManager: FileManager = .default) throws -> URL {
        guard value.hasPrefix("/") else { throw Failure.chosenFileOutsideDirectory(value) }
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: value, isDirectory: &isDirectory), !isDirectory.boolValue else {
            throw Failure.chosenFileMissing(value)
        }
        // `directory` đã chuẩn hoá (`realpath`); file có thật nên `realpath` của nó luôn có.
        let resolved = ExamFileInspector.canonical(URL(fileURLWithPath: value, isDirectory: false))
        let file = URL(fileURLWithPath: resolved.path, isDirectory: false)
        guard file.path.hasPrefix(directory.path + "/") else { throw Failure.chosenFileOutsideDirectory(value) }
        // Đường dẫn đã chuẩn hoá không còn là liên kết tượng trưng: thuộc tính là của chính file.
        let attributes = try? fileManager.attributesOfItem(atPath: file.path)
        guard attributes?[.type] as? FileAttributeType == .typeRegular,
              (attributes?[.referenceCount] as? NSNumber)?.intValue == 1
        else { throw Failure.chosenFileNotPlainFile(value) }
        return file
    }

    /// Kiểm lại file thay hộp chọn file ngay trước khi đọc (`AppLaunchStorage.revalidatedUITestChosenFile`). `nil` nếu
    /// không còn hợp lệ; lý do ghi ra stderr (log của UI test).
    public static func revalidatedChosenFile(_ file: URL, in directory: URL) -> URL? {
        do {
            return try validatedChosenFile(file.path, in: directory)
        } catch {
            FileHandle.standardError.write(Data("Exam Suite: bỏ file thay hộp chọn file: \(error)\n".utf8))
            return nil
        }
    }

    /// Thư mục đóng vai `~/Library/Application Support` của lần chạy.
    public var applicationSupportDirectory: URL {
        directory.appendingPathComponent("Application Support", isDirectory: true)
    }

    /// Tên suite `UserDefaults` là đường dẫn tuyệt đối (không có đuôi): cài đặt ghi vào `<đường dẫn>.plist`
    /// trong thư mục tạm, không vào `~/Library/Preferences`.
    public var defaultsSuiteName: String {
        directory.appendingPathComponent("Preferences", isDirectory: true).appendingPathComponent("defaults").path
    }

    /// File plist chứa cài đặt của lần chạy.
    public var defaultsFileURL: URL {
        URL(fileURLWithPath: defaultsSuiteName + ".plist")
    }

    /// Cấu hình Thư viện như bản app thật nhưng dưới `applicationSupportDirectory` của lần chạy.
    public func libraryConfiguration(bundleIdentifier: String, isAdmin: Bool) -> LibraryConfiguration {
        LibraryConfiguration.forApp(
            bundleIdentifier: bundleIdentifier,
            isAdmin: isAdmin,
            applicationSupportDirectory: applicationSupportDirectory
        )
    }

    public func makeDefaults() -> UserDefaults {
        // Đường dẫn tuyệt đối không bao giờ là bundle ID hay NSGlobalDomain, nên init không trả nil.
        UserDefaults(suiteName: defaultsSuiteName)!
    }

    public func storage(bundleIdentifier: String, isAdmin: Bool) -> AppLaunchStorage {
        var storage = AppLaunchStorage(
            configuration: libraryConfiguration(bundleIdentifier: bundleIdentifier, isAdmin: isAdmin),
            defaults: makeDefaults(),
            sessionTimeScale: timeScale,
            isUITest: true
        )
        storage.uiTestChosenFile = chosenFile
        storage.uiTestDirectory = directory
        return storage
    }

    /// Giá trị ngay sau `name` (dạng `-Tên giá trị`, như tham số của `UserDefaults`); nil nếu không có `name`.
    private static func value(of name: String, in arguments: [String]) throws -> String? {
        guard let index = arguments.firstIndex(of: name) else { return nil }
        let next = arguments.index(after: index)
        guard next < arguments.endIndex, !arguments[next].isEmpty else { throw Failure.missingValue(name) }
        return arguments[next]
    }
}
#endif
