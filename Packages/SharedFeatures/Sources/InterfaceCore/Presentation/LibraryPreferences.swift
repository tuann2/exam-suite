import LibraryData

/// Khoá `@AppStorage` của Thư viện (docs/product/library.md, mục Lưu trữ: cài đặt nhỏ dùng `@AppStorage`).
/// Mỗi bản app có `UserDefaults` riêng theo bundle ID nên hai bản không dùng chung cài đặt.
public enum LibraryPreferenceKey {
    /// Chế độ xem: `LibraryViewMode`.
    public static let viewMode = "library.viewMode"
    /// Cách sắp xếp: `LibrarySortOrder`.
    public static let sortOrder = "library.sortOrder"
    /// Dải chào mừng: `WelcomeBannerState`.
    public static let welcomeBanner = "library.welcomeBanner"
}

/// Chế độ xem thư viện: lưới thẻ hoặc danh sách (`Table`).
public enum LibraryViewMode: String, CaseIterable, Identifiable, Sendable {
    case grid
    case list

    public var id: Self { self }
}

/// Dải chào mừng sau lần đầu tạo đề mẫu; người dùng đóng thì không hiện lại.
public enum WelcomeBannerState: String, Sendable {
    /// Chưa tạo đề mẫu lần nào trong app này.
    case notShown
    /// Vừa tạo đề mẫu lần đầu, chưa đóng (vẫn hiện ở lần mở app sau cho tới khi đóng).
    case visible
    /// Người dùng đã đóng.
    case dismissed

    /// Trạng thái sau khi `LibraryStore.start()` trả `report`: vừa tạo đề mẫu lần đầu thì hiện,
    /// trừ khi người dùng đã từng đóng dải này.
    public func after(start report: SampleReport?) -> WelcomeBannerState {
        guard self == .notShown, report?.didAddSamples == true else { return self }
        return .visible
    }
}

extension LibrarySortOrder {
    /// Tên trên menu Sắp xếp.
    public var title: String {
        switch self {
        case .recent: localized("Gần đây")
        case .name: localized("Tên")
        case .lastScore: localized("Điểm lần trước")
        }
    }
}

extension LibraryFilter {
    /// Tên trên menu Lọc.
    public var title: String {
        switch self {
        case .all: localized("Tất cả")
        case .ready: localized("Sẵn sàng")
        case .problems: localized("Có vấn đề")
        }
    }

    /// Tiêu đề khi bộ lọc không có đề nào: câu trọn vẹn cho từng bộ lọc (trước bước 7c ghép "Không có đề nào" với tên
    /// bộ lọc viết thường; tiếng Anh không ghép được như vậy). `nil` với **Tất cả** (không lọc gì).
    public var emptyTitle: String? {
        switch self {
        case .all: nil
        case .ready: localized("Không có đề nào sẵn sàng")
        case .problems: localized("Không có đề nào có vấn đề")
        }
    }
}
