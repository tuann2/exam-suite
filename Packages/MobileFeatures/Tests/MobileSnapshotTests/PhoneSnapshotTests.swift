import ExamFile
import ExamKit
import Foundation
import InterfaceCore
import LibraryData
@testable import MobileFeature
@testable import SessionModel
import SnapshotTesting
import SwiftUI
import Testing
import UIKit

/// Snapshot iPhone sáng/tối (docs/product/plan-ios-v1.md Phần 5; ADR 0010): câu dài 10 lựa chọn, ảnh lớn, Kết quả nhiều
/// phần, Xem lại đề ẩn đáp án, Thư viện danh sách; cỡ chữ trợ năng `accessibility1` (UIKit `accessibilityMedium`,
/// ~165%, QI11) ở làm bài và Kết quả. Simulator cố định (iPhone 17, iOS 26.1: `EXAMSUITE_IOS_DESTINATION` của
/// verify_local.sh); ảnh 1x để file nhỏ. Ghi lại ảnh: `TEST_RUNNER_EXAMSUITE_SNAPSHOT_RECORD=all` (simulator chỉ nhận
/// biến môi trường có tiền tố `TEST_RUNNER_`) rồi xem ảnh trước khi commit (docs/process/snapshot-tests.md).
@MainActor
@Suite("Snapshot iPhone", .serialized)
struct PhoneSnapshotTests {
    // MARK: - Làm bài

    @Test(arguments: PhoneAppearance.allCases)
    func attemptLongQuestion(appearance: PhoneAppearance) async throws {
        let harness = SessionHarness()
        let attempt = try await harness.start(SnapshotContent.attemptPackage(), mode: .practice)
        _ = attempt.selectOption(atPosition: 2)
        await PhoneSnapshot.assert(
            attemptScreen(harness, attempt),
            named: "attempt-long-\(appearance.rawValue)", appearance
        )
    }

    @Test(arguments: PhoneAppearance.allCases)
    func attemptLargeImage(appearance: PhoneAppearance) async throws {
        let harness = SessionHarness()
        let attempt = try await harness.start(SnapshotContent.attemptPackage(), mode: .exam)
        _ = attempt.goTo(index: 1)
        await PhoneSnapshot.assert(
            attemptScreen(harness, attempt),
            named: "attempt-image-\(appearance.rawValue)", appearance
        )
    }

    @Test func attemptLongQuestionLargeText() async throws {
        let harness = SessionHarness()
        let attempt = try await harness.start(SnapshotContent.attemptPackage(), mode: .practice)
        await PhoneSnapshot.assert(
            attemptScreen(harness, attempt),
            named: "attempt-long-largeText", .light, largeText: true
        )
    }

    // MARK: - Kết quả, Xem lại

    @Test(arguments: PhoneAppearance.allCases)
    func resultsManySections(appearance: PhoneAppearance) async throws {
        let harness = SessionHarness()
        let session = try await harness.submittedSession(
            package: ExamPackage(exam: SnapshotContent.manySectionsExam()), previousPercent: 55)
        try await PhoneSnapshot.assert(
            resultsScreen(harness, session),
            named: "results-\(appearance.rawValue)", appearance
        )
    }

    @Test func resultsLargeText() async throws {
        let harness = SessionHarness()
        let session = try await harness.submittedSession(package: ExamPackage(exam: SnapshotContent.manySectionsExam()))
        try await PhoneSnapshot.assert(
            resultsScreen(harness, session),
            named: "results-largeText", .light, largeText: true
        )
    }

    /// Đề ẩn đáp án: chỉ lựa chọn của bạn và đúng/sai, không có "Đáp án đúng" và giải thích (exam-taking.md phương án 4).
    @Test(arguments: PhoneAppearance.allCases)
    func reviewHideAnswers(appearance: PhoneAppearance) async throws {
        let harness = SessionHarness()
        let session = try await harness.submittedSession(
            package: ExamPackage(exam: SnapshotContent.manySectionsExam(hideAnswers: true)))
        #expect(await session.openAnswerReview(filter: .all))
        let review = try #require(session.answerReview)
        review.select(index: 1)
        let view = NavigationStack { ReviewDetailScreen(review: review) }
        await PhoneSnapshot.assert(view, named: "review-hideAnswers-\(appearance.rawValue)", appearance)
    }

    // MARK: - Thư viện

