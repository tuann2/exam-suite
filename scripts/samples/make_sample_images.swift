// Vẽ ảnh minh hoạ cho hai đề mẫu của Thư viện (docs/product/library.md, mục Đề mẫu).
// Chỉ dùng AppKit + CryptoKit có sẵn trên macOS; không tải gì từ Internet. Không chạy trên CI.
//
// Dùng: swift scripts/samples/make_sample_images.swift Packages/SharedFeatures/Sources/LibraryData/Resources/Samples
// Ảnh được ghi vào <Samples>/<đề>/media/<16 hex đầu SHA-256 nội dung>.png (docs/product/exam-format.md).
// Font hệ thống khác nhau giữa các bản macOS nên vẽ lại có thể ra tên khác: khi đó sửa trường
// "image" trong exam.json theo tên script in ra và xoá ảnh cũ (scripts/validate_exam.py --all
// báo ảnh thừa hoặc thiếu).
import AppKit
import CryptoKit

let width: CGFloat = 800
let height: CGFloat = 450
let scale = 2 // ảnh 800×450 điểm ra 1600×900 px, khai báo 144 dpi để hiện đúng cỡ điểm trên màn Retina

func rgb(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

let teal = rgb(0x017777)
let ink = rgb(0x1D2A2A)
let muted = rgb(0x5B6B6B)

func font(_ size: CGFloat, _ weight: NSFont.Weight = .regular, mono: Bool = false) -> NSFont {
    mono ? .monospacedSystemFont(ofSize: size, weight: weight) : .systemFont(ofSize: size, weight: weight)
}

/// Vẽ chữ, gốc toạ độ ở góc trên trái (ngữ cảnh lật).
func text(_ s: String, _ x: CGFloat, _ y: CGFloat, _ f: NSFont, _ color: NSColor = ink) {
    NSAttributedString(string: s, attributes: [.font: f, .foregroundColor: color]).draw(at: NSPoint(x: x, y: y))
}

func textWidth(_ s: String, _ f: NSFont) -> CGFloat {
    NSAttributedString(string: s, attributes: [.font: f]).size().width
}

func box(_ r: NSRect, radius: CGFloat, fill: NSColor, stroke: NSColor? = nil, lineWidth: CGFloat = 1) {
    let p = NSBezierPath(roundedRect: r, xRadius: radius, yRadius: radius)
    fill.setFill()
    p.fill()
    if let stroke {
        stroke.setStroke()
        p.lineWidth = lineWidth
        p.stroke()
    }
}

/// Một phím: bóng dưới + mặt phím + nhãn ở giữa. Trả về chiều rộng phím.
@discardableResult
func key(_ label: String, _ x: CGFloat, _ y: CGFloat) -> CGFloat {
    // Dấu chấm của ⌘. ở cỡ chữ thường quá nhỏ, vẽ to hơn cho dễ thấy.
    let f = label == "." ? font(28, .heavy) : font(18, .semibold)
    let w = max(40, textWidth(label, f) + 24)
    box(NSRect(x: x, y: y + 3, width: w, height: 40), radius: 7, fill: rgb(0xB7C6C6))
    box(NSRect(x: x, y: y, width: w, height: 40), radius: 7, fill: .white, stroke: rgb(0x9FB1B1), lineWidth: 1.5)
    text(label, x + (w - textWidth(label, f)) / 2, label == "." ? y + 1 : y + 9, f)
    return w
}

/// Vẽ một ảnh `size` điểm (mặc định 800×450) ra PNG ở `scale` lần.
func render(_ size: NSSize, _ draw: () -> Void) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(size.width) * scale, pixelsHigh: Int(size.height) * scale,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = size
    let base = NSGraphicsContext(bitmapImageRep: rep)!
    let cg = base.cgContext
    cg.translateBy(x: 0, y: size.height)
    cg.scaleBy(x: 1, y: -1)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: true)
    draw()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

