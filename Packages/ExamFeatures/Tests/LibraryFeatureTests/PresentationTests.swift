import AppKit
import ExamFile
import ExamKit
import Foundation
@testable import InterfaceCore
import LibraryData
import Testing

/// Ánh xạ trạng thái → biểu tượng + chữ + bước tiếp theo, chuỗi hiển thị và câu đọc VoiceOver
/// (docs/product/library.md, mục Thẻ đề và Bàn phím và trợ năng).
@Suite("Trạng thái, chuỗi hiển thị, câu đọc VoiceOver")
struct PresentationTests {
    static let vietnamese = Locale(identifier: "vi_VN")
    static let utc = TimeZone(identifier: "UTC")!
    /// 15/10/2026 08:30 UTC.
    static let day = Date(timeIntervalSince1970: 1_792_053_000)

    /// Lý do có mã (bước 7b): zip hỏng; trường lạ.
    static let notZip = FileProblemReason.package(.notAZipArchive)
    static let unknownField = FileProblemReason.package(.unknownFields(["ghiChu"]))

    static let studentStatuses: [LibraryEntryStatus] = [
        .ready, .checking, .missing, .corrupt(reason: notZip),
        .needsNewerApp(found: 2, supported: 1), .invalid(reason: unknownField),
    ]
    static let adminStatuses: [LibraryEntryStatus] = [
        .ready, .checking, .missing, .corrupt(reason: notZip),
        .needsNewerApp(found: 2, supported: 1), .readableWithIssues(reason: unknownField),
    ]

    @Test("Bảng trạng thái của library.md: chữ, bước tiếp theo theo từng bản app")
    func statusTable() {
        func make(_ status: LibraryEntryStatus, admin: Bool = false) -> EntryStatusPresentation {
            EntryStatusPresentation(status: status, isAdmin: admin)
        }
        #expect(make(.ready).title == "Sẵn sàng")
        #expect(make(.ready).nextSteps.isEmpty)
        #expect(make(.ready).detail == nil)
        #expect(make(.checking).title == "Đang kiểm tra")
        #expect(make(.checking).nextSteps.isEmpty)
        #expect(make(.missing).title == "Không tìm thấy file")
        #expect(make(.missing).nextSteps == [.locateFile, .removeFromLibrary])
        #expect(make(.corrupt(reason: Self.notZip)).title == "File hỏng")
        #expect(make(.corrupt(reason: Self.notZip)).detail == "File không phải gói đề .exam hợp lệ (không đọc được dạng zip).")
        #expect(make(.corrupt(reason: Self.notZip)).nextSteps == [.removeFromLibrary])
        let newer = make(.needsNewerApp(found: 2, supported: 1))
        #expect(newer.title == "Cần app mới hơn")
        #expect(newer.detail == "Đề cần phiên bản app mới hơn (định dạng v2, app này hiểu tới v1).")
        #expect(newer.nextSteps == [.updateApp, .removeFromLibrary])
        #expect(make(.invalid(reason: Self.unknownField)).title == "Đề có lỗi")
        #expect(make(.invalid(reason: Self.unknownField)).detail == "Đề có trường không được hỗ trợ: ghiChu.")
        #expect(make(.invalid(reason: Self.unknownField)).nextSteps == [.removeFromLibrary])
        let adminIssues = make(.readableWithIssues(reason: Self.unknownField), admin: true)
        #expect(adminIssues.title == "Có lỗi")
        #expect(adminIssues.detail == "Bản Học viên sẽ không mở được đề này: Đề có trường không được hỗ trợ: ghiChu.")
        #expect(adminIssues.nextSteps == [.edit])
    }

