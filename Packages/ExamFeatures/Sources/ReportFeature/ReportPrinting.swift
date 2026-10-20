import AppKit
import PDFKit

/// In (docs/product/export-print.md, mục In, phương án 2): nội dung là đúng bản PDF A4 đã dựng, co vừa khổ giấy chọn
/// trong hộp In (`PDFDocument.printOperation`, `.pageScaleToFit`). Không có Page Setup riêng. Giao diện (bước 5b) gọi
/// `runModal(for:delegate:didRun:contextInfo:)` trên cửa sổ làm bài; test đặt `jobDisposition = .save` để chỉ in ra
/// file, không mở hộp In thật.
@MainActor
public enum ReportPrinting {
    /// Thao tác In cho `pdf`, hoặc nil nếu PDFKit không đọc được dữ liệu. `printInfo` mặc định là bản sao của
    /// `NSPrintInfo.shared` (không sửa cài đặt In chung của app).
    public static func printOperation(
        for pdf: ReportPDF,
        jobTitle: String,
        printInfo: NSPrintInfo? = nil
    ) -> NSPrintOperation? {
        PDFDocument(data: pdf.data).flatMap { operation(for: $0, jobTitle: jobTitle, printInfo: printInfo) }
    }

    /// Như trên, cho PDF đã ghi ra file (`ReportRenderer.render(_:to:)`); file phải còn tới khi In xong.
    public static func printOperation(
        for file: ReportPDFFile,
        jobTitle: String,
        printInfo: NSPrintInfo? = nil
    ) -> NSPrintOperation? {
        PDFDocument(url: file.url).flatMap { operation(for: $0, jobTitle: jobTitle, printInfo: printInfo) }
    }

    private static func operation(for document: PDFDocument, jobTitle: String, printInfo: NSPrintInfo?) -> NSPrintOperation? {
        let info = printInfo ?? (NSPrintInfo.shared.copy() as? NSPrintInfo) ?? NSPrintInfo()
        guard let operation = document.printOperation(for: info, scalingMode: .pageScaleToFit, autoRotate: true) else {
            return nil
        }
        operation.jobTitle = jobTitle
        return operation
    }
}
