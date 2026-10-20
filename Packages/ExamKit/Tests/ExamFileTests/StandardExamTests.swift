import ExamKit
import Foundation
@testable import LargeExamSupport
import Testing
@testable import ExamFile

/// Đề chuẩn để đo (docs/product/large-exams.md): đúng quy mô, hợp lệ nghiêm, và **cùng một đề** với
/// `scripts/gen_large_exam.py` (vector cố định: cùng dấu vân tay với `EXPECTED_DIGEST` của script).
@Suite("Đề chuẩn để đo: quy mô, hợp lệ, cùng đề với gen_large_exam.py")
struct StandardExamTests {
    /// SHA-256 của `StandardExam.canonicalText` cho đề chuẩn mặc định, đọc từ `fixtures/large-exam.digest`: cùng file
    /// mà `gen_large_exam.py --check` (scripts/check.sh) so, nên hai bộ sinh không thể lệch mà cả hai cùng xanh.
    static func expectedDigest() throws -> String {
        let url = RepoPaths.fixtures.appendingPathComponent("large-exam.digest")
        return try String(contentsOf: url, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func digest(_ package: ExamPackage) -> String {
        SHA256.hexDigest(Data(StandardExam.canonicalText(package).utf8))
    }

    @Test("Dấu vân tay của đề chuẩn mặc định trùng fixtures/large-exam.digest; đề sửa một ký tự thì lệch")
    func digestMatchesScript() throws {
        let expected = try Self.expectedDigest()
        #expect(expected.count == 64)
        #expect(Self.digest(StandardExam.standard) == expected)
        // Đối chứng âm: sửa nội dung một câu, hay thêm một byte vào một ảnh, thì dấu vân tay phải lệch.
        var changedText = StandardExam.standard
        changedText.exam.sections[0].questions[0].text += "."
        #expect(Self.digest(changedText) != expected)
        var changedImage = StandardExam.standard
        let first = try #require(changedImage.media.keys.sorted().first)
        changedImage.media[first]?.append(0)
        #expect(Self.digest(changedImage) != expected)
    }

    @Test("Quy mô theo large-exams.md: 2.000 câu, 20 phần, 20% nhiều đáp án, 5% 8–12 lựa chọn, 200 ảnh khác nhau")
    func shape() {
        let package = StandardExam.standard
        let questions = package.exam.allQuestions
        #expect(questions.count == 2_000)
        #expect(package.exam.sections.count == 20)
        #expect(package.exam.sections.allSatisfy { $0.questions.count == 100 })
        #expect(questions.filter { $0.type == .multiple }.count == 400)
        #expect(questions.filter { $0.options.count >= 8 }.allSatisfy { (8 ... 12).contains($0.options.count) })
        #expect(questions.filter { $0.options.count >= 8 }.count == 100)
        #expect(questions.filter { $0.options.count < 8 }.allSatisfy { $0.options.count == 4 })
        #expect(questions.filter { $0.image != nil }.count == 200)
        #expect(package.media.count == 200)
        #expect(questions.filter { $0.explanation != nil }.count == 1_000)
        #expect(questions.allSatisfy { (200 ... 600).contains($0.text.unicodeScalars.count) })
        #expect(questions.contains { $0.text.contains("**") } && questions.contains { $0.text.contains(" *") })
        let bytes = package.media.values.reduce(0) { $0 + $1.count }
        #expect((55_000_000 ... 65_000_000).contains(bytes)) // khoảng 60 MB, ~300 KB mỗi ảnh
        // Ảnh là PNG, mọi ảnh khác nhau. Tên là SHA-256 nội dung: bộ sinh băm bằng CommonCrypto trên macOS (nhanh ở
        // Debug), đối chiếu với SHA-256 của ExamFile (MediaNaming, ~4 MB/s ở Debug) trên vài ảnh đầu, cả 1 bit và 2 bit.
        #expect(Set(package.media.values).count == 200)
        for (name, data) in package.media {
            #expect(data.prefix(8) == Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]))
            #expect(name == NoisePNG.mediaPath(for: data))
        }
        for (name, data) in package.media.sorted(by: { $0.key < $1.key }).prefix(4) {
            #expect(name == (try? MediaNaming.path(for: data, fileExtension: "png")))
        }
    }

    @Test("Không lỗi, không cảnh báo của ExamValidator; cùng seed cho cùng đề, seed khác cho đề khác")
    func validAndDeterministic() {
        let package = StandardExam.standard
        #expect(ExamValidator.validate(package.exam, availableMedia: Set(package.media.keys)).isEmpty)
        let small = StandardExam.make(seed: 7, questions: 60, sections: 3)
        #expect(small == StandardExam.make(seed: 7, questions: 60, sections: 3))
        #expect(small != StandardExam.make(seed: 8, questions: 60, sections: 3))
        #expect(small.exam.sections.map(\.questions.count) == [20, 20, 20])
        #expect(small.media.count == 6)
    }

    @Test("PNG hợp lệ: CRC từng chunk và Adler-32 của zlib đúng (đối chiếu giá trị chuẩn)")
    func pngChecksums() {
        // Giá trị chuẩn: zlib.adler32(b"Wikipedia") = 0x11E60398, zlib.crc32(b"IEND") = 0xAE426082.
        #expect(NoisePNG.adler32(Array("Wikipedia".utf8)) == 0x11E6_0398)
        #expect(NoisePNG.crc32(Array("IEND".utf8)) == 0xAE42_6082)
    }
}
