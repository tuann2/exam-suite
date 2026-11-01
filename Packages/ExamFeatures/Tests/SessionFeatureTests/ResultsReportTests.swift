import ExamFile
import ExamKit
import Foundation
import LibraryData
import PDFKit
import ReportFeature
@testable import SessionFeature
@testable import SessionModel
import Testing

/// PDF kết quả (docs/product/export-print.md, mục Nội dung và Quy tắc ẩn/hiện): model dựng từ Kết quả + Xem lại, rồi
/// PDF thật đọc lại bằng PDFKit (đề nhỏ).
@MainActor
@Suite("PDF kết quả")
struct ResultsReportTests {
    let utc = TimeZone(identifier: "UTC")!
    let vi = Locale(identifier: "vi_VN")

    /// Hai phần có câu (3 + 2) và một phần rỗng; giải thích riêng từng câu để kiểm ẩn/hiện.
    func exam(hideAnswers: Bool = false) -> Exam {
        func single(_ text: String) -> Question {
            singleQuestion(text, explanation: "Lời giải của \(text)")
        }
        var multiple = multipleQuestion("Đâu là cảng biển lớn?")
        multiple.explanation = "Lời giải của Đâu là cảng biển lớn?"
        return makeExam(
            title: "Địa lý Đông Nam Á",
            code: "DL-01",
            hideAnswers: hideAnswers,
            sections: [
                SectionSpec(title: "Địa hình", questions: [single("Đỉnh núi cao nhất?"), multiple, single("Đồng bằng nào lớn nhất?")]),
                SectionSpec(title: "Rỗng", questions: []),
                SectionSpec(title: "Dân cư", questions: [single("Đô thị đông dân nhất?"), single("Dân tộc đông nhất?")]),
            ]
        )
    }

    /// Làm bài theo `plan` (theo vị trí phiên): "c" đúng, "w" sai, "-" bỏ trống; đánh dấu `flags`.
    func submit(
        _ harness: Harness,
        exam: Exam,
        plan: String,
        flags: Set<Int> = []
    ) async throws -> (ResultsModel, SessionSubmission) {
        let attempt = try await harness.start(exam, mode: .exam)
        for (index, step) in plan.enumerated() {
            attempt.goTo(index: index)
            switch step {
            case "c": attempt.answerCorrectly()
            case "w": attempt.answerWrongly()
            default: break
            }
            if flags.contains(index) { attempt.toggleFlag() }
        }
        harness.clock.advance(725)
        let submission = try #require(attempt.submitNow())
        let results = ResultsModel(
            submission: submission,
            content: ExamPackage(exam: attempt.session.exam, media: attempt.media),
            environment: harness.environment
        )
        return (results, submission)
    }

    func makeReport(_ results: ResultsModel, level: ResultsReviewLevel) async -> ResultsReport {
        let review = level == .none ? nil : await results.makeAnswerReview()
        return ResultsReport(
            results: results,
            review: review,
            level: level,
            appVersion: "1.0",
            locale: vi,
            timeZone: utc
        )
    }

    func pdfText(_ report: ResultsReport) async throws -> (PDFDocument, String) {
        let clock = ContinuousClock()
        let start = clock.now
        let pdf = try await ReportRenderer().render(report.document())
        print("Timing: PDF kết quả \(report.review?.questions.count ?? 0) câu xem lại → \(pdf.pageCount) trang \(clock.now - start)")
        let reader = try #require(PDFDocument(data: pdf.data))
        let text = try #require(reader.string)
        #expect(!text.contains("\u{00D0}"), "Ð (U+00D0) thay cho Đ")
        return (reader, text)
    }

    // MARK: - Nội dung

