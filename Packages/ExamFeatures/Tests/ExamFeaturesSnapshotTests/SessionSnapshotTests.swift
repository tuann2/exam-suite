import ExamFile
import ExamKit
import Foundation
import LibraryData
import LibraryFeature
@testable import SessionFeature
import SwiftUI
import Testing

/// Cửa sổ làm bài, Kết quả, Xem lại bài ở 960×640, sáng và tối (plan giai đoạn 5 bước 3; plan-macos-v1.md, Kiểm
/// thử: câu dài, 8+ lựa chọn, ảnh lớn, nhiều phần).
extension SnapshotSuite {
    @MainActor
    @Suite("Snapshot: cửa sổ làm bài")
    struct SessionSnapshotTests {
        /// Như `SessionWindowRoot`: kích thước tối thiểu, màu nhấn teal, model cửa sổ trong môi trường.
        private func windowContent(_ window: SessionWindowModel, @ViewBuilder _ screen: () -> some View) -> some View {
            screen()
                .navigationTitle(window.title)
                .environment(window)
                .frame(minWidth: SessionStyle.minWindowSize.width, minHeight: SessionStyle.minWindowSize.height)
                .tint(SessionStyle.accentForeground)
        }

        // MARK: - Trước khi thi

        /// Sheet **Trước khi thi** (đề 8 phần): chế độ Thi, chọn câu Theo phần, bỏ chọn hai phần đầu (mặc định chọn mọi
        /// phần; còn phần 3–8, 30 câu), thời gian; cỡ lý tưởng của sheet 600×640 (`PreExamView`). Chụp nội dung sheet trong
        /// cửa sổ chụp (không chụp được sheet thật).
        @Test func preExamSheet() async throws {
            let harness = SessionHarness()
            let package = ExamPackage(exam: SnapshotContent.manySectionsExam())
            harness.library.add(package)
            let model = PreExamModel(package: package, preset: .fresh, environment: harness.environment)
            model.mode = .exam
            model.selectionKind = .sections
            // Bỏ chọn phần 1 và 2.
            for section in package.exam.sections.prefix(2) { model.toggleSection(section.id) }
            await SnapshotHost.assertLightAndDark({
                PreExamView(model: model, onStart: {}, onCancel: {})
                    .tint(SessionStyle.accentForeground)
            }, size: CGSize(width: 600, height: 640))
        }

        // MARK: - Làm bài

        /// Thi: câu 1 dài (Markdown), 10 lựa chọn, đã chọn B; bảng câu hỏi ba phần với vài câu đã làm và đánh dấu.
        /// Ảnh thứ hai cuộn tới cuối: lựa chọn J.
        @Test func attemptLongQuestionManyOptions() async throws {
            let (window, attempt) = try await examInProgress(at: 0)
            attempt.selectOption(OptionID("B")!)
            for scroll in [SnapshotScroll.top, .bottom] {
                await SnapshotHost.assertLightAndDark({
                    windowContent(window) { AttemptScreen(window: window, attempt: attempt) }
                }, scroll: scroll)
            }
        }

        /// Thi: câu nhiều đáp án có ảnh 2400×1600 (vừa khung, tối đa cao 320).
        @Test func attemptLargeImage() async throws {
            let (window, attempt) = try await examInProgress(at: 1)
            attempt.selectOption(OptionID("A")!)
            await SnapshotHost.assertLightAndDark {
                windowContent(window) { AttemptScreen(window: window, attempt: attempt) }
            }
        }

        /// Luyện tập sau **Kiểm tra đáp án** sai: dòng kết quả, đánh dấu Đúng/Sai trên lựa chọn, khung giải thích.
        @Test func attemptPracticeCheckedAnswer() async throws {
            let harness = SessionHarness()
            let attempt = try await harness.start(SnapshotContent.attemptPackage(), mode: .practice)
            _ = attempt.goTo(index: 2)
            attempt.answerWrongly()
            attempt.perform(.checkAnswer)
            harness.clock.advance(95)
            attempt.tick()
            let window = harness.window(for: attempt)
            await SnapshotHost.assertLightAndDark {
                windowContent(window) { AttemptScreen(window: window, attempt: attempt) }
            }
        }

