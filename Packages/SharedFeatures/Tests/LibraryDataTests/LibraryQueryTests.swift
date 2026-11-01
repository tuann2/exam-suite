import ExamKit
import Foundation
import LibraryData
import Testing

@Suite("Tìm, lọc, sắp xếp, Gần đây")
struct LibraryQueryTests {
    static let now = Date(timeIntervalSince1970: 1_790_000_000)
    static let day: TimeInterval = 24 * 60 * 60

    static func entry(
        _ title: String,
        code: String? = nil,
        status: LibraryEntryStatus = .ready,
        addedDaysAgo: Double = 100,
        id: UUID = UUID()
    ) -> LibraryEntry {
        LibraryEntry(
            examID: id,
            summary: ExamSummary(title: title, code: code, questionCount: 10, sectionCount: 1, timeLimitMinutes: 10, passPercent: 50),
            fileURL: URL(fileURLWithPath: "/tmp/\(id.uuidString).exam"),
            addedAt: now.addingTimeInterval(-addedDaysAgo * day),
            status: status
        )
    }

    static func attempt(for entry: LibraryEntry, daysAgo: Double, score1000: Int) -> Attempt {
        let submitted = now.addingTimeInterval(-daysAgo * day)
        return Attempt(
            examID: entry.examID,
            examTitle: entry.title,
            candidateName: "Lan",
            mode: .exam,
            startedAt: submitted.addingTimeInterval(-600),
            submittedAt: submitted,
            elapsedSeconds: 600,
            correct: score1000 / 100,
            total: 10,
            score1000: score1000,
            percent: score1000 / 10,
            passed: score1000 >= 500
        )
    }

    // MARK: - Tìm

    @Test(
        "Không phân biệt hoa thường và dấu, \"d\" khớp \"đ\"",
        arguments: [
            ("toan", "Toán cao cấp"),
            ("TOÁN", "toán rời rạc"),
            ("toán", "TOAN"),
            ("d", "Đề cương"),
            ("de cuong", "Đề cương"),
            ("đe", "De thi"),
            ("ĐIỆN", "Kỹ thuật điện"),
            ("uong", "Đề cương"),
            ("ơ", "Cơ sở"),
            ("tieng viet", "Tiếng Việt lớp 5"),
        ]
    )
    func searchFoldsCaseAndDiacritics(query: String, title: String) {
        #expect(LibraryQuery.matches(Self.entry(title), query: query))
    }

    @Test("Chuỗi dựng sẵn và chuỗi tổ hợp (NFD) khớp nhau")
    func searchHandlesDecomposedText() {
        let decomposed = "To\u{0061}\u{0301}n" // "Toán" viết bằng a + dấu sắc tổ hợp
        #expect(LibraryQuery.matches(Self.entry("Toán học"), query: decomposed))
        #expect(LibraryQuery.matches(Self.entry(decomposed), query: "toan"))
    }

    @Test("Tìm cả theo mã đề; mọi từ phải khớp tiêu đề hoặc mã")
    func searchUsesCodeAndAllWords() {
        let toan = Self.entry("Toán cao cấp", code: "TOAN-01")
        let ly = Self.entry("Vật lý", code: "VL02")
        #expect(LibraryQuery.matches(toan, query: "toan-01"))
        #expect(LibraryQuery.matches(ly, query: "vl"))
        #expect(LibraryQuery.matches(toan, query: "cao 01"))
        #expect(!LibraryQuery.matches(toan, query: "toan ly"))
        #expect(!LibraryQuery.matches(ly, query: "toan"))
        #expect(LibraryQuery.search([toan, ly], query: "  ") == [toan, ly])
        #expect(LibraryQuery.search([toan, ly], query: "vat") == [ly])
    }

    @Test("Từ khoá không khớp thì không ra gì")
    func searchMisses() {
        #expect(!LibraryQuery.matches(Self.entry("Hoá học"), query: "sinh"))
        #expect(!LibraryQuery.matches(Self.entry("Đề A"), query: "b"))
    }

    // MARK: - Lọc

    @Test("Lọc Tất cả / Sẵn sàng / Có vấn đề")
    func filterByStatus() {
        let ready = Self.entry("A")
        let checking = Self.entry("B", status: .checking)
        let missing = Self.entry("C", status: .missing)
        let corrupt = Self.entry("D", status: .corrupt(reason: notZipReason))
        let newer = Self.entry("E", status: .needsNewerApp(found: 2, supported: 1))
        let invalid = Self.entry("F", status: .invalid(reason: unknownFieldsReason("x")))
        let issues = Self.entry("G", status: .readableWithIssues(reason: unknownFieldsReason("x")))
        let all = [ready, checking, missing, corrupt, newer, invalid, issues]

        #expect(LibraryQuery.filter(all, by: .all) == all)
        #expect(LibraryQuery.filter(all, by: .ready) == [ready])
        #expect(LibraryQuery.filter(all, by: .problems) == [missing, corrupt, newer, invalid, issues])
    }

    // MARK: - Sắp xếp

