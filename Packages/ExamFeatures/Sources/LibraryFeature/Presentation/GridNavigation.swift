import CoreGraphics

/// Điều hướng lưới thẻ bằng phím mũi tên (docs/product/library.md, mục Bàn phím và trợ năng).
public enum GridNavigation {
    public enum Direction: Hashable, Sendable {
        case up
        case down
        case left
        case right
    }

    /// Vị trí thẻ được chọn sau khi bấm phím mũi tên trong lưới `columns` cột có `count` thẻ.
    ///
    /// - Chưa chọn thẻ nào: phím nào cũng chọn thẻ đầu.
    /// - Trái/phải đi theo thứ tự đọc (sang dòng trước/sau), dừng ở thẻ đầu/cuối.
    /// - Lên/xuống đi cùng cột; xuống từ dòng có ô bên dưới trống (dòng cuối chưa đủ thẻ) thì tới thẻ cuối.
    /// - Returns: `nil` khi lưới rỗng.
    public static func move(from index: Int?, direction: Direction, count: Int, columns: Int) -> Int? {
        guard count > 0 else { return nil }
        guard let index, (0 ..< count).contains(index) else { return 0 }
        let columns = max(1, columns)
        switch direction {
        case .left:
            return max(0, index - 1)
        case .right:
            return min(count - 1, index + 1)
        case .up:
            return index - columns >= 0 ? index - columns : index
        case .down:
            if index + columns < count { return index + columns }
            let lastRow = (count - 1) / columns
            return index / columns < lastRow ? count - 1 : index
        }
    }

    /// Số cột vừa với `width` khi mỗi thẻ rộng tối thiểu `minItemWidth`, cách nhau `spacing`.
    public static func columns(forWidth width: CGFloat, minItemWidth: CGFloat, spacing: CGFloat) -> Int {
        guard width > 0, minItemWidth > 0 else { return 1 }
        return max(1, Int((width + spacing) / (minItemWidth + spacing)))
    }
}
