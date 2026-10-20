import AppKit
import Foundation
import LibraryData
@testable import LibraryFeature
import SwiftUI
import Testing

/// Điều hướng lưới bằng phím mũi tên, gộp báo cáo thêm đề qua `ImportFeedback.init`, và độ tương phản của
/// bảng màu (docs/product/library.md, mục Bàn phím và trợ năng).
@MainActor
@Suite("Lưới, gộp báo cáo thêm đề, độ tương phản")
struct GridFeedbackPaletteTests {
    // MARK: - GridNavigation

    @Test("Phím mũi tên trong lưới 3 cột có 5 thẻ (dòng cuối thiếu một thẻ)")
    func gridMoves() {
        func move(_ index: Int?, _ direction: GridNavigation.Direction) -> Int? {
            GridNavigation.move(from: index, direction: direction, count: 5, columns: 3)
        }
        // Chưa chọn: thẻ đầu.
        #expect(move(nil, .down) == 0)
        #expect(move(nil, .left) == 0)
        // Trái/phải theo thứ tự đọc, dừng ở hai đầu.
        #expect(move(0, .left) == 0)
        #expect(move(2, .right) == 3)
        #expect(move(4, .right) == 4)
        // Lên/xuống cùng cột.
        #expect(move(1, .down) == 4)
        #expect(move(4, .up) == 1)
        #expect(move(1, .up) == 1)
        // Dòng áp cuối, ô bên dưới trống (cột 3 của dòng cuối): xuống thì tới thẻ cuối.
        #expect(move(2, .down) == 4)
        // Đã ở dòng cuối: xuống thì đứng yên.
        #expect(move(3, .down) == 3)
        #expect(move(4, .down) == 4)
        // Lưới rỗng; chỉ số ngoài lưới thì về thẻ đầu.
        #expect(GridNavigation.move(from: nil, direction: .down, count: 0, columns: 3) == nil)
        #expect(move(9, .down) == 0)
    }

    @Test("Xuống từ dòng áp cuối khi dòng cuối chỉ có một thẻ, lưới nhiều dòng")
    func downToLastCardFromSecondToLastRow() {
        // 4 cột, 9 thẻ: dòng cuối chỉ có thẻ 8.
        #expect(GridNavigation.move(from: 5, direction: .down, count: 9, columns: 4) == 8)
        #expect(GridNavigation.move(from: 7, direction: .down, count: 9, columns: 4) == 8)
        #expect(GridNavigation.move(from: 4, direction: .down, count: 9, columns: 4) == 8)
        // Dòng đầu xuống dòng hai vẫn đi cùng cột.
        #expect(GridNavigation.move(from: 3, direction: .down, count: 9, columns: 4) == 7)
    }

    @Test("Số cột theo bề rộng")
    func columnsForWidth() {
        #expect(GridNavigation.columns(forWidth: 0, minItemWidth: 270, spacing: 16) == 1)
        #expect(GridNavigation.columns(forWidth: 200, minItemWidth: 270, spacing: 16) == 1)
        #expect(GridNavigation.columns(forWidth: 556, minItemWidth: 270, spacing: 16) == 2)
        #expect(GridNavigation.columns(forWidth: 555, minItemWidth: 270, spacing: 16) == 1)
    }

    // MARK: - ImportFeedback.init

    @Test("Cùng một file đưa vào hai lần trong một lần thêm: chỉ báo “Đã thêm”, không báo “đã có” cho chính đề đó")
    func feedbackDoesNotReportJustAddedExamAsExisting() async throws {
        let workspace = try FeatureWorkspace()
        let store = LibraryStore.inMemory(configuration: workspace.configuration(), defaults: workspace.defaults)
        let exam = makeExam(title: "Đề A")
        let file = try workspace.write(exam, to: "a.exam")
        let garbage = try workspace.writeGarbage(to: "hong.exam")

        let report = await store.importFiles([file, garbage, file])
        // Điều kiện của test: báo cáo có cả "đã thêm" lẫn "đã có" cho cùng đề.
        #expect(report.addedExamIDs == [exam.id])
        #expect(report.alreadyInLibraryExamIDs == [exam.id])

        let feedback = ImportFeedback(report: report, titles: [exam.id: "Đề A"])

        #expect(feedback.notice == "Đã thêm đề “Đề A”.")
        #expect(feedback.examIDToSelect == exam.id)
        #expect(feedback.replacements.isEmpty)
        #expect(feedback.problems.map(\.fileName) == ["hong.exam"])
        #expect(feedback.problems.map(\.position) == [1])
    }

    // MARK: - Độ tương phản

    static let smallText = 4.5
    static let largeTextOrIcon = 3.0

    @Test("Chữ trắng trên nền nút màu nhấn đạt 4,5:1 ở cả hai giao diện")
    func whiteOnAccentFill() {
        for fill in [LibraryPalette.accentFill.light, LibraryPalette.accentFill.dark] {
            #expect(LibraryPalette.contrast(LibraryPalette.white, fill) >= Self.smallText)
        }
        #expect(LibraryPalette.accentFill.light == LibraryPalette.RGB(hex: 0x017777))
    }

