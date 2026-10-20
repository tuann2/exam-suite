import Foundation

/// Lỗi khi tạo hoặc đọc dữ liệu chi tiết của một lần thi.
public enum AttemptRecordError: Error, Equatable, Sendable {
    /// Chỉ lưu được phiên đã nộp (`phase == .submitted`).
    case sessionNotSubmitted(phase: SessionPhase)
    /// Thiếu dấu vân tay của một câu trong đề đã tạo.
    case missingFingerprint(questionID: UUID)
    /// Dấu vân tay không phải 64 ký tự hex chữ thường (SHA-256).
    case invalidFingerprint(questionID: UUID)
    /// Payload ghi bởi bản app mới hơn: `found` > `supported` (= `AttemptRecord.currentPayloadVersion`).
    case unsupportedPayloadVersion(found: Int, supported: Int)
    /// Không đọc được: không phải JSON, thiếu khoá, sai kiểu, giá trị không hợp lệ.
    case malformedPayload(String)
    /// Đọc được nhưng mâu thuẫn (id câu không thuộc đề, tổng lệch…); lý do ở chuỗi kèm theo.
    case inconsistentPayload(String)
}

/// Dữ liệu chi tiết của một lần thi đã nộp, lưu ở cột `payload` của lần thi trong Thư viện
/// (docs/product/exam-taking.md, mục "Dữ liệu một lần thi").
///
/// Tóm tắt (thí sinh, thời điểm, thời gian làm, điểm) nằm ở `Attempt` của LibraryData, không lặp
/// lại ở đây. Bản ghi đủ để mở lại Kết quả mà không cần file đề, và để Xem lại bài với nội dung câu
/// lấy từ file đề hiện tại: dấu vân tay từng câu cho biết câu nào đã sửa sau lần thi.
///
/// Chỉ tạo bằng `init(session:fingerprints:)` từ phiên đã nộp, hoặc giải mã (có kiểm nhất quán).
///
/// Định dạng JSON (`payloadVersion` 1), khoá cố định:
///
/// ```text
/// payloadVersion      1
/// mode                "practice" | "exam"
/// timeLimitMinutes    số phút (chỉ Thi; không có ở Luyện tập)
/// paper               ExamPaper: examID, options (CompositionOptions, seed là chuỗi thập phân), items
/// answers             { "<id câu>": ["A", "C"] }  id lựa chọn gốc, đã sắp xếp
/// flagged             ["<id câu>", …]              đã sắp xếp
/// checkedQuestionIDs  ["<id câu>", …]              câu đã Kiểm tra đáp án, đã sắp xếp
/// result              ScoreResult
/// fingerprints        { "<id câu>": "<sha-256 hex>" }
/// ```
///
/// Đổi khoá hay ý nghĩa của trường đã có thì tăng `currentPayloadVersion` và thêm bước đọc bản
/// cũ; bản app cũ gặp payload mới hơn sẽ báo `unsupportedPayloadVersion` thay vì đọc sai.
public struct AttemptRecord: Equatable, Sendable {
    /// Phiên bản định dạng payload mà bản app này ghi và đọc được.
    public static let currentPayloadVersion = 1

    public let mode: SessionMode
    /// Thời gian cho phép (phút) của lần Thi; nil ở Luyện tập.
    public let timeLimitMinutes: Int?
    /// Thứ tự câu và thứ tự hiển thị lựa chọn của phiên; gồm cả tuỳ chọn tạo đề (`options`).
    public let paper: ExamPaper
    /// Đáp án theo id câu và id lựa chọn gốc; không có khoá = chưa làm.
    public let answers: AnswerSheet
    /// Câu đã đánh dấu.
    public let flagged: Set<UUID>
    /// Câu đã Kiểm tra đáp án (chỉ Luyện tập).
    public let checkedQuestionIDs: Set<UUID>
    public let result: ScoreResult
    /// Dấu vân tay (SHA-256 hex của dạng chuẩn) của từng câu trong `paper` lúc thi,
    /// tính bằng `QuestionFingerprint` của ExamFile.
    public let fingerprints: [UUID: String]

