import Foundation

/// So sánh ngữ nghĩa hai cây JSON từ `JSONSerialization`. Viết tay vì
/// `NSDictionary.isEqual` trên Linux (swift-corelibs-foundation) không so được
/// Bool/Int/Double do bridging khác macOS.
enum JSONCompare {
    static func equal(_ a: Any, _ b: Any) -> Bool {
        switch (a, b) {
        case let (x as [String: Any], y as [String: Any]):
            return x.keys.sorted() == y.keys.sorted() && x.allSatisfy { k, v in y[k].map { equal(v, $0) } ?? false }
        case let (x as [Any], y as [Any]):
            return x.count == y.count && zip(x, y).allSatisfy { equal($0, $1) }
        case let (x as String, y as String):
            return x == y
        case let (x as Bool, y as Bool):
            return x == y
        case let (x as Int, y as Int):
            return x == y
        case let (x as Double, y as Double):
            return x == y
        case let (x as NSNumber, y as NSNumber):
            return x == y
        case (is NSNull, is NSNull):
            return true
        default:
            return false
        }
    }
}
