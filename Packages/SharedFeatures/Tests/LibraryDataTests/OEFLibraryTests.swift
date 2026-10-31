import ExamFile
import ExamKit
import Foundation
import LargeExamSupport
@testable import LibraryData
import Testing

/// Đề `.oef` của Open Exam Suite trong Thư viện (plan-oef.md bước O2, QO9): file tại chỗ, đọc và chuyển mỗi lần đọc qua
/// `ExamSourceReader`; trạng thái, Làm mới, Tìm file… như `.exam` (library.md). File thử: oracle `fixtures/oef/` và đề
/// mã hoá bằng `OEFEncoding` (chỉ cho test).
@MainActor
@Suite("Thư viện: file .oef")
struct OEFLibraryTests {
    static func fixture(_ name: String) throws -> Data {
        try Data(contentsOf: RepoFixtures.root.appendingPathComponent("oef/\(name).oef"))
    }

    static func write(_ data: Data, to relativePath: String, in workspace: TestWorkspace) throws -> URL {
        let url = workspace.url(relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url)
        return url
    }

    static func reason(_ problem: OEFProblem) -> FileProblemReason {
        FileProblemReason(ExamFileError.oef(problem))
    }

    @Test("Thêm .oef đọc nghiêm được: Sẵn sàng, id dẫn xuất từ mã và tiêu đề, thông tin thẻ", arguments: [ReadMode.strict, .lenient])
    func addsReadyOEF(mode: ReadMode) async throws {
        let workspace = try TestWorkspace()
        let store = workspace.makeStore(mode: mode)
        let file = try Self.write(Self.fixture("co-ban"), to: "Tải về/Đề thử.oef", in: workspace)
        let id = try OEFReader.convert(Self.fixture("co-ban"), mode: .strict).package.exam.id

        let report = await store.importFiles([file])

        #expect(report.items.map(\.outcome) == [.added(examID: id)])
        let entry = try #require(store.entry(id))
        #expect(entry.status == .ready)
        #expect(entry.isOEF)
        #expect(sameFile(entry.fileURL, file))
        #expect(entry.summary == ExamSummary(
            title: "Đề thử OEF cơ bản",
            code: "OEF-01",
            questionCount: 3,
            sectionCount: 2,
            imageCount: 1,
            timeLimitMinutes: 45,
            passPercent: 70,
            hideAnswers: false,
            formatVersion: 1
        ))
    }

    @Test("Bản Học viên không thêm .oef có lỗi, bản cũ hay không phải đề của OES; bản Admin thêm .oef có lỗi (Có lỗi)")
    func unusableOEF() async throws {
        let workspace = try TestWorkspace()
        let invalid = try Self.write(Self.fixture("dap-an-khong-khop"), to: "co-loi.oef", in: workspace)
        let legacy = try Self.write(Self.fixture("ban-cu-nrbf"), to: "ban-cu.oef", in: workspace)
        let text = try Self.write(Self.fixture("van-ban-wims"), to: "wims.oef", in: workspace)
        let invalidReason = Self.reason(.answerNotInOptions(OEFPlace(section: 0, question: 0), letters: ["D"]))

        let student = workspace.makeStore(mode: .strict)
        let report = await student.importFiles([invalid, legacy, text])
        #expect(student.entries.isEmpty)
        #expect(report.items.map(\.outcome) == [
            .rejected(.invalid(reason: invalidReason)),
            .rejected(.corrupt(reason: Self.reason(.legacyFormat))),
            .rejected(.corrupt(reason: Self.reason(.malformed(offset: 0)))),
        ])

        let admin = try TestWorkspace().makeStore(mode: .lenient)
        let adminReport = await admin.importFiles([invalid])
        let id = try OEFReader.convert(Data(contentsOf: invalid), mode: .lenient).package.exam.id
        #expect(adminReport.items.map(\.outcome) == [.added(examID: id)])
        #expect(admin.entry(id)?.status == .readableWithIssues(reason: invalidReason))
    }

    @Test("Sửa câu trong Open Exam Suite (cùng mã, tiêu đề): Làm mới giữ id, cập nhật thẻ; đổi tiêu đề: Không tìm thấy file")
    func editedInOpenExamSuite() async throws {
        let workspace = try TestWorkspace()
        let store = workspace.makeStore()
        var package = try OEFReader.convert(Self.fixture("co-ban"), mode: .strict).package
        let file = try Self.write(OEFEncoding.encode(package), to: "de.oef", in: workspace)
        _ = await store.importFiles([file])
        let id = package.exam.id
        #expect(store.entry(id)?.status == .ready)

        // Bỏ câu cuối, sửa chữ một câu: cùng mã và tiêu đề nên cùng đề.
        package.exam.sections[1].questions[0].text = "Câu đã sửa trong Open Exam Suite"
        package.exam.sections[0].questions.removeLast()
        try OEFEncoding.encode(package).write(to: file)
        try workspace.touch(file)
        await store.refreshAll()
        let entry = try #require(store.entry(id))
        #expect(entry.status == .ready)
        #expect(entry.summary.questionCount == 2)
        #expect(entry.summary.imageCount == 0)

        // Đổi tiêu đề: file giờ là đề khác (id khác), mục cũ mất file như `.exam` bị thay bằng đề khác.
        package.exam.title = "Đề thử OEF đổi tên"
        try OEFEncoding.encode(package).write(to: file)
        try workspace.touch(file)
        await store.refreshAll()
        #expect(store.entry(id)?.status == .missing)
        #expect(store.entry(id)?.title == "Đề thử OEF cơ bản")
    }

    @Test("Tìm file… cho đề .oef mất file nhận gói .exam bản Admin chuyển từ cùng file (cùng id, QO10)")
    func relocateOEFToConvertedExam() async throws {
        let workspace = try TestWorkspace()
        let store = workspace.makeStore()
        let data = try Self.fixture("co-ban")
        let file = try Self.write(data, to: "de.oef", in: workspace)
        _ = await store.importFiles([file])
        let package = try OEFReader.convert(data, mode: .lenient).package
        try FileManager.default.removeItem(at: file)
        await store.refreshAll()
        #expect(store.entry(package.exam.id)?.status == .missing)

        let converted = try workspace.write(package, to: "Đã chuyển/de.exam")
        try await store.relocate(package.exam.id, to: converted)

        let entry = try #require(store.entry(package.exam.id))
        #expect(entry.status == .ready)
        #expect(!entry.isOEF)
        #expect(sameFile(entry.fileURL, converted))
    }

    @Test("File đuôi khác .exam, .oef bị bỏ qua; đuôi viết hoa vẫn nhận")
    func extensions() async throws {
        let workspace = try TestWorkspace()
        let store = workspace.makeStore()
        let upper = try Self.write(Self.fixture("co-ban"), to: "DE.OEF", in: workspace)
        let other = try Self.write(Self.fixture("co-ban"), to: "de.bin", in: workspace)

        let report = await store.importFiles([upper, other])

        let id = try OEFReader.convert(Self.fixture("co-ban"), mode: .strict).package.exam.id
        #expect(report.items.map(\.outcome) == [.added(examID: id), .skippedNotExam])
    }
}
