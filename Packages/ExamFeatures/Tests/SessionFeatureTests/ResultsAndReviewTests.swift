import ExamFile
import ExamKit
import Foundation
import LibraryData
@testable import SessionFeature
@testable import SessionModel
import Testing

/// Kết quả và Xem lại bài của bài vừa nộp (docs/product/exam-taking.md, mục Kết quả, Xem lại bài,
/// Đề ẩn đáp án).
@MainActor
@Suite("Kết quả và Xem lại bài")
struct ResultsAndReviewTests {
    // Hai phần có câu (3 + 2) và một phần rỗng ở giữa.
    let exam = makeExam(
        sections: [
            SectionSpec(title: "Mạng", questions: [singleQuestion("Q1"), multipleQuestion("Q2"), singleQuestion("Q3")]),
            SectionSpec(title: "Rỗng", questions: []),
            SectionSpec(title: "Bảo mật", questions: [singleQuestion("Q4"), singleQuestion("Q5")]),
        ]
    )

    /// Làm bài theo `plan` (theo vị trí phiên): "c" đúng, "w" sai, "-" bỏ trống; đánh dấu các câu `flags`.
    func finish(
        _ harness: Harness,
        exam: Exam? = nil,
        mode: SessionMode = .exam,
        plan: String,
        flags: Set<Int> = [],
        elapsed: TimeInterval = 0,
        configure: (PreExamModel) -> Void = { _ in }
    ) async throws -> (AttemptModel, SessionSubmission) {
        let attempt = try await harness.start(exam ?? self.exam, mode: mode, configure: configure)
        for (index, step) in plan.enumerated() {
            attempt.goTo(index: index)
            switch step {
            case "c": attempt.answerCorrectly()
            case "w": attempt.answerWrongly()
            default: break
            }
            if flags.contains(index) { attempt.toggleFlag() }
        }
        harness.clock.advance(elapsed)
        let submission = try #require(attempt.submitNow())
        return (attempt, submission)
    }

    func results(_ harness: Harness, _ attempt: AttemptModel, _ submission: SessionSubmission) -> ResultsModel {
        ResultsModel(
            submission: submission,
            content: ExamPackage(exam: attempt.session.exam, media: attempt.media),
            environment: harness.environment
        )
    }

    // MARK: - Kết quả

