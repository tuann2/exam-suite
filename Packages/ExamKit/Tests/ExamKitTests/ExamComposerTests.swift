import Foundation
import Testing
@testable import ExamKit

// Tình huống tham khảo theo tên từ ExamComposerTests / ExamComposerRandomTests của
// Open Exam Suite (không chép code). Quy tắc: docs/product/scoring.md, mục "Chọn câu cho một phiên".

@Suite("SeededGenerator: SplitMix64 tái lập được trên mọi nền tảng")
struct SeededGeneratorTests {
    // Vector tính bằng bản Python của thuật toán chuẩn splitmix64.c (Vigna) và đối chiếu
    // giá trị công bố cho seed 0 (0xE220A8397B1DCDAF). Đổi các số này nghĩa là seed
    // đã lưu trong lịch sử làm bài sẽ ra đề khác.
    @Test("5 giá trị đầu với seed 0")
    func vectorSeedZero() {
        var g = SeededGenerator(seed: 0)
        let values = (0 ..< 5).map { _ in g.next() }
        #expect(values == [
            0xE220_A839_7B1D_CDAF,
            0x6E78_9E6A_A1B9_65F4,
            0x06C4_5D18_8009_454F,
            0xF88B_B8A8_724C_81EC,
            0x1B39_896A_51A8_749B,
        ])
    }

    @Test("5 giá trị đầu với seed 0x0123456789ABCDEF")
    func vectorOtherSeed() {
        var g = SeededGenerator(seed: 0x0123_4567_89AB_CDEF)
        let values = (0 ..< 5).map { _ in g.next() }
        #expect(values == [
            0x157A_3807_A48F_AA9D,
            0xD573_529B_34A1_D093,
            0x2F90_B72E_996D_CCBE,
            0xA2D4_1933_4C46_67EC,
            0x0140_4CE9_1493_8008,
        ])
    }

    @Test("nextInt(below:) khớp vector tham chiếu với cận nhỏ")
    func nextIntVectorSmallBound() {
        var g = SeededGenerator(seed: 0)
        let values = (0 ..< 10).map { _ in g.nextInt(below: 6) }
        #expect(values == [1, 0, 1, 4, 1, 0, 5, 2, 5, 2])
    }

    @Test("nextInt(below:) bỏ giá trị dưới ngưỡng (rejection sampling) đúng như tham chiếu")
    func nextIntRejectionPath() {
        // Cận 3·2^61: ngưỡng 2^64 mod cận = 2^62, nên giá trị thô thứ 3, 5, 7 của seed 0 bị bỏ.
        var g = SeededGenerator(seed: 0)
        let bound = 0x6000_0000_0000_0000
        let values = (0 ..< 6).map { _ in g.nextInt(below: bound) }
        #expect(values == [
            0x2220_A839_7B1D_CDAF,
            0x0E78_9E6A_A1B9_65F4,
            0x388B_B8A8_724C_81EC,
            0x53CB_9F0C_747E_A2EA,
            0x0584_133A_C916_AB3C,
            0x33B8_488C_368C_B0A6,
        ])
    }

    @Test("nextInt(below:) luôn trong khoảng", arguments: [1, 2, 3, 7, 100, 1_000_003, Int.max])
    func nextIntInRange(bound: Int) {
        var g = SeededGenerator(seed: UInt64(bound))
        for _ in 0 ..< 2_000 {
            let v = g.nextInt(below: bound)
            #expect(v >= 0 && v < bound)
        }
    }

    @Test("nextInt(below:) phân phối đều (kiểm thô)")
    func nextIntRoughlyUniform() {
        var g = SeededGenerator(seed: 2026)
        let bound = 6
        let samples = 60_000
        var counts = [Int](repeating: 0, count: bound)
        for _ in 0 ..< samples { counts[g.nextInt(below: bound)] += 1 }
        // Kỳ vọng 10.000 mỗi ô, độ lệch chuẩn ≈ 91; cho phép ±500 (> 5 sigma).
        for c in counts { #expect(abs(c - samples / bound) < 500) }

        // Cận không chia hết 2^64 và lớn: nửa dưới / nửa trên phải cân bằng.
        let big = 3 * (1 << 40) + 1
        var low = 0
        for _ in 0 ..< samples where g.nextInt(below: big) < big / 2 { low += 1 }
        #expect(abs(low - samples / 2) < 1_000)
    }

    @Test("Cùng seed cùng chuỗi, khác seed khác chuỗi")
    func sameSeedSameSequence() {
        var a = SeededGenerator(seed: 99)
        var b = SeededGenerator(seed: 99)
        var c = SeededGenerator(seed: 100)
        let sa = (0 ..< 20).map { _ in a.next() }
        let sb = (0 ..< 20).map { _ in b.next() }
        let sc = (0 ..< 20).map { _ in c.next() }
        #expect(sa == sb)
        #expect(sa != sc)
    }
}

