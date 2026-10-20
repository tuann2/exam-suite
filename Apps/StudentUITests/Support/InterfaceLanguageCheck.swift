import XCTest

/// Kiểm giao diện không còn chữ tiếng Việt khi app chạy tiếng Anh (giai đoạn 5 bước 7c; accessibility-localization.md,
/// mục Kiểm: "không có chữ tiếng Việt của giao diện ở các màn đi qua"). Nội dung đề mẫu "Làm quen" là tiếng Việt và
/// không dịch (phương án 3), nên không quét mọi chữ có dấu. Hai cách bù nhau:
///
/// 1. **Phần tử chỉ có chữ giao diện** (nút, bộ đếm, đồng hồ, nhóm lựa chọn…; định danh khớp **đúng nguyên văn**): mọi
///    chữ của phần tử và cây con không có chữ cái ngoài ASCII (dấu câu như ’ … · không tính). Không đưa vào danh sách
///    phần tử nằm trong phần tử gộp (`accessibilityElement(children: .combine)`) có nội dung đề: phần tử gộp nhận định
///    danh của con và nhãn của cả nhóm (đầu câu "Luyện tập và Thi, Question 1 of 12", đầu câu của Xem lại bài), nên
///    `question.position`, `answerReview.status` không có ở đây (review độc lập #52 S1). Khớp nguyên văn cũng bỏ qua
///    phần tử gộp có định danh ghép ("a-b").
/// 2. **Chữ giao diện tiếng Việt đã biết** của các màn trong luồng 1: không phần tử nào (cả thanh menu) có nhãn, tiêu đề
///    hay giá trị đúng bằng một chữ trong danh sách, hoặc bắt đầu bằng một tiền tố có số ("Câu ", "Đã làm "…). Bỏ qua cây
///    con của lựa chọn (`option.*`): vài lựa chọn của đề mẫu trùng chữ giao diện ("Luyện tập", "Thi", "Làm lại").
@MainActor
struct InterfaceLanguageCheck {
    let app: XCUIApplication

    /// Định danh của phần tử chỉ mang chữ giao diện (không có nội dung đề).
    static let interfaceOnlyIdentifiers = [
        "preExam.start", "preExam.cancel", "preExam.mode", "preExam.summary", "preExam.shuffleQuestions",
        "preExam.shuffleOptions",
        "attempt.check", "attempt.flag", "attempt.pause", "attempt.previous", "attempt.next", "attempt.review",
        "attempt.progress", "attempt.clock", "attempt.toggleNavigator", "check.result", "navigator.progress",
        "review.submit", "review.back", "review.answered", "review.unanswered", "review.flagged",
        "submit.confirm", "submit.cancel",
        "results.verdict", "results.score", "results.info", "results.library", "results.retake", "results.review",
        "results.exportPDF", "results.print",
        "answerReview.position", "answerReview.previous", "answerReview.next",
        "answerReview.results", "answerReview.filter",
    ]

    /// Chữ giao diện tiếng Việt của các màn trong luồng 1 (Thư viện, Trước khi thi, làm bài, Rà soát & nộp, hộp xác
    /// nhận nộp, Kết quả, Xem lại bài, menu Bài thi). Chỉ so bằng nguyên chữ.
    static let knownVietnamese: Set<String> = [
        "Thư viện", "Tất cả đề", "Gần đây", "Lịch sử thi", "Thêm đề", "Thêm đề…", "Tìm theo tên hoặc mã đề", "Sắp xếp",
        "Lọc", "Lưới", "Danh sách", "Chế độ xem", "Sẵn sàng", "Đề mẫu", "Chưa thi lần nào", "Lưới đề", "Thao tác khác",
        "Chào mừng bạn đến với Exam Suite", "Đã hiểu", "Đóng thông báo",
        "Bắt đầu", "Huỷ", "Tên thí sinh", "Chế độ", "Luyện tập", "Thi", "Câu hỏi", "Chọn câu", "Tất cả câu", "Theo phần",
        "N câu ngẫu nhiên", "Xáo thứ tự câu", "Xáo thứ tự đáp án", "Thời gian", "phút", "Mã đề",
        "Nhập tên thí sinh để bắt đầu.",
        "Kiểm tra đáp án", "Đánh dấu", "Bỏ đánh dấu", "Tạm dừng", "Tiếp tục", "Câu trước", "Câu sau", "Câu tiếp theo",
        "Rà soát & nộp", "Bảng câu hỏi", "Ẩn bảng câu hỏi", "Hiện bảng câu hỏi", "Đã làm", "Chưa làm", "Đang xem",
        "Đang xem: viền đậm", "Đúng", "Chưa đúng", "Giải thích", "Đã chọn", "Chưa chọn", "Đã kiểm tra", "Bài thi",
        "Các lựa chọn, chọn một đáp án", "Các lựa chọn, chọn nhiều đáp án",
        "Nộp bài", "Nộp bài…", "Quay lại làm bài", "Câu chưa làm", "Câu đã đánh dấu", "Không có câu đánh dấu.", "Quay lại",
        "Kết quả", "Đậu", "Trượt", "Xem lại bài", "Làm lại", "Về thư viện", "Xem câu sai", "Luyện lại câu sai",
        "Thí sinh", "Nộp lúc", "Thời gian làm", "Số câu đúng", "Xuất PDF…", "In…", "Phần yếu nhất",
        "Bộ lọc", "Tất cả", "Sai", "Bạn chọn", "Đáp án đúng", "Các câu của bài", "Về màn Kết quả",
    ]