    @Test("Mỗi trạng thái có biểu tượng SF Symbol có thật và chữ; không hai trạng thái nào cùng biểu tượng",
          arguments: [false, true])
    func iconsAreDistinctAndExist(isAdmin: Bool) {
        let statuses = isAdmin ? Self.adminStatuses : Self.studentStatuses
        let presentations = statuses.map { EntryStatusPresentation(status: $0, isAdmin: isAdmin) }
        for presentation in presentations {
            #expect(!presentation.title.isEmpty)
            #expect(
                NSImage(systemSymbolName: presentation.systemImage, accessibilityDescription: nil) != nil,
                "Không có SF Symbol \(presentation.systemImage)"
            )
        }
        #expect(Set(presentations.map(\.systemImage)).count == presentations.count)
        #expect(Set(presentations.map(\.title)).count == presentations.count)
        #expect(Set(presentations.map(\.sortRank)).count == presentations.count)
        // Sẵn sàng xếp trước mọi vấn đề khi sắp theo cột Trạng thái.
        #expect(presentations.allSatisfy { $0.sortRank >= presentations[0].sortRank })
    }

    @Test("Biểu tượng dùng ở sidebar, kết quả thi và menu đều có thật")
    func otherSymbolsExist() {
        let symbols = LibrarySection.allCases.map(\.systemImage) + [
            LibraryFormat.resultSymbol(passed: true), LibraryFormat.resultSymbol(passed: false),
            "info.circle", "folder", "list.bullet.rectangle", "magnifyingglass", "pencil", "trash",
            "ellipsis.circle", "circle.dashed", "externaldrive.badge.exclamationmark", "sparkles",
            "square.and.arrow.down", "line.3.horizontal.decrease.circle",
            "line.3.horizontal.decrease.circle.fill", "arrow.up.arrow.down", "square.grid.2x2",
            "list.bullet", "plus", "xmark", "questionmark.folder", "books.vertical",
        ]
        for symbol in symbols {
            #expect(NSImage(systemSymbolName: symbol, accessibilityDescription: nil) != nil, "\(symbol)")
        }
    }

    @Test("Chuỗi hiển thị tiếng Việt: số câu, phần, phút, ngưỡng đậu, điểm, chế độ, kết quả")
    func formatting() {
        #expect(LibraryFormat.questions(12) == "12 câu")
        #expect(LibraryFormat.sections(2) == "2 phần")
        #expect(LibraryFormat.images(1) == "1 ảnh")
        #expect(LibraryFormat.minutes(30) == "30 phút")
        #expect(LibraryFormat.passThreshold(70) == "Đậu từ 70%")
        #expect(LibraryFormat.percent(85) == "85%")
        #expect(LibraryFormat.mode(.practice) == "Luyện tập")
        #expect(LibraryFormat.mode(.exam) == "Thi")
        #expect(LibraryFormat.result(passed: true) == "Đậu")
        #expect(LibraryFormat.result(passed: false) == "Trượt")
        #expect(LibraryFormat.resultSymbol(passed: true) != LibraryFormat.resultSymbol(passed: false))
        let summary = ExamSummary(title: "Đề", questionCount: 12, sectionCount: 2, timeLimitMinutes: 30, passPercent: 70)
        #expect(LibraryFormat.facts(summary) == "12 câu · 2 phần · 30 phút · Đậu từ 70%")
        #expect(LibraryFormat.fileSize(nil) == "Chưa rõ")
    }

    @Test("Thời gian làm bài làm tròn tới giây, bỏ đơn vị bằng 0")
    func durations() {
        #expect(LibraryFormat.duration(seconds: 0) == "0 giây")
        #expect(LibraryFormat.duration(seconds: 44.6) == "45 giây")
        #expect(LibraryFormat.duration(seconds: 299.5) == "5 phút")
        #expect(LibraryFormat.duration(seconds: 725) == "12 phút 5 giây")
        #expect(LibraryFormat.duration(seconds: 3600) == "1 giờ")
        #expect(LibraryFormat.duration(seconds: 3900) == "1 giờ 5 phút")
        #expect(LibraryFormat.duration(seconds: -3) == "0 giây")
    }

    @Test("Ngày và lần thi gần nhất theo locale truyền vào")
    func datesAndLastAttempt() {
        #expect(LibraryFormat.date(Self.day, locale: Self.vietnamese, timeZone: Self.utc) == "15/10/2026")
        let attempt = Self.attempt(percent: 80, passed: true)
        #expect(LibraryFormat.lastAttempt(attempt, locale: Self.vietnamese, timeZone: Self.utc) == "80% · 15/10/2026 · Đậu")
        #expect(LibraryFormat.lastAttempt(nil) == "Chưa thi lần nào")
    }

    @Test("Câu VoiceOver của thẻ: tiêu đề, mã, số câu, trạng thái, lần thi gần nhất")
    func cardSummary() {
        let entry = Self.entry(title: "Kiến thức chung", code: "KTC01", questions: 12, status: .ready)
        let passed = LibraryAccessibility.cardSummary(
            entry: entry,
            latestAttempt: Self.attempt(percent: 80, passed: true),
            isAdmin: false,
            locale: Self.vietnamese,
            timeZone: Self.utc
        )
        #expect(passed == "Kiến thức chung, mã KTC01, 12 câu, Sẵn sàng. Lần thi gần nhất: 80%, Đậu, ngày 15/10/2026.")

        let missing = Self.entry(title: "Đề mất file", code: nil, questions: 3, status: .missing)
        #expect(LibraryAccessibility.cardSummary(entry: missing, latestAttempt: nil, isAdmin: false)
            == "Đề mất file, 3 câu, Không tìm thấy file: File không còn ở chỗ cũ: đã bị xoá, chuyển sang nơi khác hoặc nằm trên ổ chưa gắn. Chưa thi lần nào.")

        // Đề mẫu đọc thêm nhãn "đề mẫu"; lý do lỗi đọc ngay sau trạng thái.
        let sample = Self.entry(
            title: "Làm quen với Exam Suite",
            code: "LAMQUEN",
            questions: 12,
            status: .corrupt(reason: Self.notZip),
            isSample: true
        )
        #expect(LibraryAccessibility.cardSummary(entry: sample, latestAttempt: nil, isAdmin: false)
            == "Làm quen với Exam Suite, đề mẫu, mã LAMQUEN, 12 câu, File hỏng: File không phải gói đề .exam hợp lệ (không đọc được dạng zip). Chưa thi lần nào.")

        let failed = LibraryAccessibility.cardSummary(
            entry: Self.entry(title: "Đề", code: "", questions: 5, status: .readableWithIssues(reason: .stored("x"))),
            latestAttempt: Self.attempt(percent: 40, passed: false),
            isAdmin: true,
            locale: Self.vietnamese,
            timeZone: Self.utc
        )
        #expect(failed == "Đề, 5 câu, Có lỗi: Bản Học viên sẽ không mở được đề này: x. Lần thi gần nhất: 40%, Trượt, ngày 15/10/2026.")
    }

    @Test("Dải chào mừng: hiện sau lần đầu tạo đề mẫu, đóng rồi thì không hiện lại")
    func welcomeBanner() {
        var seeded = SampleReport()
        seeded.sampleCount = 2
        seeded.addedExamIDs = [UUID(), UUID()]
        let nothing = SampleReport()

        #expect(WelcomeBannerState.notShown.after(start: nil) == .notShown)
        #expect(WelcomeBannerState.notShown.after(start: nothing) == .notShown)
        #expect(WelcomeBannerState.notShown.after(start: seeded) == .visible)
        #expect(WelcomeBannerState.visible.after(start: nothing) == .visible)
        #expect(WelcomeBannerState.dismissed.after(start: seeded) == .dismissed)
        // Giá trị lưu bằng @AppStorage không đổi giữa các bản.
        #expect(WelcomeBannerState.allRawValues == ["notShown", "visible", "dismissed"])
        #expect(LibraryViewMode.allCases.map(\.rawValue) == ["grid", "list"])
    }

    @Test("Tên trên menu Sắp xếp và Lọc")
    func menuTitles() {
        #expect(LibrarySortOrder.allCases.map(\.title) == ["Gần đây", "Tên", "Điểm lần trước"])
        #expect(LibraryFilter.allCases.map(\.title) == ["Tất cả", "Sẵn sàng", "Có vấn đề"])
        #expect(LibrarySection.allCases.map(\.title) == ["Tất cả đề", "Gần đây", "Lịch sử thi"])
    }

    // MARK: - Dữ liệu mẫu

    static func entry(
        title: String,
        code: String?,
        questions: Int,
        status: LibraryEntryStatus,
        isSample: Bool = false
    ) -> LibraryEntry {
        LibraryEntry(
            examID: UUID(),
            summary: ExamSummary(
                title: title,
                code: code,
                questionCount: questions,
                sectionCount: 1,
                timeLimitMinutes: 10,
                passPercent: 60
            ),
            fileURL: URL(fileURLWithPath: "/tmp/de.exam"),
            isSample: isSample,
            addedAt: day,
            status: status
        )
    }

    static func attempt(percent: Int, passed: Bool) -> Attempt {
        Attempt(
            examID: UUID(),
            examTitle: "Đề",
            candidateName: "An",
            mode: .exam,
            startedAt: day.addingTimeInterval(-600),
            submittedAt: day,
            elapsedSeconds: 600,
            correct: percent / 10,
            total: 10,
            score1000: percent * 10,
            percent: percent,
            passed: passed
        )
    }
}

extension WelcomeBannerState {
    static var allRawValues: [String] {
        [WelcomeBannerState.notShown, .visible, .dismissed].map(\.rawValue)
    }
}
