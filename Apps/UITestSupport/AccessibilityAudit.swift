import XCTest

/// Kiểm trợ năng tự động của macOS (`XCUIApplication.performAccessibilityAudit`; docs/product/accessibility-localization.md,
/// phương án 7): một lần ở mỗi màn mà luồng UI test đi qua. Vấn đề nào cũng làm test thất bại, trừ ngoại lệ ghi ở đây
/// (`Exception`: loại kiểm, phần tử, lý do).
///
/// - **Loại kiểm chạy** (`macOSAuditTypes`, mọi loại SDK macOS có): `contrast`, `elementDetection`, `hitRegion`,
///   `sufficientElementDescription`, `action`, `parentChild`. **Bỏ, vì không có trên macOS** (SDK chỉ khai báo cho iOS,
///   tvOS, watchOS): `dynamicType`, `textClipped`, `trait`. Chữ bị cắt và cỡ chữ lớn kiểm bằng snapshot test (960×640, cỡ
///   chữ nội dung 150%) và test tay.
/// - Kiểm chạy trên **mọi cửa sổ** của app (cửa sổ phía sau, cửa sổ có sheet đang mở cũng được kiểm).
/// - Không dừng luồng ở màn đầu có vấn đề: gom mọi vấn đề của mọi màn rồi báo **một lần khi test kết thúc** (khối dọn dẹp
///   của test, vẫn làm test thất bại), để một lần chạy `verify_local.sh --uitest` cho thấy đủ danh sách. Vấn đề trùng (cùng
///   loại, phần tử, mô tả) chỉ báo một lần.
///
/// **Ngoại lệ** (`commonExceptions`, lần chạy đầu `verify_local.sh --uitest` trên 6c59532 và các lần chạy riêng sau đó): chỉ
/// ba loại, mỗi cái khớp đúng phần tử (định danh, chữ, loại, khung), không bỏ cả một loại kiểm:
/// (a) chữ màu ngữ nghĩa của hệ thống (`.secondary`, chữ vibrant của thanh bên/inspector, tiêu đề cửa sổ) và chữ ở cửa sổ
/// không phải cửa sổ đang dùng (macOS vẽ mờ đi): Nt0 chốt 2026-10-18, màu hệ thống được miễn quy tắc tương phản của app;
/// (b) phần tử do macOS sở hữu (thanh menu, nút đóng/thu nhỏ/phóng to của cửa sổ, khung chứa của split view/inspector/sheet,
/// nút menu của thanh công cụ); (c) báo nhầm có bằng chứng (nội dung đề có chữ "nút" bị coi là lặp vai trò; khung giải
/// thích có test tương phản số).
@MainActor
final class AccessibilityAuditor {
    /// Thuộc tính của phần tử bị báo, đọc một lần (phần tử có thể đã biến mất: dải tự ẩn).
    struct IssueInfo {
        let auditType: XCUIAccessibilityAuditType
        let compact: String
        let detailed: String
        let hasElement: Bool
        let exists: Bool
        let elementType: XCUIElement.ElementType
        let identifier: String
        let label: String
        let value: String
        let frame: CGRect
        /// Nhóm không tên có ô tìm kiếm bên trong (khung của `.searchable`).
        let containsSearchField: Bool

        /// Chữ mà kiểm `contrast` đo ("Contrast failed for <chữ>", "…not high enough for <chữ> unless…").
        var measuredText: String {
            guard let range = detailed.range(of: " for ") else { return "" }
            var text = String(detailed[range.upperBound...])
            if let unless = text.range(of: " unless font size is larger") { text = String(text[..<unless.lowerBound]) }
            return text
        }

        var isAnonymous: Bool { exists && identifier.isEmpty && label.isEmpty && value.isEmpty }
    }

    /// Bối cảnh của một lần kiểm: khung của cửa sổ đang dùng (sheet nếu có, không thì cửa sổ trước nhất).
    struct Context {
        let activeFrame: CGRect
        /// Sheet đang mở, không thì cửa sổ trước nhất.
        let activeRoot: XCUIElement?
        /// Đang có sheet (Trước khi thi, hộp chọn In) hoặc cửa sổ hộp thoại riêng (Import đề).
        let modalOpen: Bool
    }

    /// Một ngoại lệ đã xem xét: vấn đề `type` ở phần tử khớp `matches` không làm test thất bại, vì `reason`.
    struct Exception {
        let type: XCUIAccessibilityAuditType
        /// Phần tử (để đọc trong test và log).
        let element: String
        let reason: String
        let matches: @MainActor (IssueInfo, Context) -> Bool
    }