    @Test("Chữ teal (nhãn Đề mẫu, nút viền) đạt 4,5:1 trên mọi nền, kể cả nền nhạt của nhãn",
          arguments: [false, true])
    func accentForegroundIsReadable(dark: Bool) {
        let foreground = dark ? LibraryPalette.accentForeground.dark : LibraryPalette.accentForeground.light
        let backgrounds = dark ? LibraryPalette.darkBackgrounds : LibraryPalette.lightBackgrounds
        for background in backgrounds {
            let tinted = foreground.blended(over: background, opacity: LibraryPalette.tintedBackgroundOpacity)
            #expect(LibraryPalette.contrast(foreground, background) >= Self.smallText, "\(background)")
            #expect(LibraryPalette.contrast(foreground, tinted) >= Self.smallText, "\(background)")
        }
    }

    @Test("Biểu tượng trạng thái đạt 3:1 trên mọi nền, kể cả nền nhạt của dải", arguments: [false, true])
    func toneIconsAreVisible(dark: Bool) {
        let backgrounds = dark ? LibraryPalette.darkBackgrounds : LibraryPalette.lightBackgrounds
        for pair in [LibraryPalette.positive, LibraryPalette.warning, LibraryPalette.critical] {
            let color = dark ? pair.dark : pair.light
            for background in backgrounds {
                let tinted = color.blended(over: background, opacity: LibraryPalette.tintedBackgroundOpacity)
                #expect(LibraryPalette.contrast(color, background) >= Self.largeTextOrIcon, "\(color) / \(background)")
                #expect(LibraryPalette.contrast(color, tinted) >= Self.largeTextOrIcon, "\(color) / \(background)")
            }
        }
    }

    @Test("Danh sách nền đo tương phản có đủ các nền bất lợi nhất (không thu hẹp được mà test vẫn xanh)")
    func backgroundsIncludeWorstCases() {
        // Giao diện sáng: nền xám nhất (#ECECEC, nền cửa sổ) bất lợi nhất cho chữ teal đậm.
        let light = Set(LibraryPalette.lightBackgrounds)
        for hex: UInt32 in [0xFFFFFF, 0xF7F7F7, 0xECECEC] {
            #expect(light.contains(LibraryPalette.RGB(hex: hex)), "Thiếu nền sáng \(String(hex, radix: 16))")
        }
        // Giao diện tối: nền sáng nhất (#3A3A3A, nền nhóm/thẻ) bất lợi nhất cho chữ teal sáng.
        let dark = Set(LibraryPalette.darkBackgrounds)
        for hex: UInt32 in [0x1E1E1E, 0x282828, 0x323232, 0x343434, 0x3A3A3A] {
            #expect(dark.contains(LibraryPalette.RGB(hex: hex)), "Thiếu nền tối \(String(hex, radix: 16))")
        }
    }

    @Test("LibraryStyle dựng đúng màu sRGB của LibraryPalette ở từng giao diện", arguments: [false, true])
    func styleColorsMatchPalette(dark: Bool) throws {
        let cases: [(name: String, color: Color, pair: LibraryPalette.Pair)] = [
            ("accent", LibraryStyle.accent, LibraryPalette.accentFill),
            ("accentForeground", LibraryStyle.accentForeground, LibraryPalette.accentForeground),
            ("positive", LibraryStyle.positive, LibraryPalette.positive),
            ("warning", LibraryStyle.warning, LibraryPalette.warning),
            ("critical", LibraryStyle.critical, LibraryPalette.critical),
        ]
        let appearance = try #require(NSAppearance(named: dark ? .darkAqua : .aqua))
        for item in cases {
            var resolved: NSColor?
            appearance.performAsCurrentDrawingAppearance {
                resolved = NSColor(item.color).usingColorSpace(.sRGB)
            }
            let rgb = try #require(resolved, "\(item.name)")
            let expected = dark ? item.pair.dark : item.pair.light
            let actual = [rgb.redComponent, rgb.greenComponent, rgb.blueComponent].map { Int(($0 * 255).rounded()) }
            #expect(actual == [Int(expected.red), Int(expected.green), Int(expected.blue)], "\(item.name)")
        }
    }

    @Test("Công thức tương phản đúng với các mốc đã biết")
    func contrastFormula() {
        let black = LibraryPalette.RGB(hex: 0x000000)
        #expect(abs(LibraryPalette.contrast(black, LibraryPalette.white) - 21) < 0.01)
        #expect(LibraryPalette.contrast(LibraryPalette.white, LibraryPalette.white) == 1)
        // #22A3A3 (bản trước) với chữ trắng chỉ khoảng 3,07:1, không đạt.
        #expect(LibraryPalette.contrast(LibraryPalette.white, LibraryPalette.RGB(hex: 0x22A3A3)) < Self.smallText)
        // #017777 trên nền thẻ tối khoảng 2,3:1, không đạt: vì vậy chữ teal ở giao diện tối dùng màu khác.
        #expect(LibraryPalette.contrast(LibraryPalette.RGB(hex: 0x017777), LibraryPalette.RGB(hex: 0x343434)) < Self.largeTextOrIcon)
    }
}
