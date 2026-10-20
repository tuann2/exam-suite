import AppKit
import ExamFile
import ExamKit
import Foundation
import Observation
import ReportFeature
import SessionFeature

/// Một lần **Xuất PDF…** / **In…** đề trên cửa sổ soạn đề (docs/product/export-print.md, mục Bản Admin: PDF và In đề):
///
/// 1. **Hộp chọn** (sheet): **Kiểu** Có đáp án và giải thích / Chỉ đề (không đáp án); mỗi lần mở luôn chọn sẵn **Chỉ đề**,
///    không nhớ lần trước (Nt0 chốt 2026-10-17, phương án 18), để không gửi nhầm bản có đáp án. Đề còn lỗi kiểm đề: dòng
///    "Đề còn N lỗi; PDF in đúng như đang soạn" (phương án 8). Đề `hideAnswers` chọn Có đáp án: dòng nhắc chỉ gửi bản có đáp án
///    cho người được phép xem (phương án 12; không chặn). Nút **Xuất PDF…** / **In…** (Return) và **Huỷ** (Esc).
/// 2. Xuất PDF: **hộp lưu** với tên gợi ý (`ExamReport.suggestedFileName`), dựng vào file tạm cạnh file đích rồi thay
///    (`ReportFileWriter`). In: dựng PDF rồi **hộp In** (co vừa khổ giấy), tên việc in là tên file gợi ý bỏ `.pdf`.
/// 3. Trong lúc dựng: sheet tiến độ "Đang dựng trang N…" có **Huỷ**, chỉ hiện khi dựng lâu hơn `progressDelay` (0,3 s,
///    phương án 14). Huỷ thì không để lại file nào, file đích có sẵn giữ nguyên.
/// 4. Lỗi: hộp báo lỗi kèm lý do. Xuất xong: không mở file (phương án 11), VoiceOver đọc "Đã xuất PDF".
///
/// Nội dung là **ảnh chụp đề lúc mở hộp chọn** (`package`): nội dung đang có trong cửa sổ, kể cả thay đổi chưa lưu; hộp
/// chọn là sheet nên trong lúc nó mở không sửa được đề. Máy trạng thái (hộp lưu, dựng trang, tiến độ, huỷ, hộp In, hộp
/// báo lỗi) dùng chung với PDF kết quả: `ReportFlowRunner` và `ReportServices` của ReportFeature (`ReportPanels` trên cửa
/// sổ soạn đề, bản giả trong test).
@Observable
@MainActor
public final class ExamReportFlow: Identifiable {
    public typealias Step = ReportFlowStep
    /// Nội dung sheet SwiftUI trên cửa sổ soạn đề.
    public typealias SheetContent = ReportFlowSheet

    public let id = UUID()
    /// Kiểu đang chọn trên hộp chọn; mỗi lần mở là `ExamReportKind.default` (Chỉ đề), không nhớ lần trước.
    public var kind: ExamReportKind = .default

    /// Đề và ảnh lúc mở hộp chọn (kể cả thay đổi chưa lưu).
    public let package: ExamPackage
    /// Số lỗi (mức `error`) của `ExamValidator` trên `package`, như thanh lỗi.
    public let errorCount: Int

    /// Máy trạng thái dùng chung với PDF kết quả (ReportFeature): hộp lưu, dựng trang, tiến độ, huỷ, hộp In, hộp báo lỗi.
    @ObservationIgnored private let runner: ReportFlowRunner

