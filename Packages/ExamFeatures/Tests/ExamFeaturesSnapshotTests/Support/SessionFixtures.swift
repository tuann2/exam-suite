import AppKit
import CryptoKit
import ExamFile
import ExamKit
import Foundation
import LibraryData
import ReportFeature
@testable import SessionFeature
@testable import SessionModel

// Dữ liệu cố định cho snapshot: id, ngày giờ, seed, đồng hồ đều là hằng số để ảnh không đổi giữa các lần chạy.

/// Id cố định: `00000000-0000-0000-0000-0000000000NN`.
func fixedID(_ n: Int) -> UUID {
    UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", n))!
}

/// 2026-10-15 09:30 giờ Việt Nam.
let fixedNow = Date(timeIntervalSince1970: 1_792_031_400)

// MARK: - Đồ giả của phiên thi

/// Đồng hồ đứng yên, chỉ đổi khi test gọi `advance`.
final class FixedClock: SessionClock, @unchecked Sendable {
    private let lock = NSLock()
    private var uptimeValue: TimeInterval = 1000
    private var date = fixedNow

    func now() -> Date { lock.withLock { date } }
    func uptime() -> TimeInterval { lock.withLock { uptimeValue } }

    func advance(_ seconds: TimeInterval) {
        lock.withLock {
            uptimeValue += seconds
            date = date.addingTimeInterval(seconds)
        }
    }
}

@MainActor
final class FixedPreferences: SessionPreferences, ReportPreferences {
    var candidateName = "Nguyễn Thị Minh Khai"
    var lastMode: SessionMode = .practice
    var reportReviewLevel: ResultsReviewLevel = .default
}

/// Thư viện giả trong bộ nhớ: đề, lần thi và payload.
@MainActor
final class MemoryLibrary: SessionLibrary {
    var entries: [UUID: LibraryEntry] = [:]
    var packages: [UUID: ExamPackage] = [:]
    var storedAttempts: [Attempt] = []
    var payloads: [UUID: Data] = [:]

    func add(_ package: ExamPackage) {
        let exam = package.exam
        entries[exam.id] = LibraryEntry(
            examID: exam.id,
            summary: ExamSummary(package: package),
            fileURL: URL(fileURLWithPath: "/tmp/\(exam.id).exam"),
            addedAt: fixedNow,
            status: .ready
        )
        packages[exam.id] = package
    }

    func entry(_ examID: UUID) -> LibraryEntry? { entries[examID] }

    func attempts(examID: UUID) -> [Attempt] {
        storedAttempts.filter { $0.examID == examID }.sorted(by: Attempt.newestFirst)
    }

    func saveAttempt(_ attempt: Attempt, payload: Data) throws {
        storedAttempts.append(attempt)
        payloads[attempt.id] = payload
    }

    func attemptPayload(id: UUID) throws -> Data? { payloads[id] }

    func readExam(_ examID: UUID) async -> Result<ExamPackage, ExamLoadFailure> {
        guard let package = packages[examID] else { return .failure(.notInLibrary) }
        return .success(package)
    }

    func examFileNeedsRefresh(_ examID: UUID) {}
}

/// Phụ thuộc giả của một phiên: thư viện, cài đặt, đồng hồ, seed và id lần thi cố định.
@MainActor
final class SessionHarness {
    let library = MemoryLibrary()
    let preferences = FixedPreferences()
    let clock = FixedClock()
    private var attemptNumber = 900

    var environment: SessionEnvironment {
        SessionEnvironment(
            library: library,
            preferences: preferences,
            makeSeed: { 42 },
            makeClock: { [clock] in clock },
            makeAttemptID: { [weak self] in
                guard let self else { return fixedID(999) }
                attemptNumber += 1
                return fixedID(attemptNumber)
            }
        )
    }

    /// Bắt đầu phiên, giữ thứ tự câu và lựa chọn như trong đề.
    func start(_ package: ExamPackage, mode: SessionMode) async throws -> AttemptModel {
        library.add(package)
        let preExam = PreExamModel(package: package, preset: .fresh, environment: environment)
        preExam.mode = mode
        preExam.shuffleQuestions = false
        preExam.shuffleOptions = false
        guard let attempt = await preExam.start() else {
            throw StartFailed(reason: preExam.startFailure ?? preExam.issues.map(\.message).joined(separator: "; "))
        }
        return attempt
    }

    /// Cửa sổ làm bài của một phiên (như `SessionCoordinator.startPreExam`).
    func window(for attempt: AttemptModel) -> SessionWindowModel {
        SessionWindowModel(attempt: attempt, environment: environment)
    }

    struct StartFailed: Error { let reason: String }
}

