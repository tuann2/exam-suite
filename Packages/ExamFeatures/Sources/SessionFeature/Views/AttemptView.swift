import Accessibility
import ExamKit
import LibraryFeature
import SwiftUI

/// Cửa sổ làm bài khi chưa nộp (docs/product/exam-taking.md, mục Cửa sổ làm bài, Tạm dừng, Cảnh báo và hết
/// giờ, Rà soát & nộp): câu hỏi hoặc Rà soát, thanh dưới, bảng câu hỏi (`.inspector`), thanh công cụ có đồng
/// hồ, lớp phủ Tạm dừng, dải cảnh báo, hộp xác nhận nộp.
///
/// Bàn phím: cả màn là một vùng nhận tiêu điểm (`onKeyPress`) cho A–Z, ←/→, Return, Esc; cửa sổ làm bài không
/// có ô nhập chữ nên phím chữ không đụng việc gõ. Lệnh có phím ⌘ nằm ở menu **Bài thi** (`SessionCommands`).
/// Đồng hồ: `tick()` mỗi 0,5 giây khi màn này hiện; thời gian luôn lấy từ phiên.
struct AttemptScreen: View {
    let window: SessionWindowModel
    @Bindable var attempt: AttemptModel

    @FocusState private var hasKeyboardFocus: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            if let banner = attempt.banner {
                SessionBannerView(
                    systemImage: banner.systemImage,
                    tone: banner.autoDismisses ? LibraryPalette.warning : LibraryPalette.critical,
                    message: banner.message,
                    onClose: banner.autoDismisses ? { attempt.dismissBanner(id: banner.id) } : nil
                )
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                .task(id: banner.id) {
                    guard banner.autoDismisses else { return }
                    try? await Task.sleep(for: .seconds(6))
                    attempt.dismissBanner(id: banner.id)
                }
                .accessibilityIdentifier("attempt.banner")
            }
            if attempt.isContentVisible {
                if let review = attempt.reviewSummary {
                    ReviewSubmitView(window: window, attempt: attempt, summary: review)
                } else {
                    // Nền đọc (menu Xem › Nền đọc): chỉ vùng câu hỏi; thanh dưới, bảng câu hỏi, Rà soát giữ giao diện macOS.
                    QuestionPane(attempt: attempt, hasKeyboardFocus: hasKeyboardFocus)
                        .readingSurface(systemTint: SessionStyle.accentForeground)
                    Divider()
                    AttemptBottomBar(attempt: attempt)
                }
            } else {
                PauseOverlay(attempt: attempt)
            }
        }
        .animation(reduceMotion ? nil : .snappy, value: attempt.banner)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .focusable()
        .focused($hasKeyboardFocus)
        .focusEffectDisabled()
        .defaultFocus($hasKeyboardFocus, true)
        .onKeyPress(phases: .down) { press in
            handle(press)
        }
        .onAppear { hasKeyboardFocus = true }
        .onChange(of: attempt.phase) { hasKeyboardFocus = true }
        .inspector(isPresented: $attempt.isNavigatorVisible) {
            NavigatorView(attempt: attempt)
                .inspectorColumnWidth(min: 220, ideal: 260, max: 380)
        }
        .toolbar { AttemptToolbar(attempt: attempt) }
        // Phóng to / Thu nhỏ / Cỡ thật (menu Xem): chỉ chữ của vùng câu hỏi (`QuestionPane`, `contentFont`) đổi cỡ.
        .contentZoomScope()
        // Xem › Nền đọc: đổi được khi đang làm bài (nền chỉ phủ vùng câu hỏi, `readingSurface`).
        .readingBackgroundScope()
        .confirmationDialog(
            Text(attempt.reviewSummary?.submitConfirmationMessage ?? ""),
            isPresented: Binding(
                get: { attempt.isConfirmingSubmit },
                set: { if !$0 { attempt.cancelSubmit() } }
            ),
            titleVisibility: .visible
        ) {
            // Quay lại là mặc định (Return và Esc); phải chủ động bấm Nộp bài (exam-taking.md, phương án 14).
            Button(localized("Quay lại"), role: .cancel) { attempt.cancelSubmit() }
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("submit.cancel")
            Button(localized("Nộp bài")) { window.confirmSubmit() }
                .accessibilityIdentifier("submit.confirm")
        }
        .task(id: ObjectIdentifier(attempt)) {
            // Đồng hồ: vẽ lại và nhận cảnh báo/hết giờ; dừng khi cửa sổ đóng hoặc đã nộp.
            while !Task.isCancelled, !attempt.isSubmitted {
                attempt.tick()
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    /// A–Z chọn lựa chọn theo vị trí, ←/→ câu trước/sau, Return câu tiếp theo, Esc quay lại làm bài (Rà soát
    /// chưa khoá). Phím có ⌘/⌃/⌥ để cho menu.
    private func handle(_ press: KeyPress) -> KeyPress.Result {
        guard press.modifiers.isDisjoint(with: [.command, .control, .option]) else { return .ignored }
        // Đang có sheet/hộp thoại: phím không tác dụng lên bài phía sau.
        guard !window.hasModal else { return .ignored }
        switch press.key {
        case .leftArrow:
            return perform(.previousQuestion)
        case .rightArrow:
            return perform(.nextQuestion)
        case .return:
            return perform(.advance)
        case .escape:
            return perform(.returnToAttempt)
        default:
            guard attempt.phase == .inProgress else { return .ignored }
            return attempt.handleLetterKey(press.characters) ? .handled : .ignored
        }
    }

    private func perform(_ command: AttemptCommand) -> KeyPress.Result {
        guard attempt.isEnabled(command) else { return .ignored }
        attempt.perform(command)
        return .handled
    }
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

    static func post(_ text: String) {
        AccessibilityNotification.Announcement(text).post()
    }
}

// MARK: - Câu hỏi

/// Câu hiện tại: tên phần, "Câu 3/60", đánh dấu; nội dung (Markdown), ảnh, gợi ý "Chọn N đáp án", các lựa
/// chọn; sau Kiểm tra đáp án: dòng kết quả và giải thích.
private struct QuestionPane: View {
    let attempt: AttemptModel
    let hasKeyboardFocus: Bool

    @Environment(\.readingStyle) private var reading

    var body: some View {
        let question = attempt.currentQuestion
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                        .id("top")
                    MarkdownText(question.text)
                        .contentFont(.title3)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                        .accessibilityIdentifier("question.text")
                    if let image = attempt.currentImage {
                        QuestionImageView(data: image)
                    }
                    if let hint = attempt.selectionHint {
                        Label(hint, systemImage: "checklist")
                            .contentFont(.callout, weight: .semibold)
                            .foregroundStyle(reading.accent)
                            .accessibilityIdentifier("question.hint")
                    }
                    OptionList(attempt: attempt, isMultiple: question.type == .multiple)
                    if let check = attempt.currentCheck {
                        CheckResultView(check: check)
                    }
                }
                // Cỡ chữ của vùng nội dung câu (Phóng to/Thu nhỏ, phương án 5): chữ không đặt phông riêng là body theo hệ số.
                .contentBodyFont()
                .frame(maxWidth: SessionStyle.readableWidth, alignment: .leading)
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: attempt.currentIndex) {
                proxy.scrollTo("top", anchor: .top)
            }
        }
        .overlay {
            // Tiêu điểm bàn phím luôn nhìn thấy: viền teal quanh vùng câu hỏi khi nó nhận phím.
            if hasKeyboardFocus {
                RoundedRectangle(cornerRadius: SessionStyle.cornerRadius)
                    .strokeBorder(reading.accent.opacity(LibraryPalette.focusRingOpacity), lineWidth: 2)
                    .padding(4)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(attempt.currentSectionTitle)
                .contentFont(.headline)
                .foregroundStyle(reading.secondaryText)
            Text(attempt.questionPositionText)
                .contentFont(.headline)
                .monospacedDigit()
                .accessibilityIdentifier("question.position")
            if attempt.isCurrentFlagged {
                Label(localized("Đã đánh dấu"), systemImage: "flag.fill")
                    .contentFont(.callout, weight: .semibold)
                    .foregroundStyle(reading.warning)
                    .accessibilityIdentifier("question.flagged")
            }
            if attempt.isCurrentLocked {
                Label(localized("Đã kiểm tra"), systemImage: "lock.fill")
                    .contentFont(.callout)
                    .foregroundStyle(reading.secondaryText)
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("question.header")
    }
}

/// Hàng lựa chọn rộng hết khung: radio (`single`) hoặc ô đánh dấu (`multiple`), nhãn A, B, C… theo vị trí hiển
/// thị; bấm chỗ nào của hàng cũng được. Sau Kiểm tra đáp án: Đúng / Sai bằng biểu tượng + chữ.
private struct OptionList: View {
    let attempt: AttemptModel
    let isMultiple: Bool

    var body: some View {
        let options = attempt.displayedOptions
        let enabled = attempt.phase == .inProgress && !attempt.isCurrentLocked
        VStack(alignment: .leading, spacing: 8) {
            ForEach(options) { option in
                Button {
                    attempt.selectOption(option.optionID)
                } label: {
                    OptionRow(option: option, isMultiple: isMultiple)
                }
                .buttonStyle(.plain)
                .disabled(!enabled)
                // Nhãn Đúng/Sai vẽ ngoài nút: nút bị khoá sau Kiểm tra đáp án làm mờ cả nội dung (nhãn chỉ còn ~2,2:1, review độc
                // lập #54 S1); trong nút chỉ giữ chỗ (ẩn) để bố cục như cũ. VoiceOver đọc Đúng/Sai trong giá trị của lựa chọn.
                .overlay(alignment: .topTrailing) {
                    if let mark = option.checkMark {
                        OptionCheckMarkLabel(mark: mark)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .accessibilityHidden(true)
                    }
                }
                .accessibilityLabel(Text("\(option.label). \(MarkdownText.plain(option.text))", bundle: .module))
                .accessibilityValue(Text(accessibilityValue(option)))
                .accessibilityAddTraits(option.isSelected ? .isSelected : [])
                .accessibilityHint(enabled ? localized("Phím \(option.label)") : "")
                .accessibilityIdentifier("option.\(option.label)")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(isMultiple
            ? localized("Các lựa chọn, chọn nhiều đáp án")
            : localized("Các lựa chọn, chọn một đáp án"))
    }

    private func accessibilityValue(_ option: DisplayedOption) -> String {
        var parts = [option.isSelected ? localized("Đã chọn") : localized("Chưa chọn")]
        if let mark = option.checkMark { parts.append(mark.title) }
        return parts.joined(separator: ", ")
    }
}

struct OptionRow: View {
    let option: DisplayedOption
    let isMultiple: Bool

    @Environment(\.questionContentScale) private var scale
    @Environment(\.readingStyle) private var reading

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: indicator)
                .contentFont(.title3)
                .foregroundStyle(option.isSelected ? AnyShapeStyle(reading.accent) : reading.secondaryText)
            Text(option.label)
                .contentFont(.body, weight: .semibold, design: .monospaced)
                .frame(minWidth: 18 * scale, alignment: .leading)
            MarkdownText(option.text)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let mark = option.checkMark {
                // Chỉ giữ chỗ: nhãn thật vẽ ngoài nút (`OptionList`, không bị làm mờ khi nút khoá).
                OptionCheckMarkLabel(mark: mark)
                    .hidden()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            // Hàng đã chọn: nền nhạt teal (chữ đặt lên có test tương phản; Reduce Transparency: nền đặc; nền đọc: màu đặc của
            // bộ màu). Chưa chọn: nền của cửa sổ (đặc) hoặc của nền đọc.
            if option.isSelected {
                Color.clear.readingFill(
                    reading.selectedOptionBackground, in: RoundedRectangle(cornerRadius: SessionStyle.cornerRadius)
                )
            } else {
                RoundedRectangle(cornerRadius: SessionStyle.cornerRadius).fill(reading.optionBackground)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: SessionStyle.cornerRadius)
                .strokeBorder(option.isSelected ? AnyShapeStyle(reading.accent) : reading.border,
                              lineWidth: option.isSelected ? 2 : 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: SessionStyle.cornerRadius))
    }

    private var indicator: String {
        switch (isMultiple, option.isSelected) {
        case (false, false): "circle"
        case (false, true): "largecircle.fill.circle"
        case (true, false): "square"
        case (true, true): "checkmark.square.fill"
        }
    }
}

/// Nhãn Đúng/Sai của một lựa chọn sau Kiểm tra đáp án (biểu tượng + chữ, màu của bảng: tương phản có test).
struct OptionCheckMarkLabel: View {
    let mark: OptionCheckMark

    @Environment(\.readingStyle) private var reading

    var body: some View {
        Label(mark.title, systemImage: mark.systemImage)
            .contentFont(.callout, weight: .semibold)
            .foregroundStyle(mark == .correct ? reading.positive : reading.critical)
    }
}

/// Kết quả Kiểm tra đáp án: "Đúng" / "Chưa đúng" (biểu tượng + chữ) và khung giải thích.
private struct CheckResultView: View {
    let check: AnswerCheckPresentation

    @Environment(\.readingStyle) private var reading

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(check.resultText, systemImage: check.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .contentFont(.title3, weight: .semibold)
                .foregroundStyle(check.isCorrect ? reading.positive : reading.critical)
                .accessibilityIdentifier("check.result")
            if let explanation = check.explanation, !explanation.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Giải thích", bundle: .module)
                        .contentFont(.headline)
                    MarkdownText(explanation)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .readingFill(reading.explanationBackground, in: RoundedRectangle(cornerRadius: SessionStyle.cornerRadius))
                .accessibilityElement(children: .combine)
                // Vai trò chữ tĩnh: phần tử gộp không có vai trò thì kiểm trợ năng báo "Unknown role" (bước 8b).
                .accessibilityAddTraits(.isStaticText)
                .accessibilityIdentifier("check.explanation")
            }
        }
    }
}

