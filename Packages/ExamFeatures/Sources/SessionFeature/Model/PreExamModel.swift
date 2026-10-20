import ExamFile
import ExamKit
import Foundation
import Observation

/// Cách mở màn Trước khi thi.
public enum PreExamPreset: Hashable, Sendable {
    /// Từ thẻ đề: chế độ dùng lần trước, mọi lựa chọn khác mặc định.
    case fresh
    /// **Làm lại**: đúng lựa chọn của lần đó (chế độ, cách chọn câu, xáo, thời gian); seed mới khi Bắt đầu.
    /// Cách chọn `.questions` (lần đó là Luyện lại câu sai) mở như `practiceIncorrect`.
    case retake(mode: SessionMode, options: CompositionOptions, timeLimitMinutes: Int?)
    /// **Luyện lại câu sai**: Luyện tập, đúng danh sách câu này theo thứ tự, không xáo; chỉ đổi được tên.
    case practiceIncorrect(questionIDs: [UUID])
}

/// Cách chọn câu trên màn Trước khi thi.
public enum QuestionSelectionKind: String, CaseIterable, Hashable, Sendable, Identifiable {
    /// **Tất cả câu**
    case all
    /// **Theo phần**
    case sections
    /// **N câu ngẫu nhiên**
    case random

    public var id: Self { self }

    public var title: String {
        switch self {
        case .all: localized("Tất cả câu")
        case .sections: localized("Theo phần")
        case .random: localized("Câu ngẫu nhiên")
        }
    }
}

/// Lý do khoá **Bắt đầu**, hiện ngay dưới dòng tóm tắt (không có hộp thoại lỗi sau khi bấm).
public enum PreExamIssue: Hashable, Sendable {
    /// Đề `hideAnswers` mà đang chọn Luyện tập.
    case practiceUnavailable
    /// Tên thí sinh trống (sau khi bỏ khoảng trắng hai đầu).
    case emptyCandidateName
    /// Đề không có câu nào.
    case examHasNoQuestions
    /// Theo phần: chưa chọn phần nào.
    case noSectionSelected
    /// Theo phần: các phần đã chọn không có câu nào.
    case selectedSectionsEmpty
    /// N câu ngẫu nhiên ngoài `1…total`.
    case randomCountOutOfRange(total: Int)
    /// Thời gian (Thi) ngoài 1–600 phút.
    case timeLimitOutOfRange
    /// Luyện lại câu sai: không còn câu nào của danh sách trong đề.
    case noQuestionsToPractice

    public var message: String {
        switch self {
        case .practiceUnavailable:
            PreExamModel.practiceUnavailableMessage
        case .emptyCandidateName:
            localized("Nhập tên thí sinh để bắt đầu.")
        case .examHasNoQuestions:
            localized("Đề không có câu nào.")
        case .noSectionSelected:
            localized("Chọn ít nhất một phần.")
        case .selectedSectionsEmpty:
            localized("Các phần đã chọn không có câu nào.")
        case let .randomCountOutOfRange(total):
            localized("Số câu ngẫu nhiên phải từ 1 đến \(total).")
        case .timeLimitOutOfRange:
            localized("Thời gian phải từ \(ExamSession.timeLimitRange.lowerBound) đến \(ExamSession.timeLimitRange.upperBound) phút.")
        case .noQuestionsToPractice:
            localized("Không còn câu nào để luyện lại.")
        }
    }
}

/// Một dòng của danh sách **Theo phần**.
public struct PreExamSectionRow: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let title: String
    public let questionCount: Int
    public let isSelected: Bool
}

/// Màn **Trước khi thi** (docs/product/exam-taking.md, mục Trước khi thi): lựa chọn, kiểm hợp lệ, dòng
/// tóm tắt, Bắt đầu.
///
/// Lựa chọn không nhớ giữa các đề; chỉ tên thí sinh và chế độ được ghi vào `SessionPreferences` khi
/// Bắt đầu tạo được phiên và phiên đó được dùng (`rememberStartedChoices()`). Bắt đầu đọc lại file đề (nghiêm) qua `SessionLibrary`: lỗi thì không tạo phiên, `startFailure`
/// có lý do và Thư viện được yêu cầu làm mới trạng thái thẻ.
@Observable
@MainActor
public final class PreExamModel: Identifiable {
    /// Tính mỗi lần đọc (không `static let`): theo ngôn ngữ đang tra.
    nonisolated static var practiceUnavailableMessage: String { localized("Đề này ẩn đáp án nên không luyện tập được") }

