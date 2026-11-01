import AppKit
import AuthoringData
@testable import AuthoringFeature
import ExamFile
import ExamImport
import ExamKit
import Foundation
import InterfaceCore
import LibraryFeature
import SwiftUI
import Testing

/// Cửa sổ soạn đề (bản Admin) ở 960×640, sáng và tối: cây đề, trình soạn câu, xem trước (docs/product/authoring.md).
extension SnapshotSuite {
    @MainActor
    @Suite("Snapshot: soạn đề")
    struct AuthoringSnapshotTests {
        /// Câu dài với 10 lựa chọn đang chọn trên cây đề: trình soạn câu ở giữa, xem trước bên phải.
        @Test func authoringQuestionEditorAndPreview() async throws {
            let document = ExamAuthoringDocument(draft: ExamDraft(package: Self.package()))
            let editor = document.editor
            editor.selection = .question(QuestionPath(section: 0, question: 0))
            await SnapshotHost.assertLightAndDark({
                AuthoringWindow(document: document)
            }, settle: {
                await editor.waitForValidation()
            })
        }

        /// Câu có ảnh lớn và một lỗi kiểm đề (lựa chọn C trống): thanh lỗi ở đáy.
        @Test func authoringImageQuestionWithIssue() async throws {
            var package = Self.package()
            package.exam.sections[0].questions[1].options[2].text = ""
            let document = ExamAuthoringDocument(draft: ExamDraft(package: package))
            let editor = document.editor
            editor.selection = .question(QuestionPath(section: 0, question: 1))
            await SnapshotHost.assertLightAndDark({
                AuthoringWindow(document: document)
            }, settle: {
                await editor.waitForValidation()
            })
        }

        /// Đề vừa import (bảng **báo cáo import** ở đáy cột giữa, trên thanh lỗi đang mở danh sách lỗi): câu có ảnh với một
        /// lỗi kiểm đề đang chọn. Như cửa sổ sau **Import đề…** (docs/product/import.md, Luồng bước 5).
        @Test func authoringImportReport() async throws {
            var package = Self.package()
            package.exam.sections[0].questions[1].options[2].text = ""
            let questionID = package.exam.sections[0].questions[1].id
            let report = ExamImport.ImportReport(entries: [
                ImportReportEntry(code: .textBeforeFirstQuestion, location: ImportLocation(line: 1), questionID: nil,
                                  detail: .textBeforeFirstQuestion(fromLine: 1, toLine: 3)),
                ImportReportEntry(code: .missingAnswer, location: ImportLocation(questionNumber: 2, line: 14),
                                  questionID: questionID, detail: .missingAnswerLine),
                ImportReportEntry(code: .noOptions, location: ImportLocation(questionNumber: 7, line: 52), questionID: nil,
                                  detail: .noOptions(misplaced: nil)),
            ])
            let document = ExamAuthoringDocument(imported: ImportedExam(
                draft: ExamDraft(package: package),
                report: ImportReportState(fileName: "Ngoại thương 2026.docx", report: report)
            ))
            let editor = document.editor
            editor.selection = .question(QuestionPath(section: 0, question: 1))
            editor.isIssueListExpanded = true
            await SnapshotHost.assertLightAndDark({
                AuthoringWindow(document: document)
            }, settle: {
                await editor.waitForValidation()
            })
        }

        /// Xem trước ở cỡ chữ nội dung 150% (Phóng to, phương án 5), ảnh sáng: câu nhiều đáp án có ảnh, hai lựa chọn đúng; nhãn
        /// "Đáp án đúng" dưới chữ lựa chọn xuống dòng khi cột hẹp, không tràn khỏi hàng (trước bước 8b có `.fixedSize()`).
        /// Cây đề và trình soạn giữ cỡ chữ của macOS.
        @Test func authoringPreviewZoom150() async throws {
            let document = ExamAuthoringDocument(draft: ExamDraft(package: Self.package()))
            let editor = document.editor
            editor.selection = .question(QuestionPath(section: 0, question: 1))
            let zoom = try ZoomDefaults(.largest)
            await SnapshotHost.assertLightAndDark({
                AuthoringWindow(document: document)
                    .defaultAppStorage(zoom.defaults)
            }, appearances: [.light], settle: {
                await editor.waitForValidation()
            })
        }

        // MARK: - Hộp xác nhận Import đề (lỗi beta G6.2)

