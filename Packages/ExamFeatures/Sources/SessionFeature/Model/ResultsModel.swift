import ExamFile
import ExamKit
import Foundation
import LibraryData
import LibraryFeature
import Observation

/// Một dòng thông tin trên màn Kết quả.
public struct ResultInfoRow: Identifiable, Hashable, Sendable {
    public enum Kind: String, Hashable, Sendable {
        case candidate, examCode, mode, submittedAt, duration, correctCount
    }

    public var id: Kind { kind }
    public let kind: Kind
    public let label: String
    public let value: String

    /// Câu VoiceOver của dòng: "Thí sinh, Nguyễn Văn An".
    public var accessibilityLabel: String { "\(label), \(value)" }
}

/// **So với lần trước**: lần thi trước đó của cùng đề, cùng chế độ.
public struct ResultComparison: Hashable, Sendable {
    public let previousAttemptID: UUID
    public let previousPercent: Int
    /// Điểm % lần này trừ lần trước.
    public let delta: Int
    /// "+8%" / "−5%" / "bằng".
    public let deltaText: String
    /// "So với lần trước: +8%".
    public let text: String
}

/// Một dòng **Theo phần**.
public struct ResultSectionRow: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let title: String
    public let correct: Int
    public let total: Int
    /// Nil với phần 0/0 (hiện "Không có câu", không có thanh).
    public let percent: Int?
    /// Phần yếu nhất (% thấp nhất trong các phần có câu, bằng nhau lấy phần đứng trước), chỉ khi có từ
    /// hai phần có câu trở lên.
    public let isWeakest: Bool

    public var hasQuestions: Bool { total > 0 }
    /// Tỉ lệ cho thanh tiến độ (0…1); nil với phần 0/0.
    public var fraction: Double? { total > 0 ? Double(correct) / Double(total) : nil }

    /// "4/5 · 80%", hoặc "Không có câu".
    public var detailText: String {
        guard let percent else { return localized("Không có câu") }
        return localized("\(correct)/\(total) · \(SessionFormat.percent(percent))")
    }

    /// Câu VoiceOver của dòng (accessibility-localization.md, Mục tiêu phủ theo màn: tên, đúng/tổng, %, "phần yếu nhất"):
    /// "Mạng, 2/3 · 66%", "Bảo mật, 1/2 · 50%, Phần yếu nhất", "Rỗng, Không có câu".
    public var accessibilityLabel: String {
        var parts = [title, detailText]
        if isWeakest { parts.append(localized("Phần yếu nhất")) }
        return parts.joined(separator: ", ")
    }
}

/// Lần thi được mở từ đâu.
public enum ResultsOrigin: Hashable, Sendable {
    /// Vừa nộp trong cửa sổ làm bài.
    case justSubmitted
    /// Mở từ Lịch sử thi.
    case history
}

/// Màn **Kết quả** (docs/product/exam-taking.md, mục Kết quả và Lịch sử thi).
///
/// Điểm, đúng/tổng lấy từ tóm tắt `Attempt`; theo phần, ngưỡng đậu và thời gian cho phép lấy từ bản ghi
/// chi tiết (`AttemptRecord`). Mở từ Lịch sử thi: payload hỏng, mới hơn app hoặc lệch với tóm tắt thì chỉ
/// có tóm tắt, chi tiết và Xem lại tắt với lý do "Không đọc được chi tiết lần thi này".
@Observable
@MainActor
public final class ResultsModel {
    /// Tính mỗi lần đọc (không `static let`): theo ngôn ngữ đang tra.
    public static var detailUnavailableMessage: String { localized("Không đọc được chi tiết lần thi này") }

