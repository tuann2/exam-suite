import ExamKit
import Foundation
import Testing
import ZIPFoundation
@testable import ExamFile

/// Lỗi `ExamFileError` mà lần đọc ném ra; nil nếu đọc thành công. Lỗi khác kiểu cũng thành nil
/// để test so sánh thấy ngay.
private func readError(_ data: Data, mode: ReadMode) -> ExamFileError? {
    do {
        _ = try ExamPackageReader.read(data, mode: mode)
        return nil
    } catch {
        return error as? ExamFileError
    }
}

private func manifestOnly(_ json: Data) throws -> Data {
    try Zip.make([("exam.json", json)])
}

@Suite("ExamPackageReader: gói hợp lệ")
struct ExamPackageReaderValidTests {
    @Test("Đóng gói kien-thuc-chung (có ảnh), đọc được ở cả hai chế độ", arguments: [ReadMode.strict, .lenient])
    func readsFixtureWithMedia(mode: ReadMode) throws {
        let package = try ExamPackageReader.read(Zip.packFixture("kien-thuc-chung"), mode: mode)
        let expected = try ExamJSON.decode(RepoPaths.examJSON("kien-thuc-chung"))
        #expect(package.exam == expected)
        #expect(package.missingMedia.isEmpty)
        let image = try Data(contentsOf: RepoPaths.examDirectory("kien-thuc-chung")
            .appendingPathComponent("media/9d5dc894e10f060d.png"))
        #expect(package.media == ["media/9d5dc894e10f060d.png": image])
    }

    @Test("Đề tối thiểu không ảnh, media rỗng")
    func readsMinimal() throws {
        let package = try ExamPackageReader.read(Zip.packFixture("toi-thieu"), mode: .strict)
        #expect(package.exam == (try ExamJSON.decode(RepoPaths.examJSON("toi-thieu"))))
        #expect(package.media.isEmpty)
    }

    @Test("Entry lạ, thư mục, media lồng (media/a/b.png) và tên sai mẫu bị bỏ qua; ảnh mồ côi đúng mẫu vẫn được đọc")
    func ignoresStrayEntries() throws {
        var entries = try Zip.fixtureEntries("kien-thuc-chung")
        entries.insert(("media/", Data()), at: 1)
        entries += [
            ("readme.txt", Data("ghi chú".utf8)),
            ("__MACOSX/._exam.json", Data([0, 1])),
            ("other/exam.json", Data("{}".utf8)),
            ("media/ffffffffffffffff.png", Data([9, 9, 9])),
            ("media/a/0123456789abcdef.png", Data([1])),
            ("media/a/b.png", Data([1])),
            ("media/ghi-chu.txt", Data([1])),
            ("media/../0123456789abcdef.png", Data([1])),
        ]
        let package = try ExamPackageReader.read(Zip.make(entries), mode: .strict)
        #expect(Set(package.media.keys) == ["media/9d5dc894e10f060d.png", "media/ffffffffffffffff.png"])
        #expect(package.media["media/ffffffffffffffff.png"] == Data([9, 9, 9]))
    }

    @Test("Đọc được gói không nén (stored)")
    func readsStoredEntries() throws {
        let data = try Zip.make(Zip.fixtureEntries("kien-thuc-chung"), compression: .none)
        let package = try ExamPackageReader.read(data, mode: .strict)
        #expect(package.media.count == 1)
    }

    @Test("Đọc từ URL")
    func readsFromURL() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("de.exam")
        try Zip.packFixture("kien-thuc-chung").write(to: url)
        let package = try ExamPackageReader.read(contentsOf: url, mode: .strict)
        #expect(package.exam.title == "Kiến thức chung")
    }
}

@Suite("ExamPackageReader: URL")
struct ExamPackageReaderURLTests {
    @Test("Đọc từ URL không tồn tại: lỗi của Foundation, không phải lỗi định dạng")
    func missingFile() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("khong-co-\(UUID().uuidString).exam")
        do {
            _ = try ExamPackageReader.read(contentsOf: url, mode: .strict)
            Issue.record("Cần ném lỗi")
        } catch {
            #expect(!(error is ExamFileError), "\(error)")
        }
    }
}

@Suite("ExamPackageReader: trường lạ")
struct ExamPackageReaderUnknownFieldTests {
    @Test("Strict từ chối trường lạ ở cấp đề, nêu đường dẫn")
    func strictRejectsTopLevel() throws {
        let data = try manifestOnly(RepoPaths.invalidJSON("unknown-top-level-field"))
        #expect(readError(data, mode: .strict) == .unknownFields(["extra"]))
    }

