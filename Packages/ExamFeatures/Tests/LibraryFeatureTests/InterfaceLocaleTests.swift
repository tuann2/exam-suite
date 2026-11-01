import Foundation
@testable import InterfaceCore
@testable import LibraryFeature
import PDFKit
import SwiftUI
import Testing

/// Số, phần trăm, ngày giờ theo locale của **ngôn ngữ giao diện**, không theo Region của macOS
/// (docs/product/accessibility-localization.md, mục Ngôn ngữ; Nt0 giữ quy tắc 2026-10-17; plan giai đoạn 5 bước 7a).
///
/// Mọi kỳ vọng dùng locale tường minh (hoặc ngôn ngữ đã khoá vi của tiến trình test), nên kết quả không phụ thuộc Region
/// của máy chạy test. Chuỗi là đúng những gì `FormatStyle` của Foundation sinh ra trên macOS 15+ (ghi lại ở đây để đổi
/// hành vi thì test đỏ): tiếng Việt "1.234", "85%", "14:05 15/10/2026"; tiếng Anh "1,234", "85%", "10/15/2026, 2:05 PM"
/// (khoảng trắng hẹp U+202F trước PM).
@Suite("Định dạng theo ngôn ngữ giao diện")
struct InterfaceLocaleTests {
    static let vi = Locale(identifier: "vi")
    static let en = Locale(identifier: "en")
    static let utc = TimeZone(identifier: "UTC")!
    /// 15/10/2026 14:05 UTC.
    static let day = Date(timeIntervalSince1970: 1_792_073_100)

    // MARK: - Chọn locale

    private static func resolve(_ preferences: [String], available: [String], pinned: Locale? = nil) -> String {
        InterfaceLocale.resolve(preferences: preferences, available: available, pinned: pinned).identifier
    }

    /// Ngôn ngữ định dạng = ngôn ngữ mà chữ của catalog thật sự ra: ngôn ngữ ưu tiên đầu tiên có trong catalog (tiếng Việt
    /// nguồn luôn có), so theo mã ngôn ngữ (bỏ vùng); không khớp thì tiếng Việt. Trước bước 7c catalog chỉ có `vi`, nên máy
    /// ưu tiên tiếng Anh vẫn ra `vi` (chữ tiếng Việt thì số và ngày cũng dạng tiếng Việt).
    @Test func resolverFollowsCatalogLanguage() {
        // Hiện nay: bundle của module không có `*.lproj` nào (chỉ ngôn ngữ nguồn vi).
        #expect(Self.resolve(["en"], available: ["vi"]) == "vi")
        #expect(Self.resolve(["en"], available: []) == "vi")
        #expect(Self.resolve(["vi"], available: []) == "vi")
        // Sau bước 7c: catalog có `en` (bundle của module chỉ có `en.lproj`, ngôn ngữ nguồn vẫn tra được).
        #expect(Self.resolve(["en"], available: ["vi", "en"]) == "en")
        #expect(Self.resolve(["vi"], available: ["en"]) == "vi")
        #expect(Self.resolve(["fr", "en"], available: ["vi", "en"]) == "en")
        #expect(Self.resolve(["fr"], available: ["vi", "en"]) == "vi")
        #expect(Self.resolve(["fr", "vi", "en"], available: ["vi", "en"]) == "vi")
        #expect(Self.resolve([], available: ["vi", "en"]) == "vi")
        #expect(Self.resolve(["Base", ""], available: ["vi", "en"]) == "vi")
        // Tiến trình không phải app (`swift test`): ngôn ngữ đã khoá của `InterfaceStrings` thắng.
        #expect(Self.resolve(["en"], available: ["vi", "en"], pinned: Locale(identifier: "vi")) == "vi")
    }

