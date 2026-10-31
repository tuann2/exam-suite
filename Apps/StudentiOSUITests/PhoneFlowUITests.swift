import XCTest

/// Luồng 1 trên iPhone (docs/product/plan-ios-v1.md Phần 4, I2): Luyện tập đề mẫu "Làm quen" tới Kết quả, Xem lại bài,
/// rồi Luyện lại câu sai. Kiểm trợ năng ở Thư viện, Giới thiệu (I3), Trước khi thi, làm bài, Rà soát & nộp, Kết quả, Xem
/// lại bài.
final class PhonePracticeFlowUITests: XCTestCase {
    @MainActor
    func testPracticeToReviewThenPracticeIncorrect() throws {
        let phone = try PhoneApp(for: self)
        phone.app.launch()
        XCTAssertTrue(phone.row(Samples.lamQuen).waitForExistence(timeout: 30), "Không thấy đề mẫu")
        PhoneAccessibilityAudit.audit(phone.app, screen: "Thư viện")

        // Giới thiệu (QI13): phiên bản và số build của app, toàn văn giấy phép đi kèm app.
        phone.tap("library.sections")
        phone.tap("library.about")
        let version = phone.element("about.version")
        XCTAssertTrue(version.waitForExistence(timeout: 5), "Không mở được Giới thiệu")
        let versionPattern = "Phiên bản [0-9]+\\.[0-9]+\\.[0-9]+ \\([0-9]+\\)"
        XCTAssertTrue(
            NSPredicate(format: "SELF MATCHES %@", versionPattern).evaluate(with: version.label),
            "Giới thiệu phải ghi phiên bản và số build: \(version.label)"
        )
        PhoneAccessibilityAudit.audit(phone.app, screen: "Giới thiệu")
        XCTAssertTrue(phone.element("about.notice").exists, "Giới thiệu phải có NOTICE (file đi kèm app)")
        phone.tap("about.license")
        let apache = phone.app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Apache License")).firstMatch
        XCTAssertTrue(apache.waitForExistence(timeout: 5), "Giới thiệu phải có toàn văn giấy phép Apache-2.0")
        phone.app.navigationBars["Giấy phép Apache 2.0"].buttons.element(boundBy: 0).tap()
        phone.tap("about.thirdParty")
        let zip = phone.app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Thomas Zoechling")).firstMatch
        XCTAssertTrue(zip.waitForExistence(timeout: 5), "Giới thiệu phải có giấy phép của ZIPFoundation")
        phone.app.navigationBars["Thư viện bên thứ ba"].buttons.element(boundBy: 0).tap()
        phone.tap("about.done")

        phone.start(Samples.lamQuen, mode: "Luyện tập", auditPreExam: true)

        // Câu 1 sai (B thay vì A), các câu còn lại đúng.
        PhoneAccessibilityAudit.audit(phone.app, screen: "Làm bài")
        let answers = Samples.lamQuen.answers
        phone.answer("B")
        for (index, letters) in answers.enumerated().dropFirst() {
            phone.answer(letters, next: index < answers.count - 1)
        }
        phone.tap("attempt.review")
        XCTAssertTrue(phone.element("review.submit").waitForExistence(timeout: 10))
        PhoneAccessibilityAudit.audit(phone.app, screen: "Rà soát & nộp")
        phone.tap("review.submit")

        XCTAssertTrue(phone.element("results.verdict").waitForExistence(timeout: 10), "Chưa tới Kết quả")
        PhoneAccessibilityAudit.audit(phone.app, screen: "Kết quả")
        phone.tap("results.review")
        XCTAssertTrue(phone.element("review.filter").waitForExistence(timeout: 10), "Chưa tới Xem lại bài")
        PhoneAccessibilityAudit.audit(phone.app, screen: "Xem lại bài")

        phone.tap("review.practiceIncorrect")
        XCTAssertTrue(phone.element("preExam.start").waitForExistence(timeout: 10), "Luyện lại câu sai không mở Trước khi thi")
        phone.tap("preExam.start")
        XCTAssertTrue(phone.element("attempt.clock").waitForExistence(timeout: 10))
        XCTAssertTrue(phone.app.staticTexts["Câu 1/1"].waitForExistence(timeout: 5), "Luyện lại câu sai phải chỉ có câu sai")
    }
}