    @Test("Strict từ chối trường lạ ở cấp câu hỏi, nêu đường dẫn")
    func strictRejectsQuestionLevel() throws {
        let data = try manifestOnly(RepoPaths.invalidJSON("unknown-question-field"))
        #expect(readError(data, mode: .strict) == .unknownFields(["sections[0].questions[0].hint"]))
    }

    @Test("Strict báo mọi trường lạ ở mọi cấp, theo thứ tự cấu trúc")
    func strictReportsEveryLevel() throws {
        let json = try JSONEdit.modify(RepoPaths.examJSON("kien-thuc-chung")) { exam in
            exam["zeta"] = 1
            exam["alpha"] = "x"
            JSONEdit.setting(true, key: "color", section: 1, in: &exam)
            JSONEdit.setting("?", key: "hint", section: 1, question: 1, in: &exam)
            JSONEdit.setting(0, key: "weight", section: 0, question: 2, option: 1, in: &exam)
        }
        var entries = try Zip.fixtureEntries("kien-thuc-chung")
        entries[0] = ("exam.json", json)
        let data = try Zip.make(entries)
        #expect(readError(data, mode: .strict) == .unknownFields([
            "alpha",
            "zeta",
            "sections[0].questions[2].options[1].weight",
            "sections[1].color",
            "sections[1].questions[1].hint",
        ]))
        // Lenient: đọc được và bỏ qua toàn bộ.
        let package = try ExamPackageReader.read(data, mode: .lenient)
        #expect(package.exam == (try ExamJSON.decode(RepoPaths.examJSON("kien-thuc-chung"))))
    }

    @Test("Lenient đọc được hai fixture có trường lạ, bỏ qua trường đó",
          arguments: ["unknown-top-level-field", "unknown-question-field"])
    func lenientIgnores(name: String) throws {
        let package = try ExamPackageReader.read(manifestOnly(RepoPaths.invalidJSON(name)), mode: .lenient)
        #expect(package.exam == (try ExamJSON.decode(RepoPaths.examJSON("toi-thieu"))))
    }

    @Test("Admin mở đề có trường lạ rồi lưu: file mới không còn trường lạ, bản Học viên mở được")
    func lenientThenSaveDropsUnknown() throws {
        let opened = try ExamPackageReader.read(
            manifestOnly(RepoPaths.invalidJSON("unknown-question-field")), mode: .lenient)
        let saved = try ExamPackageWriter.write(opened)
        let reopened = try ExamPackageReader.read(saved, mode: .strict)
        #expect(reopened == opened)
    }
}

@Suite("ExamPackageReader: phiên bản định dạng")
struct ExamPackageReaderVersionTests {
    @Test("future-version → unsupportedVersion(2, 1) ở cả hai chế độ", arguments: [ReadMode.strict, .lenient])
    func futureVersion(mode: ReadMode) throws {
        let data = try manifestOnly(RepoPaths.invalidJSON("future-version"))
        #expect(readError(data, mode: mode) == .unsupportedVersion(found: 2, supported: 1))
    }

