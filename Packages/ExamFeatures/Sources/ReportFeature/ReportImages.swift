import CoreGraphics
import Foundation
import ImageIO

/// Ảnh câu hỏi trong PDF (docs/product/export-print.md, Trình bày chung): vừa bề rộng vùng in, cao tối đa 1/3 trang,
/// giữ tỉ lệ, không phóng to quá cỡ gốc. Lượt xếp trang chỉ đọc cỡ ảnh từ thuộc tính (không giải mã); ảnh của mỗi trang
/// được giải mã **xong trước khi vẽ** (`ImageRenderer` không chạy `.task`), ngoài main actor (`ReportRenderer`), thu nhỏ
/// còn ≤ 2× cỡ hiển thị. Các hàm ở đây không giữ trạng thái, gọi được từ mọi luồng.
enum ReportImages {
    /// Cỡ hiển thị (điểm) của ảnh `data`, hoặc nil nếu không đọc được (hiện dòng "Không hiện được ảnh…").
    static func displaySize(of data: Data, maxWidth: CGFloat, maxHeight: CGFloat) -> CGSize? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue,
              width > 0, height > 0
        else { return nil }
        // Hướng EXIF 5–8 xoay 90°: đổi chiều rộng/cao.
        let orientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
        let (w, h) = orientation >= 5 ? (height, width) : (width, height)
        let scale = min(1, maxWidth / w, maxHeight / h)
        return CGSize(width: (w * scale).rounded(.down), height: (h * scale).rounded(.down))
    }

    /// Giải mã đồng bộ, theo hướng EXIF, cạnh dài nhất ≤ 2× cỡ hiển thị (đủ nét khi in). Nil nếu không giải mã được.
    static func decode(_ data: Data, displaySize: CGSize) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let maxPixel = max(1, Int((max(displaySize.width, displaySize.height) * 2).rounded(.up)))
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
