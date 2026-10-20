import Foundation

/// Đọc văn bản trong một khối RVF (RichView Format của TRichView) của file `.vce`.
///
/// Nguồn hiểu biết: đặc tả RVF công khai <https://trichview.com/help/rvf_specification.html> (dòng tiêu đề bản ghi
/// `<loại> <số dòng> <đoạn> <tuỳ chọn> <query> <tag> …` kết thúc CR LF, bản ghi `-8` phiên bản, `-9` thuộc tính tài
/// liệu, tuỳ chọn bit 3 = Unicode, query 0 = văn bản, 2 = nhị phân, 3 = Unicode dạng hex; ảnh lưu nhị phân là `i32`
/// độ dài + byte sau dòng tên lớp) và phân tích file mẫu tại máy (biến thể trong `.vce`: mỗi dòng văn bản Unicode là
/// UTF-16LE kết thúc bằng U+2029, không có CR LF).
///
/// Hỗ trợ: `-8`, `-9` (bỏ qua dữ liệu), mục văn bản query 0, Unicode hoặc ANSI; mục có kiểu chữ khác 0 giữ chữ dạng
/// thường, chỉ bỏ định dạng (`droppedFormatting`). Mọi bản ghi khác (ảnh, đường kẻ, hotspot, bullet, bảng, query khác
/// 0…) bị **bỏ qua và báo** trong `skipped`, không đoán nội dung. Bỏ qua theo số dòng của dòng tiêu đề (đặc tả); nếu sau đó không gặp dòng tiêu đề hợp lệ thì phần còn lại
/// của khối bị bỏ và cũng được báo.
enum RVFReader {
    struct Result: Equatable {
        /// Các đoạn văn bản theo thứ tự (chưa bỏ khoảng trắng, chưa sửa mojibake).
        var paragraphs: [String] = []
        /// Từng mục bị bỏ qua (có mã; `RVFSkip.logMessage` là câu tiếng Việt).
        var skipped: [RVFSkip] = []
        /// Có văn bản ANSI ngoài ASCII, đã đọc theo Windows-1252 (giả thuyết, cần kiểm lại).
        var assumedEncoding = false
        /// Có mục văn bản kiểu chữ khác 0: chữ được giữ dạng thường, định dạng bị bỏ.
        var droppedFormatting = false
    }

    /// Dòng tiêu đề dài hơn thế là dữ liệu lạ (tiêu đề thật chỉ vài số và một tag ngắn).
    static let maxHeaderLength = 4096
    /// Dấu kết thúc đoạn của văn bản Unicode trong `.vce` (U+2029 Paragraph Separator).
    static let paragraphSeparator: UInt16 = 0x2029

    static func read(_ block: ArraySlice<UInt8>) -> Result {
        var parser = Parser(block: block)
        parser.run()
        return parser.result
    }

    struct Parser {
        let block: ArraySlice<UInt8>
        var position: Int
        var result = Result()

        init(block: ArraySlice<UInt8>) {
            self.block = block
            position = block.startIndex
        }

        var end: Int { block.endIndex }

        mutating func run() {
            while position < end {
                guard let fields = header() else {
                    stop(.unknownData)
                    return
                }
                let type = fields[0]
                let count = fields.count > 1 ? fields[1] : 0
                guard count >= 0 else {
                    stop(.negativeLineCount)
                    return
                }
                switch type {
                case -8:
                    // Phiên bản RVF (`-8 1 3 1`): các số sau là phiên bản, không có dòng dữ liệu.
                    continue
                case -9:
                    // Thuộc tính tài liệu (`-9 0 0 0 0 0 7`): bỏ qua `count` dòng dữ liệu.
                    guard skipOrStop(count, .documentProperties) else { return }
                case 0...:
                    guard fields.count >= 5 else {
                        stop(.textMissingFields)
                        return
                    }
                    guard textItem(style: type, count: count, paragraph: fields[2], options: fields[3],
                                   query: fields[4])
                    else { return }
                default:
                    guard nonTextItem(type: type, count: count, query: fields.count >= 5 ? fields[4] : 0) else { return }
                }
            }
        }

        /// Ghi mục bỏ qua và dừng đọc khối (phần còn lại không đọc được một cách chắc chắn).
        mutating func stop(_ item: RVFSkip.Item, cause: RVFSkip.Cause = .none) {
            result.skipped.append(RVFSkip(item, cause: cause, stopped: true))
            position = end
        }

        // MARK: Mục văn bản

