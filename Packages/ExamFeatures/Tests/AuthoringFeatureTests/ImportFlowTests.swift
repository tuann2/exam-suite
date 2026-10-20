import AppKit
import AuthoringData
@testable import AuthoringFeature
import ExamImport
import ExamKit
import Foundation
import SwiftUI
import Testing

// MARK: - Dữ liệu tự soạn

/// Kết quả import dựng tay (không đọc file): hai phần, ba câu; báo cáo có một câu bị bỏ, một cảnh báo của câu 2 và một
/// cảnh báo đầu file.
private func sampleResult(suggestions: ImportSuggestions = ImportSuggestions(title: "Đề import")) -> ImportResult {
    ImportResult(
        examID: fixedID(100),
        sections: [
            ExamSection(id: fixedID(101), title: "Phần A", questions: [makeQuestion(111, "Câu một"), makeQuestion(112, "Câu hai")]),
            ExamSection(id: fixedID(102), title: "Phần B", questions: [makeQuestion(113, "Câu ba")]),
        ],
        media: [:],
        report: ExamImport.ImportReport(entries: [
            ImportReportEntry(code: .textBeforeFirstQuestion, location: ImportLocation(line: 1), questionID: nil,
                              detail: .textBeforeFirstQuestion(fromLine: 1, toLine: 2)),
            ImportReportEntry(code: .optionLabelsShifted, location: ImportLocation(questionNumber: 2, line: 9),
                              questionID: fixedID(112),
                              detail: .optionLabelsShifted(OptionShift(
                                  originalFirst: "B", originalLast: "E", newLast: "D", firstLine: 9,
                                  answerBefore: nil, answerAfter: nil, unmatched: []
                              ))),
            ImportReportEntry(code: .noOptions, location: ImportLocation(questionNumber: 4, line: 20), questionID: nil,
                              detail: .noOptions(misplaced: nil)),
            ImportReportEntry(code: .missingAnswer, location: ImportLocation(questionNumber: 5), questionID: fixedID(113),
                              detail: .missingAnswerLine),
        ]),
        suggestions: suggestions,
        sourceFormat: .txt
    )
}

/// Bộ chuyển đổi giả trả ngay kết quả cho trước (và đếm số lần gọi).
private final class FixedRunner: @unchecked Sendable {
    private let lock = NSLock()
    private var _calls: [URL] = []
    let outcome: Result<ImportResult, ImportError>

    init(_ outcome: Result<ImportResult, ImportError>) {
        self.outcome = outcome
    }

    var calls: [URL] { lock.withLock { _calls } }

    var runner: ExamImportRunner {
        { url, progress in
            self.lock.withLock { self._calls.append(url) }
            progress(ImportProgress(phase: .converting, fractionCompleted: 0.5))
            return try self.outcome.get()
        }
    }
}

/// Bộ chuyển đổi giả: lần gọi đầu chạy tới khi bị huỷ (như đọc file lớn), báo tiến độ trước khi chờ; các lần sau trả
/// kết quả ngay.
private func blockingRunner(started: AsyncStream<Void>.Continuation) -> ExamImportRunner {
    let calls = CallCounter()
    return { _, progress in
        guard calls.next() == 1 else { return sampleResult() }
        progress(ImportProgress(phase: .converting, fractionCompleted: 0.3))
        started.yield()
        try await Task.sleep(for: .seconds(600))
        return sampleResult()
    }
}

private final class CallCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    func next() -> Int {
        lock.withLock {
            count += 1
            return count
        }
    }
}

private let fileURL = URL(fileURLWithPath: "/tmp/g44b-khong-ton-tai/de-thu.txt")

// MARK: - Hộp thoại xác nhận

@Suite("Import đề…: hộp thoại xác nhận điền sẵn và kiểm giá trị theo exam-format.md")
struct ImportConfirmFormTests {
    private func form(_ suggestions: ImportSuggestions) -> ImportConfirmForm {
        ImportConfirmForm(suggestions: suggestions, summary: ImportSummary(sampleResult(suggestions: suggestions)))
    }

