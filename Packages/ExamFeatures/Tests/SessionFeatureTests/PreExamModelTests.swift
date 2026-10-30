import ExamFile
import ExamKit
import Foundation
import LibraryData
@testable import SessionFeature
@testable import SessionModel
import Testing

/// Màn Trước khi thi (docs/product/exam-taking.md, mục Trước khi thi và Bắt đầu).
@MainActor
@Suite("Trước khi thi: lựa chọn, kiểm hợp lệ, tóm tắt, Bắt đầu")
struct PreExamModelTests {
    // Đề 3 phần: 3 câu, 0 câu, 2 câu (tổng 5), đậu 70%, 30 phút.
    let exam = makeExam(counts: [3, 0, 2])

    // MARK: - Mặc định, tóm tắt

    @Test("Mở từ thẻ: chế độ và tên dùng lần trước, Tất cả câu, không xáo, thời gian của đề")
    func freshDefaults() {
        let harness = Harness(candidateName: "Trần Thị Bình", lastMode: .exam)
        let model = harness.preExam(exam)

        #expect(model.mode == .exam)
        #expect(model.candidateName == "Trần Thị Bình")
        #expect(model.selectionKind == .all)
        #expect(!model.shuffleQuestions)
        #expect(!model.shuffleOptions)
        #expect(model.timeLimitMinutes == 30)
        #expect(model.showsTimeLimit)
        #expect(model.title == "Kiến thức chung")
        #expect(model.code == "KTC01")
        #expect(model.instructions == "Đọc kỹ từng câu.")
        #expect(model.sectionRows.map(\.questionCount) == [3, 0, 2])
        #expect(model.sectionRows.allSatisfy { $0.isSelected })
        #expect(model.issues.isEmpty)
        #expect(model.canStart)
    }

    @Test("Nút Luyện tập / Thi trên thẻ chọn sẵn chế độ; nhấp đúp, Return dùng chế độ lần trước")
    func modeFromCardButton() {
        let harness = Harness(lastMode: .practice)
        harness.library.add(exam)
        let viaExamButton = PreExamModel(package: ExamPackage(exam: exam), mode: .exam, environment: harness.environment)
        #expect(viaExamButton.mode == .exam)
        let viaReturn = PreExamModel(package: ExamPackage(exam: exam), environment: harness.environment)
        #expect(viaReturn.mode == .practice)
        let hidden = makeExam(counts: [1], hideAnswers: true)
        let practiceOnHidden = PreExamModel(package: ExamPackage(exam: hidden), mode: .practice, environment: harness.environment)
        #expect(practiceOnHidden.mode == .exam)
    }

    @Test("Lần đầu dùng app: Luyện tập, tên trống (khoá Bắt đầu)")
    func firstLaunchDefaults() throws {
        let workspace = try SessionWorkspace()
        let preferences = UserDefaultsSessionPreferences(defaults: workspace.defaults)
        #expect(preferences.lastMode == .practice)
        #expect(preferences.candidateName == "")
        preferences.candidateName = "An"
        preferences.lastMode = .exam
        let reread = UserDefaultsSessionPreferences(defaults: workspace.defaults)
        #expect(reread.candidateName == "An")
        #expect(reread.lastMode == .exam)
        #expect(workspace.defaults.string(forKey: UserDefaultsSessionPreferences.candidateNameKey) == "An")
        #expect(workspace.defaults.string(forKey: UserDefaultsSessionPreferences.lastModeKey) == "exam")
    }

    @Test("Dòng tóm tắt theo chế độ: “5 câu · 30 phút · đậu 70%” / “5 câu · không giới hạn giờ · đậu 70%”")
    func summaryLine() {
        let model = Harness().preExam(exam)
        model.mode = .exam
        #expect(model.summaryLine == "5 câu · 30 phút · đậu 70%")
        model.timeLimitMinutes = 90
        #expect(model.summaryLine == "5 câu · 90 phút · đậu 70%")
        model.mode = .practice
        #expect(model.summaryLine == "5 câu · không giới hạn giờ · đậu 70%")
        #expect(!model.showsTimeLimit)
    }