    @Test("Đậu: “80% · 800/1000”, vạch ngưỡng 70%, thông tin thí sinh, mã đề, chế độ, ngày nộp, thời gian, đúng/tổng")
    func passedResults() async throws {
        let harness = Harness(candidateName: "Nguyễn Văn An")
        let (attempt, submission) = try await finish(harness, plan: "cccwc", elapsed: 725)
        let model = results(harness, attempt, submission)

        #expect(model.origin == .justSubmitted)
        #expect(model.passed)
        #expect(model.verdictText == "Đậu")
        #expect(model.verdictSymbol == "checkmark.seal.fill")
        #expect(model.scoreText == "80% · 800/1000")
        #expect(model.scoreFraction == 0.8)
        #expect(model.passThresholdFraction == 0.7)
        #expect(model.saveError == nil)
        #expect(model.detailUnavailableReason == nil)

        let rows = model.infoRows(locale: Locale(identifier: "vi_VN"), timeZone: TimeZone(identifier: "UTC")!)
        #expect(rows.map(\.kind) == [.candidate, .examCode, .mode, .submittedAt, .duration, .correctCount])
        #expect(rows.map(\.label) == ["Thí sinh", "Mã đề", "Chế độ", "Nộp lúc", "Thời gian làm", "Số câu đúng"])
        #expect(rows[0].value == "Nguyễn Văn An")
        #expect(rows[1].value == "KTC01")
        #expect(rows[2].value == "Thi")
        #expect(rows[3].value == SessionFormat.dateTime(
            submission.attempt.submittedAt, locale: Locale(identifier: "vi_VN"), timeZone: TimeZone(identifier: "UTC")!
        ))
        #expect(rows[4].value == "12 phút 5 giây / 30 phút")
        #expect(rows[5].value == "4/5")
    }

    @Test("Trượt; Luyện tập không có thời gian cho phép")
    func failedPractice() async throws {
        let harness = Harness()
        let (attempt, submission) = try await finish(harness, mode: .practice, plan: "cw---", elapsed: 45)
        let model = results(harness, attempt, submission)
        #expect(!model.passed)
        #expect(model.verdictText == "Trượt")
        #expect(model.verdictSymbol == "xmark.seal.fill")
        #expect(model.scoreText == "20% · 200/1000")
        let rows = model.infoRows()
        #expect(rows.first { $0.kind == .duration }?.value == "45 giây")
        #expect(rows.first { $0.kind == .mode }?.value == "Luyện tập")
    }

    @Test("Lưu lỗi: Kết quả vẫn hiện, kèm lỗi")
    func saveErrorShown() async throws {
        let harness = Harness()
        harness.library.failSaving = true
        let (attempt, submission) = try await finish(harness, plan: "ccccc")
        let model = results(harness, attempt, submission)
        #expect(model.saveError?.hasPrefix("Không lưu được lần thi vào Lịch sử thi") == true)
        #expect(model.scoreText == "100% · 1000/1000")
        #expect(model.canReview)
    }

    @Test("So với lần trước: lần trước cùng đề, cùng chế độ (khác chế độ và đề khác bị loại, không tính chính lần này)")
    func comparisonWithPrevious() async throws {
        let harness = Harness()
        let other = makeExam(counts: [1])
        // Lần đầu: không có lần trước.
        let (a1, s1) = try await finish(harness, plan: "ccc--")
        #expect(results(harness, a1, s1).comparison == nil)
        harness.clock.advance(60)
        // Luyện tập cùng đề và Thi đề khác: không tính.
        _ = try await finish(harness, mode: .practice, plan: "ccccc")
        harness.clock.advance(60)
        let otherAttempt = try await harness.start(other, mode: .exam)
        otherAttempt.answerCorrectly()
        otherAttempt.submitNow()
        harness.clock.advance(60)

        let (a2, s2) = try await finish(harness, plan: "c----")
        let comparison = try #require(results(harness, a2, s2).comparison)
        #expect(comparison.previousAttemptID == s1.attempt.id)
        #expect(comparison.previousPercent == 60)
        #expect(comparison.delta == -40)
        #expect(comparison.text == "So với lần trước: −40%")

        harness.clock.advance(60)
        let (a3, s3) = try await finish(harness, plan: "cccc-")
        #expect(results(harness, a3, s3).comparison?.text == "So với lần trước: +60%")
        harness.clock.advance(60)
        let (a4, s4) = try await finish(harness, plan: "cccc-")
        #expect(results(harness, a4, s4).comparison?.text == "So với lần trước: bằng")
    }

    @Test("Theo phần: phần 0/0 là “Không có câu”, không có thanh; phần yếu nhất là % thấp nhất")
    func sectionRows() async throws {
        let harness = Harness()
        let (attempt, submission) = try await finish(harness, plan: "ccwcw")
        let rows = results(harness, attempt, submission).sectionRows
        #expect(rows.map(\.title) == ["Mạng", "Rỗng", "Bảo mật"])
        #expect(rows.map(\.detailText) == ["2/3 · 66%", "Không có câu", "1/2 · 50%"])
        #expect(rows[1].fraction == nil)
        #expect(rows[1].percent == nil)
        #expect(!rows[1].hasQuestions)
        #expect(rows.map(\.isWeakest) == [false, false, true])
    }

    @Test("Phần yếu nhất: bằng nhau lấy phần đứng trước; chỉ một phần có câu thì không đánh dấu")
    func weakestSectionRules() {
        func score(_ title: String, _ correct: Int, _ total: Int) -> SectionScore {
            SectionScore(sectionID: UUID(), title: title, total: total, correct: correct)
        }
        let tie = [score("A", 1, 2), score("B", 2, 4), score("C", 3, 3)]
        #expect(ResultsModel.weakestSectionID(tie) == tie[0].sectionID)
        let one = [score("A", 0, 0), score("B", 1, 4), score("C", 0, 0)]
        #expect(ResultsModel.weakestSectionID(one) == nil)
        let allZero = [score("A", 0, 2), score("B", 0, 1)]
        #expect(ResultsModel.weakestSectionID(allZero) == allZero[0].sectionID)
        // Cùng % hiển thị (chia lấy phần nguyên) là bằng nhau: 1/3 và 33/100 đều 33%.
        let rounded = [score("A", 33, 100), score("B", 1, 3)]
        #expect(ResultsModel.weakestSectionID(rounded) == rounded[0].sectionID)
    }

    @Test("Chỉ một phần có câu trong phiên (Theo phần): không có phần yếu nhất")
    func weakestWithSingleSectionSelected() async throws {
        let harness = Harness()
        let (attempt, submission) = try await finish(harness, plan: "cw-") {
            $0.selectionKind = .sections
            $0.deselectAllSections()
            $0.toggleSection(exam.sections[0].id)
        }
        let rows = results(harness, attempt, submission).sectionRows
        #expect(rows.map(\.detailText) == ["1/3 · 33%", "Không có câu", "Không có câu"])
        #expect(rows.allSatisfy { !$0.isWeakest })
    }

    @Test("Làm lại: preset đúng lựa chọn của lần vừa làm; đề không còn trong thư viện thì không có")
    func retakePreset() async throws {
        let harness = Harness()
        let (attempt, submission) = try await finish(harness, plan: "c", configure: {
            $0.selectionKind = .random
            $0.randomCount = 1
            $0.timeLimitMinutes = 15
        })
        let model = results(harness, attempt, submission)
        let record = try #require(submission.record)
        #expect(model.retakePreset == .retake(mode: .exam, options: record.options, timeLimitMinutes: 15))
        harness.library.remove(exam.id)
        #expect(model.retakePreset == nil)
    }

    // MARK: - Xem lại bài

    @Test("Bộ lọc Tất cả/Sai/Chưa làm/Đã đánh dấu/Đúng kèm số; Câu trước/sau đi trong bộ lọc")
    func reviewFilters() async throws {
        let harness = Harness()
        let (attempt, submission) = try await finish(harness, plan: "cw-wc", flags: [1, 2])
        let review = try #require(await results(harness, attempt, submission).makeAnswerReview())

        #expect(review.filter == .all)
        #expect(AnswerReviewFilter.allCases.map { review.count(for: $0) } == [5, 2, 1, 2, 2])
        #expect(AnswerReviewFilter.allCases.map { review.filterTitle($0) } == [
            "Tất cả (5)", "Sai (2)", "Chưa làm (1)", "Đã đánh dấu (2)", "Đúng (2)",
        ])
        #expect(review.rows.map(\.number) == [1, 2, 3, 4, 5])
        #expect(review.rows.map(\.status.title) == ["Đúng", "Sai", "Chưa làm", "Sai", "Đúng"])
        #expect(review.rows.map(\.isFlagged) == [false, true, true, false, false])
        #expect(review.selectedIndex == 0)

        review.setFilter(.incorrect)
        #expect(review.rows.map(\.index) == [1, 3])
        #expect(review.selectedIndex == 1)
        #expect(!review.canGoPrevious)
        review.next()
        #expect(review.selectedIndex == 3)
        #expect(!review.canGoNext)
        review.next()
        #expect(review.selectedIndex == 3)
        review.previous()
        #expect(review.selectedIndex == 1)

        // Câu đang xem thuộc bộ lọc mới thì giữ nguyên.
        review.setFilter(.flagged)
        #expect(review.selectedIndex == 1)
        review.select(index: 0)
        #expect(review.selectedIndex == 1)
        review.setFilter(.correct)
        #expect(review.selectedIndex == 0)
    }

    @Test("Xem câu sai mở bộ lọc Sai; bộ lọc rỗng thì không có câu đang xem")
    func reviewIncorrectFilter() async throws {
        let harness = Harness()
        let (attempt, submission) = try await finish(harness, plan: "ccccc")
        let review = try #require(await results(harness, attempt, submission).makeAnswerReview(filter: .incorrect))
        #expect(review.filter == .incorrect)
        #expect(review.rows.isEmpty)
        #expect(review.selectedIndex == nil)
        #expect(review.detail == nil)
        #expect(review.practiceIncorrectPreset == nil)
    }

    @Test("Chi tiết: lựa chọn theo thứ tự đã hiện, Bạn chọn / Đáp án đúng, giải thích")
    func reviewDetail() async throws {
        let harness = Harness()
        harness.seeds.seeds = [11]
        let (attempt, submission) = try await finish(harness, plan: "w", configure: { $0.shuffleOptions = true })
        let order = attempt.session.paper.items[0].optionOrder
        let review = try #require(await results(harness, attempt, submission).makeAnswerReview())
        let detail = try #require(review.detail)

        #expect(detail.number == 1)
        #expect(detail.total == 5)
        #expect(detail.sectionTitle == "Mạng")
        #expect(detail.status.title == "Sai")
        #expect(detail.change == .unchanged)
        #expect(detail.notices.isEmpty)
        #expect(detail.text == "Q1")
        #expect(detail.options.map(\.optionID) == order)
        #expect(detail.options.map(\.label) == ["A", "B", "C", "D"])
        let selected = try #require(submission.record?.answers[exam.allQuestions[0].id])
        for option in detail.options {
            #expect(option.isSelected == selected.contains(option.optionID))
            #expect(option.isCorrectAnswer == (option.optionID == OptionID("B")!))
        }
        let correctRow = try #require(detail.options.first { $0.optionID == OptionID("B")! })
        #expect(correctRow.marks == ["Đáp án đúng"])
        let chosenRow = try #require(detail.options.first { $0.isSelected })
        #expect(chosenRow.marks == ["Bạn chọn"])
        #expect(detail.explanation == "Giải thích")
    }

    @Test("Luyện lại câu sai: câu sai và chưa làm theo thứ tự phiên")
    func practiceIncorrectFromReview() async throws {
        let harness = Harness()
        let (attempt, submission) = try await finish(harness, plan: "cw-wc")
        let review = try #require(await results(harness, attempt, submission).makeAnswerReview())
        let ids = attempt.session.paper.questionIDs
        #expect(review.practiceIncorrectPreset == .practiceIncorrect(questionIDs: [ids[1], ids[2], ids[3]]))
    }

    // MARK: - Đề ẩn đáp án

    @Test("hideAnswers: Kết quả đủ; Xem lại có Đúng/Sai/Chưa làm và bộ lọc nhưng không lộ đáp án đúng, giải thích")
    func hiddenAnswers() async throws {
        var hidden = exam
        hidden.hideAnswers = true
        let harness = Harness()
        let (attempt, submission) = try await finish(harness, exam: hidden, plan: "cw-wc")
        let model = results(harness, attempt, submission)
        #expect(model.scoreText == "40% · 400/1000")
        #expect(model.sectionRows.count == 3)

        let review = try #require(await model.makeAnswerReview())
        #expect(review.answersHidden)
        #expect(review.count(for: .incorrect) == 2)
        #expect(review.rows.map(\.status.title) == ["Đúng", "Sai", "Chưa làm", "Sai", "Đúng"])
        for index in 0 ..< review.questionCount {
            let detail = review.detail(at: index)
            #expect(detail.explanation == nil)
            #expect(detail.options.allSatisfy { $0.isCorrectAnswer == nil })
            #expect(detail.options.allSatisfy { !$0.marks.contains("Đáp án đúng") })
            #expect(!String(describing: detail).contains("Giải thích"))
        }
        #expect(review.detail(at: 1).options.contains { $0.isSelected })
        #expect(review.practiceIncorrectPreset == nil)
        // Câu đọc của lựa chọn cũng không có "Đáp án đúng".
        for index in 0 ..< review.questionCount {
            #expect(review.detail(at: index).options.allSatisfy { !$0.accessibilityLabel.contains("Đáp án đúng") })
        }
    }

    // MARK: - Câu đọc VoiceOver (bước 8b)

    @Test("Câu đọc của Kết quả: Đậu/Trượt, điểm, ngưỡng đậu, so với lần trước; mỗi dòng Theo phần: tên, đúng/tổng, %, phần yếu nhất")
    func resultsReadingSentences() async throws {
        let harness = Harness()
        let (a1, s1) = try await finish(harness, plan: "ccc--")
        // Lần đầu: không có so với lần trước.
        #expect(results(harness, a1, s1).verdictAccessibilityLabel == "Trượt, 60% · 600/1000, Ngưỡng đậu 70%")
        harness.clock.advance(60)
        let (a2, s2) = try await finish(harness, plan: "ccwcw")
        let model = results(harness, a2, s2)
        #expect(model.verdictAccessibilityLabel == "Trượt, 60% · 600/1000, Ngưỡng đậu 70%, So với lần trước: bằng")
        #expect(model.sectionRows.map(\.accessibilityLabel) == [
            "Mạng, 2/3 · 66%", "Rỗng, Không có câu", "Bảo mật, 1/2 · 50%, Phần yếu nhất",
        ])
        harness.clock.advance(60)
        let (a3, s3) = try await finish(harness, plan: "ccccc")
        #expect(results(harness, a3, s3).verdictAccessibilityLabel
            == "Đậu, 100% · 1000/1000, Ngưỡng đậu 70%, So với lần trước: +40%")
    }

    @Test("Câu đọc của Xem lại bài: dòng câu (số, trạng thái, đánh dấu, đoạn đầu không Markdown); lựa chọn (chữ cái, nội dung, Bạn chọn, Đáp án đúng)")
    func reviewReadingSentences() async throws {
        let markdown = makeExam(sections: [
            SectionSpec(title: "Mạng", questions: [singleQuestion("Giao thức **TCP** dùng `cổng`?"), singleQuestion("Q2")]),
        ])
        let harness = Harness()
        let (attempt, submission) = try await finish(harness, exam: markdown, plan: "wc", flags: [0])
        let review = try #require(await results(harness, attempt, submission).makeAnswerReview())
        #expect(review.rows.map(\.accessibilityLabel) == [
            "Câu 1, Sai, Đánh dấu, Giao thức TCP dùng cổng?",
            "Câu 2, Đúng, Q2",
        ])
        let detail = review.detail(at: 0)
        let chosen = try #require(detail.options.first { $0.isSelected })
        #expect(chosen.accessibilityLabel == "\(chosen.label). \(PlainMarkdown.text(chosen.text)), Bạn chọn")
        let correct = try #require(detail.options.first { $0.isCorrectAnswer == true })
        #expect(correct.accessibilityLabel == "\(correct.label). \(PlainMarkdown.text(correct.text)), Đáp án đúng")
        let plain = try #require(detail.options.first { !$0.isSelected && $0.isCorrectAnswer != true })
        #expect(plain.accessibilityLabel == "\(plain.label). \(PlainMarkdown.text(plain.text))")
        #expect(!plain.accessibilityLabel.contains("**"))
    }

    @Test("Xem trước của Soạn đề đọc lựa chọn như cửa sổ làm bài, thêm “Đáp án đúng” ở Luyện tập; bỏ ký hiệu Markdown")
    func previewOptionReading() {
        #expect(PreviewOptionRow.accessibilityLabel(label: "A", text: "Giao thức **TCP**", isCorrect: true)
            == "A. Giao thức TCP, Đáp án đúng")
        #expect(PreviewOptionRow.accessibilityLabel(label: "B", text: "`UDP`", isCorrect: false) == "B. UDP")
        #expect(PreviewOptionRow.accessibilityLabel(label: "C", text: "Khác", isCorrect: nil) == "C. Khác")
        #expect(PlainMarkdown.text("*nghiêng* và **đậm**") == "nghiêng và đậm")
    }
}