// MARK: - Thanh dưới, thanh công cụ

/// **Câu trước**, **Câu sau**, **Đánh dấu**, **Kiểm tra đáp án** (Luyện tập), tiến độ, **Rà soát & nộp**.
///
/// Không đủ chỗ cho mọi nhãn (cửa sổ 960×640 có bảng câu hỏi, giao diện tiếng Anh: "Previous Question", "Check Answer"…;
/// review độc lập #52 S2) thì **Câu trước**/**Câu sau** chỉ còn biểu tượng (nhãn vẫn đọc bằng VoiceOver, có trợ giúp),
/// rồi tới **Đánh dấu**, **Kiểm tra đáp án**; không cắt chữ. Tiếng Việt ở 960×640 khi bảng câu hỏi đang mở: Thi đủ nhãn,
/// còn Luyện tập (thêm nút Kiểm tra đáp án) đã ở mức 1, **Câu trước**/**Câu sau** chỉ biểu tượng (ảnh snapshot
/// `attemptPracticeCheckedAnswer`). Cửa sổ rộng hơn hoặc ẩn bảng câu hỏi thì đủ nhãn.
private struct AttemptBottomBar: View {
    let attempt: AttemptModel

    var body: some View {
        // Mức thu gọn: 0 đủ nhãn; 1 Câu trước/sau chỉ biểu tượng; 2 thêm Đánh dấu, Kiểm tra đáp án chỉ biểu tượng.
        ViewThatFits(in: .horizontal) {
            bar(compactLevel: 0)
            bar(compactLevel: 1)
            bar(compactLevel: 2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func bar(compactLevel: Int) -> some View {
        HStack(spacing: 10) {
            Button {
                attempt.perform(.previousQuestion)
            } label: {
                label(localized("Câu trước"), systemImage: "chevron.left", iconOnly: compactLevel >= 1)
            }
            .disabled(!attempt.isEnabled(.previousQuestion))
            .help(Text("Câu trước (←)", bundle: .module))
            .accessibilityIdentifier("attempt.previous")
            Button {
                attempt.perform(.nextQuestion)
            } label: {
                label(localized("Câu sau"), systemImage: "chevron.right", iconOnly: compactLevel >= 1)
            }
            .disabled(!attempt.isEnabled(.nextQuestion))
            .help(Text("Câu sau (→)", bundle: .module))
            .accessibilityIdentifier("attempt.next")
            Button {
                attempt.perform(.toggleFlag)
            } label: {
                label(
                    attempt.isCurrentFlagged ? localized("Bỏ đánh dấu") : localized("Đánh dấu"),
                    systemImage: attempt.isCurrentFlagged ? "flag.slash" : "flag",
                    iconOnly: compactLevel >= 2
                )
            }
            .disabled(!attempt.isEnabled(.toggleFlag))
            .help(Text("Đánh dấu (⌘D)", bundle: .module))
            .accessibilityIdentifier("attempt.flag")
            if attempt.mode == .practice {
                Button {
                    attempt.perform(.checkAnswer)
                } label: {
                    label(localized("Kiểm tra đáp án"), systemImage: "checkmark.bubble", iconOnly: compactLevel >= 2)
                }
                .disabled(!attempt.isEnabled(.checkAnswer))
                .help(Text("Kiểm tra đáp án (⌘K)", bundle: .module))
                .accessibilityIdentifier("attempt.check")
            }
            Spacer(minLength: 12)
            Text(attempt.progressText)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize()
                .accessibilityIdentifier("attempt.progress")
            Button {
                attempt.perform(.openReview)
            } label: {
                Label(localized("Rà soát & nộp"), systemImage: "checklist.checked")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.borderedProminent)
            // Nền màu nhấn có chữ trắng: #017777 (5,38:1).
            .tint(SessionStyle.accentFill)
            .disabled(!attempt.isEnabled(.openReview))
            .help(Text("Rà soát & nộp (⌘Return)", bundle: .module))
            .accessibilityIdentifier("attempt.review")
        }
    }

    /// Nhãn đủ chữ, hoặc chỉ biểu tượng khi thiếu chỗ (chữ vẫn là nhãn VoiceOver).
    @ViewBuilder
    private func label(_ title: String, systemImage: String, iconOnly: Bool) -> some View {
        if iconOnly {
            Label(title, systemImage: systemImage).labelStyle(.iconOnly)
        } else {
            Label(title, systemImage: systemImage).labelStyle(.titleAndIcon)
        }
    }
}

/// Thanh công cụ: đồng hồ (ba mức, biểu tượng + màu), **Tạm dừng** / **Tiếp tục**, ẩn/hiện bảng câu hỏi.
private struct AttemptToolbar: ToolbarContent {
    let attempt: AttemptModel

    var body: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            ClockView(attempt: attempt)
        }
        ToolbarItem(placement: .primaryAction) {
            Button {
                attempt.perform(.togglePause)
            } label: {
                Label(attempt.pauseCommandTitle, systemImage: attempt.phase == .paused ? "play.fill" : "pause.fill")
            }
            .disabled(!attempt.isEnabled(.togglePause))
            .help(Text("\(attempt.pauseCommandTitle) (⌘.)", bundle: .module))
            .accessibilityIdentifier("attempt.pause")
        }
        ToolbarItem(placement: .primaryAction) {
            Button {
                attempt.perform(.toggleNavigator)
            } label: {
                Label(
                attempt.isNavigatorVisible ? localized("Ẩn bảng câu hỏi") : localized("Hiện bảng câu hỏi"),
                systemImage: "sidebar.right"
            )
            }
            .help(attempt.isNavigatorVisible
                ? localized("Ẩn bảng câu hỏi (⌃⌘I)") : localized("Hiện bảng câu hỏi (⌃⌘I)"))
            .accessibilityIdentifier("attempt.toggleNavigator")
        }
    }
}

/// Đồng hồ: Thi đếm ngược (`mm:ss`, `h:mm:ss`), Luyện tập thời gian đã làm. Tự đọc `clockDisplay` của bài
/// (không nhận giá trị từ thanh công cụ), vì mục thanh công cụ không luôn được vẽ lại theo nội dung cha.
struct ClockView: View {
    let attempt: AttemptModel