    // MARK: - Tên thí sinh

    @Test("Tên thí sinh bỏ khoảng trắng hai đầu; chỉ có khoảng trắng thì khoá Bắt đầu kèm lý do")
    func candidateName() {
        let model = Harness().preExam(exam)
        model.candidateName = "  Lê Văn Cường \n"
        #expect(model.trimmedCandidateName == "Lê Văn Cường")
        #expect(model.canStart)

        model.candidateName = "   "
        #expect(model.issues == [.emptyCandidateName])
        #expect(!model.canStart)
        #expect(model.issues.first?.message == "Nhập tên thí sinh để bắt đầu.")
    }

    // MARK: - Đề ẩn đáp án

    @Test("Đề hideAnswers: Luyện tập tắt kèm lý do, mở ở Thi dù lần trước là Luyện tập, không chọn lại được")
    func hideAnswersDisablesPractice() {
        let hidden = makeExam(counts: [2], hideAnswers: true)
        let model = Harness(lastMode: .practice).preExam(hidden)

        #expect(model.practiceUnavailableReason == "Đề này ẩn đáp án nên không luyện tập được")
        #expect(model.mode == .exam)
        model.mode = .practice
        #expect(model.mode == .exam)
        #expect(model.canStart)

        let normal = Harness().preExam(exam)
        #expect(normal.practiceUnavailableReason == nil)
    }

    // MARK: - Theo phần

    @Test("Theo phần: số câu từng phần, Bỏ chọn → khoá; chỉ phần rỗng → khoá; Chọn hết → đủ")
    func sectionSelection() {
        let model = Harness().preExam(exam)
        model.mode = .exam
        model.selectionKind = .sections
        #expect(model.questionCount == 5)

        model.deselectAllSections()
        #expect(model.sectionRows.allSatisfy { !$0.isSelected })
        #expect(model.questionCount == 0)
        #expect(model.summaryLine == "0 câu · 30 phút · đậu 70%")
        #expect(model.issues == [.noSectionSelected])
        #expect(model.issues.first?.message == "Chọn ít nhất một phần.")

        let empty = model.sectionRows[1].id
        model.toggleSection(empty)
        #expect(model.issues == [.selectedSectionsEmpty])
        #expect(model.issues.first?.message == "Các phần đã chọn không có câu nào.")

        model.toggleSection(model.sectionRows[2].id)
        #expect(model.questionCount == 2)
        #expect(model.issues.isEmpty)
        #expect(model.summaryLine == "2 câu · 30 phút · đậu 70%")

        model.selectAllSections()
        #expect(model.questionCount == 5)
        #expect(model.compositionOptions(seed: 9).selection == .sections(Set(exam.sections.map(\.id))))
    }

    // MARK: - N câu ngẫu nhiên

    @Test("N câu ngẫu nhiên: 1…tổng hợp lệ, 0 và tổng+1 khoá kèm lý do")
    func randomCountBounds() {
        let model = Harness().preExam(exam)
        model.selectionKind = .random
        #expect(model.randomCountRange == 1 ... 5)

        for valid in [1, 5] {
            model.randomCount = valid
            #expect(model.issues.isEmpty, "N = \(valid)")
            #expect(model.questionCount == valid)
        }
        for invalid in [0, 6, -1] {
            model.randomCount = invalid
            #expect(model.issues == [.randomCountOutOfRange(total: 5)], "N = \(invalid)")
            #expect(!model.canStart)
        }
        #expect(model.issues.first?.message == "Số câu ngẫu nhiên phải từ 1 đến 5.")
        model.randomCount = 3
        #expect(model.compositionOptions(seed: 4) == CompositionOptions(selection: .random(count: 3), seed: 4))
    }

