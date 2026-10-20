import Foundation

/// Phần xem lại bài trong PDF kết quả (docs/product/export-print.md phương án 3): mặc định **Câu sai và chưa
/// làm**.
public enum ResultsReviewLevel: String, CaseIterable, Hashable, Sendable, Identifiable {
    case none
    /// Đúng như bộ lọc **Sai** cộng **Chưa làm** của Xem lại (không gồm câu đúng).
    case incorrectAndUnanswered
    case all

    public static let `default`: ResultsReviewLevel = .incorrectAndUnanswered

    public var id: Self { self }

    public var title: String {
        switch self {
        case .none: ReportStrings.reviewLevelNone
        case .incorrectAndUnanswered: ReportStrings.reviewLevelIncorrectAndUnanswered
        case .all: ReportStrings.reviewLevelAll
        }
    }
}

/// Model của PDF kết quả: ảnh chụp đúng những gì màn **Kết quả** và **Xem lại bài** được phép hiện
/// (docs/product/export-print.md, mục Nội dung và Quy tắc ẩn/hiện). Chỉ chứa dữ liệu đã lọc: SessionFeature dựng
/// model này từ `ResultsModel` và `AnswerReviewModel` (`ResultsReport(results:review:level:…)`), dùng lại đúng
/// logic của Xem lại cho `hideAnswers` và câu đã sửa sau lần thi, không chép lại quy tắc ở đây.
public struct ResultsReport: Sendable, Hashable {
    /// Một câu của phần xem lại, theo thứ tự phiên.
    public struct ReviewQuestion: Sendable, Hashable {
        public struct Option: Sendable, Hashable {
            public var label: String
            public var text: String
            /// **Bạn chọn**; luôn `false` với câu đã sửa sau lần thi.
            public var isSelected: Bool
            /// **Đáp án đúng**; `nil` khi đề `hideAnswers` hoặc câu đã sửa sau lần thi.
            public var isCorrectAnswer: Bool?

            public init(label: String, text: String, isSelected: Bool, isCorrectAnswer: Bool?) {
                self.label = label
                self.text = text
                self.isSelected = isSelected
                self.isCorrectAnswer = isCorrectAnswer
            }
        }

        /// Số thứ tự trong phiên (1-based).
        public var number: Int
        public var total: Int
        public var sectionTitle: String
        /// Đúng / Sai / Chưa làm (kết quả lúc thi).
        public var status: ReportBadge
        public var isFlagged: Bool
        /// Đã xoá; đã sửa sau lần thi (kèm "Không hiện lựa chọn của bạn…").
        public var notices: [String]
        /// Nil khi câu đã bị xoá khỏi đề.
        public var text: String?
        /// Câu có ảnh: byte ảnh hoặc `.missing`.
        public var image: ReportImageSource?
        public var options: [Option]
        /// Nil khi đề không có hoặc đề `hideAnswers`.
        public var explanation: String?

        public init(
            number: Int,
            total: Int,
            sectionTitle: String,
            status: ReportBadge,
            isFlagged: Bool,
            notices: [String],
            text: String?,
            image: ReportImageSource?,
            options: [Option],
            explanation: String?
        ) {
            self.number = number
            self.total = total
            self.sectionTitle = sectionTitle
            self.status = status
            self.isFlagged = isFlagged
            self.notices = notices
            self.text = text
            self.image = image
            self.options = options
            self.explanation = explanation
        }
    }

    /// Phần xem lại đã chọn.
    public struct Review: Sendable, Hashable {
        public var level: ResultsReviewLevel
        /// Đề hiện tại `hideAnswers`: thêm dòng "Đề này ẩn đáp án…" trên mỗi câu còn trong đề.
        public var answersHidden: Bool
        public var questions: [ReviewQuestion]

        public init(level: ResultsReviewLevel, answersHidden: Bool, questions: [ReviewQuestion]) {
            self.level = level
            self.answersHidden = answersHidden
            self.questions = questions
        }
    }

    public var examTitle: String
    public var candidateName: String
    public var submittedAt: Date
    /// Mã đề, thí sinh, chế độ, nộp lúc, thời gian làm, ngưỡng đậu.
    public var headerFields: [ReportField]
    public var verdict: ReportBadge
    public var scoreText: String
    public var scoreFraction: Double
    public var passThresholdFraction: Double?
    /// Số câu đúng/tổng (dưới điểm).
    public var summaryFields: [ReportField]
    public var comparison: ReportBadge?
    /// "Không đọc được chi tiết lần thi này" (không có Theo phần, không có Xem lại).
    public var detailUnavailableMessage: String?
    public var sections: [ReportSectionScores.Row]
    /// Nil: không có phần xem lại (chọn **Không**, hoặc Xem lại không mở được).
    public var review: Review?
    /// Phiên bản app (Creator của PDF). PDF không ghi thời điểm xuất (Nt0 chốt 2026-10-17, export-print.md phương án
    /// 17): thời điểm duy nhất là lúc nộp bài.
    public var appVersion: String

