package vn.io.nt0.examsuite.core.file

import vn.io.nt0.examsuite.core.model.Exam
import vn.io.nt0.examsuite.core.model.ExamOption
import vn.io.nt0.examsuite.core.model.ExamSection
import vn.io.nt0.examsuite.core.model.OptionId
import vn.io.nt0.examsuite.core.model.Question
import vn.io.nt0.examsuite.core.model.QuestionType
import vn.io.nt0.examsuite.core.validation.ExamValidator
import vn.io.nt0.examsuite.core.validation.IssueSeverity
import java.io.File
import java.nio.ByteBuffer
import java.nio.channels.FileChannel
import java.nio.file.StandardOpenOption
import java.security.MessageDigest
import java.text.Normalizer
import java.util.UUID

/**
 * Đọc file `.oef` của Open Exam Suite (bản Protobuf) và chuyển thành đề, theo hợp đồng ở docs/product/exam-format.md
 * (mục File `.oef`; ADR 0014), cùng kết quả với `OEFReader` của bản macOS trên oracle `fixtures/oef/`. Viết mới từ hiểu
 * biết về định dạng, không chép code của Open Exam Suite (ADR 0001).
 *
 * Chỉ có **đọc nghiêm**: bản Android không có bản Admin hay bước phân loại Đề có lỗi, nên không cần ghi chú của đọc dễ.
 * Thứ tự kiểm: kích thước file → bản cũ (zip, BinaryFormatter) → dây Protobuf và giới hạn → trường lạ → ngưỡng đậu →
 * từng câu theo thứ tự file (số lựa chọn, chữ cái trùng, đáp án, ảnh) → còn câu nào không → `ExamValidator` không báo
 * lỗi mức error.
 */
object OefReader {
    /** Đề đã chuyển. `media`: đường dẫn ảnh → vùng byte chỉ đọc của file nguồn (không chép). */
    class Conversion(val exam: Exam, val media: Map<String, ByteBuffer>)

    /** Đọc file qua ánh xạ bộ nhớ: ảnh của đề lớn không nằm trong heap. */
    fun read(file: File, limits: OefLimits = OefLimits.DEFAULT): Conversion {
        val size = file.length()
        if (size > limits.fileBytes) throw ExamFileError.Oef(OefProblem.TooLarge(OefLimit.FILE, limits.fileBytes))
        val buffer = FileChannel.open(file.toPath(), StandardOpenOption.READ).use { it.map(FileChannel.MapMode.READ_ONLY, 0, size) }
        return convert(buffer, limits)
    }

    fun convert(bytes: ByteArray, limits: OefLimits = OefLimits.DEFAULT): Conversion = convert(ByteBuffer.wrap(bytes), limits)

    /** `buffer`: nội dung file từ vị trí hiện tại tới giới hạn. */
    fun convert(buffer: ByteBuffer, limits: OefLimits = OefLimits.DEFAULT): Conversion {
        val source = buffer.slice().asReadOnlyBuffer()
        if (source.capacity() > limits.fileBytes) throw ExamFileError.Oef(OefProblem.TooLarge(OefLimit.FILE, limits.fileBytes))
        if (isLegacy(head(source, LEGACY_HEADER_BYTES))) throw ExamFileError.Oef(OefProblem.LegacyFormat)
        val decoder = WireDecoder(source, limits)
        val raw = decoder.decodeExam()
        if (decoder.unknownFields.isNotEmpty()) throw ExamFileError.Oef(OefProblem.UnknownFields(decoder.unknownFields))
        return Converter(raw, limits).convert()
    }

    /** Số byte đầu cần để nhận ra `.oef` bản cũ (`isLegacy`). */
    const val LEGACY_HEADER_BYTES = 17

    /**
     * `.oef` bản cũ: zip (v1, v2: XML và ảnh) hoặc header của .NET BinaryFormatter (MS-NRBF: bản ghi 0, root id, header
     * id −1, phiên bản 1.0). Byte đầu 0 không thể mở một thông điệp Protobuf (số trường 0), nên không nhầm.
     */
    fun isLegacy(head: ByteArray): Boolean {
        fun at(index: Int, vararg expected: Int) = head.size >= index + expected.size &&
            expected.withIndex().all { (i, b) -> head[index + i].toInt() and 0xFF == b }
        if (at(0, 0x50, 0x4B, 0x03, 0x04) || at(0, 0x50, 0x4B, 0x05, 0x06)) return true
        return head.size >= LEGACY_HEADER_BYTES && head[0].toInt() == 0 &&
            at(5, 0xFF, 0xFF, 0xFF, 0xFF) && at(9, 1, 0, 0, 0) && at(13, 0, 0, 0, 0)
    }

