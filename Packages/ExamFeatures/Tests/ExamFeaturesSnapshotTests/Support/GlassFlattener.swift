import AppKit
import CoreImage
import QuartzCore

/// Làm phẳng Liquid Glass (macOS 26+) trước khi chụp trong tiến trình.
///
/// Kính (nền sidebar/inspector nổi, nút thanh công cụ) và chữ "vibrant" trên kính do WindowServer ghép: lớp kính là
/// `CABackdropLayer`/`CAPortalLayer`/`SDF*`, chữ và ô trên kính có bộ lọc `vibrantColorMatrix`. `cacheDisplay` bỏ qua
/// bộ lọc nên kính thành khối trắng và chữ vibrant ra màu gốc chưa qua ma trận (với chữ SwiftUI quan sát được là đen,
/// nên ở giao diện tối gần như không đọc được). Ở đây, tạm thời:
/// - ẩn lớp kính (thấy nền cửa sổ bên dưới);
/// - áp ma trận màu của `vibrantColorMatrix` lên màu nền, viền, màu hình và ảnh nội dung (chữ, biểu tượng) của lớp và
///   mọi lớp con, rồi bỏ bộ lọc;
/// và trả về hàm khôi phục. Đây là xấp xỉ: hiệu ứng kính không được kiểm (test tay Dark Mode vẫn cần).
@MainActor
enum GlassFlattener {
    /// Làm phẳng cây lớp từ `root`; gọi hàm trả về để khôi phục sau khi chụp.
    static func flatten(_ root: CALayer) -> () -> Void {
        var restore: [() -> Void] = []
        visit(root, matrix: nil, restore: &restore)
        return {
            for undo in restore.reversed() { undo() }
        }
    }

    private static func isGlass(_ layer: CALayer) -> Bool {
        let name = NSStringFromClass(type(of: layer))
        return name.contains("Backdrop") || name.contains("Portal") || name.hasPrefix("SDF") || name.hasPrefix("CASDF")
    }

    private static func visit(_ layer: CALayer, matrix inherited: ColorMatrix?, restore: inout [() -> Void]) {
        guard !layer.isHidden else { return }
        if isGlass(layer) {
            layer.isHidden = true
            restore.append { layer.isHidden = false }
            return
        }
        var matrix = inherited
        if let filters = layer.filters, let own = filters.lazy.compactMap(ColorMatrix.init(vibrancyFilter:)).first {
            // Bộ lọc của lớp áp trước, của lớp cha áp sau.
            matrix = inherited.map { $0.after(own) } ?? own
            layer.filters = nil
            restore.append { layer.filters = filters }
        }
        // Lớp con lấy trước khi đổi màu: lớp phủ mà `recolor` thêm vào đã đổi màu rồi.
        let sublayers = layer.sublayers ?? []
        if let matrix { recolor(layer, with: matrix, restore: &restore) }
        for sublayer in sublayers { visit(sublayer, matrix: matrix, restore: &restore) }
    }

    private static func recolor(_ layer: CALayer, with matrix: ColorMatrix, restore: inout [() -> Void]) {
        if let color = layer.backgroundColor {
            layer.backgroundColor = matrix.apply(color)
            restore.append { layer.backgroundColor = color }
        }
        if let color = layer.borderColor, layer.borderWidth > 0 {
            layer.borderColor = matrix.apply(color)
            restore.append { layer.borderColor = color }
        }
        if let shape = layer as? CAShapeLayer {
            let fill = shape.fillColor
            let stroke = shape.strokeColor
            shape.fillColor = fill.map(matrix.apply)
            shape.strokeColor = stroke.map(matrix.apply)
            restore.append {
                shape.fillColor = fill
                shape.strokeColor = stroke
            }
        }
        // Nội dung (chữ, biểu tượng): vẽ ra ảnh đúng như Core Animation vẽ nó (nội dung chữ của SwiftUI là
        // `CATintedImage`/backing store, không phải `CGImage`; biểu tượng của SwiftUI có màu nhân `contentsMultiplyColor`),
        // rồi mới áp ma trận, như WindowServer. Ảnh đã đổi màu đặt vào một lớp con tạm (dưới mọi lớp con khác, như nội
        // dung), không thay `contents` của chính lớp: với lớp biểu tượng của SwiftUI, `render(in:)` dùng ảnh nội dung như
        // mặt nạ tô bằng màu nhân (trắng), nên ảnh đã đổi màu sang xám ở giao diện sáng lại ra trắng (biểu tượng mất).
        guard let contents = layer.contents, let source = rasterizedContents(of: layer),
              let recolored = matrix.apply(source)
        else { return }
        let overlay = CALayer()
        overlay.frame = layer.bounds
        overlay.contents = recolored
        overlay.contentsScale = layer.contentsScale
        overlay.contentsGravity = .resize
        layer.contents = nil
        layer.insertSublayer(overlay, at: 0)
        restore.append {
            overlay.removeFromSuperlayer()
            layer.contents = contents
        }
    }

