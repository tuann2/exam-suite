import ExamKit
import Foundation
import Testing
import ZIPFoundation
@testable import ExamFile

@Suite("ExamPackageWriter")
struct ExamPackageWriterTests {
    private func fixturePackage(_ name: String = "kien-thuc-chung") throws -> ExamPackage {
        try ExamPackageReader.read(Zip.packFixture(name), mode: .strict)
    }

    private func temporaryDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("examfile-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test("Ghi rồi đọc lại (strict và lenient) ra gói bằng nhau, kể cả ảnh",
          arguments: ["kien-thuc-chung", "toi-thieu"])
    func roundTrip(name: String) throws {
        let package = try fixturePackage(name)
        let data = try ExamPackageWriter.write(package)
        #expect(try ExamPackageReader.read(data, mode: .strict) == package)
        #expect(try ExamPackageReader.read(data, mode: .lenient) == package)
    }

    @Test("Round-trip với nhiều ảnh, ảnh dùng chung và đặt tên bằng MediaNaming")
    func roundTripSharedImages() throws {
        let png = Data([0x89, 0x50, 0x4e, 0x47, 1, 2, 3])
        let jpg = Data(repeating: 0xd8, count: 5000)
        let pngPath = try MediaNaming.path(for: png, fileExtension: "png")
        let jpgPath = try MediaNaming.path(for: jpg, fileExtension: "JPG")
        var package = try fixturePackage("kien-thuc-chung")
        package.exam.sections[0].questions[1].image = jpgPath
        package.exam.sections[1].questions[0].image = pngPath
        package.exam.sections[1].questions[1].image = pngPath
        package.media[pngPath] = png
        package.media[jpgPath] = jpg
        let data = try ExamPackageWriter.write(package)
        #expect(try ExamPackageReader.read(data, mode: .strict) == package)
    }

    @Test("Ảnh mồ côi (không câu nào tham chiếu) bị bỏ khi ghi")
    func dropsOrphanMedia() throws {
        var package = try fixturePackage()
        package.media["media/ffffffffffffffff.png"] = Data([1, 2, 3])
        let data = try ExamPackageWriter.write(package)
        #expect(try Zip.entryNames(data) == ["exam.json", "media/9d5dc894e10f060d.png"])
        let reread = try ExamPackageReader.read(data, mode: .strict)
        #expect(Set(reread.media.keys) == ["media/9d5dc894e10f060d.png"])
    }

    @Test("Thứ tự entry: exam.json rồi ảnh theo tên tăng dần")
    func entryOrder() throws {
        var package = try fixturePackage()
        let a = "media/0000000000000001.png", z = "media/ffffffffffffff00.gif"
        package.exam.sections[1].questions[0].image = z
        package.exam.sections[0].questions[2].image = a
        package.media[a] = Data([1])
        package.media[z] = Data([2])
        let data = try ExamPackageWriter.write(package)
        #expect(try Zip.entryNames(data) == ["exam.json", a, "media/9d5dc894e10f060d.png", z])
    }

    @Test("Cùng nội dung → cùng byte; ngày giờ entry cố định")
    func deterministic() throws {
        let package = try fixturePackage()
        let first = try ExamPackageWriter.write(package)
        let second = try ExamPackageWriter.write(package)
        #expect(first == second)
        let archive = try Archive(data: first, accessMode: .read)
        for entry in archive {
            #expect(entry.fileAttributes[.modificationDate] as? Date != nil)
            #expect(entry.checksum != 0)
        }
    }

    @Test("exam.json trong gói đúng bằng ExamJSON.encode")
    func manifestIsCanonicalJSON() throws {
        let package = try fixturePackage()
        let archive = try Archive(data: ExamPackageWriter.write(package), accessMode: .read)
        let entry = try #require(archive["exam.json"])
        var out = Data()
        _ = try archive.extract(entry) { out.append($0) }
        #expect(out == (try ExamJSON.encode(package.exam)))
    }

    @Test("Luôn ghi formatVersion mới nhất")
    func writesCurrentVersion() throws {
        var package = try fixturePackage("toi-thieu")
        package.exam.formatVersion = 0
        let reread = try ExamPackageReader.read(ExamPackageWriter.write(package), mode: .strict)
        #expect(reread.exam.formatVersion == ExamFileFormat.currentVersion)
    }

    @Test("Thiếu ảnh vẫn ghi được (Admin không chặn lưu); strict từ chối, lenient báo missingMedia")
    func writesDespiteMissingMedia() throws {
        var package = try fixturePackage()
        package.media = [:]
        let data = try ExamPackageWriter.write(package)
        #expect(try Zip.entryNames(data) == ["exam.json"])
        let reread = try ExamPackageReader.read(data, mode: .lenient)
        #expect(reread == package)
        #expect(reread.missingMedia == ["media/9d5dc894e10f060d.png"])
        #expect(throws: ExamFileError.missingMedia(["media/9d5dc894e10f060d.png"])) {
            try ExamPackageReader.read(data, mode: .strict)
        }
    }

    @Test("Ảnh có tên sai mẫu (media/../…) không được ghi vào zip")
    func skipsInvalidMediaNames() throws {
        var package = try fixturePackage("toi-thieu")
        package.exam.sections[0].questions[0].image = "media/../evil.png"
        package.media["media/../evil.png"] = Data([1])
        let data = try ExamPackageWriter.write(package)
        #expect(try Zip.entryNames(data) == ["exam.json"])
    }

    @Test("Ghi ra file rồi đọc lại; ghi đè file cũ; không để lại file tạm")
    func writeToFile() throws {
        let dir = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("Kiến thức chung.exam")

        let first = try fixturePackage()
        try ExamPackageWriter.write(first, to: url)
        #expect(try ExamPackageReader.read(contentsOf: url, mode: .strict) == first)

        var second = first
        second.exam.title = "Kiến thức chung (sửa)"
        try ExamPackageWriter.write(second, to: url)
        #expect(try ExamPackageReader.read(contentsOf: url, mode: .strict) == second)

        let files = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        #expect(files == ["Kiến thức chung.exam"])
    }

    @Test("Lỗi khi thay file đích (đích là thư mục) không làm hỏng đích, không để lại file tạm")
    func failedWriteKeepsOldContent() throws {
        let dir = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("de.exam")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        let inside = url.appendingPathComponent("giu-nguyen.txt")
        try Data("cũ".utf8).write(to: inside)

        let package = try fixturePackage()
        #expect(throws: ExamFileError.self) { try ExamPackageWriter.write(package, to: url) }
        #expect(try Data(contentsOf: inside) == Data("cũ".utf8))
        #expect(try FileManager.default.contentsOfDirectory(atPath: dir.path) == ["de.exam"])
    }

    @Test("Ghi vào thư mục không tồn tại → ném lỗi, không tạo gì")
    func writeToMissingDirectory() throws {
        let dir = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("khong-co/de.exam")
        let package = try fixturePackage()
        #expect(throws: (any Error).self) { try ExamPackageWriter.write(package, to: url) }
        #expect(try FileManager.default.contentsOfDirectory(atPath: dir.path).isEmpty)
    }
}
