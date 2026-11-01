import AppKit
import AuthoringData
@testable import AuthoringFeature
import ExamFile
import ExamKit
import Foundation
@testable import InterfaceCore
@testable import LibraryFeature
@testable import SessionFeature
@testable import SessionModel
import SwiftUI
import Testing

/// **Nền đọc** (plan giai đoạn 6 bước 1; docs/product/accessibility-localization.md, mục Dark Mode và tương phản): ảnh cửa sổ
/// làm bài ở từng nền (giao diện sáng của macOS, một ảnh mỗi nền), **Tối** khi macOS sáng, **Giấy ngà** khi macOS tối (nền
/// giữ nguyên); Xem lại bài và xem trước của Soạn đề ở một nền. Chỉ vùng nội dung câu đổi nền; bảng câu hỏi, thanh công cụ,
/// thanh dưới, thanh bên giữ giao diện macOS (kiểm bằng điểm ảnh ở `ReadingBackgroundScopeTests`).
///
/// Màn làm bài: đúng kịch bản của `attemptPracticeCheckedAnswer` (SessionSnapshotTests): Luyện tập, câu 3 chọn sai (A) rồi
/// **Kiểm tra đáp án**: nhãn Sai trên lựa chọn đang chọn, Đúng trên lựa chọn B, dòng "Chưa đúng", khung giải thích, "Đã kiểm
/// tra". Ảnh Theo hệ thống vì vậy phải giống hệt `attemptPracticeCheckedAnswer.light` (kiểm "Theo hệ thống không đổi" trực
/// tiếp). Màu "Đã đánh dấu" có ở ảnh Xem lại bài.
extension SnapshotSuite {
    @MainActor
    @Suite("Snapshot: nền đọc")
    struct ReadingBackgroundSnapshotTests {
        /// Theo hệ thống vẽ y như trước khi có nền đọc: cùng kịch bản với `attemptPracticeCheckedAnswer`, nên hai ảnh tham chiếu
        /// phải giống hệt từng byte (cả hai ghi lại cùng lúc khi giao diện cố ý đổi).
        @Test func attemptReadingSystem() async throws {
            try await assertAttempt(.system, appearances: [.light])
            let snapshots = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("__Snapshots__")
            let mine = snapshots.appendingPathComponent("ReadingBackgroundSnapshotTests/attemptReadingSystem.light-960x640.png")
            let before = snapshots.appendingPathComponent("SessionSnapshotTests/attemptPracticeCheckedAnswer.light-960x640.png")
            #expect(FileManager.default.contentsEqual(atPath: mine.path, andPath: before.path),
                    "Theo hệ thống phải vẽ giống hệt màn làm bài trước khi có nền đọc (attemptPracticeCheckedAnswer)")
        }

        @Test func attemptReadingWhite() async throws {
            try await assertAttempt(.white, appearances: [.light])
        }

        /// Giấy ngà ở cả giao diện sáng và tối của macOS: hai ảnh có vùng nội dung giống nhau, chỉ phần của macOS đổi.
        @Test func attemptReadingSepia() async throws {
            try await assertAttempt(.sepia, appearances: [.light, .dark])
        }

        @Test func attemptReadingSoftGray() async throws {
            try await assertAttempt(.softGray, appearances: [.light])
        }

        /// Tối khi macOS đang sáng: vùng câu hỏi tối, bảng câu hỏi và thanh dưới sáng.
        @Test func attemptReadingDark() async throws {
            try await assertAttempt(.dark, appearances: [.light])
        }

        /// Xem lại bài, Tối khi macOS sáng: câu 2 trả lời sai, đã đánh dấu ("Sai", "Đã đánh dấu", "Bạn chọn", "Đáp án đúng", giải
        /// thích trên nền Tối); danh sách câu và thanh nút giữ giao diện sáng.
        @Test func answerReviewReadingDark() async throws {
            let window = try await Self.reviewWindow()
            let review = try #require(window.answerReview)
            let defaults = try ZoomDefaults(reading: .dark)
            await SnapshotHost.assertLightAndDark({
                Self.windowContent(window) { AnswerReviewScreen(window: window, review: review, onPracticeIncorrect: {}) }
                    .defaultAppStorage(defaults.defaults)
            }, appearances: [.light])
        }