    @Test("Phiên bản mới hơn được báo trước cả khi phần còn lại sai hoặc có trường lạ")
    func futureVersionWinsOverOtherErrors() throws {
        let data = try manifestOnly(Data(#"{"formatVersion": 7, "sections": "sai", "x": 1}"#.utf8))
        #expect(readError(data, mode: .strict) == .unsupportedVersion(found: 7, supported: 1))
    }

    @Test("formatVersion < 1 → invalidVersion", arguments: [0, -3])
    func invalidVersion(version: Int) throws {
        let data = try manifestOnly(Data(#"{"formatVersion": \#(version)}"#.utf8))
        #expect(readError(data, mode: .strict) == .invalidVersion(version))
    }

    @Test("Thiếu hoặc sai kiểu formatVersion → invalidJSON",
          arguments: [#"{"title": "x"}"#, #"{"formatVersion": "1"}"#, #"{"formatVersion": true}"#,
                      #"{"formatVersion": 1.5}"#])
    func badVersionField(json: String) throws {
        let error = readError(try manifestOnly(Data(json.utf8)), mode: .lenient)
        guard case let .invalidJSON(problem) = error else {
            Issue.record("Cần invalidJSON, nhận \(String(describing: error))")
            return
        }
        #expect([.missingFormatVersion, .formatVersionNotInteger].contains(problem))
        #expect(problem.logMessage.contains("formatVersion"))
    }
}

@Suite("ExamPackageReader: file hỏng")
struct ExamPackageReaderCorruptTests {
    @Test("Dữ liệu không phải zip", arguments: [Data("not a zip".utf8), Data(), Data(repeating: 0x50, count: 300)])
    func notZip(data: Data) {
        #expect(readError(data, mode: .strict) == .notAZipArchive)
    }

    @Test("Zip không có exam.json ở gốc")
    func missingManifest() throws {
        let data = try Zip.make([
            ("de/exam.json", try RepoPaths.examJSON("toi-thieu")),
            ("media/aa.png", Data([1])),
        ])
        #expect(readError(data, mode: .strict) == .missingManifest)
        #expect(readError(data, mode: .lenient) == .missingManifest)
    }

    @Test("exam.json là thư mục thì coi như thiếu")
    func manifestDirectory() throws {
        let data = try Zip.make([("exam.json/", Data())])
        #expect(readError(data, mode: .strict) == .missingManifest)
    }

    @Test("JSON hỏng → invalidJSON", arguments: ["{", "[1, 2]", "\"chuỗi\"", "{\"formatVersion\": 1,}"])
    func brokenJSON(json: String) throws {
        let error = readError(try manifestOnly(Data(json.utf8)), mode: .strict)
        guard case .invalidJSON = error else {
            Issue.record("Cần invalidJSON, nhận \(String(describing: error))")
            return
        }
    }

    @Test("exam.json không phải UTF-8 → invalidJSON")
    func notUTF8() throws {
        let error = readError(try manifestOnly(Data([0x7b, 0xff, 0xfe, 0x7d])), mode: .strict)
        #expect(error == .invalidJSON(.notUTF8))
        #expect(error?.errorDescription == "exam.json không hợp lệ: exam.json phải mã hoá UTF-8.")
    }

    @Test("Sai cấu trúc đề → invalidJSON nêu đường dẫn khoá")
    func decodingErrorHasPath() throws {
        let typeJSON = try JSONEdit.modify(RepoPaths.examJSON("toi-thieu")) { exam in
            JSONEdit.setting("triple", key: "type", section: 0, question: 0, in: &exam)
        }
        let missingText = try JSONEdit.modify(RepoPaths.examJSON("toi-thieu")) { exam in
            var sections = exam["sections"] as! [[String: Any]]
            var questions = sections[0]["questions"] as! [[String: Any]]
            var options = questions[0]["options"] as! [[String: Any]]
            options[1].removeValue(forKey: "text")
            questions[0]["options"] = options
            sections[0]["questions"] = questions
            exam["sections"] = sections
        }
        let cases: [(Data, String)] = [
            (typeJSON, "sections[0].questions[0].type"),
            (missingText, "sections[0].questions[0].options[1]"),
        ]
        for (json, path) in cases {
            let error = readError(try manifestOnly(json), mode: .lenient)
            guard case let .invalidJSON(problem) = error else {
                Issue.record("Cần invalidJSON, nhận \(String(describing: error))")
                continue
            }
            #expect(problem.logMessage.hasPrefix(path), "\(problem.logMessage)")
        }
    }

    @Test("Ảnh được tham chiếu nhưng thiếu trong gói: strict → missingMedia")
    func missingMediaStrict() throws {
        let data = try manifestOnly(RepoPaths.examJSON("kien-thuc-chung"))
        #expect(readError(data, mode: .strict) == .missingMedia(["media/9d5dc894e10f060d.png"]))
    }

    @Test("Ảnh được tham chiếu nhưng thiếu trong gói: lenient vẫn mở, báo qua missingMedia")
    func missingMediaLenient() throws {
        let data = try manifestOnly(RepoPaths.examJSON("kien-thuc-chung"))
        let package = try ExamPackageReader.read(data, mode: .lenient)
        #expect(package.exam == (try ExamJSON.decode(RepoPaths.examJSON("kien-thuc-chung"))))
        #expect(package.media.isEmpty)
        #expect(package.missingMedia == ["media/9d5dc894e10f060d.png"])
    }

    @Test("Ảnh nằm ngoài media/: strict → invalidMediaPath, lenient → missingMedia")
    func imageOutsideMediaDirectory() throws {
        let json = try JSONEdit.modify(RepoPaths.examJSON("toi-thieu")) { exam in
            JSONEdit.setting("anh.png", key: "image", section: 0, question: 0, in: &exam)
        }
        let data = try Zip.make([("exam.json", json), ("anh.png", Data([1]))])
        #expect(readError(data, mode: .strict) == .invalidMediaPath(["anh.png"]))
        let package = try ExamPackageReader.read(data, mode: .lenient)
        #expect(package.media.isEmpty)
        #expect(package.missingMedia == ["anh.png"])
    }

    @Test("Đường dẫn ảnh sai mẫu (media/../, thư mục con, chữ hoa…): strict từ chối, lenient không nạp",
          arguments: ["media/../../evil.png", "media/a/0123456789abcdef.png", "media/0123456789ABCDEF.png",
                      "media/0123.png", "media/0123456789abcdef.bmp", "/media/0123456789abcdef.png"])
    func invalidImagePath(path: String) throws {
        let json = try JSONEdit.modify(RepoPaths.examJSON("toi-thieu")) { exam in
            JSONEdit.setting(path, key: "image", section: 0, question: 0, in: &exam)
        }
        let data = try Zip.make([("exam.json", json), (path, Data([1]))])
        #expect(readError(data, mode: .strict) == .invalidMediaPath([path]))
        let package = try ExamPackageReader.read(data, mode: .lenient)
        #expect(package.media.isEmpty)
        #expect(package.missingMedia == [path])
    }

    @Test("Entry sai CRC → corruptedEntry, không crash")
    func crcMismatch() throws {
        let json = try RepoPaths.examJSON("toi-thieu")
        var data = try Zip.make([("exam.json", json)], compression: .none)
        // Dữ liệu không nén nằm nguyên văn trong zip: sửa một byte ở giữa phần tiêu đề.
        let marker = Data("Đề tối thiểu".utf8)
        let range = try #require(data.range(of: marker))
        data[range.lowerBound] ^= 0x01
        #expect(readError(data, mode: .strict) == .corruptedEntry("exam.json"))
    }

    @Test("Ảnh sai CRC → corruptedEntry")
    func mediaCRCMismatch() throws {
        let image = Data(repeating: 0xab, count: 64) + Data("dấu-ảnh".utf8)
        let json = try JSONEdit.modify(RepoPaths.examJSON("toi-thieu")) { exam in
            JSONEdit.setting("media/0000000000000000.png", key: "image", section: 0, question: 0, in: &exam)
        }
        var data = try Zip.make([("exam.json", json), ("media/0000000000000000.png", image)], compression: .none)
        let range = try #require(data.range(of: Data("dấu-ảnh".utf8)))
        data[range.lowerBound] ^= 0x01
        #expect(readError(data, mode: .lenient) == .corruptedEntry("media/0000000000000000.png"))
    }

    @Test("Zip bị cắt cụt hoặc đổi từng byte: chỉ ném lỗi, không crash")
    func fuzzedArchiveDoesNotCrash() throws {
        let original = try Zip.packFixture("kien-thuc-chung")
        // Cắt cụt ở nhiều độ dài.
        for length in stride(from: 0, to: original.count, by: 37) {
            let truncated = original.prefix(length)
            #expect(throws: ExamFileError.self) { try ExamPackageReader.read(Data(truncated), mode: .strict) }
        }
        // Đổi từng byte; đọc được hoặc ném ExamFileError đều chấp nhận. Với `Archive(data:)`
        // của ZIPFoundation 0.9.20, nhiều vị trí ở đây làm crash cả tiến trình.
        #if os(Linux)
        // Trên Linux, ZIPFoundation 0.9.20 giải nén deflate bằng zlib và lặp vô hạn khi luồng
        // deflate hỏng không kết thúc (`Data.decode` đọc mãi chunk rỗng ở cuối file). App chỉ
        // chạy trên macOS (nhánh Compression của Apple, có giới hạn kích thước, fuzz đủ ở trên
        // macOS); trên Linux chỉ fuzz gói không nén để CI không treo.
        let flipSource = try Zip.make(Zip.fixtureEntries("kien-thuc-chung"), compression: .none)
        #else
        let flipSource = original
        #endif
        for index in 0 ..< flipSource.count {
            var mutated = flipSource
            mutated[index] ^= 0xff
            do {
                _ = try ExamPackageReader.read(mutated, mode: .strict)
            } catch {
                #expect(error is ExamFileError, "byte \(index): \(error)")
            }
        }
    }
}

@Suite("ExamPackageReader: entry trùng và giới hạn kích thước")
struct ExamPackageReaderLimitTests {
    @Test("Hai entry exam.json → duplicateEntry")
    func duplicateManifest() throws {
        let json = try RepoPaths.examJSON("toi-thieu")
        let data = try Zip.make([("exam.json", json), ("exam.json", json)])
        #expect(try Zip.entryNames(data) == ["exam.json", "exam.json"])
        #expect(readError(data, mode: .lenient) == .duplicateEntry("exam.json"))
    }

    @Test("Hai ảnh cùng tên → duplicateEntry")
    func duplicateMedia() throws {
        var entries = try Zip.fixtureEntries("kien-thuc-chung")
        entries.append(("media/9d5dc894e10f060d.png", Data([1, 2])))
        let data = try Zip.make(entries)
        #expect(readError(data, mode: .lenient) == .duplicateEntry("media/9d5dc894e10f060d.png"))
    }

    @Test("Giá trị mặc định của ExamPackageLimits")
    func defaults() {
        let limits = ExamPackageLimits.default
        #expect(limits.manifestBytes == 32 * 1024 * 1024)
        #expect(limits.mediaEntryBytes == 50 * 1024 * 1024)
        #expect(limits.totalUncompressedBytes == 1024 * 1024 * 1024)
        #expect(limits.entryCount == 20_000)
    }

    @Test("exam.json vượt trần → tooLarge trước khi giải nén")
    func manifestTooLarge() throws {
        let data = try Zip.packFixture("kien-thuc-chung")
        let limits = ExamPackageLimits(manifestBytes: 100)
        #expect(throws: ExamFileError.tooLarge(entry: "exam.json", limit: 100)) {
            try ExamPackageReader.read(data, mode: .lenient, limits: limits)
        }
    }

    @Test("Ảnh vượt trần → tooLarge")
    func mediaTooLarge() throws {
        let data = try Zip.packFixture("kien-thuc-chung")
        let limits = ExamPackageLimits(mediaEntryBytes: 72) // ảnh fixture 73 byte
        #expect(throws: ExamFileError.tooLarge(entry: "media/9d5dc894e10f060d.png", limit: 72)) {
            try ExamPackageReader.read(data, mode: .lenient, limits: limits)
        }
        let fits = try ExamPackageReader.read(data, mode: .lenient, limits: ExamPackageLimits(mediaEntryBytes: 73))
        #expect(fits.media.count == 1)
    }

    @Test("Tổng giải nén vượt trần → tooLarge")
    func totalTooLarge() throws {
        let data = try Zip.packFixture("kien-thuc-chung")
        let total = try RepoPaths.examJSON("kien-thuc-chung").count + 72
        #expect(throws: ExamFileError.tooLarge(entry: ExamPackageLimits.totalSizeName, limit: total)) {
            try ExamPackageReader.read(data, mode: .lenient, limits: ExamPackageLimits(totalUncompressedBytes: total))
        }
        let fits = try ExamPackageReader.read(
            data, mode: .lenient, limits: ExamPackageLimits(totalUncompressedBytes: total + 1))
        #expect(fits.media.count == 1)
    }

    @Test("Số entry vượt trần → tooLarge (kể cả entry bị bỏ qua)")
    func tooManyEntries() throws {
        var entries = try Zip.fixtureEntries("toi-thieu")
        entries += (0 ..< 5).map { ("rac/\($0).txt", Data()) }
        let data = try Zip.make(entries)
        #expect(throws: ExamFileError.tooLarge(entry: ExamPackageLimits.entryCountName, limit: 5)) {
            try ExamPackageReader.read(data, mode: .lenient, limits: ExamPackageLimits(entryCount: 5))
        }
        let fits = try ExamPackageReader.read(data, mode: .lenient, limits: ExamPackageLimits(entryCount: 6))
        #expect(fits.media.isEmpty)
    }

    @Test("Zip nói dối kích thước (giải nén ra nhiều hơn khai báo) → dừng, corruptedEntry")
    func lyingSizeIsStopped() throws {
        var data = try Zip.make([("exam.json", try RepoPaths.examJSON("kien-thuc-chung"))])
        // Sửa uncompressedSize thành 10 ở local header (offset 22) và central directory (offset 24).
        func patch(signature: [UInt8], offset: Int) throws {
            let start = try #require(data.range(of: Data(signature))).lowerBound
            for (i, byte) in [UInt8(10), 0, 0, 0].enumerated() { data[start + offset + i] = byte }
        }
        try patch(signature: [0x50, 0x4b, 0x03, 0x04], offset: 22)
        try patch(signature: [0x50, 0x4b, 0x01, 0x02], offset: 24)
        #expect(readError(data, mode: .lenient) == .corruptedEntry("exam.json"))
    }
}