    @Test("Điền sẵn từ file (docx: mã, ngưỡng, thời gian): Import bật ngay, giá trị đúng")
    func prefilledFromFile() throws {
        let f = form(ImportSuggestions(title: "  Đề ôn tập mẫu  ", code: "MAU042", passPercent: 80, timeLimitMinutes: 120))
        #expect(f.title == "  Đề ôn tập mẫu  ")
        #expect(f.code == "MAU042")
        #expect(f.passPercent == "80")
        #expect(f.timeLimitMinutes == "120")
        #expect(ImportConfirmForm.Field.allCases.allSatisfy { f.problem($0) == nil })
        #expect(f.canImport)
        let confirmation = try #require(f.confirmation)
        #expect(confirmation == ImportConfirmation(title: "Đề ôn tập mẫu", code: "MAU042", passPercent: 80, timeLimitMinutes: 120))
    }

    @Test("File không có ngưỡng/thời gian (txt): hai ô trống, phải nhập trước khi Import bật; mã trống thì đề không có mã")
    func missingValuesMustBeEntered() throws {
        var f = form(ImportSuggestions(title: "MAU_TXT_A"))
        #expect(f.code.isEmpty && f.passPercent.isEmpty && f.timeLimitMinutes.isEmpty)
        #expect(f.problem(.title) == nil)
        #expect(f.problem(.code) == nil)
        #expect(f.problem(.passPercent) == "Nhập ngưỡng đậu (%).")
        #expect(f.problem(.timeLimitMinutes) == "Nhập thời gian Thi (phút).")
        #expect(!f.canImport)
        f.passPercent = "65"
        #expect(!f.canImport)
        f.timeLimitMinutes = " 90 "
        #expect(f.canImport)
        #expect(f.confirmation == ImportConfirmation(title: "MAU_TXT_A", code: nil, passPercent: 65, timeLimitMinutes: 90))
    }

    @Test("Biên của ngưỡng đậu (0–100) và thời gian (1–600): trong khoảng thì được, ngoài khoảng hoặc không phải số nguyên thì không")
    func numericRanges() {
        var f = form(ImportSuggestions(title: "Đề", passPercent: 0, timeLimitMinutes: 1))
        #expect(f.canImport)
        f.passPercent = "100"
        f.timeLimitMinutes = "600"
        #expect(f.canImport)
        for bad in ["101", "-1", "7.5", "abc", "80%", "１０", "1234567"] {
            f.passPercent = bad
            #expect(f.problem(.passPercent) == "Ngưỡng đậu là số nguyên từ 0 đến 100.", "ngưỡng \(bad)")
            #expect(!f.canImport)
        }
        f.passPercent = "70"
        for bad in ["0", "601", "-5", "1,5", "phút"] {
            f.timeLimitMinutes = bad
            #expect(f.problem(.timeLimitMinutes) == "Thời gian Thi là số nguyên từ 1 đến 600 phút.", "thời gian \(bad)")
            #expect(!f.canImport)
        }
    }

    @Test("Tiêu đề 1–200 ký tự sau khi bỏ khoảng trắng; mã đề theo mẫu [A-Za-z0-9._-]{1,32} hoặc để trống")
    func titleAndCode() {
        var f = form(ImportSuggestions(title: "Đề", passPercent: 70, timeLimitMinutes: 60))
        f.title = " \u{00A0}\n"
        #expect(f.problem(.title) == "Nhập tiêu đề đề thi.")
        #expect(!f.canImport)
        f.title = String(repeating: "ệ", count: 200)
        #expect(f.problem(.title) == nil)
        f.title = String(repeating: "a", count: 201)
        #expect(f.problem(.title) == "Tiêu đề dài 201 ký tự, tối đa 200.")
        f.title = "Đề"
        for good in ["", "  ", "KTC-01_v2.1", String(repeating: "x", count: 32)] {
            f.code = good
            #expect(f.problem(.code) == nil, "mã \(good)")
        }
        for bad in ["Mã đề", "KTC 01", String(repeating: "x", count: 33), "a/b"] {
            f.code = bad
            #expect(f.problem(.code) != nil, "mã \(bad)")
            #expect(!f.canImport)
        }
    }

