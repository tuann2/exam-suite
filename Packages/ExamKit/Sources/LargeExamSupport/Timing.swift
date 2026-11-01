import Foundation

/// Một dòng của bảng ngân sách (docs/product/large-exams.md, mục Ngân sách): ngân sách cho build Release (chỉ ghi
/// số, không chặn merge) và giới hạn chặn cho `swift test` bản Debug (test thất bại nếu vượt; Nt0 chốt 2026-10-16).
public struct TimingBudget: Sendable, Hashable {
    /// Mã ổn định, dùng làm khoá trong bảng số đo (`scripts/measure_large.sh`).
    public let id: String
    /// Tên thao tác (tiếng Việt), như cột đầu của bảng ngân sách.
    public let label: String
    /// Ngân sách Release.
    public let budget: Duration
    /// Giới hạn chặn trong test; nil khi large-exams.md không đặt giới hạn cho mục này (chỉ ghi số).
    public let limit: Duration?

    public init(id: String, label: String, budget: Duration, limit: Duration?) {
        self.id = id
        self.label = label
        self.budget = budget
        self.limit = limit
    }
}

/// Bảng ngân sách dùng chung cho mọi test `Timing`; số lấy đúng từ large-exams.md. Mục đánh dấu "thành phần" là
/// một phần của thao tác người dùng (đo riêng để biết chỗ tốn), mang ngân sách của thao tác đó.
public extension TimingBudget {
    static let libraryImport = TimingBudget(
        id: "library.import", label: "Thêm một đề chuẩn (đọc nghiêm, nền) tới khi Sẵn sàng",
        budget: .milliseconds(1_500), limit: .seconds(6))
    static let libraryImportMainActor = TimingBudget(
        id: "library.import.mainActor", label: "Thêm một đề chuẩn: main actor chặn dài nhất",
        budget: .milliseconds(50), limit: .milliseconds(200))
    static let examFileRead = TimingBudget(
        id: "examfile.read", label: "Đọc nghiêm gói đề chuẩn (thành phần của Thêm đề, Bắt đầu)",
        budget: .milliseconds(1_500), limit: .seconds(6))
    /// Như `examFileRead`: đọc file `.oef` là thành phần của cùng thao tác Thêm đề, Bắt đầu (docs/product/plan-oef.md).
    static let oefRead = TimingBudget(
        id: "oef.read", label: "Đọc nghiêm đề chuẩn dạng .oef (thành phần của Thêm đề, Bắt đầu)",
        budget: .milliseconds(1_500), limit: .seconds(6))
    static let examFileWrite = TimingBudget(
        id: "examfile.write", label: "Ghi gói đề chuẩn có ảnh (thành phần của Lưu đề)",
        budget: .seconds(3), limit: .seconds(10))
    static let sessionCompose = TimingBudget(
        id: "session.compose", label: "Tạo đề + phiên, lõi ExamKit (thành phần của Bắt đầu)",
        budget: .milliseconds(1_500), limit: .seconds(6))
    static let sessionStart = TimingBudget(
        id: "session.start", label: "Bắt đầu (đọc lại nghiêm + tạo đề + model phiên) tới khi có câu 1",
        budget: .milliseconds(1_500), limit: .seconds(6))
    /// large-exams.md chỉ đặt ngân sách (≤ 100 ms), không đặt giới hạn chặn Debug: chỉ ghi số.
    static let sessionStartMainActor = TimingBudget(
        id: "session.start.mainActor", label: "Bắt đầu: main actor chặn dài nhất",
        budget: .milliseconds(100), limit: nil)
    static let sessionNavigate = TimingBudget(
        id: "session.navigate", label: "Đổi câu (model câu + lựa chọn + bảng câu hỏi 2.000 ô)",
        budget: .milliseconds(16), limit: .milliseconds(50))
    static let sessionSubmit = TimingBudget(
        id: "session.submit", label: "Nộp bài: chấm + lưu lần thi + Kết quả",
        budget: .milliseconds(500), limit: .seconds(2))
    /// large-exams.md chỉ đặt ngân sách main actor chặn (≤ 100 ms), không đặt giới hạn chặn Debug: chỉ ghi số (bước 9 của
    /// plan giai đoạn 5). Nộp chạy đồng bộ trên main actor nên số này ≈ `session.submit`.
    static let sessionSubmitMainActor = TimingBudget(
        id: "session.submit.mainActor", label: "Nộp bài: main actor chặn dài nhất",
        budget: .milliseconds(100), limit: nil)
    static let historyOpen = TimingBudget(
        id: "history.open", label: "Mở Kết quả + Xem lại của lần thi cũ (payload, đọc đề; kho 50 đề, 200 lần thi)",
        budget: .milliseconds(1_500), limit: .seconds(6))
    /// large-exams.md chỉ đặt giới hạn chặn cho main actor (≤ 200 ms), không cho tổng thời gian: tổng chỉ ghi số.
    static let libraryRefresh = TimingBudget(
        id: "library.refresh", label: "Làm mới trạng thái 50 đề (5 đề chuẩn, mọi file đã đổi)",
        budget: .seconds(5), limit: nil)
    static let libraryRefreshMainActor = TimingBudget(
        id: "library.refresh.mainActor", label: "Làm mới 50 đề: main actor chặn dài nhất",
        budget: .milliseconds(50), limit: .milliseconds(200))
    static let reviewFilter = TimingBudget(
        id: "review.filter", label: "Đổi bộ lọc Xem lại",
        budget: .milliseconds(50), limit: .milliseconds(200))
    static let authoringOpen = TimingBudget(
        id: "authoring.open", label: "Soạn đề: mở cửa sổ (dựng cây đề)",
        budget: .milliseconds(100), limit: .milliseconds(300))
    static let authoringTyping = TimingBudget(
        id: "authoring.typing", label: "Soạn đề: mỗi lần gõ vào câu",
        budget: .milliseconds(8), limit: .milliseconds(16))
    static let authoringSearchTyping = TimingBudget(
        id: "authoring.searchTyping", label: "Soạn đề: mỗi lần gõ khi ô tìm có chữ (gõ vào câu, lọc lại cây đề)",
        budget: .milliseconds(8), limit: .milliseconds(16))
    static let authoringSearchQuery = TimingBudget(
        id: "authoring.searchQuery", label: "Soạn đề: gõ vào ô tìm (đổi chữ tìm, chỉ mục đã có)",
        budget: .milliseconds(8), limit: .milliseconds(16))
    /// Lần gõ đầu vào ô tìm: là một lần gõ nên mang ngân sách 8 ms và giới hạn chặn 16 ms của dòng "mỗi lần gõ, kể cả
    /// khi ô tìm có chữ". Trước bước 9 của plan giai đoạn 5 lần gõ này dựng chỉ mục tìm của cả đề trên main actor (~42 ms
    /// Release, vượt); từ bước 9 chỉ mục dựng nền khi mở cửa sổ (large-exams.md).
    static let authoringFirstSearch = TimingBudget(
        id: "authoring.firstSearch", label: "Soạn đề: lần gõ đầu vào ô tìm (chỉ mục dựng nền khi mở cửa sổ)",
        budget: .milliseconds(8), limit: .milliseconds(16))
    static let authoringValidate = TimingBudget(
        id: "authoring.validate", label: "Soạn đề: kiểm đề (nền)",
        budget: .milliseconds(50), limit: .milliseconds(200))
    static let authoringSave = TimingBudget(
        id: "authoring.save", label: "Soạn đề: lưu đề chuẩn có ảnh",
        budget: .seconds(3), limit: .seconds(10))
    static let reportResults = TimingBudget(
        id: "report.results", label: "PDF kết quả không có phần xem lại",
        budget: .seconds(1), limit: .seconds(3))
    static let reportResultsReviewAll = TimingBudget(
        id: "report.results.reviewAll", label: "PDF kết quả có Xem lại tất cả 2.000 câu",
        budget: .seconds(30), limit: .seconds(120))
    /// large-exams.md đặt ngân sách main actor chặn (≤ 100 ms) cho PDF nhưng không đặt giới hạn Debug cho cột này: chỉ
    /// ghi số (ReportFeatureTests có test riêng khẳng định < 100 ms với ảnh lớn và khối dài).
    static let reportResultsReviewAllMainActor = TimingBudget(
        id: "report.results.reviewAll.mainActor", label: "PDF kết quả có Xem lại tất cả: main actor chặn dài nhất",
        budget: .milliseconds(100), limit: nil)
    /// In…: mở PDF kết quả "Xem lại tất cả" bằng PDFKit và tạo thao tác In trên main actor, trước khi hộp In hiện. Mang
    /// ngân sách main actor chặn của PDF (≤ 100 ms); large-exams.md không đặt giới hạn Debug: chỉ ghi số (bước 9).
    static let reportPrintPrepare = TimingBudget(
        id: "report.print.prepare", label: "In PDF kết quả Xem lại tất cả: mở PDF + tạo thao tác In (main actor)",
        budget: .milliseconds(100), limit: nil)
    /// In ra file (không hộp thoại) PDF kết quả "Xem lại tất cả": `NSPrintOperation.run()` chạy đồng bộ trên main actor.
    /// Mang ngân sách thời gian của PDF lớn (≤ 30 s); chỉ ghi số (bước 9; chỉ khi `Timing.recordsExtraMeasurements`).
    static let reportPrintRun = TimingBudget(
        id: "report.print.run", label: "In PDF kết quả Xem lại tất cả ra file (NSPrintOperation.run, main actor)",
        budget: .seconds(30), limit: nil)
    static let reportExamWithAnswers = TimingBudget(
        id: "report.exam.withAnswers", label: "PDF đề chuẩn có đáp án (Admin)",
        budget: .seconds(30), limit: .seconds(120))
    /// PDF đề chuẩn kiểu Chỉ đề (không đáp án): đo một lần để ghi thời gian và cỡ file (bước 9; chỉ khi
    /// `Timing.recordsExtraMeasurements`).
    static let reportExamQuestionsOnly = TimingBudget(
        id: "report.exam.questionsOnly", label: "PDF đề chuẩn chỉ đề (Admin)",
        budget: .seconds(30), limit: .seconds(120))
    /// Như PDF kết quả: large-exams.md đặt ngân sách main actor chặn (≤ 100 ms) nhưng không đặt giới hạn Debug: chỉ ghi số.
    static let reportExamWithAnswersMainActor = TimingBudget(
        id: "report.exam.withAnswers.mainActor", label: "PDF đề chuẩn có đáp án: main actor chặn dài nhất",
        budget: .milliseconds(100), limit: nil)
}

