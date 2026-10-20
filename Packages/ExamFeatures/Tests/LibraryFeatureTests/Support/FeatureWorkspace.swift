import ExamFile
import ExamKit
import Foundation
import LibraryData
@testable import LibraryFeature

/// Thư mục tạm riêng của một test (đường dẫn thật, đã giải `/var` → `/private/var`), xoá khi test xong.
/// Kho thư viện trong bộ nhớ, UserDefaults là file trong thư mục tạm: không test nào ghi vào
/// ~/Library thật.
final class FeatureWorkspace {
    let root: URL
    let defaults: UserDefaults

    init() throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("LibraryFeatureTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        root = Self.realPath(base)
        defaults = UserDefaults(suiteName: root.appendingPathComponent("defaults.plist").path)!
    }

    deinit {
        try? FileManager.default.removeItem(at: root)
    }

    static func realPath(_ url: URL) -> URL {
        let resolved = url.withUnsafeFileSystemRepresentation { path -> String? in
            guard let path, let real = realpath(path, nil) else { return nil }
            defer { free(real) }
            return String(cString: real)
        }
        return resolved.map { URL(fileURLWithPath: $0, isDirectory: true) } ?? url
    }

    func url(_ relativePath: String) -> URL {
        root.appendingPathComponent(relativePath, isDirectory: false)
    }

    func configuration(admin: Bool = false, samples: URL? = nil) -> LibraryConfiguration {
        LibraryConfiguration(
            readMode: admin ? .lenient : .strict,
            isAdmin: admin,
            storeURL: url("AppSupport/Library.store"),
            samplesDirectoryURL: root.appendingPathComponent("AppSupport/Samples", isDirectory: true),
            samplesSourceURL: samples,
            checkFingerprint: "feature-test"
        )
    }

    /// Model test: kho trong bộ nhớ, không tự `start()`, **Hiện trong Finder** ghi vào `revealed`.
    @MainActor
    func makeModel(
        admin: Bool = false,
        samples: URL? = nil,
        revealed: RevealRecorder = RevealRecorder(),
        now: @escaping () -> Date = { Date() }
    ) -> LibraryModel {
        let store = LibraryStore.inMemory(configuration: configuration(admin: admin, samples: samples), defaults: defaults)
        return LibraryModel(
            store: store,
            startsAutomatically: false,
            revealFiles: { revealed.urls.append(contentsOf: $0) },
            now: now
        )
    }

    /// Ghi đề thành gói `.exam` bằng `ExamPackageWriter` (như app).
    @discardableResult
    func write(_ exam: Exam, to relativePath: String) throws -> URL {
        let url = url(relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try ExamPackageWriter.write(ExamPackage(exam: exam), to: url)
        return url
    }

    /// File có đuôi bất kỳ với nội dung không phải zip.
    @discardableResult
    func writeGarbage(to relativePath: String) throws -> URL {
        let url = url(relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("đây không phải gói đề".utf8).write(to: url)
        return url
    }
}

/// Ghi lại các file được yêu cầu hiện trong Finder.
@MainActor
final class RevealRecorder {
    var urls: [URL] = []
}

/// Đề hợp lệ dựng bằng code, `questions` câu một đáp án.
func makeExam(id: UUID = UUID(), title: String, code: String? = nil, questions: Int = 2) -> Exam {
    Exam(
        id: id,
        title: title,
        code: code,
        passPercent: 60,
        timeLimitMinutes: 20,
        sections: [
            ExamSection(
                title: "Phần 1",
                questions: (0 ..< questions).map { index in
                    Question(
                        type: .single,
                        text: "Câu \(index + 1): \(index) + 1 bằng bao nhiêu?",
                        options: (0 ..< 4).map { option in
                            Option(id: OptionID(index: option)!, text: "Phương án \(option + 1): \(index + option)")
                        },
                        correct: [OptionID(index: 1)!],
                        explanation: "Vì \(index) + 1 = \(index + 1)."
                    )
                }
            ),
        ]
    )
}

/// Lần thi dựng sẵn cho Lịch sử thi.
func makeAttempt(
    examID: UUID,
    title: String,
    candidate: String = "Nguyễn Văn An",
    submittedAt: Date,
    percent: Int = 80
) -> Attempt {
    Attempt(
        examID: examID,
        examTitle: title,
        candidateName: candidate,
        mode: .exam,
        startedAt: submittedAt.addingTimeInterval(-600),
        submittedAt: submittedAt,
        elapsedSeconds: 600,
        correct: percent / 10,
        total: 10,
        score1000: percent * 10,
        percent: percent,
        passed: percent >= 60
    )
}

/// So hai đường dẫn file theo file thật (thiết bị + inode), không theo chuỗi.
func sameFile(_ lhs: URL, _ rhs: URL) -> Bool {
    func identity(_ url: URL) -> [Int]? {
        var info = stat()
        guard stat(url.path, &info) == 0 else { return nil }
        return [Int(info.st_dev), Int(info.st_ino)]
    }
    guard let left = identity(lhs) else { return false }
    return left == identity(rhs)
}