    /// Chỉ mã ngôn ngữ, vùng bị bỏ: "en-VN", "en_GB", "vi-US" như "en", "vi".
    @Test func resolverIgnoresRegion() {
        let englishInVietnam = InterfaceLocale.resolve(preferences: ["en-VN"], available: ["vi", "en"], pinned: nil)
        #expect(englishInVietnam.identifier == "en")
        #expect(englishInVietnam.region == nil)
        #expect(Self.resolve(["en_GB"], available: ["vi", "en"]) == "en")
        #expect(Self.resolve(["vi-US"], available: ["vi", "en"]) == "vi")
        #expect(Self.resolve(["en-VN"], available: ["vi"]) == "vi")
    }

    /// Ngôn ngữ của catalog đọc từ bundle: các `*.lproj` đã biên dịch cộng ngôn ngữ nguồn (vùng phát triển của bundle,
    /// không có thì vi). Review #50 N4: kiểm trên bundle dựng tay, vì bundle của module trong test chỉ có ngôn ngữ nguồn
    /// (khẳng định `contains("vi")` trên nó luôn đúng, không chứng minh gì).
    @Test func catalogLanguagesReadCompiledLocalizations() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("catalog-languages-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        func makeBundle(_ name: String, region: String?, lprojs: [String]) throws -> Bundle {
            let url = root.appendingPathComponent("\(name).bundle", isDirectory: true)
            let contents = url.appendingPathComponent("Contents", isDirectory: true)
            try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
            var info: [String: Any] = ["CFBundleIdentifier": "test.\(name)", "CFBundlePackageType": "BNDL"]
            if let region { info["CFBundleDevelopmentRegion"] = region }
            try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
                .write(to: contents.appendingPathComponent("Info.plist"))
            for language in lprojs {
                let lproj = contents.appendingPathComponent("Resources/\(language).lproj", isDirectory: true)
                try FileManager.default.createDirectory(at: lproj, withIntermediateDirectories: true)
                try Data("\"Thư viện\" = \"Library\";".utf8).write(to: lproj.appendingPathComponent("Localizable.strings"))
            }
            return try #require(Bundle(url: url))
        }

