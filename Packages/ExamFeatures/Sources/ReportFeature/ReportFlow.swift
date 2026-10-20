import Foundation
import Observation

/// **Xuất PDF…** hay **In…** (docs/product/export-print.md): PDF kết quả (hai bản) và PDF đề (Admin).
public enum ReportAction: Hashable, Sendable {
    case exportPDF
    case print
}

/// Phần hệ thống của luồng xuất/in: hộp lưu, hộp In, hộp báo lỗi, thông báo VoiceOver, phiên bản app. App dùng
/// `ReportServices.live(window:)` (SessionFeature: hộp của macOS trên cửa sổ đang xuất, `ReportPanels`); test dùng bản
/// giả. Dùng chung cho PDF kết quả (`ResultsReportFlow`) và PDF đề (`ExamReportFlow`).
@MainActor
public struct ReportServices {
    /// Hộp lưu với tên gợi ý; nil khi người dùng Huỷ.
    public var chooseDestination: @MainActor (_ suggestedName: String) async -> URL?
    /// Hộp In cho PDF đã dựng, chờ tới khi xong; `false` khi không tạo được thao tác In.
    public var print: @MainActor (_ pdf: ReportPDF, _ jobTitle: String) async -> Bool
    /// Hộp báo lỗi (tiêu đề, lý do), chờ người dùng đóng.
    public var presentFailure: @MainActor (_ title: String, _ message: String) async -> Void
    /// Thông báo VoiceOver (accessibility-localization.md: "Xuất xong / lỗi"; lỗi là hộp báo lỗi, VoiceOver tự đọc).
    public var announce: @MainActor (_ text: String) -> Void
    /// Phiên bản app cho Creator của PDF (PDF không ghi thời điểm xuất, export-print.md phương án 17).
    public var appVersion: String
    /// Dựng lâu hơn chừng này thì mới hiện sheet tiến độ (xuất nhanh không làm sheet chớp lên rồi tắt).
    public var progressDelay: Duration
    /// Bộ dựng trang.
    public var renderer: ReportRenderer

    public init(
        chooseDestination: @escaping @MainActor (_ suggestedName: String) async -> URL?,
        print: @escaping @MainActor (_ pdf: ReportPDF, _ jobTitle: String) async -> Bool,
        presentFailure: @escaping @MainActor (_ title: String, _ message: String) async -> Void,
        announce: @escaping @MainActor (_ text: String) -> Void,
        appVersion: String,
        progressDelay: Duration = .milliseconds(300),
        renderer: ReportRenderer = ReportRenderer()
    ) {
        self.chooseDestination = chooseDestination
        self.print = print
        self.presentFailure = presentFailure
        self.announce = announce
        self.appVersion = appVersion
        self.progressDelay = progressDelay
        self.renderer = renderer
    }
}

/// Chữ của các bước chung mà luồng hiện cho người dùng. Mỗi luồng tra trong catalog của target mình (chữ đã có ở đó từ
/// bước 5b/6, không chuyển catalog).
public struct ReportFlowMessages: Sendable {
    /// VoiceOver khi xuất xong ("Đã xuất PDF").
    public var exported: String
    /// Tiêu đề hộp báo lỗi khi ghi PDF lỗi ("Không xuất được PDF").
    public var exportFailed: String
    /// Tiêu đề hộp báo lỗi khi không in được ("Không in được").
    public var printFailed: String

    public init(exported: String, exportFailed: String, printFailed: String) {
        self.exported = exported
        self.exportFailed = exportFailed
        self.printFailed = printFailed
    }
}

/// Bước của một lần Xuất PDF…/In….
public enum ReportFlowStep: Hashable, Sendable {
    /// Hộp chọn đang mở.
    case options
    /// Đang đọc file đề cho phần xem lại (hộp chọn còn đó, nút bận); chỉ PDF kết quả.
    case loadingReview
    /// Hộp lưu đang mở.
    case choosingDestination
    /// Đang dựng trang.
    case rendering
    /// Hộp In đang mở.
    case printing
    /// Hộp báo lỗi đang mở.
    case failed
    /// Đã xong (xuất, in, huỷ hoặc lỗi).
    case finished
}