// MARK: - Đề "Làm quen với Exam Suite": bảng phím tắt khi làm bài

/// Bảng phím của cửa sổ làm bài, đúng thứ tự và tên hành động của bảng "Bàn phím và trợ năng" trong
/// docs/product/exam-taking.md (gồm cả các phím của bảng Phím tắt trong exam-session.md).
/// Đổi phím trong tài liệu thì sửa bảng này, vẽ lại ảnh và sửa câu 7 của đề "Làm quen".
let shortcutRows: [(keys: [String], more: Bool, label: String)] = [
    (["A", "B", "C"], true, "Chọn đáp án theo vị trí"),
    (["←", "→"], false, "Câu trước / câu sau"),
    (["Return"], false, "Câu tiếp theo"),
    (["⌘", "D"], false, "Đánh dấu"),
    (["⌘", "."], false, "Tạm dừng / tiếp tục"),
    (["⌘", "K"], false, "Kiểm tra đáp án (Luyện tập)"),
    (["⌘", "Return"], false, "Rà soát & nộp"),
    (["⌃", "⌘", "I"], false, "Ẩn/hiện bảng câu hỏi"),
    (["Esc"], false, "Quay lại làm bài (ở Rà soát)"),
]
let shortcutTop: CGFloat = 108
let shortcutRowHeight: CGFloat = 50
/// Cao vừa đủ cho mọi dòng của bảng, chừa lề dưới bằng lề trái.
let shortcutSize = NSSize(width: width, height: shortcutTop + shortcutRowHeight * CGFloat(shortcutRows.count) + 8 + 40)

func shortcuts() {
    rgb(0xF4F8F8).setFill()
    NSRect(origin: .zero, size: shortcutSize).fill()
    box(NSRect(x: 0, y: 0, width: width, height: 8), radius: 0, fill: teal)
    text("Phím tắt khi làm bài", 40, 28, font(30, .bold), teal)
    text("Luyện tập và Thi trong Exam Suite", 40, 70, font(17), muted)

    let top = shortcutTop, rowHeight = shortcutRowHeight
    box(NSRect(x: 40, y: top, width: 720, height: rowHeight * CGFloat(shortcutRows.count) + 8), radius: 12,
        fill: .white, stroke: rgb(0xD5E2E2))
    for (i, row) in shortcutRows.enumerated() {
        let y = top + 8 + CGFloat(i) * rowHeight
        if i > 0 {
            rgb(0xE3ECEC).setFill()
            NSRect(x: 56, y: y - 5, width: 688, height: 1).fill()
        }
        var x: CGFloat = 60
        for k in row.keys {
            x += key(k, x, y) + 6
        }
        if row.more { text("…", x + 2, y + 6, font(20, .semibold), muted) }
        text(row.label, 300, y + 8, font(19, .medium))
    }
}

// MARK: - Đề "An toàn thông tin cơ bản": email lừa đảo (giả, chỉ để minh hoạ)

