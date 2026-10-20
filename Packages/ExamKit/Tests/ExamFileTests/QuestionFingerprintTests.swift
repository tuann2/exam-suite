import ExamKit
import Foundation
import Testing
@testable import ExamFile

// Dấu vân tay câu (docs/product/exam-taking.md, "Lịch sử thi"): đổi dạng chuẩn làm mọi lần thi
// cũ báo "đã sửa", nên giá trị được khoá bằng vector cố định như SplitMix64. Vector tính độc lập
// bằng Python: json.dumps(obj, ensure_ascii=False, separators=(",", ":"), sort_keys=True) trên
// chuỗi NFC rồi hashlib.sha256. CI chạy cùng test trên Linux nên cùng giá trị trên hai nền tảng.

private func opt(_ letter: Character) -> OptionID { OptionID(letter)! }

private func options(_ pairs: [(Character, String)]) -> [Option] {
    pairs.map { Option(id: opt($0.0), text: $0.1) }
}

private enum Vectors {
    /// Câu tiếng Việt có ảnh và giải thích.
    static let q1 = Question(
        id: UUID(uuidString: "a91c2d3e-4f5a-4b6c-8d7e-9f0a1b2c3d4e")!,
        type: .single,
        text: "Đơn vị đo cường độ dòng điện là gì?",
        image: "media/9d5dc894e10f060d.png",
        options: options([("A", "Vôn"), ("B", "Ampe"), ("C", "Ôm"), ("D", "Oát")]),
        correct: [opt("B")],
        explanation: "Ampe (A) là đơn vị SI của cường độ dòng điện."
    )
    static let q1Canonical = #"{"correct":["B"],"explanation":"Ampe (A) là đơn vị SI của cường độ dòng điện.","image":"media/9d5dc894e10f060d.png","options":[{"id":"A","text":"Vôn"},{"id":"B","text":"Ampe"},{"id":"C","text":"Ôm"},{"id":"D","text":"Oát"}],"text":"Đơn vị đo cường độ dòng điện là gì?","type":"single"}"#
    static let q1Hash = "bcd9aaae267336ff9c2f93ebb35e7950e44e5b602933e47b59fe04d79631a8f3"

    /// Câu nhiều đáp án, không ảnh, không giải thích; chuỗi có ký tự phải escape, `/`, DEL, U+2028;
    /// `correct` không theo thứ tự.
    static let q2 = Question(
        type: .multiple,
        text: "Chọn \"đúng\" các mục:\n\t- a\\b / c\u{01}\u{7F}\u{2028}",
        options: options([("A", "x"), ("B", "y"), ("C", "z")]),
        correct: [opt("C"), opt("A")]
    )
    static let q2Canonical = "{\"correct\":[\"A\",\"C\"],\"explanation\":null,\"image\":null,"
        + "\"options\":[{\"id\":\"A\",\"text\":\"x\"},{\"id\":\"B\",\"text\":\"y\"},{\"id\":\"C\",\"text\":\"z\"}],"
        + "\"text\":\"Chọn \\\"đúng\\\" các mục:\\n\\t- a\\\\b / c\\u0001\u{7F}\u{2028}\",\"type\":\"multiple\"}"
    static let q2Hash = "0b7ff91f43f9d90a62a4fbea1b0325a2290a6dbbb5cf9a88044751523dbd986e"

    /// Giải thích là chuỗi rỗng (khác không có).
    static let q3 = Question(
        type: .single,
        text: "1 + 1 = ?",
        options: options([("A", "2"), ("B", "3")]),
        correct: [opt("A")],
        explanation: ""
    )
    static let q3Hash = "1f021a9b169bc8b98031cdfcee2b25b1d1c621e692ac88fad91fdd120eae6950"
}