/// Nội dung sheet SwiftUI trên cửa sổ đang xuất.
public enum ReportFlowSheet: Hashable, Sendable {
    /// Hộp chọn (cả lúc đang đọc file đề).
    case options
    /// Tiến độ dựng trang (khi dựng lâu hơn `progressDelay`).
    case progress
}

/// Máy trạng thái dùng chung của một lần **Xuất PDF…** / **In…** (docs/product/export-print.md), gộp từ
/// `ResultsReportFlow` (SessionFeature) và `ExamReportFlow` (AuthoringFeature) ở bước 9 của giai đoạn 5 (review độc lập
/// #49), không đổi hành vi:
///
/// - Hộp chọn → (Xuất PDF) hộp lưu với tên gợi ý → dựng vào file tạm cạnh file đích rồi thay (`ReportFileWriter`); (In)
///   dựng PDF → hộp In.
/// - Trong lúc dựng: sheet tiến độ có **Huỷ**, chỉ hiện khi dựng lâu hơn `progressDelay`. Huỷ (nút, đóng cửa sổ, thoát
///   app) không để lại file nào, file đích có sẵn giữ nguyên; huỷ đến đúng lúc dựng vừa xong thì không mở hộp In.
/// - Lỗi: hộp báo lỗi kèm lý do. Xuất xong: VoiceOver đọc `messages.exported`.
///
/// Phần riêng (hộp chọn, đọc file đề cho phần xem lại, dựng khối của đề) nằm ở luồng của từng bản, chạy trong `start`.
@Observable
@MainActor
public final class ReportFlowRunner {
    public let action: ReportAction
    public private(set) var step: ReportFlowStep = .options
    /// Tiến độ dựng trang (nil trước lần báo đầu).
    public private(set) var progress: ReportProgress?
    /// Sheet tiến độ đang hiện (dựng lâu hơn `progressDelay`).
    public private(set) var isProgressVisible = false

    @ObservationIgnored public let services: ReportServices
    @ObservationIgnored private let messages: ReportFlowMessages
    /// Gọi một lần khi luồng xong.
    @ObservationIgnored package var onFinish: (@MainActor () -> Void)?
    /// Chỉ cho test: gọi ngay khi dựng trang xong (trước hộp In / thông báo xong), để mô phỏng Huỷ hay đóng cửa sổ đến
    /// đúng lúc dựng vừa xong, sau lần kiểm huỷ cuối của bộ dựng trang.
    @ObservationIgnored package var didRender: (@MainActor () -> Void)?
    @ObservationIgnored private var pipeline: Task<Void, Never>?

    public init(action: ReportAction, services: ReportServices, messages: ReportFlowMessages) {
        self.action = action
        self.services = services
        self.messages = messages
    }

    /// Bấm Xuất/In được: hộp chọn đang mở, chưa bấm.
    public var canStart: Bool { step == .options && pipeline == nil }

    /// Sheet đang cần hiện; nil khi không có sheet SwiftUI (hộp lưu, hộp In, hộp báo lỗi là sheet của AppKit).
    public var sheetContent: ReportFlowSheet? {
        switch step {
        case .options, .loadingReview: .options
        case .rendering: isProgressVisible ? .progress : nil
        case .choosingDestination, .printing, .failed, .finished: nil
        }
    }

    /// **Xuất PDF…** / **In…** trên hộp chọn: chạy `perform` (phần riêng của luồng, gọi `export`/`print`/`fail` của
    /// runner) rồi kết thúc.
    public func start(_ perform: @escaping @MainActor () async -> Void) {
        guard canStart else { return }
        pipeline = Task { await run(perform) }
    }

    /// **Huỷ** trên hộp chọn (Esc) hoặc trên sheet tiến độ. Hộp lưu, hộp In có nút Huỷ riêng của macOS.
    public func cancel() {
        switch step {
        case .options:
            // Return rồi Esc ngay: lần xuất đã xếp hàng (chưa chạy lượt nào) cũng bị huỷ.
            pipeline?.cancel()
            finish()
        case .loadingReview, .rendering:
            pipeline?.cancel()
        case .choosingDestination, .printing, .failed, .finished:
            break
        }
    }

    /// Cửa sổ đóng, đổi phiên hoặc app thoát: huỷ mọi bước (không để lại file).
    package func cancelAll() {
        if let pipeline {
            pipeline.cancel()
        } else {
            finish()
        }
    }

