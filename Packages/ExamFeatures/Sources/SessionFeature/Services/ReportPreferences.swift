import Foundation
import ReportFeature
import SessionModel

/// Cài đặt của Xuất PDF/In kết quả, chung cho mọi đề. Tách khỏi `SessionPreferences` (SessionModel, dùng chung với iOS)
/// vì `ResultsReviewLevel` là của ReportFeature (chỉ bản macOS). App dùng `UserDefaultsSessionPreferences` (cùng
/// `defaults` với cài đặt của phiên thi).
@MainActor
public protocol ReportPreferences: AnyObject {
    /// **Phần xem lại bài** chọn lần trước trong hộp chọn của Xuất PDF/In (docs/product/export-print.md phương án 3);
    /// chưa có thì **Câu sai và chưa làm**.
    var reportReviewLevel: ResultsReviewLevel { get set }
}

extension UserDefaultsSessionPreferences: ReportPreferences {
    /// Phần xem lại của PDF kết quả dùng lần trước (`ResultsReviewLevel.rawValue`), chung cho mọi đề.
    public static let reportReviewLevelKey = "report.resultsReviewLevel"

    public var reportReviewLevel: ResultsReviewLevel {
        get { defaults.string(forKey: Self.reportReviewLevelKey).flatMap(ResultsReviewLevel.init(rawValue:)) ?? .default }
        set { defaults.set(newValue.rawValue, forKey: Self.reportReviewLevelKey) }
    }
}