    // ---------- Id dẫn xuất ----------

    /** UUID phiên bản 8 (RFC 9562) từ 16 byte đầu của SHA-256(UTF-8 của `name`). */
    internal fun derivedId(name: String): UUID {
        val b = MessageDigest.getInstance("SHA-256").digest(name.toByteArray(Charsets.UTF_8))
        b[6] = ((b[6].toInt() and 0x0F) or 0x80).toByte()
        b[8] = ((b[8].toInt() and 0x3F) or 0x80).toByte()
        val wrapped = ByteBuffer.wrap(b)
        return UUID(wrapped.getLong(0), wrapped.getLong(8))
    }

    /** Id đề: mã (rỗng khi không có hoặc sai mẫu) và tiêu đề sau khi chuẩn hoá, ngăn bằng U+0000. */
    internal fun examId(code: String?, title: String): UUID = derivedId("oef-exam\u0000${code ?: ""}\u0000$title")

    /** Id phần thứ `section`, câu thứ `question` theo vị trí trong file (đếm từ 0, kể cả phần và câu bị bỏ). */
    internal fun sectionId(exam: UUID, section: Int): UUID = derivedId("$exam/s$section")

    internal fun questionId(exam: UUID, section: Int, question: Int): UUID = derivedId("$exam/s$section/q$question")

    /**
     * Ngưỡng đậu thang 1000 → phần trăm, làm tròn gần nhất, nửa lên (725 → 73; như `Passing Score` của import.md phương
     * án 13); null khi không phải số trong 0–1000.
     */
    internal fun passPercent(passmark: Double): Int? =
        if (passmark.isFinite() && passmark >= 0.0 && passmark <= 1000.0) Math.round(passmark / 10).toInt() else null

    // ---------- Chuỗi ----------

    /** Ký tự được thoát bằng `\` trong chữ trơn của `.oef` (QO7 của plan-oef.md); `&` không thoát. */
    private const val MARKDOWN_SPECIALS = "\\`*_[]<>~"

    /** NFC rồi bỏ code point `White_Space` ở hai đầu (cùng định nghĩa khoảng trắng với `ExamValidator`). */
    internal fun clean(s: String): String = ExamValidator.trimmed(Normalizer.normalize(s, Normalizer.Form.NFC))

    /** Chữ trơn → Markdown cơ bản hiển thị đúng chữ gốc. */
    internal fun markdown(plain: String): String = buildString {
        for (c in clean(plain)) {
            if (c in MARKDOWN_SPECIALS) append('\\')
            append(c)
        }
    }

    /**
     * Chữ cái của lựa chọn/đáp án (giá trị varint 64 bit trong file) để hiện trong câu báo: ký tự in được ASCII giữ
     * nguyên, khác thì `U+XXXX` (hex chữ hoa, ít nhất 4 chữ số).
     */
    internal fun letterName(value: Long): String =
        if (value in 0x21L..0x7EL) value.toInt().toChar().toString() else "U+" + value.toULong().toString(16).uppercase().padStart(4, '0')

    // ---------- Ảnh ----------

    private val HEIC_BRANDS = setOf("heic", "heix", "heim", "heis", "hevc", "hevx")

    /** Đuôi ảnh theo byte đầu (PNG, JPEG, GIF, WebP, HEIC); null với loại khác. */
    internal fun imageExtension(data: ByteBuffer): String? {
        val head = head(data, 12)
        fun startsWith(vararg bytes: Int) = head.size >= bytes.size && bytes.withIndex().all { (i, b) -> head[i].toInt() and 0xFF == b }
        fun ascii(from: Int) = String(head, from, 4, Charsets.ISO_8859_1)
        return when {
            startsWith(0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A) -> "png"
            startsWith(0xFF, 0xD8, 0xFF) -> "jpg"
            head.size >= 6 && String(head, 0, 6, Charsets.ISO_8859_1).let { it == "GIF87a" || it == "GIF89a" } -> "gif"
            head.size >= 12 && ascii(0) == "RIFF" && ascii(8) == "WEBP" -> "webp"
            head.size >= 12 && ascii(4) == "ftyp" && ascii(8) in HEIC_BRANDS -> "heic"
            else -> null
        }
    }