    /// Sheet bị đóng không qua nút (thoát app: SwiftUI đóng sheet trước khi hỏi app delegate): hộp chọn thì như Huỷ,
    /// sheet tiến độ đang hiện thì huỷ lần dựng (không để lại file).
    package func sheetDismissed() {
        switch step {
        case .options:
            pipeline?.cancel()
            finish()
        case .loadingReview:
            pipeline?.cancel()
        case .rendering where isProgressVisible:
            pipeline?.cancel()
        case .rendering, .choosingDestination, .printing, .failed, .finished:
            break
        }
    }

    /// Chờ luồng đang chạy (sau `start`) dừng: xong, huỷ hoặc lỗi. Cho test.
    package func waitUntilIdle() async {
        await pipeline?.value
    }

    // MARK: - Các bước chung (gọi trong `perform`)

    /// Đang đọc file đề cho phần xem lại (hộp chọn còn đó, nút bận).
    public func beginLoadingReview() {
        step = .loadingReview
    }

    /// Xuất PDF: hộp lưu với `suggestedName`, rồi dựng `document()` vào file tạm cạnh file đích và thay.
    public func export(suggestedName: String, document: @escaping @MainActor () async throws -> ReportDocument) async {
        step = .choosingDestination
        guard let destination = await services.chooseDestination(suggestedName), !Task.isCancelled else { return }
        let renderer = services.renderer
        let outcome = await render { progress in
            let document = try await document()
            return try await ReportFileWriter.write(document, to: destination, renderer: renderer, progress: progress)
        }
        switch outcome {
        case .success:
            services.announce(messages.exported)
        case let .failure(error):
            await fail(title: messages.exportFailed, message: ReportWriteError.message(for: error))
        case nil:
            break
        }
    }

    /// In: dựng `document()` thành PDF rồi mở hộp In với tên việc in `jobTitle`.
    public func print(jobTitle: String, document: @escaping @MainActor () async throws -> ReportDocument) async {
        let renderer = services.renderer
        let outcome = await render { progress in
            let document = try await document()
            return try await renderer.render(document, progress: progress)
        }
        switch outcome {
        case let .success(pdf):
            // Huỷ hay đóng cửa sổ đến sau lần kiểm huỷ cuối của bộ dựng trang (dựng vừa xong): không mở hộp In (cửa sổ có
            // thể đã đóng, hộp In sẽ thành hộp riêng của cả app), như mọi lần huỷ khác.
            guard !Task.isCancelled else { return }
            step = .printing
            if await services.print(pdf, jobTitle) { return }
            await fail(title: messages.printFailed, message: ReportStrings.printUnavailable)
        case .failure:
            await fail(title: messages.printFailed, message: ReportStrings.printUnavailable)
        case nil:
            break
        }
    }

    /// Hộp báo lỗi (tiêu đề, lý do), chờ người dùng đóng.
    public func fail(title: String, message: String) async {
        step = .failed
        await services.presentFailure(title, message)
    }

    // MARK: - Chạy

    private func run(_ perform: @MainActor () async -> Void) async {
        // Huỷ (Esc, đóng sheet) ngay sau Return, trước khi lần xuất kịp chạy: không làm gì.
        if !Task.isCancelled { await perform() }
        pipeline = nil
        finish()
    }

    /// Dựng trang với tiến độ; sheet tiến độ hiện khi dựng lâu hơn `progressDelay`. nil khi bị huỷ.
    private func render<Output>(
        _ work: @MainActor (_ progress: @MainActor (ReportProgress) -> Void) async throws -> Output
    ) async -> Result<Output, any Error>? {
        step = .rendering
        progress = nil
        isProgressVisible = false
        let delay = services.progressDelay
        let reveal = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self, self.step == .rendering else { return }
            self.isProgressVisible = true
        }
        defer {
            reveal.cancel()
            isProgressVisible = false
        }
        do {
            let output = try await work { [weak self] in self?.progress = $0 }
            didRender?()
            return .success(output)
        } catch is CancellationError {
            return nil
        } catch {
            return Task.isCancelled ? nil : .failure(error)
        }
    }

    private func finish() {
        guard step != .finished else { return }
        step = .finished
        isProgressVisible = false
        let onFinish = onFinish
        self.onFinish = nil
        onFinish?()
    }
}
