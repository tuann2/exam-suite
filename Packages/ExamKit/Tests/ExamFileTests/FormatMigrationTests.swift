import ExamKit
import Foundation
import Testing
@testable import ExamFile

@Suite("Khung chuyển phiên bản định dạng")
struct FormatMigrationTests {
    /// Bộ chuyển đổi giả: v1 → v2 thêm hậu tố vào title, v2 → v3 đổi khoá "heading" thành "title".
    private let fakeSteps = [
        FormatMigration(sourceVersion: 1) { json in
            var json = json
            json["heading"] = (json["title"] as? String ?? "") + " (v2)"
            json.removeValue(forKey: "title")
            return json
        },
        FormatMigration(sourceVersion: 2) { json in
            var json = json
            json["title"] = json.removeValue(forKey: "heading")
            return json
        },
    ]

    @Test("v1 hiện tại chưa đăng ký bước nào")
    func noRegisteredStepsForV1() {
        #expect(ExamFileFormat.currentVersion == 1)
        #expect(FormatMigrator.registered.isEmpty)
    }

    @Test("Chạy chuỗi bước theo thứ tự và cập nhật formatVersion")
    func chainsSteps() throws {
        let out = try FormatMigrator.migrate(
            ["formatVersion": 1, "title": "Đề"], from: 1, to: 3, using: fakeSteps)
        #expect(out["title"] as? String == "Đề (v2)")
        #expect(out["heading"] == nil)
        #expect(out["formatVersion"] as? Int == 3)
    }

    @Test("Bắt đầu giữa chuỗi chỉ chạy các bước còn lại")
    func startsMidChain() throws {
        let out = try FormatMigrator.migrate(
            ["formatVersion": 2, "heading": "Đề"], from: 2, to: 3, using: fakeSteps)
        #expect(out["title"] as? String == "Đề")
        #expect(out["formatVersion"] as? Int == 3)
    }

    @Test("Thiếu bước → migrationFailed, không crash")
    func missingStep() {
        #expect(throws: ExamFileError.migrationFailed(from: 3, reason: .missingStep)) {
            try FormatMigrator.migrate(["formatVersion": 1], from: 1, to: 4, using: fakeSteps)
        }
    }

    @Test("Bước ném lỗi → migrationFailed kèm phiên bản nguồn")
    func failingStep() {
        struct Boom: Error {}
        let steps = [FormatMigration(sourceVersion: 1) { _ in throw Boom() }]
        #expect(throws: ExamFileError.migrationFailed(from: 1, reason: .stepFailed("Boom()"))) {
            try FormatMigrator.migrate(["formatVersion": 1], from: 1, to: 2, using: steps)
        }
    }

    @Test("Reader chạy chuyển đổi khi file cũ hơn phiên bản app (giả lập app v3)")
    func readerMigratesOlderFile() throws {
        let data = try Zip.packFixture("toi-thieu")
        let package = try ExamPackageReader.read(data, mode: .strict, currentVersion: 3, migrations: fakeSteps)
        #expect(package.exam.title == "Đề tối thiểu (v2)")
        #expect(package.exam.formatVersion == 3)
    }

    @Test("Reader kiểm trường lạ trên kết quả sau chuyển đổi")
    func readerChecksUnknownAfterMigration() throws {
        let leaky = [
            FormatMigration(sourceVersion: 1) { json in
                var json = json
                json["legacy"] = true
                return json
            },
        ]
        let data = try Zip.packFixture("toi-thieu")
        #expect(throws: ExamFileError.unknownFields(["legacy"])) {
            try ExamPackageReader.read(data, mode: .strict, currentVersion: 2, migrations: leaky)
        }
        let lenient = try ExamPackageReader.read(data, mode: .lenient, currentVersion: 2, migrations: leaky)
        #expect(lenient.exam.formatVersion == 2)
    }

    @Test("Reader báo migrationFailed khi thiếu bước cho file cũ")
    func readerMissingStep() throws {
        let data = try Zip.packFixture("toi-thieu")
        #expect(throws: ExamFileError.migrationFailed(from: 1, reason: .missingStep)) {
            try ExamPackageReader.read(data, mode: .lenient, currentVersion: 2, migrations: [])
        }
    }
}
