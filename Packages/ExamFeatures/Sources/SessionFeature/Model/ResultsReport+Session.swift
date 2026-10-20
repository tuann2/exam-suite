import ExamKit
import Foundation
import LibraryFeature
import ReportFeature

extension ResultsReport {
    /// PDF kết quả của màn **Kết quả** đang mở (docs/product/export-print.md, mục Nội dung và Quy tắc ẩn/hiện).
    ///
    /// Không có quy tắc ẩn/hiện riêng cho giấy: mọi thứ lấy từ `ResultsModel` (đầu trang, điểm, theo phần, chi tiết
    /// không đọc được) và `AnswerReviewModel.detail(at:)` (đề `hideAnswers` không có Đáp án đúng và giải thích; câu đã
    /// sửa sau lần thi không đánh dấu Bạn chọn/Đáp án đúng, giải thích của file hiện tại; câu đã xoá), đúng như Xem lại.
    ///
    /// - Parameters:
    ///   - review: Xem lại bài của lần thi (`ResultsModel.makeAnswerReview()`); nil khi Xem lại không mở được, khi đó
    ///     chỉ có phần kết quả (hộp chọn tắt các mức xem lại kèm lý do).
    ///   - level: **Không** / **Câu sai và chưa làm** (bộ lọc Sai + Chưa làm của Xem lại) / **Tất cả câu**.
    ///   - appVersion: phiên bản app cho Creator của PDF (PDF không ghi thời điểm xuất, export-print.md phương án 17).
    ///   - locale, timeZone: cho **Nộp lúc** (như `ResultsModel.infoRows`); số và phần trăm khác của PDF theo
    ///     `InterfaceLocale.current`.
    @MainActor
    public init(
        results: ResultsModel,
        review: AnswerReviewModel?,
        level: ResultsReviewLevel,
        appVersion: String,
        locale: Locale = InterfaceLocale.current,
        timeZone: TimeZone = .autoupdatingCurrent
    ) {
        let attempt = results.attempt
        let infoRows = results.infoRows(locale: locale, timeZone: timeZone)
        var headerFields = infoRows.filter { $0.kind != .correctCount }.map { ReportField(label: $0.label, value: $0.value) }
        if let passPercent = results.passPercent {
            headerFields.append(ReportField(label: ReportStrings.passThreshold, value: SessionFormat.percent(passPercent)))
        }
        let summaryFields = infoRows.filter { $0.kind == .correctCount }.map { ReportField(label: $0.label, value: $0.value) }
        let comparison = results.comparison.map { comparison in
            ReportBadge(
                title: comparison.text,
                systemImage: comparison.delta > 0 ? "arrow.up.right" : comparison.delta < 0 ? "arrow.down.right" : "equal"
            )
        }
        let sections = results.sectionRows.map { row in
            ReportSectionScores.Row(
                title: row.title,
                detail: row.detailText,
                fraction: row.fraction,
                mark: row.isWeakest ? ReportBadge(title: ReportStrings.weakestSection, systemImage: "exclamationmark.triangle.fill") : nil
            )
        }

        self.init(
            examTitle: attempt.examTitle,
            candidateName: attempt.candidateName,
            submittedAt: attempt.submittedAt,
            headerFields: headerFields,
            verdict: ReportBadge(title: results.verdictText, systemImage: results.verdictSymbol),
            scoreText: results.scoreText,
            scoreFraction: results.scoreFraction,
            passThresholdFraction: results.passThresholdFraction,
            summaryFields: summaryFields,
            comparison: comparison,
            detailUnavailableMessage: results.detailUnavailableReason,
            sections: sections,
            review: Self.review(results: results, review: review, level: level),
            appVersion: appVersion
        )
    }

    /// Phần xem lại: câu theo thứ tự phiên, đúng các bộ lọc của Xem lại; nội dung và dấu lấy nguyên từ
    /// `AnswerReviewModel.detail(at:)`.
    @MainActor
    static func review(results: ResultsModel, review: AnswerReviewModel?, level: ResultsReviewLevel) -> Review? {
        guard level != .none, results.record != nil, let review else { return nil }
        let indices: [Int] = switch level {
        case .none: []
        case .all: review.questionIndices(for: .all)
        case .incorrectAndUnanswered:
            Set(review.questionIndices(for: .incorrect) + review.questionIndices(for: .unanswered)).sorted()
        }
        let questions = indices.map { index -> ReviewQuestion in
            let detail = review.detail(at: index)
            let image: ReportImageSource? = detail.imagePath.map { path in
                review.media[path].map(ReportImageSource.data) ?? .missing
            }
            return ReviewQuestion(
                number: detail.number,
                total: detail.total,
                sectionTitle: detail.sectionTitle,
                status: ReportBadge(title: detail.status.title, systemImage: detail.status.systemImage),
                isFlagged: detail.isFlagged,
                notices: detail.notices,
                text: detail.text,
                image: image,
                options: detail.options.map { option in
                    ReviewQuestion.Option(
                        label: option.label,
                        text: option.text,
                        isSelected: option.isSelected,
                        isCorrectAnswer: option.isCorrectAnswer
                    )
                },
                explanation: detail.explanation
            )
        }
        return Review(level: level, answersHidden: review.answersHidden, questions: questions)
    }
}
