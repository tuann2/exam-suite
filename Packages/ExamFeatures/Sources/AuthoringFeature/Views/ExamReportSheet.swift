import AppKit
import ReportFeature
import SwiftUI

/// Sheet của **Xuất PDF…** / **In…** đề trên cửa sổ soạn đề (docs/product/export-print.md, mục Bản Admin): hộp chọn kiểu,
/// rồi (khi dựng lâu) tiến độ "Đang dựng trang N…" có **Huỷ**.
///
/// Nội dung giữ nguyên trong lúc sheet đang đóng (hiệu ứng trượt ra), như sheet Xuất PDF kết quả: bấm Return thì luồng
/// sang hộp lưu, bấm Huỷ thì luồng xong (`flow` về nil), nhưng sheet vẫn vẽ nội dung cuối cùng nó đã hiện.
struct ExamReportSheet: View {
    let controller: ExamReportController

    @State private var shownFlow: ExamReportFlow?
    @State private var shownContent: ExamReportFlow.SheetContent?

    var body: some View {
        let flow = controller.flow ?? shownFlow
        Group {
            if let flow {
                switch flow.sheetContent ?? shownContent ?? .options {
                case .options:
                    ExamReportOptionsView(flow: flow)
                case .progress:
                    ExamReportProgressView(flow: flow)
                }
            }
        }
        .onChange(of: controller.flow?.sheetContent, initial: true) { _, content in
            guard let content, let flow = controller.flow else { return }
            shownFlow = flow
            shownContent = content
        }
    }
}

/// Hộp chọn: **Kiểu** Có đáp án và giải thích / Chỉ đề (không đáp án), chọn sẵn Chỉ đề mỗi lần mở; dòng "Đề còn N
/// lỗi…" khi đề còn lỗi; dòng nhắc khi đề `hideAnswers` chọn Có đáp án. **Xuất PDF…** / **In…** (Return), **Huỷ** (Esc).
private struct ExamReportOptionsView: View {
    @Bindable var flow: ExamReportFlow

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(flow.title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 8) {
                Text("Kiểu", bundle: .module)
                    .font(.body.weight(.semibold))
                    .accessibilityHidden(true)
                Picker(localized("Kiểu"), selection: $flow.kind) {
                    ForEach(ExamReportKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
                .accessibilityIdentifier("report.examKind")
            }
            if let notice = flow.hideAnswersNotice {
                Label(notice, systemImage: "eye.slash")
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("report.hideAnswersNotice")
            }
            if let notice = flow.errorNotice {
                Label(notice, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("report.errorNotice")
            }
            HStack(spacing: 10) {
                Spacer()
                Button(localized("Huỷ")) { flow.cancel() }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("report.cancel")
                Button(flow.confirmTitle) { flow.confirm() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!flow.canConfirm)
                    .accessibilityIdentifier("report.confirm")
            }
        }
        .padding(20)
        .frame(width: 440)
        // Nhóm chứa (children: .contain) mang định danh riêng, không đè định danh của nút và nhóm lựa chọn bên trong.
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(flow.title))
        .accessibilityIdentifier("report.options")
    }
}

/// Tiến độ dựng trang: "Đang chuẩn bị trang…" / "Đang dựng trang N…", thanh tiến độ, **Huỷ** (Esc).
private struct ExamReportProgressView: View {
    let flow: ExamReportFlow

    var body: some View {
        let progress = flow.progress
        let message = progress?.message ?? ReportStrings.preparing
        VStack(alignment: .leading, spacing: 12) {
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

/// Lấy `NSWindow` của cửa sổ soạn đề cho hộp của macOS (sheet trên đúng cửa sổ này).
struct ExamReportWindowReader: NSViewRepresentable {
    let controller: ExamReportController

    func makeNSView(context: Context) -> ReaderView {
        let view = ReaderView()
        view.controller = controller
        return view
    }

    func updateNSView(_ view: ReaderView, context: Context) {
        view.controller = controller
        if let window = view.window { controller.window = window }
    }

    final class ReaderView: NSView {
        weak var controller: ExamReportController?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window { controller?.window = window }
        }
    }
}
