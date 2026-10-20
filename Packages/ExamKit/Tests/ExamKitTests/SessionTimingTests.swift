import ExamKit
import Foundation
import LargeExamSupport
import Testing

/// Lõi của Bắt đầu và đổi câu trên đề chuẩn 2.000 câu (docs/product/large-exams.md): `ExamComposer` + `ExamSession`
/// (phần còn lại của Bắt đầu, model phiên và bảng câu hỏi đo ở SessionFeatureTests).
@Suite("Timing: tạo đề và phiên trên đề chuẩn")
struct SessionTimingTests {
    struct FixedClock: SessionClock {
        func now() -> Date { Date(timeIntervalSince1970: 1_792_000_000) }
        func uptime() -> TimeInterval { 1_000 }
    }

    @Test("Tạo đề (xáo câu và lựa chọn, cả đề) + tạo phiên; đi hết 2.000 câu và trả lời")
    func composeAndSession() throws {
        let exam = StandardExam.standard.exam
        let options = CompositionOptions(
            selection: .random(count: 2_000), shuffleQuestions: true, shuffleOptions: true, seed: 77)
        var session: ExamSession?
        let compose = try Timing.measure(.sessionCompose) {
            let paper = try ExamComposer.compose(exam, options: options)
            session = try ExamSession(
                exam: exam, paper: paper, mode: .exam, timeLimitMinutes: nil, candidateName: "An", clock: FixedClock())
        }
        var s = try #require(session)
        #expect(s.questionCount == 2_000)
        #expect(Set(s.paper.questionIDs).count == 2_000)
        #expect(compose.isWithinLimit, "\(compose.line)")

        // Đi hết đề, mỗi câu chọn lựa chọn đầu: kiểm phiên không chậm dần theo số câu đã trả lời.
        for index in 0 ..< s.questionCount {
            try s.goTo(index: index)
            try s.select(option: s.currentItem.optionOrder[0])
        }
        #expect(s.unansweredCount == 0)
    }
}