    @Test("Tiêu đề chuẩn hoá NFC khi dựng đề")
    func titleNormalizedToNFC() throws {
        var f = form(ImportSuggestions(title: "Đề", passPercent: 70, timeLimitMinutes: 60))
        f.title = "Tie\u{0302}\u{0301}ng Vie\u{0323}\u{0302}t"
        let confirmation = try #require(f.confirmation)
        #expect(confirmation.title == "Tiếng Việt")
        #expect(confirmation.title.unicodeScalars.count == 10)
    }

    @Test("Tóm tắt: số phần, số câu, số câu bị bỏ, số cảnh báo")
    func summary() {
        let summary = ImportSummary(sampleResult())
        #expect(summary == ImportSummary(sectionCount: 2, questionCount: 3, droppedCount: 1, warningCount: 3))
        #expect(summary.text == "2 phần · 3 câu · 1 câu bị bỏ · 3 cảnh báo")
    }
}

// MARK: - Luồng import

@MainActor
@Suite("Import đề…: đọc nền, huỷ, lỗi không mở cửa sổ, xác nhận mở đề chưa lưu kèm báo cáo")
struct ImportFlowModelTests {
    @Test("Đọc xong → hộp thoại xác nhận điền sẵn; Import dựng đề với giá trị đã nhập, id và nội dung từ file")
    func importAndConfirm() async throws {
        let fixed = FixedRunner(.success(sampleResult(
            suggestions: ImportSuggestions(title: "Đề import", code: "IMP01", passPercent: 80)
        )))
        let model = ImportFlowModel(runner: fixed.runner)
        #expect(model.start(fileURL) == .started)
        #expect(model.phase == .reading)
        #expect(model.fileName == "de-thu.txt")
        await model.waitUntilSettled()
        #expect(model.phase == .confirming)
        #expect(fixed.calls == [fileURL])
        var form = try #require(model.form)
        #expect(form.title == "Đề import" && form.code == "IMP01" && form.passPercent == "80" && form.timeLimitMinutes.isEmpty)
        #expect(model.confirm() == nil, "thời gian Thi còn trống thì Import tắt")
        #expect(model.phase == .confirming)

        form.timeLimitMinutes = "90"
        model.form = form
        let imported = try #require(model.confirm())
        #expect(model.phase == .idle)
        #expect(model.form == nil)
        #expect(model.failure == nil)
        let exam = imported.draft.exam
        #expect(exam.id == fixedID(100))
        #expect(exam.title == "Đề import" && exam.code == "IMP01")
        #expect(exam.passPercent == 80 && exam.timeLimitMinutes == 90)
        #expect(exam.sections.map(\.title) == ["Phần A", "Phần B"])
        #expect(exam.questionCount == 3)
        #expect(imported.report.fileName == "de-thu.txt")
        #expect(imported.report.rows.count == 4)
        // Câu VoiceOver khi import xong: tên file và tóm tắt của hộp xác nhận.
        #expect(imported.announcement == "Đã import “de-thu.txt”: \(form.summary.text)")
        #expect(imported.announcement.hasPrefix("Đã import “de-thu.txt”: 2 phần · 3 câu"))
    }

    @Test("Huỷ khi đang đọc: bộ chuyển đổi dừng, không báo lỗi, không có đề; import lại được")
    func cancelWhileReading() async throws {
        let (started, continuation) = AsyncStream<Void>.makeStream()
        var failures: [ImportFailure] = []
        let model = ImportFlowModel(runner: blockingRunner(started: continuation))
        model.onFailure = { failures.append($0) }
        #expect(model.start(fileURL) == .started)
        for await _ in started { break }
        // Tiến độ đến main actor sau khi bộ chuyển đổi báo.
        for _ in 0 ..< 100 where model.progress == 0 { await Task.yield() }
        #expect(model.progress == 0.3)
        #expect(model.start(fileURL) == .busy)

        model.cancel()
        #expect(model.phase == .idle)
        await model.waitUntilSettled()
        #expect(model.phase == .idle)
        #expect(model.form == nil)
        #expect(model.failure == nil)
        #expect(failures.isEmpty)
        #expect(model.confirm() == nil)
        #expect(model.progress == 0)

        // Import lại trên chính model vừa huỷ: đọc xong, tới hộp xác nhận.
        #expect(model.start(fileURL) == .started)
        await model.waitUntilSettled()
        #expect(model.phase == .confirming)
        #expect(model.form != nil)
        #expect(failures.isEmpty)
    }

