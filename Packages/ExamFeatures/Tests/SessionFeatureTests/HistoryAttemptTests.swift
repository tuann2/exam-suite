import ExamFile
import ExamKit
import Foundation
import LibraryData
@testable import SessionFeature
@testable import SessionModel
import Testing

/// Mở lần thi cũ từ Lịch sử thi (docs/product/exam-taking.md, mục Lịch sử thi và Dữ liệu một lần thi).
@MainActor
@Suite("Lần thi cũ từ Lịch sử thi")
struct HistoryAttemptTests {
    let exam = makeExam(
        sections: [
            SectionSpec(title: "Mạng", questions: [singleQuestion("Q1"), multipleQuestion("Q2"), singleQuestion("Q3")]),
            SectionSpec(title: "Bảo mật", questions: [singleQuestion("Q4"), singleQuestion("Q5")]),
        ]
    )

    /// Một lần thi đã lưu: Q1 đúng, Q2 chọn A (sai), Q3 bỏ trống, Q4 chọn C (sai), Q5 đúng; đánh dấu Q2.
    func savedAttempt(_ harness: Harness, mode: SessionMode = .exam) async throws -> Attempt {
        let attempt = try await harness.start(exam, mode: mode)
        attempt.answer("B")
        attempt.goTo(index: 1)
        attempt.answer("A")
        attempt.toggleFlag()
        attempt.goTo(index: 3)
        attempt.answer("C")
        attempt.goTo(index: 4)
        attempt.answer("B")
        harness.clock.advance(300)
        let submission = try #require(attempt.submitNow())
        #expect(submission.saveError == nil)
        return submission.attempt
    }

    @Test("Payload đọc được và khớp tóm tắt: đủ chi tiết, theo phần, Làm lại, Xem lại")
    func readablePayload() async throws {
        let harness = Harness()
        let attempt = try await savedAttempt(harness)
        let model = ResultsModel.history(attempt, environment: harness.environment)

        #expect(model.origin == .history)
        #expect(model.record != nil)
        #expect(model.detailUnavailableReason == nil)
        #expect(model.scoreText == "40% · 400/1000")
        #expect(model.sectionRows.map(\.detailText) == ["1/3 · 33%", "1/2 · 50%"])
        #expect(model.examCode == "KTC01")
        #expect(model.infoRows().first { $0.kind == .duration }?.value == "5 phút / 30 phút")
        #expect(model.retakePreset != nil)
        #expect(model.canReview)

        let review = try #require(await model.makeAnswerReview())
        #expect(review.rows.allSatisfy { $0.change == .unchanged })
        #expect(review.rows.map(\.status.title) == ["Đúng", "Sai", "Chưa làm", "Sai", "Đúng"])
        #expect(review.count(for: .flagged) == 1)
    }

    @Test("Payload hỏng hoặc trống: tóm tắt vẫn hiện; chi tiết, Xem lại, Làm lại tắt với lý do")
    func corruptPayload() async throws {
        let harness = Harness()
        let attempt = try await savedAttempt(harness)
        for payload in [Data("không phải JSON".utf8), Data()] {
            harness.library.payloads[attempt.id] = payload
            let model = ResultsModel.history(attempt, environment: harness.environment)
            #expect(model.record == nil)
            #expect(model.detailUnavailableReason == "Không đọc được chi tiết lần thi này")
            #expect(model.reviewUnavailableReason == "Không đọc được chi tiết lần thi này")
            #expect(!model.canReview)
            #expect(model.sectionRows.isEmpty)
            #expect(model.passThresholdFraction == nil)
            #expect(model.retakePreset == nil)
            #expect(model.scoreText == "40% · 400/1000")
            #expect(model.verdictText == "Trượt")
            #expect(await model.makeAnswerReview() == nil)
        }
    }

    @Test("Payload ghi bởi bản app mới hơn: chỉ tóm tắt")
    func newerPayloadVersion() async throws {
        let harness = Harness()
        let attempt = try await savedAttempt(harness)
        let original = try #require(harness.library.payloads[attempt.id])
        var json = try #require(try JSONSerialization.jsonObject(with: original) as? [String: Any])
        json["payloadVersion"] = AttemptRecord.currentPayloadVersion + 1
        harness.library.payloads[attempt.id] = try JSONSerialization.data(withJSONObject: json)
        #expect(throws: AttemptRecordError.self) { try AttemptRecord.decode(harness.library.payloads[attempt.id]!) }

        let model = ResultsModel.history(attempt, environment: harness.environment)
        #expect(model.record == nil)
        #expect(model.detailUnavailableReason == "Không đọc được chi tiết lần thi này")
    }