    /// Tiền tố tiếng Việt của chữ giao diện có số ("Câu 3/12", "Đã làm 1/12", "Còn 11 câu chưa làm…").
    static let knownVietnamesePrefixes = ["Câu ", "Đã làm ", "Còn ", "Thời gian ", "Kết quả: "]

    /// Không còn chữ giao diện tiếng Việt trên màn `screen` (cửa sổ, sheet, thanh menu).
    func expectNoVietnamese(on screen: String, file: StaticString = #filePath, line: UInt = #line) {
        guard let root = try? app.snapshot() else {
            XCTFail("Không chụp được cây trợ năng của \(screen)", file: file, line: line)
            return
        }
        var problems: [String] = []
        visit(root, insideInterfaceOnly: false, problems: &problems)
        XCTAssertTrue(problems.isEmpty, "\(screen) còn chữ tiếng Việt của giao diện:\n" + problems.joined(separator: "\n"),
                      file: file, line: line)
    }

    /// Có phần tử mang đúng chữ `text` (nhãn, tiêu đề hoặc giá trị).
    func expectText(_ text: String, within timeout: TimeInterval = 5, file: StaticString = #filePath, line: UInt = #line) {
        let match = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@ OR title == %@ OR value == %@", text, text, text)).firstMatch
        XCTAssertTrue(match.waitForExistence(timeout: timeout), "Không thấy “\(text)”", file: file, line: line)
    }

    /// Mở menu `title` trên thanh menu, kiểm có các mục `items` và mọi mục không có chữ cái ngoài ASCII, rồi đóng menu.
    /// Cần chuột (mở menu bằng bàn phím cần Điều hướng bàn phím của macOS, xem StudentFlow).
    func expectMenu(_ title: String, items: [String], file: StaticString = #filePath, line: UInt = #line) {
        let bar = app.menuBars.menuBarItems[title].firstMatch
        XCTAssertTrue(bar.waitForExistence(timeout: 5), "Không có menu “\(title)”", file: file, line: line)
        bar.click()
        for item in items {
            XCTAssertTrue(bar.menuItems[item].firstMatch.waitForExistence(timeout: 5),
                          "Menu “\(title)” không có mục “\(item)”", file: file, line: line)
        }
        let titles = bar.menuItems.allElementsBoundByIndex.map(\.title)
        let vietnamese = titles.filter(Self.hasNonASCIILetter)
        XCTAssertTrue(vietnamese.isEmpty, "Menu “\(title)” có mục tiếng Việt: \(vietnamese)", file: file, line: line)
        app.press(.escape)
    }

    private func visit(_ node: XCUIElementSnapshot, insideInterfaceOnly: Bool, problems: inout [String]) {
        let identifier = node.identifier
        if identifier.hasPrefix("option.") { return }
        let interfaceOnly = insideInterfaceOnly || Self.interfaceOnlyIdentifiers.contains(identifier)
        let texts = [node.label, node.title, node.value as? String ?? "", node.placeholderValue ?? ""]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        for text in texts {
            let place = "  - \(node.elementType.rawValue) [\(identifier)]: “\(text)”"
            if Self.knownVietnamese.contains(text) || Self.knownVietnamesePrefixes.contains(where: { text.hasPrefix($0) }) {
                problems.append(place + " (chữ giao diện tiếng Việt)")
            } else if interfaceOnly && Self.hasNonASCIILetter(text) {
                problems.append(place + " (phần tử chỉ có chữ giao diện mà có chữ cái ngoài ASCII)")
            }
        }
        for child in node.children {
            visit(child, insideInterfaceOnly: interfaceOnly, problems: &problems)
        }
    }

    static func hasNonASCIILetter(_ text: String) -> Bool {
        text.unicodeScalars.contains { $0.properties.isAlphabetic && !$0.isASCII }
    }
}
