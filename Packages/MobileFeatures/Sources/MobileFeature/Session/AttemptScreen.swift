import ExamKit
import InterfaceCore
import SessionModel
import SwiftUI
import UIKit

/// Màn làm bài (docs/product/exam-taking.md; khác macOS ở mục Bản iOS của mobile.md): câu hỏi, ảnh (chạm để phóng to),
/// lựa chọn A–Z theo vị trí, đồng hồ ba mức, cảnh báo 5/1 phút, che câu khi tạm dừng, Kiểm tra đáp án (Luyện tập),
/// bảng câu hỏi kéo lên từ dưới, **Rà soát & nộp**. Không có phím tắt: mọi lệnh là nút. Mọi luật ở `AttemptModel`
/// (dùng chung với bản macOS).
struct AttemptScreen: View {
    let session: MobileSession
    @Bindable var attempt: AttemptModel

    @State private var isNavigatorPresented = false
    @State private var zoomedImage: ZoomedImage?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                ClockLabel(display: attempt.clockDisplay)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            if let banner = attempt.banner {
                SessionBannerView(banner: banner) { attempt.dismissBanner(id: banner.id) }
                    .task(id: banner.id) {
                        guard banner.autoDismisses else { return }
                        try? await Task.sleep(for: .seconds(8))
                        attempt.dismissBanner(id: banner.id)
                    }
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            }
            if let summary = attempt.reviewSummary {
                ReviewSubmitView(session: session, attempt: attempt, summary: summary)
            } else if attempt.isContentVisible {
                QuestionView(attempt: attempt, zoomedImage: $zoomedImage)
                AttemptBottomBar(attempt: attempt) { isNavigatorPresented = true }
            } else {
                PausedView(attempt: attempt)
            }
        }
        .animation(reduceMotion ? nil : .snappy, value: attempt.banner)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if attempt.isEnabled(.togglePause) {
                    Button {
                        attempt.perform(.togglePause)
                    } label: {
                        Label(attempt.pauseCommandTitle, systemImage: attempt.phase == .paused ? "play.fill" : "pause.fill")
                    }
                    .accessibilityIdentifier("attempt.pause")
                }
            }
        }
        .sheet(isPresented: $isNavigatorPresented) {
            NavigatorSheet(attempt: attempt) { index in
                attempt.goTo(index: index)
                isNavigatorPresented = false
            }
            .presentationDetents([.medium, .large])
        }
        .fullScreenCover(item: $zoomedImage) { image in
            ImageZoomView(image: image.image)
        }
        .confirmationDialog(
            Text(attempt.reviewSummary?.submitConfirmationMessage ?? ""),
            isPresented: Binding(
                get: { attempt.isConfirmingSubmit },
                set: { if !$0 { attempt.cancelSubmit() } }
            ),
            titleVisibility: .visible
        ) {
            // Quay lại là mặc định; phải chủ động bấm Nộp bài (exam-taking.md, phương án 14).
            Button(localized("Nộp bài")) { session.confirmSubmit() }
                .accessibilityIdentifier("submit.confirm")
            Button(localized("Quay lại"), role: .cancel) { attempt.cancelSubmit() }
        }
        .onChange(of: attempt.announcements, initial: true) {
            SessionAnnouncer.post(attempt.takeAnnouncements())
        }
        .task(id: ObjectIdentifier(attempt)) {
            // Đồng hồ: vẽ lại và nhận cảnh báo/hết giờ; dừng khi rời màn hoặc đã nộp.
            while !Task.isCancelled, !attempt.isSubmitted {
                attempt.tick()
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }
}

/// Ảnh đang phóng to.
struct ZoomedImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

/// Đọc các câu VoiceOver chờ đọc; cảnh báo giờ và hết giờ ưu tiên cao (đọc ngay).
@MainActor
enum SessionAnnouncer {
    static func post(_ announcements: [SessionAnnouncement]) {
        for announcement in announcements {
            var text = AttributedString(announcement.text)
            text.accessibilitySpeechAnnouncementPriority = announcement.priority == .high ? .high : .default
            AccessibilityNotification.Announcement(text).post()
        }
    }
}

// MARK: - Câu hỏi