        /// Cửa sổ **Import đề…** ở bước xác nhận, đúng cỡ cửa sổ thật (cửa sổ `.contentSize` lấy cỡ nhỏ nhất của nội dung),
        /// trạng thái cao nhất: tên file dài, mọi ô báo lỗi, tóm tắt như file của lỗi beta. Bốn ô có viền, bốn dòng báo lỗi và
        /// dòng ghi chú phải hiện đủ (lỗi: `Form` co về cao 0, ghi chú bị cắt; S1: ô trống không viền trông như không có ô).
        /// Ảnh sáng, tiếng Việt.
        @Test func importConfirmProblems() async throws {
            await assertImportConfirm()
        }

        /// Như `importConfirmProblems`, giao diện tiếng Anh (chữ dài hơn: dòng báo lỗi mã đề, nhãn thời gian và ghi chú
        /// xuống dòng).
        @Test func importConfirmProblemsEnglish() async throws {
            try await SnapshotHost.inLanguage(Locale(identifier: "en")) {
                await assertImportConfirm()
            }
        }

        /// Ô trống chưa có tiêu điểm của hộp xác nhận (ngưỡng đậu, thời gian Thi) có viền thấy được ở **cả bốn cạnh**, sáng
        /// và tối (Nt0 chốt 2026-10-19, review độc lập #60 S1: ô của `Form` `.grouped` không viền, vùng nhập của ô trống là
        /// một màu phẳng). Đo trên ảnh chụp quanh khung của chính ô chữ AppKit, từng cạnh một (`FieldBorder`). Hai đối chứng
        /// âm: ô chữ mặc định của `Form` `.grouped` (không viền) phẳng ở mọi cạnh; ô có nền ô mà không viền dưới ngưỡng ở mọi
        /// cạnh.
        @Test(arguments: SnapshotAppearance.allCases)
        func importConfirmEmptyFieldsHaveBorder(appearance: SnapshotAppearance) async throws {
            SnapshotHost.prepareProcess()
            if let problem = await SnapshotHost.environmentProblem() {
                Issue.record(Comment(rawValue: problem))
                return
            }
            let size = await SnapshotHost.minimumContentSize(
                of: ImportExamRoot(model: try await ContentSizedWindowTests.confirmingModel())
            )
            let fields = try await Self.emptyFieldBorders(
                ImportExamRoot(model: try await ContentSizedWindowTests.confirmingModel()), appearance: appearance, size: size
            )
            #expect(fields.count == 2, "phải có hai ô trống chưa có tiêu điểm (ngưỡng đậu, thời gian): \(fields)")
            for field in fields {
                #expect(field.sides.count == 4 && field.weakest >= Self.borderContrast,
                        "ô trống không thấy viền ở mọi cạnh (ngưỡng \(Self.borderContrast):1): \(field)")
            }

            // Đối chứng âm: hai ô của `Form` `.grouped` không đặt kiểu viền (như hộp xác nhận trước S1).
            let plain = Form {
                TextField(String("A"), text: .constant(""))
                TextField(String("B"), text: .constant(""))
            }
            .formStyle(.grouped)
            .frame(width: 480, height: 200)
            let unbordered = try await Self.emptyFieldBorders(plain, appearance: appearance, size: CGSize(width: 480, height: 200))
            #expect(!unbordered.isEmpty, "đối chứng âm phải có ô trống chưa có tiêu điểm")
            for field in unbordered {
                #expect(field.sides.count == 4 && field.strongest < 1.05,
                        "đối chứng âm: ô không viền phải phẳng ở mọi cạnh: \(field)")
            }

