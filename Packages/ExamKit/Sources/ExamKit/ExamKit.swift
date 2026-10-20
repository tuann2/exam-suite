import Foundation

/// Thông tin phiên bản của lõi. Model, chấm điểm, chọn câu và phiên thi được
/// thêm ở giai đoạn 1 theo docs/plans/completed/giai-doan-1-loi-dinh-dang.md.
public enum ExamKitInfo {
    /// Phiên bản semver của lõi (ExamKit), không phải phiên bản app (`MARKETING_VERSION` trong project.yml, CHANGELOG.md):
    /// chỉ tăng khi lõi đổi.
    public static let version = "0.1.0"
}