    /// Mọi loại kiểm có trên macOS.
    static let macOSAuditTypes: XCUIAccessibilityAuditType = [
        .contrast, .elementDetection, .hitRegion, .sufficientElementDescription, .action, .parentChild,
    ]

    /// Loại kiểm chỉ có trên iOS/tvOS/watchOS, không chạy được trên macOS (ghi ở accessibility-localization.md).
    static let unavailableOnMacOS = ["dynamicType", "textClipped", "trait"]

    /// Chữ màu `.secondary` (hoặc chữ vibrant) của hệ thống mà kiểm `contrast` báo, theo chữ đo được. Chữ có màu của bảng
    /// màu app không ở đây (test tương phản số: `PaletteContrastTests`).
    static let systemSecondaryTexts: [(pattern: String, element: String)] = [
        (#"^Mã đề: "#, "dòng mã đề của Trước khi thi (.secondary)"),
        (#"^Không có câu đánh dấu\.$|^Không còn câu chưa làm\.$"#, "danh sách trống của Rà soát (.secondary)"),
        (#"^\d+ đề$|^\d+ lần thi$"#, "phụ đề của cửa sổ Thư viện (chữ của thanh tiêu đề)"),
        (#"^Tất cả đề$|^Gần đây$|^Lịch sử thi$"#, "mục thanh bên / tiêu đề cửa sổ Thư viện (chữ vibrant của hệ thống)"),
        (#"^Không có tiêu đề$|^Untitled$"#, "tiêu đề cửa sổ soạn đề chưa lưu (chữ của thanh tiêu đề)"),
        (#"^png, jpg, gif, webp, heic"#, "gợi ý định dạng ảnh của trình soạn câu (.secondary)"),
        (#"^Khoá Luyện tập; khi xem lại bài"#, "mô tả của công tắc Ẩn đáp án (chữ phụ của Toggle, hệ thống)"),
        (#"^= \d+/1000$"#, "thang 1000 cạnh ô ngưỡng đậu (.secondary)"),
        (#"^Đề mở trong cửa sổ soạn đề chưa lưu"#, "chú thích của hộp xác nhận Import đề (.secondary)"),
        (#"^Câu \d+, (Đúng|Sai|Chưa làm)"#, "dòng danh sách câu của Xem lại bài: đoạn đầu nội dung .secondary trong thanh bên"),
    ]

    /// Chữ màu hệ thống (`.primary`, chữ của thanh tiêu đề) ở cửa sổ **không phải cửa sổ đang dùng** mà kiểm `contrast` báo
    /// (macOS vẽ mờ cửa sổ không hoạt động); cùng chữ đó đạt khi cửa sổ của nó ở trước. Chữ màu của bảng màu không ở đây.
    static let inactiveWindowTexts: [(pattern: String, element: String)] = [
        (#"^Thư viện có sẵn đề mẫu để bạn làm quen"#, "chữ của dải chào mừng (.primary) khi Thư viện ở sau"),
        (#"^Đã thêm đề "#, "thông báo ở chân Thư viện (.primary trên vật liệu) khi Thư viện ở sau"),
        (#" — (Luyện tập|Thi)$"#, "tiêu đề cửa sổ làm bài khi sheet đang mở"),
        (#"^Loại câu$"#, "nhãn ô Loại câu của trình soạn khi cửa sổ soạn đề ở sau"),
    ]

    /// Tiêu đề cửa sổ trên thanh công cụ (chữ của thanh tiêu đề, khung cao ~52 pt của vùng tiêu đề).
    static func isWindowTitle(_ info: IssueInfo) -> Bool {
        info.elementType == .staticText && (48 ... 56).contains(info.frame.height)
    }

    /// Số đếm `.secondary` nhỏ: mục thanh bên Thư viện (nhãn là tên mục) và số câu của phần trên cây đề (chữ ≤ 24 pt rộng).
    static func isSidebarCount(_ info: IssueInfo) -> Bool {
        guard info.measuredText.range(of: #"^\d+$"#, options: .regularExpression) != nil else { return false }
        return ["Tất cả đề", "Gần đây", "Lịch sử thi"].contains(info.label) || (info.frame.width <= 24 && info.frame.height <= 20)
    }

    /// Định danh của phần tử chữ `.secondary` mà kiểm `contrast` báo.
    static let systemSecondaryIdentifiers: [String: String] = [
        "results.info": "nhãn của dòng thông tin Kết quả (Thí sinh, Mã đề…: .secondary)",
        "attempt.progress": "tiến độ \"Đã làm N/M\" ở thanh dưới (.secondary)",
        "navigator.progress": "chú thích của bảng câu hỏi trong inspector (.secondary, chữ vibrant)",
        "answerReview.position": "\"Câu N/M\" ở thanh dưới của Xem lại bài (.secondary)",
        "import.confirm.summary": "tóm tắt của hộp xác nhận Import đề (.secondary)",
    ]

    /// Mô tả chi tiết của vấn đề `parentChild` không chỉ ra phần tử mà các lần chạy `verify_local.sh --uitest` gặp.
    static let knownParentChildDetail = "This element is not an accessibility child of the parent element."

    static let commonExceptions: [Exception] = [
        // (a) Màu hệ thống.
        Exception(
            type: .contrast, element: "chữ .secondary/vibrant đã biết (systemSecondaryTexts, systemSecondaryIdentifiers)",
            reason: "màu ngữ nghĩa của hệ thống, được miễn quy tắc tương phản của app (Nt0 chốt 2026-10-18)"
        ) { info, _ in
            if systemSecondaryIdentifiers[info.identifier] != nil || isSidebarCount(info) { return true }
            // Dòng câu của cây đề: số thứ tự và biểu tượng ảnh/nhiều đáp án là .secondary (chữ vibrant của thanh bên).
            if info.identifier.hasPrefix("authoring.tree.question.") { return true }
            let text = info.measuredText
            return systemSecondaryTexts.contains { text.range(of: $0.pattern, options: .regularExpression) != nil }
        },
        Exception(
            type: .contrast,
            element: "chữ màu hệ thống đã biết (inactiveWindowTexts, chữ .secondary ở trên, dòng Theo phần, chữ của cửa sổ soạn đề) ở cửa sổ không phải cửa sổ đang dùng",
            reason: "macOS vẽ mờ cửa sổ không hoạt động (màu hệ thống theo trạng thái cửa sổ); chính các chữ này đạt ở màn của chúng"
        ) { info, context in
            // Chỉ chữ màu hệ thống: màu của bảng màu không bị vẽ mờ theo trạng thái cửa sổ (re-review #54).
            guard isOutsideActiveWindow(info, context) else { return false }
            let text = info.measuredText
            return info.identifier == "results.sections" || info.identifier.hasPrefix("authoring.") || isWindowTitle(info)
                || inactiveWindowTexts.contains { text.range(of: $0.pattern, options: .regularExpression) != nil }
        },
        // (b) Phần tử của macOS.
        Exception(
            type: [.sufficientElementDescription, .action], element: "thanh menu của macOS (khung ở mép trên màn hình)",
            reason: "phần tử của thanh menu hệ thống (menu nhập liệu, biểu tượng & ký hiệu…), không phải của app"
        ) { info, _ in
            info.exists && info.frame.minY <= 0 && info.frame.height <= 34
        },
        Exception(
            type: .sufficientElementDescription,
            element: "khung chứa không tên của split view, inspector, gốc cửa sổ (nhóm lớn hơn 200×500 pt) và của sheet đang mở (cùng khung)",
            reason: "SwiftUI/AppKit tạo nhóm chứa cho cột của NavigationSplitView, .inspector, sheet; app không gắn nhãn được"
        ) { info, context in
            guard info.isAnonymous, info.elementType == .group else { return false }
            if info.frame.width >= 200 && info.frame.height >= 500 { return true }
            // Nhóm chứa nội dung của chính sheet đang mở (cùng khung với sheet, ví dụ hộp chọn In… 440×204).
            let sheet = context.activeFrame
            return context.modalOpen && abs(info.frame.minX - sheet.minX) <= 2 && abs(info.frame.maxX - sheet.maxX) <= 2
                && abs(info.frame.maxY - sheet.maxY) <= 2
        },
        Exception(
            type: .sufficientElementDescription,
            element: "nhãn trợ giúp (tooltip, loại helpTag) không tên mà macOS hiện khi con trỏ chuột dừng trên một điều khiển",
            reason: "macOS vẽ tooltip từ .help của điều khiển, có hay không tuỳ vị trí con trỏ lúc kiểm (cổng G3 2026-10-19: "
                + "tooltip 172×18 pt ở thanh công cụ Thư viện, lần chạy lại không có); điều khiển bên dưới có nhãn riêng"
        ) { info, _ in
            info.isAnonymous && info.elementType == .helpTag
        },
        Exception(
            type: .sufficientElementDescription, element: "nhóm không tên chứa ô tìm kiếm (thanh tìm của cây đề, .searchable)",
            reason: "khung của ô tìm kiếm do SwiftUI .searchable tạo; ô tìm kiếm bên trong có nhãn (prompt)"
        ) { info, _ in
            info.containsSearchField
        },
        Exception(
            type: .parentChild, element: "nhóm 14×14 pt ở thanh tiêu đề (nút đóng/thu nhỏ/phóng to của cửa sổ)",
            reason: "nút của cửa sổ do AppKit vẽ; quan hệ cha/con trong cây trợ năng là của AppKit"
        ) { info, _ in
            info.isAnonymous && info.frame.width <= 16 && info.frame.height <= 16
        },
        Exception(
            type: .action, element: "nút menu Sắp xếp, Lọc trên thanh công cụ Thư viện (nhãn Sắp xếp: …, Lọc: …)",
            reason: "Menu của SwiftUI trên thanh công cụ: AppKit chỉ có hành động mở menu (AXShowMenu), kiểm báo thiếu AXPress; bấm và VoiceOver mở menu bình thường"
        ) { info, _ in
            info.elementType == .menuButton && (info.label.hasPrefix("Sắp xếp: ") || info.label.hasPrefix("Lọc: "))
        },
        Exception(
            type: .parentChild, element: "không có phần tử (kiểm không chỉ ra được phần tử), mô tả chi tiết đã biết",
            reason: "cùng màn, lần chạy khác chỉ ra nhóm 14×14 nút của cửa sổ (ngoại lệ trên) hay cửa sổ sheet của AppKit; không có phần tử của app để sửa"
        ) { info, _ in
            // Chỉ đúng vấn đề đã biết (mô tả chi tiết của XCTest), không mọi vấn đề cha/con không có phần tử (review #54).
            !info.hasElement && info.detailed == knownParentChildDetail
        },
        // (c) Báo nhầm.
        Exception(
            type: .sufficientElementDescription, element: "lựa chọn của câu (option.*) có nội dung chứa chữ \"nút\"",
            reason: "nhãn là nội dung đề (\"…có nút Kiểm tra đáp án\"), kiểm coi chữ \"nút\" là lặp vai trò button"
        ) { info, _ in
            info.compact.contains("duplicates role") && info.identifier.hasPrefix("option.") && info.label.contains("nút")
        },
        Exception(
            type: .contrast, element: "khung giải thích (nhãn gộp \"Giải thích, …\")",
            reason: "chữ .primary trên nền trung tính của app: PaletteContrastTests.neutralFillsKeepTextReadable tính ≥ 4,5:1 (khoảng 14:1); kiểm đo phần tử gộp nhiều dòng"
        ) { info, _ in
            info.measuredText.hasPrefix("Giải thích, ")
        },
    ]

    private let app: XCUIApplication
    private var problems: [String] = []
    private var seen: Set<String> = []

    /// Gắn với `testCase`: khi test kết thúc, mọi vấn đề đã gom làm test thất bại (một lần, đủ danh sách).
    init(app: XCUIApplication, testCase: XCTestCase) {
        self.app = app
        testCase.addTeardownBlock { @MainActor [self] in
            reportProblems()
        }
    }

    /// Kiểm màn đang hiện (`screen`: tên màn trong log). `exceptions`: ngoại lệ riêng của màn này.
    func audit(_ screen: String, exceptions: [Exception] = [], file: StaticString = #filePath, line: UInt = #line) {
        XCTContext.runActivity(named: "Kiểm trợ năng: \(screen)") { _ in
            let allowed = Self.commonExceptions + exceptions
            let context = Context(activeFrame: activeFrame(), activeRoot: activeRoot(), modalOpen: app.sheets.firstMatch.exists || app.dialogs.firstMatch.exists
                || app.windows["authoring.import"].exists)
            do {
                try app.performAccessibilityAudit(for: Self.macOSAuditTypes) { [self] issue in
                    let info = Self.info(issue)
                    let description = Self.describe(info)
                    if let exception = allowed.first(where: { $0.type.contains(issue.auditType) && $0.matches(info, context) }) {
                        XCTContext.runActivity(named: "Ngoại lệ (\(exception.element)): \(exception.reason) — \(description)") { _ in }
                        return true
                    }
                    if seen.insert(description).inserted {
                        problems.append("[\(screen)] \(description)")
                        XCTContext.runActivity(named: "VẤN ĐỀ TRỢ NĂNG [\(screen)] \(description)") { _ in }
                    }
                    // Đã ghi lại; test thất bại khi kết thúc (`reportProblems`), luồng đi tiếp để thấy đủ các màn.
                    return true
                }
            } catch {
                problems.append("[\(screen)] không chạy được kiểm trợ năng: \(error)")
            }
        }
    }

    private func activeRoot() -> XCUIElement? {
        let sheet = app.sheets.firstMatch
        if sheet.exists { return sheet }
        let window = app.windows.firstMatch
        return window.exists ? window : nil
    }

    /// Phần tử (theo khung, rồi theo giá trị hoặc nhãn) không nằm trong cửa sổ đang dùng.
    static func isOutsideActiveWindow(_ info: IssueInfo, _ context: Context) -> Bool {
        guard info.exists, let root = context.activeRoot else { return false }
        if !context.activeFrame.isEmpty, !context.activeFrame.insetBy(dx: -1, dy: -1).contains(info.frame) { return true }
        let text = info.value.isEmpty ? info.label : info.value
        guard !text.isEmpty else { return false }
        return !root.descendants(matching: .any)
            .matching(NSPredicate(format: "value == %@ OR label == %@", text, text)).firstMatch.exists
    }

    /// Khung của cửa sổ đang dùng: sheet đang mở, không thì cửa sổ trước nhất.
    private func activeFrame() -> CGRect {
        let sheet = app.sheets.firstMatch
        if sheet.exists { return sheet.frame }
        let window = app.windows.firstMatch
        return window.exists ? window.frame : .zero
    }

    private func reportProblems() {
        guard !problems.isEmpty else { return }
        XCTFail("""
            Kiểm trợ năng (performAccessibilityAudit) có \(problems.count) vấn đề; sửa app, hoặc ghi ngoại lệ (loại kiểm, \
            phần tử, lý do; Apps/UITestSupport/AccessibilityAudit.swift):
            \(problems.joined(separator: "\n"))
            """)
    }

    static func info(_ issue: XCUIAccessibilityAuditIssue) -> IssueInfo {
        let target = issue.element
        // Đọc thuộc tính của phần tử không còn làm XCTest báo lỗi cứng: kiểm `exists` trước.
        let exists = target?.exists ?? false
        return IssueInfo(
            auditType: issue.auditType,
            compact: issue.compactDescription,
            detailed: issue.detailedDescription,
            hasElement: target != nil,
            exists: exists,
            elementType: exists ? target!.elementType : .any,
            identifier: exists ? target!.identifier : "",
            label: exists ? target!.label : "",
            value: exists ? target!.stringValue : "",
            frame: exists ? target!.frame : .zero,
            containsSearchField: exists && target!.elementType == .group && target!.identifier.isEmpty
                && target!.label.isEmpty && target!.searchFields.firstMatch.exists
        )
    }

    /// Một dòng: loại kiểm, mô tả ngắn, phần tử (loại, định danh, nhãn, giá trị, khung), mô tả chi tiết.
    static func describe(_ info: IssueInfo) -> String {
        let element: String
        if !info.hasElement {
            element = "không có phần tử"
        } else if !info.exists {
            element = "phần tử không còn trên màn hình"
        } else {
            element = "loại \(info.elementType.rawValue) id='\(info.identifier)' nhãn='\(info.label)' giá trị='\(info.value)' "
                + "khung=\(info.frame.integral)"
        }
        return "\(typeName(info.auditType)): \(info.compact) — \(element) — \(info.detailed)"
    }

    static func typeName(_ type: XCUIAccessibilityAuditType) -> String {
        let names: [(XCUIAccessibilityAuditType, String)] = [
            (.contrast, "contrast"), (.elementDetection, "elementDetection"), (.hitRegion, "hitRegion"),
            (.sufficientElementDescription, "sufficientElementDescription"), (.action, "action"),
            (.parentChild, "parentChild"),
        ]
        return names.first { type.contains($0.0) }?.1 ?? "loại \(type.rawValue)"
    }
}