    /// Không đặt trong `NavigationStack`: ở đó `.searchable` cùng `.refreshable` làm `render(in:)` không vẽ gì của nội
    /// dung (thử 2026-10-31; từng modifier riêng thì vẽ được). Ảnh có danh sách, trạng thái file, thanh thông báo; thanh
    /// điều hướng và ô tìm không có (ở mọi màn, thanh điều hướng của iOS 26 không vào ảnh: docs/process/snapshot-tests.md).
    @Test(arguments: PhoneAppearance.allCases)
    func libraryList(appearance: PhoneAppearance) async throws {
        let fixture = try LibraryFixture()
        let view = LibraryScreen(library: fixture.library, sessions: fixture.sessions, storage: fixture.storage)
            .defaultAppStorage(fixture.defaults)
        await PhoneSnapshot.assert(view, named: "library-\(appearance.rawValue)", appearance)
    }

    // MARK: - Dựng màn

    private func attemptScreen(_ harness: SessionHarness, _ attempt: AttemptModel) -> some View {
        NavigationStack {
            AttemptScreen(session: harness.session(for: attempt), attempt: attempt)
                .navigationTitle(attempt.exam.title)
                .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func resultsScreen(_ harness: SessionHarness, _ session: MobileSession) throws -> some View {
        let results = try #require(session.results)
        let sessions = MobileSessionCoordinator(environment: harness.environment)
        return NavigationStack { ResultsScreen(session: session, results: results, sessions: sessions) }
    }
}

/// Thư viện cố định: các đề và lần thi như snapshot Thư viện của bản macOS (`LibrarySnapshotTests`), kho trong bộ nhớ.
@MainActor
final class LibraryFixture {
    let library: LibraryModel
    let sessions: MobileSessionCoordinator
    let storage: AppLaunchStorage
    let defaults: UserDefaults
    private let directory: URL

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MobileSnapshotTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defaults = UserDefaults(suiteName: directory.appendingPathComponent("defaults.plist").path)!
        let configuration = LibraryConfiguration.forApp(
            bundleIdentifier: "vn.io.nt0.examsuite.snapshot",
            isAdmin: false,
            applicationSupportDirectory: directory
        )
        let store = LibraryStore.preview(entries: Self.entries(), attempts: Self.attempts(), configuration: configuration)
        library = LibraryModel(store: store, startsAutomatically: false, now: { fixedNow })
        sessions = MobileSessionCoordinator(environment: SessionHarness().environment)
        storage = AppLaunchStorage(configuration: configuration, defaults: defaults)
        library.sessionActions = LibrarySessionActions(openPreExam: { _, _ in }, openAttempt: { _ in })
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    private static let day: TimeInterval = 86_400

    private static func entry(
        _ n: Int, _ title: String, code: String?, questions: Int, sections: Int, minutes: Int, pass: Int,
        sample: Bool = false, status: LibraryEntryStatus = .ready
    ) -> LibraryEntry {
        LibraryEntry(
            examID: fixedID(n),
            summary: ExamSummary(
                title: title, code: code, questionCount: questions, sectionCount: sections,
                timeLimitMinutes: minutes, passPercent: pass
            ),
            fileURL: URL(fileURLWithPath: "/private/var/mobile/Documents/\(code ?? "de-\(n)").exam"),
            fileSize: Int64(questions) * 2_048,
            isSample: sample,
            addedAt: fixedNow.addingTimeInterval(-Double(n) * day),
            status: status
        )
    }

    static func entries() -> [LibraryEntry] {
        [
            entry(1, "Kiến thức chung (đề mẫu)", code: "MAU-01", questions: 20, sections: 2, minutes: 15, pass: 60,
                  sample: true),
            entry(2, "Nghiệp vụ ngoại thương — Đề tổng hợp", code: "NVNT-2026", questions: 40, sections: 3, minutes: 90,
                  pass: 70),
            entry(3, "Ôn thi kế toán viên — Bộ đề 3", code: "KTV-03", questions: 40, sections: 8, minutes: 120, pass: 60),
            entry(5, "An toàn thông tin cơ bản", code: nil, questions: 25, sections: 1, minutes: 30, pass: 80,
                  status: .missing),
            entry(6, "Tiếng Anh chuyên ngành logistics", code: "ENG-LOG", questions: 60, sections: 4, minutes: 45,
                  pass: 65, status: .invalid(reason: .stored("Câu 12 có hai đáp án đúng nhưng là câu một đáp án."))),
        ]
    }

    static func attempts() -> [Attempt] {
        [
            attempt(examID: 2, title: "Nghiệp vụ ngoại thương — Đề tổng hợp", percent: 82, daysAgo: 1),
            attempt(examID: 3, title: "Ôn thi kế toán viên — Bộ đề 3", percent: 45, daysAgo: 3),
        ]
    }

    private static func attempt(examID: Int, title: String, percent: Int, daysAgo: Double) -> Attempt {
        let submitted = fixedNow.addingTimeInterval(-daysAgo * day)
        return Attempt(
            id: fixedID(700 + examID * 10 + percent % 10),
            examID: fixedID(examID),
            examTitle: title,
            candidateName: "Nguyễn Thị Minh Khai",
            mode: .exam,
            startedAt: submitted.addingTimeInterval(-1_800),
            submittedAt: submitted,
            elapsedSeconds: 1_800,
            correct: percent * 40 / 100,
            total: 40,
            score1000: percent * 10,
            percent: percent,
            passed: percent >= 60
        )
    }
}

/// Giao diện sáng/tối của một ảnh chụp.
enum PhoneAppearance: String, CaseIterable, Sendable {
    case light
    case dark
}

/// Chụp một màn SwiftUI cỡ iPhone (390×844 pt, vùng an toàn như iPhone có Dynamic Island, ảnh 1x) rồi so với ảnh tham
/// chiếu trong `__Snapshots__/` (ADR 0010: so theo độ chính xác cảm nhận 0,98).
///
/// Màn được đặt vào một cửa sổ và chụp lại tới khi hai lần chụp liên tiếp giống nhau: `List` (UICollectionView), tiêu
/// đề và nút của thanh điều hướng chỉ có sau một vòng runloop, nên chụp ngay sau khi dựng (cách của
/// `Snapshotting.image(on:)`) ra danh sách trống, thiếu tiêu đề.
@MainActor
enum PhoneSnapshot {
    static let recordVariable = "EXAMSUITE_SNAPSHOT_RECORD"
    static let size = CGSize(width: 390, height: 844)

    static var record: SnapshotTestingConfiguration.Record {
        switch ProcessInfo.processInfo.environment[recordVariable] {
        case "all": .all
        case "failed": .failed
        case "missing": .missing
        default: .never
        }
    }

    static func assert(
        _ view: some View,
        named name: String,
        _ appearance: PhoneAppearance,
        largeText: Bool = false,
        fileID: StaticString = #fileID,
        file: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) async {
        let window = PhoneWindow(frame: CGRect(origin: .zero, size: size))
        window.traitOverrides.userInterfaceStyle = appearance == .dark ? .dark : .light
        window.traitOverrides.displayScale = 1
        window.traitOverrides.preferredContentSizeCategory = largeText ? .accessibilityMedium : .large
        // Như gốc của app (`MobileRootView`): màu nhấn teal của bảng màu số.
        window.rootViewController = UIHostingController(rootView: view
            .tint(MobilePalette.accent)
            .environment(\.locale, Locale(identifier: "vi"))
            .environment(\.timeZone, TimeZone(identifier: "Asia/Ho_Chi_Minh")!)
            .transaction { $0.disablesAnimations = true })
        window.isHidden = false
        defer { window.isHidden = true }
        let image = await stableImage(of: window)
        withSnapshotTesting(record: record) {
            assertSnapshot(
                of: image,
                as: .image(precision: 1, perceptualPrecision: 0.98),
                named: name,
                fileID: fileID,
                file: file,
                testName: testName,
                line: line,
                column: column
            )
        }
    }

    /// Chụp tới khi hai lần liên tiếp giống từng byte (tối đa 20 lần, mỗi lần cách một vòng runloop).
    private static func stableImage(of window: UIWindow) async -> UIImage {
        var previous: Data?
        var image = UIImage()
        for _ in 0..<20 {
            window.layoutIfNeeded()
            image = render(window)
            let data = image.pngData()
            if let data, data == previous { break }
            previous = data
            try? await Task.sleep(for: .milliseconds(50))
        }
        return image
    }

    private static func render(_ window: UIWindow) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { context in
            window.layer.render(in: context.cgContext)
        }
    }
}

/// Cửa sổ có vùng an toàn của iPhone có Dynamic Island ở chiều dọc (trên 47 pt, dưới 34 pt), như cấu hình `.iPhone13`
/// của swift-snapshot-testing.
private final class PhoneWindow: UIWindow {
    override var safeAreaInsets: UIEdgeInsets {
        UIEdgeInsets(top: 47, left: 0, bottom: 34, right: 0)
    }
}
