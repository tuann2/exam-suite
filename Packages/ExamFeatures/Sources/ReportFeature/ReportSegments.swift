import CoreGraphics
import SwiftUI

/// Phần nhỏ nhất của một khối khi phân trang: trang chỉ ngắt **giữa** các phần (đoạn, ảnh, lựa chọn, giải thích,
/// dòng bảng), không bao giờ giữa một dòng chữ. Đoạn chữ cao hơn cả trang được tách tiếp theo ranh giới từ
/// (`ReportRenderer`).
enum ReportSegment: Hashable {
    case title(String, subtitle: String?)
    case fields([ReportField])
    /// Chữ Markdown đã dựng (NFC, phông của PDF); `boxed`: nằm trong khung giải thích.
    case text(AttributedString, boxed: Bool)
    case verdict(ReportBadge, score: String)
    case scoreBar(fraction: Double, threshold: Double?)
    case badge(ReportBadge)
    case notice(ReportNotice)
    case heading(String, detail: String?)
    /// "Câu 12 (tiếp)": mở phần của khối bị tách sang trang sau.
    case continuation(String)
    case sectionRow(ReportSectionScores.Row)
    case questionHeader(section: String, position: String, status: ReportBadge?, flag: ReportBadge?)
    /// Ảnh đã biết cỡ hiển thị (điểm); byte giải mã lúc vẽ.
    case image(Data, size: CGSize)
    case hint(String)
    /// Lựa chọn; `continued`: mảnh sau của một lựa chọn quá cao bị tách (nhãn "A (tiếp)", dấu chỉ ở mảnh đầu).
    case option(label: String, text: AttributedString, marks: [ReportBadge], emphasized: Bool, continued: Bool)
    case explanationTitle(String)

    /// Đoạn chữ và lựa chọn tách được theo từ khi không vừa chỗ còn lại của trang.
    var isSplittable: Bool {
        switch self {
        case .text, .option: true
        default: false
        }
    }

    /// Khoảng cách phía trên phần này khi nó không đứng đầu một mảnh trên trang.
    var gapBefore: CGFloat {
        switch self {
        case .text(_, boxed: true): 0
        case .option, .sectionRow: 6
        case .scoreBar: 6
        default: 8
        }
    }
}

/// Một khối đã bung thành các phần, kèm luật phân trang.
struct ReportLayoutBlock {
    var segments: [ReportSegment]
    /// Phần mở đầu mảnh sang trang sau ("Câu 12 (tiếp)"); nil thì mảnh sau không có dòng tiếp.
    var continuation: ReportSegment?
    /// Đề mục: không đứng một mình cuối trang.
    var keepWithNext: Bool
}

extension ReportLayoutBlock {
    /// Bung khối của tài liệu thành các phần. Ảnh: lấy cỡ từ thuộc tính (không giải mã); không đọc được thì thay
    /// bằng dòng "Không hiện được ảnh của câu này".
    static func make(_ block: ReportBlock, geometry: ReportPageGeometry) -> ReportLayoutBlock {
        switch block {
        case let .title(title):
            var segments: [ReportSegment] = [.title(title.title, subtitle: title.subtitle)]
            if !title.fields.isEmpty { segments.append(.fields(title.fields)) }
            if let instructions = title.instructions, !instructions.isEmpty {
                segments += paragraphs(instructions, boxed: false)
            }
            return ReportLayoutBlock(
                segments: segments,
                continuation: .continuation(ReportStrings.continued(title.title)),
                keepWithNext: false
            )

        case let .resultSummary(summary):
            var segments: [ReportSegment] = [
                .verdict(summary.verdict, score: summary.scoreText),
                .scoreBar(fraction: summary.scoreFraction, threshold: summary.passThresholdFraction),
            ]
            if !summary.fields.isEmpty { segments.append(.fields(summary.fields)) }
            if let comparison = summary.comparison { segments.append(.badge(comparison)) }
            segments += summary.notices.map { .notice($0) }
            return ReportLayoutBlock(segments: segments, continuation: nil, keepWithNext: false)

        case let .sectionScores(table):
            return ReportLayoutBlock(
                segments: [.heading(table.title, detail: nil)] + table.rows.map { .sectionRow($0) },
                continuation: .continuation(ReportStrings.continued(table.title)),
                keepWithNext: false
            )

        case let .heading(heading):
            return ReportLayoutBlock(
                segments: [.heading(heading.title, detail: heading.detail)],
                continuation: nil,
                keepWithNext: true
            )

        case let .notice(notice):
            return ReportLayoutBlock(segments: [.notice(notice)], continuation: nil, keepWithNext: false)

        case let .question(question):
            var segments: [ReportSegment] = [.questionHeader(
                section: question.sectionTitle,
                position: question.positionText,
                status: question.status,
                flag: question.flag
            )]
            segments += question.notices.map { .notice($0) }
            if let text = question.text, !text.isEmpty {
                segments += paragraphs(text, boxed: false, size: ReportTypography.bodySize + 1)
            }
            switch question.image {
            case let .data(data):
                if let size = ReportImages.displaySize(
                    of: data,
                    maxWidth: geometry.contentWidth,
                    maxHeight: geometry.maxImageHeight
                ) {
                    segments.append(.image(data, size: size))
                } else {
                    segments.append(.notice(ReportNotice(text: ReportStrings.imageUnavailable, systemImage: "photo.badge.exclamationmark")))
                }
            case .missing:
                segments.append(.notice(ReportNotice(text: ReportStrings.imageUnavailable, systemImage: "photo.badge.exclamationmark")))
            case nil:
                break
            }
            if let hint = question.hint { segments.append(.hint(hint)) }
            segments += question.options.map { option in
                .option(
                    label: option.label,
                    text: ReportTypography.markdown(option.text),
                    marks: option.marks,
                    emphasized: option.isEmphasized,
                    continued: false
                )
            }
            if let explanation = question.explanation, !explanation.isEmpty {
                segments.append(.explanationTitle(ReportStrings.explanation))
                segments += paragraphs(explanation, boxed: true)
            }
            return ReportLayoutBlock(
                segments: segments,
                continuation: .continuation(ReportStrings.questionContinued(question.number)),
                keepWithNext: false
            )
        }
    }

    /// Tách Markdown theo đoạn (dòng trống) để trang có thể ngắt giữa các đoạn; Markdown inline không vượt qua
    /// dòng trống nên tách trước khi phân tích là an toàn.
    static func paragraphs(_ source: String, boxed: Bool, size: CGFloat = ReportTypography.bodySize) -> [ReportSegment] {
        let normalized = source.replacingOccurrences(of: "\r\n", with: "\n")
        let parts = normalized.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return (parts.isEmpty ? [normalized] : parts).map { .text(ReportTypography.markdown($0, size: size), boxed: boxed) }
    }
}