    public let id = UUID()
    public let examID: UUID
    public let preset: PreExamPreset
    /// Đề lần đọc gần nhất (lúc mở sheet, rồi lúc Bắt đầu).
    public private(set) var exam: Exam
    public private(set) var media: [String: Data]

    /// Tên thí sinh như người dùng gõ (điền sẵn tên dùng lần trước).
    public var candidateName: String
    public var selectionKind: QuestionSelectionKind
    public private(set) var selectedSectionIDs: Set<UUID>
    /// N của **N câu ngẫu nhiên**.
    public var randomCount: Int
    public var shuffleQuestions: Bool
    public var shuffleOptions: Bool
    /// Thời gian (phút), chỉ dùng ở Thi; mặc định `timeLimitMinutes` của đề.
    public var timeLimitMinutes: Int
    /// Lý do Bắt đầu thất bại (đọc file đề lỗi…); nil khi chưa bấm hoặc đã thành công.
    public private(set) var startFailure: String?
    public private(set) var isStarting = false

    private var storedMode: SessionMode
    /// Luyện lại câu sai: danh sách câu cố định.
    private let fixedQuestionIDs: [UUID]?
    /// Tên và chế độ của lần `start()` thành công gần nhất, chờ `rememberStartedChoices()`.
    @ObservationIgnored private var startedChoices: (String, SessionMode)?

    @ObservationIgnored private let environment: SessionEnvironment

    /// - Parameters:
    ///   - mode: chế độ chọn sẵn khi mở bằng nút **Luyện tập** / **Thi** trên thẻ (chỉ với `.fresh`); nil
    ///     (nhấp đúp, Return) thì dùng chế độ lần trước.
    public init(
        package: ExamPackage,
        preset: PreExamPreset = .fresh,
        mode requestedMode: SessionMode? = nil,
        environment: SessionEnvironment
    ) {
        let exam = package.exam
        self.examID = exam.id
        self.preset = preset
        self.exam = exam
        self.media = package.media
        self.environment = environment
        candidateName = environment.preferences.candidateName
        selectionKind = .all
        selectedSectionIDs = Set(exam.sections.map(\.id))
        randomCount = exam.questionCount
        shuffleQuestions = false
        shuffleOptions = false
        timeLimitMinutes = exam.timeLimitMinutes
        var mode = environment.preferences.lastMode
        var fixed: [UUID]?

        switch preset {
        case .fresh:
            if let requestedMode { mode = requestedMode }
        case let .practiceIncorrect(ids):
            fixed = ids
            mode = .practice
        case let .retake(previousMode, options, minutes):
            mode = previousMode
            if let minutes { timeLimitMinutes = minutes }
            shuffleQuestions = options.shuffleQuestions
            shuffleOptions = options.shuffleOptions
            switch options.selection {
            case .all:
                selectionKind = .all
            case let .sections(ids):
                selectionKind = .sections
                selectedSectionIDs = ids.intersection(Set(exam.sections.map(\.id)))
            case let .random(count):
                selectionKind = .random
                randomCount = count
            case let .questions(ids):
                fixed = ids
                mode = .practice
                shuffleQuestions = false
                shuffleOptions = false
            }
        }
        fixedQuestionIDs = fixed
        // Đề ẩn đáp án chỉ thi được; Luyện lại câu sai giữ Luyện tập và bị khoá kèm lý do.
        if exam.hideAnswers, fixed == nil { mode = .exam }
        storedMode = mode
    }

    // MARK: - Thông tin đề

    public var title: String { exam.title }
    public var code: String? { exam.code }
    public var instructions: String? { exam.instructions }
    public var totalQuestionCount: Int { exam.questionCount }

    // MARK: - Chế độ

    /// Chế độ đang chọn. Không đổi được ở Luyện lại câu sai; không chọn được Luyện tập khi đề `hideAnswers`.
    public var mode: SessionMode {
        get { storedMode }
        set {
            guard canChangeOptions else { return }
            if newValue == .practice, exam.hideAnswers { return }
            storedMode = newValue
        }
    }

    /// Lý do Luyện tập bị tắt; nil nếu chọn được.
    public var practiceUnavailableReason: String? {
        exam.hideAnswers ? Self.practiceUnavailableMessage : nil
    }