extension SessionHarness {
    /// Làm và nộp bài Thi của `package`: mỗi phần một số câu đúng khác nhau, vài câu bỏ trống. Có `previousPercent` thì
    /// thêm một lần thi trước (cho "So với lần trước"). Dùng chung cho snapshot Kết quả, Xem lại bài và PDF kết quả.
    func submittedWindow(package: ExamPackage, previousPercent: Int? = nil) async throws -> SessionWindowModel {
        if let previousPercent {
            library.storedAttempts.append(Attempt(
                id: fixedID(800),
                examID: package.exam.id,
                examTitle: package.exam.title,
                candidateName: preferences.candidateName,
                mode: .exam,
                startedAt: fixedNow.addingTimeInterval(-90_000),
                submittedAt: fixedNow.addingTimeInterval(-86_400),
                elapsedSeconds: 3000,
                correct: package.exam.questionCount * previousPercent / 100,
                total: package.exam.questionCount,
                score1000: previousPercent * 10,
                percent: previousPercent,
                passed: false
            ))
        }
        let attempt = try await start(package, mode: .exam)
        let count = attempt.questionCount
        for index in 0 ..< count {
            _ = attempt.goTo(index: index)
            let section = index / 5
            let position = index % 5
            // Phần i đúng (5 - i % 4) câu đầu; câu cuối phần 3 bỏ trống.
            if section == 2, position == 4 { continue }
            if position < 5 - section % 4 { attempt.answerCorrectly() } else { attempt.answerWrongly() }
            if index == 1 { attempt.answerWrongly() }
        }
        _ = attempt.goTo(index: 1)
        attempt.perform(.toggleFlag)
        clock.advance(2534)
        attempt.tick()
        let sessionWindow = window(for: attempt)
        attempt.perform(.openReview)
        sessionWindow.requestSubmit()
        if attempt.isConfirmingSubmit { sessionWindow.confirmSubmit() }
        guard sessionWindow.results != nil else { throw StartFailed(reason: "chưa nộp được bài") }
        return sessionWindow
    }
}

extension AttemptModel {
    func answerCorrectly() {
        for id in currentQuestion.correct { selectOption(id) }
    }

    func answerWrongly() {
        let wrong = currentQuestion.options.map(\.id).first { !currentQuestion.correctSet.contains($0) }!
        selectOption(wrong)
    }
}

// MARK: - Nội dung đề

enum SnapshotContent {
    /// Câu hỏi dài (nhiều đoạn, có Markdown), như đề luật/nghiệp vụ thật.
    static let longQuestionText = """
        Một doanh nghiệp xuất khẩu nông sản ký hợp đồng mua bán với đối tác nước ngoài theo điều kiện **CIF** cảng \
        Rotterdam. Trong quá trình vận chuyển, lô hàng bị hư hỏng một phần do nước biển tràn vào hầm tàu khi gặp bão \
        lớn ngoài khơi; người mua phát hiện tổn thất khi dỡ hàng và lập biên bản giám định có xác nhận của thuyền \
        trưởng, đồng thời gửi thông báo tổn thất cho người bảo hiểm trong thời hạn quy định.

        Theo *Incoterms 2020* và các nguyên tắc bảo hiểm hàng hoá vận chuyển bằng đường biển, hãy xác định bên nào \
        chịu rủi ro đối với tổn thất trên, bên nào có quyền đòi bồi thường từ người bảo hiểm, và điều kiện bảo hiểm \
        tối thiểu mà người bán phải mua theo hợp đồng. Lưu ý: hợp đồng không có thoả thuận riêng về phạm vi bảo hiểm, \
        và giá trị bảo hiểm được tính theo `CIF + 10%`.
        """

    /// Mười lựa chọn (A–J), dài ngắn khác nhau, có lựa chọn xuống nhiều dòng.
    static let manyOptions: [String] = [
        "Người bán chịu rủi ro và có quyền đòi bồi thường vì người bán là người mua bảo hiểm.",
        "Người mua chịu rủi ro kể từ khi hàng được giao lên tàu tại cảng đi; người mua có quyền đòi bồi thường "
            + "từ người bảo hiểm với tư cách người được chuyển nhượng quyền lợi bảo hiểm.",
        "Người chuyên chở chịu toàn bộ tổn thất.",
        "Hai bên chia đôi tổn thất theo nguyên tắc tổn thất chung.",
        "Người mua chịu rủi ro; điều kiện bảo hiểm tối thiểu là ICC (C).",
        "Người bán chịu rủi ro cho tới khi hàng tới cảng đích.",
        "Người bảo hiểm từ chối bồi thường vì bão là sự kiện bất khả kháng.",
        "Người mua chịu rủi ro; điều kiện bảo hiểm tối thiểu là ICC (A).",
        "Không đủ thông tin để xác định.",
        "Cả B và E đều đúng.",
    ]

