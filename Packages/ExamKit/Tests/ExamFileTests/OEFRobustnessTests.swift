import ExamKit
import Foundation
import Testing
@testable import ExamFile

/// File `.oef` hỏng hay dựng có chủ đích chỉ ra `ExamFileError`, không crash hay treo (như `VceImportTests`):
/// cắt cụt ở mọi vị trí, đột biến có seed, độ dài khổng lồ, varint quá dài, vượt từng giới hạn của `OEFLimits`.
@Suite("ExamFile: .oef hỏng không làm crash")
struct OEFRobustnessTests {
    static let valid = ["co-ban", "goi-dap-an-packed", "qua-26-lua-chon"]

    /// Đọc ở cả hai chế độ; lỗi nào cũng phải là `ExamFileError`.
    private func readBoth(_ data: Data, limits: OEFLimits = .default) {
        for mode in [ReadMode.strict, .lenient] {
            do {
                _ = try OEFReader.convert(data, mode: mode, limits: limits)
            } catch {
                #expect(error is ExamFileError, "\(error)")
            }
        }
    }

    @Test("Cắt cụt ở mọi vị trí", arguments: valid)
    func truncatedEverywhere(_ name: String) throws {
        let data = try OEFReaderTests.fixture(name)
        for length in 0 ..< data.count { readBoth(data.prefix(length)) }
    }

    @Test("Đột biến ngẫu nhiên có seed (đổi, chèn, xoá byte)", arguments: valid)
    func seededMutations(_ name: String) throws {
        let original = [UInt8](try OEFReaderTests.fixture(name))
        var rng = SeededGenerator(seed: 20_261_031)
        for _ in 0 ..< 1_500 {
            var bytes = original
            for _ in 0 ... rng.nextInt(below: 3) {
                let index = rng.nextInt(below: bytes.count)
                switch rng.nextInt(below: 3) {
                case 0: bytes[index] = UInt8(truncatingIfNeeded: rng.next())
                case 1: bytes.insert(UInt8(truncatingIfNeeded: rng.next()), at: index)
                default: if bytes.count > 1 { bytes.remove(at: index) }
                }
            }
            readBoth(Data(bytes))
        }
    }

    @Test("Độ dài khổng lồ và varint quá dài: dây hỏng tại đầu varint")
    func hugeLengthAndLongVarint() {
        // Gốc: trường 1 (độ dài) khai 2^62 byte.
        let huge = Data([0x0A, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x40])
        #expect(throws: ExamFileError.oef(.malformed(offset: 1))) { try OEFReader.convert(huge, mode: .lenient) }
        // Varint 11 byte.
        let long = Data([0x0A] + Array(repeating: 0xFF, count: 10) + [0x01])
        #expect(throws: ExamFileError.oef(.malformed(offset: 1))) { try OEFReader.convert(long, mode: .lenient) }
        // Byte thứ 10 mang hơn một bit.
        let wide = Data([0x18] + Array(repeating: 0xFF, count: 9) + [0x02])
        #expect(throws: ExamFileError.oef(.malformed(offset: 1))) { try OEFReader.convert(wide, mode: .lenient) }
        // Số trường 0.
        #expect(throws: ExamFileError.oef(.malformed(offset: 0))) { try OEFReader.convert(Data([0x02, 0x00]), mode: .lenient) }
    }

    @Test("Vượt giới hạn file, chữ, số phần tử")
    func limits() throws {
        let data = try OEFReaderTests.fixture("co-ban")
        #expect(throws: ExamFileError.oef(.tooLarge(.file, limit: 100))) {
            try OEFReader.convert(data, mode: .strict, limits: OEFLimits(fileBytes: 100))
        }
        #expect(throws: ExamFileError.oef(.tooLarge(.text, limit: 40))) {
            try OEFReader.convert(data, mode: .strict, limits: OEFLimits(textBytes: 40))
        }
        #expect(throws: ExamFileError.oef(.tooLarge(.elements, limit: 14))) {
            try OEFReader.convert(data, mode: .strict, limits: OEFLimits(elementCount: 14))
        }
        // Vừa đúng giới hạn thì đọc được: co-ban có 2 phần, 3 câu, 8 lựa chọn, 2 đáp án trong Answers.
        _ = try OEFReader.convert(data, mode: .strict, limits: OEFLimits(elementCount: 15))
    }

    /// Review độc lập O1: Answers từng không tính vào giới hạn và đáp án lệch được khử trùng bằng tìm tuyến tính
    /// (200.000 đáp án ~2·10^10 phép so). Nay mỗi đáp án là một phần tử, khử trùng bằng tập hợp.
    @Test("Hàng trăm nghìn đáp án khác nhau: đọc xong nhanh, đáp án tính vào giới hạn", .timeLimit(.minutes(1)))
    func manyAnswers() throws {
        var packed: [UInt8] = []
        for value in 0x4000 ..< 0x4000 + 200_000 {
            var v = value
            while v >= 0x80 { packed.append(UInt8(v & 0x7F) | 0x80); v >>= 7 }
            packed.append(UInt8(v))
        }
        func field(_ number: UInt8, _ payload: [UInt8]) -> [UInt8] {
            var length = payload.count
            var bytes = [number << 3 | 2]
            while length >= 0x80 { bytes.append(UInt8(length & 0x7F) | 0x80); length >>= 7 }
            return bytes + [UInt8(length)] + payload
        }
        let options = field(7, [0x08, 0x41] + field(2, [0x61])) + field(7, [0x08, 0x42] + field(2, [0x62]))
        let question = field(2, [0x71]) + [0x28, 0x01] + field(6, packed) + options
        let data = Data(field(1, field(1, [0x74]) + [0x21] + withUnsafeBytes(of: Double(500).bitPattern.littleEndian, Array.init))
            + field(2, field(2, question)))
        do {
            _ = try OEFReader.convert(data, mode: .strict)
            Issue.record("đáp án không khớp phải là lỗi")
        } catch let ExamFileError.oef(.answerNotInOptions(place, letters)) {
            #expect(place == OEFPlace(section: 0, question: 0))
            #expect(letters.count == 20, "câu báo giữ 20 chữ đầu")
        }
        #expect(throws: ExamFileError.oef(.tooLarge(.elements, limit: 1_000))) {
            try OEFReader.convert(data, mode: .lenient, limits: OEFLimits(elementCount: 1_000))
        }
    }

    @Test("Ảnh vượt giới hạn: bản Học viên từ chối, bản Admin bỏ ảnh")
    func imageTooLarge() throws {
        let data = try OEFReaderTests.fixture("co-ban")
        let limits = OEFLimits(imageBytes: 10)
        let place = OEFPlace(section: 0, question: 1)
        #expect(throws: ExamFileError.oef(.imageTooLarge(place, limit: 10))) {
            try OEFReader.convert(data, mode: .strict, limits: limits)
        }
        let lenient = try OEFReader.convert(data, mode: .lenient, limits: limits)
        #expect(lenient.notes == [.imageTooLarge(place, limit: 10)])
        #expect(lenient.package.media.isEmpty)
        #expect(lenient.package.exam.allQuestions[1].image == nil)
    }

    @Test("File rỗng: không có câu hỏi")
    func emptyFile() {
        #expect(throws: ExamFileError.oef(.noQuestions)) { try OEFReader.convert(Data(), mode: .strict) }
    }
}