    @Test("Tóm tắt lệch payload (đề, chế độ, đúng, tổng, thang 1000, %, đậu): coi như không đọc được chi tiết")
    func summaryMismatch() async throws {
        let harness = Harness()
        let attempt = try await savedAttempt(harness)
        let changes: [(String, (inout Attempt) -> Void)] = [
            ("examID", { _ in }),
            ("mode", { $0.mode = .practice }),
            ("correct", { $0.correct += 1 }),
            ("total", { $0.total += 1 }),
            ("score1000", { $0.score1000 += 1 }),
            ("percent", { $0.percent += 1 }),
            ("passed", { $0.passed.toggle() }),
        ]
        for (name, change) in changes {
            var summary: Attempt
            if name == "examID" {
                summary = Attempt(
                    id: attempt.id, examID: UUID(), examTitle: attempt.examTitle, candidateName: attempt.candidateName,
                    mode: attempt.mode, startedAt: attempt.startedAt, submittedAt: attempt.submittedAt,
                    elapsedSeconds: attempt.elapsedSeconds, correct: attempt.correct, total: attempt.total,
                    score1000: attempt.score1000, percent: attempt.percent, passed: attempt.passed
                )
            } else {
                summary = attempt
                change(&summary)
            }
            let model = ResultsModel.history(summary, environment: harness.environment)
            #expect(model.record == nil, "lệch \(name)")
            #expect(model.detailUnavailableReason == "Không đọc được chi tiết lần thi này", "lệch \(name)")
        }
        #expect(ResultsModel.history(attempt, environment: harness.environment).record != nil)
    }

    @Test("Đề đã xoá khỏi thư viện: kết quả vẫn xem được; không có Làm lại; Xem lại tắt kèm lý do")
    func examRemovedFromLibrary() async throws {
        let harness = Harness()
        let attempt = try await savedAttempt(harness)
        harness.library.remove(exam.id)
        let model = ResultsModel.history(attempt, environment: harness.environment)
        #expect(model.record != nil)
        #expect(model.sectionRows.count == 2)
        #expect(model.examCode == nil)
        #expect(model.retakePreset == nil)
        #expect(model.reviewUnavailableReason == "Đề không còn trong thư viện nên không xem lại được.")
        #expect(!model.canReview)
        #expect(await model.makeAnswerReview() == nil)
    }

    @Test("Đề mất file hoặc có lỗi: Xem lại tắt kèm lý do; Làm lại vẫn có (đề còn trong thư viện)")
    func examFileUnavailable() async throws {
        let harness = Harness()
        let attempt = try await savedAttempt(harness)
        let entry = try #require(harness.library.entries[exam.id])

        harness.library.entries[exam.id]?.status = .missing
        var model = ResultsModel.history(attempt, environment: harness.environment)
        #expect(model.reviewUnavailableReason == "Không tìm thấy file đề nên không xem lại được.")
        #expect(model.retakePreset != nil)

        harness.library.entries[exam.id]?.status = .invalid(reason: .stored("Đề có lỗi."))
        model = ResultsModel.history(attempt, environment: harness.environment)
        #expect(model.reviewUnavailableReason == "Không đọc được file đề nên không xem lại được. Đề có lỗi.")

        harness.library.entries[exam.id] = entry
        #expect(model.canReview)
    }

    @Test("Đọc file đề lúc Xem lại thất bại: không mở, có lý do, báo Thư viện làm mới")
    func reviewReadFailure() async throws {
        let harness = Harness()
        let attempt = try await savedAttempt(harness)
        harness.library.packages[exam.id] = .failure(.unreadable(reason: "File hỏng."))
        let model = ResultsModel.history(attempt, environment: harness.environment)
        #expect(model.canReview)

        #expect(await model.makeAnswerReview() == nil)
        #expect(model.reviewFailure == "Không đọc được file đề nên không xem lại được. File hỏng.")
        #expect(harness.library.refreshRequests == [exam.id])
    }