    // MARK: - Thời gian

    @Test("Thời gian chỉ áp ở Thi: 1 và 600 hợp lệ, 0 và 601 khoá; Luyện tập bỏ qua")
    func timeLimitBounds() {
        let model = Harness().preExam(exam)
        model.mode = .exam
        for valid in [1, 600] {
            model.timeLimitMinutes = valid
            #expect(model.issues.isEmpty, "\(valid) phút")
        }
        for invalid in [0, 601] {
            model.timeLimitMinutes = invalid
            #expect(model.issues == [.timeLimitOutOfRange], "\(invalid) phút")
        }
        #expect(model.issues.first?.message == "Thời gian phải từ 1 đến 600 phút.")
        model.mode = .practice
        #expect(model.issues.isEmpty)
    }

    @Test("Nhiều lý do cùng lúc hiện đủ, theo thứ tự")
    func multipleIssues() {
        let model = Harness(candidateName: "").preExam(exam)
        model.mode = .exam
        model.selectionKind = .random
        model.randomCount = 0
        model.timeLimitMinutes = 0
        #expect(model.issues == [.randomCountOutOfRange(total: 5), .timeLimitOutOfRange, .emptyCandidateName])
    }

    @Test("Đề không có câu nào: khoá Bắt đầu")
    func emptyExam() {
        let model = Harness().preExam(makeExam(counts: [0]))
        #expect(model.issues == [.examHasNoQuestions])
    }

    // MARK: - Bắt đầu

    @Test("Bắt đầu: đọc lại file, tạo đề bằng ExamComposer với seed tiêm vào; tên và chế độ ghi khi điều phối xác nhận")
    func startComposesWithInjectedSeed() async throws {
        let harness = Harness(candidateName: "An", lastMode: .practice)
        harness.seeds.seeds = [42]
        let model = harness.preExam(exam)
        model.mode = .exam
        model.candidateName = "  Bình "
        model.selectionKind = .sections
        model.deselectAllSections()
        model.toggleSection(exam.sections[0].id)
        model.shuffleQuestions = true
        model.shuffleOptions = true
        model.timeLimitMinutes = 45

        let attempt = try #require(await model.start())

        let expected = try ExamComposer.compose(exam, options: CompositionOptions(
            selection: .sections([exam.sections[0].id]),
            shuffleQuestions: true,
            shuffleOptions: true,
            seed: 42
        ))
        #expect(attempt.session.paper == expected)
        #expect(attempt.session.mode == .exam)
        #expect(attempt.session.timeLimitMinutes == 45)
        #expect(attempt.session.candidateName == "Bình")
        #expect(attempt.phase == .inProgress)
        #expect(harness.library.readCount == 1)
        // `start()` chưa ghi cài đặt; điều phối ghi khi phiên chắc chắn được dùng.
        #expect(harness.preferences.candidateName == "An")
        #expect(harness.preferences.lastMode == .practice)
        model.rememberStartedChoices()
        #expect(harness.preferences.candidateName == "Bình")
        #expect(harness.preferences.lastMode == .exam)
        #expect(model.startFailure == nil)
    }

    @Test("Luyện tập: phiên không có thời hạn dù ô thời gian đã đổi")
    func practiceHasNoTimeLimit() async throws {
        let harness = Harness()
        let attempt = try await harness.start(exam, mode: .practice) { $0.timeLimitMinutes = 5 }
        #expect(attempt.session.timeLimitMinutes == nil)
        #expect(attempt.session.mode == .practice)
    }

