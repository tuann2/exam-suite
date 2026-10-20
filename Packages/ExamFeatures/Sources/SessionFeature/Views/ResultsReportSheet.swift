import AppKit
import ReportFeature
import SwiftUI

/// Sheet của **Xuất PDF…** / **In…** trên cửa sổ làm bài (docs/product/export-print.md): hộp chọn phần xem lại, rồi
/// (khi dựng lâu) tiến độ "Đang dựng trang N…" có **Huỷ**.
///
/// Nội dung giữ nguyên trong lúc sheet đang đóng (hiệu ứng trượt ra): bấm Return thì luồng sang hộp lưu, bấm Huỷ thì luồng
/// xong (`reportFlow` về nil), nhưng sheet vẫn vẽ nội dung cuối cùng nó đã hiện (hộp chọn hay tiến độ), không đổi sang
/// nội dung khác hay trống trơn.
struct ResultsReportSheet: View {
    let window: SessionWindowModel

    @State private var shownFlow: ResultsReportFlow?
    @State private var shownContent: ResultsReportFlow.SheetContent?

    var body: some View {
        let flow = window.reportFlow ?? shownFlow
        Group {
            if let flow {
                switch flow.sheetContent ?? shownContent ?? .options {
                case .options:
                    ResultsReportOptionsView(flow: flow)
                case .progress:
                    ReportProgressSheet(flow: flow)
                }
            }
        }
        .onChange(of: window.reportFlow?.sheetContent, initial: true) { _, content in
            guard let content, let flow = window.reportFlow else { return }
            shownFlow = flow
            shownContent = content
        }
    }
}

/// Hộp chọn: **Phần xem lại bài** Không / Câu sai và chưa làm / Tất cả câu (lựa chọn lần trước, chung mọi đề); tắt kèm
/// lý do khi Xem lại bài không mở được. **Xuất PDF…** / **In…** (Return), **Huỷ** (Esc).
private struct ResultsReportOptionsView: View {
    let flow: ResultsReportFlow

    var body: some View {
        let isBusy = flow.step == .loadingReview
        VStack(alignment: .leading, spacing: 16) {
            Text(flow.title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 8) {
                Text("Phần xem lại bài", bundle: .module)
                    .font(.body.weight(.semibold))
                    .accessibilityHidden(true)
                Picker(localized("Phần xem lại bài"), selection: Binding(
                    get: { flow.effectiveLevel },
                    set: { flow.level = $0 }
                )) {
                    ForEach(ResultsReviewLevel.allCases) { level in
                        Text(level.title).tag(level)
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
                .disabled(!flow.isLevelSelectable || isBusy)
                .accessibilityIdentifier("report.reviewLevel")
                if let reason = flow.levelUnavailableReason {
                    Label(reason, systemImage: "info.circle")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("report.reviewLevelUnavailable")
                }
            }
            HStack(spacing: 10) {
                if isBusy {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel(Text("Đang đọc file đề", bundle: .module))
                }
                Spacer()
                Button(localized("Huỷ")) { flow.cancel() }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("report.cancel")
                Button(flow.confirmTitle) { flow.confirm() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(isBusy)
                    .accessibilityIdentifier("report.confirm")
            }
        }
        .padding(20)
        .frame(width: 440)
        // Nhóm chứa (children: .contain) mang định danh riêng: gắn thẳng `accessibilityIdentifier` lên VStack thì SwiftUI
        // đè định danh của mọi phần tử con (nút, nhóm lựa chọn), UI test và trợ năng không tìm được `report.confirm`…
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(flow.title))
        .accessibilityIdentifier("report.options")
    }
}

/// Tiến độ dựng trang: "Đang chuẩn bị trang…" / "Đang dựng trang N…", thanh tiến độ, **Huỷ** (Esc).
private struct ReportProgressSheet: View {
    let flow: ResultsReportFlow

    var body: some View {
        let progress = flow.progress
        let message = progress?.message ?? ReportStrings.preparing
        VStack(alignment: .leading, spacing: 12) {
            // Chữ và thanh là hai phần tử riêng, mỗi phần tử một định danh (định danh gắn lên ProgressView có nhãn sẽ đè
            // định danh của nhãn bên trong).
            Text(message)
                .monospacedDigit()
                .accessibilityIdentifier("report.progress.message")
            ProgressView(value: progress?.fractionCompleted ?? 0)
                .accessibilityLabel(Text(message))
                .accessibilityIdentifier("report.progress")
            HStack {
                Spacer()
                Button(localized("Huỷ")) { flow.cancel() }
                    .keyboardShortcut(.cancelAction)
                    .disabled(flow.step != .rendering)
                    .accessibilityIdentifier("report.progress.cancel")
            }
        }
        .padding(20)
        .frame(width: 380)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(flow.title))
        .accessibilityIdentifier("report.progressSheet")
    }
}

// MARK: - Hộp của macOS

extension ReportServices {
    /// Hộp lưu, hộp In, hộp báo lỗi của macOS làm sheet trên cửa sổ `window()` (cửa sổ làm bài; nil thì hộp riêng);
    /// VoiceOver qua `AccessibilityNotification`; phiên bản app từ `Bundle.main`.
    public static func live(window: @escaping @MainActor () -> NSWindow?) -> ReportServices {
        ReportServices(
            chooseDestination: { name in await ReportPanels.chooseDestination(suggestedName: name, for: window()) },
            print: { pdf, title in await ReportPanels.print(pdf, jobTitle: title, for: window()) },
            presentFailure: { title, message in
                await ReportPanels.presentFailure(title: title, message: message, for: window())
            },
            announce: { SessionAnnouncer.post($0) },
            appVersion: bundleVersion
        )
    }

    /// `CFBundleShortVersionString` của app (Creator của PDF).
    static var bundleVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }
}