        /// `false` nếu đã dừng đọc khối.
        mutating func textItem(style: Int, count: Int, paragraph: Int, options: Int, query: Int) -> Bool {
            let unicode = options & 8 != 0
            guard query == 0 else {
                let what: RVFSkip.Item = query == 3 ? .hexUnicodeText : .unsupportedTextStorage(query: query)
                if query == 1 || query == 3 {
                    guard skipOrStop(count, what) else { return false }
                } else {
                    stop(what)
                    return false
                }
                result.skipped.append(RVFSkip(what))
                return true
            }
            // Kiểu chữ khác 0 (đậm, nghiêng, màu… theo bảng kiểu chữ chưa đọc được): giữ chữ dạng thường, chỉ bỏ định
            // dạng (Nt0 chốt 2026-10-16, import.md phương án 17).
            if style != 0, count > 0 { result.droppedFormatting = true }
            for index in 0 ..< count {
                guard position < end else {
                    stop(.textShorterThanDeclared)
                    return false
                }
                let line: String
                if unicode {
                    line = unicodeLine()
                } else {
                    let decoded = Windows1252.decode(ansiLine())
                    if decoded.usedNonASCII { result.assumedEncoding = true }
                    line = decoded.text
                }
                // Đặc tả RVF: đoạn −1 hoặc tuỳ chọn bit 0 = nối tiếp đoạn trước; bit 2 = xuống dòng trong cùng đoạn.
                if index == 0, !result.paragraphs.isEmpty, paragraph == -1 || options & 1 != 0 || options & 4 != 0 {
                    result.paragraphs[result.paragraphs.count - 1] += (options & 4 != 0 ? "\n" : "") + line
                } else {
                    result.paragraphs.append(line)
                }
            }
            return true
        }

        // MARK: Mục khác văn bản

        /// Ảnh, đường kẻ, hotspot, bullet, bảng…: bỏ qua theo đặc tả và báo. `false` nếu đã dừng đọc khối.
        mutating func nonTextItem(type: Int, count: Int, query: Int) -> Bool {
            let what = RVFSkip.Item.nonText(type: type)
            // Đặc tả RVF: ảnh có ít nhất 3 dòng (tên, lớp, dữ liệu), hotspot/bullet ít nhất 1 (tên). Ít hơn → bố cục lạ.
            guard count >= Self.minimumLines(type) else {
                stop(what, cause: .fewerLinesThanSpecification(count))
                return false
            }
            if query == 2 {
                // Lưu nhị phân: các dòng trước (tên, lớp) rồi `i32` độ dài + dữ liệu (đặc tả RVF, ảnh).
                guard count >= 1 else {
                    stop(what)
                    return false
                }
                guard skipOrStop(count - 1, what) else { return false }
                guard end - position >= 4 else {
                    stop(what)
                    return false
                }
                let size = VceByteReader.int32(Array(block[position ..< position + 4]), at: 0)
                guard size >= 0, size <= end - position - 4 else {
                    stop(what)
                    return false
                }
                position += 4 + size
                if end - position >= 2, block[position] == 0x0D, block[position + 1] == 0x0A { position += 2 }
            } else {
                guard skipOrStop(count, what) else { return false }
            }
            result.skipped.append(RVFSkip(what))
            return true
        }

        static func minimumLines(_ type: Int) -> Int {
            switch type {
            case -3: 3
            case -4, -6: 1
            default: 0
            }
        }

        // MARK: Dòng

        /// Dòng tiêu đề bản ghi: các số cách nhau bởi dấu cách, kết thúc CR LF. Chỉ cần 5 số đầu (loại, số dòng,
        /// đoạn, tuỳ chọn, query); phần sau (tag có thể là chuỗi trong ngoặc kép) bỏ qua. `nil` nếu không phải tiêu đề.
        mutating func header() -> [Int]? {
            let limit = min(end, position + maxHeaderLength)
            var index = position
            while index + 1 < limit, !(block[index] == 0x0D && block[index + 1] == 0x0A) {
                index += 1
            }
            guard index + 1 < limit else { return nil }
            let line = block[position ..< index]
            var fields: [Int] = []
            for token in line.split(separator: 0x20, omittingEmptySubsequences: true).prefix(5) {
                guard token.count <= 11, token.allSatisfy({ $0 == 0x2D || (0x30 ... 0x39).contains($0) }),
                      let value = Int(String(decoding: token, as: UTF8.self))
                else { return nil }
                fields.append(value)
            }
            guard !fields.isEmpty else { return nil }
            position = index + 2
            return fields
        }

        /// Dòng ANSI tới CR LF (hoặc hết khối).
        mutating func ansiLine() -> ArraySlice<UInt8> {
            let start = position
            while position < end {
                if block[position] == 0x0D, position + 1 < end, block[position + 1] == 0x0A {
                    defer { position += 2 }
                    return block[start ..< position]
                }
                position += 1
            }
            return block[start ..< end]
        }

