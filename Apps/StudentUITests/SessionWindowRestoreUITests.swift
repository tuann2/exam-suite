import XCTest

/// Cửa sổ làm bài **không** dùng khung đã lưu, kể cả khung có trạng thái xếp lát của macOS 26 (`TiledWindow`; plan giai
/// đoạn 5, bước 8a, review độc lập #53 S1). Nguyên nhân là `.restorationBehavior(.disabled)` của scene
/// `SessionWindowScene` (SessionWindowView.swift): với `-NSWindow Frame session` cửa sổ mở ở cỡ mặc định 1180×780 (log
/// `verify_local.sh --uitest` trên 7836992); thử nghiệm 2026-10-18 (re-review #53, commit thử `20120bf` chỉ bỏ modifier
/// này) thì cửa sổ dùng khung xếp lát đã lưu (0, 30, 1352×783) và test này đỏ. Nhờ modifier đó, lỗi Thư viện trống của #48
/// (khôi phục khung xếp lát) không xảy ra ở cửa sổ làm bài; test giữ modifier: bỏ nó thì test đỏ, khi đó phải có UI test
/// xếp lát thật như `LibraryWindowRestoreUITests`.
///
/// Phần sau là kiểm bố cục chung (không phải cửa sổ xếp lát): làm bài khi dải "Còn 5 phút" đang hiện (chữ nhiều dòng ngoài
/// vùng cuộn), Rà soát, Kết quả, Xem lại bài; phần tử chính nằm trong cửa sổ. Chữ nhiều dòng ở độ rộng ~0 được kiểm bằng
/// `TiledWindowLayoutTests` (swift test). Đồng hồ phiên thi chạy nhanh (`-ExamSuiteUITestTimeScale`).
final class SessionWindowRestoreUITests: XCTestCase {
    /// Đồng hồ nhanh gấp 10: Thi 6 phút; cảnh báo 5 phút sau ~6 giây thật, hết giờ sau ~36 giây.
    private let timeScale = 10.0

    @MainActor
    func testSessionWindowIgnoresSavedTiledFrameAndKeepsContentInside() throws {
        continueAfterFailure = false
        let isolated = try IsolatedApp(for: self, timeScale: timeScale)
        let app = isolated.app
        let flow = StudentFlow(app: app)
        app.launchArguments += TiledWindow.launchArguments(autosaveName: "session")
        app.launch()
        flow.waitForLibrary()

        flow.openPreExam(Samples.attt)
        flow.typeCandidateName()
        flow.chooseExamMode()
        flow.typeNumber(6, into: "preExam.timeLimit")
        flow.start()
        let window = app.windows["session"]
        XCTAssertTrue(window.waitForExistence(timeout: 5), "Không thấy cửa sổ làm bài (định danh session)")
        // Khung xếp lát đã lưu không được áp (`.restorationBehavior(.disabled)`; thử nghiệm 2026-10-18).
        let restored = TiledWindow.logRestoredFrame(of: window, name: "session")
        XCTAssertFalse(restored, "Cửa sổ làm bài đã dùng khung xếp lát đã lưu \(window.frame): còn .restorationBehavior(.disabled)?")
        XCTAssertGreaterThan(
            abs(window.frame.width - TiledWindow.size.width), 2,
            "Cửa sổ làm bài rộng đúng như khung xếp lát đã lưu (\(TiledWindow.size.width) pt)"
        )

        // Bố cục chung. Làm bài, dải "Còn 5 phút" đang hiện (tự ẩn sau 6 giây): kiểm ngay các phần tử luôn có.
        flow.expectBanner("Còn 5 phút", within: 20)
        TiledWindow.assertInside(flow.header, window, "đầu câu")
        TiledWindow.assertInside(app.element("option.A"), window, "lựa chọn A")
        TiledWindow.assertInside(app.element("attempt.review"), window, "nút Rà soát & nộp (thanh dưới)")
        TiledWindow.assertInside(flow.navigatorCell(1), window, "ô 1 của bảng câu hỏi")

        // Rà soát → Nộp bài (còn câu chưa làm: hộp xác nhận) → Kết quả.
        app.press(.return, .command)
        XCTAssertTrue(app.element("review.submit").waitForExistence(timeout: 5))
        TiledWindow.assertInside(app.element("review.submit"), window, "nút Nộp bài của Rà soát")
        app.press(.return)
        flow.confirmSubmitInDialog()
        TiledWindow.assertInside(app.element("results.verdict"), window, "Đậu/Trượt của Kết quả")
        TiledWindow.assertInside(app.element("results.review"), window, "nút Xem lại bài")
        TiledWindow.assertInside(app.element("results.exportPDF"), window, "nút Xuất PDF…")

        // Xem lại bài (Return là nút mặc định của Kết quả).
        app.press(.return)
        XCTAssertTrue(app.element("answerReview.position").waitForExistence(timeout: 10), "Không mở Xem lại bài")
        TiledWindow.assertInside(app.element("answerReview.list"), window, "danh sách câu của Xem lại bài")
        TiledWindow.assertInside(app.element("answerReview.next"), window, "nút Câu sau của Xem lại bài")
        TiledWindow.assertInside(app.element("answerReview.position"), window, "vị trí câu của Xem lại bài")
    }
}
