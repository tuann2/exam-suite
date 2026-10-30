import ExamKit
import InterfaceCore
import LibraryFeature
import SessionModel
import SwiftUI

/// Màn **Kết quả** (docs/product/exam-taking.md, mục Kết quả và Lịch sử thi): Đậu/Trượt (biểu tượng + chữ),
/// điểm, thanh có vạch ngưỡng đậu, so với lần trước, thông tin, theo phần (đánh dấu phần yếu nhất), lỗi lưu;
/// **Xem lại bài** (chính, Return), **Xem câu sai**, **Làm lại**, **Về thư viện**, **Xuất PDF…** và **In…**
/// (docs/product/export-print.md phương án 6).
struct ResultsScreen: View {
    let window: SessionWindowModel
    let results: ResultsModel
    let onRetake: () -> Void
    let onReturnToLibrary: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    verdict
                    if let saveError = results.saveError {
                        SessionBannerView(
                            systemImage: "exclamationmark.triangle.fill",
                            tone: LibraryPalette.critical,
                            message: saveError
                        )
                        .accessibilityIdentifier("results.saveError")
                    }
                    if let reason = results.detailUnavailableReason {
                        SessionBannerView(systemImage: "doc.questionmark", tone: LibraryPalette.warning, message: reason)
                            .accessibilityIdentifier("results.detailUnavailable")
                    }
                    info
                    if !results.sectionRows.isEmpty {
                        sections
                    }
                }
                .frame(maxWidth: SessionStyle.readableWidth, alignment: .leading)
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            actions
        }
        .onAppear {
            if results.origin == .history {
                SessionAnnouncer.post(localized("Kết quả: \(results.verdictText), \(results.scoreText)"))
            }
        }
    }

    // MARK: - Điểm

    private var verdict: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text(results.verdictText)
            } icon: {
                Image(systemName: results.verdictSymbol)
                    .foregroundStyle(results.passed ? SessionStyle.positive : SessionStyle.critical)
            }
            .font(.system(size: 40, weight: .bold))
            .accessibilityIdentifier("results.verdict")
            Text(results.scoreText)
                .font(.title.weight(.semibold).monospacedDigit())
                .accessibilityIdentifier("results.score")
            ScoreBar(
                fraction: results.scoreFraction,
                threshold: results.passThresholdFraction,
                passed: results.passed
            )
            .frame(maxWidth: 560)
            if let passPercent = results.passPercent {
                Text("Ngưỡng đậu \(SessionFormat.percent(passPercent))", bundle: .module)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            if let comparison = results.comparison {
                Label(comparison.text, systemImage: comparisonSymbol(comparison.delta))
                    .font(.callout.weight(.semibold))
                    .accessibilityIdentifier("results.comparison")
            }
        }
        // Một phần tử: câu đọc của model (Đậu/Trượt, điểm, ngưỡng đậu, so với lần trước), là đề mục của màn để đi bằng rotor
        // Headings.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(results.verdictAccessibilityLabel))
        .accessibilityAddTraits(.isHeader)
    }

    private func comparisonSymbol(_ delta: Int) -> String {
        if delta > 0 { return "arrow.up.right" }
        if delta < 0 { return "arrow.down.right" }
        return "equal"
    }

    private var info: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 6) {
            ForEach(results.infoRows()) { row in
                // Mỗi dòng đọc một lần "Nhãn, giá trị" (`ResultInfoRow.accessibilityLabel`): `GridRow` không gộp được phần tử
                // trợ năng, và chữ chọn được (`textSelection`) không có vai trò (kiểm trợ năng: "Unknown role"), nên câu đọc đặt
                // ở ô nhãn, ô giá trị ẩn khỏi VoiceOver (vẫn chọn, chép được bằng chuột).
                GridRow {
                    Text(row.label)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(Text(row.accessibilityLabel))
                    Text(row.value)
                        .textSelection(.enabled)
                        .accessibilityHidden(true)
                }
            }
        }
        .accessibilityIdentifier("results.info")
    }

    private var sections: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Theo phần", bundle: .module)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            ForEach(results.sectionRows) { row in
                SectionResultRow(row: row)
            }
        }
        .accessibilityIdentifier("results.sections")
    }

    // MARK: - Nút

    private var actions: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let reason = results.reviewUnavailableReason ?? results.reviewFailure {
                ReviewUnavailableReason(reason: reason)
            }
            HStack(spacing: 10) {
                Button {
                    onReturnToLibrary()
                } label: {
                    Label(localized("Về thư viện"), systemImage: "books.vertical")
                }
                .accessibilityIdentifier("results.library")
                if results.retakePreset != nil {
                    Button {
                        onRetake()
                    } label: {
                        Label(localized("Làm lại"), systemImage: "arrow.counterclockwise")
                    }
                    .accessibilityIdentifier("results.retake")
                }
                Button {
                    window.requestReport(.exportPDF)
                } label: {
                    Label(localized("Xuất PDF…"), systemImage: "arrow.down.doc")
                }
                .disabled(!window.canRequestReport)
                .accessibilityIdentifier("results.exportPDF")
                Button {
                    window.requestReport(.print)
                } label: {
                    Label(localized("In…"), systemImage: "printer")
                }
                .disabled(!window.canRequestReport)
                .accessibilityIdentifier("results.print")
                Spacer()
                if window.isLoadingReview {
                    ProgressView().controlSize(.small)
                }
                if results.incorrectCount > 0 {
                    Button {
                        Task { await window.openAnswerReview(filter: .incorrect) }
                    } label: {
                        Label(localized("Xem câu sai"), systemImage: "xmark.circle")
                    }
                    .disabled(!results.canReview || window.isLoadingReview)
                    .accessibilityIdentifier("results.reviewIncorrect")
                }
                Button {
                    Task { await window.openAnswerReview(filter: .all) }
                } label: {
                    Label(localized("Xem lại bài"), systemImage: "doc.text.magnifyingglass")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .tint(SessionStyle.accentFill)
                .disabled(!results.canReview || window.isLoadingReview)
                .accessibilityIdentifier("results.review")
            }
            .labelStyle(.titleAndIcon)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

/// Vì sao không xem lại được, ở thanh nút của Kết quả (ngoài vùng cuộn).
struct ReviewUnavailableReason: View {
    let reason: String
    /// Độ rộng tối thiểu của chữ: ngoài vùng cuộn, chặn cỡ nhỏ nhất cao vô lý khi cửa sổ xếp lát được khôi phục
    /// (`SessionStyle.wrappingTextMinWidth`). Chỉ test đổi (`TiledWindowLayoutTests`: `nil` làm đối chứng âm).
    var textMinWidth: CGFloat? = SessionStyle.wrappingTextMinWidth

    var body: some View {
        Label(reason, systemImage: "info.circle")
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(minWidth: textMinWidth, alignment: .leading)
            .accessibilityIdentifier("results.reviewUnavailable")
    }
}

/// Thanh điểm có vạch ngưỡng đậu.
private struct ScoreBar: View {
    let fraction: Double
    let threshold: Double?
    let passed: Bool

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                AdaptiveFill(.neutral(opacity: 1), in: Capsule())
                Capsule()
                    .fill(passed ? SessionStyle.positive : SessionStyle.critical)
                    .frame(width: max(0, min(1, fraction)) * width)
                if let threshold {
                    Rectangle()
                        .fill(.primary)
                        .frame(width: 2, height: proxy.size.height + 8)
                        .offset(x: max(0, min(1, threshold)) * width - 1)
                }
            }
        }
        .frame(height: 14)
        .padding(.vertical, 4)
        .accessibilityHidden(true)
    }
}

/// Một dòng **Theo phần**: tên, thanh, đúng/tổng, %; phần 0/0 "Không có câu"; phần yếu nhất có biểu tượng + chữ.
private struct SectionResultRow: View {
    let row: ResultSectionRow

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.title)
                    .lineLimit(2)
                if row.isWeakest {
                    Label(localized("Phần yếu nhất"), systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(SessionStyle.warning)
                }
            }
            .frame(width: 240, alignment: .leading)
            if let fraction = row.fraction {
                ProgressView(value: fraction)
                    .tint(SessionStyle.accentForeground)
                    .frame(maxWidth: 260)
                    .accessibilityHidden(true)
            }
            Text(row.detailText)
                .monospacedDigit()
                .foregroundStyle(row.hasQuestions ? .primary : .secondary)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(row.accessibilityLabel))
    }
}
