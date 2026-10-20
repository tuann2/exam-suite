import CoreGraphics
import SwiftUI

// View của PDF chỉ dùng `Text`, `Image`, `Grid`, hình và stack: `ImageRenderer` trên macOS không vẽ control AppKit
// (`Button` mặc định, `Toggle`, `TextField`, `ProgressView`, `ScrollView`, `List`) và không chạy `.task`
// (docs/notes/g5-spike-pdf-l10n.md). Gốc mỗi mảnh ép giao diện sáng và chữ đen.

/// Một mảnh (các phần liên tiếp của một khối) vẽ trên một trang.
struct ReportChunkView: View {
    let segments: [ReportSegment]
    /// Ảnh đã giải mã theo vị trí phần trong `segments`; thiếu thì để khung trống đúng cỡ (lượt đo).
    let images: [Int: CGImage]
    let width: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(segments.indices, id: \.self) { index in
                ReportSegmentView(segment: segments[index], image: images[index])
                    .padding(.top, index == 0 ? 0 : segments[index].gapBefore)
            }
        }
        .frame(width: width, alignment: .topLeading)
        .foregroundStyle(ReportTypography.primary)
        .environment(\.colorScheme, .light)
    }
}

/// Chân trang: tên đề + "Trang N/M", rồi các dòng của tài liệu.
struct ReportFooterView: View {
    let footer: ReportFooter
    let pageLabel: String
    let width: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Rectangle().fill(ReportTypography.rule).frame(height: 0.5)
                .padding(.bottom, 3)
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(ReportTypography.plain(footer.title, font: ReportTypography.body(size: ReportTypography.footerSize, bold: true), color: ReportTypography.secondary))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
                Text(ReportTypography.plain(pageLabel, font: ReportTypography.body(size: ReportTypography.footerSize, bold: true), color: ReportTypography.secondary))
                    .fixedSize()
            }
            ForEach(footer.lines.indices, id: \.self) { index in
                Text(ReportTypography.plain(footer.lines[index], font: ReportTypography.body(size: ReportTypography.footerSize), color: ReportTypography.secondary))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(width: width, alignment: .topLeading)
        .environment(\.colorScheme, .light)
    }
}

struct ReportSegmentView: View {
    let segment: ReportSegment
    let image: CGImage?

