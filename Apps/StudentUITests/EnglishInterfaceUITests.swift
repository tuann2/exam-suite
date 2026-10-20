import XCTest

/// Giao diện **tiếng Anh** (`-AppleLanguages (en)`; giai đoạn 5 bước 7c, accessibility-localization.md mục Kiểm) trên app
/// thật: Thư viện → Trước khi thi → màn Làm bài (Luyện tập, Kiểm tra đáp án, menu "Attempt") → Rà soát & nộp (⌘Return, không
/// nộp). Tìm phần tử theo định danh;
/// kiểm vài nhãn tiếng Anh và không còn chữ tiếng Việt của giao diện ở mỗi màn (`InterfaceLanguageCheck`; nội dung đề mẫu
/// "Làm quen" là tiếng Việt, không dịch).
///
/// Rút gọn ở giai đoạn 5 bước 10 (T3 của notes/g5-ui-test-trung-lap.md): trước đây test diễn lại cả luồng 1 tới hộp xác
/// nhận, Kết quả, Xem lại bài. Chữ tiếng Anh của các màn đó đã kiểm ở chỗ khác (Rà soát & nộp không có snapshot tiếng Anh
/// nên vẫn kiểm ở đây): snapshot
/// `attemptPracticeEnglish`, `resultsEnglish`, `answerReviewEnglish` (ExamFeaturesSnapshotTests), `LocalizationTests`
/// (câu hỏi "N questions are unanswered. Submit anyway?"), `EnglishResultsReportTests` (PDF kết quả), `check_localization.py
/// --require-en` (mọi khoá có bản `en`). Phần chỉ app thật mới kiểm được (menu của app, ngôn ngữ chọn theo
/// `-AppleLanguages`) vẫn ở đây.
final class EnglishInterfaceUITests: XCTestCase {
    @MainActor
    func testLibraryPreExamAndAttemptInEnglish() throws {
        continueAfterFailure = false
        let isolated = try IsolatedApp(for: self, language: .english)
        let app = isolated.app
        let flow = StudentFlow(app: app, language: .english)
        let check = InterfaceLanguageCheck(app: app)
        let exam = Samples.lamQuen
        app.launch()
        flow.waitForLibrary()

        // Thư viện lần đầu: dải chào mừng, thanh bên, thẻ đề mẫu (câu VoiceOver của thẻ).
        check.expectText("Welcome to Exam Suite")
        check.expectText("All Exams")
        check.expectText("History")
        let card = app.element(exam.cardID).label
        XCTAssertTrue(card.contains("sample exam, code LAMQUEN, 12 questions, Ready"), card)
        check.expectNoVietnamese(on: "Library")

        // Trước khi thi (lần đầu: Practice, mọi câu).
        flow.openPreExam(exam)
        let summary = app.element("preExam.summary").text
        XCTAssertTrue(summary.contains("12 questions · no time limit · passing score 60%"), summary)
        XCTAssertTrue(app.element("preExam.start").text.contains("Start"), app.element("preExam.start").text)
        check.expectNoVietnamese(on: "Before You Start")
        flow.typeCandidateName()
        flow.start()

        // Câu 1: phím A chọn đáp án (giá trị trợ năng "Selected"), ⌘K → Correct; menu Attempt.
        flow.expectQuestion(1, of: exam.questionCount)
        app.press("a")
        XCTAssertTrue(waitUntil(3) { flow.isSelected("A") }, app.element("option.A").stringValue)
        app.press("k", .command)
        XCTAssertTrue(app.element("check.result").waitForText("Correct", within: 3), app.element("check.result").text)
        XCTAssertTrue(app.element("attempt.progress").waitForText("1 of 12 answered", within: 3),
                      app.element("attempt.progress").text)
        check.expectMenu("Attempt", items: ["Previous Question", "Next Question", "Flag", "Check Answer", "Pause",
                                            "Review & Submit", "Submit…"])
        check.expectNoVietnamese(on: "Attempt")

        // Rà soát & nộp (⌘Return): 11 câu chưa làm, nút Submit; không nộp (lần thi bỏ dở, app thoát khi test xong).
        app.press(.return, .command)
        XCTAssertTrue(app.element("review.submit").waitForExistence(timeout: 5), "⌘Return không mở Review & Submit")
        XCTAssertEqual(flow.reviewNumber("review.unanswered"), 11, flow.reviewCount("review.unanswered"))
        XCTAssertTrue(app.element("review.submit").text.contains("Submit"), app.element("review.submit").text)
        check.expectNoVietnamese(on: "Review & Submit")
    }
}