@Suite("ExamComposer: chọn câu, xáo câu, xáo đáp án theo seed")
struct ExamComposerTests {
    // Id section và câu của đề mẫu fixtures/exams/kien-thuc-chung.
    static let physics = UUID(uuidString: "5e1d3b2a-7c4f-4e8d-9a1b-3c5d7e9f1a2b")!
    static let math = UUID(uuidString: "6f2e4c3b-8d5a-4f9e-ab2c-4d6e8f0a2b3c")!
    static let q1 = UUID(uuidString: "a91c2d3e-4f5a-4b6c-8d7e-9f0a1b2c3d4e")!
    static let q2 = UUID(uuidString: "b12d3e4f-5a6b-4c7d-9e8f-0a1b2c3d4e5f")!
    static let q3 = UUID(uuidString: "c23e4f5a-6b7c-4d8e-8f9a-1b2c3d4e5f6a")!
    static let q4 = UUID(uuidString: "d34f5a6b-7c8d-4e9f-9a0b-2c3d4e5f6a7b")!
    static let q5 = UUID(uuidString: "e45a6b7c-8d9e-4f0a-8b1c-3d4e5f6a7b8c")!

    static func sample() throws -> Exam {
        try ExamJSON.decode(Fixtures.data(Fixtures.exam("kien-thuc-chung")))
    }

    /// Đề dựng bằng code: `sectionCount` section, mỗi section `perSection` câu, 4 lựa chọn.
    static func large(sectionCount: Int = 10, perSection: Int = 200) -> Exam {
        let options = (0 ..< 4).map { Option(id: OptionID(index: $0)!, text: "Lựa chọn \($0)") }
        let sections = (0 ..< sectionCount).map { s in
            ExamSection(title: "Phần \(s)", questions: (0 ..< perSection).map { q in
                Question(type: .single, text: "Câu \(s)-\(q)", options: options, correct: [options[0].id])
            })
        }
        return Exam(title: "Đề lớn", passPercent: 70, timeLimitMinutes: 60, sections: sections)
    }

    static func letters(_ item: PaperItem) -> String { item.optionOrder.map(\.description).joined() }

    // MARK: Tất cả câu

    @Test("Tất cả câu: theo thứ tự file, nhớ section gốc, lựa chọn A, B, C…")
    func allInFileOrder() throws {
        let exam = try Self.sample()
        let paper = try ExamComposer.compose(exam, options: .init(seed: 1))
        #expect(paper.examID == exam.id)
        #expect(paper.questionIDs == [Self.q1, Self.q2, Self.q3, Self.q4, Self.q5])
        #expect(paper.items.map(\.sectionID) == [Self.physics, Self.physics, Self.physics, Self.math, Self.math])
        #expect(paper.items.map(Self.letters) == ["ABCD", "ABCD", "ABC", "ABC", "ABCDE"])
        #expect(paper.options == CompositionOptions(seed: 1))
    }

    @Test("Không xáo gì thì seed không ảnh hưởng")
    func seedIrrelevantWithoutShuffle() throws {
        let exam = try Self.sample()
        let a = try ExamComposer.compose(exam, options: .init(seed: 1))
        let b = try ExamComposer.compose(exam, options: .init(seed: 2))
        #expect(a.items == b.items)
    }

