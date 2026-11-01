import ExamKit
import SessionModel
import SwiftUI

/// Một câu hiển thị như cửa sổ làm bài, chỉ đọc: tên phần và số câu, nội dung (Markdown cơ bản), ảnh, nhắc số
/// đáp án của câu nhiều đáp án, lựa chọn **theo thứ tự file** (A, B, C… theo vị trí). Dùng cho cột Xem trước của
/// cửa sổ soạn đề (bản Admin, docs/product/authoring.md mục Cửa sổ); dùng chung cách hiện chữ và ảnh của cửa sổ
/// làm bài (`MarkdownText`, `QuestionImageView`) để xem trước giống lúc làm bài.
///
/// Không chứa code soạn đề: chỉ vẽ một `Question` (ADR 0003).
public struct QuestionPreview: View {
    /// Luyện tập: hiện như sau **Kiểm tra đáp án** (đánh dấu đáp án đúng, giải thích). Thi: chỉ câu hỏi.
    public enum Mode: Hashable, Sendable {
        case practice
        case exam
    }

    private let question: Question
    private let sectionTitle: String
    private let positionText: String
    private let imageData: Data?
    private let mode: Mode

    @Environment(\.readingStyle) private var reading

    /// - Parameters:
    ///   - positionText: như "Câu 3/60".
    ///   - imageData: byte ảnh của câu nếu có trong gói; câu có ảnh mà thiếu byte thì báo thiếu ảnh.
    public init(question: Question, sectionTitle: String, positionText: String, imageData: Data?, mode: Mode) {
        self.question = question
        self.sectionTitle = sectionTitle
        self.positionText = positionText
        self.imageData = imageData
        self.mode = mode
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Cột xem trước hẹp (240–340 pt): tên phần và "Câu 1/40" một dòng nếu vừa, không thì hai dòng (tên phần trên,
            // số câu dưới), không để tên phần xuống dòng quanh số câu.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(sectionTitle).foregroundStyle(reading.secondaryText)
                    Text(positionText).monospacedDigit()
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(sectionTitle).foregroundStyle(reading.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(positionText).monospacedDigit()
                }
            }
            .contentFont(.headline)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            MarkdownText(question.text)
                .contentFont(.title3)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)

            if let imageData {
                QuestionImageView(data: imageData)
            } else if let image = question.image {
                Label(localized("Không có ảnh \(image) trong gói"), systemImage: "photo.badge.exclamationmark")
                    .foregroundStyle(reading.secondaryText)
            }

            if question.type == .multiple {
                Label(localized("Chọn \(question.correctSet.count) đáp án"), systemImage: "checklist")
                    .contentFont(.callout, weight: .semibold)
                    .foregroundStyle(reading.accent)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(question.options.enumerated()), id: \.offset) { position, option in
                    PreviewOptionRow(
                        label: SessionFormat.optionLabel(position: position),
                        text: option.text,
                        isMultiple: question.type == .multiple,
                        isCorrect: mode == .practice ? question.correctSet.contains(option.id) : nil
                    )
                }
            }

            if mode == .practice, let explanation = question.explanation, !explanation.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Giải thích", bundle: .module).contentFont(.headline)
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
            }
        }
        // Cỡ chữ của vùng nội dung câu (Phóng to/Thu nhỏ, phương án 5): chữ không đặt phông riêng là body theo hệ số.
        .contentBodyFont()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Hàng lựa chọn của xem trước: radio/ô đánh dấu trống như lúc chưa chọn; ở Luyện tập, lựa chọn đúng có nhãn
/// "Đáp án đúng" (biểu tượng + chữ) ngay dưới chữ của lựa chọn: cột xem trước hẹp, nhãn đặt bên phải như cửa sổ làm bài
/// thì ép chữ của lựa chọn còn vài chữ mỗi dòng. Nhãn một dòng khi vừa, xuống dòng khi không vừa (phóng to 150%, tiếng
/// Anh "Correct answer" ở cột 240 pt), không tràn khỏi hàng (bước 8b; trước đây `.fixedSize()`).
///
/// VoiceOver đọc như lựa chọn của cửa sổ làm bài: "A. <nội dung>", thêm "Đáp án đúng" (`accessibilityLabel`).
struct PreviewOptionRow: View {
    let label: String
    let text: String
    let isMultiple: Bool
    let isCorrect: Bool?

    @Environment(\.questionContentScale) private var scale
    @Environment(\.readingStyle) private var reading

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: isMultiple ? "square" : "circle")
                .contentFont(.title3)
                .foregroundStyle(reading.secondaryText)
                .accessibilityHidden(true)
            Text(label)
                .contentFont(.body, weight: .semibold, design: .monospaced)
                .frame(minWidth: 18 * scale, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                MarkdownText(text)
                    .fixedSize(horizontal: false, vertical: true)
                if isCorrect == true {
                    Label(localized("Đáp án đúng"), systemImage: "checkmark.circle.fill")
                        .contentFont(.callout, weight: .semibold)
                        .foregroundStyle(reading.positive)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(reading.optionBackground, in: RoundedRectangle(cornerRadius: SessionStyle.cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: SessionStyle.cornerRadius)
                .strokeBorder(isCorrect == true ? AnyShapeStyle(reading.positive) : reading.border)
        }
        .accessibilityElement(children: .ignore)
        // Vai trò chữ tĩnh: phần tử gộp không có vai trò thì kiểm trợ năng báo "Unknown role" (bước 8b).
        .accessibilityAddTraits(.isStaticText)
        .accessibilityLabel(Text(Self.accessibilityLabel(label: label, text: text, isCorrect: isCorrect)))
    }

    /// Câu VoiceOver của hàng: "A. <nội dung không ký hiệu Markdown>", thêm ", Đáp án đúng" với lựa chọn đúng ở Luyện tập.
    static func accessibilityLabel(label: String, text: String, isCorrect: Bool?) -> String {
        let option = localized("\(label). \(MarkdownText.plain(text))")
        return isCorrect == true ? [option, localized("Đáp án đúng")].joined(separator: ", ") : option
    }
}
