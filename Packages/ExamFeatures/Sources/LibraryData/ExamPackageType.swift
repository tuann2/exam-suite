import ExamFile
import UniformTypeIdentifiers

extension UTType {
    /// Kiểu file `.exam` (`vn.io.nt0.exam`, docs/product/exam-format.md), dùng ở cả hai bản app:
    /// bản Admin khai báo export (Owner, Editor), bản Học viên khai báo import (Alternate, Viewer)
    /// trong `project.yml`.
    ///
    /// Tra theo identifier thay vì `UTType(exportedAs:)` hay `UTType(importedAs:)`: hai hàm đó dành cho
    /// đúng một kiểu khai báo (export hoặc import) và báo lỗi trong log khi Info.plist của bản app không
    /// khai báo đúng kiểu đó, nên không có hàm nào hợp cho cả hai bản. Tra theo identifier lấy được khai
    /// báo đang hiệu lực ở cả hai bản. Chỉ khi tiến trình không có khai báo nào (test, công cụ dòng
    /// lệnh) mới dựng kiểu tạm conform `com.pkware.zip-archive`, khớp khai báo trong `project.yml`.
    public static let examPackage: UTType =
        UTType(ExamFileFormat.uniformTypeIdentifier)
            ?? UTType(
                importedAs: ExamFileFormat.uniformTypeIdentifier,
                conformingTo: UTType("com.pkware.zip-archive") ?? .zip
            )
}
