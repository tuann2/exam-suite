import Foundation
import Observation
import ReportFeature
import SessionModel

/// Một lần **Xuất PDF…** / **In…** kết quả trên cửa sổ làm bài (docs/product/export-print.md, mục Bản Học viên):
///
/// 1. **Hộp chọn** (sheet): **Phần xem lại bài** Không / Câu sai và chưa làm / Tất cả câu, mặc định lựa chọn lần trước
///    (chung mọi đề). Xem lại bài không mở được thì lựa chọn tắt kèm đúng lý do của nút Xem lại bài và chỉ xuất phần kết
///    quả. Nút **Xuất PDF…** / **In…** (Return) và **Huỷ** (Esc).
/// 2. Cần phần xem lại mà chưa có Xem lại đã mở: đọc file đề như nút Xem lại bài. Đọc không được thì đóng hộp chọn, báo
///    lỗi "Không đọc được file đề để làm phần xem lại" kèm lý do, không xuất/in gì (Nt0 chốt 2026-10-17, export-print.md
///    phương án 16); muốn chỉ xuất phần kết quả thì mở lại và chọn **Không**.
/// 3. Xuất PDF: **hộp lưu** với tên gợi ý (`ResultsReport.suggestedFileName`), rồi dựng vào file tạm cạnh file đích và
///    thay (`ReportFileWriter`). In: dựng PDF rồi **hộp In** (co vừa khổ giấy).
/// 4. Trong lúc dựng: sheet tiến độ "Đang dựng trang N…" có **Huỷ** (chỉ hiện khi dựng lâu hơn `progressDelay`). Huỷ
///    thì không để lại file nào, file đích có sẵn giữ nguyên.
/// 5. Lỗi: hộp báo lỗi kèm lý do. Xuất xong: không mở file (phương án 11), VoiceOver đọc "Đã xuất PDF".
///
/// Nội dung PDF là ảnh chụp đúng Kết quả/Xem lại (`ResultsReport(results:review:level:…)`): đề `hideAnswers` không có
/// đáp án đúng và giải thích, câu đã sửa sau lần thi không đánh dấu lựa chọn.
@Observable
@MainActor
public final class ResultsReportFlow: Identifiable {
    public typealias Step = ReportFlowStep
    /// Nội dung sheet SwiftUI trên cửa sổ.
    public typealias SheetContent = ReportFlowSheet

    public let id = UUID()
    /// Lựa chọn trên hộp chọn; chỉ có tác dụng khi chọn được (`isLevelSelectable`).
    public var level: ResultsReviewLevel

    @ObservationIgnored public let results: ResultsModel
    /// Xem lại bài đã mở trên cửa sổ (nếu có): PDF dùng đúng nội dung đang hiện, không đọc lại file đề.
    @ObservationIgnored private let openedReview: AnswerReviewModel?
    @ObservationIgnored private let preferences: any ReportPreferences
    /// Máy trạng thái dùng chung với PDF đề (ReportFeature): hộp lưu, dựng trang, tiến độ, huỷ, hộp In, hộp báo lỗi.
    @ObservationIgnored private let runner: ReportFlowRunner

    init(
        action: ReportAction,
        results: ResultsModel,
        openedReview: AnswerReviewModel?,
        preferences: any ReportPreferences,
        services: ReportServices
    ) {
        self.results = results
        self.openedReview = openedReview
        self.preferences = preferences
        runner = ReportFlowRunner(action: action, services: services, messages: ReportFlowMessages(
            exported: localized("Đã xuất PDF"),
            exportFailed: localized("Không xuất được PDF"),
            printFailed: localized("Không in được")
        ))
        level = preferences.reportReviewLevel
    }

    public var action: ReportAction { runner.action }
    public var step: Step { runner.step }
    /// Tiến độ dựng trang (nil trước lần báo đầu).
    public var progress: ReportProgress? { runner.progress }
    /// Sheet tiến độ đang hiện (dựng lâu hơn `progressDelay`).
    public var isProgressVisible: Bool { runner.isProgressVisible }

    /// Gọi một lần khi luồng xong.
    var onFinish: (@MainActor () -> Void)? {
        get { runner.onFinish }
        set { runner.onFinish = newValue }
    }

