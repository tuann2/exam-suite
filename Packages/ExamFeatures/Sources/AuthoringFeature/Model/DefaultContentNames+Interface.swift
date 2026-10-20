import AuthoringData
import Foundation

/// Tên mặc định app ghi vào **nội dung đề**, theo **ngôn ngữ giao diện lúc tạo** (Nt0 chốt 2026-10-17; plan giai đoạn 5,
/// Decisions; accessibility-localization.md, ghi chú bước 7c): đề mới ("Đề mới" / "New Exam"), phần thứ N ("Phần N" /
/// "Section N": phần đầu của đề mới, **Thêm phần**, câu đầu tiên của đề chưa có phần), phần chung khi import ("Phần chung"
/// / "General Section"). Sau khi tạo, tên là nội dung đề: không dịch lại khi đổi ngôn ngữ, lưu nguyên vào file.
/// AuthoringData và ExamImport không có catalog (chạy không giao diện), nên tên đã tra catalog của AuthoringFeature đi
/// vào từ đây; mặc định của hai target đó là tiếng Việt (ngôn ngữ nguồn).
extension DefaultContentNames {
    /// Tên theo ngôn ngữ giao diện; `locale` cố định khi có (test kiểm tiếng Anh, tiếng Việt). Số thứ tự của phần là chữ
    /// số trơn ("Phần 1234", như `DefaultContentNames.vietnamese`): tên là nội dung đề, không định dạng theo ngôn ngữ.
    static func interface(locale: Locale? = nil) -> DefaultContentNames {
        DefaultContentNames(
            examTitle: localized("Đề mới", locale: locale),
            sectionTitle: { localized("Phần \(String($0))", locale: locale) }
        )
    }
}

/// Tên phần cho câu không thuộc phần nào khi **Import đề…** (`ExamImporter`, `sharedSectionTitle:`), theo ngôn ngữ giao
/// diện lúc import; `locale` cố định khi có (test).
enum ImportContentNames {
    static func sharedSectionTitle(locale: Locale? = nil) -> String {
        localized("Phần chung", locale: locale)
    }
}
