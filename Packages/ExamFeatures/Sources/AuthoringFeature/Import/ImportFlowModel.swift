import AuthoringData
import ExamFile
import ExamImport
import ExamKit
import Foundation
import Observation
import OSLog

/// Chạy bộ chuyển đổi trên một file (app: `ExamImporter.importFile`; test: bộ giả). Huỷ task gọi thì ném
/// `CancellationError`.
public typealias ExamImportRunner = @Sendable (
    _ url: URL,
    _ progress: @escaping @Sendable (ImportProgress) -> Void
) async throws -> ImportResult

/// Lý do không import được: hiện bằng hộp thông báo, không mở cửa sổ soạn đề nào (import.md, Luồng).
public struct ImportFailure: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public let title: String
    public let message: String

    public init(title: String, message: String) {
        self.title = title
        self.message = message
    }
}

/// Kết quả import đã xác nhận: nội dung cho cửa sổ soạn đề chưa lưu và báo cáo đi kèm.
public struct ImportedExam: Sendable {
    public let draft: ExamDraft
    public let report: ImportReportState
    /// Câu VoiceOver đọc khi import xong (accessibility-localization.md, Mục tiêu phủ theo màn: Import đề "Import xong /
    /// lỗi"; lỗi là hộp báo của AppKit, VoiceOver tự đọc): "Đã import “x.txt”: 1 phần · 2 câu · 1 câu bị bỏ · 2 cảnh báo".
    public var announcement = ""
}

/// Luồng **Import đề…** của bản Admin (docs/product/import.md, Luồng 1–5), không giao diện:
///
/// 1. `start(_:)` với file người dùng chọn (`.txt`, `.docx`, `.vce`; `.vce` theo ADR 0009). Đuôi khác: báo lỗi.
/// 2. Đọc và chuyển đổi ở nền (`phase == .reading`, `progress` 0…1); `cancel()` huỷ, không báo lỗi.
/// 3. Hộp thoại xác nhận (`phase == .confirming`, `form`): điền sẵn từ file, kiểm giá trị; `confirm()` trả nội dung
///    để mở cửa sổ soạn đề **chưa lưu** (không ghi file nào), `cancel()` bỏ kết quả.
///
/// Lỗi (file không đọc được, không có câu nào…) → `failure` + `onFailure`, `phase` về `.idle`, không có nội dung.
/// Mỗi lúc một lần import; cửa sổ tiến độ/xác nhận (`ImportExamWindow`) hiện theo `phase`.
@MainActor
@Observable
public final class ImportFlowModel {
    public enum Phase: Hashable, Sendable {
        case idle
        case reading
        case confirming
    }

    /// Kết quả `start(_:)`.
    public enum StartOutcome: Equatable, Sendable {
        /// Đang đọc: shell mở cửa sổ tiến độ.
        case started
        /// Đang có một lần import khác (đọc hoặc chờ xác nhận): shell đưa cửa sổ đó lên trước.
        case busy
        /// Không import (đuôi không hỗ trợ): lý do ở `failure`.
        case rejected
    }

    /// Đuôi file hộp chọn file cho chọn (import.md, phương án 1).
    public static var selectableExtensions: [String] { ExamImporter.supportedExtensions }

    public private(set) var phase: Phase = .idle
    /// Tên file đang import (có đuôi).
    public private(set) var fileName = ""
    /// Tiến độ đọc, 0…1.
    public private(set) var progress = 0.0
    /// Hộp thoại xác nhận (có khi `phase == .confirming`).
    public var form: ImportConfirmForm?
    /// Lỗi gần nhất (test và giao diện); `onFailure` được gọi cùng lúc.
    public private(set) var failure: ImportFailure?

    /// Shell hiện lỗi (hộp thông báo của AppKit). Gọi sau khi `phase` đã về `.idle`.
    @ObservationIgnored public var onFailure: (@MainActor (ImportFailure) -> Void)?

    @ObservationIgnored private let runner: ExamImportRunner
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var result: ImportResult?
    /// Tăng mỗi lần bắt đầu hoặc huỷ: tiến độ và kết quả của lần cũ bị bỏ qua.
    @ObservationIgnored private var generation = 0

    private static let log = Logger(subsystem: "vn.io.nt0.examsuite.admin", category: "authoring.import")

    public init(runner: @escaping ExamImportRunner = ImportFlowModel.liveRunner) {
        self.runner = runner
    }

    /// `ExamImporter.importFile` với giới hạn mặc định; tên phần chung theo ngôn ngữ giao diện lúc import.
    public static let liveRunner: ExamImportRunner = runner(locale: nil)

    /// Như `liveRunner`, tên phần chung tra theo `locale` cố định khi có (test).
    static func runner(locale: Locale?) -> ExamImportRunner {
        { url, progress in
            try await ExamImporter.importFile(
                at: url, sharedSectionTitle: ImportContentNames.sharedSectionTitle(locale: locale), progress: progress
            )
        }
    }

    // MARK: - Bắt đầu