    /// Chỉ cho test: gọi ngay khi dựng trang xong (trước hộp In / thông báo xong), để mô phỏng Huỷ hay đóng cửa sổ đến
    /// đúng lúc dựng vừa xong, sau lần kiểm huỷ cuối của bộ dựng trang.
    var didRender: (@MainActor () -> Void)? {
        get { runner.didRender }
        set { runner.didRender = newValue }
    }

    // MARK: - Hộp chọn

    /// "Xuất PDF kết quả" / "In kết quả".
    public var title: String {
        switch action {
        case .exportPDF: localized("Xuất PDF kết quả")
        case .print: localized("In kết quả")
        }
    }

    /// Nút mặc định: "Xuất PDF…" / "In…".
    public var confirmTitle: String {
        switch action {
        case .exportPDF: localized("Xuất PDF…")
        case .print: localized("In…")
        }
    }

    /// Vì sao không chọn được phần xem lại (cùng lý do với nút Xem lại bài); nil khi chọn được.
    public var levelUnavailableReason: String? {
        openedReview != nil ? nil : results.reviewUnavailableReason
    }

    public var isLevelSelectable: Bool { levelUnavailableReason == nil }

    /// Mức sẽ xuất: lựa chọn của người dùng, hoặc **Không** khi Xem lại không mở được (chỉ phần kết quả).
    public var effectiveLevel: ResultsReviewLevel { isLevelSelectable ? level : .none }

    /// Sheet đang cần hiện; nil khi không có sheet SwiftUI (hộp lưu, hộp In, hộp báo lỗi là sheet của AppKit).
    public var sheetContent: SheetContent? { runner.sheetContent }

    public var presentsSheet: Bool { sheetContent != nil }

    /// **Xuất PDF…** / **In…** trên hộp chọn.
    public func confirm() {
        runner.start { await self.perform() }
    }

    /// **Huỷ** trên hộp chọn (Esc) hoặc trên sheet tiến độ. Hộp lưu, hộp In có nút Huỷ riêng của macOS.
    public func cancel() {
        runner.cancel()
    }

    /// Cửa sổ làm bài đóng, đổi phiên hoặc app thoát: huỷ mọi bước (không để lại file).
    func cancelAll() {
        runner.cancelAll()
    }

    /// Sheet bị đóng không qua nút (thoát app: SwiftUI đóng sheet trước khi hỏi app delegate): hộp chọn thì như Huỷ,
    /// sheet tiến độ đang hiện thì huỷ lần dựng (không để lại file).
    func sheetDismissed() {
        runner.sheetDismissed()
    }

    /// Chờ luồng đang chạy (sau `confirm()`) dừng: xong, huỷ, lỗi, hoặc quay lại hộp chọn. Cho test.
    func waitUntilIdle() async {
        await runner.waitUntilIdle()
    }

    // MARK: - Chạy

    private func perform() async {
        let level = effectiveLevel
        // Nhớ lựa chọn (chung mọi đề) khi người dùng chọn được; lựa chọn tắt thì giữ lựa chọn cũ.
        if isLevelSelectable { preferences.reportReviewLevel = level }
        var review = openedReview
        if level != .none, review == nil {
            runner.beginLoadingReview()
            review = await results.makeAnswerReview()
            if Task.isCancelled { return }
            guard review != nil else {
                // Không xuất/in gì: đóng hộp chọn, báo lỗi kèm lý do (Thư viện đã được yêu cầu làm mới thẻ).
                let reason = results.reviewLoadFailure?.message
                    ?? results.reviewUnavailableReason
                    ?? ResultsModel.detailUnavailableMessage
                await runner.fail(title: localized("Không đọc được file đề để làm phần xem lại"), message: reason)
                return
            }
        }
        let report = ResultsReport(results: results, review: review, level: level, appVersion: runner.services.appVersion)
        let document = report.document()
        let fileName = report.suggestedFileName()
        switch action {
        case .exportPDF:
            await runner.export(suggestedName: fileName) { document }
        case .print:
            // Tên việc in (tên gợi ý của "Lưu thành PDF" trong hộp In): như tên file gợi ý, bỏ đuôi.
            await runner.print(jobTitle: (fileName as NSString).deletingPathExtension) { document }
        }
    }
}
