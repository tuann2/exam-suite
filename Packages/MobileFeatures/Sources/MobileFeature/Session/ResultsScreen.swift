import InterfaceCore
import SessionModel
import SwiftUI

/// **Kết quả** (docs/product/exam-taking.md, mục Kết quả): Đậu/Trượt kèm điểm, ngưỡng đậu, so với lần trước, thông tin
/// lần thi, điểm theo phần (phần yếu nhất), **Xem lại bài**, **Xem câu sai**, **Làm lại**, **Về thư viện**. Xuất PDF ở
/// v1.1. Mọi luật ở `ResultsModel` (dùng chung với bản macOS).
struct ResultsScreen: View {
    let session: MobileSession
    let results: ResultsModel
    let sessions: MobileSessionCoordinator

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label {
                        Text(results.verdictText)
                            .font(.largeTitle.weight(.bold))
                    } icon: {
                        Image(systemName: results.verdictSymbol)
                            .foregroundStyle(results.passed ? MobilePalette.positive : MobilePalette.critical)
                    }
                    .accessibilityIdentifier("results.verdict")
                    Text(results.scoreText)
                        .font(.title2)
                        .accessibilityIdentifier("results.score")
                    ProgressView(value: results.scoreFraction)
                        .tint(results.passed ? MobilePalette.positive : MobilePalette.critical)
                        .accessibilityHidden(true)
                    if let passPercent = results.passPercent {
                        Text("Ngưỡng đậu \(SessionFormat.percent(passPercent))", bundle: .module)
                            .foregroundStyle(MobilePalette.secondaryText)
                    }
                    if let comparison = results.comparison {
                        Text(comparison.text)
                            .foregroundStyle(MobilePalette.secondaryText)
                            .accessibilityIdentifier("results.comparison")
                    }
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(results.verdictAccessibilityLabel)
                .accessibilityAddTraits(.isHeader)
            }
            if let saveError = results.saveError {
                Section {
                    Label(saveError, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(MobilePalette.warning)
                        .accessibilityIdentifier("results.saveError")
                }
            }
            Section {
                ForEach(results.infoRows()) { row in
                    LabeledContent(row.label, value: row.value)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(row.accessibilityLabel)
                }
            }
            if let reason = results.detailUnavailableReason {
                Section {
                    Text(reason)
                        .foregroundStyle(MobilePalette.secondaryText)
                        .accessibilityIdentifier("results.detailUnavailable")
                }
            }
            if !results.sectionRows.isEmpty {
                Section {
                    SectionHeader(localized("Theo phần"))
                    ForEach(results.sectionRows) { row in
                        SectionResultRow(row: row)
                    }
                }
            }
            Section {
                if let reason = results.reviewUnavailableReason ?? results.reviewFailure {
                    Text(reason)
                        .foregroundStyle(MobilePalette.secondaryText)
                        .accessibilityIdentifier("results.reviewUnavailable")
                }
                Button {
                    Task { await session.openAnswerReview(filter: .all) }
                } label: {
                    Label(localized("Xem lại bài"), systemImage: "doc.text.magnifyingglass")
                }
                .disabled(!results.canReview || session.isLoadingReview)
                .accessibilityIdentifier("results.review")
                if results.incorrectCount > 0 {
                    Button {
                        Task { await session.openAnswerReview(filter: .incorrect) }
                    } label: {
                        Label(localized("Xem câu sai"), systemImage: "xmark.circle")
                    }
                    .disabled(!results.canReview || session.isLoadingReview)
                    .accessibilityIdentifier("results.reviewIncorrect")
                }
                if results.retakePreset != nil {
                    Button {
                        Task { await sessions.retake() }
                    } label: {
                        Label(localized("Làm lại"), systemImage: "arrow.counterclockwise")
                    }
                    .accessibilityIdentifier("results.retake")
                }
                Button {
                    sessions.returnToLibrary()
                } label: {
                    Label(localized("Về thư viện"), systemImage: "books.vertical")
                }
                .accessibilityIdentifier("results.library")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(localized("Kết quả"))
        .onAppear {
            if results.origin == .history {
                AccessibilityNotification.Announcement(localized("Kết quả: \(results.verdictText), \(results.scoreText)"))
                    .post()
            }
        }
    }
}

/// Điểm của một phần: số câu đúng, phần trăm; phần yếu nhất có nhãn riêng.
struct SectionResultRow: View {
    let row: ResultSectionRow

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(row.title)
                Spacer()
                Text(row.detailText)
                    .foregroundStyle(MobilePalette.secondaryText)
                    .monospacedDigit()
            }
            if let fraction = row.fraction {
                ProgressView(value: fraction)
                    .tint(MobilePalette.accent)
            }
            if row.isWeakest {
                Label(localized("Phần yếu nhất"), systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(MobilePalette.warning)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.accessibilityLabel)
    }
}