/// Câu đang làm: phần, số câu, nội dung (Markdown), ảnh, lựa chọn, kết quả Kiểm tra đáp án.
struct QuestionView: View {
    let attempt: AttemptModel
    @Binding var zoomedImage: ZoomedImage?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(attempt.currentSectionTitle)
                            .font(.subheadline)
                            .foregroundStyle(MobilePalette.secondaryText)
                        HStack {
                            Text(attempt.questionPositionText)
                                .font(.headline)
                                .accessibilityAddTraits(.isHeader)
                            if attempt.isCurrentFlagged {
                                Label(localized("Đã đánh dấu"), systemImage: "flag.fill")
                                    .labelStyle(.iconOnly)
                                    .foregroundStyle(MobilePalette.warning)
                            }
                            if attempt.isCurrentLocked {
                                Label(localized("Đã kiểm tra"), systemImage: "lock.fill")
                                    .labelStyle(.iconOnly)
                                    .foregroundStyle(MobilePalette.secondaryText)
                            }
                        }
                    }
                    .id("top")
                    Text(PlainMarkdown.attributed(attempt.currentQuestion.text))
                        .font(.body)
                        .textSelection(.enabled)
                    if let data = attempt.currentImage, let image = UIImage(data: data) {
                        Button {
                            zoomedImage = ZoomedImage(image: image)
                        } label: {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 280)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(localized("Ảnh của câu hỏi"))
                        .accessibilityHint(localized("Chạm để phóng to"))
                    }
                    if let hint = attempt.selectionHint {
                        Text(hint)
                            .font(.subheadline)
                            .foregroundStyle(MobilePalette.secondaryText)
                    }
                    OptionList(attempt: attempt)
                    if let check = attempt.currentCheck {
                        CheckResultView(check: check)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: attempt.currentIndex) {
                proxy.scrollTo("top", anchor: .top)
            }
        }
    }
}

/// Lựa chọn A–Z theo vị trí trên màn (không theo id trong file); chạm để chọn/bỏ chọn.
struct OptionList: View {
    let attempt: AttemptModel