    /// Bắt đầu import file `url`. Không đọc file trên main actor.
    @discardableResult
    public func start(_ url: URL) -> StartOutcome {
        guard phase == .idle else { return .busy }
        let ext = url.pathExtension.lowercased()
        guard ExamImporter.supportedExtensions.contains(ext) else {
            fail(Self.failure(for: ImportError.unsupportedFileType(url.pathExtension), fileName: url.lastPathComponent))
            return .rejected
        }

        generation += 1
        let current = generation
        failure = nil
        form = nil
        result = nil
        fileName = url.lastPathComponent
        progress = 0
        phase = .reading
        Self.log.info("Import started: \(ext, privacy: .public)")
        let runner = runner
        let progressHandler: @Sendable (ImportProgress) -> Void = { [weak self] update in
            guard let model = self else { return }
            Task { @MainActor in model.report(update, generation: current) }
        }
        task = Task { [weak self] in
            do {
                let result = try await runner(url, progressHandler)
                self?.finish(.success(result), generation: current)
            } catch {
                self?.finish(.failure(error), generation: current)
            }
        }
        return .started
    }

    private func report(_ update: ImportProgress, generation: Int) {
        guard generation == self.generation, phase == .reading else { return }
        progress = max(progress, min(max(update.fractionCompleted, 0), 1))
    }

    private func finish(_ outcome: Result<ImportResult, any Error>, generation: Int) {
        // Đã huỷ (hoặc đã bắt đầu lần khác): bỏ kết quả, không báo gì.
        guard generation == self.generation, phase == .reading else { return }
        switch outcome {
        case let .success(result):
            Self.log.info("""
                Import converted: \(result.questionCount) questions, \(result.report.droppedCount) dropped, \
                \(result.report.warningCount) warnings
                """)
            self.result = result
            progress = 1
            form = ImportConfirmForm(suggestions: result.suggestions, summary: ImportSummary(result))
            phase = .confirming
        case let .failure(error):
            if error is CancellationError {
                reset()
                return
            }
            Self.log.error("Import failed: \(String(describing: error), privacy: .public)")
            fail(Self.failure(for: error, fileName: fileName))
        }
    }

    // MARK: - Huỷ, xác nhận

    /// **Huỷ** trên cửa sổ tiến độ (dừng bộ chuyển đổi) hoặc trên hộp thoại xác nhận (bỏ kết quả). Không mở gì,
    /// không báo lỗi.
    public func cancel() {
        guard phase != .idle else { return }
        task?.cancel()
        Self.log.info("Import cancelled at \(String(describing: self.phase), privacy: .public)")
        reset()
    }

    /// Chữ của ô `field` trong hộp xác nhận; rỗng khi không còn hộp xác nhận. View đọc/ghi ô qua đây (không qua
    /// `Binding($model.form)!`): sau **Import** hay **Huỷ**, `form` về `nil` trong khi các ô có thể còn được dựng lại
    /// một lượt; binding ép mở (`Binding<Form>` từ `Binding<Form?>`) đọc lúc đó làm app dừng (UI test PR #42).
    public func text(of field: ImportConfirmForm.Field) -> String {
        form?[field] ?? ""
    }

    /// Ghi chữ vào ô `field`; không còn hộp xác nhận (sau Import, Huỷ) thì không làm gì.
    public func setText(_ text: String, of field: ImportConfirmForm.Field) {
        guard form != nil else { return }
        form?[field] = text
    }

    /// **Import** trên hộp thoại xác nhận: dựng đề với giá trị đã nhập và trả nội dung cho cửa sổ soạn đề chưa lưu;
    /// `nil` (và không đổi gì) nếu còn ô chưa hợp lệ.
    public func confirm() -> ImportedExam? {
        guard phase == .confirming, let result, let confirmation = form?.confirmation else { return nil }
        var imported = ImportedExam(
            draft: ExamDraft(package: result.makePackage(confirmation)),
            report: ImportReportState(fileName: fileName, report: result.report)
        )
        if let summary = form?.summary.text {
            imported.announcement = localized("Đã import “\(fileName)”: \(summary)")
        }
        reset()
        return imported
    }

    /// Chờ lần đọc đang chạy xong (test).
    func waitUntilSettled() async {
        await task?.value
    }

    /// Về `.idle`. Task đã huỷ vẫn được giữ tới khi nó kết thúc (`waitUntilSettled`); kết quả của nó bị bỏ qua.
    private func reset() {
        generation += 1
        result = nil
        form = nil
        progress = 0
        phase = .idle
    }

    private func fail(_ failure: ImportFailure) {
        reset()
        self.failure = failure
        onFailure?(failure)
    }

    /// Lỗi của bộ chuyển đổi → hộp thông báo: câu của catalog theo mã của `ImportError`, lỗi khác dùng câu của hệ thống.
    static func failure(for error: any Error, fileName: String) -> ImportFailure {
        ImportFailure(title: localized("Không import được “\(fileName)”"), message: AuthoringMessages.message(for: error))
    }
}
