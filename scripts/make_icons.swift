#!/usr/bin/env swift
// Biểu tượng TẠM của các bản app (plan giai đoạn 6, bước 1; Nt0 chốt 2026-10-18: agent tạo tạm, Nt0 thay sau). Không
// phải logo thương hiệu: một chữ cái trắng trên màu nhấn của từng bản:
//   - bản Học viên (`Exam Suite`): chữ "E" trên teal `#017777` (`LibraryPalette.accentFill`, chữ trắng 5,38:1);
//   - bản Admin (`Exam Suite Admin`): chữ "A" trên burgundy `#801638` (`AuthoringPalette.accentFill`, chữ trắng ~10:1);
//   - bản iOS (plan-ios-v1.md bước I3): như bản Học viên, một PNG 1024 px vuông kín khung, không kênh alpha (iOS tự bo
//     góc và thu nhỏ cho mọi cỡ).
// Bản macOS là ô bo góc theo khung biểu tượng macOS, bộ PNG 16–1024 px. Vẽ bằng CoreGraphics + CoreText (có sẵn trong
// macOS, không thư viện mới, ADR 0006), xuất PNG và Contents.json vào asset catalog của từng app
// (`Apps/<app>/Assets.xcassets/AppIcon.appiconset`); project.yml khai báo `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`.
// Chạy lại khi đổi màu hay chữ, rồi commit các PNG:
//
//   swift scripts/make_icons.swift
//
// Thay bằng biểu tượng thật: thay các PNG trong các thư mục AppIcon.appiconset (cùng tên file) và bỏ script này.
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct AppIconSpec {
    enum Platform {
        case mac
        case iOS
    }

    let directory: String
    let letter: String
    /// Màu nền dạng 0xRRGGBB (giá trị của bảng màu trong app, xem đầu file).
    let fill: UInt32
    var platform: Platform = .mac
}

let specs = [
    AppIconSpec(directory: "Apps/Student/Assets.xcassets", letter: "E", fill: 0x017777),
    AppIconSpec(directory: "Apps/Admin/Assets.xcassets", letter: "A", fill: 0x801638),
    AppIconSpec(directory: "Apps/StudentiOS/Assets.xcassets", letter: "E", fill: 0x017777, platform: .iOS),
]

/// Kích thước điểm và hệ số của bộ biểu tượng macOS (16, 32, 128, 256, 512 pt; 1x và 2x).
let slots: [(points: Int, scale: Int)] = [16, 32, 128, 256, 512].flatMap { [($0, 1), ($0, 2)] }

let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent()
let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    CGColor(
        colorSpace: sRGB,
        components: [CGFloat((hex >> 16) & 0xFF) / 255, CGFloat((hex >> 8) & 0xFF) / 255, CGFloat(hex & 0xFF) / 255, alpha]
    )!
}

/// Pha `hex` với trắng (`amount` 0–1): đỉnh của dải màu nhẹ.
func lighten(_ hex: UInt32, _ amount: Double) -> UInt32 {
    func mix(_ shift: UInt32) -> UInt32 {
        let channel = Double((hex >> shift) & 0xFF)
        return UInt32((channel + (255 - channel) * amount).rounded()) << shift
    }
    return mix(16) | mix(8) | mix(0)
}

/// Vẽ biểu tượng cạnh `pixels` px, nền dải màu, chữ trắng. macOS: khung macOS (ô 824/1024 ở giữa, bo góc 185/1024,
/// bóng nhẹ). iOS: kín khung, không kênh alpha.
func render(_ spec: AppIconSpec, pixels: Int) -> CGImage {
    let isMac = spec.platform == .mac
    let context = CGContext(
        data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0, space: sRGB,
        bitmapInfo: (isMac ? CGImageAlphaInfo.premultipliedLast : CGImageAlphaInfo.noneSkipLast).rawValue
    )!
    let unit = CGFloat(pixels) / 1024
    let tile = isMac
        ? CGRect(x: 100 * unit, y: 100 * unit, width: 824 * unit, height: 824 * unit)
        : CGRect(x: 0, y: 0, width: CGFloat(pixels), height: CGFloat(pixels))
    let shape = isMac
        ? CGPath(roundedRect: tile, cornerWidth: 185 * unit, cornerHeight: 185 * unit, transform: nil)
        : CGPath(rect: tile, transform: nil)

    if isMac {
        // Bóng nhẹ dưới ô (như khung biểu tượng của macOS).
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -10 * unit), blur: 20 * unit, color: color(0x000000, alpha: 0.3))
        context.addPath(shape)
        context.setFillColor(color(spec.fill))
        context.fillPath()
        context.restoreGState()
    }

    // Nền: dải màu dọc nhẹ (đỉnh sáng hơn 12%).
    context.saveGState()
    context.addPath(shape)
    context.clip()
    let gradient = CGGradient(colorsSpace: sRGB, colors: [color(lighten(spec.fill, 0.12)), color(spec.fill)] as CFArray,
                              locations: [0, 1])!
    context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: tile.maxY), end: CGPoint(x: 0, y: tile.minY), options: [])
    context.restoreGState()

    // Chữ trắng, đậm, căn giữa theo khung nét chữ; cỡ chữ theo ô (560/824 như bản macOS).
    let font = CTFontCreateUIFontForLanguage(.emphasizedSystem, tile.height * 560 / 824, nil)!
    let attributes: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): color(0xFFFFFF),
    ]
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: spec.letter, attributes: attributes))
    let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
    context.textPosition = CGPoint(x: tile.midX - bounds.midX, y: tile.midY - bounds.midY)
    CTLineDraw(line, context)
    return context.makeImage()!
}

func writePNG(_ image: CGImage, to url: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw CocoaError(.fileWriteUnknown)
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
}

func writeJSON(_ object: Any, to url: URL) throws {
    let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
    try (data + Data("\n".utf8)).write(to: url)
}

let info = ["author": "xcode", "version": 1] as [String: Any]
for spec in specs {
    let catalog = root.appendingPathComponent(spec.directory, isDirectory: true)
    let iconSet = catalog.appendingPathComponent("AppIcon.appiconset", isDirectory: true)
    try FileManager.default.createDirectory(at: iconSet, withIntermediateDirectories: true)
    try writeJSON(["info": info], to: catalog.appendingPathComponent("Contents.json"))
    var images: [[String: String]] = []
    switch spec.platform {
    case .mac:
        for slot in slots {
            let name = "icon_\(slot.points)x\(slot.points)\(slot.scale == 2 ? "@2x" : "").png"
            try writePNG(render(spec, pixels: slot.points * slot.scale), to: iconSet.appendingPathComponent(name))
            images.append([
                "filename": name, "idiom": "mac", "scale": "\(slot.scale)x", "size": "\(slot.points)x\(slot.points)",
            ])
        }
    case .iOS:
        // Một ảnh 1024 px cho mọi cỡ (asset catalog "Single Size" của iOS).
        let name = "icon_1024x1024.png"
        try writePNG(render(spec, pixels: 1024), to: iconSet.appendingPathComponent(name))
        images.append(["filename": name, "idiom": "universal", "platform": "ios", "size": "1024x1024"])
    }
    try writeJSON(["images": images, "info": info], to: iconSet.appendingPathComponent("Contents.json"))
    print("ok   \(spec.directory)/AppIcon.appiconset: \(images.count) PNG, chữ \(spec.letter)")
}
