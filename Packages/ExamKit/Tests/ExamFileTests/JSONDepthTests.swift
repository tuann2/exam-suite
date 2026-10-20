import ExamKit
import Foundation
import Testing
@testable import ExamFile

/// Đề tối thiểu (sâu 7 cấp: gốc → sections → section → questions → câu → options → lựa chọn)
/// kèm một trường lạ `deep` ở gốc chứa `arrays` mảng lồng nhau. Độ sâu toàn file là
/// `max(7, 1 + arrays)`.
private func examWithDeepField(arrays: Int) -> Data {
    let deep = String(repeating: "[", count: arrays) + String(repeating: "]", count: arrays)
    let json = String(decoding: try! RepoPaths.examJSON("toi-thieu"), as: UTF8.self)
    let head = json.prefix { $0 != "{" }
    let rest = json.drop { $0 != "{" }.dropFirst()
    return Data((head + "{ \"deep\": " + deep + "," + rest).utf8)
}

/// Kết quả đọc trên một luồng khác, để test trên luồng có stack nhỏ.
private final class ReadOutcome: @unchecked Sendable {
    var strict: ExamFileError?
    var lenient: ExamFileError?
    var finished = false
}

@Suite("ExamPackageReader: trần độ sâu JSON")
struct JSONDepthTests {
    static let limit = ExamPackageLimits.default.maxJSONDepth

    @Test("Mặc định 32 cấp")
    func defaultLimit() {
        #expect(Self.limit == 32)
    }

    @Test("Lồng 33 cấp: cả strict lẫn lenient báo tooDeep", arguments: [ReadMode.strict, .lenient])
    func rejectsOverLimit(mode: ReadMode) throws {
        let data = try Zip.make([("exam.json", examWithDeepField(arrays: Self.limit))])
        #expect(throws: ExamFileError.tooDeep(limit: Self.limit)) {
            try ExamPackageReader.read(data, mode: mode)
        }
    }

    @Test("Lồng đúng 32 cấp: không lỗi độ sâu (strict báo trường lạ, lenient đọc được)")
    func acceptsAtLimit() throws {
        let data = try Zip.make([("exam.json", examWithDeepField(arrays: Self.limit - 1))])
        #expect(throws: ExamFileError.unknownFields(["deep"])) {
            try ExamPackageReader.read(data, mode: .strict)
        }
        let package = try ExamPackageReader.read(data, mode: .lenient)
        #expect(package.exam == (try ExamJSON.decode(RepoPaths.examJSON("toi-thieu"))))
    }

    @Test("Trần tuỳ chỉnh qua ExamPackageLimits")
    func customLimit() throws {
        let data = try Zip.packFixture("kien-thuc-chung")
        // Đề hợp lệ sâu đúng 7 cấp (… → options → lựa chọn).
        #expect(throws: ExamFileError.tooDeep(limit: 6)) {
            try ExamPackageReader.read(data, mode: .lenient, limits: ExamPackageLimits(maxJSONDepth: 6))
        }
        _ = try ExamPackageReader.read(data, mode: .strict, limits: ExamPackageLimits(maxJSONDepth: 7))
    }

    @Test("Bộ đếm độ sâu bỏ qua ngoặc trong chuỗi, kể cả sau dấu nháy escape")
    func depthScanner() {
        let quoteInString = #"{"a": "\"[[[[", "b": "\\", "c": [[1]]}"#
        #expect(!StrictJSON.depthExceeds(Data(quoteInString.utf8), limit: 3))
        #expect(StrictJSON.depthExceeds(Data(quoteInString.utf8), limit: 2))
        #expect(!StrictJSON.depthExceeds(Data("[[]][[]]".utf8), limit: 2))
        #expect(StrictJSON.depthExceeds(Data("[[[".utf8), limit: 2))
    }

    @Test("Lồng 100.000 cấp trên luồng stack 512 KB: báo tooDeep, không crash")
    func hugeNestingOnSmallStack() throws {
        let levels = 100_000
        let objects = String(repeating: #"{"a":"#, count: levels) + "1" + String(repeating: "}", count: levels)
        let arrays = "{\"formatVersion\": 1, \"x\": " + String(repeating: "[", count: levels)
            + String(repeating: "]", count: levels) + "}"
        for json in [objects, arrays] {
            let data = try Zip.make([("exam.json", Data(json.utf8))])
            let outcome = ReadOutcome()
            let done = DispatchSemaphore(value: 0)
            let thread = Thread {
                for mode in [ReadMode.strict, .lenient] {
                    var caught: ExamFileError?
                    do { _ = try ExamPackageReader.read(data, mode: mode) } catch { caught = error as? ExamFileError }
                    if mode == .strict { outcome.strict = caught } else { outcome.lenient = caught }
                }
                outcome.finished = true
                done.signal()
            }
            thread.stackSize = 512 * 1024
            thread.start()
            #expect(done.wait(timeout: .now() + 60) == .success)
            #expect(outcome.finished)
            #expect(outcome.strict == .tooDeep(limit: Self.limit))
            #expect(outcome.lenient == .tooDeep(limit: Self.limit))
        }
    }

    @Test("Duyệt null không đệ quy: 100.000 cấp trên luồng stack 512 KB")
    func nullWalkIsIterative() throws {
        // Dựng cây lồng sâu trực tiếp (không qua JSONSerialization) rồi duyệt trên luồng nhỏ.
        let outcome = ReadOutcome()
        let done = DispatchSemaphore(value: 0)
        let thread = Thread {
            var value: Any = NSNull()
            for _ in 0 ..< 100_000 { value = [value] as [Any] }
            let paths = StrictJSON.nullValuePaths(in: ["x": value])
            outcome.finished = paths.count == 1 && paths[0].hasPrefix("x[0][0]")
            // Gỡ cây từ ngoài vào: giải phóng mảng lồng sâu một lần sẽ đệ quy và tràn stack.
            while let array = value as? [Any], let inner = array.first { value = inner }
            done.signal()
        }
        thread.stackSize = 512 * 1024
        thread.start()
        #expect(done.wait(timeout: .now() + 60) == .success)
        #expect(outcome.finished)
    }

    @Test("errorDescription tiếng Việt nêu trần")
    func description() {
        #expect(ExamFileError.tooDeep(limit: 32).errorDescription?.contains("32") == true)
    }
}
