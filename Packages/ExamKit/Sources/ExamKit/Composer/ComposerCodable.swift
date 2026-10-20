import Foundation

// Codable của tuỳ chọn tạo đề và đề đã tạo, để lưu trong dữ liệu lần thi
// (docs/product/exam-taking.md, "Dữ liệu một lần thi"). Khoá JSON cố định bằng CodingKeys
// tường minh: đổi tên khoá làm lần thi đã lưu không đọc được, phải tăng
// `AttemptRecord.currentPayloadVersion` kèm bước đọc bản cũ (test JSON mẫu cố định
// trong AttemptRecordTests bắt lỗi này).

extension QuestionSelection: Codable {
    /// `{"kind":"all"}`, `{"kind":"sections","sectionIDs":[…]}`, `{"kind":"random","count":N}`,
    /// `{"kind":"questions","questionIDs":[…]}`.
    private enum CodingKeys: String, CodingKey {
        case kind, sectionIDs, count, questionIDs
    }

    private enum Kind: String, Codable {
        case all, sections, random, questions
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(Kind.self, forKey: .kind) {
        case .all:
            self = .all
        case .sections:
            self = .sections(try c.decodeUniqueIDs(forKey: .sectionIDs))
        case .random:
            self = .random(count: try c.decode(Int.self, forKey: .count))
        case .questions:
            // Giữ nguyên thứ tự (và cả id trùng, như ExamComposer nhận) để tạo lại đúng đề.
            self = .questions(try c.decode([UUID].self, forKey: .questionIDs))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .all:
            try c.encode(Kind.all, forKey: .kind)
        case let .sections(ids):
            try c.encode(Kind.sections, forKey: .kind)
            try c.encodeSorted(ids, forKey: .sectionIDs)
        case let .random(count):
            try c.encode(Kind.random, forKey: .kind)
            try c.encode(count, forKey: .count)
        case let .questions(ids):
            try c.encode(Kind.questions, forKey: .kind)
            try c.encodeLowercased(ids, forKey: .questionIDs)
        }
    }
}

extension CompositionOptions: Codable {
    private enum CodingKeys: String, CodingKey {
        case selection, shuffleQuestions, shuffleOptions, seed
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            selection: try c.decode(QuestionSelection.self, forKey: .selection),
            shuffleQuestions: try c.decode(Bool.self, forKey: .shuffleQuestions),
            shuffleOptions: try c.decode(Bool.self, forKey: .shuffleOptions),
            // Chuỗi thập phân, không phải số JSON: giữ đủ 64 bit (xem PayloadCoding.swift).
            seed: try c.decodeDecimalString(forKey: .seed)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(selection, forKey: .selection)
        try c.encode(shuffleQuestions, forKey: .shuffleQuestions)
        try c.encode(shuffleOptions, forKey: .shuffleOptions)
        try c.encodeDecimalString(seed, forKey: .seed)
    }
}

extension PaperItem: Codable {
    private enum CodingKeys: String, CodingKey {
        case questionID, sectionID, optionOrder
    }

    /// Từ chối `optionOrder` có lựa chọn trùng (ExamComposer không bao giờ tạo ra).
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let order = try c.decode([OptionID].self, forKey: .optionOrder)
        guard Set(order).count == order.count else {
            throw inconsistency("Thứ tự lựa chọn có lựa chọn trùng", codingPath: c.codingPath + [CodingKeys.optionOrder])
        }
        self.init(
            questionID: try c.decode(UUID.self, forKey: .questionID),
            sectionID: try c.decode(UUID.self, forKey: .sectionID),
            optionOrder: order
        )
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeLowercased(questionID, forKey: .questionID)
        try c.encodeLowercased(sectionID, forKey: .sectionID)
        try c.encode(optionOrder, forKey: .optionOrder)
    }
}

extension ExamPaper: Codable {
    private enum CodingKeys: String, CodingKey {
        case examID, options, items
    }

    /// Từ chối đề có một câu hai lần (ExamComposer không bao giờ tạo ra, ExamSession không nhận).
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let items = try c.decode([PaperItem].self, forKey: .items)
        var seen = Set<UUID>()
        for item in items where !seen.insert(item.questionID).inserted {
            throw inconsistency(
                "Câu \(item.questionID.uuidString.lowercased()) xuất hiện hai lần trong đề",
                codingPath: c.codingPath + [CodingKeys.items]
            )
        }
        self.init(
            examID: try c.decode(UUID.self, forKey: .examID),
            options: try c.decode(CompositionOptions.self, forKey: .options),
            items: items
        )
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeLowercased(examID, forKey: .examID)
        try c.encode(options, forKey: .options)
        try c.encode(items, forKey: .items)
    }
}
