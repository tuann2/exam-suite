@testable import AuthoringData
import ExamFile
import ExamKit
import Foundation
import Testing

enum RepoFixtures {
    static let root: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // Support
        .deletingLastPathComponent() // AuthoringDataTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // ExamFeatures
        .deletingLastPathComponent() // Packages
        .deletingLastPathComponent() // repo root
        .appendingPathComponent("fixtures", isDirectory: true)

    /// Đề trong `fixtures/exams/<name>` (exam.json + media/), dựng thành `ExamPackage`.
    static func package(_ name: String) throws -> ExamPackage {
        let directory = root.appendingPathComponent("exams/\(name)", isDirectory: true)
        let exam = try ExamJSON.decode(Data(contentsOf: directory.appendingPathComponent("exam.json")))
        var media: [String: Data] = [:]
        let mediaDirectory = directory.appendingPathComponent("media", isDirectory: true)
        if FileManager.default.fileExists(atPath: mediaDirectory.path) {
            for file in try FileManager.default.contentsOfDirectory(atPath: mediaDirectory.path) where !file.hasPrefix(".") {
                media["media/\(file)"] = try Data(contentsOf: mediaDirectory.appendingPathComponent(file))
            }
        }
        return ExamPackage(exam: exam, media: media)
    }

    /// Đề "Kiến thức chung": phần Vật lý (3 câu, câu 1 có ảnh), phần Toán (2 câu).
    static func kienThucChung() throws -> ExamDraft { ExamDraft(package: try package("kien-thuc-chung")) }
}

/// Id cố định cho test: `00000000-0000-0000-0000-0000000000NN`.
func fixedID(_ n: Int) -> UUID {
    UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", n))!
}

func letters(_ ids: [OptionID]) -> String { ids.map(\.description).joined() }

extension Question {
    var optionLetters: String { letters(options.map(\.id)) }
    var optionTexts: [String] { options.map(\.text) }
    var correctLetters: String { letters(correct) }
}

extension ExamDraft {
    func question(_ id: UUID) -> Question { exam.question(id: id)! }
}

/// Câu một/nhiều đáp án với nội dung lựa chọn cho trước; `correct` theo chữ cái.
func makeQuestion(
    id: UUID = UUID(), type: QuestionType = .single, text: String = "Câu hỏi",
    options texts: [String], correct: String, image: String? = nil, explanation: String? = nil
) -> Question {
    Question(
        id: id, type: type, text: text, image: image,
        options: texts.enumerated().map { Option(id: OptionID(index: $0.offset)!, text: $0.element) },
        correct: correct.map { OptionID($0)! },
        explanation: explanation
    )
}

/// Chạy `operation` trên `draft`, rồi kiểm Hoàn tác (áp thay đổi ngược) đưa đề về đúng trạng thái
/// trước và Làm lại (áp thay đổi ngược của thay đổi ngược) đưa về đúng trạng thái sau. Để `draft`
/// ở trạng thái sau thao tác.
@discardableResult
func checkUndoRedo(
    _ draft: inout ExamDraft,
    sourceLocation: SourceLocation = #_sourceLocation,
    _ operation: (inout ExamDraft) throws -> ExamEdit
) throws -> ExamEdit {
    let before = draft
    let inverse = try operation(&draft)
    let after = draft
    let redo = try draft.apply(inverse)
    #expect(draft == before, "Hoàn tác không khôi phục đúng", sourceLocation: sourceLocation)
    let undoAgain = try draft.apply(redo)
    #expect(draft == after, "Làm lại không ra đúng trạng thái sau", sourceLocation: sourceLocation)
    // Hoàn tác lần hai (sau Làm lại) vẫn đúng.
    var copy = draft
    try copy.apply(undoAgain)
    #expect(copy == before, "Hoàn tác sau Làm lại không khôi phục đúng", sourceLocation: sourceLocation)
    return inverse
}

/// Ghi bằng `ExamPackageWriter` rồi đọc lại dễ (và nghiêm nếu `strict`); kiểm ra đúng `packageForSaving`.
@discardableResult
func checkRoundTrip(
    _ draft: ExamDraft, strict: Bool, sourceLocation: SourceLocation = #_sourceLocation
) throws -> ExamPackage {
    let data = try draft.fileData()
    let expected = draft.packageForSaving
    let lenient = try ExamPackageReader.read(data, mode: .lenient)
    #expect(lenient == expected, sourceLocation: sourceLocation)
    if strict {
        let strictRead = try ExamPackageReader.read(data, mode: .strict)
        #expect(strictRead == expected, sourceLocation: sourceLocation)
    }
    return lenient
}

/// Byte giả của ảnh (chỉ cần khác nhau; bộ đọc/ghi không giải mã ảnh).
func imageBytes(_ seed: UInt8, count: Int = 64) -> Data {
    Data([0x89, 0x50, 0x4e, 0x47] + (0 ..< count).map { UInt8(truncatingIfNeeded: Int(seed) &* 31 &+ $0) })
}
