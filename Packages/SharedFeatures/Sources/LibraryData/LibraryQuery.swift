import Foundation

/// Bộ lọc thư viện (docs/product/library.md, mục Tìm, lọc, sắp xếp).
public enum LibraryFilter: String, CaseIterable, Identifiable, Sendable {
    /// Tất cả
    case all
    /// Sẵn sàng
    case ready
    /// Có vấn đề: không tìm thấy file, file hỏng, cần app mới hơn, đề có lỗi.
    case problems

    public var id: Self { self }
}

/// Cách sắp xếp thư viện. Giá trị thô ổn định để giao diện nhớ bằng `@AppStorage`.
public enum LibrarySortOrder: String, CaseIterable, Identifiable, Sendable {
    /// Gần đây: lần thi hoặc lần thêm gần nhất, mới nhất trước.
    case recent
    /// Tên theo thứ tự tiếng Việt, A → Z.
    case name
    /// Điểm lần thi gần nhất, cao trước; đề chưa thi xếp cuối.
    case lastScore

    public var id: Self { self }
}

/// Tìm, lọc, sắp xếp và "Gần đây": hàm thuần, không đụng tới kho hay file.
public enum LibraryQuery {
    /// Locale dùng để so sánh tên đề theo thứ tự tiếng Việt (a < ă < â < b …, d < đ).
    public static let vietnamese = Locale(identifier: "vi")
    /// "Gần đây": có lần thi hoặc được thêm trong 30 ngày.
    public static let recentWindow: TimeInterval = 30 * 24 * 60 * 60

    // MARK: - Tìm

    /// Chuỗi dùng để so khi tìm: bỏ dấu, không phân biệt hoa thường, "đ"/"Đ" thành "d"
    /// ("Đề Toán" → "de toan"). `folding` không bỏ nét gạch của "đ" nên phải đổi riêng.
    public static func searchKey(_ text: String) -> String {
        text.replacingOccurrences(of: "đ", with: "d")
            .replacingOccurrences(of: "Đ", with: "d")
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: vietnamese)
    }

    /// Đề khớp từ khoá khi mọi từ (tách bằng khoảng trắng) của từ khoá nằm trong tiêu đề hoặc mã đề,
    /// không phân biệt hoa thường và dấu ("toan" khớp "Toán", "d" khớp "đ"). Từ khoá rỗng khớp mọi đề.
    public static func matches(_ entry: LibraryEntry, query: String) -> Bool {
        let words = searchKey(query).split(whereSeparator: \.isWhitespace)
        guard !words.isEmpty else { return true }
        let haystack = searchKey(entry.summary.title) + "\n" + searchKey(entry.summary.code ?? "")
        return words.allSatisfy { haystack.contains($0) }
    }

    public static func search(_ entries: [LibraryEntry], query: String) -> [LibraryEntry] {
        entries.filter { matches($0, query: query) }
    }

    // MARK: - Lọc

    public static func filter(_ entries: [LibraryEntry], by filter: LibraryFilter) -> [LibraryEntry] {
        switch filter {
        case .all: entries
        case .ready: entries.filter(\.status.isReady)
        case .problems: entries.filter(\.status.hasProblem)
        }
    }

    // MARK: - Sắp xếp

    /// So tên đề theo thứ tự tiếng Việt, số so theo giá trị ("Đề 2" trước "Đề 10").
    public static func compareTitles(_ lhs: String, _ rhs: String) -> ComparisonResult {
        lhs.compare(rhs, options: [.numeric], range: nil, locale: vietnamese)
    }

    /// Mốc "gần đây" của một đề: lần thi gần nhất hoặc lúc thêm, lấy cái muộn hơn.
    public static func recencyDate(of entry: LibraryEntry, latestAttempt: Attempt?) -> Date {
        guard let latestAttempt else { return entry.addedAt }
        return max(entry.addedAt, latestAttempt.submittedAt)
    }

    /// Sắp xếp theo `order`. Bằng nhau thì theo tên, rồi mã đề, rồi id đề để thứ tự luôn ổn định.
    /// - Parameter latestAttempts: lần thi gần nhất theo id đề (`LibraryStore.latestAttempts`).
    public static func sorted(
        _ entries: [LibraryEntry],
        by order: LibrarySortOrder,
        latestAttempts: [UUID: Attempt]
    ) -> [LibraryEntry] {
        entries.sorted { lhs, rhs in
            switch order {
            case .recent:
                let left = recencyDate(of: lhs, latestAttempt: latestAttempts[lhs.examID])
                let right = recencyDate(of: rhs, latestAttempt: latestAttempts[rhs.examID])
                if left != right { return left > right }
            case .name:
                break
            case .lastScore:
                switch (latestAttempts[lhs.examID], latestAttempts[rhs.examID]) {
                case let (left?, right?) where left.score1000 != right.score1000:
                    return left.score1000 > right.score1000
                case (.some, nil):
                    return true
                case (nil, .some):
                    return false
                default:
                    break
                }
            }
            return nameOrder(lhs, rhs)
        }
    }

    /// Đề "Gần đây" (sidebar): lần thi gần nhất hoặc lúc thêm nằm trong 30 ngày tính tới `now`,
    /// mới nhất trước.
    public static func recent(
        _ entries: [LibraryEntry],
        latestAttempts: [UUID: Attempt],
        now: Date
    ) -> [LibraryEntry] {
        let cutoff = now.addingTimeInterval(-recentWindow)
        let inWindow = entries.filter {
            recencyDate(of: $0, latestAttempt: latestAttempts[$0.examID]) >= cutoff
        }
        return sorted(inWindow, by: .recent, latestAttempts: latestAttempts)
    }

    /// Tìm, lọc rồi sắp xếp, theo đúng thứ tự thanh công cụ áp dụng.
    public static func apply(
        _ entries: [LibraryEntry],
        query: String,
        filter: LibraryFilter,
        order: LibrarySortOrder,
        latestAttempts: [UUID: Attempt]
    ) -> [LibraryEntry] {
        sorted(
            Self.filter(search(entries, query: query), by: filter),
            by: order,
            latestAttempts: latestAttempts
        )
    }

    private static func nameOrder(_ lhs: LibraryEntry, _ rhs: LibraryEntry) -> Bool {
        let byTitle = compareTitles(lhs.summary.title, rhs.summary.title)
        if byTitle != .orderedSame { return byTitle == .orderedAscending }
        let byCode = compareTitles(lhs.summary.code ?? "", rhs.summary.code ?? "")
        if byCode != .orderedSame { return byCode == .orderedAscending }
        return lhs.examID.uuidString < rhs.examID.uuidString
    }
}