        /// Xem trước của Soạn đề, Giấy ngà khi macOS sáng: câu nhiều đáp án có ảnh, hai lựa chọn đúng; cây đề và trình soạn giữ
        /// giao diện sáng.
        @Test func authoringPreviewReadingSepia() async throws {
            let document = ExamAuthoringDocument(draft: ExamDraft(package: AuthoringSnapshotTests.package()))
            let editor = document.editor
            editor.selection = .question(QuestionPath(section: 0, question: 1))
            let defaults = try ZoomDefaults(reading: .sepia)
            await SnapshotHost.assertLightAndDark({
                AuthoringWindow(document: document)
                    .defaultAppStorage(defaults.defaults)
            }, appearances: [.light], settle: {
                await editor.waitForValidation()
            })
        }

        /// Trước khi thi cuộn tới cuối (đề 8 phần, chọn câu Theo phần): ô chọn **Nền đọc** với mẫu màu của nền đang chọn (Giấy
        /// ngà), sáng và tối (mẫu màu cố định, không theo giao diện).
        @Test func preExamReadingBackgroundPicker() async throws {
            let harness = SessionHarness()
            let package = ExamPackage(exam: SnapshotContent.manySectionsExam())
            harness.library.add(package)
            let model = PreExamModel(package: package, preset: .fresh, environment: harness.environment)
            model.mode = .exam
            model.selectionKind = .sections
            let defaults = try ZoomDefaults(reading: .sepia)
            await SnapshotHost.assertLightAndDark({
                PreExamView(model: model, onStart: {}, onCancel: {})
                    .tint(SessionStyle.accentForeground)
                    .defaultAppStorage(defaults.defaults)
            }, size: CGSize(width: 600, height: 640), scroll: .bottom)
        }

        // MARK: - Dựng màn

        private func assertAttempt(
            _ background: ReadingBackground,
            appearances: [SnapshotAppearance],
            testName: String = #function,
            line: UInt = #line
        ) async throws {
            let (window, attempt) = try await Self.checkedPractice()
            let defaults = try ZoomDefaults(reading: background)
            await SnapshotHost.assertLightAndDark({
                Self.windowContent(window) { AttemptScreen(window: window, attempt: attempt) }
                    .defaultAppStorage(defaults.defaults)
            }, appearances: appearances, testName: testName, line: line)
        }

        /// Như `SessionWindowRoot`: kích thước tối thiểu, màu nhấn teal, model cửa sổ trong môi trường.
        static func windowContent(_ window: SessionWindowModel, @ViewBuilder _ screen: () -> some View) -> some View {
            screen()
                .navigationTitle(window.title)
                .environment(window)
                .frame(minWidth: SessionStyle.minWindowSize.width, minHeight: SessionStyle.minWindowSize.height)
                .tint(SessionStyle.accentForeground)
        }

        /// Luyện tập, câu 3 chọn sai rồi Kiểm tra đáp án; đồng hồ 1:35 (như `attemptPracticeCheckedAnswer`).
        static func checkedPractice() async throws -> (SessionWindowModel, AttemptModel) {
            let harness = SessionHarness()
            let attempt = try await harness.start(SnapshotContent.attemptPackage(), mode: .practice)
            _ = attempt.goTo(index: 2)
            attempt.answerWrongly()
            attempt.perform(.checkAnswer)
            harness.clock.advance(95)
            attempt.tick()
            return (harness.window(for: attempt), attempt)
        }