@Suite("QuestionFingerprint: dạng chuẩn và vector cố định")
struct QuestionFingerprintVectorTests {
    @Test("Dạng chuẩn đúng từng byte")
    func canonicalForm() {
        #expect(QuestionFingerprint.canonicalJSON(of: Vectors.q1) == Vectors.q1Canonical)
        #expect(Array(QuestionFingerprint.canonicalJSON(of: Vectors.q2).utf8) == Array(Vectors.q2Canonical.utf8))
    }

    @Test("Vector cố định (khoá giá trị; đổi là làm mọi lần thi cũ báo đã sửa)")
    func fixedVectors() {
        #expect(QuestionFingerprint.fingerprint(of: Vectors.q1) == Vectors.q1Hash)
        #expect(QuestionFingerprint.fingerprint(of: Vectors.q2) == Vectors.q2Hash)
        #expect(QuestionFingerprint.fingerprint(of: Vectors.q3) == Vectors.q3Hash)
    }

    @Test("Chuỗi NFD và NFC cho cùng dấu vân tay")
    func nfdEqualsNFC() {
        var nfd = Vectors.q1
        nfd.text = nfd.text.decomposedStringWithCanonicalMapping
        nfd.explanation = nfd.explanation?.decomposedStringWithCanonicalMapping
        nfd.options = nfd.options.map { Option(id: $0.id, text: $0.text.decomposedStringWithCanonicalMapping) }
        // Chắc chắn đã khác ở mức scalar, nếu không test vô nghĩa.
        #expect(Array(nfd.text.unicodeScalars) != Array(Vectors.q1.text.unicodeScalars))
        #expect(Array(nfd.options[2].text.unicodeScalars) != Array(Vectors.q1.options[2].text.unicodeScalars))
        #expect(QuestionFingerprint.fingerprint(of: nfd) == Vectors.q1Hash)
    }

    @Test("Không phụ thuộc id câu và thứ tự trong correct")
    func ignoresIDAndCorrectOrder() {
        var q = Vectors.q1
        q.id = UUID()
        #expect(QuestionFingerprint.fingerprint(of: q) == Vectors.q1Hash)
        var q2 = Vectors.q2
        q2.correct = [opt("A"), opt("C")]
        #expect(QuestionFingerprint.fingerprint(of: q2) == Vectors.q2Hash)
    }

    @Test("Kết quả luôn là 64 ký tự hex chữ thường")
    func hexShape() {
        for q in [Vectors.q1, Vectors.q2, Vectors.q3] {
            let fp = QuestionFingerprint.fingerprint(of: q)
            #expect(fp.count == 64)
            #expect(fp.allSatisfy { "0123456789abcdef".contains($0) })
        }
    }
}

@Suite("QuestionFingerprint: đổi nội dung thì đổi dấu")
struct QuestionFingerprintChangeTests {
    static let edits: [(String, @Sendable (inout Question) -> Void)] = [
        ("loại câu", { $0.type = .multiple }),
        ("nội dung", { $0.text += " " }),
        ("nội dung: chữ hoa/thường", { $0.text = $0.text.replacingOccurrences(of: "Đơn", with: "đơn") }),
        ("ảnh: đổi", { $0.image = "media/0123456789abcdef.png" }),
        ("ảnh: bỏ", { $0.image = nil }),
        ("lựa chọn: sửa chữ", { $0.options[0].text = "Vôn kế" }),
        ("lựa chọn: thêm", { $0.options.append(Option(id: OptionID("E")!, text: "Culông")) }),
        ("lựa chọn: bỏ", { $0.options.removeLast() }),
        ("lựa chọn: đổi thứ tự", { $0.options.swapAt(0, 1) }),
        ("đáp án đúng: đổi", { $0.correct = [OptionID("A")!] }),
        ("đáp án đúng: thêm", { $0.correct.append(OptionID("C")!) }),
        ("giải thích: sửa", { $0.explanation = "Ampe." }),
        ("giải thích: bỏ", { $0.explanation = nil }),
        ("giải thích: rỗng", { $0.explanation = "" }),
    ]