    var body: some View {
        let display = attempt.clockDisplay
        // HStack, không dùng `Label`: thanh công cụ macOS có thể đổi `Label` thành mục tiêu đề + biểu tượng
        // tĩnh, không vẽ lại theo đồng hồ.
        HStack(spacing: 6) {
            Image(systemName: display.level.systemImage)
            Text(display.text)
                .font(.title3.weight(display.level == .normal ? .regular : .semibold).monospacedDigit())
        }
        .fixedSize()
        .foregroundStyle(SessionStyle.color(for: display.level))
        .padding(.horizontal, 8)
        .accessibilityElement(children: .ignore)
        // Vai trò chữ tĩnh: phần tử gộp không có vai trò thì kiểm trợ năng báo "Unknown role" (bước 8b).
        .accessibilityAddTraits(.isStaticText)
        .accessibilityLabel(Text(display.accessibilityLabel))
        .accessibilityIdentifier("attempt.clock")
        .help(display.isCountdown ? localized("Thời gian còn lại") : localized("Thời gian đã làm"))
    }
}

// MARK: - Tạm dừng

/// Lớp phủ Tạm dừng: che toàn bộ câu hỏi và lựa chọn (không vẽ chúng), nút **Tiếp tục** (Return hoặc ⌘.).
private struct PauseOverlay: View {
    let attempt: AttemptModel

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "pause.circle")
                .font(.system(size: 56))
                .foregroundStyle(SessionStyle.accentForeground)
                .accessibilityHidden(true)
            Text(attempt.pauseMessage ?? "")
                .font(.title2.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("pause.message")
            Text("Câu hỏi được che trong lúc tạm dừng. Đồng hồ đã dừng.", bundle: .module)
                .foregroundStyle(.secondary)
            Button(localized("Tiếp tục")) { attempt.perform(.togglePause) }
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
                .tint(SessionStyle.accentFill)
                .help(Text("Tiếp tục (Return hoặc ⌘.)", bundle: .module))
                .accessibilityIdentifier("pause.resume")
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityElement(children: .contain)
    }
}