    @Test("Bắt đầu khi đọc file lỗi: không tạo phiên, có lý do, báo Thư viện làm mới; cài đặt không đổi")
    func startFailsWhenFileUnreadable() async {
        let harness = Harness(candidateName: "An", lastMode: .practice)
        let model = harness.preExam(exam)
        model.mode = .exam
        model.candidateName = "Bình"
        harness.library.packages[exam.id] = .failure(.unreadable(reason: "Đề có lỗi: thiếu ảnh."))

        let attempt = await model.start()

        #expect(attempt == nil)
        #expect(model.startFailure == "Đề có lỗi: thiếu ảnh.")
        #expect(harness.library.refreshRequests == [exam.id])
        #expect(harness.preferences.candidateName == "An")
        #expect(harness.preferences.lastMode == .practice)
        #expect(harness.seeds.used.isEmpty)
    }

    @Test("Bắt đầu khi đề đã bị xoá khỏi thư viện hoặc mất file: lý do tương ứng")
    func startFailsWhenRemovedOrMissing() async {
        let harness = Harness()
        let model = harness.preExam(exam)
        harness.library.packages[exam.id] = .failure(.fileMissing)
        #expect(await model.start() == nil)
        #expect(model.startFailure == "Không tìm thấy file đề.")

        harness.library.remove(exam.id)
        #expect(await model.start() == nil)
        #expect(model.startFailure == "Đề không còn trong thư viện.")
        #expect(harness.library.refreshRequests == [exam.id, exam.id])
    }

    @Test("Bắt đầu dùng đề vừa đọc lại; lựa chọn không còn hợp lệ trên đề mới thì khoá kèm lý do")
    func startUsesRereadExam() async throws {
        let harness = Harness()
        let model = harness.preExam(exam)
        var edited = exam
        edited.title = "Kiến thức chung (bản mới)"
        edited.sections[0].questions.removeLast()
        harness.library.packages[exam.id] = .success(ExamPackage(exam: edited))

        let attempt = try #require(await model.start())
        #expect(attempt.exam.title == "Kiến thức chung (bản mới)")
        #expect(attempt.questionCount == 4)

        let random = harness.preExam(exam)
        random.selectionKind = .random
        random.randomCount = 5
        #expect(await random.start() == nil)
        #expect(random.startFailure == "Số câu ngẫu nhiên phải từ 1 đến 4.")
        #expect(random.totalQuestionCount == 4)
    }

    // MARK: - Làm lại

    @Test("Làm lại: đúng chế độ, cách chọn câu, xáo, thời gian của lần trước; Bắt đầu với seed mới")
    func retakePrefill() async throws {
        let harness = Harness(lastMode: .practice)
        harness.seeds.seeds = [7, 8]
        let first = try await harness.start(exam, mode: .exam) {
            $0.selectionKind = .sections
            $0.deselectAllSections()
            $0.toggleSection(exam.sections[2].id)
            $0.shuffleOptions = true
            $0.timeLimitMinutes = 12
        }
        let submission = try #require(first.submitNow())
        let record = try #require(submission.record)

        let retake = harness.preExam(exam, preset: .retake(
            mode: record.mode, options: record.options, timeLimitMinutes: record.timeLimitMinutes
        ))
        #expect(retake.mode == .exam)
        #expect(retake.selectionKind == .sections)
        #expect(retake.sectionRows.filter(\.isSelected).map(\.id) == [exam.sections[2].id])
        #expect(!retake.shuffleQuestions)
        #expect(retake.shuffleOptions)
        #expect(retake.timeLimitMinutes == 12)
        #expect(!retake.isPracticeIncorrect)

        let second = try #require(await retake.start())
        #expect(second.session.paper.options.seed == 8)
        var expected = record.options
        expected.seed = 8
        #expect(second.session.paper.options == expected)
    }

