import Foundation

/// Đề mẫu của Thư viện (Packages/ExamFeatures/Sources/LibraryData/Resources/Samples), ghi vào thư mục tạm khi
/// app mở lần đầu ở chế độ cô lập; hai bản app có cùng đề mẫu. Đổi đề mẫu thì sửa ở đây.
enum Samples {
    struct Exam {
        let id: String
        let code: String
        let questionCount: Int
        /// Đáp án đúng theo thứ tự câu trong file (không xáo), dạng chữ cái theo vị trí.
        let answers: [String]

        /// `accessibilityIdentifier` của thẻ đề trong lưới Thư viện.
        var cardID: String { "library.card.\(id.uppercased())" }
    }

    /// "Làm quen với Exam Suite": 12 câu, 10 phút, đậu 60%.
    static let lamQuen = Exam(
        id: "d55ecdea-98ea-446a-b3c3-9a9ce426be6d",
        code: "LAMQUEN",
        questionCount: 12,
        answers: ["A", "AB", "D", "A", "B", "C", "B", "D", "B", "ABD", "C", "A"]
    )

    /// "An toàn thông tin cơ bản": 23 câu (đủ cho Thi 20 câu ngẫu nhiên), 20 phút, đậu 70%.
    static let attt = Exam(
        id: "c1ad3171-dafe-4291-a8b7-12537edbd94d",
        code: "ATTT01",
        questionCount: 23,
        answers: []
    )

    /// Nội dung các lựa chọn đúng của "An toàn thông tin cơ bản" (`Fixtures/attt-correct-options.json` trong bundle test;
    /// BundledSampleTests kiểm khớp đề mẫu và không trùng nội dung lựa chọn sai nào). Luồng 2 dùng để chọn chắc chắn một
    /// lựa chọn sai khi câu được chọn ngẫu nhiên.
    static func atttCorrectOptionTexts() throws -> Set<String> {
        guard let url = Bundle(for: SamplesBundleToken.self).url(forResource: "attt-correct-options", withExtension: "json")
        else { throw CocoaError(.fileNoSuchFile) }
        return Set(try JSONDecoder().decode([String].self, from: Data(contentsOf: url)))
    }
}

/// Lớp mốc để tìm bundle của target UI test.
private final class SamplesBundleToken {}