    public let origin: ResultsOrigin
    public let attempt: Attempt
    /// Bản ghi chi tiết; nil khi không đọc được (hoặc lệch với tóm tắt).
    public let record: AttemptRecord?
    public let examCode: String?
    /// Lỗi lưu lần thi vừa nộp vào Lịch sử thi.
    public let saveError: String?
    /// Lần thi trước của cùng đề, cùng chế độ (không tính chính lần này).
    public let previousAttempt: Attempt?
    /// Lần bấm Xem lại gần nhất thất bại vì đọc file đề lỗi (hiện kèm nút; Thư viện làm mới trạng thái thẻ
    /// nên `reviewUnavailableReason` cập nhật theo).
    public private(set) var reviewFailure: String?
    /// Lý do của lần đọc file đề thất bại gần nhất (`reviewFailure` là câu đầy đủ cho thanh nút Kết quả).
    public private(set) var reviewLoadFailure: ExamLoadFailure?

    /// Đề và ảnh lúc thi (chỉ lần vừa nộp; lần cũ đọc file đề hiện tại khi Xem lại).
    @ObservationIgnored private let content: ExamPackage?
    @ObservationIgnored private let environment: SessionEnvironment

    init(
        origin: ResultsOrigin,
        attempt: Attempt,
        record: AttemptRecord?,
        examCode: String?,
        saveError: String?,
        content: ExamPackage?,
        environment: SessionEnvironment
    ) {
        self.origin = origin
        self.attempt = attempt
        self.record = record
        self.examCode = examCode
        self.saveError = saveError
        self.content = content
        self.environment = environment
        previousAttempt = Self.previous(of: attempt, in: environment.library.attempts(examID: attempt.examID))
    }

    /// Kết quả của bài vừa nộp.
    convenience init(submission: SessionSubmission, content: ExamPackage, environment: SessionEnvironment) {
        self.init(
            origin: .justSubmitted,
            attempt: submission.attempt,
            record: submission.record,
            examCode: content.exam.code,
            saveError: submission.saveError,
            content: content,
            environment: environment
        )
    }

    /// Kết quả của một lần thi trong Lịch sử thi: đọc payload và đối chiếu với tóm tắt.
    public static func history(_ attempt: Attempt, environment: SessionEnvironment) -> ResultsModel {
        ResultsModel(
            origin: .history,
            attempt: attempt,
            record: loadRecord(for: attempt, library: environment.library),
            examCode: environment.library.entry(attempt.examID)?.code,
            saveError: nil,
            content: nil,
            environment: environment
        )
    }

    /// Bản ghi chi tiết của lần thi, hoặc nil nếu payload trống, hỏng, mới hơn app hay lệch với tóm tắt
    /// (examID, chế độ, đúng/tổng, thang 1000, %, đậu/trượt).
    static func loadRecord(for attempt: Attempt, library: any SessionLibrary) -> AttemptRecord? {
        guard let data = try? library.attemptPayload(id: attempt.id), !data.isEmpty,
              let record = try? AttemptRecord.decode(data)
        else { return nil }
        let result = record.result
        guard record.examID == attempt.examID,
              record.mode == attempt.mode,
              result.correct == attempt.correct,
              result.total == attempt.total,
              result.score1000 == attempt.score1000,
              result.percent == attempt.percent,
              result.passed == attempt.passed
        else { return nil }
        return record
    }

    /// Lần trước của cùng đề, cùng chế độ: lần mới nhất nộp trước lần này (theo `Attempt.newestFirst`).
    static func previous(of attempt: Attempt, in attempts: [Attempt]) -> Attempt? {
        attempts
            .filter { $0.id != attempt.id && $0.examID == attempt.examID && $0.mode == attempt.mode }
            .filter { Attempt.newestFirst(attempt, $0) }
            .sorted(by: Attempt.newestFirst)
            .first
    }

    // MARK: - Điểm

    public var passed: Bool { attempt.passed }
    /// "Đậu" / "Trượt" (cùng chữ với Lịch sử thi).
    public var verdictText: String { SessionFormat.result(passed: attempt.passed) }
    public var verdictSymbol: String { SessionFormat.resultSymbol(passed: attempt.passed) }
    public var percent: Int { attempt.percent }
    public var score1000: Int { attempt.score1000 }