    @Test("Đầu trang, kết quả, theo phần, chân trang; chữ tiếng Việt đọc lại nguyên văn")
    func content() async throws {
        let harness = Harness(candidateName: "Nguyễn Văn Đức")
        let (results, submission) = try await submit(harness, exam: exam(), plan: "cccwc")
        let report = await makeReport(results, level: .none)

        #expect(report.examTitle == "Địa lý Đông Nam Á")
        #expect(report.headerFields.map(\.label) == ["Thí sinh", "Mã đề", "Chế độ", "Nộp lúc", "Thời gian làm", "Ngưỡng đậu"])
        #expect(report.headerFields.map(\.value).last == "70%")
        #expect(report.summaryFields == [ReportField(label: "Số câu đúng", value: "4/5")])
        #expect(report.verdict.title == "Đậu")
        #expect(report.scoreText == "80% · 800/1000")
        #expect(report.passThresholdFraction == 0.7)
        #expect(report.sections.map(\.detail) == ["3/3 · 100%", "Không có câu", "1/2 · 50%"])
        #expect(report.sections.map { $0.mark != nil } == [false, false, true])
        #expect(report.sections.map(\.fraction) == [1, nil, 0.5])
        #expect(report.review == nil)
        #expect(report.suggestedFileName(timeZone: utc) == ReportFileName.results(
            examTitle: "Địa lý Đông Nam Á",
            candidateName: "Nguyễn Văn Đức",
            submittedAt: submission.attempt.submittedAt,
            timeZone: utc
        ))

        let (reader, text) = try await pdfText(report)
        for expected in ["Địa lý Đông Nam Á", "Nguyễn Văn Đức", "DL-01", "Đậu", "80% · 800/1000", "Số câu đúng", "4/5",
                         "Ngưỡng đậu", "70%", "Theo phần", "Địa hình", "Dân cư", "Không có câu", "Phần yếu nhất",
                         "Kết quả luyện tập, không có giá trị xác nhận"] {
            #expect(text.contains(expected), "thiếu \(expected)")
        }
        #expect(!text.contains("Xem lại bài"))
        #expect(!text.contains("Bạn chọn"))
        #expect(reader.findString("Nguyễn Văn Đức", withOptions: []).count == 1)
        // Không có thời điểm xuất (export-print.md phương án 17): thời điểm duy nhất là lúc nộp, một lần ở đầu trang.
        #expect(!text.contains("Xuất bằng"))
        #expect(report.document().footer.lines == ["Kết quả luyện tập, không có giá trị xác nhận"])
        let submittedText = SessionFormat.dateTime(submission.attempt.submittedAt, locale: vi, timeZone: utc)
        #expect(reader.findString(submittedText, withOptions: []).count == 1)
        let attributes = reader.documentAttributes ?? [:]
        #expect(attributes[PDFDocumentAttribute.titleAttribute] as? String == "Địa lý Đông Nam Á – Kết quả")
        #expect(attributes[PDFDocumentAttribute.creatorAttribute] as? String == "Exam Suite 1.0")
        #expect(attributes[PDFDocumentAttribute.authorAttribute] == nil)
    }

    @Test("Mức xem lại: Không / Câu sai và chưa làm (đúng bộ lọc Sai + Chưa làm) / Tất cả câu, theo thứ tự phiên")
    func reviewLevels() async throws {
        let harness = Harness()
        // Câu 1 đúng, 2 sai, 3 bỏ trống, 4 sai, 5 đúng; đánh dấu câu 5.
        let (results, _) = try await submit(harness, exam: exam(), plan: "cw-wc", flags: [4])

        #expect(await makeReport(results, level: .none).review == nil)
        let incorrect = try #require(await makeReport(results, level: .incorrectAndUnanswered).review)
        #expect(incorrect.questions.map(\.number) == [2, 3, 4])
        #expect(incorrect.questions.map(\.status.title) == ["Sai", "Chưa làm", "Sai"])
        let all = try #require(await makeReport(results, level: .all).review)
        #expect(all.questions.map(\.number) == [1, 2, 3, 4, 5])
        #expect(all.questions.map(\.isFlagged) == [false, false, false, false, true])

        let (_, text) = try await pdfText(await makeReport(results, level: .incorrectAndUnanswered))
        #expect(text.contains("Xem lại bài"))
        #expect(text.contains("Câu sai và chưa làm · 3 câu"))
        for number in [2, 3, 4] { #expect(text.contains("Câu \(number)/5"), "thiếu câu \(number)") }
        for number in [1, 5] { #expect(!text.contains("Câu \(number)/5"), "thừa câu \(number)") }
        #expect(text.contains("Bạn chọn"))
        #expect(text.contains("Đáp án đúng"))
        #expect(text.contains("Lời giải của Đô thị đông dân nhất?"))

        let (_, allText) = try await pdfText(await makeReport(results, level: .all))
        for number in 1 ... 5 { #expect(allText.contains("Câu \(number)/5"), "thiếu câu \(number)") }
        #expect(allText.contains("Đã đánh dấu"))
        #expect(allText.contains("Tất cả câu · 5 câu"))

        // Làm đúng hết: mức mặc định không có câu nào, PDF ghi rõ.
        let (perfect, _) = try await submit(harness, exam: exam(), plan: "ccccc")
        let empty = try #require(await makeReport(perfect, level: .incorrectAndUnanswered).review)
        #expect(empty.questions.isEmpty)
        let (_, emptyText) = try await pdfText(await makeReport(perfect, level: .incorrectAndUnanswered))
        #expect(emptyText.contains("Không có câu sai hoặc chưa làm."))
        #expect(!emptyText.contains("Không có câu nào."))
        // Mức Tất cả câu mà không có câu (không xảy ra với phiên thật): dòng báo đúng mức.
        var allEmpty = await makeReport(perfect, level: .all)
        allEmpty.review = ResultsReport.Review(level: .all, answersHidden: false, questions: [])
        let notices = allEmpty.document().blocks.compactMap { block -> String? in
            if case let .notice(notice) = block { return notice.text }
            return nil
        }
        #expect(notices == ["Không có câu nào."])
    }

    @Test("hideAnswers: có lựa chọn của người làm và Đúng/Sai/Chưa làm; không có Đáp án đúng, không có giải thích")
    func hiddenAnswers() async throws {
        let harness = Harness()
        let (results, _) = try await submit(harness, exam: exam(hideAnswers: true), plan: "cw-wc")
        let review = try #require(await makeReport(results, level: .all).review)
        #expect(review.answersHidden)
        #expect(review.questions.allSatisfy { $0.explanation == nil })
        #expect(review.questions.allSatisfy { $0.options.allSatisfy { $0.isCorrectAnswer == nil } })
        #expect(review.questions.contains { $0.options.contains(where: \.isSelected) })

        let report = await makeReport(results, level: .all)
        let document = report.document()
        for case let .question(question) in document.blocks {
            #expect(question.explanation == nil)
            #expect(!question.options.contains { $0.marks.map(\.title).contains("Đáp án đúng") })
        }
        let (reader, text) = try await pdfText(report)
        #expect(!text.contains("Đáp án đúng"))
        #expect(reader.findString("Đáp án đúng", withOptions: .caseInsensitive).isEmpty)
        #expect(!text.contains("Lời giải"))
        #expect(!text.contains("Giải thích"))
        #expect(text.contains("Bạn chọn"))
        #expect(text.contains("Đề này ẩn đáp án: chỉ hiện lựa chọn của bạn và kết quả đúng/sai."))
        #expect(text.contains("Sai"))
        #expect(text.contains("Chưa làm"))
        // Siêu dữ liệu cũng không mang đáp án hay giải thích.
        let attributes = reader.documentAttributes ?? [:]
        #expect(Set(attributes.keys.map { "\($0.base)" }).isSubset(of: ["Title", "Creator", "Producer", "CreationDate", "ModDate"]))
        for value in attributes.values.compactMap({ $0 as? String }) {
            #expect(!value.contains("Lời giải"))
            #expect(!value.contains("Đáp án"))
            #expect(!value.contains("Giải thích"))
        }
        // Mức mặc định cũng vậy.
        let (_, defaultText) = try await pdfText(await makeReport(results, level: .incorrectAndUnanswered))
        #expect(!defaultText.contains("Đáp án đúng"))
        #expect(!defaultText.contains("Lời giải"))
    }

    @Test("hideAnswers cộng câu đã sửa sau lần thi: giải thích của file hiện tại cũng ẩn; không có Bạn chọn, Đáp án đúng")
    func hiddenAnswersWithEditedQuestion() async throws {
        let harness = Harness()
        let original = exam()
        let attempt = try await savedAttempt(harness, exam: original)
        var hidden = original
        hidden.hideAnswers = true
        hidden.sections[0].questions[1].explanation = "Giải thích mới bí mật"
        hidden.sections[0].questions[0].text = "Đỉnh núi cao nhất? (sửa)"
        harness.library.packages[original.id] = .success(ExamPackage(exam: hidden))

        let report = await makeReport(ResultsModel.history(attempt, environment: harness.environment), level: .all)
        let review = try #require(report.review)
        #expect(review.answersHidden)
        #expect(review.questions[0].notices.first == "Câu này đã được sửa sau lần thi")
        #expect(review.questions[1].notices.first == "Câu này đã được sửa sau lần thi")
        #expect(review.questions.allSatisfy { $0.explanation == nil })
        let (reader, text) = try await pdfText(report)
        #expect(!text.contains("Giải thích mới bí mật"))
        #expect(!text.contains("Lời giải"))
        #expect(!text.contains("Đáp án đúng"))
        #expect(reader.findString("Câu này đã được sửa sau lần thi", withOptions: []).count == 2)
        // Câu sửa không có Bạn chọn; ba câu không đổi đã trả lời (1 bỏ trống) còn lại: câu 4, 5.
        #expect(reader.findString("Bạn chọn", withOptions: []).count == 2)
    }

    @Test("Câu sai và chưa làm: câu đã xoá khỏi đề mà lúc thi Sai vẫn có, kèm “Câu này đã bị xoá khỏi đề”")
    func incorrectIncludesDeletedQuestion() async throws {
        let harness = Harness()
        let original = exam()
        let attempt = try await savedAttempt(harness, exam: original)
        var edited = original
        edited.sections[2].questions.remove(at: 0)  // câu 4 (Sai lúc thi)
        harness.library.packages[original.id] = .success(ExamPackage(exam: edited))

        let report = await makeReport(ResultsModel.history(attempt, environment: harness.environment), level: .incorrectAndUnanswered)
        let review = try #require(report.review)
        #expect(review.questions.map(\.number) == [2, 3, 4])
        let deleted = review.questions[2]
        #expect(deleted.status.title == "Sai")
        #expect(deleted.text == nil)
        #expect(deleted.options.isEmpty)
        #expect(deleted.notices == ["Câu này đã bị xoá khỏi đề"])
        let (_, text) = try await pdfText(report)
        #expect(text.contains("Câu 4/5"))
        #expect(text.contains("Câu này đã bị xoá khỏi đề"))
        #expect(!text.contains("Đô thị đông dân nhất?"))
    }

    // MARK: - Lần thi cũ

    /// Lần thi đã lưu: Q1 đúng, Q2 sai, Q3 bỏ trống, Q4 sai, Q5 đúng.
    func savedAttempt(_ harness: Harness, exam: Exam) async throws -> Attempt {
        try await submit(harness, exam: exam, plan: "cw-wc").1.attempt
    }

    @Test("Câu đã sửa sau lần thi: nội dung hiện tại, cảnh báo, không có “Bạn chọn”/“Đáp án đúng”; giải thích hiện tại; câu đã xoá")
    func editedQuestions() async throws {
        let harness = Harness()
        let original = exam()
        let attempt = try await savedAttempt(harness, exam: original)
        var edited = original
        // Sửa mọi câu còn lại, xoá câu 3.
        edited.sections[0].questions[0].text = "Đỉnh núi cao nhất? (sửa)"
        edited.sections[0].questions[1].explanation = "Giải thích mới của câu 2"
        edited.sections[0].questions.remove(at: 2)
        edited.sections[2].questions[0].options[0].text = "Lựa chọn đã sửa"
        edited.sections[2].questions[1].correct = [OptionID("C")!]
        // Đề sửa phải ghi rồi đọc lại được như file thật (đọc dễ: đề thử có phần rỗng để kiểm "Không có câu").
        let workspace = try SessionWorkspace()
        let file = try workspace.write(ExamPackage(exam: edited), to: "edited.exam")
        harness.library.packages[original.id] = .success(try ExamPackageReader.read(contentsOf: file, mode: .lenient))

        let results = ResultsModel.history(attempt, environment: harness.environment)
        let report = await makeReport(results, level: .all)
        let review = try #require(report.review)
        #expect(review.questions.count == 5)
        #expect(review.questions.allSatisfy { $0.options.allSatisfy { !$0.isSelected && $0.isCorrectAnswer == nil } })
        #expect(review.questions[2].text == nil)
        #expect(review.questions[2].notices == ["Câu này đã bị xoá khỏi đề"])
        #expect(review.questions[1].explanation == "Giải thích mới của câu 2")
        #expect(review.questions.map(\.status.title) == ["Đúng", "Sai", "Chưa làm", "Sai", "Đúng"])

        let (reader, text) = try await pdfText(report)
        #expect(!text.contains("Bạn chọn"))
        #expect(reader.findString("Bạn chọn", withOptions: .caseInsensitive).isEmpty)
        #expect(!text.contains("Đáp án đúng"))
        #expect(text.contains("Đỉnh núi cao nhất? (sửa)"))
        #expect(text.contains("Giải thích mới của câu 2"))
        #expect(text.contains("Câu này đã bị xoá khỏi đề"))
        #expect(reader.findString("Câu này đã được sửa sau lần thi", withOptions: []).count == 4)
        #expect(reader.findString("Không hiện lựa chọn của bạn vì câu đã sửa sau lần thi", withOptions: []).count == 4)

        // Chỉ một câu sửa: các câu không đổi vẫn có “Bạn chọn”, câu sửa thì không.
        var oneEdited = original
        oneEdited.sections[0].questions[1].text = "Đâu là cảng biển lớn? (sửa)"
        harness.library.packages[original.id] = .success(ExamPackage(exam: oneEdited))
        let mixed = try #require(await makeReport(ResultsModel.history(attempt, environment: harness.environment), level: .all).review)
        #expect(mixed.questions.map { $0.options.contains(where: \.isSelected) } == [true, false, false, true, true])
        let (mixedReader, _) = try await pdfText(await makeReport(ResultsModel.history(attempt, environment: harness.environment), level: .all))
        #expect(mixedReader.findString("Bạn chọn", withOptions: []).count == 3)
    }

    @Test("Chi tiết lần thi không đọc được: đầu trang và tóm tắt kèm lý do; không có Theo phần, không có Xem lại")
    func detailUnavailable() async throws {
        let harness = Harness(candidateName: "Trần Thị Đào")
        let attempt = try await savedAttempt(harness, exam: exam())
        harness.library.payloads[attempt.id] = Data("hỏng".utf8)
        let results = ResultsModel.history(attempt, environment: harness.environment)
        let report = await makeReport(results, level: .all)
        #expect(report.detailUnavailableMessage == "Không đọc được chi tiết lần thi này")
        #expect(report.sections.isEmpty)
        #expect(report.review == nil)
        #expect(!report.headerFields.map(\.label).contains("Ngưỡng đậu"))

        let (_, text) = try await pdfText(report)
        #expect(text.contains("Không đọc được chi tiết lần thi này"))
        #expect(text.contains("Trần Thị Đào"))
        #expect(text.contains("Trượt"))
        #expect(text.contains("40% · 400/1000"))
        #expect(!text.contains("Theo phần"))
        #expect(!text.contains("Xem lại bài"))
    }
}