        // Như sau bước 7c: catalog có bản `en` (Xcode ghi `en.lproj`), nguồn vi.
        let translated = InterfaceLocale.catalogLanguages(of: try makeBundle("translated", region: "vi", lprojs: ["en"]))
        #expect(Set(translated) == ["en", "vi"])
        #expect(InterfaceLocale.resolve(preferences: ["en-GB"], available: translated, pinned: nil).identifier == "en")
        // Như hiện nay: chưa có `*.lproj` nào, chỉ ngôn ngữ nguồn; ưu tiên tiếng Anh vẫn ra vi.
        let sourceOnly = InterfaceLocale.catalogLanguages(of: try makeBundle("source-only", region: "vi", lprojs: []))
        #expect(Set(sourceOnly) == ["vi"])
        #expect(InterfaceLocale.resolve(preferences: ["en"], available: sourceOnly, pinned: nil).identifier == "vi")
        // Bundle không khai báo vùng phát triển: nguồn mặc định vi.
        #expect(InterfaceLocale.catalogLanguages(of: try makeBundle("no-region", region: nil, lprojs: [])).contains("vi"))
        #expect(InterfaceLocale.calendar.identifier == .gregorian)
    }

    /// Bỏ vùng là có tác dụng: "en_VN" (giao diện tiếng Anh, Region Việt Nam) theo Region sẽ ra "1.234" và
    /// "15/10/2026, 14:05"; theo ngôn ngữ giao diện (khi catalog có `en`) ra dạng tiếng Anh.
    @Test func regionDoesNotChangeFormatting() {
        let regionLocale = Locale(identifier: "en_VN")
        #expect(1234.formatted(.number.locale(regionLocale)) == "1.234")
        let interface = InterfaceLocale.resolve(preferences: [regionLocale.identifier], available: ["vi", "en"], pinned: nil)
        #expect(InterfaceLocale.number(1234, locale: interface) == "1,234")
        #expect(LibraryFormat.dateTime(Self.day, locale: interface, timeZone: Self.utc) == "10/15/2026, 2:05\u{202F}PM")
        let vietnameseInUS = InterfaceLocale.resolve(preferences: ["vi_US"], available: ["vi", "en"], pinned: nil)
        #expect(InterfaceLocale.number(1234, locale: vietnameseInUS) == "1.234")
    }

    @Test func testProcessFormatsAsVietnamese() {
        #expect(InterfaceLocale.current.identifier == "vi")
        #expect(InterfaceLocale.current.region == nil)
    }

    // MARK: - Số, phần trăm, ngày giờ

    @Test func numbersAndPercentages() {
        #expect(InterfaceLocale.number(1175, locale: Self.vi) == "1.175")
        #expect(InterfaceLocale.number(1175, locale: Self.en) == "1,175")
        #expect(InterfaceLocale.number(999, locale: Self.vi) == "999")
        #expect(InterfaceLocale.number(2000) == "2.000")
        #expect(InterfaceLocale.percent(85, locale: Self.vi) == "85%")
        #expect(InterfaceLocale.percent(85, locale: Self.en) == "85%")
        #expect(InterfaceLocale.percent(100) == "100%")
        #expect(LibraryFormat.percent(80) == "80%")
        #expect(LibraryFormat.passThreshold(70) == "Đậu từ 70%")
        #expect(LibraryFormat.questions(2000) == "2.000 câu")
        #expect(LibraryFormat.images(1500) == "1.500 ảnh")
    }

    @Test func datesAndFileSizes() {
        #expect(LibraryFormat.dateTime(Self.day, locale: Self.vi, timeZone: Self.utc) == "14:05 15/10/2026")
        #expect(LibraryFormat.dateTime(Self.day, locale: Self.en, timeZone: Self.utc) == "10/15/2026, 2:05\u{202F}PM")
        #expect(LibraryFormat.date(Self.day, locale: Self.vi, timeZone: Self.utc) == "15/10/2026")
        #expect(LibraryFormat.date(Self.day, locale: Self.en, timeZone: Self.utc) == "10/15/2026")
        // Mặc định: ngôn ngữ giao diện (vi trong test), không phải Region của máy.
        #expect(LibraryFormat.dateTime(Self.day, timeZone: Self.utc) == "14:05 15/10/2026")
        #expect(LibraryFormat.fileSize(1_350_000, locale: Self.vi) == "1,4 MB")
        #expect(LibraryFormat.fileSize(1_350_000, locale: Self.en) == "1.4 MB")
        #expect(LibraryFormat.fileSize(1_350_000) == "1,4 MB")
    }

    // MARK: - Thang 1000 (ngoại lệ: số trơn)

    /// Thang 1000 luôn số trơn ở mọi ngôn ngữ (Nt0 chốt 2026-10-17): "1000", không "1.000"/"1,000". Ô cột Thang 1000 của
    /// Lịch sử thi vẽ dưới locale vi và en (đọc lại chữ trên PDF) vẫn ra "1000".
    @MainActor
    @Test func scale1000IsPlainDigits() throws {
        #expect(InterfaceLocale.scale1000(1000) == "1000")
        #expect(InterfaceLocale.scale1000(850) == "850")
        for locale in [Self.vi, Self.en] {
            let text = try renderedText(HistoryView.scale1000Cell(1000).interfaceLocale(locale))
            #expect(text.contains("1000"), "\(locale.identifier): \(text)")
            #expect(!text.contains("1.000") && !text.contains("1,000"), "\(locale.identifier): \(text)")
        }
        // Đối chứng: số thường dưới cùng locale thì có ngăn nghìn.
        #expect(try renderedText(Text(1000, format: .number).interfaceLocale(Self.vi)).contains("1.000"))
    }

    // MARK: - Số nội suy trong chữ của catalog

    /// Ba đường tra chữ: khoá ngôn ngữ (test), theo bundle chính (app) và mặc định (`localized`). Số nội suy theo locale
    /// truyền vào hoặc ngôn ngữ giao diện, không theo `Locale.current`. Chữ tiếng Anh chưa dịch (bước 7c) nên chỉ so số.
    @Test func interpolatedNumbersFollowInterfaceLanguage() {
        let bundle = InterfaceCore.ModuleStrings.bundle
        #expect(InterfaceStrings.resolve("\(2000) câu", bundle: bundle, locale: Self.vi) == "2.000 câu")
        #expect(InterfaceStrings.resolve("\(2000) câu", bundle: bundle, locale: Self.en).hasPrefix("2,000 "))
        #expect(InterfaceStrings.resolveFollowingMainBundle("\(2000) câu", bundle: bundle, formatLocale: Self.vi)
            .hasPrefix("2.000 "))
        #expect(InterfaceStrings.resolveFollowingMainBundle("\(2000) câu", bundle: bundle, formatLocale: Self.en)
            .hasPrefix("2,000 "))
        #expect(InterfaceStrings.resolve("\(2000) câu", bundle: bundle, locale: nil).hasPrefix("2.000 "))
        #expect(InterfaceCore.localized("\(2000) câu") == "2.000 câu")
    }

    // MARK: - SwiftUI

    /// `.interfaceLocale()` ở gốc là đủ cho view: SwiftUI định dạng nội suy của `Text("…", bundle:)` và
    /// `Text(n, format:)` theo `\.locale` của môi trường (đọc lại chữ trên PDF dựng bằng `ImageRenderer`).
    @MainActor
    @Test func swiftUITextFollowsEnvironmentLocale() throws {
        let bundle = InterfaceCore.ModuleStrings.bundle
        let view = VStack {
            Text("\(2000) câu", bundle: bundle)
            Text(1234, format: .number)
        }
        let vietnamese = try renderedText(view.interfaceLocale(Self.vi))
        #expect(vietnamese.contains("2.000"))
        #expect(vietnamese.contains("1.234"))
        let english = try renderedText(view.interfaceLocale(Self.en))
        #expect(english.contains("2,000"))
        #expect(english.contains("1,234"))
        // Mặc định của `.interfaceLocale()` là ngôn ngữ giao diện (vi trong test).
        #expect(try renderedText(view.interfaceLocale()).contains("1.234"))
    }

    /// Review #50 N1: `.interfaceLocale()` đặt cả lịch của môi trường (Gregorian), không chỉ `\.locale`; lịch Phật hay
    /// lịch Nhật của Region (môi trường bên ngoài) không lọt vào view.
    @MainActor
    @Test func interfaceLocaleSetsGregorianCalendar() throws {
        let buddhist = Calendar(identifier: .buddhist)
        #expect(try renderedText(CalendarProbe().environment(\.calendar, buddhist)).contains("calendar=other"))
        let probed = try renderedText(CalendarProbe().interfaceLocale().environment(\.calendar, buddhist))
        #expect(probed.contains("calendar=gregorian"))
    }

    private struct CalendarProbe: View {
        @Environment(\.calendar) private var calendar

        var body: some View {
            Text(verbatim: calendar.identifier == .gregorian ? "calendar=gregorian" : "calendar=other")
        }
    }

    @MainActor
    private func renderedText(_ view: some View) throws -> String {
        let renderer = ImageRenderer(content: view)
        renderer.proposedSize = ProposedViewSize(width: 400, height: nil)
        let data = NSMutableData()
        renderer.render { size, draw in
            var box = CGRect(origin: .zero, size: size)
            guard let consumer = CGDataConsumer(data: data as CFMutableData),
                  let context = CGContext(consumer: consumer, mediaBox: &box, nil)
            else { return }
            context.beginPDFPage(nil)
            draw(context)
            context.endPDFPage()
            context.closePDF()
        }
        let document = try #require(PDFDocument(data: data as Data))
        return document.string ?? ""
    }
}
