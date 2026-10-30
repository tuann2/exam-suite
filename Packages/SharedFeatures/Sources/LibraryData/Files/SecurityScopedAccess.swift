import Foundation

/// Quyền đọc file ngoài container của app trên iOS (docs/product/mobile.md, mục Bản iOS): file chọn bằng hộp chọn file
/// (app Tệp: iCloud Drive, Trên iPhone, Drive…) chỉ đọc được trong lúc mở quyền security scope của URL; bookmark tạo
/// trong lúc đó mang theo quyền, URL phân giải từ bookmark phải mở quyền lại mỗi lần đọc. File trong container của app
/// (đề mẫu, file nhận từ app khác đã dời khỏi `Inbox`) không cần quyền: mở quyền với URL thường không làm gì.
///
/// Bản macOS (app không sandbox, ADR 0004) gọi thẳng, không đổi hành vi: bookmark thường, đọc theo đường dẫn.
public enum SecurityScopedAccess {
    /// Chạy `body` trong lúc mở quyền security scope của `url` (iOS); macOS gọi thẳng `body`.
    public static func with<T>(_ url: URL, _ body: () throws -> T) rethrows -> T {
        #if os(iOS)
        let started = url.startAccessingSecurityScopedResource()
        defer { if started { url.stopAccessingSecurityScopedResource() } }
        #endif
        return try body()
    }

    /// URL để đọc file của một mục thư viện: iOS phân giải lại `bookmark` (URL mang quyền security scope, kể cả khi
    /// container của app đổi đường dẫn sau khi cập nhật app), không được thì `url`; macOS luôn là `url` (đường dẫn của
    /// lần phân giải gần nhất, như trước).
    public static func readableURL(_ url: URL, bookmark: Data?) -> URL {
        #if os(iOS)
        if let bookmark {
            var stale = false
            if let resolved = try? URL(
                resolvingBookmarkData: bookmark,
                options: [.withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            ) {
                return resolved
            }
        }
        #endif
        return url
    }
}
