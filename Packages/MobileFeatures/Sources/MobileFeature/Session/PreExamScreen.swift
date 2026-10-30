import ExamKit
import InterfaceCore
import SessionModel
import SwiftUI

/// **Trước khi thi** (docs/product/exam-taking.md, mục Trước khi thi): sheet trên Thư viện, cùng các lựa chọn với bản
/// macOS (`PreExamModel` dùng chung): chế độ, tên thí sinh, chọn câu, xáo, thời gian, lý do chưa bắt đầu được. Nền đọc
/// ở v1.1 (QI11).
struct PreExamScreen: View {
    @Bindable var model: PreExamModel
    let onCancel: () -> Void
    let onStart: () -> Void


    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(model.title)
                        .font(.headline)
                    if let code = model.code, !code.isEmpty {
                        Text("Mã đề: \(code)", bundle: .module)
                            .foregroundStyle(MobilePalette.secondaryText)
                    }
                    if let instructions = model.instructions, !instructions.isEmpty {
                        Text(PlainMarkdown.attributed(instructions))
                    }
                }
                Section {
                    Picker(localized("Chế độ"), selection: $model.mode) {
                        Text("Luyện tập", bundle: .module).tag(SessionMode.practice)
                        Text("Thi", bundle: .module).tag(SessionMode.exam)
                    }
                    .pickerStyle(.segmented)
                    .disabled(!model.canChangeOptions)
                    .accessibilityIdentifier("preExam.mode")
                    if let reason = model.practiceUnavailableReason {
                        Text(reason)
                            .font(.footnote)
                            .foregroundStyle(MobilePalette.secondaryText)
                    }
                    TextField(localized("Tên thí sinh"), text: $model.candidateName)
                        .textContentType(.name)
                        .accessibilityIdentifier("preExam.name")
                }
                if model.isPracticeIncorrect {
                    Section {
                        SectionHeader(localized("Câu hỏi"))
                        Text(localized("Luyện lại câu sai: \(model.questionCount) câu, theo thứ tự lần trước, không xáo."))
                    }
                } else {
                    questionsSection
                    Section {
                        Toggle(localized("Xáo thứ tự câu"), isOn: $model.shuffleQuestions)
                        Toggle(localized("Xáo thứ tự đáp án"), isOn: $model.shuffleOptions)
                    }
                    if model.showsTimeLimit {
                        Section {
                            Stepper(value: $model.timeLimitMinutes, in: ExamSession.timeLimitRange) {
                                Text("Thời gian: \(model.timeLimitMinutes) phút", bundle: .module)
                            }
                            .accessibilityIdentifier("preExam.time")
                        }
                    }
                }
                Section {
                    Text(model.summaryLine)
                    ForEach(reasons, id: \.self) { reason in
                        Label(reason, systemImage: "exclamationmark.circle")
                            .foregroundStyle(MobilePalette.critical)
                    }
                    if model.isStarting {
                        Label(localized("Đang đọc file đề…"), systemImage: "hourglass")
                    }
                }
            }
            .navigationTitle(localized("Trước khi thi"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localized("Huỷ"), action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localized("Bắt đầu"), action: onStart)
                        .disabled(!model.canStart)
                        .accessibilityIdentifier("preExam.start")
                }
            }
        }
    }

    /// Lý do chưa bắt đầu được (`PreExamIssue.message`: câu của catalog SessionModel) và lỗi của lần bắt đầu trước.
    private var reasons: [String] {
        let blockers = model.issues
        return blockers.map(\.message) + (model.startFailure.map { [$0] } ?? [])
    }

    private var questionsSection: some View {
        Section {
            SectionHeader(localized("Câu hỏi"))
            Picker(localized("Chọn câu"), selection: $model.selectionKind) {
                Text("Tất cả câu (\(model.totalQuestionCount))", bundle: .module).tag(QuestionSelectionKind.all)
                Text("Theo phần", bundle: .module).tag(QuestionSelectionKind.sections)
                Text("N câu ngẫu nhiên", bundle: .module).tag(QuestionSelectionKind.random)
            }
            switch model.selectionKind {
            case .all:
                EmptyView()
            case .sections:
                ForEach(model.sectionRows) { row in
                    Toggle(isOn: Binding(
                        get: { row.isSelected },
                        set: { model.setSection(row.id, selected: $0) }
                    )) {
                        VStack(alignment: .leading) {
                            Text(row.title)
                            Text("\(row.questionCount) câu", bundle: .module)
                                .font(.footnote)
                                .foregroundStyle(MobilePalette.secondaryText)
                        }
                    }
                }
                HStack {
                    Button(localized("Chọn hết")) { model.selectAllSections() }
                    Spacer()
                    Button(localized("Bỏ chọn")) { model.deselectAllSections() }
                }
                .buttonStyle(.borderless)
            case .random:
                Stepper(value: $model.randomCount, in: model.randomCountRange) {
                    Text("Số câu: \(model.randomCount)/\(model.totalQuestionCount)", bundle: .module)
                }
            }
        }
    }
}