    /// Tuỳ chọn tạo đề (có seed), để Làm lại.
    public var options: CompositionOptions { paper.options }
    public var examID: UUID { paper.examID }

    init(
        mode: SessionMode,
        timeLimitMinutes: Int?,
        paper: ExamPaper,
        answers: AnswerSheet,
        flagged: Set<UUID>,
        checkedQuestionIDs: Set<UUID>,
        result: ScoreResult,
        fingerprints: [UUID: String]
    ) {
        self.mode = mode
        self.timeLimitMinutes = timeLimitMinutes
        self.paper = paper
        self.answers = answers
        self.flagged = flagged
        self.checkedQuestionIDs = checkedQuestionIDs
        self.result = result
        self.fingerprints = fingerprints
    }

    /// Bản ghi của một phiên đã nộp.
    ///
    /// - Parameter fingerprints: dấu vân tay theo id câu, thường là
    ///   `QuestionFingerprint.fingerprints(of: session.exam)`. Phải có mọi câu của `session.paper`;
    ///   câu khác bị bỏ.
    /// - Throws: `AttemptRecordError.sessionNotSubmitted`, `.missingFingerprint`, `.invalidFingerprint`.
    public init(session: ExamSession, fingerprints: [UUID: String]) throws {
        guard session.phase == .submitted, let result = session.result else {
            throw AttemptRecordError.sessionNotSubmitted(phase: session.phase)
        }
        var kept: [UUID: String] = [:]
        for id in session.paper.questionIDs {
            guard let value = fingerprints[id] else { throw AttemptRecordError.missingFingerprint(questionID: id) }
            guard Self.isValidFingerprint(value) else { throw AttemptRecordError.invalidFingerprint(questionID: id) }
            kept[id] = value
        }
        self.init(
            mode: session.mode,
            timeLimitMinutes: session.timeLimitMinutes,
            paper: session.paper,
            answers: session.answers,
            flagged: session.flagged,
            checkedQuestionIDs: session.checkedQuestionIDs,
            result: result,
            fingerprints: kept
        )
        // Phiên đã nộp luôn nhất quán; kiểm để bản ghi lưu xuống chắc chắn đọc lại được.
        if let problem = consistencyProblem() {
            throw AttemptRecordError.inconsistentPayload(problem)
        }
    }

    // MARK: - JSON

