import Testing
@testable import ExamKit

@Suite("ExamKit smoke")
struct ExamKitInfoTests {
    @Test("Phiên bản module là semver hợp lệ")
    func versionIsSemver() {
        let parts = ExamKitInfo.version.split(separator: ".")
        #expect(parts.count == 3)
        #expect(parts.allSatisfy { Int($0) != nil })
    }
}