/// Ngân sách cỡ file PDF của đề chuẩn (large-exams.md, mục Cỡ file PDF; Nt0 chốt 2026-10-18: giữ ảnh 2× không mất,
/// đặt ngân sách để bắt cỡ file tăng). Số đo bước 9 (ảnh nhiễu không nén được của đề chuẩn) cộng biên ~20%. Cỡ file
/// không phụ thuộc máy hay cấu hình build nên test so ở mọi lần chạy (Debug và Release). Byte, đơn vị MB = 10⁶ byte.
public enum PDFSizeBudget {
    /// PDF kết quả "Xem lại tất cả" 2.000 câu: đo 108 MB.
    public static let resultsReviewAll = 130_000_000
    /// PDF đề chuẩn có đáp án: đo 105 MB.
    public static let examWithAnswers = 126_000_000
    /// PDF đề chuẩn chỉ đề: đo 100 MB.
    public static let examQuestionsOnly = 121_000_000
}

/// Kết quả đo một thao tác: thời gian từng lần, lần nhanh nhất, trung vị, lần chậm nhất. Test so **lần nhanh nhất**
/// với giới hạn chặn (ít phụ thuộc máy đang bận; Nt0 chốt 2026-10-16, large-exams.md), trung vị là số báo cáo và so
/// với ngân sách Release. Riêng mẫu gồm nhiều biến thể (ví dụ nhiều chữ tìm, mỗi chữ đã lấy lần nhanh nhất) thì so
/// **biến thể chậm nhất** (`gate: .slowest`).
public struct TimingSample: Sendable {
    /// Giá trị so với giới hạn chặn.
    public enum Gate: String, Sendable {
        case fastest = "min"
        case slowest = "max"
    }

