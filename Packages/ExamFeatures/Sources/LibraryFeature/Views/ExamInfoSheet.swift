import InterfaceCore
import LibraryData
import SwiftUI

/// Đích của sheet **Thông tin** (`sheet(item:)`).
struct InfoTarget: Identifiable, Hashable {
    let id: UUID
}

/// Sheet **Thông tin** (docs/product/library.md): đường dẫn file, dung lượng, phiên bản định dạng, ngày
/// thêm, số phần/câu/ảnh, thời gian, ngưỡng đậu, trạng thái và lý do; kèm bước tiếp theo của trạng thái.
struct ExamInfoSheet: View {
    let model: LibraryModel
    let examID: UUID

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            if let entry = model.store.entry(examID) {
                content(entry, actions: ExamActions(entry: entry, model: model))
            } else {
                ContentUnavailableView(
                    localized("Đề không còn trong thư viện"),
                    systemImage: "questionmark.folder"
                )
                .frame(minHeight: 200)
            }
            Divider()
            HStack {
                Spacer()
                Button(localized("Đóng")) { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    // Nút mặc định có nền màu nhấn và chữ trắng: dùng #017777 (5,38:1) ở cả hai giao diện.
                    .tint(LibraryStyle.accent)
            }
            .padding(16)
        }
        .frame(minWidth: 540, idealWidth: 580, minHeight: 420)
        .onExitCommand { dismiss() }
    }

    private func content(_ entry: LibraryEntry, actions: ExamActions) -> some View {
        let summary = entry.summary
        return Form {
            Section {
                LabeledContent(
                    localized("Mã đề"),
                    value: entry.code?.isEmpty == false ? entry.code ?? "" : localized("Chưa có")
                )
                LabeledContent(localized("Số phần"), value: LibraryFormat.sections(summary.sectionCount))
                LabeledContent(localized("Số câu"), value: LibraryFormat.questions(summary.questionCount))
                LabeledContent(localized("Số ảnh"), value: LibraryFormat.images(summary.imageCount))
                LabeledContent(localized("Thời gian làm bài"), value: LibraryFormat.minutes(summary.timeLimitMinutes))
                LabeledContent(localized("Ngưỡng đậu"), value: LibraryFormat.percent(summary.passPercent))
            } header: {
                HStack(alignment: .firstTextBaseline) {
                    Text(entry.title)
                        .font(.title3.weight(.semibold))
                        .textSelection(.enabled)
                        .accessibilityAddTraits(.isHeader)
                    if entry.isSample { SampleBadge() }
                }
            }
            Section(localized("File")) {
                LabeledContent(localized("Đường dẫn")) {
                    Text(entry.fileURL.path)
                        .textSelection(.enabled)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                }
                LabeledContent(localized("Dung lượng"), value: LibraryFormat.fileSize(entry.fileSize))
                LabeledContent(localized("Phiên bản định dạng"), value: String(summary.formatVersion))
                LabeledContent(localized("Ngày thêm"), value: LibraryFormat.dateTime(entry.addedAt))
                HStack {
                    Spacer()
                    Button(localized("Hiện trong Finder")) { actions.revealInFinder() }
                        .disabled(!actions.canReveal)
                    Button(localized("Xem lịch sử thi")) {
                        dismiss()
                        actions.showHistory()
                    }
                }
            }
            Section(localized("Trạng thái")) {
                StatusLabel(presentation: actions.presentation)
                    .font(.body.weight(.semibold))
                if let detail = actions.presentation.detail {
                    Text(detail)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                NextStepButtons(actions: actions)
            }
        }
        .formStyle(.grouped)
    }
}