    /// JSON gọn (không thụt lề), khoá sắp xếp, để lưu vào cột `payload`.
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }

    /// Đọc payload. Kiểm `payloadVersion` trước mọi trường khác, rồi kiểm nhất quán.
    ///
    /// - Throws: `AttemptRecordError.unsupportedPayloadVersion` (payload mới hơn bản app),
    ///   `.malformedPayload` (JSON hỏng, thiếu khoá, sai kiểu), `.inconsistentPayload` (mâu thuẫn).
    public static func decode(_ data: Data) throws -> AttemptRecord {
        do {
            return try JSONDecoder().decode(AttemptRecord.self, from: data)
        } catch let error as AttemptRecordError {
            throw error
        } catch let DecodingError.dataCorrupted(context) {
            if let consistency = context.underlyingError as? PayloadConsistencyError {
                throw AttemptRecordError.inconsistentPayload(consistency.reason)
            }
            throw AttemptRecordError.malformedPayload(describe(.dataCorrupted(context)))
        } catch let error as DecodingError {
            throw AttemptRecordError.malformedPayload(describe(error))
        } catch {
            throw AttemptRecordError.malformedPayload(String(describing: error))
        }
    }

    private static func describe(_ error: DecodingError) -> String {
        let context: DecodingError.Context
        switch error {
        case let .dataCorrupted(c), let .keyNotFound(_, c), let .typeMismatch(_, c), let .valueNotFound(_, c):
            context = c
        @unknown default:
            return String(describing: error)
        }
        let path = context.codingPath.map { $0.intValue.map(String.init) ?? $0.stringValue }.joined(separator: ".")
        return path.isEmpty ? context.debugDescription : "\(path): \(context.debugDescription)"
    }

    // MARK: - Kiểm nhất quán

    /// 64 ký tự hex chữ thường.
    static func isValidFingerprint(_ value: String) -> Bool {
        value.utf8.count == 64 && value.utf8.allSatisfy { (48 ... 57).contains($0) || (97 ... 102).contains($0) }
    }

    /// Điều mâu thuẫn đầu tiên giữa đề đã tạo, đáp án, kết quả và dấu vân tay; nil nếu nhất quán.
    /// `ScoreResult` tự kiểm phần bên trong nó lúc giải mã; ở đây kiểm quan hệ giữa các phần.
    func consistencyProblem() -> String? {
        func hex(_ id: UUID) -> String { id.uuidString.lowercased() }

        let items = paper.items
        guard !items.isEmpty else { return "Đề của lần thi không có câu nào" }
        let paperIDs = Set(items.map(\.questionID))

        // Chế độ và thời gian cho phép.
        switch mode {
        case .practice:
            if timeLimitMinutes != nil { return "Luyện tập không có thời gian cho phép" }
            if !checkedQuestionIDs.isSubset(of: Set(answers.keys)) {
                return "Câu đã Kiểm tra đáp án phải có đáp án"
            }
        case .exam:
            guard let minutes = timeLimitMinutes, ExamSession.timeLimitRange.contains(minutes) else {
                return "Thi phải có thời gian cho phép trong \(ExamSession.timeLimitRange)"
            }
            if !checkedQuestionIDs.isEmpty { return "Thi không có Kiểm tra đáp án" }
        }

        // Cách chọn câu khớp các câu của đề đã tạo (phần kiểm được mà không cần file đề).
        switch paper.options.selection {
        case .all:
            break
        case let .sections(ids):
            if let item = items.first(where: { !ids.contains($0.sectionID) }) {
                return "Câu \(hex(item.questionID)) thuộc section không được chọn"
            }
        case let .random(count):
            if count != items.count { return "Chọn \(count) câu ngẫu nhiên nhưng đề có \(items.count) câu" }
        case let .questions(ids):
            if Set(ids) != paperIDs { return "Danh sách câu đã chọn khác các câu của đề" }
        }

        // Kết quả chấm đúng các câu, đúng thứ tự phiên.
        guard result.questionIDs == paper.questionIDs else { return "Kết quả chấm không khớp thứ tự câu của đề" }

        // Đáp án: câu thuộc đề, lựa chọn thuộc câu, khớp có/không có đáp án với kết quả.
        let itemsByID = Dictionary(items.map { ($0.questionID, $0) }, uniquingKeysWith: { first, _ in first })
        for (id, selected) in answers {
            guard let item = itemsByID[id] else { return "Đáp án của câu \(hex(id)) không thuộc đề" }
            if selected.isEmpty { return "Đáp án rỗng ở câu \(hex(id))" }
            if !selected.isSubset(of: Set(item.optionOrder)) {
                return "Đáp án câu \(hex(id)) có lựa chọn không thuộc câu"
            }
        }
        for item in items {
            let answered = answers[item.questionID] != nil
            let unanswered = result.outcomes[item.questionID] == .unanswered
            if answered == unanswered { return "Kết quả câu \(hex(item.questionID)) không khớp đáp án" }
        }

        // Theo section: đếm lại từ đề đã tạo và kết quả từng câu.
        var counts: [UUID: (total: Int, correct: Int)] = [:]
        for item in items {
            var entry = counts[item.sectionID] ?? (0, 0)
            entry.total += 1
            if result.outcomes[item.questionID] == .correct { entry.correct += 1 }
            counts[item.sectionID] = entry
        }
        let sectionIDs = Set(result.sections.map(\.sectionID))
        if let missing = counts.keys.first(where: { !sectionIDs.contains($0) }) {
            return "Section \(hex(missing)) có câu nhưng không có trong kết quả"
        }
        for section in result.sections {
            let expected = counts[section.sectionID] ?? (0, 0)
            if section.total != expected.total || section.correct != expected.correct {
                return "Kết quả section \(hex(section.sectionID)) không khớp các câu của đề"
            }
        }

        // Đánh dấu chỉ trên câu của đề. (Câu đã Kiểm tra đáp án đã nằm trong đề: chúng có đáp án,
        // và đáp án chỉ có ở câu của đề.)
        if !flagged.isSubset(of: paperIDs) { return "Câu đánh dấu không thuộc đề" }

        // Dấu vân tay: đúng các câu của đề, đúng dạng SHA-256 hex.
        guard Set(fingerprints.keys) == paperIDs else { return "Dấu vân tay không khớp các câu của đề" }
        if let bad = fingerprints.first(where: { !Self.isValidFingerprint($0.value) }) {
            return "Dấu vân tay câu \(hex(bad.key)) không phải SHA-256 hex"
        }
        return nil
    }
}