        /// Xem lại bài (bộ lọc Tất cả) của đề nhiều phần, câu 2: trả lời sai, đã đánh dấu.
        static func reviewWindow() async throws -> SessionWindowModel {
            let harness = SessionHarness()
            let exam = SnapshotContent.manySectionsExam()
            let window = try await harness.submittedWindow(package: ExamPackage(exam: exam))
            _ = await window.openAnswerReview(filter: .all)
            window.answerReview?.select(index: 1)
            return window
        }
    }

    /// Phạm vi và tương phản của nền đọc đo trên ảnh chụp thật (không so ảnh tham chiếu): nền của bộ màu chỉ phủ vùng nội dung
    /// câu (cửa sổ làm bài, chi tiết Xem lại bài, xem trước của Soạn đề), phần của macOS giữ nền sáng; nhãn Đúng/Sai sau Kiểm
    /// tra đáp án (review độc lập #54 S1) đạt 4,5:1 trên nền thật của hàng ở mọi nền cố định.
    @MainActor
    @Suite("Nền đọc: phạm vi và nhãn Đúng/Sai trên ảnh chụp")
    struct ReadingBackgroundScopeTests {
        typealias RGB = LibraryPalette.RGB

        @Test("Cửa sổ làm bài, Tối khi macOS sáng: vùng câu hỏi nền Tối; thanh công cụ, thanh dưới, bảng câu hỏi giữ nền sáng")
        func attemptScope() async throws {
            let (window, attempt) = try await ReadingBackgroundSnapshotTests.checkedPractice()
            let defaults = try ZoomDefaults(reading: .dark)
            let rep = try await Self.render(
                ReadingBackgroundSnapshotTests.windowContent(window) { AttemptScreen(window: window, attempt: attempt) }
                    .defaultAppStorage(defaults.defaults)
            )
            let dark = ReadingPalette.dark.background
            let middle = rep.pixelsHigh / 2
            // Lề trái của vùng câu hỏi (padding 24 pt): đúng nền Tối.
            #expect(Self.pixel(rep, x: 8, y: middle) == dark, "vùng câu hỏi \(Self.pixel(rep, x: 8, y: middle))")
            // Thanh tiêu đề/thanh công cụ và thanh dưới (hai đầu cột trái), bảng câu hỏi (mép phải): nền sáng của macOS.
            for (name, x, y) in [("thanh công cụ hoặc thanh dưới", 8, 3), ("thanh công cụ hoặc thanh dưới", 8, rep.pixelsHigh - 4),
                                 ("bảng câu hỏi", rep.pixelsWide - 6, middle)] {
                let color = Self.pixel(rep, x: x, y: y)
                #expect(color.luminance > 0.6, "\(name) phải giữ nền sáng: \(color)")
            }
        }

        @Test("Xem lại bài, Tối khi macOS sáng: chi tiết câu nền Tối; danh sách câu giữ nền sáng")
        func answerReviewScope() async throws {
            let window = try await ReadingBackgroundSnapshotTests.reviewWindow()
            let review = try #require(window.answerReview)
            let defaults = try ZoomDefaults(reading: .dark)
            let rep = try await Self.render(
                ReadingBackgroundSnapshotTests.windowContent(window) {
                    AnswerReviewScreen(window: window, review: review, onPracticeIncorrect: {})
                }
                .defaultAppStorage(defaults.defaults)
            )
            let middle = rep.pixelsHigh / 2
            #expect(Self.pixel(rep, x: rep.pixelsWide - 6, y: middle) == ReadingPalette.dark.background, "chi tiết câu")
            #expect(Self.pixel(rep, x: 6, y: middle).luminance > 0.6, "danh sách câu phải giữ nền sáng")
        }

        @Test("Xem trước của Soạn đề, Giấy ngà khi macOS tối: xem trước nền Giấy ngà; cây đề, trình soạn giữ nền tối")
        func authoringPreviewScope() async throws {
            let document = ExamAuthoringDocument(draft: ExamDraft(package: AuthoringSnapshotTests.package()))
            let editor = document.editor
            editor.selection = .question(QuestionPath(section: 0, question: 1))
            let defaults = try ZoomDefaults(reading: .sepia)
            let rep = try await Self.render(
                AuthoringWindow(document: document).defaultAppStorage(defaults.defaults),
                appearance: .dark,
                settle: { await editor.waitForValidation() }
            )
            let middle = rep.pixelsHigh / 2
            #expect(Self.pixel(rep, x: rep.pixelsWide - 6, y: middle) == ReadingPalette.sepia.background, "xem trước")
            #expect(Self.pixel(rep, x: rep.pixelsWide / 2, y: 3).luminance < 0.2, "thanh công cụ phải giữ nền tối")
            #expect(Self.pixel(rep, x: 6, y: middle).luminance < 0.2, "cây đề phải giữ nền tối")
        }

        @Test("Nhãn Đúng/Sai sau Kiểm tra đáp án đạt 4,5:1 trên nền thật của hàng, ở mọi nền cố định (ảnh chụp, macOS sáng)",
              arguments: [ReadingBackground.white, .sepia, .softGray, .dark])
        func checkMarksKeepContrast(background: ReadingBackground) async throws {
            let palette = try #require(background.fixedPalette)
            let (window, attempt) = try await ReadingBackgroundSnapshotTests.checkedPractice()
            let defaults = try ZoomDefaults(reading: background)
            let rep = try await Self.render(
                AttemptScreen(window: window, attempt: attempt)
                    .environment(window)
                    .frame(minWidth: SessionStyle.minWindowSize.width, minHeight: SessionStyle.minWindowSize.height)
                    .tint(SessionStyle.accentForeground)
                    .defaultAppStorage(defaults.defaults)
            )
            // Nửa phải của hàng lựa chọn (x 400–690; bảng câu hỏi bên phải từ ~700 pt; chữ của lựa chọn hết trước x 300). Nền
            // so là điểm ảnh thật của hàng ở x 395 cùng dòng: nút của lựa chọn bị khoá làm mờ cả nền của hàng đang chọn (nền đó
            // pha với nền đọc), còn nhãn Đúng/Sai vẽ ngoài nút (#54). "Sai" chỉ tìm trên dòng có nền khác nền đọc (hàng đang chọn;
            // các hàng khác, đầu câu, dòng kết quả nằm trên nền đọc), nên chữ đỏ/cam khác của màn không được tính thay.
            let sai = try #require(Self.strongestMark(in: rep, columns: 400 ..< 690, referenceX: 395, rows: { $0 != palette.background },
                                                      matches: Self.isRed), "không thấy nhãn Sai trên lựa chọn đang chọn")
            let dung = try #require(Self.strongestMark(in: rep, columns: 400 ..< 690, referenceX: 395, rows: { $0 == palette.background },
                                                       matches: Self.isGreen), "không thấy nhãn Đúng")
            #expect(sai.ratio >= 4.5, "Sai \(sai.rgb) trên hàng đã chọn \(sai.background): \(sai.ratio)")
            #expect(dung.ratio >= 4.5, "Đúng \(dung.rgb) trên nền \(dung.background): \(dung.ratio)")
        }

        @Test("Đối chứng âm: cùng phép đo bắt được nhãn Sai bị làm mờ (trong nút .plain bị khoá) trên lựa chọn đang chọn của mỗi nền",
              arguments: [ReadingBackground.white, .sepia, .softGray, .dark])
        func dimmedCheckMarkFails(background: ReadingBackground) async throws {
            let palette = try #require(background.fixedPalette)
            let size = CGSize(width: 300, height: 80)
            let rep = try await Self.render(
                Button {} label: {
                    OptionCheckMarkLabel(mark: .incorrect)
                        .padding(20)
                }
                .buttonStyle(.plain)
                .disabled(true)
                .frame(width: size.width, height: size.height)
                .background(palette.selectedOptionBackground.fixedColor)
                .environment(\.readingStyle, ReadingStyle(background)),
                size: size
            )
            let sai = try #require(Self.strongestMark(in: rep, columns: 0 ..< Int(size.width), referenceX: 2,
                                                      rows: { $0 == palette.selectedOptionBackground }, matches: Self.isRed),
                                   "không thấy nhãn Sai")
            #expect(sai.ratio < 4.5, "nút khoá phải làm mờ nhãn: \(sai.rgb) trên \(sai.background): \(sai.ratio)")
        }

        /// Điểm ảnh khớp `matches` có tương phản cao nhất với nền của dòng (lõi nét chữ; điểm ảnh khử răng cưa pha với nền). Nền
        /// của mỗi dòng điểm ảnh là điểm `referenceX` của dòng đó; chỉ xét dòng có nền khớp `rows`.
        private static func strongestMark(
            in rep: NSBitmapImageRep, columns: Range<Int>, referenceX: Int, rows: (RGB) -> Bool, matches: (RGB) -> Bool
        ) -> (rgb: RGB, background: RGB, ratio: Double)? {
            var best: (rgb: RGB, background: RGB, ratio: Double)?
            for y in 0 ..< rep.pixelsHigh {
                let background = pixel(rep, x: referenceX, y: y)
                guard rows(background) else { continue }
                for x in columns {
                    let rgb = pixel(rep, x: x, y: y)
                    guard matches(rgb) else { continue }
                    let ratio = LibraryPalette.contrast(rgb, background)
                    if ratio > (best?.ratio ?? 0) { best = (rgb, background, ratio) }
                }
            }
            return best
        }

        /// Tông màu (độ) và độ bão hoà (HSV) của điểm ảnh.
        private static func hueAndSaturation(_ rgb: RGB) -> (hue: Double, saturation: Double) {
            let (r, g, b) = (Double(rgb.red), Double(rgb.green), Double(rgb.blue))
            let high = max(r, g, b), delta = high - min(r, g, b)
            guard high > 0, delta > 0 else { return (0, 0) }
            let hue: Double
            switch high {
            case r: hue = 60 * ((g - b) / delta).truncatingRemainder(dividingBy: 6)
            case g: hue = 60 * ((b - r) / delta + 2)
            default: hue = 60 * ((r - g) / delta + 4)
            }
            return (hue < 0 ? hue + 360 : hue, delta / high)
        }

        /// Đỏ của "Sai" (tông ~4–6°); cam của đánh dấu (~30–37°) và teal (180°) không khớp.
        private static func isRed(_ rgb: RGB) -> Bool {
            let (hue, saturation) = hueAndSaturation(rgb)
            return saturation > 0.25 && (hue < 20 || hue > 340)
        }

        /// Xanh của "Đúng" (tông ~135°); teal (180°) không khớp.
        private static func isGreen(_ rgb: RGB) -> Bool {
            let (hue, saturation) = hueAndSaturation(rgb)
            return saturation > 0.3 && (100 ... 160).contains(hue)
        }

        // MARK: - Ảnh

        private static func render(
            _ content: some View,
            appearance: SnapshotAppearance = .light,
            size: CGSize = SnapshotHost.minimumWindow,
            settle: @MainActor () async -> Void = {}
        ) async throws -> NSBitmapImageRep {
            SnapshotHost.prepareProcess()
            if let problem = await SnapshotHost.environmentProblem() {
                Issue.record(Comment(rawValue: problem))
                throw CancellationError()
            }
            let image = await SnapshotHost.image(of: content, appearance: appearance, size: size, settle: settle)
            return try #require(image.representations.compactMap { $0 as? NSBitmapImageRep }.first)
        }

        private static func pixel(_ rep: NSBitmapImageRep, x: Int, y: Int) -> RGB {
            guard let color = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { return RGB(hex: 0) }
            func channel(_ value: CGFloat) -> UInt32 { UInt32((min(max(value, 0), 1) * 255).rounded()) }
            return RGB(hex: channel(color.redComponent) << 16 | channel(color.greenComponent) << 8 | channel(color.blueComponent))
        }
    }
}