func phishingEmail() {
    rgb(0xE9EDF1).setFill()
    NSRect(x: 0, y: 0, width: width, height: height).fill()
    box(NSRect(x: 28, y: 20, width: 744, height: 410), radius: 12, fill: .white, stroke: rgb(0xC5CED8))
    // Thanh tiêu đề chung chung, không mô phỏng phần mềm cụ thể nào.
    box(NSRect(x: 29, y: 21, width: 742, height: 38), radius: 11, fill: rgb(0xF2F4F7))
    rgb(0xF2F4F7).setFill()
    NSRect(x: 29, y: 45, width: 742, height: 14).fill()
    text("Hộp thư đến", 48, 30, font(15, .semibold), muted)
    let tag = "ẢNH MINH HOẠ"
    let tagFont = font(12, .bold)
    let tagW = textWidth(tag, tagFont) + 20
    box(NSRect(x: 752 - tagW, y: 29, width: tagW, height: 22), radius: 11, fill: rgb(0xFFE9C2))
    text(tag, 762 - tagW, 32, tagFont, rgb(0x8A5A00))

    let labelFont = font(15, .medium)
    let rows: [(String, String, NSFont)] = [
        ("Từ:", "Bộ phận CNTT <hotro-cntt@congty-baomat.test>", font(15)),
        ("Đến:", "ban@congty.example", font(15)),
        ("Tiêu đề:", "[KHẨN] Hộp thư của bạn sẽ bị khoá sau 2 giờ", font(15, .bold)),
    ]
    for (i, row) in rows.enumerated() {
        let y = 74 + CGFloat(i) * 28
        text(row.0, 52, y, labelFont, muted)
        text(row.1, 130, y, row.2)
    }
    rgb(0xE1E6EC).setFill()
    NSRect(x: 52, y: 162, width: 696, height: 1).fill()

    let body = font(16)
    text("Chào bạn,", 52, 178, body)
    text("Hệ thống phát hiện đăng nhập bất thường vào hộp thư của bạn.", 52, 206, body)
    text("Để tránh bị KHOÁ, hãy xác minh mật khẩu ngay trong vòng 2 giờ.", 52, 234, body)

    let button = NSRect(x: 52, y: 272, width: 190, height: 42)
    box(button, radius: 8, fill: rgb(0xC62828))
    let bf = font(17, .semibold)
    text("Xác minh ngay", button.midX - textWidth("Xác minh ngay", bf) / 2, 282, bf, .white)

    // Con trỏ chuột đặt trên nút và địa chỉ thật hiện ra khi rê chuột.
    let cursor = NSBezierPath()
    let cx: CGFloat = 222, cy: CGFloat = 290
    cursor.move(to: NSPoint(x: cx, y: cy))
    cursor.line(to: NSPoint(x: cx, y: cy + 22))
    cursor.line(to: NSPoint(x: cx + 5.5, y: cy + 17))
    cursor.line(to: NSPoint(x: cx + 9.5, y: cy + 25.5))
    cursor.line(to: NSPoint(x: cx + 13, y: cy + 24))
    cursor.line(to: NSPoint(x: cx + 9, y: cy + 15.5))
    cursor.line(to: NSPoint(x: cx + 16, y: cy + 15.5))
    cursor.close()
    NSColor.black.setFill()
    cursor.fill()
    NSColor.white.setStroke()
    cursor.lineWidth = 1.5
    cursor.stroke()

    let url = "http://xac-minh-hop-thu.test/congty/dang-nhap"
    let uf = font(14, mono: true)
    let tip = NSRect(x: 238, y: 322, width: textWidth(url, uf) + 20, height: 28)
    box(tip, radius: 6, fill: rgb(0xFFF8D6), stroke: rgb(0xD9C66B))
    text(url, tip.minX + 10, tip.minY + 5, uf)

    text("Trân trọng,", 52, 366, body)
    text("Bộ phận CNTT", 52, 392, font(16, .semibold))
}

// MARK: - Ghi file

guard CommandLine.arguments.count == 2 else {
    print("Dùng: swift scripts/samples/make_sample_images.swift <thư-mục-Samples>")
    exit(2)
}
let samples = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let images: [(exam: String, name: String, size: NSSize, draw: () -> Void)] = [
    ("lam-quen-exam-suite", "phím tắt", shortcutSize, shortcuts),
    ("an-toan-thong-tin-co-ban", "email lừa đảo", NSSize(width: width, height: height), phishingEmail),
]
for image in images {
    let data = render(image.size, image.draw)
    let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined().prefix(16)
    let media = samples.appendingPathComponent("\(image.exam)/media", isDirectory: true)
    try FileManager.default.createDirectory(at: media, withIntermediateDirectories: true)
    try data.write(to: media.appendingPathComponent("\(hash).png"))
    print("ok   \(image.exam) (\(image.name)): media/\(hash).png, \(data.count / 1024) KB")
}