    /// Luyện lại câu sai: chỉ đổi được tên thí sinh.
    public var isPracticeIncorrect: Bool { fixedQuestionIDs != nil }

    /// Đổi được chế độ, cách chọn câu, xáo, thời gian.
    public var canChangeOptions: Bool { !isPracticeIncorrect }

    /// Ô Thời gian chỉ có ở Thi.
    public var showsTimeLimit: Bool { storedMode == .exam }

    // MARK: - Theo phần

    public var sectionRows: [PreExamSectionRow] {
        exam.sections.map {
            PreExamSectionRow(
                id: $0.id,
                title: $0.title,
                questionCount: $0.questions.count,
                isSelected: selectedSectionIDs.contains($0.id)
            )
        }
    }

    public func setSection(_ id: UUID, selected: Bool) {
        guard exam.sections.contains(where: { $0.id == id }) else { return }
        if selected { selectedSectionIDs.insert(id) } else { selectedSectionIDs.remove(id) }
    }

    public func toggleSection(_ id: UUID) {
        setSection(id, selected: !selectedSectionIDs.contains(id))
    }

    /// **Chọn hết**
    public func selectAllSections() {
        selectedSectionIDs = Set(exam.sections.map(\.id))
    }

    /// **Bỏ chọn**
    public func deselectAllSections() {
        selectedSectionIDs = []
    }

    /// Khoảng của Stepper **N câu ngẫu nhiên**.
    public var randomCountRange: ClosedRange<Int> { 1 ... max(1, totalQuestionCount) }

    // MARK: - Tóm tắt và kiểm hợp lệ

    /// Câu của Luyện lại câu sai còn trong đề, theo thứ tự, bỏ trùng.
    private var practiceQuestionIDs: [UUID] {
        guard let fixedQuestionIDs else { return [] }
        let known = Set(exam.allQuestions.map(\.id))
        var seen = Set<UUID>()
        return fixedQuestionIDs.filter { known.contains($0) && seen.insert($0).inserted }
    }

    /// Phần được chọn còn trong đề.
    private var effectiveSectionIDs: Set<UUID> {
        selectedSectionIDs.intersection(Set(exam.sections.map(\.id)))
    }

    /// Số câu của lựa chọn hiện tại (N câu ngẫu nhiên: đúng N đã nhập, kể cả khi ngoài khoảng).
    public var questionCount: Int {
        if isPracticeIncorrect { return practiceQuestionIDs.count }
        switch selectionKind {
        case .all:
            return totalQuestionCount
        case .sections:
            let ids = effectiveSectionIDs
            return exam.sections.filter { ids.contains($0.id) }.reduce(0) { $0 + $1.questions.count }
        case .random:
            return randomCount
        }
    }

    /// Dòng tóm tắt: "60 câu · 90 phút · đậu 70%" (Luyện tập: "60 câu · không giới hạn giờ · đậu 70%").
    public var summaryLine: String {
        let time = storedMode == .exam
            ? SessionFormat.minutes(timeLimitMinutes)
            : localized("không giới hạn giờ")
        return [
            localized("\(questionCount) câu"),
            time,
            localized("đậu \(SessionFormat.percent(exam.passPercent))"),
        ].joined(separator: " · ")
    }

    /// Mọi lý do khoá Bắt đầu, theo thứ tự hiện trên sheet.
    public var issues: [PreExamIssue] {
        var issues: [PreExamIssue] = []
        if storedMode == .practice, exam.hideAnswers { issues.append(.practiceUnavailable) }
        if isPracticeIncorrect {
            if practiceQuestionIDs.isEmpty { issues.append(.noQuestionsToPractice) }
        } else {
            switch selectionKind {
            case .all:
                if totalQuestionCount == 0 { issues.append(.examHasNoQuestions) }
            case .sections:
                if effectiveSectionIDs.isEmpty {
                    issues.append(.noSectionSelected)
                } else if questionCount == 0 {
                    issues.append(.selectedSectionsEmpty)
                }
            case .random:
                if totalQuestionCount == 0 {
                    issues.append(.examHasNoQuestions)
                } else if !(1 ... totalQuestionCount).contains(randomCount) {
                    issues.append(.randomCountOutOfRange(total: totalQuestionCount))
                }
            }
            if storedMode == .exam, !ExamSession.timeLimitRange.contains(timeLimitMinutes) {
                issues.append(.timeLimitOutOfRange)
            }
        }
        if trimmedCandidateName.isEmpty { issues.append(.emptyCandidateName) }
        return issues
    }

