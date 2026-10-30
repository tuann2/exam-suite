import ExamFile
import Foundation
@testable import LibraryData
import Testing

/// Chế độ cô lập của UI test (`AppLaunchStorage`, `UITestLaunchOptions`): khi tắt, app dùng kho và cài đặt thật;
/// khi bật, kho, đề mẫu và cài đặt đều nằm trong thư mục tạm; tham số sai thì từ chối, không rơi về kho thật.
@Suite("Nơi lưu khi chạy app và chế độ cô lập của UI test")
struct AppLaunchStorageTests {
    /// Bundle ID của bản build cho UI test (`EXAMSUITE_BUNDLE_ID_SUFFIX=.uitest`).
    private let uiTestBundleID = "vn.io.nt0.examsuite.uitest"
    /// Bundle ID của bản Admin build cho UI test (`vn.io.nt0.examsuite.admin` + `.uitest`).
    private let adminUITestBundleID = "vn.io.nt0.examsuite.admin.uitest"

    private func isolatedDirectory(_ workspace: TestWorkspace, marker: Bool = true) throws -> URL {
        let directory = workspace.root.appendingPathComponent("uitest", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if marker {
            try Data().write(to: directory.appendingPathComponent(UITestLaunchOptions.markerFileName))
        }
        return directory
    }

    @Test("Không có tham số: kho thật của bản app và UserDefaults.standard")
    func standardWithoutArguments() throws {
        for configuration in [LibraryConfiguration.student, .admin] {
            let storage = try AppLaunchStorage.resolve(
                configuration,
                arguments: ["/Applications/Exam Suite.app/Contents/MacOS/Exam Suite"],
                bundleIdentifier: configuration.isAdmin
                    ? LibraryConfiguration.adminBundleIdentifier
                    : LibraryConfiguration.studentBundleIdentifier
            )
            #expect(storage.configuration == configuration)
            #expect(storage.defaults === UserDefaults.standard)
            #expect(storage.sessionTimeScale == 1)
            #expect(!storage.isUITest)
            #expect(storage.uiTestChosenFile == nil)
        }
        #expect(AppLaunchStorage.standard(.admin).uiTestChosenFile == nil)
    }

    @Test("Bật: kho, đề mẫu và cài đặt nằm trong thư mục tạm, không trùng kho thật")
    func isolatedPaths() throws {
        let workspace = try TestWorkspace()
        let directory = try isolatedDirectory(workspace)
        let storage = try AppLaunchStorage.resolve(
            .student,
            arguments: ["app", UITestLaunchOptions.directoryArgument, directory.path],
            bundleIdentifier: uiTestBundleID
        )
        #expect(storage.isUITest)
        #expect(storage.sessionTimeScale == 1)
        let root = ExamFileInspector.canonical(directory).path + "/"
        let store = storage.configuration.storeURL.path
        let samples = storage.configuration.samplesDirectoryURL.path
        #expect(store == root + "Application Support/vn.io.nt0.examsuite/Library.store")
        #expect(samples == root + "Application Support/vn.io.nt0.examsuite/Samples")
        #expect(storage.configuration.storeURL != LibraryConfiguration.student.storeURL)
        #expect(storage.configuration.samplesDirectoryURL != LibraryConfiguration.student.samplesDirectoryURL)
        // Cùng bản app: đọc nghiêm, không phải Admin, đề mẫu từ bundle.
        #expect(storage.configuration.readMode == .strict)
        #expect(!storage.configuration.isAdmin)
        #expect(storage.configuration.samplesSourceURL == LibraryConfiguration.bundledSamplesURL)
        #expect(storage.defaults !== UserDefaults.standard)
        // Tính đường dẫn không tạo gì trên đĩa.
        #expect(!workspace.exists(directory.appendingPathComponent("Application Support")))
    }

    @Test("Bật: cài đặt ghi vào plist trong thư mục tạm, không vào UserDefaults.standard")
    func isolatedDefaultsStayInDirectory() throws {
        let workspace = try TestWorkspace()
        let directory = try isolatedDirectory(workspace)
        let options = try #require(try UITestLaunchOptions.parse(
            arguments: [UITestLaunchOptions.directoryArgument, directory.path],
            bundleIdentifier: uiTestBundleID
        ))
        let key = "session.candidateName.\(UUID().uuidString)"
        let defaults = options.makeDefaults()
        defaults.set("Học viên UI test", forKey: key)
        #expect(defaults.synchronize())
        #expect(UserDefaults.standard.object(forKey: key) == nil)
        #expect(options.defaultsFileURL.path.hasPrefix(ExamFileInspector.canonical(directory).path + "/"))
        let written = try #require(NSDictionary(contentsOf: options.defaultsFileURL))
        #expect(written[key] as? String == "Học viên UI test")
        // Đọc lại bằng một UserDefaults mới cùng suite (như lần mở app sau trong cùng test).
        #expect(options.makeDefaults().string(forKey: key) == "Học viên UI test")
    }

    @Test("Hệ số thời gian đọc từ tham số")
    func timeScale() throws {
        let workspace = try TestWorkspace()
        let directory = try isolatedDirectory(workspace)
        let storage = try AppLaunchStorage.resolve(
            .student,
            arguments: [
                UITestLaunchOptions.directoryArgument, directory.path,
                UITestLaunchOptions.timeScaleArgument, "6",
            ],
            bundleIdentifier: uiTestBundleID
        )
        #expect(storage.sessionTimeScale == 6)
    }

    @Test("Tham số sai thì từ chối (app dừng), không rơi về kho thật")
    func rejectsInvalidArguments() throws {
        let workspace = try TestWorkspace()
        let directory = try isolatedDirectory(workspace)
        let unmarked = try isolatedDirectory(workspace, marker: false)
            .appendingPathComponent("khong-danh-dau", isDirectory: true)
        try FileManager.default.createDirectory(at: unmarked, withIntermediateDirectories: true)
        let flag = UITestLaunchOptions.directoryArgument
        let scale = UITestLaunchOptions.timeScaleArgument
        typealias Failure = UITestLaunchOptions.Failure

        func failure(_ arguments: [String], bundleID: String? = "vn.io.nt0.examsuite.uitest") -> Failure? {
            do {
                _ = try AppLaunchStorage.resolve(.student, arguments: arguments, bundleIdentifier: bundleID)
                return nil
            } catch let error as Failure {
                return error
            } catch {
                return nil
            }
        }

        #expect(failure([flag]) == .missingValue(flag))
        #expect(failure([flag, ""]) == .missingValue(flag))
        #expect(failure([flag, "tmp/uitest"]) == .relativePath("tmp/uitest"))
        let missing = directory.appendingPathComponent("khong-co").path
        #expect(failure([flag, missing]) == .notADirectory(missing))
        // Thư mục có thật nhưng không do test tạo (ví dụ trỏ nhầm vào ~/Library/Application Support).
        #expect(failure([flag, unmarked.path]) == .missingMarker(unmarked.path))
        #expect(failure([flag, directory.path, scale, "0"]) == .invalidTimeScale("0"))
        #expect(failure([flag, directory.path, scale, "abc"]) == .invalidTimeScale("abc"))
        #expect(failure([flag, directory.path, scale, "inf"]) == .invalidTimeScale("inf"))
        #expect(failure([scale, "6"]) == .timeScaleWithoutDirectory)
        #expect(failure([UITestLaunchOptions.chosenFileArgument]) == .missingValue(UITestLaunchOptions.chosenFileArgument))
        // Bundle ID thật (hai bản macOS: AppKit sẽ ghi vị trí cửa sổ vào defaults thật; bản iOS và bản Debug của nó: dữ
        // liệu thật trên iPhone), nên không cho chạy.
        for real in LibraryConfiguration.productionBundleIdentifiers {
            #expect(failure([flag, directory.path], bundleID: real) == .productionBundleIdentifier(real))
        }
        // Bản build cho UI test chạy thiếu tham số cô lập: dừng, không rơi về kho thật (review #26 N1).
        for testBuild in ["vn.io.nt0.examsuite.uitest", "vn.io.nt0.examsuite.admin.uitest",
                          "vn.io.nt0.examsuite.ios.debug.uitest"] {
            #expect(failure([], bundleID: testBuild) == .testBuildWithoutDirectory(testBuild))
        }
        // Bản thật và tiến trình khác (ví dụ trình chạy test) không có tham số: chạy bình thường.
        let others = ["com.apple.dt.xctest.tool", "vn.io.nt0.examsuitex"]
        for normal in LibraryConfiguration.productionBundleIdentifiers + others {
            #expect(failure([], bundleID: normal) == nil)
        }
    }

    @Test(
        "Bật: mở thư viện thật (SwiftData, đề mẫu) chỉ ghi trong thư mục tạm, ở cả hai bản app",
        arguments: [false, true]
    )
    @MainActor
    func isolatedLibraryWritesOnlyInDirectory(isAdmin: Bool) async throws {
        let workspace = try TestWorkspace()
        let directory = try isolatedDirectory(workspace)
        let configuration: LibraryConfiguration = isAdmin ? .admin : .student
        let bundleID = isAdmin ? adminUITestBundleID : uiTestBundleID
        let appFolder = isAdmin ? LibraryConfiguration.adminBundleIdentifier : LibraryConfiguration.studentBundleIdentifier
        let storage = try AppLaunchStorage.resolve(
            configuration,
            arguments: [UITestLaunchOptions.directoryArgument, directory.path],
            bundleIdentifier: bundleID
        )
        let store = LibraryStore.persistent(configuration: storage.configuration, defaults: storage.defaults)
        let report = await store.start()
        #expect(report.didAddSamples)
        #expect(store.entries.count == 2)
        #expect(FileManager.default.fileExists(atPath: storage.configuration.storeURL.path))
        let root = ExamFileInspector.canonical(directory).path + "/"
        for entry in store.entries {
            #expect(entry.fileURL.path.hasPrefix(root + "Application Support/\(appFolder)/Samples/"))
        }
        #expect(storage.configuration.isAdmin == isAdmin)
        #expect(storage.configuration.storeURL != configuration.storeURL)
        // Cờ "đã tạo đề mẫu" ở suite của thư mục tạm.
        #expect(storage.defaults.bool(forKey: LibraryStore.samplesSeededKey))
        storage.defaults.synchronize()
        let options = try #require(try UITestLaunchOptions.parse(
            arguments: [UITestLaunchOptions.directoryArgument, directory.path],
            bundleIdentifier: bundleID
        ))
        let written = try #require(NSDictionary(contentsOf: options.defaultsFileURL))
        #expect(written[LibraryStore.samplesSeededKey] as? Bool == true)
        // Mọi file mới nằm trong thư mục tạm: không có gì ngoài Application Support/, Preferences/ và file đánh dấu.
        let top = try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted()
        #expect(top == [UITestLaunchOptions.markerFileName, "Application Support", "Preferences"].sorted())
    }

    @Test("Bản Admin ở chế độ cô lập: kho Admin trong thư mục tạm, đọc dễ")
    func isolatedAdmin() throws {
        let workspace = try TestWorkspace()
        let directory = try isolatedDirectory(workspace)
        let storage = try AppLaunchStorage.resolve(
            .admin,
            arguments: [
                UITestLaunchOptions.directoryArgument, directory.path,
                UITestLaunchOptions.timeScaleArgument, "5",
            ],
            bundleIdentifier: adminUITestBundleID
        )
        let root = ExamFileInspector.canonical(directory).path + "/"
        #expect(storage.isUITest)
        #expect(storage.sessionTimeScale == 5)
        #expect(storage.configuration.storeURL.path == root + "Application Support/vn.io.nt0.examsuite.admin/Library.store")
        #expect(storage.configuration.samplesDirectoryURL.path == root + "Application Support/vn.io.nt0.examsuite.admin/Samples")
        #expect(storage.configuration.storeURL != LibraryConfiguration.admin.storeURL)
        #expect(storage.configuration.samplesDirectoryURL != LibraryConfiguration.admin.samplesDirectoryURL)
        #expect(storage.configuration.readMode == .lenient)
        #expect(storage.configuration.isAdmin)
        #expect(storage.configuration.samplesSourceURL == LibraryConfiguration.bundledSamplesURL)
        #expect(storage.defaults !== UserDefaults.standard)
    }

    @Test("Bản Admin: chế độ cô lập dưới bundle ID thật thì dừng; bản build UI test thiếu tham số thì dừng")
    func adminGuards() throws {
        let workspace = try TestWorkspace()
        let directory = try isolatedDirectory(workspace)
        typealias Failure = UITestLaunchOptions.Failure
        func failure(_ arguments: [String], bundleID: String) -> Failure? {
            do {
                _ = try AppLaunchStorage.resolve(.admin, arguments: arguments, bundleIdentifier: bundleID)
                return nil
            } catch {
                return error as? Failure
            }
        }
        let real = LibraryConfiguration.adminBundleIdentifier
        #expect(failure([UITestLaunchOptions.directoryArgument, directory.path], bundleID: real) == .productionBundleIdentifier(real))
        #expect(failure(["app"], bundleID: adminUITestBundleID) == .testBuildWithoutDirectory(adminUITestBundleID))
        #expect(failure([UITestLaunchOptions.directoryArgument, directory.path], bundleID: adminUITestBundleID) == nil)
        #expect(failure(["app"], bundleID: real) == nil)
    }

    /// UI test hai bản app (Apps/UITestSupport/IsolatedApp.swift, không link LibraryData) kiểm cài đặt nằm trong thư
    /// mục tạm bằng cách đọc file và khoá ghi cứng; hai giá trị đó phải khớp nơi app thật sự ghi.
    @Test("UI test đọc đúng file cài đặt cô lập và đúng khoá cờ đề mẫu")
    @MainActor
    func uiTestSupportMatchesIsolatedDefaults() throws {
        let workspace = try TestWorkspace()
        let directory = try isolatedDirectory(workspace)
        let options = try #require(try UITestLaunchOptions.parse(
            arguments: [UITestLaunchOptions.directoryArgument, directory.path],
            bundleIdentifier: adminUITestBundleID
        ))
        #expect(options.defaultsFileURL.path == options.directory.path + "/Preferences/defaults.plist")
        let supportURL = RepoFixtures.root.deletingLastPathComponent()
            .appendingPathComponent("Apps/UITestSupport/IsolatedApp.swift")
        let source = try String(contentsOf: supportURL, encoding: .utf8)
        #expect(source.contains("static let samplesSeededKey = \"\(LibraryStore.samplesSeededKey)\""))
        #expect(source.contains("directory.appendingPathComponent(\"Preferences/defaults.plist\")"))
    }

    /// project.yml dựng bundle ID của hai bản app là `<bundle ID thật>$(EXAMSUITE_BUNDLE_ID_SUFFIX)`: build thường
    /// (đuôi rỗng) ra đúng bundle ID thật mà code dùng làm tên thư mục kho; build UI test (đuôi `.uitest`) ra bundle ID
    /// mà rào chắn nhận là bản build test (dừng khi thiếu tham số, không bị coi là bản thật).
    @Test("project.yml: bundle ID ba bản app khớp code, đuôi .uitest được nhận là bản build test")
    func projectBundleIdentifiers() throws {
        let lines = try Self.projectLines()
        /// Giá trị `PRODUCT_BUNDLE_IDENTIFIER` trong khối target `name`.
        func bundleIdentifier(ofTarget name: String) -> String? {
            let key = "PRODUCT_BUNDLE_IDENTIFIER:"
            return Self.targetBlock(name, in: lines)?
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .first { $0.hasPrefix(key) }
                .map { $0.dropFirst(key.count).trimmingCharacters(in: .whitespaces) }
        }
        let suffix = "$(EXAMSUITE_BUNDLE_ID_SUFFIX)"
        let targets = [
            ("ExamSuite", LibraryConfiguration.studentBundleIdentifier),
            ("ExamSuiteAdmin", LibraryConfiguration.adminBundleIdentifier),
        ]
        for (target, real) in targets {
            let value = try #require(bundleIdentifier(ofTarget: target), "project.yml thiếu bundle ID của \(target)")
            #expect(value == real + suffix, "\(target): \(value)")
            #expect(!UITestLaunchOptions.isTestBuild(bundleIdentifier: value.replacingOccurrences(of: suffix, with: "")))
            let testBuild = value.replacingOccurrences(of: suffix, with: ".uitest")
            #expect(UITestLaunchOptions.isTestBuild(bundleIdentifier: testBuild), "\(testBuild)")
        }
        // Bản iOS: đuôi theo cấu hình build (`EXAMSUITE_IOS_CONFIG_SUFFIX`, đọc từ khối `configs:` của target), build
        // UI test thêm `.uitest`. Cả bản Release và bản Debug đều là bản thật (dữ liệu trên iPhone); hai bản build UI
        // test thì không.
        let configSuffix = "$(EXAMSUITE_IOS_CONFIG_SUFFIX)"
        let ios = try #require(
            bundleIdentifier(ofTarget: "ExamSuiteiOS"), "project.yml thiếu bundle ID của ExamSuiteiOS"
        )
        #expect(ios == LibraryConfiguration.iosBundleIdentifier + configSuffix + suffix, "ExamSuiteiOS: \(ios)")
        let configSuffixes = try Self.iosConfigSuffixes(lines)
        #expect(configSuffixes.keys.sorted() == ["Debug", "Release"], "\(configSuffixes)")
        for (config, real) in [("Release", LibraryConfiguration.iosBundleIdentifier),
                               ("Debug", LibraryConfiguration.iosDebugBundleIdentifier)] {
            let value = try #require(configSuffixes[config], "project.yml: ExamSuiteiOS thiếu đuôi của \(config)")
            let built = ios.replacingOccurrences(of: configSuffix, with: value)
            #expect(built.replacingOccurrences(of: suffix, with: "") == real)
            #expect(!UITestLaunchOptions.isTestBuild(bundleIdentifier: real))
            let testBuild = built.replacingOccurrences(of: suffix, with: ".uitest")
            #expect(UITestLaunchOptions.isTestBuild(bundleIdentifier: testBuild), "\(testBuild)")
        }
    }

    /// project.yml khai báo kiểu file `.exam` ở sáu chỗ: `LSItemContentTypes` và `UTTypeIdentifier` của ba bản app (bản
    /// Học viên macOS và bản iOS import, bản Admin export; exam-format.md, ADR 0003). Cả sáu phải là
    /// `ExamFileFormat.uniformTypeIdentifier` mà `UTType.examPackage` dùng; lệch thì Finder và hộp chọn file không coi
    /// `.exam` là đề của app (đổi tên kiểu 2026-10-18, plan giai đoạn 6 mục G6 Nt0).
    @Test("project.yml: kiểu file .exam của ba bản app khớp ExamFileFormat.uniformTypeIdentifier")
    func projectExamTypeIdentifiers() throws {
        let lines = try Self.projectLines()
        let identifier = ExamFileFormat.uniformTypeIdentifier
        for (target, declarationKey) in [("ExamSuite", "UTImportedTypeDeclarations:"),
                                         ("ExamSuiteAdmin", "UTExportedTypeDeclarations:"),
                                         ("ExamSuiteiOS", "UTImportedTypeDeclarations:")] {
            let block = try #require(Self.targetBlock(target, in: lines), "project.yml thiếu target \(target)")
            let trimmed = block.map { $0.trimmingCharacters(in: .whitespaces) }
            /// Mục đầu tiên ngay dưới khoá `key` trong khối target.
            func firstItem(under key: String) throws -> String {
                let index = try #require(trimmed.firstIndex(of: key), "\(target): thiếu \(key)")
                return try #require(trimmed.indices.contains(index + 1) ? trimmed[index + 1] : nil, "\(target): \(key) rỗng")
            }
            #expect(try firstItem(under: "LSItemContentTypes:") == "- " + identifier, "\(target): LSItemContentTypes")
            #expect(try firstItem(under: declarationKey) == "- UTTypeIdentifier: " + identifier, "\(target): \(declarationKey)")
        }
        // Không có khai báo kiểu nào khác (ví dụ tên cũ sót ở chỗ thứ năm).
        let declarations = lines.map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.hasPrefix("- UTTypeIdentifier:") }
        #expect(declarations == Array(repeating: "- UTTypeIdentifier: " + identifier, count: 3), "\(declarations)")
    }

    /// Giá trị `EXAMSUITE_IOS_CONFIG_SUFFIX` theo tên cấu hình (`Debug:`, `Release:`) trong khối target ExamSuiteiOS,
    /// bỏ dấu nháy (`""` là đuôi rỗng).
    static func iosConfigSuffixes(_ lines: [String]) throws -> [String: String] {
        let block = try #require(targetBlock("ExamSuiteiOS", in: lines), "project.yml thiếu target ExamSuiteiOS")
        let key = "EXAMSUITE_IOS_CONFIG_SUFFIX:"
        var config: String?
        var result: [String: String] = [:]
        for line in block.map({ $0.trimmingCharacters(in: .whitespaces) }) {
            if line == "Debug:" || line == "Release:" {
                config = String(line.dropLast())
            } else if line.hasPrefix(key), let config {
                result[config] = line.dropFirst(key.count).trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            }
        }
        return result
    }

    /// Các dòng của project.yml ở gốc repo.
    private static func projectLines() throws -> [String] {
        let projectURL = RepoFixtures.root.deletingLastPathComponent().appendingPathComponent("project.yml")
        return try String(contentsOf: projectURL, encoding: .utf8).components(separatedBy: "\n")
    }

    /// Các dòng của khối target `name` (thụt 2 dấu cách dưới `targets:`), tới target kế tiếp hay khoá gốc kế tiếp; dòng
    /// comment không cắt khối.
    private static func targetBlock(_ name: String, in lines: [String]) -> ArraySlice<String>? {
        guard let start = lines.firstIndex(of: "  \(name):") else { return nil }
        let rest = lines[(start + 1)...]
        let end = rest.firstIndex { line in
            let isComment = line.trimmingCharacters(in: .whitespaces).hasPrefix("#")
            let isTarget = line.hasPrefix("  ") && !line.hasPrefix("   ")
            let isRootKey = !line.isEmpty && !line.hasPrefix(" ")
            return !isComment && (isTarget || isRootKey)
        } ?? lines.endIndex
        return lines[(start + 1) ..< end]
    }

    // MARK: - File thay hộp chọn file (bước 5b, chỉ build Debug, chỉ chế độ cô lập)

    @Test("Bản Admin cô lập: file thay hộp chọn file đọc từ tham số, nằm trong thư mục tạm")
    func chosenFileInsideDirectory() throws {
        let workspace = try TestWorkspace()
        let directory = try isolatedDirectory(workspace)
        let files = directory.appendingPathComponent("Files", isDirectory: true)
        try FileManager.default.createDirectory(at: files, withIntermediateDirectories: true)
        let image = files.appendingPathComponent("hinh.png")
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: image)
        let storage = try AppLaunchStorage.resolve(
            .admin,
            arguments: [
                UITestLaunchOptions.directoryArgument, directory.path,
                UITestLaunchOptions.chosenFileArgument, image.path,
            ],
            bundleIdentifier: adminUITestBundleID
        )
        #expect(storage.isUITest)
        #expect(storage.uiTestChosenFile?.path == ExamFileInspector.canonical(image).path)
        // Không có tham số thì không có file thay hộp chọn file, kể cả ở chế độ cô lập.
        let plain = try AppLaunchStorage.resolve(
            .admin,
            arguments: [UITestLaunchOptions.directoryArgument, directory.path],
            bundleIdentifier: adminUITestBundleID
        )
        #expect(plain.isUITest)
        #expect(plain.uiTestChosenFile == nil)
    }

    @Test("File thay hộp chọn file: thiếu thư mục cô lập, ngoài thư mục, không có file, bundle ID thật thì từ chối")
    func chosenFileRejected() throws {
        let workspace = try TestWorkspace()
        let directory = try isolatedDirectory(workspace)
        let outside = workspace.root.appendingPathComponent("ngoai.png")
        try Data([1, 2, 3]).write(to: outside)
        let inside = directory.appendingPathComponent("trong.png")
        try Data([1, 2, 3]).write(to: inside)
        // Liên kết trong thư mục cô lập trỏ ra ngoài: chuẩn hoá rồi mới so, nên vẫn bị từ chối.
        let link = directory.appendingPathComponent("lien-ket.png")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)
        let flag = UITestLaunchOptions.directoryArgument
        let chosen = UITestLaunchOptions.chosenFileArgument
        typealias Failure = UITestLaunchOptions.Failure
        func failure(_ arguments: [String], bundleID: String? = "vn.io.nt0.examsuite.admin.uitest") -> Failure? {
            do {
                _ = try AppLaunchStorage.resolve(.admin, arguments: arguments, bundleIdentifier: bundleID)
                return nil
            } catch {
                return error as? Failure
            }
        }
        // Chạy bình thường (không có thư mục cô lập) mà có tham số: dừng, không bao giờ dùng file đó. Bản thật cũng vậy.
        #expect(failure([chosen, inside.path]) == .chosenFileWithoutDirectory)
        for real in [LibraryConfiguration.adminBundleIdentifier, LibraryConfiguration.studentBundleIdentifier] {
            #expect(failure([chosen, inside.path], bundleID: real) == .chosenFileWithoutDirectory)
            #expect(failure([flag, directory.path, chosen, inside.path], bundleID: real) == .productionBundleIdentifier(real))
        }
        #expect(failure([flag, directory.path, chosen, outside.path]) == .chosenFileOutsideDirectory(outside.path))
        #expect(failure([flag, directory.path, chosen, link.path]) == .chosenFileOutsideDirectory(link.path))
        let traversal = directory.path + "/../ngoai.png"
        #expect(failure([flag, directory.path, chosen, traversal]) == .chosenFileOutsideDirectory(traversal))
        #expect(failure([flag, directory.path, chosen, "trong.png"]) == .chosenFileOutsideDirectory("trong.png"))
        let missing = directory.appendingPathComponent("khong-co.png").path
        #expect(failure([flag, directory.path, chosen, missing]) == .chosenFileMissing(missing))
        // Thư mục không phải file.
        #expect(failure([flag, directory.path, chosen, directory.path]) == .chosenFileMissing(directory.path))
        // Liên kết cứng tới file ngoài thư mục: `realpath` không lộ, nên từ chối file có hơn một liên kết cứng.
        let hardLink = directory.appendingPathComponent("lien-ket-cung.png")
        try FileManager.default.linkItem(at: outside, to: hardLink)
        #expect(failure([flag, directory.path, chosen, hardLink.path]) == .chosenFileNotPlainFile(hardLink.path))
        #expect(failure([flag, directory.path, chosen, inside.path]) == nil)
    }

    @Test("File thay hộp chọn file được kiểm lại mỗi lần dùng: bị thay bằng liên kết ra ngoài, liên kết cứng hay xoá thì không dùng")
    func chosenFileRevalidatedAtUse() throws {
        let workspace = try TestWorkspace()
        let directory = try isolatedDirectory(workspace)
        let outside = workspace.root.appendingPathComponent("ngoai.png")
        try Data([9, 9, 9]).write(to: outside)
        let image = directory.appendingPathComponent("hinh.png")
        try Data([1, 2, 3]).write(to: image)
        let storage = try AppLaunchStorage.resolve(
            .admin,
            arguments: [
                UITestLaunchOptions.directoryArgument, directory.path,
                UITestLaunchOptions.chosenFileArgument, image.path,
            ],
            bundleIdentifier: adminUITestBundleID
        )
        let expected = ExamFileInspector.canonical(image).path
        #expect(storage.uiTestDirectory?.path == ExamFileInspector.canonical(directory).path)
        #expect(storage.revalidatedUITestChosenFile()?.path == expected)
        let manager = FileManager.default
        // Sau khi app khởi động, file bị thay bằng liên kết tượng trưng ra ngoài thư mục.
        try manager.removeItem(at: image)
        try manager.createSymbolicLink(at: image, withDestinationURL: outside)
        #expect(storage.revalidatedUITestChosenFile() == nil)
        // Thay bằng liên kết cứng tới file ngoài thư mục.
        try manager.removeItem(at: image)
        try manager.linkItem(at: outside, to: image)
        #expect(storage.revalidatedUITestChosenFile() == nil)
        // Bị xoá.
        try manager.removeItem(at: image)
        #expect(storage.revalidatedUITestChosenFile() == nil)
        // File thường trở lại: dùng được.
        try Data([4, 5, 6]).write(to: image)
        #expect(storage.revalidatedUITestChosenFile()?.path == expected)
        // Không có móc (chạy bình thường hay cô lập không có tham số): luôn nil.
        #expect(AppLaunchStorage.standard(.admin).revalidatedUITestChosenFile() == nil)
    }

    /// Bản Release không được có đường đi nào tới file thay hộp chọn file: mọi chỗ nhắc tới nó trong code app nằm trong
    /// `#if DEBUG` (Release không biên dịch). Kiểm trên mã nguồn vì test chỉ chạy ở build Debug.
    @Test("File thay hộp chọn file chỉ có trong code #if DEBUG (Release không biên dịch)")
    func chosenFileHookIsDebugOnly() throws {
        let sources = RepoFixtures.root.deletingLastPathComponent().appendingPathComponent("Packages/ExamFeatures/Sources")
        let markers = [
            "uiTestChosenFile", "uiTestDirectory", "uiTestChooseImageFile", "chosenFileArgument",
            "ExamSuiteUITestChosenFile", "validatedChosenFile", "revalidatedChosenFile", "revalidatedUITestChosenFile",
        ]
        var found = 0
        let enumerator = try #require(FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil))
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            let lines = try String(contentsOf: url, encoding: .utf8).components(separatedBy: "\n")
            for (number, isDebugOnly) in Self.debugOnlyLines(lines) {
                let trimmed = lines[number].trimmingCharacters(in: .whitespaces)
                guard !trimmed.hasPrefix("//"), markers.contains(where: trimmed.contains) else { continue }
                if isDebugOnly {
                    found += 1
                } else {
                    Issue.record("\(url.lastPathComponent):\(number + 1) nhắc tới file thay hộp chọn file ngoài #if DEBUG: \(trimmed)")
                }
            }
        }
        // Có dùng thật (LibraryData, AuthoringFeature, AdminShell); bộ đếm 0 nghĩa là kiểm nhầm chỗ.
        #expect(found >= 6)
        // Đối chứng âm: bộ phân tích nhận ra dòng ngoài #if DEBUG và nhánh #else.
        let sample = ["#if DEBUG", "a", "#else", "b", "#endif", "c", "#if os(macOS)", "#if DEBUG", "d", "#endif", "e", "#endif"]
        let flags = Dictionary(uniqueKeysWithValues: Self.debugOnlyLines(sample).map { (sample[$0.0], $0.1) })
        #expect(flags["a"] == true && flags["d"] == true)
        #expect(flags["b"] == false && flags["c"] == false && flags["e"] == false)
    }

    /// Mỗi dòng (chỉ số) và việc nó có nằm trong nhánh `#if DEBUG` (kể cả lồng trong điều kiện khác) hay không.
    private static func debugOnlyLines(_ lines: [String]) -> [(Int, Bool)] {
        var stack: [Bool] = [] // mỗi tầng #if: nhánh hiện tại là nhánh DEBUG dương
        var result: [(Int, Bool)] = []
        for (number, raw) in lines.enumerated() {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("#if ") {
                stack.append(line == "#if DEBUG")
            } else if line.hasPrefix("#elseif") || line == "#else" {
                if !stack.isEmpty { stack[stack.count - 1] = false }
            } else if line == "#endif" {
                _ = stack.popLast()
            } else {
                result.append((number, stack.contains(true)))
            }
        }
        return result
    }

    /// UI test bản Admin (Apps/UITestSupport/IsolatedApp.swift, không link LibraryData) ghi cứng tên tham số.
    @Test("UI test dùng đúng tên tham số file thay hộp chọn file")
    func uiTestSupportMatchesChosenFileArgument() throws {
        let supportURL = RepoFixtures.root.deletingLastPathComponent()
            .appendingPathComponent("Apps/UITestSupport/IsolatedApp.swift")
        let source = try String(contentsOf: supportURL, encoding: .utf8)
        #expect(source.contains("static let chosenFileArgument = \"\(UITestLaunchOptions.chosenFileArgument)\""))
    }
}
