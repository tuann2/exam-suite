import CoreGraphics
import Foundation
import InterfaceCore
import SwiftUI

/// Khổ trang và lề của PDF (docs/product/export-print.md, Trình bày chung): luôn **A4** dọc 595 × 842 pt, lề 18 mm.
public struct ReportPageGeometry: Sendable, Hashable {
    public var pageSize: CGSize
    public var margin: CGFloat

    public static let a4 = ReportPageGeometry(pageSize: CGSize(width: 595, height: 842), margin: 51)

    public init(pageSize: CGSize, margin: CGFloat) {
        self.pageSize = pageSize
        self.margin = margin
    }

    var contentWidth: CGFloat { pageSize.width - 2 * margin }
    /// Ảnh câu hỏi cao tối đa 1/3 trang.
    var maxImageHeight: CGFloat { (pageSize.height / 3).rounded(.down) }
}

/// Tiến độ dựng PDF: lượt xếp trang (đo từng khối) rồi lượt vẽ từng trang.
public struct ReportProgress: Sendable, Hashable {
    public enum Phase: Sendable, Hashable {
        /// Đo và xếp khối; `completed`/`total` là số khối.
        case layout
        /// Vẽ trang; `completed` là số trang đã vẽ, `total` là số trang.
        case drawing
    }

    public let phase: Phase
    public let completed: Int
    public let total: Int

    /// "Đang chuẩn bị trang…" / "Đang dựng trang N…".
    public var message: String {
        switch phase {
        case .layout: ReportStrings.preparing
        case .drawing: ReportStrings.drawingPage(min(completed + 1, max(total, 1)))
        }
    }

    /// 0…1 cho thanh tiến độ: xếp trang chiếm 40%, vẽ 60% (gần đúng theo số đo của spike).
    public var fractionCompleted: Double {
        let part = total > 0 ? Double(completed) / Double(total) : 1
        switch phase {
        case .layout: return 0.4 * part
        case .drawing: return 0.4 + 0.6 * part
        }
    }
}

/// PDF đã dựng, trong bộ nhớ (ánh xạ từ file tạm đã xoá): cho In và test.
public struct ReportPDF: Sendable {
    public let data: Data
    public let pageCount: Int
}

/// PDF đã ghi ra file.
public struct ReportPDFFile: Sendable, Hashable {
    public let url: URL
    public let pageCount: Int
}

public enum ReportRenderError: Error, Equatable, Sendable {
    /// Core Graphics không tạo được ngữ cảnh PDF (ví dụ không ghi được vào đường dẫn đích).
    case cannotCreateContext
}

/// Bộ dựng trang (cách A của docs/product/export-print.md, số đo ở docs/notes/g5-spike-pdf-l10n.md): đo từng khối bằng
/// `ImageRenderer` ở bề rộng vùng in, xếp tham lam vào trang A4, rồi vẽ từng trang vào `CGContext` PDF ghi thẳng ra file
/// (`CGDataConsumer(url:)`, không giữ cả PDF trong bộ nhớ). Chữ là chữ thật (chọn, tìm, sao chép được).
///
/// Chạy trên main actor (`ImageRenderer`), nhường lượt khi đã chạy liền ≥ 16 ms (kể cả giữa các lần đo của một khối quá
/// cao) và sau mỗi trang; ảnh giải mã ngoài main actor (trang kế được giải mã trong lúc vẽ trang này). Kiểm huỷ
/// (`Task.isCancelled`) ở mỗi lần nhường: huỷ thì ném `CancellationError` và xoá file dở.
///
/// Cách dùng: Xuất PDF… qua `ReportFileWriter` (`render(_:to:)` vào file tạm ẩn cạnh file đích, rồi `rename(2)`;
/// export-print.md: ghi file tạm rồi thay, không để file dở). In…: `render(_:)` trả `Data` cho `ReportPrinting`.
@MainActor
public struct ReportRenderer {
    public let geometry: ReportPageGeometry
    /// Locale của môi trường SwiftUI khi đo và vẽ: ngôn ngữ giao diện (`InterfaceLocale.current`), như mọi cửa sổ của
    /// app, để số và ngày trong `Text` không theo Region của macOS (accessibility-localization.md, mục Ngôn ngữ). Chữ
    /// của tài liệu đã được định dạng sẵn khi dựng `ReportDocument`.
    public let locale: Locale
    /// Thời gian chạy liền tối đa trên main actor trước khi nhường lượt.
    static let yieldInterval: Duration = .milliseconds(16)
    /// Khoảng cách giữa hai khối.
    static let blockSpacing: CGFloat = 16
    /// Khoảng cách giữa vùng nội dung và chân trang.
    static let footerGap: CGFloat = 10