    var body: some View {
        VStack(spacing: 8) {
            ForEach(attempt.displayedOptions) { option in
                Button {
                    _ = attempt.selectOption(atPosition: option.position)
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(option.label)
                            .font(.body.weight(.semibold))
                            .frame(minWidth: 28, minHeight: 28)
                            .background(
                                Circle().fill(option.isSelected ? MobilePalette.accent : Color.clear)
                            )
                            .overlay(Circle().stroke(option.isSelected ? Color.clear : Color.secondary))
                            .foregroundStyle(option.isSelected ? Color(uiColor: .systemBackground) : Color.primary)
                        Text(PlainMarkdown.attributed(option.text))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundStyle(.primary)
                        if let mark = option.checkMark {
                            Label(mark.title, systemImage: mark.systemImage)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(mark == .correct ? MobilePalette.positive : MobilePalette.critical)
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(option.isSelected ? MobilePalette.tint(MobilePalette.accent) : Color(uiColor: .secondarySystemBackground))
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(attempt.isCurrentLocked || attempt.phase != .inProgress)
                .accessibilityLabel(Text(verbatim: "\(option.label). \(PlainMarkdown.text(option.text))"))
                .accessibilityValue(accessibilityValue(option))
                .accessibilityAddTraits(option.isSelected ? .isSelected : [])
                .accessibilityIdentifier("option.\(option.label)")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(attempt.currentQuestion.type == .multiple
            ? localized("Các lựa chọn, chọn nhiều đáp án")
            : localized("Các lựa chọn, chọn một đáp án"))
    }

    private func accessibilityValue(_ option: DisplayedOption) -> String {
        var parts = [option.isSelected ? localized("Đã chọn") : localized("Chưa chọn")]
        if let mark = option.checkMark { parts.append(mark.title) }
        return parts.joined(separator: ", ")
    }
}

/// Kết quả của **Kiểm tra đáp án** (Luyện tập): Đúng/Chưa đúng và giải thích.
struct CheckResultView: View {
    let check: AnswerCheckPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(check.resultText, systemImage: check.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.headline)
                .foregroundStyle(check.isCorrect ? MobilePalette.positive : MobilePalette.critical)
            if let explanation = check.explanation {
                Text("Giải thích", bundle: .module)
                    .font(.subheadline.weight(.semibold))
                Text(PlainMarkdown.attributed(explanation))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(uiColor: .secondarySystemBackground)))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("attempt.check")
    }
}

/// Thanh dưới màn làm bài: câu trước/sau, đánh dấu, Kiểm tra đáp án (Luyện tập), bảng câu hỏi, Rà soát & nộp.
struct AttemptBottomBar: View {
    let attempt: AttemptModel
    let showNavigator: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(attempt.progressText)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button {
                    attempt.perform(.openReview)
                } label: {
                    Label(localized("Rà soát & nộp"), systemImage: "checklist.checked")
                        .fixedSize(horizontal: false, vertical: true)
                }
                .disabled(!attempt.isEnabled(.openReview))
                .accessibilityIdentifier("attempt.review")
            }
            HStack(spacing: 0) {
                barButton(localized("Câu trước"), systemImage: "chevron.left", command: .previousQuestion,
                          identifier: "attempt.previous")
                barButton(
                    attempt.isCurrentFlagged ? localized("Bỏ đánh dấu") : localized("Đánh dấu"),
                    systemImage: attempt.isCurrentFlagged ? "flag.slash" : "flag",
                    command: .toggleFlag,
                    identifier: "attempt.flag"
                )
                if attempt.mode == .practice {
                    barButton(localized("Kiểm tra đáp án"), systemImage: "checkmark.bubble", command: .checkAnswer,
                              identifier: "attempt.check.button")
                }
                Button(action: showNavigator) {
                    Label(localized("Bảng câu hỏi"), systemImage: "square.grid.3x3")
                        .labelStyle(.iconOnly)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .accessibilityIdentifier("attempt.navigator")
                barButton(localized("Câu sau"), systemImage: "chevron.right", command: .nextQuestion,
                          identifier: "attempt.next")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(MobilePalette.barBackground)
        .overlay(alignment: .top) { Divider() }
    }

    private func barButton(_ title: String, systemImage: String, command: AttemptCommand, identifier: String) -> some View {
        Button {
            attempt.perform(command)
        } label: {
            Label(title, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .disabled(!attempt.isEnabled(command))
        .accessibilityIdentifier(identifier)
    }
}

/// Đồng hồ ở thanh trên: đếm ngược (Thi có giới hạn) hay thời gian đã làm; ba mức thường/cảnh báo/khẩn bằng biểu tượng
/// và màu.
struct ClockLabel: View {
    let display: ClockDisplay

    var body: some View {
        Label {
            Text(display.text)
                .monospacedDigit()
        } icon: {
            Image(systemName: display.level.systemImage)
        }
        .font(.headline)
        .foregroundStyle(color)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(display.accessibilityLabel)
        .accessibilityIdentifier("attempt.clock")
    }

    private var color: Color {
        switch display.level {
        case .normal: .primary
        case .warning: MobilePalette.warning
        case .urgent: MobilePalette.critical
        }
    }
}

/// Dải cảnh báo giờ (5 phút, 1 phút: tự ẩn) và hết giờ (ở lại).
struct SessionBannerView: View {
    let banner: SessionBanner
    let onClose: () -> Void

    var body: some View {
        let tone = banner.autoDismisses ? MobilePalette.warning : MobilePalette.critical
        HStack(spacing: 10) {
            Image(systemName: banner.systemImage)
                .foregroundStyle(tone)
            Text(banner.message)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
            if banner.autoDismisses {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                    .accessibilityLabel(localized("Đóng thông báo"))
            }
        }
        .padding(12)
        .background(MobilePalette.tint(tone))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("attempt.banner")
    }
}

/// Lớp che khi tạm dừng: câu hỏi bị che, đồng hồ đã dừng; lý do (bạn bấm, máy ngủ, rời app) và nút Tiếp tục.
struct PausedView: View {
    let attempt: AttemptModel

    var body: some View {
        ScrollView {
            pausedContent
                .frame(maxWidth: .infinity)
                .padding()
                .padding(.top, 48)
        }
    }

    private var pausedContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "pause.circle")
                .font(.system(size: 56))
                .foregroundStyle(MobilePalette.secondaryText)
                .accessibilityHidden(true)
            Text(attempt.pauseMessage ?? "")
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("attempt.pauseMessage")
            Text("Câu hỏi được che trong lúc tạm dừng. Đồng hồ đã dừng.", bundle: .module)
                .foregroundStyle(MobilePalette.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button(localized("Tiếp tục")) { attempt.perform(.togglePause) }
                .buttonStyle(.borderedProminent)
                .tint(LibraryPalette.accentFill.color)
                .accessibilityIdentifier("attempt.resume")
        }
    }
}

// MARK: - Bảng câu hỏi

/// Bảng câu hỏi kéo lên từ dưới (sheet có detent): ô số câu theo phần, đã làm/đánh dấu/đang xem; tạm dừng thì chỉ hiện
/// số ô (như bản macOS). Chạm ô để tới câu đó.
struct NavigatorSheet: View {
    let attempt: AttemptModel
    let goTo: (Int) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(attempt.navigatorSections) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.title)
                                .font(.headline)
                                .accessibilityAddTraits(.isHeader)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 48), spacing: 8)], spacing: 8) {
                                ForEach(section.cells) { cell in
                                    NavigatorCellButton(cell: cell) { goTo(cell.index) }
                                        .disabled(attempt.phase == .paused)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(localized("Bảng câu hỏi"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct NavigatorCellButton: View {
    let cell: NavigatorCell
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(InterfaceLocale.number(cell.number))
                    .font(.body.weight(cell.isCurrent ? .bold : .regular))
                    .monospacedDigit()
                if !cell.isStateHidden {
                    Image(systemName: cell.systemImage)
                        .font(.caption2)
                        .foregroundStyle(cell.isFlagged ? MobilePalette.warning : MobilePalette.secondaryText)
                }
            }
            .frame(minWidth: 44, minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(cell.isAnswered && !cell.isStateHidden
                        ? MobilePalette.tint(MobilePalette.accent) : Color(uiColor: .secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(cell.isCurrent ? MobilePalette.accent : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(cell.accessibilityLabel)
    }
}

// MARK: - Rà soát & nộp

/// **Rà soát & nộp**: ba số Đã làm / Chưa làm / Đánh dấu, hai danh sách số câu (chạm để quay lại làm bài tại câu đó;
/// không có khi rà soát khoá vì hết giờ), **Quay lại làm bài** và **Nộp bài**.
struct ReviewSubmitView: View {
    let session: MobileSession
    let attempt: AttemptModel
    let summary: ReviewSummary

    var body: some View {
        VStack(spacing: 0) {
            List {
                Section {
                    countRow(localized("Đã làm"), summary.answeredCount)
                        .accessibilityIdentifier("review.answered")
                    countRow(localized("Chưa làm"), summary.unansweredCount)
                        .accessibilityIdentifier("review.unanswered")
                    countRow(localized("Đánh dấu"), summary.flaggedCount)
                        .accessibilityIdentifier("review.flagged")
                }
                questionList(
                    title: localized("Câu chưa làm"),
                    empty: localized("Không còn câu chưa làm."),
                    indices: summary.unansweredIndices
                )
                questionList(
                    title: localized("Câu đã đánh dấu"),
                    empty: localized("Không có câu đánh dấu."),
                    indices: summary.flaggedIndices
                )
            }
            .listStyle(.insetGrouped)
            VStack(spacing: 8) {
                if summary.canReturnToAttempt {
                    Button {
                        attempt.perform(.returnToAttempt)
                    } label: {
                        Label(localized("Quay lại làm bài"), systemImage: "arrow.uturn.backward")
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    // Chữ chính trên nền xám của nút viền (màu nhấn trên nền pha màu nhấn của iOS không đạt 4,5:1).
                    .tint(.primary)
                    .accessibilityIdentifier("review.back")
                } else {
                    Label(localized("Đã hết giờ: không sửa được đáp án."), systemImage: "lock.fill")
                        .foregroundStyle(MobilePalette.secondaryText)
                }
                Button {
                    session.requestSubmit()
                } label: {
                    Label(localized("Nộp bài"), systemImage: "paperplane.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                // Nền màu nhấn có chữ trắng: #017777 (5,38:1).
                .tint(LibraryPalette.accentFill.color)
                .accessibilityIdentifier("review.submit")
            }
            .padding()
            .background(MobilePalette.barBackground)
            .overlay(alignment: .top) { Divider() }
        }
        .navigationTitle(localized("Rà soát & nộp"))
    }

    private func countRow(_ title: String, _ value: Int) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(InterfaceLocale.number(value))
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }

    private func questionList(title: String, empty: String, indices: [Int]) -> some View {
        Section {
            SectionHeader(title)
            if indices.isEmpty {
                Text(empty)
                    .font(.body)
                    .foregroundStyle(MobilePalette.secondaryText)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 48), spacing: 8)], spacing: 8) {
                    ForEach(indices, id: \.self) { index in
                        Button(InterfaceLocale.number(index + 1)) {
                            attempt.returnToAttempt(at: index)
                        }
                        .buttonStyle(.bordered)
                        .disabled(!summary.canReturnToAttempt)
                        .accessibilityLabel(localized("Câu \(index + 1)"))
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

// MARK: - Ảnh phóng to

/// Ảnh của câu phóng to toàn màn: chụm hai ngón để phóng to thêm, chạm Xong để đóng.
struct ImageZoomView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical]) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geometry.size.width * scale, height: geometry.size.height * scale)
                }
                .gesture(MagnifyGesture().onChanged { value in scale = min(max(value.magnification, 1), 5) })
            }
            .accessibilityLabel(localized("Ảnh của câu hỏi"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(localized("Xong")) { dismiss() }
                }
            }
        }
    }
}
