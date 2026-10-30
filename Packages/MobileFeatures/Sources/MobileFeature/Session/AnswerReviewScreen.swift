import ExamKit
import InterfaceCore
import SessionModel
import SwiftUI
import UIKit

/// **Xem lại bài** (docs/product/exam-taking.md, mục Xem lại bài): bộ lọc (Tất cả, Sai, Chưa làm, Đánh dấu), danh sách
/// câu, chạm để xem chi tiết (lựa chọn của bạn, đáp án đúng, giải thích; đề `hideAnswers` không hiện đáp án đúng và
/// giải thích; câu đã sửa sau lần thi có ghi chú), **Luyện lại câu sai**. Mọi luật ở `AnswerReviewModel` (dùng chung
/// với bản macOS).
struct AnswerReviewScreen: View {
    let session: MobileSession
    let review: AnswerReviewModel
    let sessions: MobileSessionCoordinator

    @State private var isDetailPresented = false

    var body: some View {
        VStack(spacing: 0) {
            reviewList
            bottomBar
        }
        .navigationTitle(localized("Xem lại bài"))
        .navigationDestination(isPresented: $isDetailPresented) {
            ReviewDetailScreen(review: review)
        }
    }

    private var reviewList: some View {
        List {
            Section {
                // Năm bộ lọc kèm số câu không vừa một hàng nút trên iPhone: menu chọn.
                Picker(localized("Bộ lọc"), selection: Binding(get: { review.filter }, set: { review.setFilter($0) })) {
                    ForEach(AnswerReviewFilter.allCases) { filter in
                        Text(review.filterTitle(filter)).tag(filter)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("review.filter")
            }
            Section {
                ForEach(review.rows) { row in
                    Button {
                        review.select(index: row.index)
                        isDetailPresented = true
                    } label: {
                        ReviewRowLabel(row: row)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(row.accessibilityLabel)
                    .accessibilityAddTraits(.isButton)
                }
            }
        }
        .listStyle(.insetGrouped)
        .solidBottomEdge()
        .overlay {
            if review.rows.isEmpty {
                ContentUnavailableView {
                    Label(localized("Không có câu nào"), systemImage: "line.3.horizontal.decrease.circle")
                } description: {
                    Text("Bộ lọc này không có câu nào.", bundle: .module)
                }
            }
        }
    }

    private var bottomBar: some View {
        HStack {
            Button {
                session.showResults()
            } label: {
                Label(localized("Kết quả"), systemImage: "chevron.backward")
            }
            .accessibilityIdentifier("review.results")
            Spacer()
            if review.practiceIncorrectPreset != nil {
                Button {
                    Task { await sessions.practiceIncorrect() }
                } label: {
                    Label(localized("Luyện lại câu sai"), systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.borderedProminent)
                .tint(LibraryPalette.accentFill.color)
                .accessibilityIdentifier("review.practiceIncorrect")
            }
        }
        .padding()
        .background(MobilePalette.barBackground)
        .overlay(alignment: .top) { Divider() }
    }
}

/// Một câu trong danh sách: số câu, Đúng/Sai/Chưa làm, đánh dấu, đã sửa/đã xoá, đầu câu hỏi.
struct ReviewRowLabel: View {
    let row: AnswerReviewRow

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Text("Câu \(row.number)", bundle: .module)
                    .font(.headline)
                Label(row.status.title, systemImage: row.status.systemImage)
                    .font(.subheadline)
                    .foregroundStyle(ReviewColors.color(for: row.status.outcome))
                if row.isFlagged {
                    Label(localized("Đánh dấu"), systemImage: "flag.fill")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(MobilePalette.warning)
                }
                switch row.change {
                case .unchanged:
                    EmptyView()
                case .edited:
                    Label(localized("Đã sửa"), systemImage: "pencil.circle")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(MobilePalette.secondaryText)
                case .deleted:
                    Label(localized("Đã xoá"), systemImage: "trash.circle")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(MobilePalette.secondaryText)
                }
            }
            Text(PlainMarkdown.text(row.preview))
                .font(.subheadline)
                .foregroundStyle(MobilePalette.secondaryText)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

enum ReviewColors {
    static func color(for outcome: QuestionOutcome) -> Color {
        switch outcome {
        case .correct: MobilePalette.positive
        case .incorrect: MobilePalette.critical
        case .unanswered: MobilePalette.secondaryText
        }
    }
}

/// Chi tiết một câu; câu trước/sau trong bộ lọc.
struct ReviewDetailScreen: View {
    let review: AnswerReviewModel

    var body: some View {
        Group {
            if let detail = review.detail {
                ScrollView {
                    ReviewDetailView(detail: detail, media: review.media, answersHidden: review.answersHidden)
                        .padding()
                        .id(detail.index)
                }
                .navigationTitle(localized("Câu \(detail.number)/\(detail.total)"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .bottomBar) {
                        Button {
                            review.previous()
                        } label: {
                            Label(localized("Câu trước"), systemImage: "chevron.left")
                        }
                        .disabled(!review.canGoPrevious)
                        Spacer()
                        Button {
                            review.next()
                        } label: {
                            Label(localized("Câu sau"), systemImage: "chevron.right")
                        }
                        .disabled(!review.canGoNext)
                    }
                }
                .onChange(of: review.selectedIndex) { _, index in
                    guard let index else { return }
                    let detail = review.detail(at: index)
                    AccessibilityNotification.Announcement(
                        localized("Câu \(detail.number) trên \(detail.total), \(detail.status.title)")
                    ).post()
                }
            } else {
                ContentUnavailableView(localized("Chọn một câu để xem lại"), systemImage: "doc.text.magnifyingglass")
            }
        }
    }
}

/// Nội dung một câu khi xem lại.
struct ReviewDetailView: View {
    let detail: AnswerReviewDetail
    let media: [String: Data]
    let answersHidden: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(detail.sectionTitle)
                    .font(.subheadline)
                    .foregroundStyle(MobilePalette.secondaryText)
                HStack(spacing: 10) {
                    Label(detail.status.title, systemImage: detail.status.systemImage)
                        .font(.headline)
                        .foregroundStyle(ReviewColors.color(for: detail.status.outcome))
                    if detail.isFlagged {
                        Label(localized("Đã đánh dấu"), systemImage: "flag.fill")
                            .foregroundStyle(MobilePalette.warning)
                    }
                }
            }
            ForEach(Array(detail.notices.enumerated()), id: \.offset) { _, notice in
                Label(notice, systemImage: "info.circle")
                    .font(.subheadline)
                    .foregroundStyle(MobilePalette.secondaryText)
            }
            if let text = detail.text {
                Text(PlainMarkdown.attributed(text))
                    .textSelection(.enabled)
            }
            if let path = detail.imagePath, let data = media[path], let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 280)
                    .accessibilityLabel(localized("Ảnh của câu hỏi"))
            }
            if answersHidden, detail.text != nil {
                Label(
                    localized("Đề này ẩn đáp án: chỉ hiện lựa chọn của bạn và kết quả đúng/sai."),
                    systemImage: "eye.slash"
                )
                .font(.subheadline)
                .foregroundStyle(MobilePalette.secondaryText)
            }
            VStack(spacing: 8) {
                ForEach(detail.options) { option in
                    ReviewOptionRow(option: option)
                }
            }
            if let explanation = detail.explanation, !explanation.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Giải thích", bundle: .module)
                        .font(.headline)
                    Text(PlainMarkdown.attributed(explanation))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Một lựa chọn khi xem lại: "Bạn chọn", "Đáp án đúng" bằng biểu tượng + chữ.
struct ReviewOptionRow: View {
    let option: ReviewOption

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(option.label)
                    .font(.body.weight(.semibold))
                Text(PlainMarkdown.attributed(option.text))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 12) {
                if option.isSelected {
                    Label(localized("Bạn chọn"), systemImage: "hand.point.up.left.fill")
                        .foregroundStyle(MobilePalette.accent)
                }
                if option.isCorrectAnswer == true {
                    Label(localized("Đáp án đúng"), systemImage: "checkmark.circle.fill")
                        .foregroundStyle(MobilePalette.positive)
                }
            }
            .font(.subheadline.weight(.semibold))
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(uiColor: .secondarySystemBackground)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(option.accessibilityLabel)
    }
}
