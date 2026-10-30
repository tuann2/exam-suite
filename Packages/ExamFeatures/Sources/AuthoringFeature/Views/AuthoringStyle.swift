import AppKit
import ExamKit
import InterfaceCore
import LibraryFeature
import SwiftUI

/// Màu và kích thước của cửa sổ soạn đề (docs/product/authoring.md, mục Cửa sổ).
enum AuthoringStyle {
    /// Burgundy cho chữ, biểu tượng, viền trên nền; cũng là `tint` của cửa sổ soạn đề.
    static let accentForeground = AuthoringPalette.accentForeground.color(name: "AuthoringAccentForeground")
    /// Burgundy làm nền có chữ trắng: nền dòng đang chọn của cây đề (`#801638` ở cả hai giao diện; `accentForeground`
    /// tối `#F7A1B8` với chữ trắng chỉ ~1,9:1).
    static let accentFill = AuthoringPalette.accentFill.color(name: "AuthoringAccentFill")
    static let critical = LibraryPalette.critical.color(name: "AuthoringCritical")
    static let warning = LibraryPalette.warning.color(name: "AuthoringWarning")

    static let minWindowSize = CGSize(width: 960, height: 640)

    /// Độ rộng một cột của cửa sổ soạn đề.
    struct ColumnWidth: Sendable {
        let min: CGFloat
        let ideal: CGFloat
        let max: CGFloat
    }

    // Bố cục ba cột (UI test PR #42: dòng Đề của cây đề ở x = −16,5, cột cây đề bị đẩy ra ngoài mép trái). Đo trên
    // macOS 26 (WindowLayoutTests): split view của SwiftUI lấy độ rộng tối thiểu của nó là độ rộng tối thiểu khai báo của
    // cột giữa CỘNG độ rộng hiện tại của các cột phủ lên nó (nội dung kéo dài dưới cây đề và xem trước), rồi cộng thêm
    // lần nữa độ rộng các cột bên; tổng đó lớn hơn cửa sổ thì cả split view rộng hơn cửa sổ và bị cắt hai bên (trước đây
    // 420 + 2 × 360 + 308 = 1.448 pt). Vì vậy:
    // - xem trước (`.inspector`) gắn vào cột giữa, không vào cả `NavigationSplitView` (chỉ cây đề bị tính hai lần);
    // - cột giữa không khai báo độ rộng tối thiểu: cửa sổ tối thiểu 960 pt đã giữ cho trình soạn đủ rộng
    //   (`editorMinimumAtMinWindow`);
    // - độ rộng tối đa của cây đề và xem trước đủ nhỏ để kể cả khi kéo hết cỡ ở cửa sổ 960 pt, tổng vẫn vừa.
    static let treeColumnWidth = ColumnWidth(min: 200, ideal: 240, max: 300)
    static let previewColumnWidth = ColumnWidth(min: 240, ideal: 280, max: 340)
    /// Độ rộng lý tưởng của cột giữa (trình soạn, thanh lỗi, báo cáo import): cố định, không để Form hay chữ dài một
    /// dòng của thanh lỗi tự đòi độ rộng lớn.
    static let editorIdealWidth: CGFloat = 430
    /// Phần cột cây đề rộng hơn độ rộng khai báo (lề của sidebar, đo được 8 pt trên macOS 26).
    static let sidebarExtra: CGFloat = 8
    /// Trình soạn hẹp nhất có thể ở cửa sổ tối thiểu (cây đề và xem trước kéo hết cỡ).
    static var editorMinimumAtMinWindow: CGFloat {
        minWindowSize.width - (treeColumnWidth.max + sidebarExtra) - previewColumnWidth.max
    }
    /// Chiều cao danh sách ở đáy cột giữa (danh sách lỗi, báo cáo import) theo số dòng: vừa đủ dòng (ước lượng một dòng
    /// chữ mỗi mục), tối đa `bottomListMaxHeight` rồi cuộn, để danh sách ít dòng không chiếm chỗ của trình soạn. Cả hai
    /// danh sách cùng mở (`sharing`) thì mỗi cái tối đa `bottomListSharedMaxHeight`: ở cửa sổ 640 pt, hai danh sách
    /// 180 pt chỉ còn ~160 pt cho trình soạn (review lại PR #42).
    static func bottomListHeight(rows: Int, sharing: Bool = false) -> CGFloat {
        let cap = sharing ? bottomListSharedMaxHeight : bottomListMaxHeight
        return min(cap, max(bottomListRowHeight + 8, CGFloat(rows) * bottomListRowHeight + 8))
    }

    static let bottomListRowHeight: CGFloat = 28
    static let bottomListMaxHeight: CGFloat = 180
    static let bottomListSharedMaxHeight: CGFloat = 100

    /// Cỡ mặc định của cửa sổ soạn đề mới (Đề mới, Import đề…, mở file): `DocumentGroup.defaultSize` ở AdminShell.
    static let defaultWindowSize = CGSize(width: 1200, height: 760)
    /// Thụt dòng câu dưới dòng phần trên cây đề.
    static let questionIndent: CGFloat = 14

    static func color(for severity: IssueSeverity) -> Color {
        severity == .error ? critical : warning
    }
}

/// Dấu lỗi/cảnh báo: biểu tượng + chữ (không chỉ màu).
struct IssueMark: View {
    let severity: IssueSeverity
    var compact = false

    var body: some View {
        Label {
            Text(AuthoringPresentation.severityTitle(severity))
        } icon: {
            Image(systemName: AuthoringPresentation.severitySymbol(severity))
                .paletteForeground(AuthoringStyle.color(for: severity))
        }
        .font(compact ? .caption : .callout)
        .labelStyle(.titleAndIcon)
    }
}

/// Vấn đề của một ô nhập, hiện ngay dưới ô đó.
struct FieldIssues: View {
    let editor: AuthoringEditor
    let issues: [ValidationIssue]

    var body: some View {
        if !issues.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(issues.enumerated()), id: \.offset) { _, issue in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        IssueMark(severity: issue.severity, compact: true)
                        Text(editor.message(for: issue))
                            .font(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}