    @Test("Kết quả đến sau khi đã Huỷ (bộ chuyển đổi không kịp dừng): bị bỏ, không hiện hộp thoại xác nhận")
    func lateResultAfterCancelIsIgnored() async {
        let (gate, open) = AsyncStream<Void>.makeStream()
        let model = ImportFlowModel(runner: { _, _ in
            for await _ in gate { break }
            return sampleResult()
        })
        model.start(fileURL)
        model.cancel()
        open.yield()
        await model.waitUntilSettled()
        #expect(model.phase == .idle)
        #expect(model.form == nil)
    }

    @Test("Huỷ trên hộp thoại xác nhận: bỏ kết quả, không mở gì")
    func cancelAtConfirmation() async {
        let model = ImportFlowModel(runner: FixedRunner(.success(sampleResult())).runner)
        model.start(fileURL)
        await model.waitUntilSettled()
        #expect(model.phase == .confirming)
        model.cancel()
        #expect(model.phase == .idle)
        #expect(model.confirm() == nil)
    }

    @Test("Ô của hộp xác nhận đọc/ghi qua model: Import và Huỷ đưa form về nil, ô đọc ra rỗng, ghi không làm gì (không ép mở)")
    func fieldTextAfterFormCleared() async throws {
        for ending in ["import", "huỷ"] {
            let model = ImportFlowModel(runner: FixedRunner(.success(sampleResult())).runner)
            model.start(fileURL)
            await model.waitUntilSettled()
            #expect(model.phase == .confirming)
            #expect(model.text(of: .title) == "Đề import")
            #expect(model.text(of: .passPercent).isEmpty)
            model.setText("70", of: .passPercent)
            model.setText("45", of: .timeLimitMinutes)
            model.setText("MA-01", of: .code)
            #expect(model.form?.passPercent == "70" && model.form?.timeLimitMinutes == "45" && model.form?.code == "MA-01")
            #expect(model.form?.canImport == true)
            if ending == "import" {
                #expect(model.confirm() != nil)
            } else {
                model.cancel()
            }
            #expect(model.phase == .idle)
            #expect(model.form == nil)
            // Ô còn được dựng lại một lượt sau Import/Huỷ: đọc rỗng, ghi bị bỏ, không tạo lại form.
            for field in ImportConfirmForm.Field.allCases {
                #expect(model.text(of: field).isEmpty)
                model.setText("x", of: field)
            }
            #expect(model.form == nil, "\(ending)")
        }
    }

    @Test("Hộp xác nhận dựng trong NSHostingView: Import rồi Huỷ đưa form về nil giữa hai lần layout, không dừng app")
    @MainActor
    func confirmViewSurvivesFormCleared() async throws {
        for ending in ["import", "huỷ"] {
            let model = ImportFlowModel(runner: FixedRunner(.success(sampleResult())).runner)
            model.start(fileURL)
            await model.waitUntilSettled()
            model.setText("70", of: .passPercent)
            model.setText("45", of: .timeLimitMinutes)
            let host = NSHostingView(rootView: ImportConfirmView(model: model, open: { _ in }))
            host.frame = NSRect(x: 0, y: 0, width: 480, height: 480)
            host.layoutSubtreeIfNeeded()
            if ending == "import" {
                #expect(model.confirm() != nil)
            } else {
                model.cancel()
            }
            // Lượt cập nhật kế tiếp của SwiftUI sau khi form về nil (nơi binding ép mở từng làm app dừng).
            for _ in 0 ..< 3 {
                host.needsLayout = true
                host.layoutSubtreeIfNeeded()
                await Task.yield()
            }
            #expect(model.form == nil)
        }
    }

