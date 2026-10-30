import Foundation
import SwiftData

/// Repository trên SwiftData, dùng `mainContext` của container (cùng main actor với `LibraryStore`).
/// Mỗi lệnh ghi lưu ngay; lỗi lưu thì huỷ thay đổi đang chờ để context không ở trạng thái dở dang.
@MainActor
final class SwiftDataLibraryRepository: LibraryRepository {
    let container: ModelContainer
    private let context: ModelContext

    init(container: ModelContainer) {
        self.container = container
        context = container.mainContext
        // Lưu tường minh sau mỗi lệnh để lỗi lưu hiện ra ngay tại lệnh gây ra nó.
        context.autosaveEnabled = false
    }

    func fetchEntries() throws -> [LibraryRecord] {
        let descriptor = FetchDescriptor<LibraryItem>(sortBy: [SortDescriptor(\.addedAt)])
        return try context.fetch(descriptor).map(\.record)
    }

    func saveEntries(_ records: [LibraryRecord]) throws {
        guard !records.isEmpty else { return }
        try commit {
            for record in records {
                if let item = try item(examID: record.examID) {
                    item.update(from: record)
                } else {
                    context.insert(LibraryItem(record: record))
                }
            }
        }
    }

    func deleteEntry(examID: UUID) throws {
        try commit {
            if let item = try item(examID: examID) { context.delete(item) }
        }
    }

    func fetchAttempts() throws -> [Attempt] {
        let descriptor = FetchDescriptor<AttemptItem>(
            sortBy: [SortDescriptor(\.submittedAt, order: .reverse), SortDescriptor(\.startedAt, order: .reverse)]
        )
        // Sắp lại bằng cùng thứ tự với bản trong bộ nhớ (kể cả khi bằng nhau về thời gian).
        return try context.fetch(descriptor).map(\.attempt).sorted(by: Attempt.newestFirst)
    }

    func insertAttempt(_ attempt: Attempt, payload: Data) throws {
        try commit {
            context.insert(AttemptItem(attempt: attempt, payload: payload))
        }
    }

    func attemptPayload(id: UUID) throws -> Data? {
        var descriptor = FetchDescriptor<AttemptItem>(predicate: #Predicate { $0.attemptID == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first?.payload
    }

    // MARK: - Nội bộ

    private func item(examID: UUID) throws -> LibraryItem? {
        var descriptor = FetchDescriptor<LibraryItem>(predicate: #Predicate { $0.examID == examID })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func commit(_ changes: () throws -> Void) throws {
        do {
            try changes()
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
