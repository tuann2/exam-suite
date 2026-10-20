import XCTest

/// Luồng 2 và 3 (docs/product/overview.md) với đồng hồ phiên thi chạy nhanh (chế độ cô lập,
/// `-ExamSuiteUITestTimeScale`): Thi tính giờ, cảnh báo 5 và 1 phút, Rà soát → Nộp có xác nhận, Kết quả, Xem câu
/// sai, Làm lại; Tạm dừng che câu hỏi, tiếp tục, hết giờ → Rà soát khoá → Nộp. Test luồng 3 còn gồm đóng cửa sổ làm bài khi
/// chưa nộp và ⌘Q khi hộp "Vẫn nộp?" đang mở (mỗi đoạn một activity `XCTContext.runActivity`).
final class ExamFlowUITests: XCTestCase {
    /// Đồng hồ nhanh gấp `timeScale` (giai đoạn 5 bước 10, T4 của notes/g5-ui-test-trung-lap.md; trước là 5×). Luồng 2
    /// thi 6 phút: cảnh báo 5 phút sau `realSeconds(1)`, 1 phút sau `realSeconds(5)`, hết giờ sau `realSeconds(6)` giây
    /// thật, nên Rà soát và nộp còn `realSeconds(1)` giây thật sau cảnh báo 1 phút. Chọn 10× sau 3 lần chạy liền lớp này ở
    /// chế độ cô lập (plan giai đoạn 5, Decisions bước 10): ở 15× (còn 4 giây) bài nộp sau khi hết giờ, phép kiểm Thời gian
    /// làm đỏ cả 3 lần; ở 10× (còn 6 giây) đạt cả 3 lần.
    private let timeScale = 10.0

    /// Giây thật của `minutes` phút trên đồng hồ phiên thi.
    private func realSeconds(_ minutes: Double) -> TimeInterval {
        minutes * 60 / timeScale
    }

    /// Chờ thêm cho mỗi mốc đồng hồ (dựng giao diện, máy bận): mốc đến muộn hơn chừng này giây thật là lỗi.
    private let clockSlack: TimeInterval = 10

    /// Thời gian Thi của test luồng 3: đủ dài để đoạn ⌘Q khi hộp Vẫn nộp? (đồng hồ vẫn chạy; xong sau ~10 giây thật khi
    /// máy rảnh) xong trước khi hết giờ, kèm dư; ở 10× là 24 giây thật (trước: thi 1 phút ở 5× = 12 giây, chưa có đoạn ⌘Q).
    private let pauseTestMinutes = 4

    /// Chờ dải "Đã hết giờ" tính từ khi tiếp tục sau tạm dừng (đồng hồ dừng trong lúc tạm dừng).
    private var timeUpWait: TimeInterval {
        realSeconds(Double(pauseTestMinutes)) + clockSlack
    }

