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
                            NumberEntryRow(
                                title: localized("Thời gian"),
                                fieldLabel: localized("Thời gian (phút)"),
                                unit: localized("phút"),
                                value: $model.timeLimitMinutes,
                                range: ExamSession.timeLimitRange,
                                identifier: "preExam.timeLimit"
                            )
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
            .scrollDismissesKeyboard(.interactively)
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
                NumberEntryRow(
                    title: localized("Số câu"),
                    fieldLabel: localized("Số câu"),
                    unit: "/ " + InterfaceLocale.number(model.totalQuestionCount),
                    value: $model.randomCount,
                    range: model.randomCountRange,
                    identifier: "preExam.randomCount"
                )
            }
        }
    }
}

/// Ô số kèm nút tăng/giảm (như ô số và Stepper của bản macOS): gõ thẳng số câu hay số phút, nên đề 2.000 câu không phải
/// bấm hàng trăm lần. Số ngoài khoảng không bị sửa ngầm: `PreExamModel` báo lý do chưa bắt đầu được, như macOS.
struct NumberEntryRow: View {
    let title: String
    let fieldLabel: String
    let unit: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let identifier: String

    @State private var text = ""
    @FocusState private var isFocused: Bool
    @ScaledMetric(relativeTo: .body) private var fieldWidth: CGFloat = 64
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 8))
        layout {
            Text(title)
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
            HStack(spacing: 8) {
                TextField(fieldLabel, text: $text)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: fieldWidth)
                    .focused($isFocused)
                    .accessibilityLabel(fieldLabel)
                    .accessibilityIdentifier(identifier)
                Text(unit)
                    .foregroundStyle(MobilePalette.secondaryText)
                    .monospacedDigit()
                Stepper(title, value: $value, in: range)
                    .labelsHidden()
            }
        }
        .onAppear { text = InterfaceLocale.number(value) }
        // Gõ số: cập nhật ngay (ô trống thì giữ số cũ); bỏ chọn ô thì hiện lại số đang dùng.
        .onChange(of: text) { _, newText in
            if let number = Self.parse(newText), number != value { value = number }
        }
        .onChange(of: value) { _, newValue in
            if Self.parse(text) != newValue { text = InterfaceLocale.number(newValue) }
        }
        .onChange(of: isFocused) { _, focused in
            if !focused { text = InterfaceLocale.number(value) }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if isFocused {
                    Spacer()
                    Button(localized("Xong")) { isFocused = false }
                        .accessibilityIdentifier("keyboard.done")
                }
            }
        }
    }

    /// Chỉ lấy chữ số (bỏ dấu ngăn nghìn của locale); không có chữ số hay quá lớn thì nil.
    static func parse(_ text: String) -> Int? {
        let digits = text.filter(\.isASCII).filter(\.isNumber)
        return digits.isEmpty ? nil : Int(digits.prefix(9))
    }
}
