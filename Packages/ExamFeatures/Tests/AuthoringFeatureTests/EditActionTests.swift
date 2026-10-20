import Foundation
@testable import AuthoringFeature
@testable import LibraryFeature
import Testing

/// Thao tác sửa đề (`EditAction`): tên bước Hoàn tác và tiêu đề hộp báo khi lỗi theo catalog của AuthoringFeature.
@Suite("Tên bước Hoàn tác và tiêu đề hộp báo của soạn đề")
struct EditActionTests {
    /// Tiêu đề hộp báo khi thao tác sửa đề lỗi (review độc lập #52 N1): tiếng Việt không đổi ("Không" + tên bước Hoàn
    /// tác viết thường + "được"), tiếng Anh là câu trọn vẹn của từng thao tác.
    @Test func editActionFailureTitles() {
        for action in EditAction.allCases {
            #expect(action.failureTitle == "Không \(action.undoName.lowercased()) được", "\(action)")
        }
        let english = InterfaceStrings.$languageOverride.withValue(Locale(identifier: "en")) {
            EditAction.allCases.map { ($0.undoName, $0.failureTitle) }
        }
        #expect(english.first { $0.0 == "Assign New ID" }?.1 == "Couldn’t assign a new ID")
        #expect(english.first { $0.0 == "Change Hide Answers" }?.1 == "Couldn’t change Hide Answers")
        #expect(english.allSatisfy { $0.1.hasPrefix("Couldn’t ") && !$0.1.contains("Không") })
    }
}