/// Luồng 2 trên iPhone: thêm một file `.exam` bằng Thêm đề (hộp chọn file thay bằng file truyền vào): bản chép của đề
/// mẫu "Làm quen" nên Thư viện hỏi Dùng file mới / Huỷ như bản macOS (QI12); rồi Thi 1 phút (gõ vào ô thời gian) trên
/// đồng hồ chạy nhanh, hết giờ thì Rà soát khoá (bảng câu hỏi chỉ để xem), Nộp bài, Kết quả Trượt. Kiểm trợ năng ở Rà
/// soát khoá, bảng câu hỏi, Kết quả.
final class PhoneExamFlowUITests: XCTestCase {
    @MainActor
    func testAddFileThenTimedExamRunsOut() throws {
        let phone = try PhoneApp(for: self, timeScale: 60)
        // Lần mở đầu ghi đề mẫu vào thư mục cô lập; file thêm vào là bản chép của nó (file truyền vào phải có sẵn lúc
        // mở app, nên mở lại).
        phone.app.launch()
        XCTAssertTrue(phone.row(Samples.lamQuen).waitForExistence(timeout: 30), "Không thấy đề mẫu")
        phone.app.terminate()
        try phone.useChosenFile(copying: phone.sampleFile(named: "Làm quen với Exam Suite.exam"), as: "Đề nhận.exam")
        phone.app.launch()
        XCTAssertTrue(phone.row(Samples.lamQuen).waitForExistence(timeout: 30))

        phone.tap("library.add")
        let useNew = phone.app.alerts.buttons["Dùng file mới"]
        XCTAssertTrue(useNew.waitForExistence(timeout: 10), "Cùng đề, khác file phải hỏi Dùng file mới / Huỷ")
        useNew.tap()

        phone.start(Samples.lamQuen, mode: "Thi", minutes: 1, auditPreExam: true)
        // 1 phút ở hệ số 60 là khoảng 1 giây: hết giờ, sang Rà soát khoá (không kịp làm câu nào).
        XCTAssertTrue(phone.element("review.submit").waitForExistence(timeout: 20), "Hết giờ chưa sang Rà soát")
        XCTAssertFalse(phone.element("review.back").exists, "Rà soát khoá không được quay lại làm bài")
        PhoneAccessibilityAudit.audit(phone.app, screen: "Rà soát khoá")
        phone.tap("review.navigator")
        XCTAssertTrue(phone.element("navigator.done").waitForExistence(timeout: 5), "Rà soát phải mở được bảng câu hỏi")
        // Ô đọc "Câu 1, Chưa làm, …" (`NavigatorCell.accessibilityLabel`).
        let firstCell = phone.app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Câu 1,")).firstMatch
        XCTAssertTrue(firstCell.waitForExistence(timeout: 5))
        XCTAssertFalse(firstCell.isEnabled, "Rà soát khoá: bảng câu hỏi chỉ để xem")
        // Ở Rà soát, bảng câu hỏi mở cỡ lớn (cỡ vừa để chữ của màn bên dưới thấy mà không đọc được).
        let done = phone.element("navigator.done")
        XCTAssertLessThan(done.frame.minY, phone.app.frame.height * 0.2, "Bảng câu hỏi ở Rà soát phải mở cỡ lớn")
        PhoneAccessibilityAudit.audit(phone.app, screen: "Bảng câu hỏi (Rà soát khoá)")
        phone.tap("navigator.done")
        phone.tap("review.submit")
        let confirm = phone.element("submit.confirm")
        if confirm.waitForExistence(timeout: 3) { confirm.tap() }
        XCTAssertTrue(phone.element("results.verdict").waitForExistence(timeout: 10), "Chưa tới Kết quả")
        PhoneAccessibilityAudit.audit(phone.app, screen: "Kết quả (Trượt)")
        phone.tap("results.library")
        XCTAssertTrue(phone.row(Samples.lamQuen).waitForExistence(timeout: 10), "Về thư viện chưa thấy Thư viện")
    }
}

/// Luồng 3 trên iPhone: nút Quay lại hỏi "Bỏ bài?" (Tiếp tục làm giữ bài); vuốt từ cạnh trái hay trên nội dung không
/// rời màn làm bài; đang phóng to ảnh mà xuống nền thì Tạm dừng "vì bạn rời app", ảnh đóng theo câu, mở lại vẫn Tạm
/// dừng tới khi bấm Tiếp tục; Bỏ bài thì về Thư viện, không có lần thi.
final class PhoneLeaveAppUITests: XCTestCase {
    @MainActor
    func testBackAsksAndBackgroundPauses() throws {
        let phone = try PhoneApp(for: self)
        phone.app.launch()
        phone.start(Samples.lamQuen, mode: "Luyện tập")

        phone.tap("session.back")
        let keep = phone.app.alerts.buttons["Tiếp tục làm"]
        XCTAssertTrue(keep.waitForExistence(timeout: 5), "Quay lại phải hỏi Bỏ bài?")
        keep.tap()
        XCTAssertTrue(phone.element("attempt.clock").waitForExistence(timeout: 5), "Tiếp tục làm phải giữ bài")

        // Cử chỉ vuốt để quay lại (cạnh trái, và trên nội dung từ iOS 26) bị tắt: không rời bài mà không hỏi.
        for startX in [0.01, 0.3] {
            phone.app.coordinate(withNormalizedOffset: CGVector(dx: startX, dy: 0.5))
                .press(forDuration: 0.05, thenDragTo: phone.app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)))
            XCTAssertTrue(phone.element("attempt.clock").waitForExistence(timeout: 3), "Vuốt không được rời màn làm bài")
            XCTAssertFalse(phone.app.alerts.firstMatch.exists, "Vuốt không hỏi Bỏ bài?")
        }

        // Câu 7 của đề "Làm quen" có ảnh (Luyện tập mặc định không xáo câu): phóng to rồi xuống nền.
        for _ in 1 ..< 7 { phone.tap("attempt.next") }
        phone.tap("question.image")
        XCTAssertTrue(phone.element("zoom.done").waitForExistence(timeout: 5), "Chạm ảnh phải phóng to")

        XCUIDevice.shared.press(.home)
        sleep(2)
        phone.app.activate()
        let message = phone.element("attempt.pauseMessage")
        XCTAssertTrue(message.waitForExistence(timeout: 10), "Xuống nền phải tạm dừng")
        XCTAssertEqual(message.label, "Đã tạm dừng vì bạn rời app")
        XCTAssertFalse(phone.element("zoom.done").exists, "Tạm dừng phải che cả ảnh phóng to")
        PhoneAccessibilityAudit.audit(phone.app, screen: "Tạm dừng")
        phone.tap("attempt.resume")
        XCTAssertTrue(phone.element("question.image").waitForExistence(timeout: 5), "Tiếp tục phải hiện lại câu hỏi")
        XCTAssertFalse(phone.element("zoom.done").exists, "Tiếp tục không mở lại ảnh phóng to")

        phone.tap("session.back")
        phone.tap("session.discard", timeout: 5)
        XCTAssertTrue(phone.row(Samples.lamQuen).waitForExistence(timeout: 10), "Bỏ bài phải về Thư viện")
    }
}