    /// "72% · 720/1000". Phần trăm theo ngôn ngữ giao diện; điểm thang 1000 luôn số trơn ("1000/1000", Nt0 chốt
    /// 2026-10-17: `InterfaceLocale.scale1000`).
    public var scoreText: String {
        let percent = SessionFormat.percent(attempt.percent)
        let score = InterfaceLocale.scale1000(attempt.score1000)
        return localized("\(percent) · \(score)/1000")
    }

    /// Tỉ lệ cho thanh điểm (0…1), theo thang 1000.
    public var scoreFraction: Double { Double(attempt.score1000) / 1000 }

    /// Câu VoiceOver của khối điểm, đề mục của màn Kết quả (accessibility-localization.md, Mục tiêu phủ theo màn): Đậu/Trượt,
    /// điểm, ngưỡng đậu (khi có chi tiết), so với lần trước (khi có). Ví dụ "Đậu, 80% · 800/1000, Ngưỡng đậu 70%, So với lần
    /// trước: +5%".
    public var verdictAccessibilityLabel: String {
        var parts = [verdictText, scoreText]
        if let passPercent { parts.append(localized("Ngưỡng đậu \(SessionFormat.percent(passPercent))")) }
        if let comparison { parts.append(comparison.text) }
        return parts.joined(separator: ", ")
    }

    /// Vị trí vạch ngưỡng đậu trên thanh (0…1); nil khi không có chi tiết.
    public var passThresholdFraction: Double? {
        record.map { Double($0.result.passPercent) / 100 }
    }

    public var passPercent: Int? { record?.result.passPercent }

    /// Lý do chi tiết (theo phần, Xem lại) không có; nil nếu có.
    public var detailUnavailableReason: String? {
        record == nil ? Self.detailUnavailableMessage : nil
    }

    // MARK: - Thông tin