    @Test("Câu đã xoá; câu đã sửa: nội dung hiện tại + cảnh báo, không đánh dấu Bạn chọn/Đáp án đúng; đúng/sai lúc thi; Luyện lại chỉ câu còn trong đề")
    func reviewAgainstEditedExam() async throws {
        let harness = Harness()
        let attempt = try await savedAttempt(harness)
        var edited = exam
        let q2 = exam.sections[0].questions[1]
        let q4 = exam.sections[1].questions[0]
        // Q3 (chưa làm) bị xoá.
        edited.sections[0].questions.remove(at: 2)
        // Q2 (lúc thi chọn A, sai) bỏ lựa chọn đầu: mã lựa chọn đi theo vị trí nên B, C, D cũ thành A, B, C;
        // đáp án đúng còn lại là C cũ (nay là B). Mã "A" giờ trỏ sang nội dung khác.
        let oldOptions = q2.options
        edited.sections[0].questions[1].type = .single
        edited.sections[0].questions[1].options = oldOptions.dropFirst().enumerated().map { index, option in
            Option(id: OptionID(index: index)!, text: option.text)
        }
        edited.sections[0].questions[1].correct = [OptionID("B")!]
        // Q4 chỉ sửa giải thích; Q1 sửa nội dung.
        edited.sections[1].questions[0].explanation = "Giải thích mới"
        edited.sections[0].questions[0].text = "Q1 (sửa)"
        // Đề sửa phải đọc nghiêm được như file thật.
        let workspace = try SessionWorkspace()
        let file = try workspace.write(ExamPackage(exam: edited), to: "edited.exam")
        let strict = try ExamPackageReader.read(contentsOf: file, mode: .strict)
        harness.library.packages[exam.id] = .success(strict)

        let model = ResultsModel.history(attempt, environment: harness.environment)
        let review = try #require(await model.makeAnswerReview())

        #expect(review.rows.map(\.change) == [.edited, .edited, .deleted, .edited, .unchanged])
        #expect(review.rows.map(\.status.title) == ["Đúng", "Sai", "Chưa làm", "Sai", "Đúng"])
        #expect(review.rows[2].preview == "Câu này đã bị xoá khỏi đề")

        let deleted = review.detail(at: 2)
        #expect(deleted.text == nil)
        #expect(deleted.options.isEmpty)
        #expect(deleted.notices == ["Câu này đã bị xoá khỏi đề"])
        #expect(deleted.sectionTitle == "Mạng")

        let editedNotices = ["Câu này đã được sửa sau lần thi", "Không hiện lựa chọn của bạn vì câu đã sửa sau lần thi"]
        let first = review.detail(at: 0)
        #expect(first.text == "Q1 (sửa)")
        #expect(first.notices == editedNotices)
        #expect(first.status.title == "Đúng")

        // Lúc thi đã chọn mã A; nay A là lựa chọn khác: không được đánh dấu "Bạn chọn" nhầm.
        let renumbered = review.detail(at: 1)
        #expect(renumbered.notices == editedNotices)
        #expect(renumbered.status.title == "Sai")
        #expect(renumbered.options.map(\.label) == ["A", "B", "C"])
        #expect(renumbered.options.map(\.text) == oldOptions.dropFirst().map(\.text))
        #expect(renumbered.options.allSatisfy { !$0.isSelected && $0.isCorrectAnswer == nil && $0.marks.isEmpty })

        let explanationOnly = review.detail(at: 3)
        #expect(explanationOnly.notices == editedNotices)
        #expect(explanationOnly.explanation == "Giải thích mới")
        #expect(explanationOnly.options.allSatisfy { $0.marks.isEmpty })

        let unchanged = review.detail(at: 4)
        #expect(unchanged.notices.isEmpty)
        #expect(unchanged.options.contains { $0.marks == ["Bạn chọn", "Đáp án đúng"] })
        #expect(review.practiceIncorrectPreset == .practiceIncorrect(questionIDs: [q2.id, q4.id]))
    }

    @Test("Luyện lại câu sai từ lần cũ: không còn câu sai nào trong đề thì không có")
    func practiceIncorrectAllDeleted() async throws {
        let harness = Harness()
        let attempt = try await savedAttempt(harness)
        var edited = exam
        let wrong = Set([exam.allQuestions[1].id, exam.allQuestions[2].id, exam.allQuestions[3].id])
        for index in edited.sections.indices {
            edited.sections[index].questions.removeAll { wrong.contains($0.id) }
        }
        harness.library.packages[exam.id] = .success(ExamPackage(exam: edited))
        let review = try #require(await ResultsModel.history(attempt, environment: harness.environment).makeAnswerReview())
        #expect(review.practiceIncorrectPreset == nil)
    }

    @Test("Đề nay ẩn đáp án: Xem lại lần cũ không lộ đáp án đúng, giải thích")
    func historyHiddenAnswers() async throws {
        let harness = Harness()
        let attempt = try await savedAttempt(harness)
        var hidden = exam
        hidden.hideAnswers = true
        harness.library.packages[exam.id] = .success(ExamPackage(exam: hidden))
        let review = try #require(await ResultsModel.history(attempt, environment: harness.environment).makeAnswerReview())
        #expect(review.answersHidden)
        #expect((0 ..< 5).allSatisfy { review.detail(at: $0).explanation == nil })
        #expect((0 ..< 5).allSatisfy { review.detail(at: $0).options.allSatisfy { $0.isCorrectAnswer == nil } })

        // Câu đã sửa sau lần thi trên đề ẩn đáp án: cũng không hiện giải thích (phương án 18 chỉ áp khi đề không
        // `hideAnswers`).
        hidden.sections[0].questions[0].explanation = "Giải thích mới"
        harness.library.packages[exam.id] = .success(ExamPackage(exam: hidden))
        let edited = try #require(await ResultsModel.history(attempt, environment: harness.environment).makeAnswerReview())
        #expect(edited.rows.first?.change == .edited)
        #expect(edited.detail(at: 0).explanation == nil)
    }

    @Test("So với lần trước khi mở lần cũ: chỉ lần nộp trước lần đó")
    func historyComparison() async throws {
        let harness = Harness()
        let first = try await savedAttempt(harness)
        harness.clock.advance(60)
        let second = try await savedAttempt(harness)
        harness.clock.advance(60)
        _ = try await savedAttempt(harness)
        #expect(ResultsModel.history(first, environment: harness.environment).comparison == nil)
        #expect(ResultsModel.history(second, environment: harness.environment).comparison?.previousAttemptID == first.id)
    }
}