    @Test("Đề không có câu nào → noQuestions")
    func emptyExam() {
        let exam = Exam(title: "Rỗng", passPercent: 50, timeLimitMinutes: 10, sections: [
            ExamSection(title: "Trống", questions: []),
        ])
        #expect(throws: CompositionError.noQuestions) {
            try ExamComposer.compose(exam, options: .init(seed: 0))
        }
    }

    // MARK: Theo section

    @Test("Theo section: chỉ section được chọn, giữ thứ tự file")
    func sectionsSubset() throws {
        let exam = try Self.sample()
        let onlyMath = try ExamComposer.compose(exam, options: .init(selection: .sections([Self.math]), seed: 0))
        #expect(onlyMath.questionIDs == [Self.q4, Self.q5])
        #expect(onlyMath.items.allSatisfy { $0.sectionID == Self.math })

        // Thứ tự trong Set không quan trọng: luôn theo thứ tự section trong file.
        let both = try ExamComposer.compose(exam, options: .init(selection: .sections([Self.math, Self.physics]), seed: 0))
        #expect(both.questionIDs == [Self.q1, Self.q2, Self.q3, Self.q4, Self.q5])
    }

    @Test("Theo section: tập rỗng → noQuestions")
    func sectionsEmptySet() throws {
        let exam = try Self.sample()
        #expect(throws: CompositionError.noQuestions) {
            try ExamComposer.compose(exam, options: .init(selection: .sections([]), seed: 0))
        }
    }

    @Test("Theo section: chỉ chọn section không có câu → noQuestions")
    func sectionsOnlyEmptySection() throws {
        var exam = try Self.sample()
        let empty = ExamSection(title: "Trống", questions: [])
        exam.sections.append(empty)
        #expect(throws: CompositionError.noQuestions) {
            try ExamComposer.compose(exam, options: .init(selection: .sections([empty.id]), seed: 0))
        }
    }

    @Test("Theo section: id lạ → unknownSection")
    func sectionsUnknown() throws {
        let exam = try Self.sample()
        let stranger = UUID()
        #expect(throws: CompositionError.unknownSection(stranger)) {
            try ExamComposer.compose(exam, options: .init(selection: .sections([Self.math, stranger]), seed: 0))
        }
    }

    // MARK: N câu ngẫu nhiên

    @Test("Ngẫu nhiên: đúng N câu, không trùng, mọi câu thuộc đề, section gốc đúng", arguments: [1, 2, 3, 4, 5])
    func randomCountAndMembership(count: Int) throws {
        let exam = try Self.sample()
        let paper = try ExamComposer.compose(exam, options: .init(selection: .random(count: count), seed: 42))
        #expect(paper.items.count == count)
        #expect(Set(paper.questionIDs).count == count)
        for item in paper.items {
            #expect(exam.question(id: item.questionID) != nil)
            #expect(exam.section(containing: item.questionID)?.id == item.sectionID)
        }
    }

    @Test("Ngẫu nhiên: N bằng tổng số câu → đủ mọi câu")
    func randomAll() throws {
        let exam = try Self.sample()
        let paper = try ExamComposer.compose(exam, options: .init(selection: .random(count: 5), seed: 9))
        #expect(Set(paper.questionIDs) == [Self.q1, Self.q2, Self.q3, Self.q4, Self.q5])
    }

    @Test("Ngẫu nhiên: N ngoài 1…tổng → countOutOfRange", arguments: [0, -1, 6, 100])
    func randomOutOfRange(count: Int) throws {
        let exam = try Self.sample()
        #expect(throws: CompositionError.countOutOfRange(requested: count, available: 5)) {
            try ExamComposer.compose(exam, options: .init(selection: .random(count: count), seed: 42))
        }
    }

    @Test("Ngẫu nhiên trên đề rỗng → countOutOfRange với available 0")
    func randomOnEmptyExam() {
        let exam = Exam(title: "Rỗng", passPercent: 50, timeLimitMinutes: 10, sections: [])
        #expect(throws: CompositionError.countOutOfRange(requested: 1, available: 0)) {
            try ExamComposer.compose(exam, options: .init(selection: .random(count: 1), seed: 0))
        }
    }

    // Kết quả tính độc lập bằng bản Python của đúng thuật toán (SplitMix64, rejection
    // sampling, Fisher–Yates Durstenfeld, thứ tự tiêu thụ 1→2→3). Khoá tính tái lập
    // giữa macOS, Linux và các phiên bản Swift.
    @Test("Vector cố định: random 3, seed 42, giữ thứ tự sau xáo")
    func goldenRandom() throws {
        let exam = try Self.sample()
        let paper = try ExamComposer.compose(exam, options: .init(selection: .random(count: 3), seed: 42))
        #expect(paper.questionIDs == [Self.q2, Self.q3, Self.q1])
        #expect(paper.items.map(Self.letters) == ["ABCD", "ABC", "ABCD"])
    }

    @Test("Vector cố định: random 3 + xáo câu + xáo đáp án, seed 42")
    func goldenRandomShuffleAll() throws {
        let exam = try Self.sample()
        let options = CompositionOptions(selection: .random(count: 3), shuffleQuestions: true, shuffleOptions: true, seed: 42)
        let paper = try ExamComposer.compose(exam, options: options)
        #expect(paper.questionIDs == [Self.q1, Self.q2, Self.q3])
        #expect(paper.items.map(Self.letters) == ["ADCB", "BADC", "ABC"])
    }

    @Test("Vector cố định: tất cả + xáo câu + xáo đáp án, seed 7")
    func goldenAllShuffleAll() throws {
        let exam = try Self.sample()
        let options = CompositionOptions(shuffleQuestions: true, shuffleOptions: true, seed: 7)
        let paper = try ExamComposer.compose(exam, options: options)
        #expect(paper.questionIDs == [Self.q5, Self.q2, Self.q4, Self.q1, Self.q3])
        #expect(paper.items.map(Self.letters) == ["CADBE", "ADCB", "CAB", "BCDA", "ACB"])
        #expect(paper.items.map(\.sectionID) == [Self.math, Self.physics, Self.math, Self.physics, Self.physics])
    }

    @Test("Vector cố định: chỉ xáo đáp án, seed 0, thứ tự câu giữ nguyên")
    func goldenOptionsOnly() throws {
        let exam = try Self.sample()
        let paper = try ExamComposer.compose(exam, options: .init(shuffleOptions: true, seed: 0))
        #expect(paper.questionIDs == [Self.q1, Self.q2, Self.q3, Self.q4, Self.q5])
        #expect(paper.items.map(Self.letters) == ["CBAD", "CDBA", "BAC", "BAC", "DEACB"])
    }

    // MARK: Tái lập

    @Test("Cùng đề + cùng tuỳ chọn (kể cả seed) ⇒ cùng ExamPaper")
    func sameSeedSamePaper() throws {
        let exam = Self.large()
        for selection in [QuestionSelection.all, .random(count: 50), .sections([exam.sections[3].id, exam.sections[7].id])] {
            let options = CompositionOptions(selection: selection, shuffleQuestions: true, shuffleOptions: true, seed: 12_345)
            let a = try ExamComposer.compose(exam, options: options)
            let b = try ExamComposer.compose(exam, options: options)
            #expect(a == b)
        }
    }

    @Test("Khác seed thường ra đề khác")
    func differentSeedsDiffer() throws {
        let exam = Self.large()
        var papers = Set<[UUID]>()
        for seed in UInt64(1) ... 20 {
            papers.insert(try ExamComposer.compose(exam, options: .init(selection: .random(count: 50), seed: seed)).questionIDs)
        }
        #expect(papers.count == 20)

        let small = try Self.sample()
        let a = try ExamComposer.compose(small, options: .init(selection: .random(count: 3), seed: 1))
        let b = try ExamComposer.compose(small, options: .init(selection: .random(count: 3), seed: 2))
        #expect(a.questionIDs != b.questionIDs)
    }

    // MARK: Xáo câu, xáo đáp án

    @Test("Xáo câu: hoán vị đúng tập câu đã chọn, section gốc đi theo câu")
    func shuffleQuestionsIsPermutation() throws {
        let exam = Self.large()
        let plain = try ExamComposer.compose(exam, options: .init(seed: 5))
        let shuffled = try ExamComposer.compose(exam, options: .init(shuffleQuestions: true, seed: 5))
        #expect(shuffled.questionIDs != plain.questionIDs)
        #expect(Set(shuffled.items) == Set(plain.items))
    }

    @Test("Xáo đáp án: mỗi câu giữ đủ tập id lựa chọn gốc, không trùng")
    func shuffleOptionsKeepsIDs() throws {
        let exam = try Self.sample()
        for seed in UInt64(0) ..< 50 {
            let paper = try ExamComposer.compose(exam, options: .init(shuffleOptions: true, seed: seed))
            for item in paper.items {
                let original = exam.question(id: item.questionID)!.options.map(\.id)
                #expect(item.optionOrder.count == original.count)
                #expect(Set(item.optionOrder) == Set(original))
            }
        }
    }

    @Test("Xáo đáp án không đổi dữ liệu đề (đáp án đúng vẫn theo id gốc)")
    func shuffleOptionsDoesNotTouchExam() throws {
        let exam = try Self.sample()
        let before = exam
        _ = try ExamComposer.compose(exam, options: .init(shuffleQuestions: true, shuffleOptions: true, seed: 3))
        #expect(exam == before)
    }

    // MARK: Luyện lại câu sai

    @Test("Luyện lại câu sai: đúng các câu, theo thứ tự truyền vào, section gốc đúng")
    func questionsInGivenOrder() throws {
        let exam = try Self.sample()
        let paper = try ExamComposer.compose(exam, options: .init(selection: .questions([Self.q5, Self.q1, Self.q3]), seed: 0))
        #expect(paper.questionIDs == [Self.q5, Self.q1, Self.q3])
        #expect(paper.items.map(\.sectionID) == [Self.math, Self.physics, Self.physics])
    }

    @Test("Luyện lại câu sai: trùng id giữ lần đầu")
    func questionsDeduplicated() throws {
        let exam = try Self.sample()
        let paper = try ExamComposer.compose(exam, options: .init(selection: .questions([Self.q2, Self.q4, Self.q2, Self.q4, Self.q1]), seed: 0))
        #expect(paper.questionIDs == [Self.q2, Self.q4, Self.q1])
    }

    @Test("Luyện lại câu sai: id không thuộc đề → unknownQuestion")
    func questionsUnknown() throws {
        let exam = try Self.sample()
        let stranger = UUID()
        #expect(throws: CompositionError.unknownQuestion(stranger)) {
            try ExamComposer.compose(exam, options: .init(selection: .questions([Self.q1, stranger]), seed: 0))
        }
    }

    @Test("Luyện lại câu sai: danh sách rỗng → noQuestions")
    func questionsEmpty() throws {
        let exam = try Self.sample()
        #expect(throws: CompositionError.noQuestions) {
            try ExamComposer.compose(exam, options: .init(selection: .questions([]), seed: 0))
        }
    }

    // MARK: Đề lớn

    @Test("Đề 2.000 câu: chạy nhanh, kết quả đúng số lượng")
    func largeExamIsFast() throws {
        let exam = Self.large()
        #expect(exam.questionCount == 2_000)
        let clock = ContinuousClock()
        var paper: ExamPaper?
        let elapsed = try clock.measure {
            paper = try ExamComposer.compose(exam, options: .init(selection: .random(count: 2_000), shuffleQuestions: true, shuffleOptions: true, seed: 77))
        }
        #expect(paper?.items.count == 2_000)
        #expect(Set(paper?.questionIDs ?? []).count == 2_000)
        // Ngưỡng rộng cho bản debug và máy CI chậm; thực tế vài mili giây.
        #expect(elapsed < .seconds(1))
    }
}