    @Test("Làm lại N câu ngẫu nhiên giữ N; phần đã bị xoá khỏi đề thì bỏ khỏi lựa chọn")
    func retakeRandomAndRemovedSection() {
        let harness = Harness()
        let random = harness.preExam(exam, preset: .retake(
            mode: .practice, options: CompositionOptions(selection: .random(count: 4), seed: 1), timeLimitMinutes: nil
        ))
        #expect(random.selectionKind == .random)
        #expect(random.randomCount == 4)
        #expect(random.mode == .practice)
        #expect(random.timeLimitMinutes == 30)

        let gone = UUID()
        let sections = harness.preExam(exam, preset: .retake(
            mode: .exam,
            options: CompositionOptions(selection: .sections([gone, exam.sections[0].id]), seed: 1),
            timeLimitMinutes: 20
        ))
        #expect(sections.sectionRows.filter(\.isSelected).map(\.id) == [exam.sections[0].id])
        #expect(sections.questionCount == 3)
    }

    // MARK: - Luyện lại câu sai

    @Test("Luyện lại câu sai: Luyện tập khoá, đúng danh sách câu theo thứ tự, không xáo; chỉ đổi tên")
    func practiceIncorrectPrefill() async throws {
        let harness = Harness(lastMode: .exam)
        harness.seeds.seeds = [5]
        let ids = [exam.sections[2].questions[1].id, exam.sections[0].questions[0].id]
        let model = harness.preExam(exam, preset: .practiceIncorrect(questionIDs: ids))

        #expect(model.isPracticeIncorrect)
        #expect(!model.canChangeOptions)
        #expect(model.mode == .practice)
        model.mode = .exam
        #expect(model.mode == .practice)
        model.selectionKind = .random
        model.shuffleQuestions = true
        model.shuffleOptions = true
        #expect(model.summaryLine == "2 câu · không giới hạn giờ · đậu 70%")
        #expect(model.compositionOptions(seed: 5) == CompositionOptions(selection: .questions(ids), seed: 5))

        model.candidateName = "Đổi tên"
        let attempt = try #require(await model.start())
        #expect(attempt.session.paper.questionIDs == ids)
        #expect(attempt.session.mode == .practice)
        #expect(attempt.session.candidateName == "Đổi tên")
        #expect(attempt.session.paper.items.allSatisfy { $0.optionOrder == ["A", "B", "C", "D"].map { OptionID($0)! } })
    }

    @Test("Luyện lại câu sai: câu không còn trong đề bị bỏ; không còn câu nào thì khoá kèm lý do")
    func practiceIncorrectWithDeletedQuestions() {
        let harness = Harness()
        let kept = exam.sections[0].questions[1].id
        let model = harness.preExam(exam, preset: .practiceIncorrect(questionIDs: [UUID(), kept, kept]))
        #expect(model.questionCount == 1)
        #expect(model.compositionOptions(seed: 1).selection == .questions([kept]))

        let none = harness.preExam(exam, preset: .practiceIncorrect(questionIDs: [UUID()]))
        #expect(none.issues == [.noQuestionsToPractice])
        #expect(none.issues.first?.message == "Không còn câu nào để luyện lại.")
    }

    @Test("Làm lại một phiên Luyện lại câu sai mở như Luyện lại câu sai")
    func retakeOfPracticeIncorrect() {
        let ids = [exam.sections[0].questions[0].id]
        let model = Harness(lastMode: .exam).preExam(exam, preset: .retake(
            mode: .practice, options: CompositionOptions(selection: .questions(ids), seed: 3), timeLimitMinutes: nil
        ))
        #expect(model.isPracticeIncorrect)
        #expect(model.mode == .practice)
        #expect(model.questionCount == 1)
    }

    @Test("Luyện lại câu sai trên đề nay đã ẩn đáp án: khoá kèm lý do")
    func practiceIncorrectOnHiddenExam() {
        let hidden = makeExam(counts: [2], hideAnswers: true)
        let model = Harness().preExam(hidden, preset: .practiceIncorrect(questionIDs: [hidden.allQuestions[0].id]))
        #expect(model.issues == [.practiceUnavailable])
        #expect(model.issues.first?.message == "Đề này ẩn đáp án nên không luyện tập được")
    }
}