    public init(geometry: ReportPageGeometry = .a4, locale: Locale = InterfaceLocale.current) {
        self.geometry = geometry
        self.locale = locale
    }

    /// Dựng PDF của `document` rồi trả dữ liệu (cho In, test). PDF được ghi ra file tạm của hệ thống rồi ánh xạ vào bộ nhớ;
    /// file tạm bị xoá khi xong, lỗi, huỷ, hoặc app thoát bình thường giữa chừng (`ReportTemporaryFiles`).
    public func render(
        _ document: ReportDocument,
        progress: (ReportProgress) -> Void = { _ in }
    ) async throws -> ReportPDF {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ExamSuiteReport-\(UUID().uuidString).pdf", isDirectory: false)
        ReportTemporaryFiles.track(url)
        defer {
            ReportTemporaryFiles.untrack(url)
            try? FileManager.default.removeItem(at: url)
        }
        let file = try await render(document, to: url, progress: progress)
        let data = try Data(contentsOf: url, options: .alwaysMapped)
        return ReportPDF(data: data, pageCount: file.pageCount)
    }

    /// Dựng PDF của `document` và ghi thẳng ra `url` (ghi đè). Lỗi hoặc huỷ thì xoá file dở ở `url`. `progress` được gọi
    /// trên main actor ở mỗi lần nhường lượt khi xếp trang và mỗi trang khi vẽ.
    public func render(
        _ document: ReportDocument,
        to url: URL,
        progress: (ReportProgress) -> Void = { _ in }
    ) async throws -> ReportPDFFile {
        let pacer = Pacer(interval: Self.yieldInterval)
        let width = geometry.contentWidth
        let metrics = layoutMetrics(for: document.footer)
        let contentHeight = metrics.contentHeight

        // Lượt 1: bung khối, đo, tách khối quá cao.
        progress(ReportProgress(phase: .layout, completed: 0, total: document.blocks.count))
        try await pacer.pause()
        var measured: [MeasuredBlock] = []
        measured.reserveCapacity(document.blocks.count)
        for (index, block) in document.blocks.enumerated() {
            if pacer.isDue {
                progress(ReportProgress(phase: .layout, completed: index, total: document.blocks.count))
                try await pacer.pause()
            }
            let layout = ReportLayoutBlock.make(block, geometry: geometry)
            let height = measureHeight(layout.segments, width: width)
            var result = MeasuredBlock(
                segments: layout.segments,
                height: height,
                segmentHeights: nil,
                continuation: layout.continuation,
                continuationHeight: 0,
                keepWithNext: layout.keepWithNext
            )
            if height > contentHeight {
                result = try await segmentize(result, width: width, pacer: pacer)
            }
            measured.append(result)
        }
        // Đề mục mà cộng khối sau (vừa một trang) cao hơn một trang: cho khối sau tách được để đề mục không đứng một
        // mình cuối trang.
        for index in measured.indices.dropLast() where measured[index].keepWithNext {
            let next = measured[index + 1]
            if next.segmentHeights == nil,
               measured[index].height + Self.blockSpacing + next.height > contentHeight {
                measured[index + 1] = try await segmentize(next, width: width, pacer: pacer)
            }
        }
        progress(ReportProgress(phase: .layout, completed: document.blocks.count, total: document.blocks.count))
        try Task.checkCancellation()

        let pages = try await Self.paginate(measured, pageHeight: contentHeight) { segment, space in
            try await splitHead(segment, maxHeight: space, width: width, pacer: pacer)
        }

        // Lượt 2: vẽ từng trang thẳng ra file.
        var mediaBox = CGRect(origin: .zero, size: geometry.pageSize)
        let info: [CFString: Any] = [
            kCGPDFContextTitle: document.metadata.title.precomposedStringWithCanonicalMapping,
            kCGPDFContextCreator: document.metadata.creator,
        ]
        guard let consumer = CGDataConsumer(url: url as CFURL),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, info as CFDictionary)
        else { throw ReportRenderError.cannotCreateContext }