    public init(
        examTitle: String,
        candidateName: String,
        submittedAt: Date,
        headerFields: [ReportField],
        verdict: ReportBadge,
        scoreText: String,
        scoreFraction: Double,
        passThresholdFraction: Double?,
        summaryFields: [ReportField],
        comparison: ReportBadge?,
        detailUnavailableMessage: String?,
        sections: [ReportSectionScores.Row],
        review: Review?,
        appVersion: String
    ) {
        self.examTitle = examTitle
        self.candidateName = candidateName
        self.submittedAt = submittedAt
        self.headerFields = headerFields
        self.verdict = verdict
        self.scoreText = scoreText
        self.scoreFraction = scoreFraction
        self.passThresholdFraction = passThresholdFraction
        self.summaryFields = summaryFields
        self.comparison = comparison
        self.detailUnavailableMessage = detailUnavailableMessage
        self.sections = sections
        self.review = review
        self.appVersion = appVersion
    }

    /// Tên file gợi ý: `<Tên đề> - <Thí sinh> - <yyyy-MM-dd HHmm>.pdf` (thời điểm nộp).
    public func suggestedFileName(timeZone: TimeZone = .autoupdatingCurrent) -> String {
        ReportFileName.results(examTitle: examTitle, candidateName: candidateName, submittedAt: submittedAt, timeZone: timeZone)
    }

    /// Tài liệu để dựng trang: đầu trang, kết quả, theo phần, xem lại (nếu có).
    public func document() -> ReportDocument {
        var blocks: [ReportBlock] = [
            .title(ReportTitle(title: examTitle, subtitle: ReportStrings.resultsSubtitle, fields: headerFields)),
            .resultSummary(ReportResultSummary(
                verdict: verdict,
                scoreText: scoreText,
                scoreFraction: scoreFraction,
                passThresholdFraction: passThresholdFraction,
                fields: summaryFields,
                comparison: comparison,
                notices: detailUnavailableMessage.map { [ReportNotice(text: $0, systemImage: "doc.questionmark")] } ?? []
            )),
        ]
        if !sections.isEmpty {
            blocks.append(.sectionScores(ReportSectionScores(title: ReportStrings.sectionsTitle, rows: sections)))
        }
        if let review {
            let labels = Labels()
            blocks.append(.heading(ReportHeading(
                title: ReportStrings.reviewTitle,
                detail: "\(review.level.title) · \(ReportStrings.questionCount(review.questions.count))"
            )))
            if review.questions.isEmpty {
                let text = review.level == .all ? ReportStrings.noQuestions : ReportStrings.noIncorrectOrUnanswered
                blocks.append(.notice(ReportNotice(text: text, systemImage: "checkmark.circle")))
            }
            for question in review.questions {
                blocks.append(.question(Self.block(for: question, answersHidden: review.answersHidden, labels: labels)))
            }
        }
        return ReportDocument(
            metadata: ReportMetadata(
                title: ReportStrings.resultsDocumentTitle(examTitle),
                creator: ReportStrings.creator(version: appVersion)
            ),
            footer: ReportFooter(title: examTitle, lines: [ReportStrings.resultsDisclaimer]),
            blocks: blocks
        )
    }

    /// Nhãn lặp lại trên mọi câu, tra catalog một lần cho cả tài liệu (dựng 2.000 khối chạy liền trên main actor).
    struct Labels {
        var selected = ReportStrings.selected
        var correctAnswer = ReportStrings.correctAnswer
        var flagged = ReportStrings.flagged
        var answersHidden = ReportStrings.answersHiddenNote
    }

    /// Khối câu: chỉ vẽ dấu có trong `question` (đã lọc theo quy tắc của Xem lại).
    static func block(for question: ReviewQuestion, answersHidden: Bool, labels: Labels = Labels()) -> ReportQuestion {
        var notices = question.notices.enumerated().map { offset, text in
            ReportNotice(text: text, systemImage: offset == 0 ? "exclamationmark.triangle.fill" : "info.circle")
        }
        if answersHidden, question.text != nil {
            notices.append(ReportNotice(text: labels.answersHidden, systemImage: "eye.slash"))
        }
        return ReportQuestion(
            number: question.number,
            sectionTitle: question.sectionTitle,
            positionText: ReportStrings.questionPosition(question.number, of: question.total),
            status: question.status,
            flag: question.isFlagged ? ReportBadge(title: labels.flagged, systemImage: "flag.fill") : nil,
            notices: notices,
            text: question.text,
            image: question.image,
            options: question.options.map { option in
                var marks: [ReportBadge] = []
                if option.isSelected {
                    marks.append(ReportBadge(title: labels.selected, systemImage: "hand.point.up.left.fill"))
                }
                if option.isCorrectAnswer == true {
                    marks.append(ReportBadge(title: labels.correctAnswer, systemImage: "checkmark.circle.fill"))
                }
                return ReportOption(label: option.label, text: option.text, marks: marks)
            },
            explanation: question.explanation
        )
    }
}