    /// Ảnh lớn 2400×1600 vẽ bằng code (mảng màu, lưới, hình tròn), PNG; tên theo SHA-256 như exam-format.md.
    static func largeImage() -> (path: String, data: Data) {
        let width = 2400
        let height = 1600
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        )!
        let context = NSGraphicsContext(bitmapImageRep: rep)!
        let cg = context.cgContext
        // Mảng màu phẳng (không dải màu) để ảnh chụp màn hình nén PNG nhỏ.
        cg.setFillColor(CGColor(red: 0.0, green: 0.47, blue: 0.47, alpha: 1))
        cg.fill(CGRect(x: 0, y: 0, width: width, height: height))
        cg.setFillColor(CGColor(red: 0.95, green: 0.85, blue: 0.6, alpha: 1))
        cg.fill(CGRect(x: width / 2, y: 0, width: width / 2, height: height / 2))
        cg.setStrokeColor(CGColor(gray: 1, alpha: 0.6))
        cg.setLineWidth(6)
        for x in stride(from: 0, through: width, by: 200) {
            cg.move(to: CGPoint(x: x, y: 0))
            cg.addLine(to: CGPoint(x: x, y: height))
        }
        for y in stride(from: 0, through: height, by: 200) {
            cg.move(to: CGPoint(x: 0, y: y))
            cg.addLine(to: CGPoint(x: width, y: y))
        }
        cg.strokePath()
        cg.setFillColor(CGColor(red: 0.6, green: 0.1, blue: 0.2, alpha: 1))
        cg.fillEllipse(in: CGRect(x: 900, y: 500, width: 600, height: 600))
        let data = rep.representation(using: .png, properties: [:])!
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        return ("media/\(hash.prefix(16)).png", data)
    }

    static func option(_ index: Int, _ text: String) -> Option {
        Option(id: OptionID(index: index)!, text: text)
    }

    /// Đề cho màn làm bài: câu 1 dài với 10 lựa chọn, câu 2 có ảnh lớn; thêm hai phần để bảng câu hỏi có nhiều nhóm.
    static func attemptPackage() -> ExamPackage {
        let image = largeImage()
        let long = Question(
            id: fixedID(101),
            type: .single,
            text: longQuestionText,
            options: manyOptions.enumerated().map { option($0.offset, $0.element) },
            correct: [OptionID("B")!],
            explanation: "Theo CIF, rủi ro chuyển sang người mua khi hàng đã được giao lên tàu."
        )
        let pictured = Question(
            id: fixedID(102),
            type: .multiple,
            text: "Câu 2: Quan sát sơ đồ cảng dưới đây. Những khu vực nào được dùng để lưu kho hàng **container lạnh**?",
            image: image.path,
            options: (0 ..< 4).map { option($0, "Khu vực \($0 + 1)") },
            correct: [OptionID("A")!, OptionID("C")!],
            explanation: "Khu 1 và khu 3 có ổ cắm điện cho container lạnh."
        )
        var sections = [ExamSection(
            id: fixedID(201),
            title: "Phần 1: Điều kiện thương mại quốc tế",
            questions: [long, pictured] + (3 ... 12).map { regularQuestion(number: $0, id: 100 + $0) }
        )]
        for (index, title) in ["Phần 2: Thanh toán quốc tế", "Phần 3: Vận tải và bảo hiểm"].enumerated() {
            sections.append(ExamSection(
                id: fixedID(202 + index),
                title: title,
                questions: (1 ... 14).map { regularQuestion(number: $0, id: 300 + index * 50 + $0) }
            ))
        }
        let exam = Exam(
            id: fixedID(1),
            title: "Nghiệp vụ ngoại thương — Đề tổng hợp",
            code: "NVNT-2026",
            passPercent: 70,
            timeLimitMinutes: 90,
            instructions: "Đọc kỹ từng câu.",
            sections: sections
        )
        return ExamPackage(exam: exam, media: [image.path: image.data])
    }

    static func regularQuestion(number: Int, id: Int, multiple: Bool = false) -> Question {
        Question(
            id: fixedID(id),
            type: multiple ? .multiple : .single,
            text: "Câu \(number): Nội dung câu hỏi số \(number) về nghiệp vụ, đủ dài để xuống dòng khi cửa sổ hẹp.",
            options: (0 ..< 4).map { option($0, "Phương án \($0 + 1) của câu \(number)") },
            correct: multiple ? [OptionID("A")!, OptionID("C")!] : [OptionID("B")!],
            explanation: "Giải thích ngắn cho câu \(number)."
        )
    }

    /// Đề nhiều phần (8 phần, tên phần dài ngắn khác nhau) cho màn Kết quả.
    static func manySectionsExam(hideAnswers: Bool = false) -> Exam {
        let titles = [
            "Phần 1: Pháp luật về doanh nghiệp",
            "Phần 2: Thuế giá trị gia tăng",
            "Phần 3: Kế toán",
            "Phần 4: Thuế thu nhập doanh nghiệp và các khoản ưu đãi thuế theo quy định hiện hành",
            "Phần 5: Hoá đơn, chứng từ",
            "Phần 6: Quản lý thuế",
            "Phần 7: Bảo hiểm xã hội",
            "Phần 8: Tình huống tổng hợp",
        ]
        return Exam(
            id: fixedID(2),
            title: "Ôn thi kế toán viên — Bộ đề 3",
            code: "KTV-03",
            passPercent: 60,
            timeLimitMinutes: 120,
            hideAnswers: hideAnswers,
            instructions: nil,
            sections: titles.enumerated().map { index, title in
                ExamSection(
                    id: fixedID(400 + index),
                    title: title,
                    questions: (1 ... 5).map { regularQuestion(number: index * 5 + $0, id: 500 + index * 10 + $0) }
                )
            }
        )
    }
}
