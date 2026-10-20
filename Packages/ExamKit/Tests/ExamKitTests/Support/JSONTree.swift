import Foundation

/// Sửa cây JSON (từ `JSONSerialization`) theo đường dẫn, để dựng payload hỏng hoặc mâu thuẫn
/// từ một payload hợp lệ. Phần tử mảng chỉ bằng số thứ tự dạng chuỗi ("0", "1"…).
enum JSONTree {
    static func parse(_ data: Data) throws -> Any {
        try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    }

    static func data(_ tree: Any) throws -> Data {
        try JSONSerialization.data(withJSONObject: tree, options: [.fragmentsAllowed])
    }

    /// Gọi `change` trên giá trị ở `path` (giá trị thiếu là `NSNull`).
    static func modify(_ tree: inout Any, _ path: [String], _ change: (inout Any) -> Void) {
        modify(&tree, path[...], change)
    }

    private static func modify(_ value: inout Any, _ path: ArraySlice<String>, _ change: (inout Any) -> Void) {
        guard let key = path.first else {
            change(&value)
            return
        }
        if var object = value as? [String: Any] {
            var child: Any = object[key] ?? NSNull()
            modify(&child, path.dropFirst(), change)
            object[key] = child
            value = object
        } else if var array = value as? [Any], let index = Int(key), array.indices.contains(index) {
            var child = array[index]
            modify(&child, path.dropFirst(), change)
            array[index] = child
            value = array
        } else {
            preconditionFailure("Đường dẫn \(path) không có trong cây JSON")
        }
    }

    /// Đặt giá trị ở `path`.
    static func set(_ tree: inout Any, _ path: [String], _ newValue: Any) {
        modify(&tree, path) { $0 = newValue }
    }

    /// Bỏ khoá cuối của `path` khỏi object chứa nó.
    static func remove(_ tree: inout Any, _ path: [String]) {
        modify(&tree, Array(path.dropLast())) { parent in
            guard var object = parent as? [String: Any] else { preconditionFailure("Không phải object") }
            object[path.last!] = nil
            parent = object
        }
    }
}
