import ExamFile
import ExamKit
import Foundation

/// Ghi một gói đề thành dây Protobuf của `.oef` (docs/product/exam-format.md, mục File `.oef`), chỉ cho test: đo đọc
/// đề chuẩn dạng `.oef`. App không ghi `.oef`. Ngưỡng đậu ghi thang 1000; chữ ghi nguyên (bộ đọc coi là chữ trơn).
public enum OEFEncoding {
    public static func encode(_ package: ExamPackage) -> Data {
        let exam = package.exam
        var properties = string(1, exam.title)
        if let code = exam.code { properties += string(2, code) }
        properties += key(4, wireType: 1) + withUnsafeBytes(of: (Double(exam.passPercent) * 10).bitPattern.littleEndian, Array.init)
        properties += key(5, wireType: 0) + varint(UInt64(exam.timeLimitMinutes))
        if let instructions = exam.instructions { properties += string(6, instructions) }
        if exam.hideAnswers { properties += key(7, wireType: 0) + [1] }

        var root = field(1, properties)
        for section in exam.sections {
            var sectionBytes = string(1, section.title)
            for question in section.questions {
                var questionBytes = string(2, question.text)
                if let image = question.image, let data = package.media[image] { questionBytes += field(3, [UInt8](data)) }
                if question.type == .multiple {
                    questionBytes += key(5, wireType: 0) + [1]
                    for answer in question.correct { questionBytes += key(6, wireType: 0) + letter(answer) }
                } else if let answer = question.correct.first {
                    questionBytes += key(4, wireType: 0) + letter(answer)
                }
                for option in question.options {
                    questionBytes += field(7, key(1, wireType: 0) + letter(option.id) + string(2, option.text))
                }
                if let explanation = question.explanation { questionBytes += string(8, explanation) }
                sectionBytes += field(2, questionBytes)
            }
            root += field(2, sectionBytes)
        }
        return Data(root)
    }

    private static func varint(_ value: UInt64) -> [UInt8] {
        var value = value
        var out: [UInt8] = []
        repeat {
            let byte = UInt8(value & 0x7F)
            value >>= 7
            out.append(value == 0 ? byte : byte | 0x80)
        } while value != 0
        return out
    }

    private static func key(_ field: Int, wireType: UInt8) -> [UInt8] { varint(UInt64(field) << 3 | UInt64(wireType)) }
    private static func field(_ number: Int, _ payload: [UInt8]) -> [UInt8] {
        key(number, wireType: 2) + varint(UInt64(payload.count)) + payload
    }
    private static func string(_ number: Int, _ text: String) -> [UInt8] { field(number, Array(text.utf8)) }
    private static func letter(_ id: OptionID) -> [UInt8] { varint(UInt64(id.letter.asciiValue!)) }
}
