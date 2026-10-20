import Foundation
import Testing
@testable import ExamKit

// Codable với khoá cố định cho dữ liệu lần thi (docs/product/exam-taking.md, "Dữ liệu một lần thi"):
// QuestionSelection, CompositionOptions, PaperItem, ExamPaper, QuestionOutcome, SectionScore, ScoreResult.

private func encode<T: Encodable>(_ value: T) throws -> Data {
    let e = JSONEncoder()
    e.outputFormatting = [.sortedKeys]
    return try e.encode(value)
}

private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
    try JSONDecoder().decode(type, from: Data(json.utf8))
}

private func roundTrip<T: Codable & Equatable>(_ value: T) throws -> T {
    try JSONDecoder().decode(T.self, from: encode(value))
}

/// JSON của `value` bằng JSON mẫu `expected` (so ngữ nghĩa, không so thứ tự khoá hay khoảng trắng).
private func expectJSON<T: Encodable>(
    _ value: T, _ expected: String, sourceLocation: SourceLocation = #_sourceLocation
) throws {
    let data = try encode(value)
    let actual = try JSONTree.parse(data)
    let golden = try JSONTree.parse(Data(expected.utf8))
    let text = String(decoding: data, as: UTF8.self)
    #expect(JSONCompare.equal(actual, golden), "\(text)", sourceLocation: sourceLocation)
}

/// Lỗi giải mã là `DecodingError` mang `PayloadConsistencyError` (dữ liệu mâu thuẫn).
private func isInconsistency(_ error: any Error) -> Bool {
    if case let DecodingError.dataCorrupted(context) = error {
        return context.underlyingError is PayloadConsistencyError
    }
    return false
}

/// `body` phải ném lỗi "dữ liệu mâu thuẫn" (không phải lỗi cú pháp hay lỗi khác).
private func expectInconsistent(sourceLocation: SourceLocation = #_sourceLocation, _ body: () throws -> Void) {
    do {
        try body()
        Issue.record("Lẽ ra bị từ chối vì mâu thuẫn", sourceLocation: sourceLocation)
    } catch {
        #expect(isInconsistency(error), "\(error)", sourceLocation: sourceLocation)
    }
}

private let s1 = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
private let s2 = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!
private let s3 = UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!

