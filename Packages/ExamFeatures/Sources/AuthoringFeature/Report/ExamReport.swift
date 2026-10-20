import ExamFile
import ExamKit
import Foundation
import LibraryFeature
import ReportFeature
import SessionFeature

/// Kiểu PDF đề (docs/product/export-print.md, mục Bản Admin, phương án 7).
public enum ExamReportKind: String, CaseIterable, Hashable, Sendable, Identifiable {
    /// **Có đáp án và giải thích**: đánh dấu **Đáp án đúng** trên lựa chọn đúng và khối **Giải thích**.
    case withAnswers
    /// **Chỉ đề (không đáp án)**: câu hỏi, ảnh, lựa chọn; không có đáp án đúng, không có giải thích.
    case questionsOnly

    /// Kiểu chọn sẵn mỗi lần mở hộp chọn: luôn **Chỉ đề**, không nhớ lần trước (Nt0 chốt 2026-10-17, export-print.md
    /// phương án 18): muốn bản có đáp án thì phải chọn mỗi lần, để không gửi nhầm đáp án cho học viên.
    public static let `default`: ExamReportKind = .questionsOnly

    public var id: Self { self }

    public var title: String {
        switch self {
        case .withAnswers: localized("Có đáp án và giải thích")
        case .questionsOnly: localized("Chỉ đề (không đáp án)")
        }
    }

    var includesAnswers: Bool { self == .withAnswers }
}

/// Model của PDF đề (docs/product/export-print.md, mục Bản Admin: PDF và In đề): ảnh chụp **nội dung đang có trong cửa
/// sổ soạn đề** (kể cả thay đổi chưa lưu, đề còn lỗi kiểm đề), dựng thành khối của ReportFeature cho bộ dựng trang dùng
/// chung với PDF kết quả. Mọi quy tắc của PDF đề nằm ở đây, có test không cần vẽ:
///
/// - **Đầu trang đầu**: tên đề, mã đề, số câu, số phần, thời gian Thi mặc định, ngưỡng đậu (% và thang 1000), "Ẩn đáp án"
///   nếu có; hướng dẫn (Markdown cơ bản).
/// - **Mỗi phần**: tên phần làm đề mục (không đứng một mình cuối trang); câu đánh số liên tục toàn đề (1…N) theo **thứ
///   tự file**; lựa chọn theo thứ tự file, nhãn A, B, C… theo vị trí. Không xáo.
/// - **Mỗi câu**: tên phần và "Câu 12/60" (như cửa sổ làm bài và xem trước), nội dung, ảnh, gợi ý "Chọn N đáp án" cho câu
///   nhiều đáp án, lựa chọn; kiểu **Có đáp án** thêm **Đáp án đúng** (ký hiệu + chữ) và khối **Giải thích**.
/// - **Chân trang**: tên đề và "Trang N/M", rồi mã đề và "Có đáp án" (kiểu Có đáp án). Không có thời điểm xuất
///   (phương án 17).
///
/// Nội dung đề in **đúng như đang soạn** (phương án 8): không sửa, không bỏ câu lỗi. Đáp án đúng theo `Question.correct`
/// như xem trước của Soạn đề; ảnh không có trong gói (thiếu, sai tên) thì dòng "Không hiện được ảnh của câu này"; tên
/// đề/phần rỗng hiện như cây đề ("(Đề chưa có tên)", "(Phần chưa có tên)").
public struct ExamReport: Sendable, Equatable {
    /// Đề và ảnh đang có trong cửa sổ (`ExamDraft.package`).
    public var package: ExamPackage
    public var kind: ExamReportKind
    /// Phiên bản app (Creator của PDF).
    public var appVersion: String

    public init(package: ExamPackage, kind: ExamReportKind, appVersion: String) {
        self.package = package
        self.kind = kind
        self.appVersion = appVersion
    }

    public var exam: Exam { package.exam }

    /// Tên đề hiện trong PDF: như cây đề, tên rỗng là "(Đề chưa có tên)".
    public var displayTitle: String {
        exam.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? localized("(Đề chưa có tên)") : exam.title
    }

    /// Tên file gợi ý (phương án 10): `<Tên đề> (có đáp án).pdf` / `<Tên đề> (đề).pdf`, cắt ở 120 ký tự.
    public var suggestedFileName: String {
        ReportFileName.exam(title: exam.title, withAnswers: kind.includesAnswers)
    }

    /// Tên việc in (tên gợi ý của "Lưu thành PDF" trong hộp In, phương án 15): tên file gợi ý bỏ `.pdf`.
    public var jobTitle: String {
        (suggestedFileName as NSString).deletingPathExtension
    }