    public var canStart: Bool { issues.isEmpty && !isStarting }

    /// Tên thí sinh sau khi bỏ khoảng trắng (và xuống dòng) hai đầu.
    public var trimmedCandidateName: String {
        candidateName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Tuỳ chọn tạo đề của lựa chọn hiện tại với `seed`.
    public func compositionOptions(seed: UInt64) -> CompositionOptions {
        if isPracticeIncorrect {
            return CompositionOptions(selection: .questions(practiceQuestionIDs), seed: seed)
        }
        let selection: QuestionSelection
        switch selectionKind {
        case .all: selection = .all
        case .sections: selection = .sections(effectiveSectionIDs)
        case .random: selection = .random(count: randomCount)
        }
        return CompositionOptions(
            selection: selection,
            shuffleQuestions: shuffleQuestions,
            shuffleOptions: shuffleOptions,
            seed: seed
        )
    }

    // MARK: - Bắt đầu

    /// **Bắt đầu**: đọc lại file đề (nghiêm), kiểm lại lựa chọn trên đề vừa đọc, tạo đề với seed mới và
    /// tạo phiên. Chưa ghi cài đặt (xem `rememberStartedChoices()`). Lỗi → nil, lý do ở `startFailure`.
    /// Giao diện gọi qua `SessionCoordinator.startPreExam()` (kiểm Huỷ và mỗi lúc một phiên).
    func start() async -> AttemptModel? {
        guard canStart else { return nil }
        isStarting = true
        defer { isStarting = false }
        startFailure = nil

        let package: ExamPackage
        switch await environment.library.readExam(examID) {
        case let .failure(failure):
            startFailure = failure.message
            environment.library.examFileNeedsRefresh(examID)
            return nil
        case let .success(read):
            package = read
        }
        // File có thể đã đổi từ lúc mở sheet: sheet hiện đề mới, lựa chọn kiểm lại trên đề mới.
        exam = package.exam
        media = package.media
        if let blocking = issues.first {
            startFailure = blocking.message
            return nil
        }

        let name = trimmedCandidateName
        let options = compositionOptions(seed: environment.makeSeed())
        let session: ExamSession
        do {
            let paper = try ExamComposer.compose(exam, options: options)
            session = try ExamSession(
                exam: exam,
                paper: paper,
                mode: storedMode,
                timeLimitMinutes: storedMode == .exam ? timeLimitMinutes : nil,
                candidateName: name,
                clock: environment.makeClock()
            )
        } catch {
            startFailure = Self.startErrorMessage(error)
            return nil
        }
        startedChoices = (name, storedMode)
        return AttemptModel(session: session, media: media, environment: environment)
    }

    /// Ghi tên thí sinh và chế độ của lần Bắt đầu thành công vào cài đặt (dùng cho lần sau). Điều phối gọi
    /// sau khi chắc phiên được dùng (không bị Huỷ trong lúc đọc file), nên Huỷ giữa chừng không đổi cài đặt.
    func rememberStartedChoices() {
        guard let (name, mode) = startedChoices else { return }
        environment.preferences.candidateName = name
        environment.preferences.lastMode = mode
    }

    /// Lý do tiếng Việt khi không tạo được đề hoặc phiên (lựa chọn đã kiểm trước nên hiếm khi xảy ra).
    static func startErrorMessage(_ error: any Error) -> String {
        switch error {
        case CompositionError.noQuestions, SessionError.emptyPaper:
            localized("Lựa chọn này không có câu nào.")
        case let CompositionError.countOutOfRange(_, available):
            PreExamIssue.randomCountOutOfRange(total: available).message
        case CompositionError.unknownSection, CompositionError.unknownQuestion, SessionError.unknownQuestion:
            localized("Đề đã thay đổi so với lựa chọn. Hãy đóng rồi mở lại màn Trước khi thi.")
        case SessionError.practiceNotAllowed:
            PreExamIssue.practiceUnavailable.message
        case SessionError.invalidTimeLimit:
            PreExamIssue.timeLimitOutOfRange.message
        default:
            localized("Không tạo được bài thi từ đề này.")
        }
    }
}