            // Đối chứng âm thứ hai: ô có nền ô (màu nền chữ của hệ thống) nhưng không viền, cùng bố cục với hộp xác nhận (nhãn
            // bên trái, ô 200 pt bên phải, trong `Form` `.grouped`): chỉ có bậc nền cửa sổ/nền ô (1,07 sáng, 1,09 tối), phải
            // dưới ngưỡng ở mọi cạnh; bậc đó phải đo được (> 1,03), để đối chứng không đạt vì phẳng.
            let filled = Form {
                HStack(spacing: 12) {
                    Text(String("A")).frame(maxWidth: .infinity, alignment: .leading)
                    TextField(String("A"), text: .constant(""))
                        .labelsHidden()
                        .textFieldStyle(.plain)
                        .frame(width: 200)
                        .background(Color(nsColor: .textBackgroundColor))
                }
            }
            .formStyle(.grouped)
            .frame(width: 480, height: 200)
            let unstroked = try await Self.emptyFieldBorders(filled, appearance: appearance, size: CGSize(width: 480, height: 200))
            #expect(unstroked.count == 1, "đối chứng âm thứ hai phải có một ô trống chưa có tiêu điểm: \(unstroked)")
            for field in unstroked {
                #expect(field.sides.count == 4 && field.strongest < Self.borderContrast && field.weakest > 1.03,
                        "đối chứng âm: ô có nền, không viền phải dưới ngưỡng ở mọi cạnh và có bậc nền đo được: \(field)")
            }
        }

        /// Tương phản tối thiểu của **mỗi** cạnh viền với nền trong ô trống (`FieldBorder.weakest`). Đo trên macOS 26.6
        /// (Xcode 27), ảnh 1 điểm ảnh/pt: cạnh yếu nhất 1,19:1 ở cả hai giao diện (sáng: cạnh trên/dưới `#EBEBEB` trên nền ô
        /// `#FFFFFF`, hai cạnh bên 1,30–1,32; tối: hai cạnh bên `#2C2C2C` trên `#1E1E1E`, cạnh trên/dưới 3,62); ô không viền
        /// 1,00. Ô có nền ô mà không viền (đối chứng âm thứ hai) chỉ có bậc nền cửa sổ/nền ô ở mọi cạnh: 1,07 (sáng,
        /// `#F7F7F7`/`#FFFFFF`), 1,09 (tối, `#252525`/`#1E1E1E`). Ngưỡng 1,12 nằm giữa hai nhóm (review lại #60). Bản đầu (ngưỡng 1,2) lấy điểm ảnh sáng
        /// nhất và tối nhất của cả khung ô: 1,32:1 (sáng) chỉ đến từ góc bo của hai cạnh bên, còn cạnh trên/dưới 1,19 dưới
        /// ngưỡng, nên test không đòi viền ở mọi cạnh. Viền là màu của hệ thống (`.roundedBorder`), được miễn quy tắc 3:1 của
        /// app (accessibility-localization.md, Dark Mode và tương phản); ngưỡng chỉ phân biệt có viền với không viền.
        static let borderContrast = 1.12

        /// Tương phản của bốn cạnh một ô chữ trống với nền trong ô. Viền `.roundedBorder` của macOS 26 nằm sát hoặc ngay
        /// ngoài khung `NSTextField` (hai cạnh bên: cột ngoài khung 1 điểm ảnh), nên mỗi cạnh xét các dòng (cột) điểm ảnh từ
        /// `outside` điểm ảnh ngoài khung tới `inside` điểm ảnh trong khung, lấy dòng có độ sáng trung bình (trên nửa giữa
        /// của cạnh, bỏ góc bo) khác nền trong ô nhiều nhất; nền trong ô là độ sáng trung bình của phần cách mép hơn `inside`.
        struct FieldBorder: CustomStringConvertible {
            static let outside = 2
            static let inside = 3
            let frame: CGRect
            /// Trên, dưới, trái, phải; rỗng khi không đo được (ô quá nhỏ, nền trong ô hay cả một cạnh nằm ngoài ảnh).
            let sides: [Double]
            var weakest: Double { sides.min() ?? 1 }
            var strongest: Double { sides.max() ?? 1 }
            var description: String {
                let values = zip(["trên", "dưới", "trái", "phải"], sides).map { "\($0) \(String(format: "%.2f", $1))" }
                return "\(frame): \(values.isEmpty ? "không đo được" : values.joined(separator: ", "))"
            }
        }

        /// Chụp `content` và đo viền (`FieldBorder`) của từng ô chữ AppKit đang trống và chưa có tiêu điểm.
        private static func emptyFieldBorders(
            _ content: some View, appearance: SnapshotAppearance, size: CGSize
        ) async throws -> [FieldBorder] {
            var frames: [CGRect] = []
            let image = await SnapshotHost.image(of: content, appearance: appearance, size: size, inspect: { frameView in
                func visit(_ view: NSView) {
                    if let field = view as? NSTextField, field.isEditable, field.stringValue.isEmpty,
                       field.currentEditor() == nil, !field.isHidden, field.bounds.height > 1 {
                        let rect = field.convert(field.bounds, to: frameView)
                        // Ảnh có gốc ở góc trên trái; khung cửa sổ của AppKit có thể không lật.
                        frames.append(frameView.isFlipped ? rect : CGRect(
                            x: rect.minX, y: frameView.bounds.height - rect.maxY, width: rect.width, height: rect.height
                        ))
                    }
                    view.subviews.forEach(visit)
                }
                visit(frameView)
            })
            let rep = try #require(image.representations.compactMap { $0 as? NSBitmapImageRep }.first)
            func luminance(x: Int, y: Int) -> Double {
                guard let color = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { return 0 }
                func channel(_ value: CGFloat) -> UInt32 { UInt32((min(max(value, 0), 1) * 255).rounded()) }
                return LibraryPalette.RGB(
                    hex: channel(color.redComponent) << 16 | channel(color.greenComponent) << 8 | channel(color.blueComponent)
                ).luminance
            }
            /// Độ sáng trung bình của vùng, bỏ phần ngoài ảnh; `nil` khi cả vùng nằm ngoài ảnh (không coi là màu đen).
            func mean(xs: Range<Int>, ys: Range<Int>) -> Double? {
                let xs = xs.clamped(to: 0 ..< rep.pixelsWide), ys = ys.clamped(to: 0 ..< rep.pixelsHigh)
                guard !xs.isEmpty, !ys.isEmpty else { return nil }
                var total = 0.0
                for y in ys { for x in xs { total += luminance(x: x, y: y) } }
                return total / Double(xs.count * ys.count)
            }
            let (outside, inside) = (FieldBorder.outside, FieldBorder.inside)
            var borders: [FieldBorder] = []
            for frame in frames {
                let box = frame.integral
                let (minX, maxX, minY, maxY) = (Int(box.minX), Int(box.maxX), Int(box.minY), Int(box.maxY))
                guard maxX - minX > 4 * inside, maxY - minY > 4 * inside else {
                    borders.append(FieldBorder(frame: frame, sides: []))
                    continue
                }
                let middleX = minX + (maxX - minX) / 4 ..< maxX - (maxX - minX) / 4
                let middleY = minY + (maxY - minY) / 4 ..< maxY - (maxY - minY) / 4
                // Độ sáng trung bình của từng dòng (cột) quanh mép: trên, dưới, trái, phải; dòng ngoài ảnh bị bỏ.
                let sides: [[Double]] = [
                    (minY - outside ..< minY + inside).compactMap { mean(xs: middleX, ys: $0 ..< $0 + 1) },
                    (maxY - inside ..< maxY + outside).compactMap { mean(xs: middleX, ys: $0 ..< $0 + 1) },
                    (minX - outside ..< minX + inside).compactMap { mean(xs: $0 ..< $0 + 1, ys: middleY) },
                    (maxX - inside ..< maxX + outside).compactMap { mean(xs: $0 ..< $0 + 1, ys: middleY) },
                ]
                // Không đo được nền trong ô hay cả một cạnh: ô không có số đo (`sides` rỗng), test hỏng thay vì đạt suông.
                guard let fill = mean(xs: minX + inside ..< maxX - inside, ys: minY + inside ..< maxY - inside),
                      sides.allSatisfy({ !$0.isEmpty })
                else {
                    borders.append(FieldBorder(frame: frame, sides: []))
                    continue
                }
                borders.append(FieldBorder(frame: frame, sides: sides.map { lines in
                    lines.map { (max($0, fill) + 0.05) / (min($0, fill) + 0.05) }.max() ?? 1
                }))
            }
            return borders
        }

        /// Chụp cửa sổ Import đề (gốc `ImportExamRoot`) ở cỡ nhỏ nhất của nội dung trong cửa sổ (cỡ cửa sổ thật); tên ảnh
        /// mang cỡ đó. Mỗi cửa sổ một lần import riêng: đóng cửa sổ là Huỷ (`onDisappear`).
        private func assertImportConfirm(testName: String = #function, line: UInt = #line) async {
            guard let measured = try? await ContentSizedWindowTests.confirmingModel(),
                  let shown = try? await ContentSizedWindowTests.confirmingModel()
            else {
                Issue.record("Không dựng được hộp xác nhận (\(testName))")
                return
            }
            let size = await SnapshotHost.minimumContentSize(of: ImportExamRoot(model: measured))
            // Đủ bốn ô, bốn dòng báo lỗi và ghi chú (cửa sổ bị co của lỗi cao ~170 pt).
            #expect(size.height > 400, "cửa sổ Import đề chỉ cao \(size.height) pt (\(testName))")
            await SnapshotHost.assertLightAndDark(
                { ImportExamRoot(model: shown) }, appearances: [.light], size: size, testName: testName, line: line
            )
        }

        /// Đề của phiên làm bài (câu dài 10 lựa chọn, câu có ảnh, ba phần), đặt tên mới để phân biệt.
        static func package() -> ExamPackage {
            var package = SnapshotContent.attemptPackage()
            package.exam.title = "Nghiệp vụ ngoại thương — Bản nháp"
            return package
        }
    }
}