    @Test("Sắp theo tên dùng thứ tự tiếng Việt")
    func nameOrderIsVietnamese() {
        let titles = ["Bò", "Ân", "Ưa", "Đề 10", "Ăn", "Ơn", "Dê", "An", "Ua", "Đá", "Anh", "Ôm", "Em", "Đề 2", "Ong"]
        let entries = titles.map { Self.entry($0) }
        let sorted = LibraryQuery.sorted(entries, by: .name, latestAttempts: [:]).map(\.title)
        #expect(sorted == ["An", "Anh", "Ăn", "Ân", "Bò", "Dê", "Đá", "Đề 2", "Đề 10", "Em", "Ong", "Ôm", "Ơn", "Ua", "Ưa"])
    }

    @Test(
        "So tên theo bảng chữ cái tiếng Việt, không theo thứ tự gốc của Unicode",
        arguments: [("Ăn", "Ân"), ("Ân", "Bò"), ("Ăn", "Âm"), ("Anh", "Ân"), ("Dê", "Đá"), ("Đá", "Em"), ("Ôm", "Ơn"), ("Ua", "Ưa")]
    )
    func vietnameseAlphabet(first: String, second: String) {
        // "Ăn" < "Âm" và "Anh" < "Ân" chỉ đúng khi ă, â là chữ cái riêng (thứ tự tiếng Việt);
        // so theo locale gốc thì ngược lại.
        #expect(LibraryQuery.compareTitles(first, second) == .orderedAscending)
        #expect(LibraryQuery.compareTitles(second, first) == .orderedDescending)
    }

    @Test("Gần đây: lấy lần thi hoặc lần thêm, cái nào muộn hơn; mới nhất trước")
    func recentOrder() {
        let oldWithNewAttempt = Self.entry("Cũ, vừa thi", addedDaysAgo: 90)
        let newlyAdded = Self.entry("Mới thêm", addedDaysAgo: 3)
        let oldWithOldAttempt = Self.entry("Cũ, thi lâu rồi", addedDaysAgo: 200)
        let attempts = [
            oldWithNewAttempt.examID: Self.attempt(for: oldWithNewAttempt, daysAgo: 1, score1000: 800),
            oldWithOldAttempt.examID: Self.attempt(for: oldWithOldAttempt, daysAgo: 150, score1000: 900),
        ]
        let sorted = LibraryQuery.sorted([oldWithOldAttempt, newlyAdded, oldWithNewAttempt], by: .recent, latestAttempts: attempts)
        #expect(sorted.map(\.title) == ["Cũ, vừa thi", "Mới thêm", "Cũ, thi lâu rồi"])
    }

    @Test("Điểm lần trước: cao trước, đề chưa thi xếp cuối theo tên")
    func lastScoreOrder() {
        let high = Self.entry("Bình", addedDaysAgo: 5)
        let low = Self.entry("An", addedDaysAgo: 5)
        let neverB = Self.entry("Cúc")
        let neverA = Self.entry("Ánh")
        let attempts = [
            high.examID: Self.attempt(for: high, daysAgo: 2, score1000: 900),
            low.examID: Self.attempt(for: low, daysAgo: 1, score1000: 400),
        ]
        let sorted = LibraryQuery.sorted([neverB, low, neverA, high], by: .lastScore, latestAttempts: attempts)
        #expect(sorted.map(\.title) == ["Bình", "An", "Ánh", "Cúc"])
    }

    @Test("Gần đây trên sidebar: có lần thi hoặc được thêm trong 30 ngày, mới nhất trước")
    func recentWindow() {
        let added10 = Self.entry("Thêm 10 ngày trước", addedDaysAgo: 10)
        let added29 = Self.entry("Thêm 29 ngày trước", addedDaysAgo: 29.9)
        let added31 = Self.entry("Thêm 31 ngày trước", addedDaysAgo: 31)
        let attempted5 = Self.entry("Thi 5 ngày trước", addedDaysAgo: 60)
        let attempted40 = Self.entry("Thi 40 ngày trước", addedDaysAgo: 60)
        let attempts = [
            attempted5.examID: Self.attempt(for: attempted5, daysAgo: 5, score1000: 500),
            attempted40.examID: Self.attempt(for: attempted40, daysAgo: 40, score1000: 500),
        ]
        let recent = LibraryQuery.recent(
            [added31, attempted40, added29, attempted5, added10],
            latestAttempts: attempts,
            now: Self.now
        )
        #expect(recent.map(\.title) == ["Thi 5 ngày trước", "Thêm 10 ngày trước", "Thêm 29 ngày trước"])
        // Đúng 30 ngày vẫn tính là gần đây.
        let boundary = Self.entry("Đúng 30 ngày", addedDaysAgo: 30)
        #expect(LibraryQuery.recent([boundary], latestAttempts: [:], now: Self.now) == [boundary])
    }

    @Test("apply: tìm, lọc rồi sắp xếp")
    func applyCombines() {
        let a = Self.entry("Toán 2")
        let b = Self.entry("Toán 10", status: .missing)
        let c = Self.entry("Toán 1")
        let d = Self.entry("Văn")
        let result = LibraryQuery.apply([a, b, c, d], query: "toan", filter: .ready, order: .name, latestAttempts: [:])
        #expect(result == [c, a])
        let all = LibraryQuery.apply([a, b, c, d], query: "TOÁN", filter: .all, order: .name, latestAttempts: [:])
        #expect(all == [c, a, b])
    }
}