    var body: some View {
        switch segment {
        case let .title(title, subtitle):
            VStack(alignment: .leading, spacing: 3) {
                if let subtitle {
                    Text(ReportTypography.plain(subtitle, font: ReportTypography.body(size: ReportTypography.bodySize, bold: true), color: ReportTypography.secondary))
                }
                paragraph(ReportTypography.plain(title, font: ReportTypography.body(size: ReportTypography.titleSize, bold: true)))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        case let .fields(fields):
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 14, verticalSpacing: 4) {
                ForEach(fields.indices, id: \.self) { index in
                    GridRow {
                        Text(ReportTypography.plain(fields[index].label, font: ReportTypography.body(), color: ReportTypography.secondary))
                            .fixedSize()
                        paragraph(ReportTypography.plain(fields[index].value, font: ReportTypography.body()))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        case let .text(text, boxed):
            if boxed {
                paragraph(text)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(ReportTypography.tint)
            } else {
                paragraph(text)
            }

        case let .verdict(verdict, score):
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                badge(verdict, size: ReportTypography.verdictSize)
                Text(ReportTypography.plain(score, font: ReportTypography.body(size: ReportTypography.titleSize, bold: true)))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        case let .scoreBar(fraction, threshold):
            ReportScoreBar(fraction: fraction, threshold: threshold)

        case let .badge(value):
            badge(value, size: ReportTypography.bodySize)
                .frame(maxWidth: .infinity, alignment: .leading)

        case let .notice(notice):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                symbol(notice.systemImage, size: ReportTypography.bodySize)
                paragraph(ReportTypography.plain(notice.text, font: ReportTypography.body(bold: true)))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay { Rectangle().strokeBorder(ReportTypography.rule, lineWidth: 0.5) }

        case let .heading(title, detail):
            VStack(alignment: .leading, spacing: 2) {
                paragraph(ReportTypography.plain(title, font: ReportTypography.body(size: ReportTypography.headingSize, bold: true)))
                if let detail {
                    paragraph(ReportTypography.plain(detail, font: ReportTypography.body(), color: ReportTypography.secondary))
                }
            }

        case let .continuation(text):
            Text(ReportTypography.plain(text, font: ReportTypography.body(size: ReportTypography.smallSize, bold: true), color: ReportTypography.secondary))
                .frame(maxWidth: .infinity, alignment: .leading)

        case let .sectionRow(row):
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    paragraph(ReportTypography.plain(row.title, font: ReportTypography.body()))
                    if let mark = row.mark {
                        badge(mark, size: ReportTypography.smallSize)
                    }
                }
                .frame(width: 210, alignment: .leading)
                ZStack(alignment: .leading) {
                    if let fraction = row.fraction {
                        Rectangle().fill(ReportTypography.tint)
                        Rectangle().fill(ReportTypography.fill).frame(width: max(0, min(1, fraction)) * 130)
                    }
                }
                .frame(width: 130, height: 7)
                Text(ReportTypography.plain(row.detail, font: ReportTypography.body(), color: row.fraction == nil ? ReportTypography.secondary : ReportTypography.primary))
                    .fixedSize()
                Spacer(minLength: 0)
            }

        case let .questionHeader(section, position, status, flag):
            VStack(alignment: .leading, spacing: 5) {
                Rectangle().fill(ReportTypography.rule).frame(height: 0.75)
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(ReportTypography.plain(section, font: ReportTypography.body(bold: true), color: ReportTypography.secondary))
                        .lineLimit(2)
                    Text(ReportTypography.plain(position, font: ReportTypography.body(bold: true)))
                        .fixedSize()
                    if let status { badge(status, size: ReportTypography.bodySize).fixedSize() }
                    if let flag { badge(flag, size: ReportTypography.bodySize).fixedSize() }
                    Spacer(minLength: 0)
                }
            }

        case let .image(_, size):
            Group {
                if let image {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .interpolation(.high)
                } else {
                    Color.clear
                }
            }
            .frame(width: size.width, height: size.height)
            .overlay { Rectangle().strokeBorder(ReportTypography.rule, lineWidth: 0.5) }
            .frame(maxWidth: .infinity, alignment: .leading)

        case let .hint(hint):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                symbol("checklist", size: ReportTypography.bodySize)
                Text(ReportTypography.plain(hint, font: ReportTypography.body(bold: true)))
            }

        case let .option(label, text, marks, emphasized, continued):
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(ReportTypography.plain(label, font: ReportTypography.code(bold: true)))
                    if continued {
                        Text(ReportTypography.plain(ReportStrings.optionContinued, font: ReportTypography.body(size: ReportTypography.smallSize), color: ReportTypography.secondary))
                            .fixedSize()
                    }
                }
                .frame(minWidth: 14, alignment: .leading)
                paragraph(text)
                if !marks.isEmpty {
                    VStack(alignment: .trailing, spacing: 2) {
                        ForEach(marks.indices, id: \.self) { index in
                            badge(marks[index], size: ReportTypography.smallSize).fixedSize()
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(emphasized ? ReportTypography.primary : ReportTypography.rule, lineWidth: emphasized ? 1.5 : 0.5)
            }

        case let .explanationTitle(title):
            Text(ReportTypography.plain(title, font: ReportTypography.body(bold: true)))
                .padding(.horizontal, 10)
                .padding(.top, 8)
                .padding(.bottom, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ReportTypography.tint)
        }
    }

    /// Đoạn chữ xuống dòng theo bề rộng (theo từ của hệ thống).
    private func paragraph(_ text: AttributedString) -> some View {
        Text(text)
            .lineSpacing(1.5)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Ký hiệu + chữ (không dùng màu làm tín hiệu duy nhất).
    private func badge(_ badge: ReportBadge, size: CGFloat) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            symbol(badge.systemImage, size: size)
            Text(ReportTypography.plain(badge.title, font: ReportTypography.body(size: size, bold: true)))
        }
    }

    private func symbol(_ name: String, size: CGFloat) -> some View {
        Image(systemName: name)
            .font(.system(size: size * 0.95, weight: .semibold))
            .foregroundStyle(ReportTypography.primary)
            .accessibilityHidden(true)
    }
}

/// Thanh điểm có vạch ngưỡng đậu (đen trắng).
struct ReportScoreBar: View {
    let fraction: Double
    let threshold: Double?
    var width: CGFloat = 300

    var body: some View {
        ZStack(alignment: .leading) {
            Rectangle().fill(ReportTypography.tint)
            Rectangle().fill(ReportTypography.fill).frame(width: max(0, min(1, fraction)) * width)
            if let threshold {
                Rectangle()
                    .fill(ReportTypography.primary)
                    .frame(width: 2, height: 16)
                    .offset(x: max(0, min(1, threshold)) * width - 1)
            }
        }
        .frame(width: width, height: 10)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