@Suite("Codable: QuestionSelection và CompositionOptions")
struct CompositionCodableTests {
    @Test("Bốn cách chọn câu: JSON mẫu cố định và vòng mã hoá–giải mã")
    func selectionGolden() throws {
        let cases: [(QuestionSelection, String)] = [
            (.all, #"{"kind":"all"}"#),
            (.sections([s3, s1, s2]), #"{"kind":"sections","sectionIDs":["11111111-1111-4111-8111-111111111111","22222222-2222-4222-8222-222222222222","aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"]}"#),
            (.random(count: 7), #"{"kind":"random","count":7}"#),
            (.questions([s3, s1, s3]), #"{"kind":"questions","questionIDs":["aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","11111111-1111-4111-8111-111111111111","aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"]}"#),
        ]
        for (selection, json) in cases {
            try expectJSON(selection, json)
            #expect(try roundTrip(selection) == selection)
            #expect(try decode(QuestionSelection.self, json) == selection)
        }
    }

    @Test("Tập section ghi theo thứ tự sắp xếp: cùng tập cho cùng byte")
    func sectionsDeterministic() throws {
        let a = try encode(QuestionSelection.sections([s1, s2, s3]))
        let b = try encode(QuestionSelection.sections([s3, s2, s1]))
        #expect(a == b)
    }

    @Test("Đọc UUID chữ hoa", arguments: [
        #"{"kind":"sections","sectionIDs":["AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA"]}"#,
    ])
    func uppercaseUUID(json: String) throws {
        #expect(try decode(QuestionSelection.self, json) == .sections([s3]))
    }

    @Test("Từ chối loại lạ, thiếu khoá, section trùng", arguments: [
        #"{"kind":"some"}"#,
        #"{}"#,
        #"{"kind":"random"}"#,
        #"{"kind":"random","count":"3"}"#,
        #"{"kind":"sections"}"#,
        #"{"kind":"sections","sectionIDs":["11111111-1111-4111-8111-111111111111","11111111-1111-4111-8111-111111111111"]}"#,
        #"{"kind":"questions","questionIDs":["không-phải-uuid"]}"#,
    ])
    func rejectsBadSelection(json: String) {
        #expect(throws: DecodingError.self) { try decode(QuestionSelection.self, json) }
    }

    @Test("CompositionOptions: JSON mẫu cố định")
    func optionsGolden() throws {
        let options = CompositionOptions(selection: .random(count: 3), shuffleQuestions: true, shuffleOptions: false, seed: 42)
        try expectJSON(options, #"{"selection":{"kind":"random","count":3},"shuffleQuestions":true,"shuffleOptions":false,"seed":"42"}"#)
    }

    @Test("Seed UInt64 giữ đủ 64 bit (ghi thành chuỗi thập phân)", arguments: [
        0, 1, 9_007_199_254_740_992, 9_007_199_254_740_993, 9_223_372_036_854_775_807,
        18_446_744_073_709_551_614, UInt64.max,
    ] as [UInt64])
    func seedPrecision(seed: UInt64) throws {
        let options = CompositionOptions(seed: seed)
        #expect(try roundTrip(options) == options)
        let json = String(decoding: try encode(options), as: UTF8.self)
        #expect(json.contains("\"seed\":\"\(seed)\""))
    }

    @Test("Seed UInt64.max: JSON mẫu cố định")
    func seedMaxGolden() throws {
        try expectJSON(CompositionOptions(seed: .max),
                       #"{"selection":{"kind":"all"},"shuffleQuestions":false,"shuffleOptions":false,"seed":"18446744073709551615"}"#)
    }

    @Test("Từ chối seed không phải chuỗi số nguyên không dấu 64 bit", arguments: [
        #"5"#, #""-1""#, #""+1""#, #""""#, #"" 1""#, #""1.0""#, #""0x10""#, #""1e3""#,
        #""18446744073709551616""#, #""٣""#, #"null"#,
    ])
    func rejectsBadSeed(seed: String) {
        let json = #"{"selection":{"kind":"all"},"shuffleQuestions":false,"shuffleOptions":false,"seed":\#(seed)}"#
        #expect(throws: DecodingError.self) { try decode(CompositionOptions.self, json) }
    }
}

@Suite("Codable: PaperItem và ExamPaper")
struct PaperCodableTests {
    @Test("Đề tạo từ fixture (xáo câu, xáo đáp án, seed lớn): vòng mã hoá–giải mã")
    func paperRoundTrip() throws {
        let exam = try AttemptSamples.exam()
        for selection in [QuestionSelection.all, .random(count: 3), .sections([AttemptSamples.math]),
                          .questions([AttemptSamples.q5, AttemptSamples.q1])] {
            let options = CompositionOptions(
                selection: selection, shuffleQuestions: true, shuffleOptions: true, seed: AttemptSamples.bigSeed)
            let paper = try ExamComposer.compose(exam, options: options)
            #expect(try roundTrip(paper) == paper)
        }
    }

    @Test("PaperItem: JSON mẫu cố định")
    func itemGolden() throws {
        let item = PaperItem(questionID: s1, sectionID: s3, optionOrder: [OptionID("C")!, OptionID("A")!, OptionID("B")!])
        try expectJSON(item, #"{"questionID":"11111111-1111-4111-8111-111111111111","sectionID":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","optionOrder":["C","A","B"]}"#)
    }

    @Test("ExamPaper: JSON mẫu cố định")
    func paperGolden() throws {
        let paper = ExamPaper(
            examID: s2,
            options: CompositionOptions(seed: 7),
            items: [PaperItem(questionID: s1, sectionID: s3, optionOrder: [OptionID("A")!])]
        )
        try expectJSON(paper, #"""
        {"examID":"22222222-2222-4222-8222-222222222222",
         "options":{"selection":{"kind":"all"},"shuffleQuestions":false,"shuffleOptions":false,"seed":"7"},
         "items":[{"questionID":"11111111-1111-4111-8111-111111111111","sectionID":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","optionOrder":["A"]}]}
        """#)
    }

    @Test("Từ chối lựa chọn trùng trong optionOrder và câu trùng trong đề")
    func rejectsDuplicates() {
        let dupOption = #"{"questionID":"11111111-1111-4111-8111-111111111111","sectionID":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","optionOrder":["A","B","A"]}"#
        expectInconsistent { _ = try decode(PaperItem.self, dupOption) }

        let item = #"{"questionID":"11111111-1111-4111-8111-111111111111","sectionID":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","optionOrder":["A"]}"#
        let upper = item.replacingOccurrences(of: "11111111-1111-4111-8111-111111111111", with: "11111111-1111-4111-8111-111111111111".uppercased())
        let dupQuestion = #"{"examID":"22222222-2222-4222-8222-222222222222","options":{"selection":{"kind":"all"},"shuffleQuestions":false,"shuffleOptions":false,"seed":"7"},"items":["#
            + item + "," + upper + "]}"
        expectInconsistent { _ = try decode(ExamPaper.self, dupQuestion) }
    }

    @Test("Từ chối mã lựa chọn sai", arguments: [#"["a"]"#, #"["AB"]"#, #"[""]"#, #"[1]"#])
    func rejectsBadOptionID(order: String) {
        let json = #"{"questionID":"11111111-1111-4111-8111-111111111111","sectionID":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","optionOrder":\#(order)}"#
        #expect(throws: DecodingError.self) { try decode(PaperItem.self, json) }
    }
}

@Suite("Codable: ScoreResult")
struct ScoreResultCodableTests {
    /// Kết quả chấm thật từ fixture: đúng q1, q4; sai q2; bỏ q3, q5 → 2/5.
    static func sample() throws -> ScoreResult {
        let exam = try AttemptSamples.exam()
        let sheet: AnswerSheet = [
            AttemptSamples.q1: [OptionID("B")!],
            AttemptSamples.q2: [OptionID("A")!],
            AttemptSamples.q4: [OptionID("B")!],
        ]
        return try Scorer.score(
            exam: exam,
            questionIDs: [AttemptSamples.q5, AttemptSamples.q1, AttemptSamples.q2, AttemptSamples.q3, AttemptSamples.q4],
            answers: sheet
        )
    }

    static func tree() throws -> Any { try JSONTree.parse(encode(sample())) }

    @Test("QuestionOutcome ghi bằng tên cố định")
    func outcomeRawValues() throws {
        try expectJSON([QuestionOutcome.correct, .incorrect, .unanswered], #"["correct","incorrect","unanswered"]"#)
        #expect(throws: DecodingError.self) { try decode([QuestionOutcome].self, #"["wrong"]"#) }
    }

    @Test("SectionScore: JSON mẫu cố định")
    func sectionGolden() throws {
        try expectJSON(SectionScore(sectionID: s1, title: "Mạng", total: 4, correct: 3),
                       #"{"sectionID":"11111111-1111-4111-8111-111111111111","title":"Mạng","total":4,"correct":3}"#)
    }

    @Test("Vòng mã hoá–giải mã: kết quả thật, đề rỗng câu (0/0), mọi câu đúng")
    func roundTrips() throws {
        let exam = try AttemptSamples.exam()
        let all = exam.allQuestions.map(\.id)
        var perfect: AnswerSheet = [:]
        for q in exam.allQuestions { perfect[q.id] = q.correctSet }
        let results = [
            try Self.sample(),
            try Scorer.score(exam: exam, questionIDs: [], answers: [:]),
            try Scorer.score(exam: exam, questionIDs: all, answers: perfect),
        ]
        for result in results {
            #expect(try roundTrip(result) == result)
        }
        #expect(results[2].passed)
    }

    @Test("JSON mẫu cố định của kết quả thật")
    func golden() throws {
        try expectJSON(try Self.sample(), #"""
        {"total":5,"correct":2,"score1000":400,"percent":40,"passPercent":70,"passed":false,
         "sections":[
           {"sectionID":"5e1d3b2a-7c4f-4e8d-9a1b-3c5d7e9f1a2b","title":"Vật lý","total":3,"correct":1},
           {"sectionID":"6f2e4c3b-8d5a-4f9e-ab2c-4d6e8f0a2b3c","title":"Toán","total":2,"correct":1}],
         "outcomes":{
           "a91c2d3e-4f5a-4b6c-8d7e-9f0a1b2c3d4e":"correct",
           "b12d3e4f-5a6b-4c7d-9e8f-0a1b2c3d4e5f":"incorrect",
           "c23e4f5a-6b7c-4d8e-8f9a-1b2c3d4e5f6a":"unanswered",
           "d34f5a6b-7c8d-4e9f-9a0b-2c3d4e5f6a7b":"correct",
           "e45a6b7c-8d9e-4f0a-8b1c-3d4e5f6a7b8c":"unanswered"},
         "questionIDs":[
           "e45a6b7c-8d9e-4f0a-8b1c-3d4e5f6a7b8c","a91c2d3e-4f5a-4b6c-8d7e-9f0a1b2c3d4e",
           "b12d3e4f-5a6b-4c7d-9e8f-0a1b2c3d4e5f","c23e4f5a-6b7c-4d8e-8f9a-1b2c3d4e5f6a",
           "d34f5a6b-7c8d-4e9f-9a0b-2c3d4e5f6a7b"]}
        """#)
    }

    static let q1 = "a91c2d3e-4f5a-4b6c-8d7e-9f0a1b2c3d4e"
    static let q3 = "c23e4f5a-6b7c-4d8e-8f9a-1b2c3d4e5f6a"

    /// Mỗi phép sửa làm kết quả mâu thuẫn ở đúng một điểm.
    static let inconsistencies: [(String, @Sendable (inout Any) -> Void)] = [
        ("total lệch số câu", { JSONTree.set(&$0, ["total"], 6) }),
        ("questionIDs trùng", { JSONTree.modify(&$0, ["questionIDs"]) { $0 = ($0 as! [Any]) + [q1] } }),
        ("outcomes thiếu một câu", { JSONTree.remove(&$0, ["outcomes", q3]) }),
        ("outcomes thừa một câu", { JSONTree.set(&$0, ["outcomes", UUID().uuidString.lowercased()], "correct") }),
        ("correct lệch số câu đúng", {
            JSONTree.set(&$0, ["correct"], 3); JSONTree.set(&$0, ["score1000"], 600); JSONTree.set(&$0, ["percent"], 60)
        }),
        ("outcome đổi làm correct lệch", { JSONTree.set(&$0, ["outcomes", q3], "correct") }),
        ("tổng total theo section lệch", { JSONTree.set(&$0, ["sections", "0", "total"], 4) }),
        ("tổng correct theo section lệch", { JSONTree.set(&$0, ["sections", "0", "correct"], 0) }),
        ("section correct > total", { JSONTree.set(&$0, ["sections", "1", "correct"], 3) }),
        ("section correct âm", { JSONTree.set(&$0, ["sections", "1", "correct"], -1) }),
        ("section trùng id", {
            JSONTree.modify(&$0, ["sections"]) { s in
                var a = s as! [Any]
                var dup = a[0] as! [String: Any]
                dup["total"] = 0
                dup["correct"] = 0
                a.append(dup)
                s = a
            }
        }),
        ("score1000 sai", { JSONTree.set(&$0, ["score1000"], 401) }),
        ("percent sai", { JSONTree.set(&$0, ["percent"], 41) }),
        ("passed sai", { JSONTree.set(&$0, ["passed"], true) }),
        ("passPercent đổi làm passed sai", { JSONTree.set(&$0, ["passPercent"], 40) }),
        ("passPercent tràn khi nhân 10", { JSONTree.set(&$0, ["passPercent"], Int.max) }),
        ("tổng section tràn số", {
            JSONTree.set(&$0, ["sections", "0", "total"], Int.max)
            JSONTree.set(&$0, ["sections", "1", "total"], Int.max)
        }),
    ]

    @Test("Kết quả mâu thuẫn bị từ chối (không crash kể cả số rất lớn)", arguments: 0 ..< inconsistencies.count)
    func rejectsInconsistent(index: Int) throws {
        var tree = try Self.tree()
        Self.inconsistencies[index].1(&tree)
        let data = try JSONTree.data(tree)
        expectInconsistent { _ = try JSONDecoder().decode(ScoreResult.self, from: data) }
    }

    @Test("Mọi khoá là bắt buộc", arguments: [
        "total", "correct", "score1000", "percent", "passPercent", "passed", "sections", "outcomes", "questionIDs",
    ])
    func requiresAllKeys(key: String) throws {
        var tree = try Self.tree()
        JSONTree.remove(&tree, [key])
        let data = try JSONTree.data(tree)
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(ScoreResult.self, from: data) }
    }

    @Test("passPercent ngoài 0–100 bị từ chối (passed vẫn khớp công thức)", arguments: [(-1, true), (101, false)])
    func rejectsPassPercentOutOfRange(passPercent: Int, passed: Bool) throws {
        var tree = try Self.tree()
        JSONTree.set(&tree, ["passPercent"], passPercent)
        JSONTree.set(&tree, ["passed"], passed)
        let data = try JSONTree.data(tree)
        expectInconsistent { _ = try JSONDecoder().decode(ScoreResult.self, from: data) }
    }

    @Test("passPercent 0 và 100 được nhận (đối chứng)", arguments: [0, 100])
    func acceptsPassPercentBounds(passPercent: Int) throws {
        // Sửa JSON của kết quả mẫu (400/1000): chỉ đổi ngưỡng và passed cho khớp.
        var tree = try Self.tree()
        JSONTree.set(&tree, ["passPercent"], passPercent)
        JSONTree.set(&tree, ["passed"], passPercent == 0)
        let decoded = try JSONDecoder().decode(ScoreResult.self, from: JSONTree.data(tree))
        #expect(decoded.passPercent == passPercent)
        #expect(decoded.passed == (passPercent == 0))

        // Kết quả chấm thật với ngưỡng biên, cả khi đúng hết (100% đậu ở ngưỡng 100).
        var exam = try AttemptSamples.exam()
        exam.passPercent = passPercent
        var perfect: AnswerSheet = [:]
        for q in exam.allQuestions { perfect[q.id] = q.correctSet }
        let ids = exam.allQuestions.map(\.id)
        for sheet in [perfect, AnswerSheet()] {
            let result = try Scorer.score(exam: exam, questionIDs: ids, answers: sheet)
            #expect(try roundTrip(result) == result)
        }
    }

    @Test("outcomes: khoá không phải UUID hoặc hai khoá cùng UUID bị từ chối")
    func rejectsBadOutcomeKeys() throws {
        var tree = try Self.tree()
        JSONTree.set(&tree, ["outcomes", "abc"], "correct")
        let bad = try JSONTree.data(tree)
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(ScoreResult.self, from: bad) }

        tree = try Self.tree()
        JSONTree.set(&tree, ["outcomes", Self.q3.uppercased()], "unanswered")
        let dup = try JSONTree.data(tree)
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(ScoreResult.self, from: dup) }
    }
}