    @Test("Lỗi đọc file (không có câu nào): báo lý do một lần, không có đề, về trạng thái chờ")
    func importErrorOpensNothing() async {
        let error = ImportError.noQuestions(dropped: 2)
        var failures: [ImportFailure] = []
        let model = ImportFlowModel(runner: FixedRunner(.failure(error)).runner)
        model.onFailure = { failures.append($0) }
        #expect(model.start(fileURL) == .started)
        await model.waitUntilSettled()
        #expect(model.phase == .idle)
        #expect(model.form == nil)
        #expect(model.confirm() == nil)
        #expect(failures.count == 1)
        #expect(failures.first == model.failure)
        #expect(model.failure?.title == "Không import được “de-thu.txt”")
        #expect(model.failure?.message == error.logMessage)
    }

    @Test("Đuôi không hỗ trợ: báo lỗi, không đọc file, không mở cửa sổ; hộp chọn file cho .txt, .docx, .vce")
    func unsupportedExtensionIsRejected() {
        let fixed = FixedRunner(.success(sampleResult()))
        var failures: [ImportFailure] = []
        let model = ImportFlowModel(runner: fixed.runner)
        model.onFailure = { failures.append($0) }
        #expect(model.start(URL(fileURLWithPath: "/tmp/g44b/de.pdf")) == .rejected)
        #expect(model.phase == .idle)
        #expect(failures.count == 1)
        #expect(failures[0].message == ImportError.unsupportedFileType("pdf").logMessage)
        #expect(fixed.calls.isEmpty)
        #expect(ImportFlowModel.selectableExtensions == ["txt", "docx", "vce"])
    }

    @Test(".vce tự dựng (bộ đọc thật): đọc nền, hộp xác nhận điền sẵn mã, ngưỡng, thời gian; Import dựng đề")
    func vceImportFlow() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("g44b-vce-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        var writer = MiniVceWriter()
        writer.questions = [
            .init(text: "Giao thức nào dùng cổng 53?", options: ["HTTP", "DNS", "FTP"], answer: "B"),
            .init(text: "Chọn hai cổng của web.", options: ["80", "22", "443"], answer: "AC"),
        ]
        let url = directory.appendingPathComponent("On tap.vce")
        try writer.data().write(to: url)

        let model = ImportFlowModel()
        #expect(model.start(url) == .started)
        await model.waitUntilSettled()
        #expect(model.phase == .confirming)
        let form = try #require(model.form)
        #expect(form.title == "De VCE tu soan")
        #expect(form.code == "MINI-VCE")
        #expect(form.passPercent == "70")
        #expect(form.timeLimitMinutes == "45")
        #expect(form.summary.questionCount == 2)
        #expect(form.canImport)
        let imported = try #require(model.confirm())
        let questions = imported.draft.exam.sections.flatMap(\.questions)
        #expect(questions.map(\.type) == [.single, .multiple])
        #expect(questions[0].text == "Giao thức nào dùng cổng 53?")
        #expect(imported.report.fileName == "On tap.vce")
    }

    @Test(".vce không đọc được (hỏng): báo lý do của bộ đọc .vce, không có đề")
    func unreadableVceShowsAlert() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("g44b-vce-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        var writer = MiniVceWriter()
        writer.questions = [.init(text: "Câu", options: ["A", "B"], answer: "A")]
        var bytes = writer.data()
        bytes[bytes.count - 1] ^= 0xFF
        let url = directory.appendingPathComponent("hong.vce")
        try bytes.write(to: url)

        var failures: [ImportFailure] = []
        let model = ImportFlowModel()
        model.onFailure = { failures.append($0) }
        model.start(url)
        await model.waitUntilSettled()
        #expect(model.phase == .idle)
        #expect(model.confirm() == nil)
        #expect(failures.count == 1)
        #expect(failures.first?.title == "Không import được “hong.vce”")
        #expect(failures.first?.message.hasPrefix("File .vce không đọc được:") == true)
    }

