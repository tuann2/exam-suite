import Foundation
import PDFKit
@testable import ReportFeature
import Testing

/// Ghi PDF ra file người dùng chọn (docs/product/export-print.md, mục Tên file và hộp lưu): file tạm cạnh file đích rồi
/// thay; lỗi ghi có lý do, huỷ hay lỗi không để lại file dở, file đích có sẵn giữ nguyên tới khi PDF mới ghi xong.
@MainActor
@Suite("Ghi PDF ra file", .serialized)
struct ReportFileWriterTests {
    func document(_ count: Int = 3) -> ReportDocument {
        ReportRendererTests.document((1 ... count).map {
            ReportRendererTests.question($0, text: "Câu ghi file \($0) " + String(repeating: "nội dung ", count: 40))
        })
    }

    func directory() throws -> URL {
        try ReportRendererTests.temporaryDirectory()
    }

    func files(in directory: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted()
    }

    @Test("Ghi xong: file đích là PDF đọc được, đè file có sẵn, không còn file tạm")
    func writesAndReplaces() async throws {
        let directory = try directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = directory.appendingPathComponent("Địa lý - Đức - 2026-10-17 0905.pdf")
        try Data("bản cũ".utf8).write(to: destination)
        var events: [ReportProgress] = []
        let file = try await ReportFileWriter.write(document(), to: destination) { events.append($0) }
        #expect(file.url == destination)
        #expect(try files(in: directory) == [destination.lastPathComponent])
        let reader = try #require(PDFDocument(url: destination))
        #expect(reader.pageCount == file.pageCount)
        #expect(reader.string?.contains("Câu ghi file 3") == true)
        #expect(events.last?.fractionCompleted == 1)
    }

    @Test("Huỷ khi đang dựng: CancellationError, không còn file tạm, file đích cũ giữ nguyên")
    func cancellationKeepsDestination() async throws {
        let directory = try directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = directory.appendingPathComponent("ket-qua.pdf")
        try Data("bản cũ".utf8).write(to: destination)
        for phase in [ReportProgress.Phase.layout, .drawing] {
            let task = Task { @MainActor () -> ReportPDFFile in
                try await ReportFileWriter.write(document(30), to: destination) { event in
                    if event.phase == phase, event.completed >= 1 {
                        withUnsafeCurrentTask { $0?.cancel() }
                    }
                }
            }
            await #expect(throws: CancellationError.self) { try await task.value }
            #expect(try files(in: directory) == ["ket-qua.pdf"], "file tạm còn sau khi huỷ ở \(phase)")
            #expect(try Data(contentsOf: destination) == Data("bản cũ".utf8))
        }
        // Huỷ trước cả khi dựng: không tạo file nào.
        let fresh = directory.appendingPathComponent("moi.pdf")
        let task = Task { @MainActor () -> ReportPDFFile in
            withUnsafeCurrentTask { $0?.cancel() }
            return try await ReportFileWriter.write(document(), to: fresh)
        }
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(try files(in: directory) == ["ket-qua.pdf"])
    }

    @Test("App thoát giữa chừng: file tạm đang dựng được ghi nhớ và xoá lúc willTerminate; xong thì không còn trong danh sách")
    func terminationRemovesTemporaryFile() async throws {
        let directory = try directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = directory.appendingPathComponent("thoat.pdf")
        let inDirectory: (URL) -> Bool = { $0.deletingLastPathComponent().path == directory.path }
        var pendingDuringWrite: [URL] = []
        var listingAfterCleanup: [String]?
        let task = Task { @MainActor () -> ReportPDFFile in
            try await ReportFileWriter.write(document(30), to: destination) { event in
                guard event.phase == .drawing, event.completed >= 1, listingAfterCleanup == nil else { return }
                pendingDuringWrite = ReportTemporaryFiles.pending.filter(inDirectory)
                // Như `NSApplication.willTerminateNotification`: tiến trình chưa kết thúc nên lần dựng chạy tiếp, rồi huỷ.
                ReportTemporaryFiles.removeAll(matching: inDirectory)
                listingAfterCleanup = try? files(in: directory)
                withUnsafeCurrentTask { $0?.cancel() }
            }
        }
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(pendingDuringWrite.count == 1)
        #expect(pendingDuringWrite.first?.lastPathComponent.hasPrefix(ReportFileWriter.temporaryPrefix) == true)
        #expect(listingAfterCleanup == [])
        #expect(try files(in: directory).isEmpty)
        #expect(ReportTemporaryFiles.pending.filter(inDirectory).isEmpty)

        _ = try await ReportFileWriter.write(document(), to: destination)
        #expect(ReportTemporaryFiles.pending.filter(inDirectory).isEmpty)
    }