extension AttemptRecord: Codable {
    private enum CodingKeys: String, CodingKey {
        case payloadVersion, mode, timeLimitMinutes, paper, answers, flagged, checkedQuestionIDs, result, fingerprints
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Phiên bản trước mọi trường khác: payload mới hơn có thể đổi cấu trúc.
        let version = try c.decode(Int.self, forKey: .payloadVersion)
        guard version >= 1 else {
            throw DecodingError.dataCorruptedError(
                forKey: .payloadVersion, in: c, debugDescription: "payloadVersion phải ≥ 1, nhận \(version)")
        }
        guard version <= Self.currentPayloadVersion else {
            throw AttemptRecordError.unsupportedPayloadVersion(found: version, supported: Self.currentPayloadVersion)
        }

        let answers = try c.decodeByID([OptionID].self, forKey: .answers)
        var sheet: AnswerSheet = [:]
        for (id, letters) in answers {
            let set = Set(letters)
            guard set.count == letters.count else {
                throw DecodingError.dataCorruptedError(
                    forKey: .answers, in: c, debugDescription: "Đáp án câu \(id.uuidString.lowercased()) có lựa chọn trùng")
            }
            sheet[id] = set
        }

        self.init(
            mode: try c.decode(SessionMode.self, forKey: .mode),
            timeLimitMinutes: try c.decodeIfPresent(Int.self, forKey: .timeLimitMinutes),
            paper: try c.decode(ExamPaper.self, forKey: .paper),
            answers: sheet,
            flagged: try c.decodeUniqueIDs(forKey: .flagged),
            checkedQuestionIDs: try c.decodeUniqueIDs(forKey: .checkedQuestionIDs),
            result: try c.decode(ScoreResult.self, forKey: .result),
            fingerprints: try c.decodeByID(String.self, forKey: .fingerprints)
        )
        if let problem = consistencyProblem() {
            throw inconsistency(problem, codingPath: c.codingPath)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(Self.currentPayloadVersion, forKey: .payloadVersion)
        try c.encode(mode, forKey: .mode)
        try c.encodeIfPresent(timeLimitMinutes, forKey: .timeLimitMinutes)
        try c.encode(paper, forKey: .paper)
        try c.encodeByID(answers.mapValues { $0.sorted() }, forKey: .answers)
        try c.encodeSorted(flagged, forKey: .flagged)
        try c.encodeSorted(checkedQuestionIDs, forKey: .checkedQuestionIDs)
        try c.encode(result, forKey: .result)
        try c.encodeByID(fingerprints, forKey: .fingerprints)
    }
}