    /// Nội dung của `layer` vẽ ra ảnh phủ `bounds`, ở hệ số của lớp, không kèm nền, viền hay lớp con (ẩn tạm); bộ lọc
    /// đã gỡ trước đó.
    private static func rasterizedContents(of layer: CALayer) -> CGImage? {
        let scale = max(layer.contentsScale, 1)
        let width = Int((layer.bounds.width * scale).rounded(.up))
        let height = Int((layer.bounds.height * scale).rounded(.up))
        guard width > 0, height > 0,
              let context = CGContext(
                  data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { return nil }
        let background = layer.backgroundColor
        let borderWidth = layer.borderWidth
        let opacity = layer.opacity
        let visibleSublayers = (layer.sublayers ?? []).filter { !$0.isHidden }
        layer.backgroundColor = nil
        layer.borderWidth = 0
        layer.opacity = 1
        visibleSublayers.forEach { $0.isHidden = true }
        defer {
            layer.backgroundColor = background
            layer.borderWidth = borderWidth
            layer.opacity = opacity
            visibleSublayers.forEach { $0.isHidden = false }
        }
        context.scaleBy(x: scale, y: scale)
        // `render(in:)` vẽ nội dung lật khi lớp lật nội dung (lớp của view lật như SwiftUI): lật lại để ảnh đúng chiều.
        if layer.contentsAreFlipped() {
            context.translateBy(x: 0, y: layer.bounds.height)
            context.scaleBy(x: 1, y: -1)
        }
        context.translateBy(x: -layer.bounds.minX, y: -layer.bounds.minY)
        layer.render(in: context)
        return context.makeImage()
    }
}

/// Ma trận màu 4×5 của Core Animation (`CAColorMatrix`): mỗi kênh ra = tổ hợp R, G, B, A vào + hằng số.
struct ColorMatrix {
    /// 20 hệ số theo hàng: R' = m[0]R + m[1]G + m[2]B + m[3]A + m[4], rồi G', B', A'.
    var m: [Float]

    /// Ma trận của bộ lọc `vibrantColorMatrix` (CAFilter riêng của hệ thống); nil với bộ lọc khác.
    init?(vibrancyFilter filter: Any) {
        let object = filter as AnyObject
        guard let name = object.value(forKey: "name") as? String, name.lowercased().contains("colormatrix"),
              let value = object.value(forKey: "inputColorMatrix") as? NSValue
        else { return nil }
        var floats = [Float](repeating: 0, count: 20)
        floats.withUnsafeMutableBytes { buffer in
            value.getValue(buffer.baseAddress!, size: buffer.count)
        }
        m = floats
    }

    init(m: [Float]) { self.m = m }

    /// Ma trận áp `inner` trước rồi tới `self`.
    func after(_ inner: ColorMatrix) -> ColorMatrix {
        var out = [Float](repeating: 0, count: 20)
        for row in 0 ..< 4 {
            for column in 0 ..< 4 {
                out[row * 5 + column] = (0 ..< 4).reduce(0) { $0 + m[row * 5 + $1] * inner.m[$1 * 5 + column] }
            }
            out[row * 5 + 4] = (0 ..< 4).reduce(m[row * 5 + 4]) { $0 + m[row * 5 + $1] * inner.m[$1 * 5 + 4] }
        }
        return ColorMatrix(m: out)
    }

    func apply(_ color: CGColor) -> CGColor {
        guard let rgb = color.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil),
              let c = rgb.components, c.count == 4
        else { return color }
        let input = c.map(Float.init)
        let output = (0 ..< 4).map { row in
            min(1, max(0, (0 ..< 4).reduce(m[row * 5 + 4]) { $0 + m[row * 5 + $1] * input[$1] }))
        }
        return CGColor(srgbRed: CGFloat(output[0]), green: CGFloat(output[1]), blue: CGFloat(output[2]),
                       alpha: CGFloat(output[3]))
    }

    func apply(_ image: CGImage) -> CGImage? {
        let filter = CIFilter(name: "CIColorMatrix")!
        filter.setValue(CIImage(cgImage: image), forKey: kCIInputImageKey)
        func vector(_ row: Int) -> CIVector {
            CIVector(x: CGFloat(m[row * 5]), y: CGFloat(m[row * 5 + 1]), z: CGFloat(m[row * 5 + 2]), w: CGFloat(m[row * 5 + 3]))
        }
        filter.setValue(vector(0), forKey: "inputRVector")
        filter.setValue(vector(1), forKey: "inputGVector")
        filter.setValue(vector(2), forKey: "inputBVector")
        filter.setValue(vector(3), forKey: "inputAVector")
        filter.setValue(CIVector(x: CGFloat(m[4]), y: CGFloat(m[9]), z: CGFloat(m[14]), w: CGFloat(m[19])), forKey: "inputBiasVector")
        guard let output = filter.outputImage else { return nil }
        let context = CIContext(options: [.useSoftwareRenderer: true])
        return context.createCGImage(output, from: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    }
}
