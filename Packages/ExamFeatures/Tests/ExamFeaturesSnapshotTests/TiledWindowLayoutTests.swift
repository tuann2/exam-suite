import AppKit
import AuthoringData
@testable import AuthoringFeature
import ExamFile
import ExamImport
import ExamKit
import LibraryData
@testable import LibraryFeature
@testable import SessionFeature
import SwiftUI
import Testing

/// Cửa sổ xếp lát của macOS 26 (plan giai đoạn 5, Decisions 2026-10-17 "Thư viện trống", bước 8a): khi khôi phục khung có
/// `tilingState`, SwiftUI đo cỡ nhỏ nhất của nội dung từng cột ở độ rộng ~0. Chữ nhiều dòng có `fixedSize` dọc nằm ngoài
/// vùng cuộn mà không có độ rộng tối thiểu thì cao hàng nghìn điểm, đẩy nội dung ra ngoài cửa sổ (Thư viện trống).
///
/// Đo đúng phép đo đó: `NSHostingController.sizeThatFits(in: .zero)` của nội dung một cột, ở trạng thái có chữ dài nhất
/// (dải thông báo, lý do ở thanh nút, báo cáo import, lỗi), rồi đòi chiều cao không vượt cửa sổ tối thiểu (640 pt). Đối
/// chứng âm trên **chính view thật** (dải thông báo của phiên thi, lý do ở thanh nút Kết quả, dải thông báo của Thư viện)
/// với `textMinWidth: nil`: không có độ rộng tối thiểu thì cao hơn 640 pt, tức phép đo bắt được lỗi và độ rộng tối thiểu
/// là thứ sửa nó. Không cần SnapshotTesting; ở trong `SnapshotSuite` (tuần tự) vì dùng chung dữ liệu và `NSApplication`
/// của tiến trình snapshot. UI test cửa sổ xếp lát thật: `LibraryWindowRestoreUITests` (cửa sổ làm bài không dùng khung đã
/// lưu: `SessionWindowRestoreUITests`).
extension SnapshotSuite {
    @MainActor
    @Suite("Cửa sổ xếp lát: cỡ nhỏ nhất của nội dung đo ở độ rộng 0")
    struct TiledWindowLayoutTests {
        /// Chiều cao tối thiểu của cửa sổ làm bài, Thư viện, soạn đề.
        private static let windowHeight = SessionStyle.minWindowSize.height

        /// Chữ dài (dải thông báo, lý do) đủ để lộ lỗi: ở độ rộng ~0 mỗi ký tự một dòng.
        private static let longText = String(
            repeating: "Không đọc được file đề nên không xem lại được, kiểm tra lại file rồi thử lại. ", count: 3
        )

        private func minimumSize(_ view: some View) -> CGSize {
            SnapshotHost.prepareProcess()
            return NSHostingController(rootView: view.interfaceLocale()).sizeThatFits(in: .zero)
        }

        /// Dải thông báo của phiên thi (`SessionBannerView`; ở cửa sổ làm bài nằm trên vùng cuộn câu hỏi: cảnh báo giờ, hết
        /// giờ; cả Kết quả, Xem lại bài): thấp khi có độ rộng tối thiểu, cao hơn cửa sổ khi bỏ nó (đối chứng âm).
        @Test func sessionBannerStaysShort() {
            func banner(textMinWidth: CGFloat?) -> some View {
                SessionBannerView(
                    systemImage: "clock.badge.exclamationmark", tone: LibraryPalette.warning, message: Self.longText,
                    textMinWidth: textMinWidth, onClose: {}
                )
            }
            let bounded = minimumSize(banner(textMinWidth: SessionStyle.wrappingTextMinWidth))
            #expect(bounded.height < 200, "dải thông báo cao \(bounded.height) pt ở độ rộng 0")
            let unbounded = minimumSize(banner(textMinWidth: nil))
            #expect(unbounded.height > Self.windowHeight, "đối chứng âm không tái hiện lỗi: \(unbounded)")
        }

        /// Lý do không xem lại được ở thanh nút Kết quả (`ReviewUnavailableReason`), cùng cách kiểm.
        @Test func reviewUnavailableReasonStaysShort() {
            let bounded = minimumSize(ReviewUnavailableReason(reason: Self.longText))
            #expect(bounded.height < 200, "lý do cao \(bounded.height) pt ở độ rộng 0")
            let unbounded = minimumSize(ReviewUnavailableReason(reason: Self.longText, textMinWidth: nil))
            #expect(unbounded.height > Self.windowHeight, "đối chứng âm không tái hiện lỗi: \(unbounded)")
        }