    /// Luồng 2: Thi 20 câu ngẫu nhiên, đánh dấu (⌘D), bỏ qua câu, cảnh báo 5 và 1 phút, Rà soát → Nộp có xác nhận →
    /// Kết quả → Xem câu sai → Kết quả → Làm lại (Trước khi thi điền sẵn lựa chọn cũ).
    @MainActor
    func testTimedExamRandomTwentyFlagSkipWarningsSubmitReviewIncorrectRetake() throws {
        continueAfterFailure = false
        let isolated = try IsolatedApp(for: self, timeScale: timeScale)
        let app = isolated.app
        let flow = StudentFlow(app: app)
        app.launch()
        flow.waitForLibrary()

        flow.openPreExam(Samples.attt)
        flow.typeCandidateName()
        flow.chooseExamMode()
        flow.chooseRandomSelection()
        flow.typeNumber(20, into: "preExam.randomCount")
        flow.typeNumber(6, into: "preExam.timeLimit")
        let summary = app.element("preExam.summary").text
        XCTAssertTrue(summary.contains("20 câu · 6 phút · đậu 70%"), summary)
        flow.start()
        flow.expectQuestion(1, of: 20)
        XCTAssertTrue(app.element("attempt.clock").text.contains("Còn"), app.element("attempt.clock").text)

        // Cảnh báo 5 phút (dải không chặn, tự ẩn).
        flow.expectBanner("Còn 5 phút", within: realSeconds(1) + clockSlack)

        // Câu 1 làm SAI (chọn lựa chọn có nội dung không thuộc tập lựa chọn đúng của đề mẫu): câu được chọn ngẫu nhiên,
        // trước đây chọn A ở câu 1 và B ở câu 3 có lúc trúng cả hai, Kết quả không có câu sai nên không có nút Xem câu sai
        // (UI test PR #42). Câu 2 đánh dấu rồi bỏ qua; câu 3 làm.
        let wrong = try XCTUnwrap(
            flow.wrongOptionLetter(correctTexts: try Samples.atttCorrectOptionTexts()), "Câu 1 không có lựa chọn sai"
        )
        app.press(wrong.lowercased())
        XCTAssertTrue(waitUntil(3) { flow.isSelected(wrong) }, "Phím \(wrong.lowercased()) không chọn lựa chọn \(wrong)")
        app.press(.return)
        flow.expectQuestion(2, of: 20)
        app.press("d", .command)
        XCTAssertTrue(flow.header.waitForText("Đã đánh dấu", within: 3), flow.header.text)
        app.press(.rightArrow)
        flow.expectQuestion(3, of: 20)
        app.press("b")
        XCTAssertTrue(waitUntil(3) { flow.isSelected("B") })
        XCTAssertTrue(flow.navigatorCell(2).text.contains("Đánh dấu"), flow.navigatorCell(2).text)
        XCTAssertTrue(flow.navigatorCell(2).text.contains("Chưa làm"), flow.navigatorCell(2).text)

        // Rà soát & nộp (đồng hồ vẫn chạy): đọc số câu và mở hộp "Vẫn nộp?" trước, rồi chờ cảnh báo 1 phút trong lúc hộp
        // đang mở (dải cảnh báo nằm trên Rà soát, sau hộp, vẫn truy vấn được), để sau cảnh báo chỉ còn một cú bấm Nộp bài
        // trong `realSeconds(1)` giây thật còn lại (T4: trước đây mở Rà soát, đọc số câu, mở hộp đều sau cảnh báo).
        app.press(.return, .command)
        XCTAssertTrue(app.element("review.submit").waitForExistence(timeout: 5))
        XCTAssertEqual(flow.reviewNumber("review.answered"), 2, flow.reviewCount("review.answered"))
        XCTAssertEqual(flow.reviewNumber("review.unanswered"), 18, flow.reviewCount("review.unanswered"))
        XCTAssertEqual(flow.reviewNumber("review.flagged"), 1, flow.reviewCount("review.flagged"))
        app.press(.return)
        XCTAssertTrue(flow.submitConfirmation.waitForExistence(timeout: 5), "Còn câu chưa làm phải hỏi")
        flow.expectBanner("Còn 1 phút", within: realSeconds(5) + clockSlack)
        flow.confirmSubmitInDialog()
        XCTAssertTrue(app.element("results.verdict").text.contains("Trượt"), app.element("results.verdict").text)
        // Nộp trước khi hết giờ (hết giờ là luồng 3): Thời gian làm dưới 6 phút. Đồng hồ nhanh quá thì phép kiểm này đỏ
        // thay vì lặng lẽ thành nộp sau khi hết giờ.
        // Dòng thông tin của Kết quả là chữ tĩnh định danh `results.info`, câu đọc "Thời gian làm, 5 phút 58 giây / 6 phút"
        // nằm ở giá trị (nộp đúng lúc hết giờ: "Thời gian làm, 6 phút / 6 phút").
        let duration = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@ OR value BEGINSWITH %@", "Thời gian làm,", "Thời gian làm,"))
            .firstMatch
        XCTAssertTrue(duration.waitForExistence(timeout: 5), "Kết quả thiếu dòng Thời gian làm")
        XCTAssertTrue(duration.text.contains("Thời gian làm, 5 phút"), "Phải nộp trước khi hết giờ: \(duration.text)")

        // Xem câu sai: bộ lọc Sai (không gồm câu chưa làm). Câu 1 chắc chắn sai nên nút có.
        flow.needsFullKeyboardAccess("Xem câu sai")
        let reviewIncorrect = app.element("results.reviewIncorrect")
        XCTAssertTrue(reviewIncorrect.waitForExistence(timeout: 10), "Kết quả không có nút Xem câu sai")
        XCTAssertTrue(waitUntil(10) { reviewIncorrect.isEnabled }, "Nút Xem câu sai đang tắt")
        reviewIncorrect.click()
        let filter = app.element("answerReview.filter")
        XCTAssertTrue(filter.waitForExistence(timeout: 10))
        let selectedFilter = filter.radioButtons.matching(NSPredicate(format: "value == 1")).firstMatch
        XCTAssertTrue(selectedFilter.text.hasPrefix("Sai"), selectedFilter.text)

        // Về Kết quả → Làm lại: Trước khi thi trên Thư viện, cùng lựa chọn (Thi, 20 câu, 6 phút).
        flow.needsFullKeyboardAccess("Kết quả (thanh công cụ Xem lại bài)")
        app.element("answerReview.results").click()
        flow.expectResults()
        flow.needsFullKeyboardAccess("Làm lại")
        app.element("results.retake").click()
        XCTAssertTrue(app.element("preExam.start").waitForExistence(timeout: 10), "Làm lại không mở Trước khi thi")
        let retakeSummary = app.element("preExam.summary").text
        XCTAssertTrue(retakeSummary.contains("20 câu · 6 phút · đậu 70%"), retakeSummary)
        app.press(.escape)
        XCTAssertTrue(app.element("preExam.start").waitForNonExistence(within: 5), "Esc phải Huỷ Trước khi thi")
    }

