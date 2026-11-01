import ExamFile
import Foundation

/// Đề mẫu (docs/product/library.md, mục Đề mẫu và lần đầu mở app).
extension LibraryStore {
    /// Lần đầu mở app (chưa từng tạo đề mẫu): ghi các đề mẫu trong `configuration.samplesSourceURL`
    /// ra `configuration.samplesDirectoryURL` (tên file theo tiêu đề) và thêm vào thư viện với cờ đề mẫu.
    /// Đã tạo rồi thì không làm gì, kể cả khi người dùng đã xoá đề mẫu khỏi thư viện.
    ///
    /// Cờ "đã tạo đề mẫu" chỉ bật khi mọi đề mẫu đều ổn (thêm được hoặc đã có), để lần mở sau thử lại
    /// đề mẫu lỗi. Nguồn không có đề mẫu nào: không làm gì, không bật cờ, không lỗi.
    @discardableResult
    public func seedSamplesIfNeeded() async -> SampleReport {
        guard !hasSeededSamples else { return SampleReport() }
        return await installSamples(rewriteMissingFiles: false)
    }

    /// **Khôi phục đề mẫu** (menu Trợ giúp): thêm lại đề mẫu không còn trong thư viện (ghi lại file),
    /// ghi lại file cho mục đề mẫu bị mất file; mục đang có file thì giữ nguyên, không tạo mục trùng.
    @discardableResult
    public func restoreSamples() async -> SampleReport {
        await installSamples(rewriteMissingFiles: true)
    }

    private func installSamples(rewriteMissingFiles: Bool) async -> SampleReport {
        var report = SampleReport()
        guard let source = configuration.samplesSourceURL else { return report }
        let request = ExamFileInspector.SampleRequest(
            sourceRoot: source,
            destinationDirectory: configuration.samplesDirectoryURL,
            existing: records.mapValues(\.location),
            rewriteMissingFiles: rewriteMissingFiles
        )
        let inspector = inspector
        let outcomes = await Self.offMain { inspector.installSamples(request) }
        report.sampleCount = outcomes.count
        var changed: [UUID] = []
        for outcome in outcomes {
            switch outcome {
            case let .alreadyInLibrary(examID):
                report.keptExamIDs.append(examID)
            case let .failed(sampleName, reason):
                report.failures.append(.init(sampleName: sampleName, reason: reason))
            case let .written(file, replacesExistingEntry):
                if configuration.readMode == .strict, case let .failsStrict(reason) = file.verdict {
                    // Đề mẫu phải đọc nghiêm được (docs/product/library.md); lỗi ở đây là lỗi nội dung đề mẫu.
                    report.failures.append(.init(sampleName: file.url.lastPathComponent, reason: reason))
                    continue
                }
                let status = file.verdict.status(for: configuration.readMode)
                if var existing = records[file.examID] {
                    // Chỉ ghi đè mục đã có khi khôi phục file bị mất; mục được thêm trong lúc chờ thì giữ.
                    guard replacesExistingEntry else {
                        report.keptExamIDs.append(file.examID)
                        continue
                    }
                    existing.adopt(file, fingerprint: configuration.checkFingerprint, checkedAt: now())
                    existing.isSample = true
                    replaceRecord(existing, status: status)
                } else {
                    let record = LibraryRecord(
                        file: file,
                        isSample: true,
                        addedAt: now(),
                        fingerprint: configuration.checkFingerprint
                    )
                    replaceRecord(record, status: status)
                }
                changed.append(file.examID)
                report.addedExamIDs.append(file.examID)
            }
        }
        let saved = persist(changed, while: "save samples")
        if report.sampleCount > 0, report.failures.isEmpty, saved {
            defaults.set(true, forKey: Self.samplesSeededKey)
        }
        return report
    }
}