    @Test("Bộ chuyển đổi thật trên file .txt tự soạn: Import mở được đề, lỗi file trống không mở gì")
    func liveRunnerOnSelfAuthoredText() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("g44b-import-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let good = directory.appendingPathComponent("Mạng cơ bản.txt")
        try Data("""
            Q1:
            Giao thức nào dùng cổng 443?
            A. HTTP
            B. HTTPS
            Correct Answer: B

            Q2:
            Chọn hai địa chỉ riêng.
            A. 10.0.0.1
            B. 8.8.8.8
            C. 192.168.1.1
            Correct Answer: A,C
            """.utf8).write(to: good)
        let model = ImportFlowModel()
        model.start(good)
        await model.waitUntilSettled()
        var form = try #require(model.form)
        #expect(form.title == "Mạng cơ bản")
        #expect(form.summary == ImportSummary(sectionCount: 1, questionCount: 2, droppedCount: 0, warningCount: 0))
        form.passPercent = "50"
        form.timeLimitMinutes = "10"
        model.form = form
        let imported = try #require(model.confirm())
        #expect(imported.draft.exam.sections[0].questions.map(\.type) == [.single, .multiple])
        #expect(imported.draft.validationIssues.filter { $0.severity == .error }.isEmpty)

        let empty = directory.appendingPathComponent("trống.txt")
        try Data("Không có câu nào.\n".utf8).write(to: empty)
        model.start(empty)
        await model.waitUntilSettled()
        #expect(model.phase == .idle)
        #expect(model.failure?.message == ImportError.noQuestions(dropped: 0).logMessage)
    }
}

// MARK: - Báo cáo import trong cửa sổ soạn đề

@MainActor
@Suite("Báo cáo import: mở cùng cửa sổ chưa lưu, vị trí + lý do, bấm dòng có câu thì nhảy tới câu đó")
struct ImportReportNavigationTests {
    private func importedDocument() throws -> ExamAuthoringDocument {
        let result = sampleResult()
        let package = result.makePackage(ImportConfirmation(title: "Đề import", code: nil, passPercent: 70, timeLimitMinutes: 60))
        let imported = ImportedExam(
            draft: ExamDraft(package: package),
            report: ImportReportState(fileName: "de-thu.txt", report: result.report)
        )
        let document = ExamAuthoringDocument(imported: imported)
        // Như cửa sổ thật: bộ soạn đề có `UndoManager` (thiếu thì thao tác sửa báo lỗi lập trình).
        document.editor.undoManager = undoManager
        return document
    }

    private let undoManager = UndoManager()

