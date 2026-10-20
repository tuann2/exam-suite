import Foundation
import Testing
import ZIPFoundation
@testable import ExamFile
import ExamKit

@Suite("ExamFile format constants and zip dependency")
struct ExamFileFormatTests {
    @Test("Hằng số định dạng khớp schema v1")
    func constantsMatchSchema() {
        #expect(ExamFileFormat.currentVersion == 1)
        #expect(ExamFileFormat.currentVersion == Exam.currentFormatVersion)
        #expect(ExamFileFormat.fileExtension == "exam")
        #expect(ExamFileFormat.manifestName == "exam.json")
        #expect(ExamFileFormat.mediaDirectory == "media")
    }

    @Test("ZIPFoundation tạo và đọc lại được gói trong bộ nhớ")
    func zipRoundTrip() throws {
        let archive = try Archive(data: Data(), accessMode: .create)
        let payload = Data(#"{"formatVersion":1}"#.utf8)
        try archive.addEntry(
            with: ExamFileFormat.manifestName,
            type: .file,
            uncompressedSize: Int64(payload.count),
            provider: { position, size in
                payload.subdata(in: Int(position) ..< Int(position) + size)
            }
        )
        let bytes = try #require(archive.data)
        let reopened = try Archive(data: bytes, accessMode: .read)
        let entry = try #require(reopened[ExamFileFormat.manifestName])
        var out = Data()
        _ = try reopened.extract(entry) { out.append($0) }
        #expect(out == payload)
    }
}