    /// Luồng 3 và hai đoạn nối vào (giai đoạn 5 bước 10, T3 của notes/g5-ui-test-trung-lap.md; trước là hai lần mở app riêng
    /// `CloseWindowUITests`, `QuitWhileConfirmingUITests` diễn lại cùng đoạn Thư viện → Trước khi thi → Bắt đầu):
    ///
    /// 1. **Đóng cửa sổ làm bài khi chưa nộp** (docs/product/exam-taking.md, mục Đóng cửa sổ hoặc thoát app khi chưa nộp):
    ///    ⌘W hỏi "Bài chưa nộp sẽ mất. Bỏ bài?"; Return = Tiếp tục làm giữ nguyên bài; Bỏ bài đóng cửa sổ và không lưu gì.
    /// 2. Luồng 3: Thi, ⌘. che câu hỏi (đồng hồ dừng), ⌘. tiếp tục.
    /// 3. **⌘Q khi hộp "Còn N câu chưa làm. Vẫn nộp?" đang mở** (hộp hai nút, chặn thoát theo mặc định của macOS/SwiftUI;
    ///    Nt0 chốt 2026-10-17, plan giai đoạn 5 Decisions; exam-taking.md cùng mục): ⌘Q không tác dụng, hộp còn và dùng
    ///    được, bài giữ nguyên. Review độc lập PR #45 (M1): UI test PR #42 từng thấy một sheet chặn thoát biến mất và mọi
    ///    cửa sổ bị khoá sau ⌘Q, nên khẳng định này phải kiểm trên app thật.
    /// 4. Luồng 3 tiếp: hết giờ → Rà soát khoá (không quay lại, không sửa) → Nộp; ⌘Q sau khi nộp thoát app (không hỏi).
    @MainActor
    func testCloseAsksThenPauseHidesQuestionQuitWhileConfirmingTimeUpLockedReviewSubmit() throws {
        continueAfterFailure = false
        let isolated = try IsolatedApp(for: self, timeScale: timeScale)
        let app = isolated.app
        let flow = StudentFlow(app: app)
        let exam = Samples.lamQuen
        app.launch()
        flow.waitForLibrary()

        XCTContext.runActivity(named: "Đóng cửa sổ làm bài khi chưa nộp (trước là CloseWindowUITests)") { _ in
            closeUnsubmittedAttempt(app: app, flow: flow, exam: exam)
        }

        // Thi `pauseTestMinutes` phút (đồng hồ nhanh). Tên thí sinh đã nhớ từ lần Bắt đầu trước
        // (Bỏ bài không xoá), nên không gõ lại.
        flow.openPreExam(exam)
        XCTAssertEqual(app.element("preExam.candidateName").stringValue, "Hoc vien UI test", "Trước khi thi phải nhớ tên thí sinh")
        flow.chooseExamMode()
        flow.typeNumber(pauseTestMinutes, into: "preExam.timeLimit")
        flow.start()

        // ⌘. ngay: lớp phủ che câu hỏi và lựa chọn; đồng hồ đứng yên.
        app.press(".", .command)
        XCTAssertTrue(app.element("pause.message").waitForExistence(timeout: 5), "⌘. không tạm dừng")
        XCTAssertFalse(app.element("question.header").exists, "Tạm dừng phải che câu hỏi")
        XCTAssertFalse(app.element("option.A").exists, "Tạm dừng phải che lựa chọn")
        let clock = app.element("attempt.clock")
        let pausedAt = clock.text
        Thread.sleep(forTimeInterval: 3) // 3 × timeScale giây của phiên nếu đồng hồ còn chạy (đồng hồ hiện giây)
        XCTAssertEqual(clock.text, pausedAt, "Đồng hồ phải dừng khi tạm dừng")
        // Phím chữ không tác dụng khi tạm dừng.
        app.press("a")

        // ⌘. tiếp tục: câu hỏi hiện lại, chưa có đáp án.
        app.press(".", .command)
        XCTAssertTrue(app.element("question.header").waitForExistence(timeout: 5), "⌘. không tiếp tục")
        XCTAssertFalse(flow.isSelected("A"))
        app.press("a")
        XCTAssertTrue(waitUntil(3) { flow.isSelected("A") })

        XCTContext.runActivity(named: "⌘Q khi hộp Vẫn nộp? đang mở (trước là QuitWhileConfirmingUITests)") { _ in
            quitWhileConfirmingSubmit(app: app, flow: flow, exam: exam)
        }

        // Hết giờ: tự sang Rà soát khoá với dải "Đã hết giờ".
        flow.expectBanner("Đã hết giờ", within: timeUpWait)
        XCTAssertTrue(app.element("review.submit").waitForExistence(timeout: 5))
        XCTAssertFalse(app.element("review.back").exists, "Rà soát khoá không có Quay lại làm bài")
        app.press(.escape)
        XCTAssertTrue(app.element("review.submit").exists, "Esc không được quay lại làm bài khi đã hết giờ")
        XCTAssertFalse(app.element("question.header").exists)
        // Câu 1 (A) và câu 2 (B, chọn sau khi ⌘Q bị từ chối).
        XCTAssertEqual(flow.reviewNumber("review.answered"), 2, flow.reviewCount("review.answered"))

        // Nộp (còn 10 câu chưa làm → hỏi) → Kết quả; ⌘Q thoát app (đã nộp: không hỏi).
        app.press(.return)
        flow.confirmSubmitInDialog()
        XCTContext.runActivity(named: "⌘Q sau khi nộp thoát app (trước là QuitWhileConfirmingUITests)") { _ in
            app.press("q", .command)
            let quitted = waitUntil(10) { app.state == .notRunning }
            if !quitted { flow.dumpTree() }
            XCTAssertTrue(quitted, "⌘Q sau khi nộp phải thoát app")
        }
    }