    @Test("Tên file đích dài tới giới hạn 255 byte (APFS): file tạm có tên ngắn cố định nên vẫn ghi được")
    func longDestinationName() async throws {
        let directory = try directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let name = String(repeating: "ệ", count: 83) + ".pdf"
        #expect(name.utf8.count == 253)
        let destination = directory.appendingPathComponent(name)
        let file = try await ReportFileWriter.write(document(), to: destination)
        #expect(file.url == destination)
        #expect(try files(in: directory).map(\.precomposedStringWithCanonicalMapping) == [name])
        let temporary = ReportFileWriter.temporaryURL(for: destination).lastPathComponent
        #expect(temporary.hasPrefix(".ExamSuite-") && temporary.hasSuffix(".pdf.tmp"))
        #expect(temporary.utf8.count == 27)
    }

    @Test("Lỗi ghi: thư mục chỉ đọc, thư mục không còn, đích là thư mục; báo lý do, không để lại file")
    func writeErrors() async throws {
        let directory = try directory()
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path)
            try? FileManager.default.removeItem(at: directory)
        }
        let occupied = directory.appendingPathComponent("trung.pdf", isDirectory: true)
        try FileManager.default.createDirectory(at: occupied, withIntermediateDirectories: true)
        try Data().write(to: occupied.appendingPathComponent("giu.txt"))
        await #expect(throws: ReportWriteError.failed) { try await ReportFileWriter.write(document(), to: occupied) }
        #expect(try files(in: directory) == ["trung.pdf"])

        await #expect(throws: ReportWriteError.folderMissing) {
            try await ReportFileWriter.write(document(), to: directory.appendingPathComponent("khong-co/a.pdf"))
        }

        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: directory.path)
        await #expect(throws: ReportWriteError.noPermission) {
            try await ReportFileWriter.write(document(), to: directory.appendingPathComponent("a.pdf"))
        }
        #expect(try files(in: directory) == ["trung.pdf"])
    }

    @Test("PDF ghi ra không đọc lại được hoặc thiếu trang thì là lỗi (Core Graphics không báo lỗi ghi)")
    func verifyOutput() async throws {
        let directory = try directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let broken = directory.appendingPathComponent("hong.pdf")
        try Data("%PDF-1.7 cắt cụt".utf8).write(to: broken)
        #expect(throws: ReportWriteError.unreadableOutput) { try ReportFileWriter.verify(broken, pageCount: 1) }
        let good = directory.appendingPathComponent("tot.pdf")
        let file = try await ReportRenderer().render(document(), to: good)
        try ReportFileWriter.verify(good, pageCount: file.pageCount)
        #expect(throws: ReportWriteError.unreadableOutput) { try ReportFileWriter.verify(good, pageCount: file.pageCount + 1) }
    }

    @Test("Mã lỗi hệ thống → lý do bằng chữ của app")
    func errnoMessages() {
        #expect(ReportWriteError(errno: EACCES) == .noPermission)
        #expect(ReportWriteError(errno: EPERM) == .noPermission)
        #expect(ReportWriteError(errno: ENOSPC) == .outOfSpace)
        #expect(ReportWriteError(errno: EDQUOT) == .outOfSpace)
        #expect(ReportWriteError(errno: EROFS) == .readOnlyVolume)
        #expect(ReportWriteError(errno: ENOENT) == .folderMissing)
        #expect(ReportWriteError(errno: EISDIR) == .failed)
        #expect(ReportWriteError.noPermission.message == "Không có quyền ghi vào thư mục đã chọn.")
        #expect(ReportWriteError.outOfSpace.message == "Ổ đĩa không còn đủ chỗ trống.")
        #expect(ReportWriteError.readOnlyVolume.message == "Ổ đĩa đã chọn chỉ đọc.")
        #expect(ReportWriteError.folderMissing.message == "Không tìm thấy thư mục đã chọn.")
        #expect(ReportWriteError.unreadableOutput.message == "File PDF vừa ghi bị lỗi, có thể do ổ đĩa đầy.")
        #expect(ReportWriteError.message(for: CocoaError(.fileWriteUnknown)) == "Không ghi được file PDF.")
        #expect(ReportStrings.printUnavailable == "Không chuẩn bị được bản in.")
    }
}
