import ExamKit
import SwiftUI

/// Sheet **Trước khi thi** trên cửa sổ Thư viện (docs/product/exam-taking.md, mục Trước khi thi): `Form` với
/// chế độ (segmented), tên thí sinh, cách chọn câu, xáo, thời gian (Thi), **Nền đọc** (ô chọn có mẫu màu; lựa chọn của cả
/// app, plan giai đoạn 6 bước 1), dòng tóm tắt, lý do khoá ngay dưới; **Bắt đầu** (Return, mặc định) và **Huỷ** (Esc).
struct PreExamView: View {
    @Bindable var model: PreExamModel
    let onStart: () -> Void
    let onCancel: () -> Void

    @FocusState private var focusedField: Field?
    /// Locale của ngôn ngữ giao diện (gốc scene gắn `.interfaceLocale()`): ô số hiện và đọc số theo nó.
    @Environment(\.locale) private var locale

    private enum Field: Hashable {
        case name
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                header
                modeSection
                Section {
                    TextField(localized("Tên thí sinh"), text: $model.candidateName)
                        .focused($focusedField, equals: .name)
                        .accessibilityIdentifier("preExam.candidateName")
                }
                if model.isPracticeIncorrect {
                    practiceIncorrectSection
                } else {
                    questionsSection
                    shuffleSection
                    if model.showsTimeLimit {
                        timeSection
                    }
                }
                Section {
                    ReadingBackgroundPicker()
                }
            }
            .formStyle(.grouped)
            .accessibilityIdentifier("preExam.form")
            Divider()
            footer
        }
        .frame(minWidth: 560, idealWidth: 600, minHeight: 480, idealHeight: 640)
        .onAppear {
            // Tên trống thì đưa tiêu điểm vào ô tên (phải nhập mới Bắt đầu được).
            if model.trimmedCandidateName.isEmpty { focusedField = .name }
        }
    }

    // MARK: - Các phần

    private var header: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text(model.title)
                    .font(.title2.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                if let code = model.code, !code.isEmpty {
                    Text("Mã đề: \(code)", bundle: .module)
                        .font(.subheadline.monospaced())
                        .foregroundStyle(.secondary)
                }
                if let instructions = model.instructions, !instructions.isEmpty {
                    MarkdownText(instructions)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                        .textSelection(.enabled)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var modeSection: some View {
        Section {
            Picker(localized("Chế độ"), selection: $model.mode) {
                Text("Luyện tập", bundle: .module).tag(SessionMode.practice)
                Text("Thi", bundle: .module).tag(SessionMode.exam)
            }
            .pickerStyle(.segmented)
            .disabled(!model.canChangeOptions)
            .accessibilityIdentifier("preExam.mode")
            if let reason = model.practiceUnavailableReason {
                Label(reason, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var practiceIncorrectSection: some View {
        Section(localized("Câu hỏi")) {
            Label(
                localized("Luyện lại câu sai: \(model.questionCount) câu, theo thứ tự lần trước, không xáo."),
                systemImage: "arrow.counterclockwise"
            )
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var questionsSection: some View {
        Section(localized("Câu hỏi")) {
            Picker(localized("Chọn câu"), selection: $model.selectionKind) {
                Text("Tất cả câu (\(model.totalQuestionCount))", bundle: .module).tag(QuestionSelectionKind.all)
                Text("Theo phần", bundle: .module).tag(QuestionSelectionKind.sections)
                Text("N câu ngẫu nhiên", bundle: .module).tag(QuestionSelectionKind.random)
            }
            .pickerStyle(.radioGroup)
            .accessibilityIdentifier("preExam.selection")

            switch model.selectionKind {
            case .all:
                EmptyView()
            case .sections:
                sectionList
            case .random:
                randomCount
            }
        }
    }

    @ViewBuilder
    private var sectionList: some View {
        ForEach(model.sectionRows) { row in
            Toggle(isOn: Binding(
                get: { row.isSelected },
                set: { model.setSection(row.id, selected: $0) }
            )) {
                HStack {
                    Text(row.title)
                    Spacer()
                    Text("\(row.questionCount) câu", bundle: .module)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .toggleStyle(.checkbox)
        }
        HStack {
            Button(localized("Chọn hết")) { model.selectAllSections() }
            Button(localized("Bỏ chọn")) { model.deselectAllSections() }
        }
        .controlSize(.small)
    }

    private var randomCount: some View {
        LabeledContent(localized("Số câu")) {
            HStack(spacing: 6) {
                TextField(localized("Số câu"), value: $model.randomCount, format: .number.locale(locale))
                    .labelsHidden()
                    .multilineTextAlignment(.trailing)
                    .frame(width: 72)
                    .accessibilityIdentifier("preExam.randomCount")
                Stepper(localized("Số câu"), value: $model.randomCount, in: model.randomCountRange)
                    .labelsHidden()
                Text(verbatim: "/ \(SessionFormat.number(model.totalQuestionCount))")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    private var shuffleSection: some View {
        Section {
            Toggle(localized("Xáo thứ tự câu"), isOn: $model.shuffleQuestions)
                .accessibilityIdentifier("preExam.shuffleQuestions")
            Toggle(localized("Xáo thứ tự đáp án"), isOn: $model.shuffleOptions)
                .accessibilityIdentifier("preExam.shuffleOptions")
        }
    }

    private var timeSection: some View {
        Section {
            LabeledContent(localized("Thời gian")) {
                HStack(spacing: 6) {
                    TextField(localized("Thời gian"), value: $model.timeLimitMinutes, format: .number.locale(locale))
                        .labelsHidden()
                        .multilineTextAlignment(.trailing)
                        .frame(width: 72)
                        .accessibilityLabel(Text("Thời gian (phút)", bundle: .module))
                        .accessibilityIdentifier("preExam.timeLimit")
                    Stepper(localized("Thời gian"), value: $model.timeLimitMinutes, in: ExamSession.timeLimitRange)
                        .labelsHidden()
                    Text("phút", bundle: .module)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Chân sheet

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.summaryLine)
                .font(.headline)
                .monospacedDigit()
                .accessibilityIdentifier("preExam.summary")
            let blockers = model.issues
            let reasons = blockers.map(\.message) + (model.startFailure.map { [$0] } ?? [])
            if !reasons.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(reasons, id: \.self) { reason in
                        Label {
                            Text(reason).fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(SessionStyle.warning)
                        }
                        .font(.callout)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("preExam.issues")
            }
            HStack {
                if model.isStarting {
                    ProgressView()
                        .controlSize(.small)
                    Text("Đang đọc file đề…", bundle: .module)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(localized("Huỷ"), action: onCancel)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("preExam.cancel")
                Button(localized("Bắt đầu"), action: onStart)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!model.canStart)
                    // Nút mặc định có nền màu nhấn và chữ trắng: #017777 (5,38:1) ở cả hai giao diện.
                    .tint(SessionStyle.accentFill)
                    .accessibilityIdentifier("preExam.start")
            }
        }
        .padding(16)
    }
}
