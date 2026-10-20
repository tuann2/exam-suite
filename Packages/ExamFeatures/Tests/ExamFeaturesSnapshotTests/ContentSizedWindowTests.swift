import AppKit
import AuthoringData
@testable import AuthoringFeature
import ExamFile
import ExamImport
import ExamKit
import ReportFeature
@testable import SessionFeature
import SwiftUI
import Testing

/// Cửa sổ và sheet cỡ theo nội dung (lỗi beta G6.2, bản Release build 342 trên macOS 26): cửa sổ **Import đề** dùng
/// `.windowResizability(.contentSize)`, tức lấy cỡ nhỏ nhất và lớn nhất của nội dung làm giới hạn, và mở ở cỡ nhỏ nhất.
/// Hộp xác nhận đặt bốn ô trong `Form` kiểu `.grouped` (vùng cuộn, cỡ nhỏ nhất gần như 0): cửa sổ cao ~170 pt, bốn ô co về
/// cao 0, dòng ghi chú bị cắt còn một dòng, **Import** khoá mà không điền được.
///
/// Đo đúng phép đo của cửa sổ trên **gốc của cửa sổ** (`ImportExamRoot`, ở bước đọc và bước xác nhận): cỡ nhỏ nhất
/// (`NSHostingController.sizeThatFits(in: .zero)`) phải bằng cỡ lý tưởng (`NSHostingView.fittingSize`), ở trạng thái cao
/// nhất (mọi ô báo lỗi, tên file dài) và cả tiếng Anh. Đối chứng âm trên **chính view thật** với `fitsIdealHeight: false`
/// (bố cục trước khi sửa): cỡ nhỏ nhất thấp hơn hẳn, tức phép đo bắt được lỗi. Sheet Xuất PDF/In (hai bản) cũng cỡ theo
/// nội dung: kiểm cùng điều kiện. Sheet có vùng cuộn
/// (Trước khi thi, Thông tin, file không thêm được, ảnh phóng to) đặt cỡ nhỏ nhất riêng (`minHeight`), không thuộc phép đo
/// này. Ảnh chụp hộp xác nhận ở đúng cỡ cửa sổ: `AuthoringSnapshotTests.importConfirmProblems*`; UI test cửa sổ thật:
/// `ImportExamUITests`.
extension SnapshotSuite {
    @MainActor
    @Suite("Cửa sổ và sheet cỡ theo nội dung: cỡ nhỏ nhất bằng cỡ lý tưởng")
    struct ContentSizedWindowTests {
        /// Tên file dài (đầu đề hộp xác nhận và tiến độ xuống hai dòng).
        static let longFileName = "Đề ôn tập chứng chỉ quản trị dự án quốc tế, bộ câu hỏi tổng hợp 2026 (bản cuối).txt"

        /// Hộp xác nhận ở trạng thái cao nhất: tên file dài; mọi ô báo lỗi (tiêu đề trống, mã đề sai mẫu, ngưỡng đậu và
        /// thời gian trống); tóm tắt như file của lỗi beta (1 phần, 1.019 câu, 4 cảnh báo).
        static func confirmingModel() async throws -> ImportFlowModel {
            let model = ImportFlowModel(runner: { _, _ in
                ImportResult(
                    examID: UUID(), sections: [ExamSection(id: UUID(), title: "Phần chung", questions: [])], media: [:],
                    report: ExamImport.ImportReport(), suggestions: ImportSuggestions(title: ""), sourceFormat: .txt
                )
            })
            #expect(model.start(URL(fileURLWithPath: "/tmp").appendingPathComponent(longFileName)) == .started)
            await model.waitUntilSettled()
            #expect(model.phase == .confirming)
            model.form = ImportConfirmForm(
                suggestions: ImportSuggestions(title: "", code: "mã đề sai!"),
                summary: ImportSummary(sectionCount: 1, questionCount: 1019, droppedCount: 0, warningCount: 4)
            )
            let form = try #require(model.form)
            #expect(ImportConfirmForm.Field.allCases.allSatisfy { form.problem($0) != nil }, "mọi ô phải báo lỗi")
            return model
        }

        nonisolated static let languages = [Locale(identifier: "vi"), Locale(identifier: "en")]

        private func minimumSize(_ view: some View) -> CGSize {
            NSHostingController(rootView: view.interfaceLocale()).sizeThatFits(in: .zero)
        }