    /// Luyện tập "Làm quen" (đồng hồ không chạy), câu 1 chọn A, câu 2 đánh dấu; ⌘W hỏi → Return = Tiếp tục làm giữ bài;
    /// ⌘W lần nữa → Bỏ bài: cửa sổ làm bài đóng, Thư viện không có lần thi nào.
    @MainActor
    private func closeUnsubmittedAttempt(app: XCUIApplication, flow: StudentFlow, exam: Samples.Exam) {
        flow.openPreExam(exam)
        flow.typeCandidateName()
        flow.start()

        app.press("a")
        XCTAssertTrue(waitUntil(3) { flow.isSelected("A") })
        app.press(.return)
        flow.expectQuestion(2, of: exam.questionCount)
        app.press("d", .command)

        // ⌘W: hỏi trên cửa sổ làm bài; Return = Tiếp tục làm (mặc định).
        app.press("w", .command)
        let alert = app.sheets.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "Đóng khi chưa nộp phải hỏi")
        XCTAssertTrue(alert.staticTexts["Bài chưa nộp sẽ mất. Bỏ bài?"].exists, alert.debugDescription)
        app.press(.return)
        XCTAssertTrue(alert.waitForNonExistence(within: 5))

        // Bài giữ nguyên: câu 2 đang xem, đã đánh dấu; câu 1 vẫn có đáp án A.
        flow.expectQuestion(2, of: exam.questionCount)
        XCTAssertTrue(flow.header.text.contains("Đã đánh dấu"), flow.header.text)
        app.press(.leftArrow)
        flow.expectQuestion(1, of: exam.questionCount)
        XCTAssertTrue(flow.isSelected("A"), "Tiếp tục làm phải giữ đáp án")

