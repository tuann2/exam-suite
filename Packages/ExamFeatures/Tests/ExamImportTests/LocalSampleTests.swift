import ExamFile
@testable import ExamImport
import ExamKit
import Foundation
import Testing

/// Thử bộ chuyển đổi trên file thật tại máy (import.md, Kiểm chứng): chỉ chạy khi có biến môi trường
/// `EXAMIMPORT_SAMPLES` trỏ tới thư mục chứa file `.txt`/`.docx`/`.vce` (ví dụ `docs/archive/`, không vào git).
/// Chỉ in số liệu (số phần, câu, câu bỏ, cảnh báo theo loại, lỗi kiểm tra theo mã), không in nội dung câu hỏi.
@Suite("File thật tại máy (EXAMIMPORT_SAMPLES)")
struct LocalSampleTests {
    static var directory: URL? {
        ProcessInfo.processInfo.environment["EXAMIMPORT_SAMPLES"].map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    @Test("Số liệu import", .enabled(if: directory != nil))
    func statistics() async throws {
        let directory = try #require(Self.directory)
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { ImportSourceFormat(fileExtension: $0.pathExtension) != nil }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        for url in files {
            let result = try await ExamImporter.importFile(at: url)
            let package = result.makePackage(ImportConfirmation(
                title: result.suggestions.title,
                code: result.suggestions.code,
                passPercent: result.suggestions.passPercent ?? 70,
                timeLimitMinutes: result.suggestions.timeLimitMinutes ?? 60
            ))
            let reread = try ExamPackageReader.read(ExamPackageWriter.write(package), mode: .lenient)
            #expect(reread.exam == package.exam)

            var lines = ["== \(url.pathExtension) (\(url.lastPathComponent.count) ký tự tên file)"]
            lines.append("phần: \(result.sections.count), câu: \(result.questionCount) "
                + "(theo phần: \(result.sections.map { "\($0.questions.count)" }.joined(separator: ", ")))")
            lines.append("bỏ: \(result.report.droppedCount), cảnh báo: \(result.report.warningCount)")
            let byCode = Dictionary(grouping: result.report.entries, by: \.code)
            for (code, entries) in byCode.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
                let places = entries.map(\.location.logDescription).joined(separator: "; ")
                lines.append("  \(code.rawValue): \(entries.count) [\(places)]")
            }
            let s = result.suggestions
            lines.append("gợi ý: mã \(s.code ?? "-"), ngưỡng \(s.passPercent.map(String.init) ?? "-"), "
                + "thời gian \(s.timeLimitMinutes.map(String.init) ?? "-"), tiêu đề \(s.title.count) ký tự")
            let all = result.sections.flatMap(\.questions)
            lines.append("loại: single \(all.filter { $0.type == .single }.count), multiple "
                + "\(all.filter { $0.type == .multiple }.count); có giải thích \(all.filter { $0.explanation != nil }.count); "
                + "có ảnh \(all.filter { $0.image != nil }.count)")
            let issues = package.validationIssues
            let issueCounts = Dictionary(grouping: issues, by: \.code).map { "\($0.key.rawValue)=\($0.value.count)" }
            lines.append("lỗi kiểm tra của đề (với ngưỡng/thời gian giả định): \(issueCounts.sorted().joined(separator: ", "))")
            if ProcessInfo.processInfo.environment["EXAMIMPORT_VERBOSE"] != nil {
                // Chỉ cấu trúc: số lựa chọn, đáp án, phần, độ dài chữ.
                for section in result.sections {
                    for q in section.questions {
                        lines.append("  [\(section.title.count)] opts=\(q.options.count) ans=\(q.correct.map(\.description).joined()) "
                            + "text=\(q.text.count) optLen=\(q.options.map { "\($0.text.count)" }.joined(separator: "/")) "
                            + "exp=\(q.explanation?.count ?? 0) nl=\(q.text.filter { $0 == "\n" }.count) "
                            + "leak=\(([q.text, q.explanation ?? ""] + q.options.map(\.text)).filter { $0.contains("Correct Answer") || $0.contains("Section:") || $0.contains("Explanation") || $0.contains("QUESTION") }.count) "
                            + "esc=\(([q.text, q.explanation ?? ""] + q.options.map(\.text)).filter { $0.contains("\\") }.count)")
                    }
                }
            }
            print(lines.joined(separator: "\n"))
        }
    }
}