    init(
        action: ReportAction,
        package: ExamPackage,
        errorCount: Int,
        services: ReportServices
    ) {
        self.package = package
        self.errorCount = errorCount
        runner = ReportFlowRunner(action: action, services: services, messages: ReportFlowMessages(
            exported: localized("Đã xuất PDF"),
            exportFailed: localized("Không xuất được PDF"),
            printFailed: localized("Không in được")
        ))
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

    /// "Xuất PDF đề" / "In đề".
    public var title: String {
        switch action {
        case .exportPDF: localized("Xuất PDF đề")
        case .print: localized("In đề")
        }
    }

    /// Nút mặc định: "Xuất PDF…" / "In…".
    public var confirmTitle: String {
        switch action {
        case .exportPDF: localized("Xuất PDF…")
        case .print: localized("In…")
        }
    }

    /// "Đề còn N lỗi; PDF in đúng như đang soạn" khi đề còn lỗi kiểm đề (phương án 8); nil khi không có lỗi.
    public var errorNotice: String? {
        errorCount > 0 ? localized("Đề còn \(errorCount) lỗi; PDF in đúng như đang soạn") : nil
    }

    /// Đề `hideAnswers` và đang chọn Có đáp án: dòng nhắc (phương án 12; không chặn, admin có file đề, ADR 0005).
    public var hideAnswersNotice: String? {
        package.exam.hideAnswers && kind == .withAnswers
            ? localized("Đề này ẩn đáp án với học viên. Chỉ gửi bản có đáp án cho người được phép xem")
            : nil
    }

    /// Bấm Xuất/In được: hộp chọn đang mở, chưa bấm (Return xác nhận ngay với kiểu đang chọn).
    public var canConfirm: Bool { runner.canStart }

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

    /// Cửa sổ soạn đề đóng hoặc app thoát: huỷ mọi bước (không để lại file).
    func cancelAll() {
        runner.cancelAll()
    }

    /// Sheet bị đóng không qua nút (thoát app: SwiftUI đóng sheet trước khi hỏi app delegate): hộp chọn thì như Huỷ, sheet
    /// tiến độ đang hiện thì huỷ lần dựng (không để lại file).
    func sheetDismissed() {
        runner.sheetDismissed()
    }

    /// Chờ luồng đang chạy (sau `confirm()`) dừng. Cho test.
    func waitUntilIdle() async {
        await runner.waitUntilIdle()
    }

    // MARK: - Chạy

    private func perform() async {
        let report = ExamReport(package: package, kind: kind, appVersion: runner.services.appVersion)
        switch action {
        case .exportPDF:
            await runner.export(suggestedName: report.suggestedFileName) { try await Self.document(of: report) }
        case .print:
            await runner.print(jobTitle: report.jobTitle) { try await Self.document(of: report) }
        }
    }

    /// Dựng khối của đề ngoài main actor (đề 2.000 câu: dựng chữ của từng câu), rồi kiểm huỷ.
    private static func document(of report: ExamReport) async throws -> ReportDocument {
        let document = await Task.detached(priority: .userInitiated) { report.document() }.value
        try Task.checkCancellation()
        return document
    }
}

/// Xuất PDF/In đề của **một** cửa sổ soạn đề: mỗi lúc một lần (`flow`), bật/tắt hai mục của menu Tệp
/// (`ReportCommandTarget`), hộp của macOS trên đúng cửa sổ đó.
@Observable
@MainActor
public final class ExamReportController {
    /// Lần Xuất/In đang chạy (hộp chọn, hộp lưu, tiến độ, hộp In, hộp báo lỗi).
    public private(set) var flow: ExamReportFlow?

    /// Cửa sổ soạn đề (cửa sổ gán khi hiện): hộp của macOS là sheet trên cửa sổ này.
    @ObservationIgnored weak var window: NSWindow?
    /// Hộp của macOS; test thay bằng bản giả.
    @ObservationIgnored var makeServices: @MainActor (ExamReportController) -> ReportServices = { controller in
        ReportServices.live(window: { [weak controller] in controller?.window })
    }

    public init() {}

    /// Mở hộp chọn được: không có lần Xuất/In nào đang chạy, bộ soạn đề không có hộp thoại (thông báo lỗi, hỏi xoá phần),
    /// cửa sổ không có sheet nào khác (ảnh phóng to của xem trước, hộp chọn ảnh, hộp Lưu của Thử đề này).
    func canRequest(editor: AuthoringEditor) -> Bool {
        flow == nil && editor.alert == nil && editor.sectionPendingRemoval == nil && window?.attachedSheet == nil
    }

    /// Hai mục **Xuất PDF…** / **In…** của menu Tệp cho cửa sổ này (nhóm in chung của cả app, `SessionCommands`).
    func commandTarget(for editor: AuthoringEditor) -> ReportCommandTarget {
        // `attachedSheet` không quan sát được: kiểm lại lúc bấm (`request`).
        ReportCommandTarget(
            id: ObjectIdentifier(self),
            isEnabled: flow == nil && editor.alert == nil && editor.sectionPendingRemoval == nil
        ) { [weak self, weak editor] action in
            guard let self, let editor else { return }
            self.request(action, editor: editor)
        }
    }

    /// Mở hộp chọn của **Xuất PDF…** / **In…** với ảnh chụp đề đang soạn (kể cả thay đổi chưa lưu). Trả `false` khi
    /// không được (`canRequest`).
    @discardableResult
    func request(_ action: ReportAction, editor: AuthoringEditor) -> Bool {
        guard canRequest(editor: editor) else { return false }
        let package = editor.draft.package
        // Kết quả kiểm đề của đúng nội dung này: thanh lỗi nếu đã kiểm xong, không thì kiểm ngay (≈ 15 ms với đề 2.000 câu).
        let errorCount = editor.issuesAreCurrent
            ? editor.issues.errorCount
            : package.validationIssues.count { $0.severity == .error }
        let flow = ExamReportFlow(
            action: action,
            package: package,
            errorCount: errorCount,
            services: makeServices(self)
        )
        flow.onFinish = { [weak self, weak flow] in
            guard let self, let flow, self.flow === flow else { return }
            self.flow = nil
        }
        self.flow = flow
        return true
    }

    /// Cửa sổ đóng: huỷ lần đang chạy (không để lại file).
    func cancelAll() {
        flow?.cancelAll()
    }
}
