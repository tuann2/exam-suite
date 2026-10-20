import AppKit
@testable import AuthoringFeature
import Foundation
import Testing

/// Câu VoiceOver của cửa sổ soạn đề (docs/product/accessibility-localization.md, Mục tiêu phủ theo màn: Soạn đề "Lưu xong,
/// kiểm đề có lỗi mới (không đọc mỗi lần gõ)"; plan giai đoạn 5 bước 8b).
@MainActor
@Suite("Soạn đề: câu VoiceOver khi kiểm đề có lỗi mới và khi lưu xong")
struct AuthoringAnnouncementTests {
    @Test("Kiểm đề có thêm lỗi thì đọc số lỗi mới; lần kiểm đầu khi mở cửa sổ, lỗi giảm thì không đọc")
    func newErrorsAreAnnounced() async {
        let h = EditorHarness()
        var spoken: [String] = []
        h.editor.announce = { spoken.append($0) }
        await h.editor.waitForValidation()
        #expect(spoken.isEmpty, "lần kiểm đầu không đọc: \(spoken)")
        let before = h.editor.issues.errorCount

        // Câu mới: chưa có nội dung, lựa chọn trống, chưa có đáp án đúng.
        h.step { h.editor.addQuestion() }
        await h.editor.waitForValidation()
        let added = h.editor.issues.errorCount - before
        #expect(added > 0)
        #expect(spoken == [AuthoringPresentation.newErrorsAnnouncement(added)])
        #expect(spoken.first == "Kiểm đề: \(added) lỗi mới")

        // Hoàn tác: lỗi giảm, không đọc thêm.
        h.undo.undo()
        await h.editor.waitForValidation()
        #expect(h.editor.issues.errorCount == before)
        #expect(spoken.count == 1)
    }

    @Test("Lưu xong: chỉ theo lệnh Lưu và Lưu thành…; xong khi document có file và hết “Đã sửa”")
    func saveAnnouncementRules() {
        #expect(SaveAnnouncementObserver.isSaveCommand(NSSelectorFromString("saveDocument:")))
        #expect(SaveAnnouncementObserver.isSaveCommand(NSSelectorFromString("saveDocumentAs:")))
        #expect(!SaveAnnouncementObserver.isSaveCommand(NSSelectorFromString("duplicateDocument:")))
        #expect(!SaveAnnouncementObserver.isSaveCommand(NSSelectorFromString("revertDocumentToSaved:")))
        #expect(!SaveAnnouncementObserver.isSaveCommand(nil))
        typealias State = SaveAnnouncementObserver.FileState
        let url = URL(fileURLWithPath: "/tmp/De thu.exam")
        let other = URL(fileURLWithPath: "/tmp/Ban sao.exam")
        let t0 = Date(timeIntervalSince1970: 1_000), t1 = Date(timeIntervalSince1970: 2_000)
        // ⌘S đề đã sửa: ghi xong (ngày sửa file mới hơn, hết Đã sửa).
        #expect(SaveAnnouncementObserver.didSave(
            before: State(fileURL: url, modificationDate: t0, isEdited: true), now: State(fileURL: url, modificationDate: t1, isEdited: false)))
        // Đang ghi: còn Đã sửa.
        #expect(!SaveAnnouncementObserver.didSave(
            before: State(fileURL: url, modificationDate: t0, isEdited: true), now: State(fileURL: url, modificationDate: t0, isEdited: true)))
        // Lưu thành… của đề đã lưu, không sửa gì, hộp Lưu đang mở rồi Huỷ (review #54 S3): file không đổi, không đọc.
        #expect(!SaveAnnouncementObserver.didSave(
            before: State(fileURL: url, modificationDate: t0, isEdited: false), now: State(fileURL: url, modificationDate: t0, isEdited: false)))
        // Lưu thành… sang file mới.
        #expect(SaveAnnouncementObserver.didSave(
            before: State(fileURL: url, modificationDate: t0, isEdited: false), now: State(fileURL: other, modificationDate: t0, isEdited: false)))
        // Đề chưa từng lưu: có file sau khi lưu.
        #expect(SaveAnnouncementObserver.didSave(
            before: State(fileURL: nil, modificationDate: nil, isEdited: true), now: State(fileURL: url, modificationDate: t1, isEdited: false)))
        // Huỷ hộp Lưu của đề chưa từng lưu.
        #expect(!SaveAnnouncementObserver.didSave(
            before: State(fileURL: nil, modificationDate: nil, isEdited: true), now: State(fileURL: nil, modificationDate: nil, isEdited: true)))
        #expect(AuthoringPresentation.savedAnnouncement(fileName: url.lastPathComponent) == "Đã lưu “De thu.exam”")
    }
}