        // ⌘W lần nữa → Bỏ bài: cửa sổ làm bài đóng, Thư viện không có lần thi nào.
        app.press("w", .command)
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        flow.needsFullKeyboardAccess("Bỏ bài")
        alert.buttons["Bỏ bài"].click()
        XCTAssertTrue(flow.header.waitForNonExistence(within: 5), "Bỏ bài phải đóng cửa sổ làm bài")
        let card = app.element(exam.cardID)
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertTrue(card.text.contains("Chưa thi lần nào"), card.text)
    }

    /// Đang Thi ở câu 1 (đã chọn A): ⌘Return → Rà soát; Return → hộp "Vẫn nộp?"; ⌘Q: app không thoát, hộp còn nguyên và bấm
    /// được, không chuyển sang hỏi Bỏ bài; Return = Quay lại → Rà soát; Esc → câu 1 còn A; → câu 2 chọn B (cửa sổ nhận
    /// phím). Đồng hồ vẫn chạy (đồng hồ nhanh), nên đoạn này phải xong trước khi hết giờ (`pauseTestMinutes`).
    @MainActor
    private func quitWhileConfirmingSubmit(app: XCUIApplication, flow: StudentFlow, exam: Samples.Exam) {
        flow.expectQuestion(1, of: exam.questionCount)

        // ⌘Return: Rà soát; Return: Nộp bài → còn câu chưa làm nên hỏi "Vẫn nộp?".
        app.press(.return, .command)
        XCTAssertTrue(app.element("review.submit").waitForExistence(timeout: 5), "⌘Return không mở Rà soát")
        app.press(.return)
        let cancel = app.element("submit.cancel")
        XCTAssertTrue(cancel.waitForExistence(timeout: 5), "Còn câu chưa làm phải hỏi Vẫn nộp?")

        // ⌘Q khi hộp hỏi đang mở: app không thoát, hộp còn nguyên và bấm được, không chuyển sang hỏi Bỏ bài.
        app.press("q", .command)
        Thread.sleep(forTimeInterval: 2)
        if app.state != .runningForeground || !cancel.exists { flow.dumpTree() }
        XCTAssertEqual(app.state, .runningForeground, "⌘Q khi hộp Vẫn nộp? đang mở không được thoát app")
        XCTAssertTrue(cancel.exists, "Hộp Vẫn nộp? phải còn sau ⌘Q")
        XCTAssertTrue(flow.submitConfirmation.exists, "Nút Nộp bài của hộp hỏi phải còn")
        XCTAssertTrue(cancel.isHittable, "Nút Quay lại phải bấm được sau ⌘Q")
        XCTAssertFalse(
            app.staticTexts["Bài chưa nộp sẽ mất. Bỏ bài?"].exists,
            "⌘Q khi hộp Vẫn nộp? đang mở không được hỏi Bỏ bài"
        )

        // Hộp hỏi dùng được: Return = Quay lại (mặc định) → Rà soát; Esc → làm bài tại câu 1, đáp án còn nguyên.
        app.press(.return)
        XCTAssertTrue(cancel.waitForNonExistence(within: 5), "Return phải đóng hộp hỏi (Quay lại)")
        XCTAssertTrue(app.element("review.submit").waitForExistence(timeout: 5), "Quay lại phải về Rà soát")
        app.press(.escape)
        flow.expectQuestion(1, of: exam.questionCount)
        XCTAssertTrue(flow.isSelected("A"), "Bài phải giữ nguyên sau ⌘Q bị từ chối")

        // Cửa sổ làm bài nhận phím: câu 2, chọn B.
        app.press(.rightArrow)
        flow.expectQuestion(2, of: exam.questionCount)
        app.press("b")
        XCTAssertTrue(waitUntil(3) { flow.isSelected("B") }, "Cửa sổ làm bài không nhận phím sau ⌘Q bị từ chối")
    }
}