    /// Các dòng thông tin của Kết quả. `locale`/`timeZone` (để test cố định được) chỉ áp cho **Nộp lúc**; số trong các
    /// dòng khác (thời gian làm, số câu đúng) luôn theo `InterfaceLocale.current`, cùng ngôn ngữ với chữ của catalog.
    public func infoRows(
        locale: Locale = InterfaceLocale.current,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> [ResultInfoRow] {
        var rows = [ResultInfoRow(kind: .candidate, label: localized("Thí sinh"), value: attempt.candidateName)]
        if let examCode, !examCode.isEmpty {
            rows.append(ResultInfoRow(kind: .examCode, label: localized("Mã đề"), value: examCode))
        }
        rows.append(ResultInfoRow(kind: .mode, label: localized("Chế độ"), value: SessionFormat.mode(attempt.mode)))
        rows.append(ResultInfoRow(
            kind: .submittedAt,
            label: localized("Nộp lúc"),
            value: SessionFormat.dateTime(attempt.submittedAt, locale: locale, timeZone: timeZone)
        ))
        var duration = SessionFormat.duration(seconds: attempt.elapsedSeconds)
        if attempt.mode == .exam, let minutes = record?.timeLimitMinutes {
            duration += " / " + SessionFormat.minutes(minutes)
        }
        rows.append(ResultInfoRow(kind: .duration, label: localized("Thời gian làm"), value: duration))
        rows.append(ResultInfoRow(
            kind: .correctCount,
            label: localized("Số câu đúng"),
            value: "\(SessionFormat.number(attempt.correct))/\(SessionFormat.number(attempt.total))"
        ))
        return rows
    }

    /// **So với lần trước**; nil khi không có lần trước (không hiện dòng này).
    public var comparison: ResultComparison? {
        guard let previousAttempt else { return nil }
        let delta = attempt.percent - previousAttempt.percent
        let deltaText = SessionFormat.percentDelta(delta)
        return ResultComparison(
            previousAttemptID: previousAttempt.id,
            previousPercent: previousAttempt.percent,
            delta: delta,
            deltaText: deltaText,
            text: localized("So với lần trước: \(deltaText)")
        )
    }

    // MARK: - Theo phần

    /// Mỗi phần của đề lúc thi một dòng; trống khi không có chi tiết.
    public var sectionRows: [ResultSectionRow] {
        guard let sections = record?.result.sections else { return [] }
        let weakest = Self.weakestSectionID(sections)
        return sections.map { section in
            ResultSectionRow(
                id: section.sectionID,
                title: section.title,
                correct: section.correct,
                total: section.total,
                percent: section.total > 0 ? Scorer.percent(correct: section.correct, total: section.total) : nil,
                isWeakest: section.sectionID == weakest
            )
        }
    }

    /// Phần yếu nhất: % (chia lấy phần nguyên, như số hiển thị) thấp nhất trong các phần có câu; bằng nhau
    /// lấy phần đứng trước; nil khi có ít hơn hai phần có câu.
    static func weakestSectionID(_ sections: [SectionScore]) -> UUID? {
        let scored = sections.filter { $0.total > 0 }
        guard scored.count >= 2 else { return nil }
        var weakest = scored[0]
        for section in scored.dropFirst()
            where Scorer.percent(correct: section.correct, total: section.total)
            < Scorer.percent(correct: weakest.correct, total: weakest.total) {
            weakest = section
        }
        return weakest.sectionID
    }

    // MARK: - Hành động

    /// Số câu sai (đã trả lời nhưng sai), cho **Xem câu sai**.
    public var incorrectCount: Int {
        record?.result.outcomes.values.filter { $0 == .incorrect }.count ?? 0
    }

    /// Vì sao **Xem lại bài** tắt; nil nếu bật.
    ///
    /// Lần cũ cần file đề hiện tại: cùng id, có trong thư viện, Sẵn sàng (đọc nghiêm được).
    public var reviewUnavailableReason: String? {
        guard record != nil else { return Self.detailUnavailableMessage }
        if origin == .justSubmitted { return content == nil ? Self.detailUnavailableMessage : nil }
        guard let entry = environment.library.entry(attempt.examID) else {
            return localized("Đề không còn trong thư viện nên không xem lại được.")
        }
        switch entry.status {
        case .ready, .checking:
            return nil
        case .missing:
            return localized("Không tìm thấy file đề nên không xem lại được.")
        case .corrupt, .needsNewerApp, .invalid, .readableWithIssues:
            let reason = entry.status.reason.map { ErrorMessages.message(for: $0) } ?? ""
            return localized("Không đọc được file đề nên không xem lại được. \(reason)")
        }
    }

    public var canReview: Bool { reviewUnavailableReason == nil }

    /// **Làm lại**: đúng lựa chọn của lần này; nil (không có nút) khi đề không còn trong thư viện hoặc không
    /// đọc được chi tiết lần thi (không biết lựa chọn của lần đó).
    public var retakePreset: PreExamPreset? {
        guard let record, environment.library.entry(attempt.examID) != nil else { return nil }
        return .retake(mode: record.mode, options: record.options, timeLimitMinutes: record.timeLimitMinutes)
    }

    /// Mở Xem lại bài với bộ lọc `filter`. Lần cũ: đọc nghiêm file đề hiện tại; lỗi thì `reviewFailure` có
    /// lý do, Thư viện được yêu cầu làm mới trạng thái thẻ, trả nil.
    public func makeAnswerReview(filter: AnswerReviewFilter = .all) async -> AnswerReviewModel? {
        guard reviewUnavailableReason == nil, let record else { return nil }
        reviewFailure = nil
        reviewLoadFailure = nil
        if let content {
            return AnswerReviewModel(record: record, exam: content.exam, media: content.media, filter: filter)
        }
        switch await environment.library.readExam(attempt.examID) {
        case let .success(package):
            return AnswerReviewModel(record: record, exam: package.exam, media: package.media, filter: filter)
        case let .failure(failure):
            reviewFailure = localized("Không đọc được file đề nên không xem lại được. \(failure.message)")
            reviewLoadFailure = failure
            environment.library.examFileNeedsRefresh(attempt.examID)
            return nil
        }
    }
}