        /// Bài Thi đang làm, đứng ở câu `index`: vài câu đã làm, câu 4 đánh dấu, đồng hồ còn 1:17:26.
        private func examInProgress(at index: Int) async throws -> (SessionWindowModel, AttemptModel) {
            let harness = SessionHarness()
            let attempt = try await harness.start(SnapshotContent.attemptPackage(), mode: .exam)
            for answered in [2, 4, 5, 13, 15] {
                _ = attempt.goTo(index: answered)
                attempt.answerCorrectly()
            }
            _ = attempt.goTo(index: 3)
            attempt.perform(.toggleFlag)
            _ = attempt.goTo(index: index)
            harness.clock.advance(754)
            attempt.tick()
            return (harness.window(for: attempt), attempt)
        }

        // MARK: - Kết quả

        /// Kết quả của đề 8 phần (tên phần dài xuống dòng, phần yếu nhất), có so với lần trước. Ảnh thứ hai cuộn tới
        /// cuối: các phần còn lại.
        @Test func resultsManySections() async throws {
            let harness = SessionHarness()
            let package = ExamPackage(exam: SnapshotContent.manySectionsExam())
            let window = try await harness.submittedWindow(package: package, previousPercent: 45)
            let results = try #require(window.results)
            for scroll in [SnapshotScroll.top, .bottom] {
                await SnapshotHost.assertLightAndDark({
                    windowContent(window) {
                        ResultsScreen(window: window, results: results, onRetake: {}, onReturnToLibrary: {})
                    }
                }, scroll: scroll)
            }
        }

        // MARK: - Xem lại bài

        /// Xem lại bài, đề `hideAnswers`: không có "Đáp án đúng" và giải thích, có dòng nhắc ẩn đáp án.
        @Test func answerReviewHideAnswers() async throws {
            let harness = SessionHarness()
            let package = ExamPackage(exam: SnapshotContent.manySectionsExam(hideAnswers: true))
            let window = try await harness.submittedWindow(package: package)
            _ = await window.openAnswerReview(filter: .all)
            let review = try #require(window.answerReview)
            // Câu 2: trả lời sai.
            review.select(index: 1)
            await SnapshotHost.assertLightAndDark {
                windowContent(window) { AnswerReviewScreen(window: window, review: review, onPracticeIncorrect: {}) }
            }
        }

        /// Xem lại bài khi câu đã bị sửa sau lần thi: dòng báo "đã sửa", không đánh dấu lựa chọn (exam-taking.md,
        /// phương án 13, 18).
        @Test func answerReviewEditedQuestion() async throws {
            let harness = SessionHarness()
            let exam = SnapshotContent.manySectionsExam()
            let window = try await harness.submittedWindow(package: ExamPackage(exam: exam))
            let record = try #require(window.results?.record)
            // Sửa nội dung câu 2 sau lần thi (cùng id, khác dấu vân tay).
            var edited = exam
            edited.sections[0].questions[1].text = "Câu 2 (đã sửa): Nội dung mới của câu hỏi sau khi người soạn đề chỉnh lại."
            edited.sections[0].questions[1].options[3].text = "Phương án mới được thêm vào khi sửa đề"
            let review = AnswerReviewModel(record: record, exam: edited, media: [:], filter: .all)
            review.select(index: 1)
            await SnapshotHost.assertLightAndDark {
                windowContent(window) { AnswerReviewScreen(window: window, review: review, onPracticeIncorrect: {}) }
            }
        }

        // MARK: - Cỡ chữ nội dung 150% (bước 8b)

        // Phóng to ba lần (150%, mức lớn nhất của phương án 5) ở cửa sổ tối thiểu 960×640, chỉ ảnh sáng: chữ của vùng nội dung
        // câu lớn hơn, không chữ nào bị cắt hay chồng, vùng câu hỏi cuộn được; thanh công cụ, bảng câu hỏi, thanh nút, danh
        // sách câu của Xem lại bài giữ cỡ chữ của macOS (accessibility-localization.md, mục Cỡ chữ).

        /// Thi: câu 1 dài, 10 lựa chọn, đã chọn B; ảnh thứ hai cuộn tới cuối (lựa chọn J).
        @Test func attemptContentZoom150() async throws {
            let (window, attempt) = try await examInProgress(at: 0)
            attempt.selectOption(OptionID("B")!)
            let zoom = try ZoomDefaults(.largest)
            for scroll in [SnapshotScroll.top, .bottom] {
                await SnapshotHost.assertLightAndDark({
                    windowContent(window) { AttemptScreen(window: window, attempt: attempt) }
                        .defaultAppStorage(zoom.defaults)
                }, appearances: [.light], scroll: scroll)
            }
        }

