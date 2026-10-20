import ExamFile
import ExamKit
import Foundation
import LibraryData
@testable import SessionFeature
import Testing

/// Cửa sổ làm bài (docs/product/exam-taking.md: Câu hỏi, Bảng câu hỏi, Thanh công cụ, Kiểm tra đáp án,
/// Tạm dừng, Cảnh báo và hết giờ, Rà soát & nộp, Bàn phím và trợ năng).
@MainActor
@Suite("Làm bài: phím, đồng hồ, cảnh báo, hết giờ, tạm dừng, rà soát, nộp")
struct AttemptModelTests {
    let exam = makeExam(
        sections: [
            SectionSpec(title: "Mạng", questions: [singleQuestion("Q1"), multipleQuestion("Q2"), singleQuestion("Q3")]),
            SectionSpec(title: "Bảo mật", questions: [singleQuestion("Q4", options: 3), singleQuestion("Q5")]),
        ]
    )

    /// Seed đầu tiên làm câu đầu tiên có thứ tự lựa chọn khác thứ tự trong file.
    func shuffledSeed() throws -> UInt64 {
        for seed in UInt64(1) ... 200 {
            let paper = try ExamComposer.compose(exam, options: CompositionOptions(shuffleOptions: true, seed: seed))
            if paper.items[0].optionOrder != exam.allQuestions[0].options.map(\.id) { return seed }
        }
        throw Harness.StartFailed(reason: "không tìm được seed xáo")
    }

    // MARK: - Câu hỏi và phím chữ