    /** Tối đa `count` byte đầu của `data`, không đổi vị trí của nó. */
    internal fun head(data: ByteBuffer, count: Int): ByteArray {
        val copy = data.duplicate()
        return ByteArray(minOf(count, copy.remaining())).also { copy.get(it) }
    }
}

/**
 * Loại file đề theo nội dung (bản Android: file từ app khác có thể không có tên; plan-oef.md Phần 3 bước 1). Chữ ký zip
 * là gói `.exam`; header `.oef` bản cũ hay byte đầu `0A` (khoá của Properties, trường 1 kiểu độ dài, thứ protobuf-net luôn
 * ghi đầu tiên) là `.oef`; còn lại không phải file đề. Một `.oef` bản cũ dạng zip vì vậy đọc như gói `.exam`.
 */
enum class ExamSourceKind {
    EXAM_PACKAGE,
    OEF,
    UNKNOWN,
    ;

    companion object {
        /** Số byte đầu cần để nhận diện. */
        const val HEAD_BYTES = OefReader.LEGACY_HEADER_BYTES

        fun of(head: ByteArray): ExamSourceKind {
            val zip = head.size >= 4 && head[0] == 0x50.toByte() && head[1] == 0x4B.toByte() &&
                ((head[2] == 3.toByte() && head[3] == 4.toByte()) || (head[2] == 5.toByte() && head[3] == 6.toByte()))
            return when {
                zip -> EXAM_PACKAGE
                OefReader.isLegacy(head) || (head.isNotEmpty() && head[0] == 0x0A.toByte()) -> OEF
                else -> UNKNOWN
            }
        }
    }
}

// ---------- Giải mã dây ----------

private class RawOption {
    var letter = 0L
    var text = ""
}

private class RawQuestion {
    var text = ""
    var image: Span? = null
    var answer = 0L
    var isMultipleChoice = false
    val answers = ArrayList<Long>()
    val options = ArrayList<RawOption>()
    var explanation = ""
}

private class RawSection {
    var title = ""
    val questions = ArrayList<RawQuestion>()
}

private class RawExam(val source: ByteBuffer) {
    var title = ""
    var code = ""
    var passmark = 0.0
    var timeLimit = 0
    var instructions = ""
    var hideAnswers = false
    val sections = ArrayList<RawSection>()
}

/**
 * Dây Protobuf → `RawExam`. Trường không lặp xuất hiện nhiều lần: giá trị vô hướng lấy lần cuối, thông điệp (Properties)
 * gộp, như luật của Protobuf. Trường đã biết sai kiểu dây là dây hỏng.
 */
private class WireDecoder(private val bytes: ByteBuffer, private val limits: OefLimits) {
    val unknownFields = ArrayList<String>()
    private val seenUnknown = HashSet<String>()
    private var elements = 0
    private var textBytes = 0L

    fun decodeExam(): RawExam {
        val exam = RawExam(bytes)
        val reader = ProtobufReader(bytes, 0, bytes.capacity())
        while (true) {
            val tag = reader.nextTag() ?: break
            when (tag.field) {
                1 -> decodeProperties(reader.nested(message(tag, reader)), exam)
                2 -> {
                    val nested = reader.nested(message(tag, reader))
                    count()
                    exam.sections += decodeSection(nested, "sections[${exam.sections.size}]")
                }
                else -> unknown(tag, reader, "")
            }
        }
        return exam
    }

    private fun decodeProperties(reader: ProtobufReader, exam: RawExam) {
        while (true) {
            val tag = reader.nextTag() ?: break
            when (tag.field) {
                1 -> exam.title = string(tag, reader)
                2 -> exam.code = string(tag, reader)
                3 -> varint(tag, reader) // Version: số phiên bản đề của người soạn, `.exam` không có.
                4 -> {
                    if (tag.wireType != ProtobufReader.WireType.FIXED64) throw malformed(tag.offset)
                    exam.passmark = Double.fromBits(reader.readFixed64())
                }
                5 -> exam.timeLimit = varint(tag, reader).toInt() // 32 bit thấp, có dấu.
                6 -> exam.instructions = string(tag, reader)
                7 -> exam.hideAnswers = varint(tag, reader) != 0L
                else -> unknown(tag, reader, "properties.")
            }
        }
    }

