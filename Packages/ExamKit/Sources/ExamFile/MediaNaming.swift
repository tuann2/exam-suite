import Foundation

/// Đặt tên ảnh trong gói theo nội dung (docs/product/exam-format.md, mục Gói):
/// ảnh trùng nội dung có cùng tên nên chỉ lưu một lần.
public enum MediaNaming {
    /// Đuôi ảnh được phép, chữ thường, khớp `image` trong schema v1.
    public static let allowedExtensions: Set<String> = ["png", "jpg", "jpeg", "gif", "webp", "heic"]
    /// Số ký tự hex đầu của SHA-256 dùng làm tên (schema cho phép 16–64).
    public static let hashPrefixLength = 16

    /// "media/" + 16 ký tự hex đầu của SHA-256(data) + "." + ext (chữ thường).
    /// `fileExtension` không có dấu chấm, ví dụ `"PNG"` hoặc `"jpg"`.
    /// - Throws: `ExamFileError.unsupportedImageType` nếu đuôi không thuộc `allowedExtensions`.
    public static func path(for data: Data, fileExtension: String) throws -> String {
        let ext = fileExtension.lowercased()
        guard allowedExtensions.contains(ext) else {
            throw ExamFileError.unsupportedImageType(fileExtension)
        }
        let hash = SHA256.hexDigest(data).prefix(hashPrefixLength)
        return "\(ExamFileFormat.mediaDirectory)/\(hash).\(ext)"
    }

    /// `true` nếu `path` khớp mẫu `image` của schema v1:
    /// `^media/[a-f0-9]{16,64}\.(png|jpg|jpeg|gif|webp|heic)$`.
    /// Chặn đường dẫn kiểu `media/../evil.png` hay thư mục con `media/a/b.png`.
    public static func isValidPath(_ path: String) -> Bool {
        let prefix = ExamFileFormat.mediaDirectory + "/"
        guard path.hasPrefix(prefix) else { return false }
        let name = path.dropFirst(prefix.count)
        guard let dot = name.lastIndex(of: ".") else { return false }
        let hash = name[..<dot]
        let ext = String(name[name.index(after: dot)...])
        return (16 ... 64).contains(hash.count)
            && hash.allSatisfy { $0.isASCII && ($0.isWholeNumber || ("a" ... "f").contains($0)) }
            && allowedExtensions.contains(ext)
    }
}
