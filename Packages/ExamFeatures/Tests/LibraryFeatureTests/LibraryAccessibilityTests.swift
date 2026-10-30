import Foundation
@testable import InterfaceCore
import LibraryData
@testable import LibraryFeature
import Testing

/// Câu đọc VoiceOver của Thư viện ngoài câu tóm tắt của thẻ (`PresentationTests.cardSummary`): hành động trợ năng của thẻ
/// như menu chuột phải, chữ từng ô của một dòng Lịch sử thi (docs/product/accessibility-localization.md, Mục tiêu phủ theo
/// màn; plan giai đoạn 5 bước 8b).
@MainActor
@Suite("Thư viện: hành động trợ năng của thẻ, câu đọc của Lịch sử thi")
struct LibraryAccessibilityTests {
    @Test("Hành động trợ năng của thẻ như menu chuột phải, bỏ mục bị tắt; bản Admin thêm Sửa")
    func cardActions() {
        let ready = PresentationTests.entry(title: "Đề", code: "A", questions: 3, status: .ready)
        #expect(ExamActions(previewing: ready, isAdmin: false).accessibilityActions.map(\.title) == [
            "Luyện tập", "Thi", "Thông tin", "Hiện trong Finder", "Xem lịch sử thi", "Xoá khỏi thư viện",
        ])
        #expect(ExamActions(previewing: ready, isAdmin: true).accessibilityActions.map(\.title) == [
            "Luyện tập", "Thi", "Thông tin", "Hiện trong Finder", "Xem lịch sử thi", "Sửa", "Xoá khỏi thư viện",
        ])
        // Mất file: không Luyện tập/Thi (đề chưa Sẵn sàng), không Hiện trong Finder; có Tìm file….
        let missing = PresentationTests.entry(title: "Đề", code: nil, questions: 3, status: .missing)
        #expect(ExamActions(previewing: missing, isAdmin: false).accessibilityActions.map(\.title) == [
            "Thông tin", "Xem lịch sử thi", "Tìm file…", "Xoá khỏi thư viện",
        ])
    }

    @Test("Một dòng Lịch sử thi đọc ngày giờ, đề, thí sinh, chế độ, điểm, thang 1000, đậu/trượt, thời gian làm bằng chữ")
    func historyRow() {
        var attempt = PresentationTests.attempt(percent: 85, passed: true)
        attempt.elapsedSeconds = 725
        let cells = LibraryAccessibility.historyRowCells(
            attempt, locale: PresentationTests.vietnamese, timeZone: PresentationTests.utc
        )
        #expect(cells == [
            LibraryFormat.dateTime(attempt.submittedAt, locale: PresentationTests.vietnamese, timeZone: PresentationTests.utc),
            "Đề", "An", "Thi", "85%", "850/1000", "Đậu", "12 phút 5 giây",
        ])
        #expect(cells[0] == "8:30 15/10/2026")
        // Thang 1000 luôn số trơn (không "1.000/1.000").
        #expect(LibraryAccessibility.scale1000Label(1000) == "1000/1000")
        var failed = PresentationTests.attempt(percent: 40, passed: false)
        failed.mode = .practice
        let failedCells = LibraryAccessibility.historyRowCells(
            failed, locale: PresentationTests.vietnamese, timeZone: PresentationTests.utc
        )
        #expect(Array(failedCells[3...6]) == ["Luyện tập", "40%", "400/1000", "Trượt"])
    }

    @Test("Bảng Lịch sử thi định dạng chữ của mỗi dòng một lần, ô lấy đúng cột của dòng đó")
    func historyCellsComputedOncePerRow() {
        let passed = PresentationTests.attempt(percent: 85, passed: true)
        var failed = PresentationTests.attempt(percent: 40, passed: false)
        failed.mode = .practice
        let cells = HistoryView.cells(of: [passed, failed])
        #expect(cells.count == 2)
        #expect(cells[passed.id] == LibraryAccessibility.historyRowCells(passed))
        #expect(cells[failed.id] == LibraryAccessibility.historyRowCells(failed))
        #expect(HistoryView.cell(failed, .mode, in: cells) == "Luyện tập")
        #expect(HistoryView.cell(passed, .result, in: cells) == "Đậu")
        // Dòng không có trong bảng đã dựng (không xảy ra trong app): dựng lại chữ của dòng đó.
        #expect(HistoryView.cell(failed, .percent, in: [:]) == "40%")
    }
}