        let contentClip = CGRect(
            x: geometry.margin - 4,
            y: geometry.pageSize.height - geometry.margin - contentHeight,
            width: width + 8,
            height: contentHeight + geometry.margin - 4
        )
        var pendingImages: Task<DecodedImages, Never>? = pages.first.map(Self.decodeImages(on:))
        for (pageIndex, placements) in pages.enumerated() {
            progress(ReportProgress(phase: .drawing, completed: pageIndex, total: pages.count))
            await Task.yield()
            if Task.isCancelled {
                pendingImages?.cancel()
                context.closePDF()
                try? FileManager.default.removeItem(at: url)
                throw CancellationError()
            }
            // Ảnh của trang này đã (đang) giải mã ngoài main actor; bắt đầu giải mã trang kế trong lúc vẽ.
            let images = await pendingImages?.value ?? DecodedImages(images: [:])
            pendingImages = pageIndex + 1 < pages.count ? Self.decodeImages(on: pages[pageIndex + 1]) : nil
            autoreleasepool {
                context.beginPDFPage(nil)
                // Lưới an toàn: không phần nào vẽ tràn xuống chân trang.
                context.saveGState()
                context.clip(to: contentClip)
                for (placementIndex, placement) in placements.enumerated() {
                    draw(
                        ReportChunkView(segments: placement.segments, images: images.images[placementIndex] ?? [:], width: width),
                        width: width,
                        top: geometry.margin + placement.y,
                        in: context
                    )
                }
                context.restoreGState()
                draw(
                    ReportFooterView(
                        footer: document.footer,
                        pageLabel: ReportStrings.page(pageIndex + 1, of: pages.count),
                        width: width
                    ),
                    width: width,
                    top: geometry.pageSize.height - geometry.margin - metrics.footerHeight,
                    in: context
                )
                context.endPDFPage()
            }
        }
        context.closePDF()
        progress(ReportProgress(phase: .drawing, completed: pages.count, total: pages.count))
        return ReportPDFFile(url: url, pageCount: pages.count)
    }

    // MARK: - Nhường lượt

    /// Nhường main actor khi đã chạy liền ≥ `interval`; kiểm huỷ mỗi lần nhường.
    @MainActor
    final class Pacer {
        private let clock = ContinuousClock()
        private let interval: Duration
        private var last: ContinuousClock.Instant

        init(interval: Duration) {
            self.interval = interval
            last = clock.now
        }

        var isDue: Bool { clock.now - last >= interval }

        func pause() async throws {
            await Task.yield()
            try Task.checkCancellation()
            last = clock.now
        }

        func pauseIfDue() async throws {
            if isDue { try await pause() }
        }
    }

    // MARK: - Đo

    struct MeasuredBlock {
        var segments: [ReportSegment]
        /// Chiều cao cả khối (các phần nối liền).
        var height: CGFloat
        /// Có khi khối được phép tách (cao hơn một trang, hoặc đi sau đề mục mà không vừa cùng trang): chiều cao từng
        /// phần (đoạn và lựa chọn quá cao đã tách theo từ).
        var segmentHeights: [CGFloat]?
        var continuation: ReportSegment?
        var continuationHeight: CGFloat
        var keepWithNext: Bool

        /// Chiều cao tối thiểu phải nằm cùng trang với đề mục đứng trước: cả khối nếu không tách được, nếu không thì
        /// hai phần đầu (khối tách được chỉ bắt đầu ở trang đang dở khi hai phần đầu vừa).
        func leadingHeight() -> CGFloat {
            guard let segmentHeights else { return height }
            // Đoạn chữ, lựa chọn tách được: chỉ cần chỗ cho phần đầu (khoảng hai dòng).
            return segmentHeights.prefix(2).enumerated().reduce(CGFloat(0)) { sum, item in
                let segment = segments[item.offset]
                let height = segment.isSplittable ? min(item.element, ReportRenderer.minimumSplitSpace) : item.element
                return sum + height + (item.offset == 0 ? 0 : segment.gapBefore)
            }
        }
    }

    /// Chiều cao vùng nội dung và chân trang của mỗi trang.
    func layoutMetrics(for footer: ReportFooter) -> (footerHeight: CGFloat, contentHeight: CGFloat) {
        let renderer = ImageRenderer(
            content: ReportFooterView(footer: footer, pageLabel: ReportStrings.page(999, of: 999), width: geometry.contentWidth)
                .interfaceLocale(locale)
        )
        renderer.proposedSize = ProposedViewSize(width: geometry.contentWidth, height: nil)
        var height: CGFloat = 0
        renderer.render { size, _ in height = size.height }
        let footerHeight = height.rounded(.up)
        return (footerHeight, geometry.pageSize.height - 2 * geometry.margin - footerHeight - Self.footerGap)
    }

    func measureHeight(_ segments: [ReportSegment], width: CGFloat) -> CGFloat {
        let renderer = ImageRenderer(content: ReportChunkView(segments: segments, images: [:], width: width).interfaceLocale(locale))
        renderer.proposedSize = ProposedViewSize(width: width, height: nil)
        var height: CGFloat = 0
        renderer.render { size, _ in height = size.height }
        return height.rounded(.up)
    }

    /// Đo từng phần của khối để xếp trang có thể tách giữa các phần. Đoạn chữ hay lựa chọn quá cao được tách tiếp lúc
    /// xếp trang (`splitHead`), vừa đúng chỗ còn lại của trang. Phần không tách được mà cao hơn một trang (không có
    /// trong đề hợp lệ) bị cắt ở mép vùng nội dung khi vẽ.
    func segmentize(_ block: MeasuredBlock, width: CGFloat, pacer: Pacer) async throws -> MeasuredBlock {
        var result = block
        result.continuationHeight = block.continuation.map { measureHeight([$0], width: width) } ?? 0
        var heights: [CGFloat] = []
        for segment in block.segments {
            try await pacer.pauseIfDue()
            heights.append(measureHeight([segment], width: width))
        }
        result.segmentHeights = heights
        return result
    }

    /// Một phần bị tách: phần đầu vừa chỗ còn lại, phần sau sang trang mới.
    struct SegmentSplit {
        var head: ReportSegment
        var headHeight: CGFloat
        var tail: ReportSegment
        var tailHeight: CGFloat
    }

    /// Tách đoạn chữ hoặc lựa chọn ở ranh giới từ xa nhất mà phần đầu cao không quá `maxHeight` (không cắt giữa một
    /// dòng); từ đầu dài hơn cả chỗ thì ngắt giữa ký tự. Lựa chọn: phần đầu giữ nhãn và dấu (Bạn chọn, Đáp án đúng),
    /// phần sau giữ nhãn kèm "(tiếp)". Nil khi phần này không tách được hoặc không chữ nào vừa.
    func splitHead(_ segment: ReportSegment, maxHeight: CGFloat, width: CGFloat, pacer: Pacer) async throws -> SegmentSplit? {
        let text: AttributedString
        let make: (AttributedString, Bool) -> ReportSegment
        switch segment {
        case let .text(value, boxed):
            text = value
            make = { piece, _ in .text(piece, boxed: boxed) }
        case let .option(label, value, marks, emphasized, continued):
            text = value
            make = { piece, isTail in
                .option(label: label, text: piece, marks: isTail ? [] : marks, emphasized: emphasized, continued: continued || isTail)
            }
        default:
            return nil
        }
        let characters = text.characters
        guard characters.count > 1 else { return nil }
        func fits(_ end: AttributedString.Index) -> Bool {
            measureHeight([make(AttributedString(text[text.startIndex ..< end]), false)], width: width) <= maxHeight
        }
        /// Điểm ngắt xa nhất trong `breaks` mà phần đầu vẫn vừa (tìm nhị phân).
        func farthestFitting(_ breaks: [AttributedString.Index]) async throws -> AttributedString.Index? {
            var low = 0
            var high = breaks.count - 1
            var best: AttributedString.Index?
            while low <= high {
                try await pacer.pauseIfDue()
                let mid = (low + high) / 2
                if fits(breaks[mid]) {
                    best = breaks[mid]
                    low = mid + 1
                } else {
                    high = mid - 1
                }
            }
            return best
        }
        var wordBreaks: [AttributedString.Index] = []
        var index = characters.startIndex
        while index != characters.endIndex {
            let next = characters.index(after: index)
            if characters[index].isWhitespace, next != characters.endIndex, !characters[next].isWhitespace {
                wordBreaks.append(next)
            }
            index = next
        }
        var cut = try await farthestFitting(wordBreaks)
        if cut == nil {
            cut = try await farthestFitting(Array(characters.indices.dropFirst()))
        }
        guard let end = cut else { return nil }
        let head = make(AttributedString(text[text.startIndex ..< end]), false)
        let tail = make(AttributedString(text[end ..< text.endIndex]), true)
        return SegmentSplit(
            head: head,
            headHeight: measureHeight([head], width: width),
            tail: tail,
            tailHeight: measureHeight([tail], width: width)
        )
    }

    // MARK: - Xếp trang

    struct Placement {
        var segments: [ReportSegment]
        /// Khoảng cách từ đỉnh vùng nội dung.
        var y: CGFloat
        var height: CGFloat
    }

    /// Tách một phần cho vừa chỗ còn lại (`splitHead`); nil thì không tách.
    typealias Splitter = (ReportSegment, CGFloat) async throws -> SegmentSplit?

    /// Chỗ tối thiểu (khoảng hai dòng) để bắt đầu phần đầu của một đoạn bị tách ở cuối trang.
    nonisolated static let minimumSplitSpace: CGFloat = 32

    /// Xếp tham lam: khối vừa chỗ còn lại thì đặt; vừa một trang thì sang trang mới; cao hơn một trang thì tách giữa
    /// các phần (đoạn chữ, lựa chọn quá cao thì tách tiếp cho vừa chỗ còn lại bằng `splitter`), mảnh sau mở bằng dòng
    /// "(tiếp)". Đề mục không đứng một mình cuối trang: khối sau nó, nếu không vừa chỗ còn lại, được tách để phần đầu
    /// đi cùng đề mục.
    static func paginate(
        _ blocks: [MeasuredBlock],
        pageHeight: CGFloat,
        splitter: Splitter? = nil
    ) async throws -> [[Placement]] {
        var pages: [[Placement]] = [[]]
        var y: CGFloat = 0
        // Khối vừa đặt cuối trang hiện tại là đề mục.
        var headingEndsPage = false

        func remaining() -> CGFloat {
            pageHeight - y - (pages[pages.count - 1].isEmpty ? 0 : blockSpacing)
        }
        func newPage() {
            if pages[pages.count - 1].isEmpty { return }
            pages.append([])
            y = 0
        }
        func place(_ segments: [ReportSegment], height: CGFloat) {
            if !pages[pages.count - 1].isEmpty { y += blockSpacing }
            pages[pages.count - 1].append(Placement(segments: segments, y: y, height: height))
            y += height
        }

        for (index, block) in blocks.enumerated() {
            let followsHeading = headingEndsPage
            headingEndsPage = false
            var needed = block.height
            if block.keepWithNext, index + 1 < blocks.count {
                let withNext = block.height + blockSpacing + blocks[index + 1].leadingHeight()
                if withNext <= pageHeight { needed = withNext }
            }
            if needed <= remaining() {
                place(block.segments, height: block.height)
                headingEndsPage = block.keepWithNext
                continue
            }
            // Không vừa chỗ còn lại: khối vừa một trang thì sang trang mới, trừ khi nó phải đi cùng đề mục ngay trước.
            guard let heights = block.segmentHeights, block.height > pageHeight || followsHeading else {
                newPage()
                place(block.segments, height: block.height)
                headingEndsPage = block.keepWithNext
                continue
            }

            // Tách: bắt đầu ở trang hiện tại nếu phần đầu vừa.
            if block.leadingHeight() > remaining() { newPage() }
            var queue = Array(zip(block.segments, heights))
            var position = 0
            var chunk: [ReportSegment] = []
            var chunkHeight: CGFloat = 0
            // Mảnh đang dựng có phần nội dung (không chỉ dòng "(tiếp)"); khối đã đặt ít nhất một mảnh.
            var chunkHasContent = false
            var placedAny = false
            var available = remaining()
            var chunkOnFreshPage = pages[pages.count - 1].isEmpty
            while position < queue.count {
                let (segment, height) = queue[position]
                let gap = chunk.isEmpty ? 0 : segment.gapBefore
                if chunkHeight + gap + height <= available {
                    chunk.append(segment)
                    chunkHeight += gap + height
                    chunkHasContent = true
                    position += 1
                    continue
                }
                let space = available - chunkHeight - gap
                if let splitter, space >= minimumSplitSpace, let split = try await splitter(segment, space) {
                    chunk.append(split.head)
                    chunkHeight += gap + split.headHeight
                    chunkHasContent = true
                    queue[position] = (split.tail, split.tailHeight)
                } else if !chunkHasContent, chunkOnFreshPage {
                    // Không tách được và cao hơn cả trang trống: đặt (phần thừa bị cắt ở mép vùng nội dung).
                    chunk.append(segment)
                    chunkHeight += gap + height
                    chunkHasContent = true
                    position += 1
                    continue
                }
                if chunkHasContent {
                    place(chunk, height: chunkHeight)
                    placedAny = true
                }
                newPage()
                available = pageHeight
                chunkOnFreshPage = true
                chunk = placedAny ? (block.continuation.map { [$0] } ?? []) : []
                chunkHeight = chunk.isEmpty ? 0 : block.continuationHeight
                chunkHasContent = false
            }
            if chunkHasContent { place(chunk, height: chunkHeight) }
        }
        return pages
    }

    // MARK: - Vẽ

    /// Ảnh đã giải mã của một trang: theo vị trí mảnh rồi vị trí phần trong mảnh.
    struct DecodedImages: @unchecked Sendable {
        // CGImage bất biến, an toàn khi chuyển giữa luồng.
        var images: [Int: [Int: CGImage]]
    }

    struct ImageRequest: Sendable {
        var placement: Int
        var segment: Int
        var data: Data
        var size: CGSize
    }

    /// Giải mã ảnh của trang ngoài main actor (`CGImageSource` an toàn đa luồng): `ImageRenderer` không chạy `.task` nên
    /// ảnh phải có sẵn trước khi vẽ, và ảnh rất lớn giải mã trên main actor sẽ chặn giao diện.
    static func decodeImages(on placements: [Placement]) -> Task<DecodedImages, Never> {
        var requests: [ImageRequest] = []
        for (placementIndex, placement) in placements.enumerated() {
            for (segmentIndex, segment) in placement.segments.enumerated() {
                if case let .image(data, size) = segment {
                    requests.append(ImageRequest(placement: placementIndex, segment: segmentIndex, data: data, size: size))
                }
            }
        }
        return Task.detached(priority: .userInitiated) {
            var result = DecodedImages(images: [:])
            for request in requests where !Task.isCancelled {
                if let image = ReportImages.decode(request.data, displaySize: request.size) {
                    result.images[request.placement, default: [:]][request.segment] = image
                }
            }
            return result
        }
    }

    /// Vẽ `view` với đỉnh cách mép trên trang `top` điểm, ở lề trái.
    private func draw(_ view: some View, width: CGFloat, top: CGFloat, in context: CGContext) {
        let renderer = ImageRenderer(content: view.interfaceLocale(locale))
        renderer.proposedSize = ProposedViewSize(width: width, height: nil)
        let pageHeight = geometry.pageSize.height
        let margin = geometry.margin
        renderer.render { size, draw in
            context.saveGState()
            context.translateBy(x: margin, y: pageHeight - top - size.height)
            draw(context)
            context.restoreGState()
        }
    }
}