    private fun decodeSection(reader: ProtobufReader, path: String): RawSection {
        val section = RawSection()
        while (true) {
            val tag = reader.nextTag() ?: break
            when (tag.field) {
                1 -> section.title = string(tag, reader)
                2 -> {
                    val nested = reader.nested(message(tag, reader))
                    count()
                    section.questions += decodeQuestion(nested, "$path.questions[${section.questions.size}]")
                }
                else -> unknown(tag, reader, "$path.")
            }
        }
        return section
    }

    private fun decodeQuestion(reader: ProtobufReader, path: String): RawQuestion {
        val question = RawQuestion()
        while (true) {
            val tag = reader.nextTag() ?: break
            when (tag.field) {
                1 -> varint(tag, reader) // No: số thứ tự, không dùng.
                2 -> question.text = string(tag, reader)
                3 -> question.image = message(tag, reader)
                4 -> question.answer = varint(tag, reader)
                5 -> question.isMultipleChoice = varint(tag, reader) != 0L
                6 -> {
                    // Answers: char lặp, nhận cả dạng packed lẫn từng phần tử; mỗi đáp án tính vào giới hạn số phần tử.
                    if (tag.wireType == ProtobufReader.WireType.LENGTH_DELIMITED) {
                        val packed = reader.nested(reader.readLengthDelimited())
                        while (!packed.isAtEnd) {
                            count()
                            question.answers += packed.readVarint()
                        }
                    } else {
                        if (tag.wireType != ProtobufReader.WireType.VARINT) throw malformed(tag.offset)
                        count()
                        question.answers += reader.readVarint()
                    }
                }
                7 -> {
                    val nested = reader.nested(message(tag, reader))
                    count()
                    question.options += decodeOption(nested, "$path.options[${question.options.size}]")
                }
                8 -> question.explanation = string(tag, reader)
                else -> unknown(tag, reader, "$path.")
            }
        }
        return question
    }

    private fun decodeOption(reader: ProtobufReader, path: String): RawOption {
        val option = RawOption()
        while (true) {
            val tag = reader.nextTag() ?: break
            when (tag.field) {
                1 -> option.letter = varint(tag, reader)
                2 -> option.text = string(tag, reader)
                else -> unknown(tag, reader, "$path.")
            }
        }
        return option
    }

    /** Trường độ dài (thông điệp con, ảnh): vùng byte. */
    private fun message(tag: ProtobufReader.Tag, reader: ProtobufReader): Span {
        if (tag.wireType != ProtobufReader.WireType.LENGTH_DELIMITED) throw malformed(tag.offset)
        return reader.readLengthDelimited()
    }

    private fun string(tag: ProtobufReader.Tag, reader: ProtobufReader): String {
        val span = message(tag, reader)
        textBytes += span.size
        if (textBytes > limits.textBytes) throw ExamFileError.Oef(OefProblem.TooLarge(OefLimit.TEXT, limits.textBytes))
        return reader.string(span)
    }

    private fun varint(tag: ProtobufReader.Tag, reader: ProtobufReader): Long {
        if (tag.wireType != ProtobufReader.WireType.VARINT) throw malformed(tag.offset)
        return reader.readVarint()
    }

    private fun count() {
        elements += 1
        if (elements > limits.elementCount) {
            throw ExamFileError.Oef(OefProblem.TooLarge(OefLimit.ELEMENTS, limits.elementCount.toLong()))
        }
    }

    private fun unknown(tag: ProtobufReader.Tag, reader: ProtobufReader, path: String) {
        reader.skip(tag.wireType)
        if (unknownFields.size >= limits.listedItems) return
        val fieldPath = "$path#${tag.field}"
        if (seenUnknown.add(fieldPath)) unknownFields += fieldPath
    }

    private fun malformed(offset: Int) = ExamFileError.Oef(OefProblem.Malformed(offset))
}

// ---------- Chuyển thành đề ----------

private class Converter(private val raw: RawExam, private val limits: OefLimits) {
    private val media = LinkedHashMap<String, ByteBuffer>()