    public let budget: TimingBudget
    public let runs: [Duration]
    public let gate: Gate
    /// Sự kiện đơn lẻ chậm nhất khi mỗi lần đo là trung bình một đợt sự kiện (đổi câu, gõ); chỉ báo cáo.
    public let worstEvent: Duration?

    public init(budget: TimingBudget, runs: [Duration], gate: Gate = .fastest, worstEvent: Duration? = nil) {
        precondition(!runs.isEmpty, "cần ít nhất một lần đo")
        self.budget = budget
        self.runs = runs
        self.gate = gate
        self.worstEvent = worstEvent
    }

    public var fastest: Duration { runs.min()! }
    public var slowest: Duration { runs.max()! }

    public var median: Duration {
        let sorted = runs.sorted()
        let middle = sorted.count / 2
        return sorted.count % 2 == 1 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2
    }

    /// Giá trị so với giới hạn chặn theo `gate`.
    public var gated: Duration { gate == .fastest ? fastest : slowest }

    /// Không vượt giới hạn chặn (mục không có giới hạn thì luôn đúng).
    public var isWithinLimit: Bool { budget.limit.map { gated <= $0 } ?? true }

    /// Trung vị không vượt ngân sách Release (chỉ có ý nghĩa khi đo bản Release).
    public var isWithinBudget: Bool { median <= budget.budget }

