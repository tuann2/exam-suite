package vn.io.nt0.examsuite.core.file

import java.nio.ByteBuffer
import java.nio.charset.CharacterCodingException
import java.nio.charset.CodingErrorAction

/** Vùng byte `[start, end)` của một trường độ dài, tính từ đầu file. */
internal class Span(val start: Int, val end: Int) {
    val size: Int get() = end - start
}

/**
 * Đọc dây Protobuf (https://protobuf.dev/programming-guides/encoding/) có kiểm biên, cho file `.oef`
 * (docs/product/exam-format.md, mục File `.oef`). Cùng luật với `ProtobufReader` của bản macOS; tự viết vì ADR 0012 không
 * cho thêm thư viện. Đọc theo vị trí tuyệt đối trên `ByteBuffer` (file ánh xạ bộ nhớ: đề nhiều ảnh không nằm trong heap).
 * Mọi độ dài được so với phần còn lại của thông điệp; sai lệch nào cũng là `OefProblem.Malformed` với vị trí byte tính
 * từ đầu file.
 */
internal class ProtobufReader(private val bytes: ByteBuffer, start: Int, val end: Int) {
    enum class WireType { VARINT, FIXED64, LENGTH_DELIMITED, FIXED32 }

    /** `offset`: vị trí byte đầu của khoá trong file. */
    class Tag(val field: Int, val wireType: WireType, val offset: Int)

    var position: Int = start
        private set

    val isAtEnd: Boolean get() = position >= end

    /** Khoá kế tiếp; null khi hết thông điệp. Kiểu dây nhóm (3, 4), 6, 7 và số trường 0 hay quá 2^29 − 1 là dây hỏng. */
    fun nextTag(): Tag? {
        if (isAtEnd) return null
        val offset = position
        val key = readVarint()
        val wireType = when ((key and 7).toInt()) {
            0 -> WireType.VARINT
            1 -> WireType.FIXED64
            2 -> WireType.LENGTH_DELIMITED
            5 -> WireType.FIXED32
            else -> throw malformed(offset)
        }
        val field = key ushr 3
        if (field == 0L || field > 0x1FFF_FFFFL) throw malformed(offset)
        return Tag(field.toInt(), wireType, offset)
    }

    /** Varint tối đa 10 byte; byte thứ 10 chỉ được mang bit cuối của số 64 bit. Giá trị là 64 bit không dấu. */
    fun readVarint(): Long {
        val start = position
        var value = 0L
        var shift = 0
        while (true) {
            if (position >= end) throw malformed(start)
            val byte = bytes.get(position).toInt() and 0xFF
            position += 1
            if (shift == 63 && byte > 1) throw malformed(start)
            value = value or ((byte and 0x7F).toLong() shl shift)
            if (byte and 0x80 == 0) return value
            shift += 7
            if (shift > 63) throw malformed(start)
        }
    }

    fun readFixed64(): Long {
        if (end - position < 8) throw malformed(position)
        var value = 0L
        for (i in 0 until 8) value = value or ((bytes.get(position + i).toLong() and 0xFF) shl (8 * i))
        position += 8
        return value
    }

    /** Vùng byte của một trường độ dài; con trỏ nhảy qua vùng đó. */
    fun readLengthDelimited(): Span {
        val start = position
        val length = readVarint()
        if (length < 0 || length > (end - position).toLong()) throw malformed(start)
        val span = Span(position, position + length.toInt())
        position = span.end
        return span
    }

    /** Bỏ qua giá trị của trường (trường lạ). */
    fun skip(wireType: WireType) {
        when (wireType) {
            WireType.VARINT -> readVarint()
            WireType.FIXED64 -> readFixed64()
            WireType.LENGTH_DELIMITED -> readLengthDelimited()
            WireType.FIXED32 -> {
                if (end - position < 4) throw malformed(position)
                position += 4
            }
        }
    }

    /** Chuỗi UTF-8 hợp lệ trong `span`; không hợp lệ là dây hỏng tại đầu vùng. */
    fun string(span: Span): String = try {
        Charsets.UTF_8.newDecoder()
            .onMalformedInput(CodingErrorAction.REPORT)
            .onUnmappableCharacter(CodingErrorAction.REPORT)
            .decode(slice(span))
            .toString()
    } catch (_: CharacterCodingException) {
        throw malformed(span.start)
    }

    /** Vùng byte chỉ đọc, không chép. */
    fun slice(span: Span): ByteBuffer = bytes.duplicate().apply {
        limit(span.end)
        position(span.start)
    }.slice()

    /** Bộ đọc cho thông điệp con nằm trong `span`. */
    fun nested(span: Span) = ProtobufReader(bytes, span.start, span.end)

    private fun malformed(offset: Int) = ExamFileError.Oef(OefProblem.Malformed(offset))
}
