import Foundation
@testable import ExamKit

/// `fixtures/vectors/composer.json`: vector cố định của SplitMix64, `nextInt(below:)` và chọn câu, dùng chung với
/// lõi Kotlin của bản Android (android/core). Đọc hỏng thì trả rỗng để test `vectorFileLoaded` báo đỏ.
enum ComposerVectors {
    struct File: Decodable {
        let splitmix64: [Sequence]
        let nextInt: [NextInt]
        let compositions: [Composition]
    }

    struct Sequence: Decodable {
        let seed: String
        let next: [String]
    }

    struct NextInt: Decodable {
        let seed: String
        let bound: String
        let values: [String]
    }

    struct Composition: Decodable {
        let name: String
        let exam: String
        let options: CompositionOptionsJSON
        let questionIDs: [String]
        let optionOrders: [String]
        let sectionIDs: [String]?
    }

    struct CompositionOptionsJSON: Decodable {
        struct Selection: Decodable {
            let kind: String
            let count: Int?
        }

        let selection: Selection
        let shuffleQuestions: Bool
        let shuffleOptions: Bool
        let seed: String

        var options: CompositionOptions {
            let selection: QuestionSelection = switch self.selection.kind {
            case "random": .random(count: self.selection.count ?? 0)
            default: .all
            }
            return CompositionOptions(selection: selection, shuffleQuestions: shuffleQuestions,
                                      shuffleOptions: shuffleOptions, seed: hex(seed))
        }
    }

    static let file: File? = {
        guard let data = try? Data(contentsOf: Fixtures.root.appendingPathComponent("vectors/composer.json")) else {
            return nil
        }
        return try? JSONDecoder().decode(File.self, from: data)
    }()

    /// `"0x…"` → UInt64.
    static func hex(_ text: String) -> UInt64 {
        UInt64(text.dropFirst(2), radix: 16) ?? .max
    }
}