        /// Dải thông báo của Thư viện (`BannerView`: chào mừng, sự cố kho, lỗi lưu; lỗi gốc #48), cùng cách kiểm.
        @Test func libraryBannerStaysShort() {
            func banner(textMinWidth: CGFloat?) -> some View {
                BannerView(
                    systemImage: "sparkles", tone: LibraryPalette.accentForeground, title: "Chào mừng",
                    message: Self.longText, closeTitle: "Đóng", textMinWidth: textMinWidth, onClose: {}
                )
            }
            let bounded = minimumSize(banner(textMinWidth: LibraryStyle.bannerTextMinWidth))
            #expect(bounded.height < 200, "dải thông báo Thư viện cao \(bounded.height) pt ở độ rộng 0")
            let unbounded = minimumSize(banner(textMinWidth: nil))
            #expect(unbounded.height > Self.windowHeight, "đối chứng âm không tái hiện lỗi: \(unbounded)")
        }

        /// Kết quả của lần thi cũ có file đề lỗi: lý do "Không đọc được file đề…" nằm ở thanh nút, ngoài vùng cuộn.
        @Test func resultsWithReviewUnavailableReasonFitsWindow() async throws {
            let harness = SessionHarness()
            let package = ExamPackage(exam: SnapshotContent.manySectionsExam())
            let attempt = try await harness.start(package, mode: .practice)
            attempt.perform(.openReview)
            let window = harness.window(for: attempt)
            window.requestSubmit()
            if attempt.isConfirmingSubmit { window.confirmSubmit() }
            let stored = try #require(harness.library.storedAttempts.first)
            harness.library.entries[package.exam.id]?.status = .invalid(reason: .stored(Self.longText))
            let results = ResultsModel.history(stored, environment: harness.environment)
            let reason = try #require(results.reviewUnavailableReason)
            #expect(reason.count > 200)
            let history = SessionWindowModel(results: results, environment: harness.environment)
            let size = minimumSize(
                ResultsScreen(window: history, results: results, onRetake: {}, onReturnToLibrary: {}).environment(history)
            )
            #expect(size.height <= Self.windowHeight, "Kết quả cao \(size.height) pt ở độ rộng 0")
        }

        /// Vùng nội dung Thư viện (cột chi tiết) có dải chào mừng, lưới và danh sách (lỗi gốc của PR #48).
        @Test(arguments: [LibraryViewMode.grid, .list])
        func libraryDetailWithWelcomeBannerFitsWindow(viewMode: LibraryViewMode) throws {
            let fixture = try LibraryFixture(viewMode: viewMode)
            let size = minimumSize(
                LibraryDetailView(model: fixture.model, viewMode: viewMode, sortOrder: .name, welcomeBanner: .constant(.visible))
                    .defaultAppStorage(fixture.defaults)
            )
            #expect(size.height <= Self.windowHeight, "Thư viện cao \(size.height) pt ở độ rộng 0")
        }

        /// Các cột của cửa sổ soạn đề (trình soạn ở mọi loại dòng, xem trước, báo cáo import và danh sách lỗi đang mở).
        @Test func authoringColumnsFitWindow() throws {
            var package = AuthoringSnapshotTests.package()
            package.exam.sections[0].questions[1].options[2].text = ""
            let draft = ExamDraft(package: package)
            let entries = (1 ... 8).map { number in
                ImportReportEntry(code: .unrecognizedText, location: ImportLocation(questionNumber: number, line: number * 5),
                                  questionID: nil, detail: .textAfterAnswerLine)
            }
            let document = ExamAuthoringDocument(imported: ImportedExam(
                draft: draft,
                report: ImportReportState(fileName: Self.longText + ".txt", report: ExamImport.ImportReport(entries: entries))
            ))
            let editor = document.editor
            editor.validateNow()
            editor.isIssueListExpanded = true
            let selections: [TreeRow] = [.exam, .section(index: 0), .question(QuestionPath(section: 0, question: 1))]
            for selection in selections {
                editor.selection = selection
                let column = minimumSize(VStack(spacing: 0) {
                    EditorColumn(editor: editor, focus: FocusState<AuthoringFocus?>().projectedValue)
                    if let report = editor.importReport { ImportReportPanel(editor: editor, report: report) }
                    IssueBar(editor: editor)
                })
                #expect(column.height <= Self.windowHeight, "cột giữa (\(selection)) cao \(column.height) pt ở độ rộng 0")
                let preview = minimumSize(PreviewPane(editor: editor))
                #expect(preview.height <= Self.windowHeight, "xem trước (\(selection)) cao \(preview.height) pt")
            }
        }
    }
}