    @Test("Phím chữ chọn theo vị trí hiển thị khi xáo đáp án; nhãn A, B… theo vị trí; chữ vượt số lựa chọn bỏ qua")
    func letterKeysFollowDisplayOrder() async throws {
        let harness = Harness()
        harness.seeds.seeds = [try shuffledSeed()]
        let attempt = try await harness.start(exam) { $0.shuffleOptions = true }
        let order = attempt.session.currentItem.optionOrder

        #expect(attempt.displayedOptions.map(\.label) == ["A", "B", "C", "D"])
        #expect(attempt.displayedOptions.map(\.optionID) == order)
        #expect(attempt.displayedOptions.map(\.text) == order.map { id in
            attempt.currentQuestion.options.first { $0.id == id }!.text
        })

        #expect(attempt.handleLetterKey("b"))
        #expect(attempt.session.answers[attempt.currentQuestion.id] == [order[1]])
        #expect(attempt.displayedOptions.map(\.isSelected) == [false, true, false, false])

        #expect(attempt.handleLetterKey("D"))
        #expect(attempt.session.answers[attempt.currentQuestion.id] == [order[3]])

        #expect(!attempt.handleLetterKey("E"))
        #expect(attempt.session.answers[attempt.currentQuestion.id] == [order[3]])
    }

    @Test("Phím không phải một chữ ASCII A–Z (ß, ﬁ, chữ có dấu, số, emoji, rỗng, nhiều ký tự) bị bỏ qua, không crash")
    func nonASCIIKeysIgnored() async throws {
        let attempt = try await Harness().start(exam)
        for key in ["ß", "ﬁ", "é", "Ä", "đ", "1", "", "AB", "🙂", " ", "\u{0410}"] {
            #expect(!attempt.handleLetterKey(key), "phím \(key.debugDescription)")
        }
        for key: Character in ["ß", "ﬁ", "é", "🇻🇳"] {
            #expect(!attempt.handleLetterKey(key), "phím \(key.debugDescription)")
        }
        #expect(attempt.session.answers.isEmpty)
        #expect(AttemptModel.letterPosition("a") == 0)
        #expect(AttemptModel.letterPosition("Z") == 25)
    }

    @Test("Câu nhiều đáp án: phím chữ bật/tắt, gợi ý “Chọn 2 đáp án”; câu một đáp án không có gợi ý")
    func multipleChoiceToggles() async throws {
        let attempt = try await Harness().start(exam)
        #expect(attempt.selectionHint == nil)
        attempt.nextQuestion()
        #expect(attempt.selectionHint == "Chọn 2 đáp án")
        attempt.handleLetterKey("A")
        attempt.handleLetterKey("C")
        #expect(attempt.displayedOptions.map(\.isSelected) == [true, false, true, false])
        attempt.handleLetterKey("a")
        #expect(attempt.displayedOptions.map(\.isSelected) == [false, false, true, false])
        attempt.clearAnswer()
        #expect(attempt.displayedOptions.allSatisfy { !$0.isSelected })
    }

    @Test("Câu 3 lựa chọn: phím D bỏ qua")
    func letterBeyondOptionCount() async throws {
        let attempt = try await Harness().start(exam)
        attempt.goTo(index: 3)
        #expect(attempt.displayedOptions.count == 3)
        #expect(!attempt.handleLetterKey("D"))
        #expect(attempt.handleLetterKey("C"))
    }

    // MARK: - Điều hướng, VoiceOver

    @Test("←/→/Return và bảng câu hỏi; đổi câu thì VoiceOver đọc “Câu 4 trên 5, Phần Bảo mật”")
    func navigationAndAnnouncements() async throws {
        let attempt = try await Harness().start(exam)
        #expect(attempt.questionPositionText == "Câu 1/5")
        #expect(attempt.currentSectionTitle == "Mạng")
        #expect(!attempt.isEnabled(.previousQuestion))
        #expect(attempt.isEnabled(.nextQuestion))
        _ = attempt.takeAnnouncements()

        attempt.perform(.advance)
        #expect(attempt.currentIndex == 1)
        attempt.perform(.nextQuestion)
        attempt.perform(.previousQuestion)
        attempt.goTo(index: 3)
        #expect(attempt.questionPositionText == "Câu 4/5")
        #expect(attempt.currentSectionTitle == "Bảo mật")
        #expect(attempt.takeAnnouncements().map(\.text) == [
            "Câu 2 trên 5, Phần Mạng",
            "Câu 3 trên 5, Phần Mạng",
            "Câu 2 trên 5, Phần Mạng",
            "Câu 4 trên 5, Phần Bảo mật",
        ])
        #expect(attempt.takeAnnouncements().isEmpty)

        attempt.goTo(index: 4)
        #expect(!attempt.isEnabled(.nextQuestion))
        #expect(!attempt.isEnabled(.advance))
        attempt.perform(.advance)
        #expect(attempt.currentIndex == 4)
    }

    @Test("Tên phần dạng “Phần <số>” không đọc lặp chữ “Phần”; “Phần mềm” vẫn thêm")
    func sectionTitleAlreadyPrefixed() async throws {
        let attempt = try await Harness().start(makeExam(counts: [1, 1]))
        _ = attempt.takeAnnouncements()
        attempt.nextQuestion()
        #expect(attempt.takeAnnouncements().map(\.text) == ["Câu 2 trên 2, Phần 2"])

        let software = makeExam(sections: [
            SectionSpec(title: "Phần mềm", questions: [singleQuestion("Q1")]),
            SectionSpec(title: "phần 3: Mạng", questions: [singleQuestion("Q2")]),
        ])
        let second = try await Harness().start(software)
        _ = second.takeAnnouncements()
        second.nextQuestion()
        second.previousQuestion()
        #expect(second.takeAnnouncements().map(\.text) == ["Câu 2 trên 2, phần 3: Mạng", "Câu 1 trên 2, Phần Phần mềm"])
        #expect(!AttemptModel.hasNumberedSectionPrefix("Phần"))
        #expect(!AttemptModel.hasNumberedSectionPrefix("Phầnmềm 2"))
        // Tên mặc định của đề tạo khi giao diện tiếng Anh (bước 7c).
        #expect(AttemptModel.hasNumberedSectionPrefix("Section 2"))
        #expect(AttemptModel.hasNumberedSectionPrefix("section 10: Networking"))
        #expect(!AttemptModel.hasNumberedSectionPrefix("Sections"))
        #expect(!AttemptModel.hasNumberedSectionPrefix("Section A"))
    }

    @Test("Bảng câu hỏi theo phần, Đã làm/Chưa làm/Đánh dấu/Đang xem; tiến độ “Đã làm x/y”")
    func navigatorAndProgress() async throws {
        let attempt = try await Harness().start(exam)
        attempt.answer("B")
        attempt.perform(.toggleFlag)
        #expect(attempt.isCurrentFlagged)
        attempt.goTo(index: 3)
        attempt.perform(.toggleFlag)
        attempt.perform(.toggleFlag)
        attempt.goTo(index: 4)
        attempt.answer("A")

        #expect(attempt.progressText == "Đã làm 2/5")
        let sections = attempt.navigatorSections
        #expect(sections.map(\.title) == ["Mạng", "Bảo mật"])
        #expect(sections.map { $0.cells.map(\.number) } == [[1, 2, 3], [4, 5]])
        let first = sections[0].cells[0]
        #expect(first.isAnswered && first.isFlagged && !first.isCurrent)
        #expect(first.accessibilityLabel == "Câu 1, Đã làm, Đánh dấu")
        #expect(sections[1].cells[0].accessibilityLabel == "Câu 4, Chưa làm")
        #expect(sections[1].cells[1].accessibilityLabel == "Câu 5, Đã làm, Đang xem")
        #expect(Set([first.systemImage, sections[1].cells[0].systemImage, sections[1].cells[1].systemImage]).count == 3)
    }

    @Test("Bảng câu hỏi khi xáo câu: nhóm theo phần của đề, số theo thứ tự phiên")
    func navigatorWithShuffledQuestions() async throws {
        let harness = Harness()
        harness.seeds.seeds = [3]
        let attempt = try await harness.start(exam) { $0.shuffleQuestions = true }
        let numbers = attempt.navigatorSections.flatMap { $0.cells.map(\.number) }
        #expect(numbers.sorted() == [1, 2, 3, 4, 5])
        for section in attempt.navigatorSections {
            for cell in section.cells {
                #expect(attempt.session.paper.items[cell.index].sectionID == section.id)
            }
        }
    }

    // MARK: - Đồng hồ

    @Test("Đồng hồ Thi: đếm ngược mm:ss, ba mức; cảnh báo 5 và 1 phút đúng một lần (dải + VoiceOver ưu tiên cao)")
    func examClockWarnings() async throws {
        let harness = Harness()
        let attempt = try await harness.start(exam, mode: .exam) { $0.timeLimitMinutes = 10 }
        #expect(attempt.clockDisplay.text == "10:00")
        #expect(attempt.clockDisplay.level == .normal)
        #expect(attempt.clockDisplay.isCountdown)
        _ = attempt.takeAnnouncements()

        harness.clock.advance(4 * 60 + 59.5)
        attempt.tick()
        #expect(attempt.clockDisplay.text == "05:01")
        #expect(attempt.banner == nil)

        harness.clock.advance(0.5)
        attempt.tick()
        #expect(attempt.clockDisplay.text == "05:00")
        #expect(attempt.clockDisplay.level == .warning)
        #expect(attempt.clockDisplay.accessibilityLabel == "Còn 5 phút")
        let warning = try #require(attempt.banner)
        #expect(warning.message == "Còn 5 phút")
        #expect(warning.kind == .timeWarning(minutesLeft: 5))
        #expect(warning.autoDismisses)
        let spoken = attempt.takeAnnouncements()
        #expect(spoken.map(\.text) == ["Còn 5 phút"])
        #expect(spoken.map(\.priority) == [.high])

        // Tick tiếp không phát lại.
        attempt.dismissBanner(id: warning.id)
        harness.clock.advance(30)
        attempt.tick()
        #expect(attempt.banner == nil)

        harness.clock.advance(3 * 60 + 30)
        attempt.tick()
        #expect(attempt.clockDisplay.text == "01:00")
        #expect(attempt.clockDisplay.level == .urgent)
        #expect(attempt.banner?.message == "Còn 1 phút")
        attempt.tick()
        #expect(attempt.phase == .inProgress)
    }

    @Test("Cảnh báo đọc VoiceOver đúng một lần mỗi mốc, ưu tiên cao")
    func warningAnnouncementsOnce() async throws {
        let harness = Harness()
        let attempt = try await harness.start(exam, mode: .exam) { $0.timeLimitMinutes = 10 }
        _ = attempt.takeAnnouncements()
        for _ in 0 ..< 20 {
            harness.clock.advance(30)
            attempt.tick()
        }
        let texts = attempt.takeAnnouncements().filter { $0.priority == .high }.map(\.text)
        #expect(texts == ["Còn 5 phút", "Còn 1 phút", "Đã hết giờ. Xem lại rồi bấm Nộp bài"])
    }

    @Test("Tick thưa nhảy qua cả hai mốc: phát 5 rồi 1 phút")
    func sparseTickWarnings() async throws {
        let harness = Harness()
        let attempt = try await harness.start(exam, mode: .exam) { $0.timeLimitMinutes = 10 }
        _ = attempt.takeAnnouncements()
        harness.clock.advance(9 * 60 + 30)
        attempt.tick()
        #expect(attempt.takeAnnouncements().map(\.text) == ["Còn 5 phút", "Còn 1 phút"])
        #expect(attempt.banner?.message == "Còn 1 phút")
    }

    @Test("Từ 60 phút trở lên đồng hồ là h:mm:ss; dưới 60 phút là mm:ss")
    func longClockFormat() async throws {
        let harness = Harness()
        let attempt = try await harness.start(exam, mode: .exam) { $0.timeLimitMinutes = 90 }
        #expect(attempt.clockDisplay.text == "1:30:00")
        harness.clock.advance(30 * 60)
        attempt.tick()
        #expect(attempt.clockDisplay.text == "1:00:00")
        harness.clock.advance(1)
        attempt.tick()
        #expect(attempt.clockDisplay.text == "59:59")
        #expect(SessionFormat.clock(seconds: 3600 * 10 + 61) == "10:01:01")
        #expect(SessionFormat.clock(seconds: 5) == "00:05")
    }

    @Test("Luyện tập: hiện thời gian đã làm, không đếm ngược, không cảnh báo")
    func practiceClock() async throws {
        let harness = Harness()
        let attempt = try await harness.start(exam, mode: .practice)
        #expect(attempt.clockDisplay.text == "00:00")
        #expect(!attempt.clockDisplay.isCountdown)
        _ = attempt.takeAnnouncements()
        harness.clock.advance(75.9)
        attempt.tick()
        #expect(attempt.clockDisplay.text == "01:15")
        #expect(attempt.clockDisplay.accessibilityLabel == "Đã làm 1 phút 15 giây")
        harness.clock.advance(3 * 3600)
        attempt.tick()
        #expect(attempt.clockDisplay.text == "3:01:15")
        #expect(attempt.clockDisplay.level == .normal)
        #expect(attempt.banner == nil)
        #expect(attempt.takeAnnouncements().isEmpty)
    }

    @Test("Chỉnh giờ máy không đổi đồng hồ (lấy theo uptime của phiên)")
    func wallClockChangeIgnored() async throws {
        let harness = Harness()
        let attempt = try await harness.start(exam, mode: .exam) { $0.timeLimitMinutes = 10 }
        harness.clock.shiftWallClock(-3600)
        attempt.tick()
        #expect(attempt.clockDisplay.text == "10:00")
    }

    // MARK: - Hết giờ

    @Test("Hết giờ phát hiện bằng tick: chuyển ngay sang Rà soát khoá, dải “Đã hết giờ…”, VoiceOver đọc")
    func timeUpByTick() async throws {
        let harness = Harness()
        let attempt = try await harness.start(exam, mode: .exam) { $0.timeLimitMinutes = 1 }
        _ = attempt.takeAnnouncements()
        harness.clock.advance(61)
        attempt.tick()

        #expect(attempt.phase == .reviewing(locked: true))
        #expect(attempt.banner?.kind == .timeUp)
        #expect(attempt.banner?.message == "Đã hết giờ. Xem lại rồi bấm Nộp bài")
        #expect(attempt.banner?.autoDismisses == false)
        #expect(attempt.takeAnnouncements().map(\.text) == ["Đã hết giờ. Xem lại rồi bấm Nộp bài"])
        #expect(attempt.clockDisplay.text == "00:00")
        #expect(attempt.clockDisplay.level == .urgent)
        let review = try #require(attempt.reviewSummary)
        #expect(review.isLocked)
        #expect(!review.canReturnToAttempt)
        #expect(!attempt.isEnabled(.returnToAttempt))
        #expect(!attempt.isEnabled(.togglePause))
        #expect(attempt.isEnabled(.submit))
        #expect(!attempt.returnToAttempt(at: 0))
        #expect(attempt.phase == .reviewing(locked: true))
        // Không tự nộp.
        #expect(attempt.submission == nil)
        #expect(harness.library.storedAttempts.isEmpty)
    }

    @Test("Hết giờ phát hiện qua lệnh bị từ chối (chọn đáp án): vẫn sang Rà soát khoá ngay, đáp án không đổi")
    func timeUpByRejectedCommand() async throws {
        let harness = Harness()
        let attempt = try await harness.start(exam, mode: .exam) { $0.timeLimitMinutes = 1 }
        attempt.answer("A")
        harness.clock.advance(120)

        #expect(!attempt.answer("B"))

        #expect(attempt.phase == .reviewing(locked: true))
        #expect(attempt.session.answers[attempt.session.paper.items[0].questionID] == [OptionID("A")!])
        #expect(attempt.banner?.kind == .timeUp)
    }

    @Test("Hết giờ phát hiện qua ⌘Return (openReview bị từ chối với phase .timeUp): vẫn sang Rà soát khoá")
    func timeUpByOpenReview() async throws {
        let harness = Harness()
        let attempt = try await harness.start(exam, mode: .exam) { $0.timeLimitMinutes = 1 }
        harness.clock.advance(60)
        attempt.perform(.openReview)
        #expect(attempt.phase == .reviewing(locked: true))
        #expect(attempt.reviewSummary?.isLocked == true)
    }

    @Test("Hết giờ khi đang Rà soát chưa khoá: sang Rà soát khoá")
    func timeUpDuringReview() async throws {
        let harness = Harness()
        let attempt = try await harness.start(exam, mode: .exam) { $0.timeLimitMinutes = 2 }
        attempt.openReview()
        #expect(attempt.reviewSummary?.isLocked == false)
        harness.clock.advance(200)
        attempt.tick()
        #expect(attempt.phase == .reviewing(locked: true))
    }

    // MARK: - Tạm dừng

    @Test("Tạm dừng (⌘.): che nội dung, đồng hồ dừng, lệnh làm bài bị từ chối; Tiếp tục hiện lại")
    func pauseAndResume() async throws {
        let harness = Harness()
        let attempt = try await harness.start(exam, mode: .exam) { $0.timeLimitMinutes = 10 }
        harness.clock.advance(60)
        attempt.answer("B")
        attempt.toggleFlag()
        attempt.perform(.togglePause)

        #expect(attempt.phase == .paused)
        #expect(!attempt.isContentVisible)
        #expect(attempt.pauseMessage == "Đã tạm dừng")
        #expect(attempt.pauseCommandTitle == "Tiếp tục")
        #expect(!attempt.isEnabled(.toggleFlag))
        #expect(!attempt.isEnabled(.nextQuestion))
        #expect(!attempt.isEnabled(.openReview))
        #expect(attempt.isEnabled(.togglePause))
        #expect(!attempt.answer("A"))

        harness.clock.advance(3600)
        attempt.tick()
        #expect(attempt.clockDisplay.text == "09:00")
        // Bảng câu hỏi chỉ hiện số ô.
        let cells = attempt.navigatorSections.flatMap(\.cells)
        #expect(cells.allSatisfy { $0.isStateHidden && !$0.isAnswered && !$0.isFlagged && !$0.isCurrent })
        #expect(cells.map(\.accessibilityLabel) == ["Câu 1", "Câu 2", "Câu 3", "Câu 4", "Câu 5"])

        attempt.perform(.togglePause)
        #expect(attempt.phase == .inProgress)
        #expect(attempt.isContentVisible)
        #expect(attempt.pauseMessage == nil)
        #expect(attempt.navigatorSections[0].cells[0].accessibilityLabel == "Câu 1, Đã làm, Đánh dấu, Đang xem")
        #expect(attempt.pauseCommandTitle == "Tạm dừng")
    }

    @Test("Máy ngủ: tự tạm dừng “Đã tạm dừng vì máy ngủ”, giờ ngủ không bị trừ, thức dậy vẫn tạm dừng")
    func systemSleep() async throws {
        let harness = Harness()
        let attempt = try await harness.start(exam, mode: .exam) { $0.timeLimitMinutes = 10 }
        attempt.systemWillSleep()
        #expect(attempt.phase == .paused)
        #expect(attempt.pauseMessage == "Đã tạm dừng vì máy ngủ")
        harness.clock.advance(8 * 3600)
        attempt.tick()
        #expect(attempt.phase == .paused)
        #expect(attempt.clockDisplay.text == "10:00")
        attempt.resume()
        #expect(attempt.phase == .inProgress)
    }

    @Test("Tạm dừng được ở Rà soát chưa khoá và quay về đúng Rà soát; Rà soát khoá thì máy ngủ không đổi gì")
    func pauseInReview() async throws {
        let harness = Harness()
        let attempt = try await harness.start(exam, mode: .exam) { $0.timeLimitMinutes = 1 }
        attempt.openReview()
        #expect(attempt.isEnabled(.togglePause))
        attempt.togglePause()
        #expect(attempt.phase == .paused)
        attempt.togglePause()
        #expect(attempt.phase == .reviewing(locked: false))

        harness.clock.advance(90)
        attempt.tick()
        attempt.systemWillSleep()
        #expect(attempt.phase == .reviewing(locked: true))
    }

    // MARK: - Kiểm tra đáp án

    @Test("Kiểm tra đáp án (Luyện tập): bật khi có đáp án; Đúng/Sai từng lựa chọn, “Chưa đúng”, giải thích, khoá đáp án")
    func checkAnswerPractice() async throws {
        let attempt = try await Harness().start(exam, mode: .practice)
        #expect(!attempt.isEnabled(.checkAnswer))
        attempt.answer("C")
        #expect(attempt.isEnabled(.checkAnswer))
        _ = attempt.takeAnnouncements()

        attempt.perform(.checkAnswer)

        #expect(attempt.isCurrentLocked)
        #expect(!attempt.isEnabled(.checkAnswer))
        #expect(attempt.displayedOptions.map(\.checkMark) == [nil, .correct, .incorrect, nil])
        #expect(attempt.displayedOptions[1].checkMark?.title == "Đúng")
        #expect(attempt.displayedOptions[2].checkMark?.title == "Sai")
        let check = try #require(attempt.currentCheck)
        #expect(!check.isCorrect)
        #expect(check.resultText == "Chưa đúng")
        #expect(check.explanation == "Giải thích")
        #expect(attempt.takeAnnouncements().map(\.text) == ["Chưa đúng"])
        #expect(!attempt.answer("B"))
        #expect(attempt.isEnabled(.toggleFlag))

        attempt.nextQuestion()
        #expect(attempt.currentCheck == nil)
        attempt.answer("A")
        attempt.answer("C")
        attempt.checkAnswer()
        #expect(attempt.currentCheck?.resultText == "Đúng")
        #expect(attempt.displayedOptions.map(\.checkMark) == [.correct, nil, .correct, nil])
    }

    @Test("Kiểm tra đáp án không có ở Thi")
    func checkAnswerExam() async throws {
        let attempt = try await Harness().start(exam, mode: .exam)
        attempt.answer("B")
        #expect(!attempt.isEnabled(.checkAnswer))
        #expect(!attempt.checkAnswer())
        #expect(attempt.currentCheck == nil)
    }

    // MARK: - Rà soát

    @Test("Rà soát: ba số, danh sách chưa làm/đánh dấu, quay lại tới câu; xác nhận “Còn 3 câu chưa làm. Vẫn nộp?”")
    func reviewSummaryAndReturn() async throws {
        let harness = Harness()
        let attempt = try await harness.start(exam)
        attempt.answer("B")
        attempt.toggleFlag()
        attempt.goTo(index: 2)
        attempt.answer("A")
        attempt.goTo(index: 4)
        attempt.toggleFlag()
        attempt.perform(.openReview)

        let review = try #require(attempt.reviewSummary)
        #expect(review.answeredCount == 2)
        #expect(review.unansweredCount == 3)
        #expect(review.flaggedCount == 2)
        #expect(review.unansweredIndices == [1, 3, 4])
        #expect(review.flaggedIndices == [0, 4])
        #expect(review.canReturnToAttempt)
        #expect(review.submitConfirmationMessage == "Còn 3 câu chưa làm. Vẫn nộp?")
        #expect(attempt.isEnabled(.returnToAttempt))
        #expect(!attempt.isEnabled(.toggleFlag))

        // Đồng hồ vẫn chạy khi rà soát chưa khoá.
        harness.clock.advance(60)
        attempt.tick()
        #expect(attempt.clockDisplay.text == "29:00")

        attempt.returnToAttempt(at: 3)
        #expect(attempt.phase == .inProgress)
        #expect(attempt.currentIndex == 3)
        #expect(attempt.reviewSummary == nil)

        attempt.openReview()
        attempt.perform(.returnToAttempt)
        #expect(attempt.phase == .inProgress)
        #expect(attempt.currentIndex == 3)
    }

    @Test("Nộp khi còn câu chưa làm: hỏi trước; Quay lại thì không nộp; Nộp bài thì nộp")
    func submitConfirmation() async throws {
        let harness = Harness()
        let attempt = try await harness.start(exam)
        attempt.openReview()

        #expect(attempt.requestSubmit() == nil)
        #expect(attempt.isConfirmingSubmit)
        #expect(attempt.phase == .reviewing(locked: false))
        attempt.cancelSubmit()
        #expect(!attempt.isConfirmingSubmit)
        #expect(attempt.submission == nil)

        attempt.perform(.submit)
        #expect(attempt.isConfirmingSubmit)
        let submission = try #require(attempt.submit())
        #expect(!attempt.isConfirmingSubmit)
        #expect(attempt.isSubmitted)
        #expect(submission.attempt.correct == 0)
        // Nộp lần nữa không lưu thêm.
        #expect(attempt.submit() == submission)
        #expect(harness.library.storedAttempts.count == 1)
    }

    @Test("Hết giờ đúng lúc đang hỏi xác nhận nộp: sang Rà soát khoá, hộp vẫn hỏi; Quay lại vẫn khoá, Nộp bài thì nộp")
    func timeUpWhileConfirmingSubmit() async throws {
        let harness = Harness()
        let attempt = try await harness.start(exam, mode: .exam) { $0.timeLimitMinutes = 1 }
        attempt.answer("B")
        attempt.openReview()
        #expect(attempt.requestSubmit() == nil)
        #expect(attempt.isConfirmingSubmit)

        harness.clock.advance(61)
        attempt.tick()
        #expect(attempt.phase == .reviewing(locked: true))
        #expect(attempt.isConfirmingSubmit)
        #expect(attempt.reviewSummary?.submitConfirmationMessage == "Còn 4 câu chưa làm. Vẫn nộp?")

        attempt.cancelSubmit()
        #expect(attempt.phase == .reviewing(locked: true))
        #expect(attempt.submission == nil)
        #expect(attempt.requestSubmit() == nil)
        let submission = try #require(attempt.submit())
        #expect(submission.attempt.elapsedSeconds == 60)
        #expect(harness.library.storedAttempts.count == 1)
    }

    @Test("Không còn câu chưa làm: nộp luôn, không hỏi")
    func submitWithoutConfirmation() async throws {
        let attempt = try await Harness().start(exam)
        for index in 0 ..< attempt.questionCount {
            attempt.goTo(index: index)
            attempt.answerCorrectly()
        }
        attempt.openReview()
        #expect(attempt.reviewSummary?.submitConfirmationMessage == nil)
        let submission = try #require(attempt.requestSubmit())
        #expect(!attempt.isConfirmingSubmit)
        #expect(submission.attempt.correct == 5)
    }

    @Test("Menu Bài thi: lệnh bật/tắt theo trạng thái")
    func menuAvailability() async throws {
        let practice = try await Harness().start(exam, mode: .practice)
        #expect(practice.isEnabled(.toggleFlag))
        #expect(practice.isEnabled(.openReview))
        #expect(!practice.isEnabled(.returnToAttempt))
        #expect(!practice.isEnabled(.submit))
        #expect(practice.isEnabled(.toggleNavigator))
        practice.perform(.toggleNavigator)
        #expect(!practice.isNavigatorVisible)
        practice.perform(.toggleNavigator)
        #expect(practice.isNavigatorVisible)

        practice.openReview()
        #expect(!practice.isEnabled(.openReview))
        #expect(practice.isEnabled(.submit))
        #expect(!practice.isEnabled(.nextQuestion))
        practice.submit()
        for command in AttemptCommand.allCases {
            #expect(!practice.isEnabled(command), "\(command) sau khi nộp")
        }
    }

    // MARK: - Nộp và lưu

    @Test("Nộp: lưu Attempt + payload AttemptRecord, dấu vân tay từ đề lúc thi; VoiceOver đọc kết quả")
    func submitSaves() async throws {
        let harness = Harness(candidateName: "Phạm Dũng")
        let attempt = try await harness.start(exam, mode: .exam)
        attempt.answerCorrectly()
        attempt.nextQuestion()
        attempt.answerWrongly()
        harness.clock.advance(125)
        _ = attempt.takeAnnouncements()

        let submission = try #require(attempt.submitNow())

        #expect(submission.saveError == nil)
        let saved = try #require(harness.library.storedAttempts.first)
        #expect(saved == submission.attempt)
        #expect(saved.id == harness.attemptIDs.first)
        #expect(saved.examID == exam.id)
        #expect(saved.examTitle == "Kiến thức chung")
        #expect(saved.candidateName == "Phạm Dũng")
        #expect(saved.mode == .exam)
        #expect(saved.elapsedSeconds == 125)
        #expect(saved.submittedAt == saved.startedAt.addingTimeInterval(125))
        #expect(saved.correct == 1)
        #expect(saved.total == 5)
        #expect(saved.score1000 == 200)
        #expect(saved.percent == 20)
        #expect(!saved.passed)

        let record = try AttemptRecord.decode(try #require(harness.library.payloads[saved.id]))
        #expect(record == submission.record)
        #expect(record.paper == attempt.session.paper)
        #expect(record.timeLimitMinutes == 30)
        let expected = QuestionFingerprint.fingerprints(of: exam)
        #expect(record.fingerprints == expected.filter { record.paper.questionIDs.contains($0.key) })
        #expect(attempt.takeAnnouncements().map(\.text) == ["Đã nộp bài. Trượt, 20%."])
    }

    @Test("Lưu thất bại: vẫn có kết quả, kèm thông báo lỗi")
    func submitSaveFailure() async throws {
        let harness = Harness()
        harness.library.failSaving = true
        let attempt = try await harness.start(exam)
        let submission = try #require(attempt.submitNow())
        #expect(submission.saveError == "Không lưu được lần thi vào Lịch sử thi: Không lưu được thư viện: đĩa đầy")
        #expect(submission.record != nil)
        #expect(attempt.isSubmitted)
        #expect(harness.library.storedAttempts.isEmpty)
    }

    @Test("Tiêu đề cửa sổ: tên đề, chế độ")
    func windowTitle() async throws {
        let attempt = try await Harness().start(exam, mode: .practice)
        #expect(attempt.windowTitle == "Kiến thức chung — Luyện tập")
    }
}
