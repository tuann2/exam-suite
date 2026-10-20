import ExamFile
import ExamKit
import Foundation

/// Đề chuẩn để đo hiệu năng (docs/product/large-exams.md, mục "Đề chuẩn để đo"): bản Swift của
/// `scripts/gen_large_exam.py`, cùng seed thì **cùng một đề** (cùng id, chữ, đáp án và byte ảnh). Thuật toán và
/// thứ tự rút số ngẫu nhiên mô tả ở đầu script; đổi một bên thì đổi bên kia và file dấu vân tay chung
/// (`gen_large_exam.py --check`, `StandardExamTests`).
///
/// Chỉ dùng trong test và đo đạc; không app nào phụ thuộc module này.
public enum StandardExam {
    public static let defaultSeed: UInt64 = 20_261_016
    public static let defaultQuestions = 2_000
    public static let defaultSections = 20

    /// Đề chuẩn mặc định (2.000 câu, 20 phần, 200 ảnh ~60 MB), sinh một lần cho cả tiến trình test.
    public static let standard: ExamPackage = make()

    /// Sinh đề `questions` câu chia cho `sections` phần (phần đầu nhận câu dư).
    /// - Precondition: `sections ≥ 1`, `questions ≥ sections`.
    public static func make(
        seed: UInt64 = defaultSeed,
        questions: Int = defaultQuestions,
        sections: Int = defaultSections
    ) -> ExamPackage {
        precondition(sections >= 1 && questions >= sections, "cần sections ≥ 1 và questions ≥ sections")
        var rng = SeededGenerator(seed: seed)
        let examID = makeUUID(&rng)
        let n = questions
        let multiple = Set(permutation(n, &rng).prefix(n * 20 / 100))
        let manyOptions = Set(permutation(n, &rng).prefix(n * 5 / 100))
        let withImage = Set(permutation(n, &rng).prefix(n * 10 / 100))
        let withExplanation = Set(permutation(n, &rng).prefix(n * 50 / 100))
        let pool = withImage.isEmpty ? [] : NoisePNG.pool(seed: seed)

        var media: [String: Data] = [:]
        var imageCount = 0
        var examSections: [ExamSection] = []
        let base = n / sections
        let extra = n % sections
        var k = 0
        for s in 0 ..< sections {
            let sectionID = makeUUID(&rng)
            var examQuestions: [Question] = []
            for _ in 0 ..< base + (s < extra ? 1 : 0) {
                let questionID = makeUUID(&rng)
                let optionCount = manyOptions.contains(k) ? 8 + rng.nextInt(below: 5) : 4
                let text = paragraph(&rng, prefix: "Câu \(k + 1).", minLength: 200, spread: 300)
                var options: [Option] = []
                for i in 0 ..< optionCount {
                    let term = StandardExamWords.optionTerms[rng.nextInt(below: StandardExamWords.optionTerms.count)]
                    let qualifier = StandardExamWords.qualifiers[rng.nextInt(below: StandardExamWords.qualifiers.count)]
                    options.append(Option(id: OptionID(index: i)!, text: "\(term) \(qualifier)"))
                }
                let isMultiple = multiple.contains(k)
                var correct: [OptionID]
                if isMultiple {
                    let maxCorrect = optionCount == 4 ? 3 : 4
                    let count = 2 + rng.nextInt(below: maxCorrect - 1)
                    var indices = Array(0 ..< optionCount)
                    for i in 0 ..< count {
                        let j = i + rng.nextInt(below: optionCount - i)
                        indices.swapAt(i, j)
                    }
                    correct = indices.prefix(count).sorted().map { OptionID(index: $0)! }
                } else {
                    correct = [OptionID(index: rng.nextInt(below: optionCount))!]
                }
                var image: String?
                if withImage.contains(k) {
                    let data = NoisePNG.image(pool: pool, ordinal: imageCount)
                    imageCount += 1
                    let name = NoisePNG.mediaPath(for: data)
                    media[name] = data
                    image = name
                }
                let explanation = withExplanation.contains(k)
                    ? paragraph(&rng, prefix: "", minLength: 60, spread: 140)
                    : nil
                examQuestions.append(Question(
                    id: questionID,
                    type: isMultiple ? .multiple : .single,
                    text: text,
                    image: image,
                    options: options,
                    correct: correct,
                    explanation: explanation
                ))
                k += 1
            }
            let topic = StandardExamWords.topics[s % StandardExamWords.topics.count]
            examSections.append(ExamSection(id: sectionID, title: "Phần \(s + 1): \(topic)", questions: examQuestions))
        }
        let exam = Exam(
            id: examID,
            title: "Đề chuẩn \(n) câu (seed \(seed))",
            code: "DECHUAN-\(n)",
            passPercent: 70,
            timeLimitMinutes: 180,
            hideAnswers: false,
            instructions: "Đề sinh tự động để đo hiệu năng (docs/product/large-exams.md). **Không** dùng để thi thật.",
            sections: examSections
        )
        return ExamPackage(exam: exam, media: media)
    }

