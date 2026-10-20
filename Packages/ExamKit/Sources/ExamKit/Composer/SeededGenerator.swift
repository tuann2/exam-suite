import Foundation

/// Bộ sinh số giả ngẫu nhiên có seed, thuật toán SplitMix64 (Steele, Lea, Flood 2014;
/// bản tham chiếu `splitmix64.c` của Sebastiano Vigna), tự cài đặt.
///
/// Không dùng `SystemRandomNumberGenerator` hay `Int.random(in:using:)` /
/// `shuffled(using:)` của thư viện chuẩn: thuật toán bên trong chúng không được
/// cam kết giữ nguyên giữa các phiên bản Swift và nền tảng. Mọi phép xáo của
/// `ExamComposer` chỉ dùng `next()` và `nextInt(below:)` dưới đây, nên cùng seed
/// cho cùng kết quả trên macOS, Linux và mọi phiên bản Swift
/// (docs/product/scoring.md, mục "Chọn câu cho một phiên").
public struct SeededGenerator: RandomNumberGenerator, Sendable {
    /// Hằng số cộng mỗi bước (2^64 / φ, "golden gamma").
    static let gamma: UInt64 = 0x9E37_79B9_7F4A_7C15
    static let mix1: UInt64 = 0xBF58_476D_1CE4_E5B9
    static let mix2: UInt64 = 0x94D0_49BB_1331_11EB

    private var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    /// Giá trị 64 bit tiếp theo. Mọi phép cộng/nhân đều tràn số theo modulo 2^64.
    public mutating func next() -> UInt64 {
        state &+= Self.gamma
        var z = state
        z = (z ^ (z >> 30)) &* Self.mix1
        z = (z ^ (z >> 27)) &* Self.mix2
        return z ^ (z >> 31)
    }

    /// Số nguyên phân phối đều trong `0..<upperBound`, không lệch.
    ///
    /// Thuật toán (rejection sampling): `threshold = 2^64 mod upperBound`; lấy
    /// `r = next()`, nếu `r < threshold` thì bỏ và lấy tiếp, ngược lại trả
    /// `r % upperBound`. Các giá trị `r ≥ threshold` gồm đúng một số nguyên lần
    /// trọn `upperBound` giá trị, nên mọi số dư có xác suất bằng nhau. Mỗi lần gọi
    /// tiêu thụ ít nhất một `next()`; số lần bỏ phụ thuộc giá trị nhưng xác định theo seed.
    ///
    /// - Precondition: `upperBound > 0`.
    public mutating func nextInt(below upperBound: Int) -> Int {
        precondition(upperBound > 0, "upperBound phải > 0")
        let bound = UInt64(upperBound)
        // (2^64 - bound) mod bound == 2^64 mod bound, tính được trong UInt64.
        let threshold = (0 &- bound) % bound
        while true {
            let r = next()
            if r >= threshold {
                return Int(r % bound)
            }
        }
    }

    /// Fisher–Yates (biến thể Durstenfeld) tại chỗ: `i` chạy từ `count - 1` xuống 1,
    /// mỗi bước lấy `j = nextInt(below: i + 1)` rồi đổi chỗ phần tử `i` và `j`.
    /// Mảng 0 hoặc 1 phần tử không tiêu thụ số ngẫu nhiên nào.
    mutating func shuffle<T>(_ items: inout [T]) {
        guard items.count > 1 else { return }
        for i in stride(from: items.count - 1, to: 0, by: -1) {
            let j = nextInt(below: i + 1)
            if i != j { items.swapAt(i, j) }
        }
    }
}