    /// Dòng máy đọc được, `scripts/measure_large.sh` gom thành bảng:
    /// `Timing: <id> | <tên> | min <ms> | median <ms> | max <ms> | runs <n> | gate <min|max> | worst-event <ms|—> |
    /// budget <ms> | limit <ms|—> | <Debug|Release>`.
    public var line: String {
        [
            "Timing: \(budget.id)",
            budget.label,
            "min \(Self.milliseconds(fastest))",
            "median \(Self.milliseconds(median))",
            "max \(Self.milliseconds(slowest))",
            "runs \(runs.count)",
            "gate \(gate.rawValue)",
            "worst-event \(worstEvent.map(Self.milliseconds) ?? "—")",
            "budget \(Self.milliseconds(budget.budget))",
            "limit \(budget.limit.map(Self.milliseconds) ?? "—")",
            Timing.buildConfiguration,
        ].joined(separator: " | ")
    }

    /// Mili giây, hai chữ số thập phân, dấu chấm thập phân (không theo locale).
    public static func milliseconds(_ duration: Duration) -> String {
        let (seconds, attoseconds) = duration.components
        let value = Double(seconds) * 1_000 + Double(attoseconds) / 1e15
        return String(format: "%.2f ms", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}

/// Đo thời gian trong test (Swift Testing không có `measure`): chạy `runs` lần, in một dòng `Timing:` rồi trả về
/// mẫu để test so với giới hạn chặn.
public enum Timing {
    /// Đo thêm chỉ để ghi số (in thật 1.168 trang bằng `NSPrintOperation`, PDF đề chỉ đề): chỉ khi biến môi trường
    /// `EXAMSUITE_MEASURE_RECORD=1`, do `scripts/measure_large.sh` đặt. `swift test`/check.sh thường không trả thời gian
    /// đó, và `NSPrintOperation` có thể chập chờn khi không có phiên giao diện (review độc lập #55 S3). Test so giới hạn
    /// chặn không phụ thuộc cờ này.
    public static var recordsExtraMeasurements: Bool {
        ProcessInfo.processInfo.environment["EXAMSUITE_MEASURE_RECORD"] == "1"
    }

    /// "Debug" khi build không tối ưu (`-Onone`), "Release" khi tối ưu (`swift test -c release`, measure_large.sh).
    /// Xét mức tối ưu chứ không xét cờ `DEBUG`: measure_large.sh phải bật `-DDEBUG` để test target biên dịch được
    /// (vài test dùng code chỉ có ở Debug, như chế độ cô lập của UI test). `assert` chỉ chạy khi không tối ưu.
    public static let buildConfiguration: String = {
        var optimized = true
        assert({ optimized = false; return true }())
        return optimized ? "Release" : "Debug"
    }()

    /// Đo cả `body` mỗi lần.
    @discardableResult
    public static func measure(
        _ budget: TimingBudget,
        runs: Int = 5,
        _ body: () throws -> Void
    ) rethrows -> TimingSample {
        let clock = ContinuousClock()
        var durations: [Duration] = []
        for _ in 0 ..< runs {
            durations.append(try clock.measure(body))
        }
        return record(TimingSample(budget: budget, runs: durations))
    }

    /// Đo cả `body` mỗi lần (bất đồng bộ; giữ actor của nơi gọi).
    @discardableResult
    public static func measure(
        _ budget: TimingBudget,
        runs: Int = 5,
        isolation: isolated (any Actor)? = #isolation,
        _ body: () async throws -> Void
    ) async rethrows -> TimingSample {
        let clock = ContinuousClock()
        var durations: [Duration] = []
        for _ in 0 ..< runs {
            let start = clock.now
            try await body()
            durations.append(clock.now - start)
        }
        return record(TimingSample(budget: budget, runs: durations))
    }

    /// Đo `batches` đợt, mỗi đợt `events` sự kiện (`body(đợt, sự kiện)`); mỗi lần đo là trung bình một sự kiện của
    /// một đợt, kèm sự kiện đơn lẻ chậm nhất.
    @discardableResult
    public static func measureEvents(
        _ budget: TimingBudget,
        batches: Int = 5,
        events: Int,
        before: (Int) -> Void = { _ in },
        _ body: (Int, Int) -> Void
    ) -> TimingSample {
        let clock = ContinuousClock()
        var averages: [Duration] = []
        var worst: Duration = .zero
        for batch in 0 ..< batches {
            before(batch)
            var total: Duration = .zero
            for event in 0 ..< events {
                let elapsed = clock.measure { body(batch, event) }
                total += elapsed
                worst = max(worst, elapsed)
            }
            averages.append(total / events)
        }
        return record(TimingSample(budget: budget, runs: averages, worstEvent: worst))
    }

    /// In và trả về mẫu đã đo theo cách riêng (ví dụ chỉ đo một đoạn của mỗi lần).
    @discardableResult
    public static func record(_ sample: TimingSample) -> TimingSample {
        print(sample.line)
        return sample
    }
}

/// Đo khoảng main actor bị chặn dài nhất trong lúc một thao tác chạy: một task trên main actor ngủ 5 ms rồi ghi
/// khoảng cách giữa hai lần thức (như `MainActorHeartbeat` của LibraryDataTests). Main actor bị chặn X ms thì có
/// khoảng cách ≥ X ms. `start()` chờ nhịp đầu tiên nên thao tác đo ngay sau đó (kể cả phần chạy đồng bộ trên main
/// actor trước lần `await` đầu) đã nằm trong vùng đo. Đối chứng âm: `MainActorGapProbeTests` (ExamKitTests).
@MainActor
public final class MainActorGapProbe {
    public private(set) var longestGap: Duration = .zero
    public private(set) var beats = 0
    private var task: Task<Void, Never>?

    public init() {}

    public func start() async {
        task = Task { @MainActor in
            let clock = ContinuousClock()
            var last = clock.now
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(5))
                let now = clock.now
                self.longestGap = max(self.longestGap, now - last)
                self.beats += 1
                last = now
            }
        }
        while beats == 0 {
            try? await Task.sleep(for: .milliseconds(1))
        }
    }

    public func stop() async {
        task?.cancel()
        await task?.value
    }
}
