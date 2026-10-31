import ExamKit
import Foundation

/// Hằng số của định dạng gói `.exam` (xem docs/product/exam-format.md và
/// schema/exam-v1.schema.json). Đọc/ghi gói được thêm ở giai đoạn 1.
public enum ExamFileFormat {
    /// `formatVersion` mới nhất mà app này ghi ra và hiểu được.
    /// Lấy từ model để chỉ có một nguồn sự thật.
    public static let currentVersion = Exam.currentFormatVersion
    /// Đuôi file của gói đề.
    public static let fileExtension = "exam"
    /// Tên file JSON bắt buộc ở gốc gói.
    public static let manifestName = "exam.json"
    /// Thư mục chứa ảnh trong gói.
    public static let mediaDirectory = "media"
    /// UTType identifier khai báo trong Info.plist của hai app.
    public static let uniformTypeIdentifier = "vn.io.nt0.exam"
    /// Đuôi file `.oef` của Open Exam Suite, chỉ đọc (docs/product/exam-format.md, mục File `.oef`).
    public static let oefFileExtension = "oef"
    /// UTType nhập cho `.oef` (Open Exam Suite chỉ đăng ký đuôi, không khai báo UTType).
    public static let oefUniformTypeIdentifier = "vn.io.nt0.examsuite.oef"
}
