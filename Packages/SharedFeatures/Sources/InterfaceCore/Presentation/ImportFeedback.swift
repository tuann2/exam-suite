import Foundation
import LibraryData

/// Một file không thêm được, để báo gọn ở cuối lần thêm (docs/product/library.md, mục Thêm đề).
public struct ImportProblem: Identifiable, Hashable, Sendable {
    /// Vị trí của file trong lần thêm (một file có thể được đưa vào hai lần).
    public let position: Int
    public let url: URL
    /// Lý do, chữ của catalog (`ErrorMessages`).
    public let reason: String
    /// Người dùng nên làm gì tiếp (docs/product/library.md, "Phương án chờ Nt0 chốt" mục 2).
    public let nextStep: String

    public var id: Int { position }
    public var fileName: String { url.lastPathComponent }

    public init(position: Int, url: URL, reason: String, nextStep: String) {
        self.position = position
        self.url = url
        self.reason = reason
        self.nextStep = nextStep
    }

    /// Bước tiếp theo theo loại vấn đề của file.
    public static func nextStep(for problem: LibraryFileProblem) -> String {
        switch problem {
        case .corrupt:
            localized("Kiểm tra lại file hoặc xin người soạn đề gửi lại file khác.")
        case .needsNewerApp:
            localized("Cập nhật Exam Suite lên bản mới hơn rồi thêm lại.")
        case .invalid:
            localized("Báo người soạn đề sửa đề bằng bản Admin rồi gửi lại.")
        }
    }
}

/// Gộp `ImportReport` thành những gì giao diện làm sau một lần thêm đề: chọn đề, thông báo không chặn,
/// hỏi "Dùng file mới" cho từng file trùng id, rồi báo gọn các file không thêm được.
public struct ImportFeedback: Hashable, Sendable {
    /// Đề được chọn sau khi thêm (đề cuối cùng vừa thêm hoặc đã có).
    public var examIDToSelect: UUID?
    /// "Đã thêm 2 đề.", "Đề đã có trong thư viện: “…”."…; `nil` nếu không thêm hay chọn được đề nào.
    public var notice: String?
    /// File cùng id với đề đã có nhưng khác file: hỏi lần lượt.
    public var replacements: [PendingReplacement]
    /// File không thêm được (hỏng, có lỗi, cần app mới hơn, không phải `.exam`).
    public var problems: [ImportProblem]

    /// - Parameter titles: tiêu đề hiện tại của các đề trong thư viện, theo id đề.
    public init(report: ImportReport, titles: [UUID: String]) {
        examIDToSelect = report.examIDToSelect
        replacements = report.pendingReplacements
        problems = report.items.enumerated().compactMap { position, item in
            switch item.outcome {
            case .rejected(let problem):
                ImportProblem(
                    position: position,
                    url: item.url,
                    reason: ErrorMessages.message(for: problem),
                    nextStep: ImportProblem.nextStep(for: problem)
                )
            case .skippedNotExam:
                ImportProblem(
                    position: position,
                    url: item.url,
                    reason: localized("Không phải file đề .exam."),
                    nextStep: localized("Chỉ thêm được file đề có đuôi .exam.")
                )
            case .added, .alreadyInLibrary, .needsReplaceConfirmation:
                nil
            }
        }
        let added = Self.unique(report.addedExamIDs)
        let existing = Self.unique(report.alreadyInLibraryExamIDs).filter { !added.contains($0) }
        notice = Self.notice(added: added, existing: existing, titles: titles)
    }

    static func unique(_ ids: [UUID]) -> [UUID] {
        var seen = Set<UUID>()
        return ids.filter { seen.insert($0).inserted }
    }

    static func notice(added: [UUID], existing: [UUID], titles: [UUID: String]) -> String? {
        var sentences: [String] = []
        if added.count == 1, let title = titles[added[0]] {
            sentences.append(localized("Đã thêm đề “\(title)”."))
        } else if !added.isEmpty {
            sentences.append(localized("Đã thêm \(added.count) đề."))
        }
        if existing.count == 1, let title = titles[existing[0]] {
            sentences.append(localized("Đề đã có trong thư viện: “\(title)”."))
        } else if !existing.isEmpty {
            sentences.append(localized("\(existing.count) đề đã có trong thư viện."))
        }
        return sentences.isEmpty ? nil : sentences.joined(separator: " ")
    }
}