    @Test("Dòng báo cáo: mức (biểu tượng + chữ), vị trí trong file gốc, lý do; chỉ dòng gắn câu mới bấm được")
    func rows() throws {
        let editor = try importedDocument().editor
        let report = try #require(editor.importReport)
        #expect(editor.showsImportReport)
        #expect(report.droppedCount == 1 && report.warningCount == 3)
        #expect(report.summary == "Báo cáo import “de-thu.txt”: 1 câu bị bỏ · 3 cảnh báo")
        #expect(report.rows.map(\.location) == ["Dòng 1", "Câu 2, dòng 9", "Câu 4, dòng 20", "Câu 5"])
        #expect(report.rows.map(\.severityTitle) == ["Cảnh báo", "Cảnh báo", "Bị bỏ", "Cảnh báo"])
        #expect(report.rows.map(\.questionID) == [nil, fixedID(112), nil, fixedID(113)])
        #expect(report.rows[2].accessibilityLabel
            == "Bị bỏ, Câu 4, dòng 20: Câu không có lựa chọn nào nên bị bỏ. Kiểm tra các dòng lựa chọn (A. …, B. …) trong file gốc.")
        // Lý do là chữ của catalog dựng từ mã (bước 7b), tiếng Việt trùng câu của ExamImport.
        #expect(report.rows.map(\.message) == sampleResult().report.entries.map(\.logMessage))
    }

    @Test("Bấm dòng có câu: chọn đúng câu (theo id, kể cả sau khi sắp xếp lại) và đưa tiêu điểm vào nội dung câu")
    func navigateToQuestion() throws {
        let editor = try importedDocument().editor
        #expect(editor.navigate(toQuestion: fixedID(112)))
        #expect(editor.selection == .question(QuestionPath(section: 0, question: 1)))
        #expect(editor.focusRequest?.focus == .questionText)
        #expect(editor.navigate(toQuestion: fixedID(113)))
        #expect(editor.selection == .question(QuestionPath(section: 1, question: 0)))

        // Câu chuyển sang phần khác sau khi import: vẫn tìm theo id.
        editor.moveQuestion(at: QuestionPath(section: 1, question: 0), toSection: 0)
        editor.selection = .exam
        #expect(editor.navigate(toQuestion: fixedID(113)))
        #expect(editor.selection == .question(QuestionPath(section: 0, question: 2)))
    }

    @Test("Ô tìm đang ẩn câu đó thì bỏ tìm; câu đã xoá thì không làm gì")
    func navigateClearsSearchOrIgnoresDeleted() throws {
        let editor = try importedDocument().editor
        editor.searchText = "Câu ba"
        #expect(editor.navigate(toQuestion: fixedID(112)))
        #expect(editor.searchText.isEmpty)

        editor.removeQuestion(at: QuestionPath(section: 0, question: 1))
        editor.selection = .exam
        #expect(!editor.navigate(toQuestion: fixedID(112)))
        #expect(editor.selection == .exam)
    }

    @Test("Đề import: không có lý do từ chối ở mức file, không có ảnh sai tên (giá trị mặc định của document chưa lưu)")
    func importedDocumentDefaults() throws {
        let editor = try importedDocument().editor
        #expect(editor.fileRejection == nil)
        #expect(editor.misnamedImages.isEmpty)
    }

    @Test("Báo cáo trỏ theo id câu nên nhảy đúng câu cả khi đề vừa sửa, chưa kiểm lại (sắp xếp câu trong phần)")
    func navigateRightAfterEditWithStaleIssues() throws {
        let editor = try importedDocument().editor
        editor.moveTreeRows(editor.visibleRows, fromOffsets: IndexSet(integer: 2), toOffset: 1)
        #expect(editor.draft.path(of: fixedID(112)) == QuestionPath(section: 0, question: 0))
        #expect(!editor.issuesAreCurrent)
        #expect(editor.navigate(toQuestion: fixedID(112)))
        #expect(editor.selection == .question(QuestionPath(section: 0, question: 0)))
    }

    @Test("Dòng của câu đã xoá không bấm được (ghi chú “câu đã bị xoá”); dòng không gắn câu cũng không bấm được")
    func destinationOfRows() throws {
        let editor = try importedDocument().editor
        let rows = try #require(editor.importReport).rows
        #expect(rows.map { $0.destination(containsQuestion: editor.containsQuestion) }
            == [.none, .question(fixedID(112)), .none, .question(fixedID(113))])
        editor.removeQuestion(at: QuestionPath(section: 0, question: 1))
        #expect(rows[1].destination(containsQuestion: editor.containsQuestion) == .deletedQuestion)
        #expect(rows[3].destination(containsQuestion: editor.containsQuestion) == .question(fixedID(113)))
    }

    /// Import file `.txt` tự soạn qua luồng thật, xác nhận với ngưỡng/thời gian, trả báo cáo trong cửa sổ.
    private func importText(_ text: String, named name: String) async throws -> (ImportSummary, ImportReportState) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("g44b-cap-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent(name)
        try Data(text.utf8).write(to: url)
        let model = ImportFlowModel()
        model.start(url)
        await model.waitUntilSettled()
        var form = try #require(model.form)
        form.passPercent = "70"
        form.timeLimitMinutes = "60"
        model.form = form
        let imported = try #require(model.confirm())
        return (form.summary, imported.report)
    }

    /// `count` câu có lựa chọn A/B nhưng không có dòng đáp án (mỗi câu một cảnh báo `missingAnswer`), số câu từ `first`.
    private func questionsWithoutAnswer(_ count: Int, from first: Int = 1) -> String {
        (first ..< first + count).map { "Q\($0):\nCâu \($0)?\nA. Có\nB. Không\n" }.joined(separator: "\n")
    }

    @Test("Báo cáo quá 1.000 mục của một loại (trần theo mã): đếm theo cả báo cáo, dòng tóm tắt dễ đọc, không bấm được; loại khác vẫn chi tiết")
    func reportOverDetailLimit() async throws {
        let missing = 1_100
        // Sau 1.100 cảnh báo thiếu đáp án: 5 câu không có dòng A. (cảnh báo loại khác, vẫn có chi tiết vì trần theo mã).
        let shifted = (1 ... 5).map { "Q\(missing + $0):\nCâu lệch \($0)?\nB. Có\nC. Không\nCorrect Answer: B\n" }
        let text = questionsWithoutAnswer(missing) + "\n" + shifted.joined(separator: "\n")
        let (summary, report) = try await importText(text, named: "thieu-dap-an.txt")

        // Hộp xác nhận đếm mọi cảnh báo, không chỉ các dòng chi tiết.
        #expect(summary.questionCount == missing + 5)
        #expect(summary.warningCount == missing + 5)
        #expect(report.warningCount == missing + 5)
        #expect(report.droppedCount == 0)
        // Số theo định dạng của máy (1.105 / 1,105), như giao diện.
        #expect(report.summary == String(localized: "Báo cáo import “thieu-dap-an.txt”: 0 câu bị bỏ · \(missing + 5) cảnh báo"))

        let detailed = report.rows.filter { !$0.isSummary }
        #expect(detailed.filter { $0.code == .missingAnswer }.count == 1_000)
        #expect(detailed.filter { $0.code == .optionLabelsShifted }.count == 5)
        #expect(detailed.allSatisfy { $0.occurrences == 1 && $0.questionID != nil })

        let summaries = report.rows.filter(\.isSummary)
        #expect(summaries.count == 1)
        let summaryRow = try #require(summaries.first)
        #expect(summaryRow.code == .missingAnswer)
        #expect(summaryRow.occurrences == 100)
        #expect(summaryRow.location == "100 mục")
        #expect(summaryRow.message.hasPrefix("… và 100 mục tương tự"))
        #expect(summaryRow.questionID == nil)
        #expect(summaryRow.destination(containsQuestion: { _ in true }) == .none)
    }

    @Test("Vượt trần đúng một mục: mục đó vẫn có chi tiết, không có dòng tóm tắt")
    func reportOverLimitByOne() async throws {
        let (summary, report) = try await importText(questionsWithoutAnswer(1_001), named: "mot-muc.txt")
        #expect(summary.warningCount == 1_001)
        #expect(report.rows.count == 1_001)
        #expect(report.rows.allSatisfy { !$0.isSummary && $0.questionID != nil })
        #expect(report.warningCount == 1_001)
    }

    @Test("Ẩn/hiện bảng báo cáo; đề mới và đề mở từ file không có báo cáo")
    func toggleAndAbsence() throws {
        let editor = try importedDocument().editor
        editor.showsImportReport = false
        #expect(!editor.showsImportReport)
        let plain = ExamAuthoringDocument().editor
        #expect(plain.importReport == nil)
        #expect(!plain.showsImportReport)
    }

    @Test("Đề import là document chưa lưu: lưu bằng ExamPackageWriter rồi mở lại ra đúng đề, không có báo cáo")
    func importedDocumentSavesNormally() throws {
        let document = try importedDocument()
        let snapshot = try document.snapshot(contentType: .examPackage)
        let reopened = try ExamAuthoringDocument(fileData: try ExamAuthoringDocument.fileData(for: snapshot))
        #expect(reopened.draft.exam == document.draft.exam)
        #expect(reopened.editor.importReport == nil)
    }
}
