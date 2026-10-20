import Foundation
import LibraryFeature
@testable import ReportFeature
import Testing

/// Màu của PDF (luôn sáng, docs/product/export-print.md): chữ đạt 4,5:1 trên trang trắng và trên nền nhạt (khung giải
/// thích, dòng báo); phần đã đạt của thanh điểm khác rõ rãnh của nó (≥ 3:1). Bảng màu dạng số: `ReportTypography.Gray`.
@Suite("Tương phản của màu PDF")
struct ReportPaletteTests {
    static func gray(_ value: Double) -> LibraryPalette.RGB {
        let channel = UInt32((value * 255).rounded())
        return LibraryPalette.RGB(hex: channel << 16 | channel << 8 | channel)
    }

    @Test("Chữ chính và chữ phụ đạt 4,5:1 trên trang trắng và nền nhạt; thanh điểm đạt 3:1 trên rãnh")
    func pdfColors() {
        let page = LibraryPalette.white
        let tint = Self.gray(ReportTypography.Gray.tint)
        for text in [ReportTypography.Gray.primary, ReportTypography.Gray.secondary] {
            #expect(LibraryPalette.contrast(Self.gray(text), page) >= 4.5, "\(text) trên trang")
            #expect(LibraryPalette.contrast(Self.gray(text), tint) >= 4.5, "\(text) trên nền nhạt")
        }
        #expect(LibraryPalette.contrast(Self.gray(ReportTypography.Gray.fill), tint) >= 3)
        // Đối chứng âm: vạch phân cách (không phải chữ) không đạt mức chữ, nên không được dùng làm màu chữ.
        #expect(LibraryPalette.contrast(Self.gray(ReportTypography.Gray.rule), page) < 4.5)
    }
}