        /// Dòng UTF-16LE tới U+2029 (hoặc hết khối; byte lẻ cuối bị bỏ). Cặp surrogate hỏng thành U+FFFD.
        mutating func unicodeLine() -> String {
            var units: [UInt16] = []
            while end - position >= 2 {
                let unit = UInt16(block[position]) | UInt16(block[position + 1]) << 8
                position += 2
                if unit == RVFReader.paragraphSeparator {
                    // Đặc tả RVF dùng CR LF giữa các dòng; các file mẫu `.vce` không có, nhưng phiên bản khác có thể có.
                    // Bỏ CR LF ngay sau U+2029 (nếu không sẽ đọc nhầm thành ký tự U+0A0D ở đầu đoạn sau).
                    if end - position >= 2, block[position] == 0x0D, block[position + 1] == 0x0A { position += 2 }
                    return String(decoding: units, as: UTF16.self)
                }
                units.append(unit)
            }
            position = end
            return String(decoding: units, as: UTF16.self)
        }

        enum SkipOutcome {
            case done
            /// Khối hết trước khi đủ số dòng.
            case ranOut
            /// Một dòng định bỏ qua lại là dòng tiêu đề bản ghi: số dòng khai báo lấn sang bản ghi sau.
            case crossedHeader
        }

        /// Bỏ `count` dòng kết thúc CR LF; dừng đọc khối (và báo) nếu khối hết trước hoặc số dòng lấn sang bản ghi sau,
        /// để không lặng lẽ nuốt mục chữ phía sau (review độc lập PR #38). `false` nếu đã dừng.
        mutating func skipOrStop(_ count: Int, _ what: RVFSkip.Item) -> Bool {
            switch skipLines(count) {
            case .done:
                return true
            case .ranOut:
                stop(what, cause: .blockEndedEarly)
            case .crossedHeader:
                stop(what, cause: .crossedNextRecord)
            }
            return false
        }

        /// Bỏ `count` dòng kết thúc CR LF (số dòng khai báo của bản ghi bị bỏ qua quyết định chỗ bản ghi kết thúc). Không
        /// bỏ dòng có đúng dạng tiêu đề của một bản ghi kế tiếp theo đặc tả (`isRecordHeader`): khi đó số dòng khai báo
        /// lấn sang bản ghi sau.
        mutating func skipLines(_ count: Int) -> SkipOutcome {
            var remaining = count
            while remaining > 0 {
                guard position < end else { return .ranOut }
                let start = position
                var lineEnd: Int?
                while position + 1 < end {
                    if block[position] == 0x0D, block[position + 1] == 0x0A {
                        lineEnd = position
                        position += 2
                        break
                    }
                    position += 1
                }
                guard let lineEnd else { return .ranOut }
                if Self.isRecordHeader(block[start ..< lineEnd]) {
                    position = start
                    return .crossedHeader
                }
                remaining -= 1
            }
            return .done
        }

        /// Dòng có đúng dạng tiêu đề của một bản ghi đứng sau bản ghi khác (đặc tả RVF): `<loại> <số dòng> <đoạn>
        /// <tuỳ chọn> <query> <tag> …`, tức ít nhất 6 trường; 5 trường đầu là số nguyên trong khoảng hợp lệ (loại ≥ -20,
        /// số dòng ≥ 0, đoạn ≥ -1, tuỳ chọn 0–65535, query 0–3); tag là số hoặc chuỗi trong ngoặc kép. Bản ghi `-8`
        /// (4 trường) chỉ đứng đầu khối nên không tính. Dòng dữ liệu chỉ gồm vài số (ví dụ `100 100 100 100` của `-9`,
        /// tên ảnh `1 2 3 4`) không khớp (re-review PR #38).
        static func isRecordHeader(_ line: ArraySlice<UInt8>) -> Bool {
            guard line.count <= RVFReader.maxHeaderLength else { return false }
            let tokens = line.split(separator: 0x20, omittingEmptySubsequences: true)
            guard tokens.count >= 6 else { return false }
            var numbers: [Int] = []
            for token in tokens.prefix(5) {
                let digits = token.first == 0x2D ? token.dropFirst() : token[...]
                guard !digits.isEmpty, digits.count <= 10, digits.allSatisfy({ (0x30 ... 0x39).contains($0) }),
                      let value = Int(String(decoding: token, as: UTF8.self))
                else { return false }
                numbers.append(value)
            }
            let tag = tokens[5]
            let tagIsNumber = tag.allSatisfy { $0 == 0x2D || (0x30 ... 0x39).contains($0) }
            return numbers[0] >= -20 && numbers[1] >= 0 && numbers[2] >= -1 && (0 ... 0xFFFF).contains(numbers[3])
                && (0 ... 3).contains(numbers[4]) && (tagIsNumber || tag.first == 0x22)
        }
    }
}
