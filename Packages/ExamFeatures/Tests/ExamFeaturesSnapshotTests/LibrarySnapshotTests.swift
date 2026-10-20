import ExamKit
import Foundation
import LibraryData
@testable import LibraryFeature
import SwiftUI
import Testing

/// Cửa sổ Thư viện ở 960×640, sáng và tối: lưới thẻ và danh sách (docs/product/library.md), cùng một bộ đề có đủ
/// trạng thái (Sẵn sàng, Đề mẫu, Không tìm thấy file, Không hợp lệ), tên dài, lần thi gần nhất.
extension SnapshotSuite {
    @MainActor
    @Suite("Snapshot: Thư viện")
    struct LibrarySnapshotTests {
        @Test func libraryGrid() async throws {
            let fixture = try LibraryFixture(viewMode: .grid)
            await SnapshotHost.assertLightAndDark {
                LibraryRootView(model: fixture.model)
                    .defaultAppStorage(fixture.defaults)
            }
        }

        @Test func libraryList() async throws {
            let fixture = try LibraryFixture(viewMode: .list)
            await SnapshotHost.assertLightAndDark {
                LibraryRootView(model: fixture.model)
                    .defaultAppStorage(fixture.defaults)
            }
        }
    }
}

/// Thư viện dựng sẵn trong bộ nhớ (`LibraryStore.preview`, không đọc/ghi file), cài đặt `@AppStorage` trong một file
/// tạm riêng (không đụng `defaults` của app hay của tiến trình test).
@MainActor
final class LibraryFixture {
    let model: LibraryModel
    let defaults: UserDefaults
    private let directory: URL

    init(viewMode: LibraryViewMode) throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ExamFeaturesSnapshotTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defaults = UserDefaults(suiteName: directory.appendingPathComponent("defaults.plist").path)!
        defaults.set(viewMode.rawValue, forKey: LibraryPreferenceKey.viewMode)
        defaults.set(LibrarySortOrder.name.rawValue, forKey: LibraryPreferenceKey.sortOrder)
        defaults.set(WelcomeBannerState.dismissed.rawValue, forKey: LibraryPreferenceKey.welcomeBanner)
        let configuration = LibraryConfiguration.forApp(
            bundleIdentifier: "vn.io.nt0.examsuite.snapshot",
            isAdmin: false,
            applicationSupportDirectory: directory
        )
        let store = LibraryStore.preview(entries: Self.entries(), attempts: Self.attempts(), configuration: configuration)
        model = LibraryModel(store: store, startsAutomatically: false, revealFiles: { _ in }, now: { fixedNow })
        // Như app: nút Luyện tập/Thi bật (lệnh làm bài không làm gì trong test); một thẻ đang chọn.
        model.sessionActions = LibrarySessionActions(openPreExam: { _, _ in }, openAttempt: { _ in })
        model.selection = fixedID(2)
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    private static let day: TimeInterval = 86_400

    private static func entry(
        _ n: Int,
        _ title: String,
        code: String?,
        questions: Int,
        sections: Int,
        minutes: Int,
        pass: Int,
        sample: Bool = false,
        status: LibraryEntryStatus = .ready
    ) -> LibraryEntry {
        LibraryEntry(
            examID: fixedID(n),
            summary: ExamSummary(
                title: title, code: code, questionCount: questions, sectionCount: sections,
                timeLimitMinutes: minutes, passPercent: pass
            ),
            fileURL: URL(fileURLWithPath: "/Users/hocvien/Documents/De thi/\(code ?? "de-\(n)").exam"),
            fileSize: Int64(questions) * 2_048,
            isSample: sample,
            addedAt: fixedNow.addingTimeInterval(-Double(n) * day),
            lastOpenedAt: n.isMultiple(of: 2) ? fixedNow.addingTimeInterval(-Double(n) * 3_600) : nil,
            status: status
        )
    }

    static func entries() -> [LibraryEntry] {
        [
            entry(1, "Kiến thức chung (đề mẫu)", code: "MAU-01", questions: 20, sections: 2, minutes: 15, pass: 60, sample: true),
            entry(2, "Nghiệp vụ ngoại thương — Đề tổng hợp", code: "NVNT-2026", questions: 40, sections: 3, minutes: 90, pass: 70),
            entry(3, "Ôn thi kế toán viên — Bộ đề 3", code: "KTV-03", questions: 40, sections: 8, minutes: 120, pass: 60),
            entry(
                4, "Luật Doanh nghiệp 2020 và các văn bản hướng dẫn thi hành mới nhất, cập nhật đến hết quý III/2026",
                code: "LDN-2020", questions: 2_000, sections: 20, minutes: 180, pass: 75
            ),
            entry(5, "An toàn thông tin cơ bản", code: nil, questions: 25, sections: 1, minutes: 30, pass: 80, status: .missing),
            entry(
                6, "Tiếng Anh chuyên ngành logistics", code: "ENG-LOG", questions: 60, sections: 4, minutes: 45, pass: 65,
                // Lý do dạng chữ có sẵn (`.stored` hiện nguyên chữ) để ảnh tham chiếu không đổi qua bước 7b.
                status: .invalid(reason: .stored("Câu 12 có hai đáp án đúng nhưng là câu một đáp án."))
            ),
            entry(7, "Quy trình nội bộ phòng kho", code: "QT-KHO", questions: 15, sections: 2, minutes: 20, pass: 70),
        ]
    }

    static func attempts() -> [Attempt] {
        [
            attempt(examID: 2, title: "Nghiệp vụ ngoại thương — Đề tổng hợp", percent: 82, daysAgo: 1),
            attempt(examID: 3, title: "Ôn thi kế toán viên — Bộ đề 3", percent: 45, daysAgo: 3),
            attempt(examID: 3, title: "Ôn thi kế toán viên — Bộ đề 3", percent: 67, daysAgo: 0.2),
            attempt(examID: 7, title: "Quy trình nội bộ phòng kho", percent: 100, daysAgo: 12),
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