    /// Tài liệu để dựng trang. Thuần (không SwiftUI, không main actor): luồng Xuất/In dựng ngoài main actor.
    public func document() -> ReportDocument {
        let labels = Labels()
        let total = exam.questionCount
        var blocks: [ReportBlock] = [.title(titleBlock())]
        blocks.reserveCapacity(total + exam.sections.count + 1)
        var number = 0
        for section in exam.sections {
            let sectionTitle = AuthoringPresentation.sectionTitle(section.title)
            blocks.append(.heading(ReportHeading(
                title: sectionTitle,
                detail: ReportStrings.questionCount(section.questions.count)
            )))
            for question in section.questions {
                number += 1
                blocks.append(.question(questionBlock(
                    question,
                    number: number,
                    total: total,
                    sectionTitle: sectionTitle,
                    labels: labels
                )))
            }
        }
        return ReportDocument(
            metadata: ReportMetadata(
                title: localized("\(displayTitle) – Đề"),
                creator: ReportStrings.creator(version: appVersion)
            ),
            footer: footer(),
            blocks: blocks
        )
    }

    // MARK: - Khối

    /// Đầu trang đầu: tên đề, các trường, hướng dẫn.
    func titleBlock() -> ReportTitle {
        var fields: [ReportField] = []
        if let code = exam.code, !code.isEmpty {
            fields.append(ReportField(label: localized("Mã đề"), value: code))
        }
        // Số có ngăn nghìn theo ngôn ngữ giao diện ("2.000"), như "Câu 1.234/2.000" (accessibility-localization.md).
        fields.append(ReportField(label: localized("Số câu"), value: SessionFormat.number(exam.questionCount)))
        fields.append(ReportField(label: localized("Số phần"), value: SessionFormat.number(exam.sections.count)))
        fields.append(ReportField(label: localized("Thời gian Thi"), value: SessionFormat.minutes(exam.timeLimitMinutes)))
        // Thang 1000 luôn số trơn, như "72% · 720/1000" của Kết quả (Nt0 chốt 2026-10-17).
        let percent = SessionFormat.percent(exam.passPercent)
        let scaled = InterfaceLocale.scale1000(exam.passPercent * 10)
        fields.append(ReportField(label: ReportStrings.passThreshold, value: localized("\(percent) · \(scaled)/1000")))
        if exam.hideAnswers {
            fields.append(ReportField(label: localized("Ẩn đáp án"), value: localized("Có")))
        }
        let instructions = exam.instructions?.trimmingCharacters(in: .whitespacesAndNewlines)
        return ReportTitle(
            title: displayTitle,
            fields: fields,
            instructions: instructions?.isEmpty == false ? exam.instructions : nil
        )
    }

    /// Nhãn lặp lại trên mọi câu, tra catalog một lần cho cả tài liệu (đề 2.000 câu). Chỉ dùng trong một lần dựng.
    final class Labels {
        let correctAnswer = ReportBadge(title: ReportStrings.correctAnswer, systemImage: "checkmark.circle.fill")
        private var hints: [Int: String] = [:]

        /// "Chọn N đáp án" (như cửa sổ làm bài: N = số đáp án đúng của câu).
        func hint(_ count: Int) -> String {
            if let hint = hints[count] { return hint }
            let hint = localized("Chọn \(count) đáp án")
            hints[count] = hint
            return hint
        }
    }

    func questionBlock(
        _ question: Question,
        number: Int,
        total: Int,
        sectionTitle: String,
        labels: Labels
    ) -> ReportQuestion {
        let image: ReportImageSource? = question.image.map { path in
            package.media[path].map(ReportImageSource.data) ?? .missing
        }
        let correct = question.correctSet
        let options = question.options.enumerated().map { position, option in
            ReportOption(
                label: SessionFormat.optionLabel(position: position),
                text: option.text,
                marks: kind.includesAnswers && correct.contains(option.id) ? [labels.correctAnswer] : []
            )
        }
        let explanation = question.explanation.flatMap { text in
            kind.includesAnswers && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? text : nil
        }
        return ReportQuestion(
            number: number,
            sectionTitle: sectionTitle,
            positionText: ReportStrings.questionPosition(number, of: total),
            text: question.text,
            image: image,
            hint: question.type == .multiple ? labels.hint(correct.count) : nil,
            options: options,
            explanation: explanation
        )
    }

    /// Chân trang: tên đề + "Trang N/M" (bộ dựng trang điền), rồi "Mã đề: …" và "Có đáp án" (kiểu Có đáp án).
    func footer() -> ReportFooter {
        var parts: [String] = []
        if let code = exam.code, !code.isEmpty { parts.append(localized("Mã đề: \(code)")) }
        if kind.includesAnswers { parts.append(localized("Có đáp án")) }
        return ReportFooter(title: displayTitle, lines: parts.isEmpty ? [] : [parts.joined(separator: " · ")])
    }
}