    fun convert(): OefReader.Conversion {
        val title = OefReader.clean(raw.title)
        val code = OefReader.clean(raw.code).takeIf { it.isNotEmpty() && ExamValidator.isValidCode(it) }
        val passPercent = OefReader.passPercent(raw.passmark) ?: throw ExamFileError.Oef(OefProblem.PassmarkOutOfRange)

        val examId = OefReader.examId(code, title)
        val sections = ArrayList<ExamSection>()
        raw.sections.forEachIndexed { sectionIndex, rawSection ->
            if (rawSection.questions.isEmpty()) return@forEachIndexed
            val questions = rawSection.questions.mapIndexed { questionIndex, rawQuestion ->
                convertQuestion(
                    rawQuestion,
                    OefPlace(sectionIndex, questionIndex),
                    OefReader.questionId(examId, sectionIndex, questionIndex),
                )
            }
            sections += ExamSection(OefReader.sectionId(examId, sectionIndex), OefReader.clean(rawSection.title), questions)
        }
        if (sections.isEmpty()) throw ExamFileError.Oef(OefProblem.NoQuestions)

        val instructions = OefReader.markdown(raw.instructions)
        val exam = Exam(
            formatVersion = Exam.CURRENT_FORMAT_VERSION,
            id = examId,
            title = title,
            code = code,
            passPercent = passPercent.toLong(),
            timeLimitMinutes = raw.timeLimit.toLong(),
            hideAnswers = raw.hideAnswers,
            instructions = instructions.ifEmpty { null },
            sections = sections,
        )
        val errors = ExamValidator.validate(exam, availableMedia = media.keys).filter { it.severity == IssueSeverity.ERROR }
        if (errors.isNotEmpty()) throw ExamFileError.ValidationFailed(errors)
        return OefReader.Conversion(exam, media)
    }

    private fun convertQuestion(raw: RawQuestion, place: OefPlace, id: UUID): Question {
        val type = if (raw.isMultipleChoice) QuestionType.MULTIPLE else QuestionType.SINGLE
        // Câu không có lựa chọn: giữ để `ExamValidator` báo; không xét đáp án và ảnh.
        if (raw.options.isEmpty()) return Question(id, type, OefReader.markdown(raw.text), null, emptyList(), emptyList(), null)
        if (raw.options.size > MAX_OPTIONS) throw oef(OefProblem.TooManyOptions(place, raw.options.size))

        // Chữ cái → vị trí lựa chọn đầu tiên mang chữ đó; chữ trùng đầu tiên theo thứ tự lựa chọn.
        val position = HashMap<Long, Int>()
        var duplicate: Long? = null
        raw.options.forEachIndexed { index, option ->
            if (position.putIfAbsent(option.letter, index) != null && duplicate == null) duplicate = option.letter
        }
        duplicate?.let { throw oef(OefProblem.DuplicateOptionLetter(place, OefReader.letterName(it))) }

        val letters = if (raw.isMultipleChoice) raw.answers else if (raw.answer == 0L) emptyList() else listOf(raw.answer)
        val correct = sortedSetOf<Int>()
        val unmatched = ArrayList<String>()
        val unmatchedLetters = HashSet<Long>()
        for (letter in letters) {
            val index = position[letter]
            if (index != null) {
                correct += index
            } else if (unmatched.size < limits.listedItems && unmatchedLetters.add(letter)) {
                unmatched += OefReader.letterName(letter)
            }
        }
        if (unmatched.isNotEmpty()) throw oef(OefProblem.AnswerNotInOptions(place, unmatched))

        var imagePath: String? = null
        val span = raw.image
        if (span != null && span.size > 0) {
            if (span.size > limits.imageBytes) throw oef(OefProblem.ImageTooLarge(place, limits.imageBytes))
            val data = slice(span)
            val ext = OefReader.imageExtension(data) ?: throw oef(OefProblem.UnsupportedImage(place))
            val path = MediaNaming.path(data, ext)
            media[path] = data
            imagePath = path
        }

        val explanation = OefReader.markdown(raw.explanation)
        return Question(
            id = id,
            type = type,
            text = OefReader.markdown(raw.text),
            image = imagePath,
            options = raw.options.mapIndexed { index, option -> ExamOption(OptionId.at(index)!!, OefReader.markdown(option.text)) },
            correct = correct.map { OptionId.at(it)!! },
            explanation = explanation.ifEmpty { null },
        )
    }

    /** Ảnh: vùng byte chỉ đọc của file nguồn, không chép. */
    private fun slice(span: Span): ByteBuffer = raw.source.duplicate().apply {
        limit(span.end)
        position(span.start)
    }.slice()

    private fun oef(problem: OefProblem) = ExamFileError.Oef(problem)

    private companion object {
        const val MAX_OPTIONS = 26
    }
}