        private func idealSize(_ view: some View) -> CGSize {
            NSHostingView(rootView: view.interfaceLocale()).fittingSize
        }

        /// Cửa sổ Import đề ở bước xác nhận: cỡ nhỏ nhất bằng cỡ lý tưởng (cửa sổ vừa khít, `Form` không co); đối chứng âm
        /// như trước khi sửa: cỡ nhỏ nhất thấp hơn cỡ lý tưởng cả trăm điểm (bốn ô biến mất).
        @Test(arguments: languages)
        func importConfirmFitsIdealHeight(language: Locale) async throws {
            try await SnapshotHost.inLanguage(language) {
                let model = try await Self.confirmingModel()
                let root = ImportExamRoot(model: model)
                let minimum = minimumSize(root)
                let ideal = idealSize(root)
                #expect(abs(minimum.height - ideal.height) < 0.5, "cỡ nhỏ nhất \(minimum) khác cỡ lý tưởng \(ideal)")
                #expect(minimum.width == 480, "\(minimum)")
                // Đầu đề, tóm tắt, bốn ô và bốn dòng báo lỗi, ghi chú, hai nút: cao hơn hẳn cửa sổ bị co của lỗi (~170 pt).
                #expect(minimum.height > 400, "hộp xác nhận chỉ cao \(minimum.height) pt")

                let unfixed = ImportExamRoot(model: model, fitsIdealHeight: false)
                let collapsed = minimumSize(unfixed)
                #expect(collapsed.height < idealSize(unfixed).height - 150, "đối chứng âm không tái hiện lỗi: \(collapsed)")
                #expect(model.phase == .confirming, "phép đo không được đổi bước của lần import")
            }
        }

        /// Cửa sổ Import đề ở bước đọc (tiến độ, tên file dài hai dòng): cỡ nhỏ nhất bằng cỡ lý tưởng.
        @Test(arguments: languages)
        func importProgressFitsIdealHeight(language: Locale) async throws {
            try await SnapshotHost.inLanguage(language) {
                let model = ImportFlowModel(runner: { _, _ in
                    try await Task.sleep(for: .seconds(600))
                    throw CancellationError()
                })
                #expect(model.start(URL(fileURLWithPath: "/tmp").appendingPathComponent(Self.longFileName)) == .started)
                defer { model.cancel() }
                let root = ImportExamRoot(model: model)
                let minimum = minimumSize(root)
                let ideal = idealSize(root)
                #expect(abs(minimum.height - ideal.height) < 0.5, "cỡ nhỏ nhất \(minimum) khác cỡ lý tưởng \(ideal)")
                #expect(minimum.width == 420, "\(minimum)")
                #expect(model.phase == .reading, "phép đo không được đổi bước của lần import")
            }
        }

        /// Hộp chọn của Xuất PDF…/In… (đề ở bản Admin, kết quả ở hai bản): cỡ nhỏ nhất bằng cỡ lý tưởng.
        @Test(arguments: languages)
        func reportOptionSheetsFitIdealHeight(language: Locale) async throws {
            try await SnapshotHost.inLanguage(language) {
                let document = ExamAuthoringDocument(draft: ExamDraft(package: AuthoringSnapshotTests.package()))
                for action in [ReportAction.exportPDF, .print] {
                    let controller = ExamReportController()
                    #expect(controller.request(action, editor: document.editor))
                    let sheet = ExamReportSheet(controller: controller)
                    let minimum = minimumSize(sheet)
                    let ideal = idealSize(sheet)
                    #expect(abs(minimum.height - ideal.height) < 0.5, "đề \(action): \(minimum) khác \(ideal)")
                    #expect(minimum.height > 100, "đề \(action): \(minimum)")
                }

                let harness = SessionHarness()
                let window = try await harness.submittedWindow(package: ExamPackage(exam: SnapshotContent.manySectionsExam()))
                window.reportServices = ReportServices.live(window: { nil })
                #expect(window.requestReport(.exportPDF))
                let sheet = ResultsReportSheet(window: window)
                let minimum = minimumSize(sheet)
                let ideal = idealSize(sheet)
                #expect(abs(minimum.height - ideal.height) < 0.5, "kết quả: \(minimum) khác \(ideal)")
                #expect(minimum.height > 100, "kết quả: \(minimum)")
                window.cancelReport()
            }
        }
    }
}