    /// Dạng chính tắc của đề (mỗi dòng một đối tượng, tab ngăn trường), giống `canonical_text` của script;
    /// SHA-256 của chuỗi này là dấu vân tay hai bên so với cùng file `fixtures/large-exam.digest`.
    public static func canonicalText(_ package: ExamPackage) -> String {
        let exam = package.exam
        var lines = [[
            "exam", exam.id.uuidString.lowercased(), exam.title, exam.code ?? "", String(exam.passPercent),
            String(exam.timeLimitMinutes), exam.hideAnswers ? "1" : "0", exam.instructions ?? "",
        ].joined(separator: "\t")]
        for section in exam.sections {
            lines.append(["section", section.id.uuidString.lowercased(), section.title].joined(separator: "\t"))
            for q in section.questions {
                lines.append([
                    "question", q.id.uuidString.lowercased(), q.type.rawValue, q.text, q.image ?? "",
                    q.correct.map(\.description).joined(separator: ","), q.explanation ?? "",
                ].joined(separator: "\t"))
                for o in q.options {
                    lines.append(["option", o.id.description, o.text].joined(separator: "\t"))
                }
            }
        }
        for name in package.media.keys.sorted() {
            lines.append("media\t\(name)\t\(package.media[name]!.count)")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: - Phần dùng chung với script

    /// UUID từ hai số 64 bit (big-endian), gắn bit phiên bản 4 và biến thể RFC 4122.
    static func makeUUID(_ rng: inout SeededGenerator) -> UUID {
        var bytes: [UInt8] = []
        for value in [rng.next(), rng.next()] {
            for shift in stride(from: 56, through: 0, by: -8) { bytes.append(UInt8(truncatingIfNeeded: value >> UInt64(shift))) }
        }
        bytes[6] = (bytes[6] & 0x0F) | 0x40
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    /// Hoán vị Fisher–Yates của `0..<n` (i từ n−1 xuống 1, j = nextInt(below: i + 1)).
    static func permutation(_ n: Int, _ rng: inout SeededGenerator) -> [Int] {
        var items = Array(0 ..< n)
        var i = n - 1
        while i > 0 {
            let j = rng.nextInt(below: i + 1)
            items.swapAt(i, j)
            i -= 1
        }
        return items
    }

    /// Nối câu mẫu (1/8 đậm, 1/8 nghiêng) tới khi đủ độ dài đích, đếm theo Unicode code point.
    static func paragraph(_ rng: inout SeededGenerator, prefix: String, minLength: Int, spread: Int) -> String {
        let target = minLength + rng.nextInt(below: spread + 1)
        var text = prefix
        var length = text.unicodeScalars.count
        while length < target {
            var fragment = StandardExamWords.fragments[rng.nextInt(below: StandardExamWords.fragments.count)]
            switch rng.nextInt(below: 8) {
            case 0: fragment = "**\(fragment)**"
            case 1: fragment = "*\(fragment)*"
            default: break
            }
            if text.isEmpty {
                text = fragment
            } else {
                text += " " + fragment
                length += 1
            }
            length += fragment.unicodeScalars.count
        }
        return text
    }
}