    @Test("Mỗi thay đổi cho dấu khác vector gốc", arguments: 0 ..< edits.count)
    func changeAltersFingerprint(index: Int) {
        var q = Vectors.q1
        Self.edits[index].1(&q)
        #expect(QuestionFingerprint.fingerprint(of: q) != Vectors.q1Hash, "\(Self.edits[index].0)")
    }

    @Test("Mọi thay đổi cho dấu đôi một khác nhau")
    func changesAreDistinct() {
        var seen: Set<String> = [Vectors.q1Hash]
        for (name, edit) in Self.edits {
            var q = Vectors.q1
            edit(&q)
            #expect(seen.insert(QuestionFingerprint.fingerprint(of: q)).inserted, "\(name)")
        }
    }

    @Test("Ranh giới giữa các trường không nhập nhằng: dời chữ giữa nội dung và lựa chọn đổi dấu")
    func fieldBoundaries() {
        let a = Question(type: .single, text: "ab", options: options([("A", "c")]), correct: [opt("A")])
        let b = Question(type: .single, text: "a", options: options([("A", "bc")]), correct: [opt("A")])
        #expect(QuestionFingerprint.fingerprint(of: a) != QuestionFingerprint.fingerprint(of: b))
    }
}

@Suite("QuestionFingerprint: cả đề")
struct ExamFingerprintsTests {
    @Test("Mọi câu của đề, theo id; khớp hàm từng câu")
    func allQuestions() throws {
        let exam = try ExamJSON.decode(RepoPaths.examJSON("kien-thuc-chung"))
        let fps = QuestionFingerprint.fingerprints(of: exam)
        #expect(fps.count == exam.questionCount)
        for q in exam.allQuestions {
            #expect(fps[q.id] == QuestionFingerprint.fingerprint(of: q))
        }
        // Câu đầu của fixture có cùng nội dung với vector q1.
        #expect(fps[Vectors.q1.id] == Vectors.q1Hash)
    }

    @Test("Dùng cho AttemptRecord: lưu dấu vân tay thật rồi đọc lại; sửa câu sau lần thi thì dấu khác")
    func attemptRecordIntegration() throws {
        var exam = try ExamJSON.decode(RepoPaths.examJSON("kien-thuc-chung"))
        let paper = try ExamComposer.compose(exam, options: CompositionOptions(selection: .random(count: 3), seed: 9))
        var session = try ExamSession(
            exam: exam, paper: paper, mode: .exam, timeLimitMinutes: nil, candidateName: "A", clock: SystemSessionClock())
        try session.openReview()
        try session.submit()
        let record = try AttemptRecord(session: session, fingerprints: QuestionFingerprint.fingerprints(of: exam))
        let decoded = try AttemptRecord.decode(record.encoded())
        #expect(decoded == record)

        // Xem lại sau khi sửa đề: đúng câu đã sửa có dấu khác.
        let edited = paper.questionIDs[0]
        for s in exam.sections.indices {
            for q in exam.sections[s].questions.indices where exam.sections[s].questions[q].id == edited {
                exam.sections[s].questions[q].text += " (sửa)"
            }
        }
        let now = QuestionFingerprint.fingerprints(of: exam)
        for id in paper.questionIDs {
            #expect((now[id] != decoded.fingerprints[id]) == (id == edited))
        }
    }

    @Test("Id câu trùng (đề sai): lấy lần xuất hiện đầu")
    func duplicateIDKeepsFirst() {
        let id = UUID()
        var first = Vectors.q3
        first.id = id
        var second = Vectors.q2
        second.id = id
        let exam = Exam(title: "t", passPercent: 50, timeLimitMinutes: 10, sections: [
            ExamSection(title: "1", questions: [first]),
            ExamSection(title: "2", questions: [second]),
        ])
        #expect(QuestionFingerprint.fingerprints(of: exam) == [id: Vectors.q3Hash])
    }
}