        /// Luyện tập sau Kiểm tra đáp án sai: nhãn Đúng/Sai trên lựa chọn, dòng kết quả, khung giải thích ở 150%.
        @Test func attemptPracticeCheckedAnswerZoom150() async throws {
            let harness = SessionHarness()
            let attempt = try await harness.start(SnapshotContent.attemptPackage(), mode: .practice)
            _ = attempt.goTo(index: 2)
            attempt.answerWrongly()
            attempt.perform(.checkAnswer)
            harness.clock.advance(95)
            attempt.tick()
            let window = harness.window(for: attempt)
            let zoom = try ZoomDefaults(.largest)
            await SnapshotHost.assertLightAndDark({
                windowContent(window) { AttemptScreen(window: window, attempt: attempt) }
                    .defaultAppStorage(zoom.defaults)
            }, appearances: [.light])
        }

        /// Xem lại bài (bộ lọc Tất cả, câu 2 trả lời sai, đã đánh dấu): "Bạn chọn", "Đáp án đúng", giải thích ở 150%.
        @Test func answerReviewContentZoom150() async throws {
            let harness = SessionHarness()
            let package = ExamPackage(exam: SnapshotContent.manySectionsExam())
            let window = try await harness.submittedWindow(package: package)
            _ = await window.openAnswerReview(filter: .all)
            let review = try #require(window.answerReview)
            review.select(index: 1)
            let zoom = try ZoomDefaults(.largest)
            await SnapshotHost.assertLightAndDark({
                windowContent(window) { AnswerReviewScreen(window: window, review: review, onPracticeIncorrect: {}) }
                    .defaultAppStorage(zoom.defaults)
            }, appearances: [.light])
        }

        // MARK: - Tiếng Anh (bước 7c)

        // Giao diện tiếng Anh ở 960×640, chỉ ảnh sáng (review độc lập #52 S2): chữ tiếng Anh dài hơn, xem có bị cắt hay
        // xuống dòng xấu không. Nội dung đề vẫn tiếng Việt (không dịch).
        private static let english = Locale(identifier: "en")

        /// Luyện tập, bảng câu hỏi mở (mặc định): câu 3 đã chọn đáp án nhưng chưa kiểm tra, đã đánh dấu; thanh dưới đủ
        /// nút (Previous/Next Question, Unflag, Check Answer, tiến độ, Review & Submit).
        @Test func attemptPracticeEnglish() async throws {
            try await SnapshotHost.inLanguage(Self.english) {
                let harness = SessionHarness()
                let attempt = try await harness.start(SnapshotContent.attemptPackage(), mode: .practice)
                for answered in [0, 1] {
                    _ = attempt.goTo(index: answered)
                    attempt.answerCorrectly()
                }
                _ = attempt.goTo(index: 2)
                attempt.answerWrongly()
                attempt.perform(.toggleFlag)
                harness.clock.advance(95)
                attempt.tick()
                let window = harness.window(for: attempt)
                await SnapshotHost.assertLightAndDark({
                    windowContent(window) { AttemptScreen(window: window, attempt: attempt) }
                }, appearances: [.light])
            }
        }

        /// Kết quả (đề nhiều phần, có so với lần trước) ở tiếng Anh.
        @Test func resultsEnglish() async throws {
            try await SnapshotHost.inLanguage(Self.english) {
                let harness = SessionHarness()
                let package = ExamPackage(exam: SnapshotContent.manySectionsExam())
                let window = try await harness.submittedWindow(package: package, previousPercent: 45)
                let results = try #require(window.results)
                await SnapshotHost.assertLightAndDark({
                    windowContent(window) {
                        ResultsScreen(window: window, results: results, onRetake: {}, onReturnToLibrary: {})
                    }
                }, appearances: [.light])
            }
        }

        /// Xem lại bài (bộ lọc Tất cả, câu 2 trả lời sai, đã đánh dấu) ở tiếng Anh.
        @Test func answerReviewEnglish() async throws {
            try await SnapshotHost.inLanguage(Self.english) {
                let harness = SessionHarness()
                let package = ExamPackage(exam: SnapshotContent.manySectionsExam())
                let window = try await harness.submittedWindow(package: package)
                _ = await window.openAnswerReview(filter: .all)
                let review = try #require(window.answerReview)
                review.select(index: 1)
                await SnapshotHost.assertLightAndDark({
                    windowContent(window) { AnswerReviewScreen(window: window, review: review, onPracticeIncorrect: {}) }
                }, appearances: [.light])
            }
        }
    }
}
