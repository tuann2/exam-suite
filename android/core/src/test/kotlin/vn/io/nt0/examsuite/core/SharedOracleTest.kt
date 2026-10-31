package vn.io.nt0.examsuite.core

import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.boolean
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Assertions.fail
import org.junit.jupiter.api.Test
import org.junit.jupiter.params.ParameterizedTest
import org.junit.jupiter.params.provider.MethodSource
import vn.io.nt0.examsuite.core.composer.CompositionOptions
import vn.io.nt0.examsuite.core.composer.ExamComposer
import vn.io.nt0.examsuite.core.composer.QuestionSelection
import vn.io.nt0.examsuite.core.composer.SeededGenerator
import vn.io.nt0.examsuite.core.file.ExamDecoderAccess
import vn.io.nt0.examsuite.core.file.ExamFileError
import vn.io.nt0.examsuite.core.file.ExamPackageReader
import vn.io.nt0.examsuite.core.file.JsonProblem
import vn.io.nt0.examsuite.core.file.OefPlace
import vn.io.nt0.examsuite.core.file.OefProblem
import vn.io.nt0.examsuite.core.file.OefReader
import vn.io.nt0.examsuite.core.file.QuestionFingerprint
import vn.io.nt0.examsuite.core.model.ExamOption
import vn.io.nt0.examsuite.core.model.OptionId
import vn.io.nt0.examsuite.core.model.Question
import vn.io.nt0.examsuite.core.model.QuestionType
import vn.io.nt0.examsuite.core.validation.ExamValidator
import vn.io.nt0.examsuite.core.validation.IssueCode
import vn.io.nt0.examsuite.core.validation.IssueSeverity
import java.io.File
import java.nio.ByteBuffer
import java.security.MessageDigest
import java.util.UUID

/**
 * Oracle dùng chung với lõi Swift (plan-android-v1.md Phần 2): mỗi test tham số hoá đọc một file trong `fixtures/`, không
 * chép ca nào vào code. Đổi hành vi lõi thì sửa oracle trước, rồi hai lõi cùng xanh.
 */
class SharedOracleTest {
    companion object {
        private val verdictDoc = Repo.json("expected-verdicts.json").jsonObject
        private val invalidJsonDoc = Repo.json("invalid-json/expected.json").jsonObject
        private val composerDoc = Repo.json("vectors/composer.json").jsonObject
        private val fingerprintDoc = Repo.json("vectors/question-fingerprints.json").jsonObject

        @JvmStatic fun verdictKeys() = verdictDoc.getValue("verdicts").jsonObject.keys.sorted()

        @JvmStatic fun invalidJsonCases() = invalidJsonDoc.getValue("cases").jsonObject.keys.sorted()

        @JvmStatic fun compositionIndices() = composerDoc.getValue("compositions").jsonArray.indices.toList()

        private val packagesDoc = Repo.json("packages/expected.json").jsonObject

        @JvmStatic fun packageNames() = packagesDoc.getValue("cases").jsonObject.keys.sorted()

        private val oefDoc = Repo.json("oef/expected.json").jsonObject

        @JvmStatic fun oefNames() = oefDoc.getValue("files").jsonObject.keys.sorted()

        @JvmStatic fun sampleNames() = Repo.samples.list()!!.filter { File(Repo.samples, "$it/exam.json").isFile }.sorted()

        fun hex(text: String): ULong = text.removePrefix("0x").toULong(16)

        /** Tên mã như `IssueCode` của bản macOS (`DUPLICATE_ID` → `duplicateID`). */
        fun swiftName(code: IssueCode): String {
            val parts = code.name.lowercase().split('_')
            return (parts.first() + parts.drop(1).joinToString("") { it.replaceFirstChar(Char::uppercase) }).replace("Id", "ID")
        }

        /** Gói của khoá `exams/<tên>` (kèm media) hay `invalid/<tên>` (chỉ exam.json). */
        fun pack(key: String): File {
            val (group, name) = key.split('/', limit = 2)
            return if (group == "exams") Zip.pack(Repo.examDir(name)) else Zip.manifestOnly(File(Repo.fixtures, "invalid/$name.json").readBytes())
        }

        fun describe(error: ExamFileError): Pair<String, List<String>?> = when (error) {
            is ExamFileError.DuplicateJsonKeys -> "duplicateJSONKeys" to error.paths
            is ExamFileError.NullValues -> "nullValues" to error.paths
            is ExamFileError.UnknownFields -> "unknownFields" to error.paths
            is ExamFileError.TooDeep -> "tooDeep" to null
            is ExamFileError.InvalidVersion -> "invalidVersion" to null
            is ExamFileError.ValidationFailed -> "validationFailed" to error.issues.map { swiftName(it.code) }
            is ExamFileError.InvalidJson -> when (val p = error.problem) {
                is JsonProblem.TrailingCommas -> "trailingCommas" to p.paths
                is JsonProblem.Unparsable -> "unparsable" to null
                JsonProblem.NotUtf8 -> "notUTF8" to null
                JsonProblem.RootNotObject -> "rootNotObject" to null
                JsonProblem.MissingFormatVersion -> "missingFormatVersion" to null
                JsonProblem.FormatVersionNotInteger -> "formatVersionNotInteger" to null
                is JsonProblem.InvalidValue -> "invalidValue" to listOf(p.path)
                is JsonProblem.TypeMismatch -> "typeMismatch" to listOf(p.path)
                is JsonProblem.ValueMissing -> "valueMissing" to listOf(p.path)
                is JsonProblem.MissingKey -> "missingKey" to listOf(p.path, p.key)
            }
            else -> error.toString() to null
        }

        private val OefPlace.oracle get() = "$section/$question"

        /** Mã lỗi như `OEFReaderTests.code` của lõi Swift (`oef.malformed:3`, `validationFailed:titleEmpty,…`). */
        fun oefCode(error: Throwable): String = when (error) {
            is ExamFileError.Oef -> "oef." + when (val p = error.problem) {
                OefProblem.LegacyFormat -> "legacyFormat"
                is OefProblem.Malformed -> "malformed:${p.offset}"
                OefProblem.NoQuestions -> "noQuestions"
                is OefProblem.TooLarge -> "tooLarge:${p.limit.raw}:${p.value}"
                is OefProblem.ImageTooLarge -> "imageTooLarge:${p.place.oracle}:${p.limit}"
                is OefProblem.UnknownFields -> "unknownFields:" + p.paths.joinToString(",")
                OefProblem.PassmarkOutOfRange -> "passmarkOutOfRange"
                is OefProblem.UnsupportedImage -> "unsupportedImage:${p.place.oracle}"
                is OefProblem.TooManyOptions -> "tooManyOptions:${p.place.oracle}:${p.count}"
                is OefProblem.DuplicateOptionLetter -> "duplicateOptionLetter:${p.place.oracle}:${p.letter}"
                is OefProblem.AnswerNotInOptions -> "answerNotInOptions:${p.place.oracle}:" + p.letters.joinToString(",")
            }
            is ExamFileError.ValidationFailed -> "validationFailed:" + error.issues.joinToString(",") { swiftName(it.code) }
            else -> error.toString()
        }

        fun sha256Hex(data: ByteBuffer): String =
            MessageDigest.getInstance("SHA-256").apply { update(data.duplicate()) }.digest().joinToString("") { "%02x".format(it) }
    }

    // ---------- fixtures/expected-verdicts.json ----------

    @ParameterizedTest(name = "{0}")
    @MethodSource("verdictKeys")
    fun `kết luận theo expected-verdicts giống lõi Swift`(key: String) {
        val expected = verdictDoc.getValue("verdicts").jsonObject.getValue(key).jsonPrimitive.content
        val file = pack(key)
        val (group, name) = key.split('/', limit = 2)
        val json = if (group == "exams") File(Repo.examDir(name), "exam.json") else File(Repo.fixtures, "invalid/$name.json")
        val media = File(Repo.examDir(name), "media").list()?.map { "media/$it" }?.toSet() ?: emptySet()
        val strictError = runCatching { ExamPackageReader.readStrict(file) }.exceptionOrNull()

        val exam = runCatching { ExamDecoderAccess.decode(json.readBytes()) }.getOrNull()
        val actual = when {
            exam == null -> "undecodable"
            ExamValidator.validate(exam, media).any { it.severity == IssueSeverity.ERROR } -> "error"
            strictError != null -> "examfile"
            else -> "valid"
        }
        assertEquals(expected, actual, key)
        when (expected) {
            "valid" -> assertEquals(null, strictError, key)
            "undecodable" -> assertTrue(strictError is ExamFileError.InvalidJson, "$key: $strictError")
            // Bộ đọc nghiêm báo ảnh sai tên/thiếu trước bước kiểm đề (cùng thứ tự với bản macOS).
            "error" -> assertTrue(
                strictError is ExamFileError.ValidationFailed || strictError is ExamFileError.InvalidMediaPath ||
                    strictError is ExamFileError.MissingMedia,
                "$key: $strictError",
            )
            // examfile: model giải mã được nên InvalidJson ở đây chỉ có thể là dấu phẩy thừa (như test Swift).
            "examfile" -> assertTrue(
                strictError is ExamFileError.UnsupportedVersion || strictError is ExamFileError.InvalidVersion ||
                    strictError is ExamFileError.UnknownFields || strictError is ExamFileError.DuplicateJsonKeys ||
                    strictError is ExamFileError.NullValues ||
                    (strictError is ExamFileError.InvalidJson && strictError.problem is JsonProblem.TrailingCommas),
                "$key: $strictError",
            )
        }
    }

    @ParameterizedTest(name = "{0}")
    @MethodSource("verdictKeys")
    fun `mã vấn đề của fixture nhãn error đúng thứ tự như lõi Swift`(key: String) {
        val codes = verdictDoc.getValue("issueCodes").jsonObject[key] ?: return
        val name = key.substringAfter('/')
        val exam = ExamDecoderAccess.decode(File(Repo.fixtures, "invalid/$name.json").readBytes())
        assertEquals(codes.jsonArray.map { it.jsonPrimitive.content }, ExamValidator.validate(exam).map { swiftName(it.code) }, key)
    }

    @Test
    fun `khoảng trắng của lõi Kotlin đúng khoá whiteSpace (25 code point), không gồm ZWSP, U+001C, U+180E, U+FEFF`() {
        val listed = verdictDoc.getValue("whiteSpace").jsonArray.flatMap { entry ->
            val parts = entry.jsonPrimitive.content.split('-')
            (parts.first().toInt(16)..parts.last().toInt(16)).toList()
        }.toSet()
        assertEquals(25, listed.size)
        val blank = (0..0x3000).filter { ExamValidator.isBlank(String(Character.toChars(it))) }.toSet()
        assertEquals(listed, blank)
        for (cp in listOf(0x200B, 0x1C, 0x1F, 0x180E, 0xFEFF)) assertTrue(!ExamValidator.isBlank(String(Character.toChars(cp))))
    }

    @Test
    fun `đề biên khoảng trắng chỉ có hai warning như lõi Swift`() {
        val issues = ExamValidator.validate(Repo.exam("bien-khoang-trang"), availableMedia = emptySet())
        assertEquals(listOf(IssueCode.DUPLICATE_SECTION_TITLE, IssueCode.MULTIPLE_HAS_SINGLE_CORRECT), issues.map { it.code })
    }

    // ---------- fixtures/invalid-json ----------

    @ParameterizedTest(name = "{0}")
    @MethodSource("invalidJsonCases")
    fun `ca JSON dùng chung, đọc nghiêm ra đúng lỗi và đường dẫn như lõi Swift`(name: String) {
        val expected = invalidJsonDoc.getValue("cases").jsonObject.getValue(name).jsonObject
        val error = expected["error"]?.takeUnless { it is JsonNull }?.jsonPrimitive?.content
        val paths = expected["paths"]?.jsonArray?.map { it.jsonPrimitive.content }
        val file = Zip.manifestOnly(File(Repo.fixtures, "invalid-json/$name.json").readBytes())
        try {
            ExamPackageReader.readStrict(file)
            assertEquals(null, error, "$name: đọc được")
        } catch (e: ExamFileError) {
            val (actualName, actualPaths) = describe(e)
            assertEquals(error, actualName, "$name: $e")
            assertEquals(paths, actualPaths, name)
        }
    }

    @Test
    fun `mỗi file invalid-json có đúng một dòng kỳ vọng`() {
        val files = File(Repo.fixtures, "invalid-json").list()!!.filter { it.endsWith(".json") && it != "expected.json" }.map { it.removeSuffix(".json") }
        assertEquals(invalidJsonCases().toSet(), files.toSet())
    }

    // ---------- fixtures/packages ----------

    @ParameterizedTest(name = "{0}")
    @MethodSource("packageNames")
    fun `gói nhị phân dùng chung đọc nghiêm đúng kỳ vọng như lõi Swift`(name: String) {
        val expected = packagesDoc.getValue("cases").jsonObject.getValue(name).jsonObject
        val error = expected["error"]?.takeUnless { it is JsonNull }?.jsonPrimitive?.content
        val result = runCatching { ExamPackageReader.readStrict(File(Repo.fixtures, "packages/$name.exam")) }
        if (error == null) {
            val package_ = result.getOrThrow()
            expected["questions"]?.let { assertEquals(it.jsonPrimitive.int, package_.exam.questionCount, name) }
        } else {
            assertTrue(result.isFailure, name)
        }
    }

    @Test
    fun `mỗi gói trong fixtures packages có đúng một dòng kỳ vọng`() {
        val files = File(Repo.fixtures, "packages").list()!!.filter { it.endsWith(".exam") }.map { it.removeSuffix(".exam") }
        assertEquals(packageNames().toSet(), files.toSet())
    }

    // ---------- fixtures/oef (lõi Kotlin chỉ đọc nghiêm: so phần strict) ----------

    @ParameterizedTest(name = "{0}")
    @MethodSource("oefNames")
    fun `file oef đọc nghiêm ra đề hoặc mã lỗi như lõi Swift`(name: String) {
        val expected = oefDoc.getValue("files").jsonObject.getValue(name).jsonObject.getValue("strict").jsonObject
        val result = runCatching { OefReader.read(File(Repo.fixtures, "oef/$name.oef")) }
        expected["error"]?.let {
            assertEquals(it.jsonPrimitive.content, result.exceptionOrNull()?.let(::oefCode) ?: "ok", name)
            return
        }
        val conversion = result.getOrThrow()
        assertEquals(ExamDecoderAccess.decode(expected.getValue("exam").toString().toByteArray()), conversion.exam, name)
        assertEquals(expected.getValue("media").jsonArray.map { it.jsonPrimitive.content }.toSet(), conversion.media.keys, name)
        for ((path, data) in conversion.media) assertTrue(path.startsWith("media/${sha256Hex(data).take(16)}."), path)
    }

    @Test
    fun `mỗi file oef có đúng một dòng kỳ vọng`() {
        val files = File(Repo.fixtures, "oef").list()!!.filter { it.endsWith(".oef") }.map { it.removeSuffix(".oef") }
        assertEquals(oefNames().toSet(), files.toSet())
        assertTrue(files.size >= 32)
    }

    @Test
    fun `vector của oef (id dẫn xuất, Markdown, ngưỡng đậu, loại ảnh, tên chữ cái)`() {
        val v = oefDoc.getValue("vectors").jsonObject
        for (id in v.getValue("ids").jsonArray.map { it.jsonObject }) {
            assertEquals(id.getValue("uuid").jsonPrimitive.content, OefReader.derivedId(id.getValue("name").jsonPrimitive.content).toString())
        }
        val any = OefReader.derivedId("x").toString()
        assertEquals('8', any[14], "phiên bản 8")
        assertTrue(any[19] in "89ab", "biến thể RFC 9562")
        for (m in v.getValue("markdown").jsonArray.map { it.jsonObject }) {
            assertEquals(m.getValue("markdown").jsonPrimitive.content, OefReader.markdown(m.getValue("plain").jsonPrimitive.content))
        }
        for (pair in v.getValue("passmark").jsonArray.map { it.jsonArray }) {
            assertEquals(pair[1].jsonPrimitive.content.toDouble().toInt(), OefReader.passPercent(pair[0].jsonPrimitive.content.toDouble()), pair.toString())
        }
        for (value in v.getValue("passmarkOutOfRange").jsonArray) {
            assertEquals(null, OefReader.passPercent(value.jsonPrimitive.content.toDouble()), value.toString())
        }
        assertEquals(null, OefReader.passPercent(Double.NaN))
        assertEquals(null, OefReader.passPercent(Double.POSITIVE_INFINITY))
        for (kind in v.getValue("imageKinds").jsonArray.map { it.jsonObject }) {
            val head = kind.getValue("head").jsonPrimitive.content.chunked(2).map { it.toInt(16).toByte() }.toByteArray()
            val ext = kind.getValue("ext").takeUnless { it is JsonNull }?.jsonPrimitive?.content
            assertEquals(ext, OefReader.imageExtension(ByteBuffer.wrap(head)), kind.toString())
        }
        for (pair in v.getValue("letters").jsonArray.map { it.jsonArray }) {
            assertEquals(pair[1].jsonPrimitive.content, OefReader.letterName(pair[0].jsonPrimitive.content.toLong()))
        }
    }

    // ---------- fixtures/vectors/composer.json ----------

    @Test
    fun `SplitMix64 next() và nextInt() đúng vector cố định`() {
        for (v in composerDoc.getValue("splitmix64").jsonArray.map { it.jsonObject }) {
            val g = SeededGenerator(hex(v.getValue("seed").jsonPrimitive.content))
            val expected = v.getValue("next").jsonArray.map { hex(it.jsonPrimitive.content) }
            assertEquals(expected, expected.map { g.next() })
        }
        for (v in composerDoc.getValue("nextInt").jsonArray.map { it.jsonObject }) {
            val g = SeededGenerator(hex(v.getValue("seed").jsonPrimitive.content))
            val bound = hex(v.getValue("bound").jsonPrimitive.content).toLong()
            val expected = v.getValue("values").jsonArray.map { hex(it.jsonPrimitive.content).toLong() }
            assertEquals(expected, expected.map { g.nextInt(bound) })
        }
    }

    @ParameterizedTest(name = "chọn câu #{0}")
    @MethodSource("compositionIndices")
    fun `chọn câu và xáo đúng vector cố định`(index: Int) {
        val v = composerDoc.getValue("compositions").jsonArray[index].jsonObject
        val o = v.getValue("options").jsonObject
        val sel = o.getValue("selection").jsonObject
        val selection = when (sel.getValue("kind").jsonPrimitive.content) {
            "random" -> QuestionSelection.Random(sel.getValue("count").jsonPrimitive.int)
            else -> QuestionSelection.All
        }
        val options = CompositionOptions(selection, o.getValue("shuffleQuestions").jsonPrimitive.boolean,
            o.getValue("shuffleOptions").jsonPrimitive.boolean, hex(o.getValue("seed").jsonPrimitive.content))
        val paper = ExamComposer.compose(Repo.exam(v.getValue("exam").jsonPrimitive.content.substringAfter('/')), options)
        val name = v.getValue("name").jsonPrimitive.content
        assertEquals(v.getValue("questionIDs").jsonArray.map { it.jsonPrimitive.content }, paper.questionIds.map { it.toString() }, name)
        assertEquals(v.getValue("optionOrders").jsonArray.map { it.jsonPrimitive.content }, paper.items.map { it.optionOrder.joinToString("") }, name)
        (v["sectionIDs"] as? JsonArray)?.let { assertEquals(it.map { s -> s.jsonPrimitive.content }, paper.items.map { i -> i.sectionId.toString() }, name) }
    }

    // ---------- fixtures/vectors/question-fingerprints.json ----------

    @Test
    fun `dấu vân tay câu đúng vector cố định, dạng chuẩn đúng từng byte`() {
        val vectors = fingerprintDoc.getValue("vectors").jsonArray.map { it.jsonObject }
        assertEquals(3, vectors.size)
        for (v in vectors) {
            val q = v.getValue("question").jsonObject
            val question = Question(
                id = UUID.fromString(q.getValue("id").jsonPrimitive.content),
                type = QuestionType.fromRaw(q.getValue("type").jsonPrimitive.content)!!,
                text = q.getValue("text").jsonPrimitive.content,
                image = q["image"]?.jsonPrimitive?.content,
                options = q.getValue("options").jsonArray.map { ExamOption(OptionId.of(it.jsonObject.getValue("id").jsonPrimitive.content)!!, it.jsonObject.getValue("text").jsonPrimitive.content) },
                correct = q.getValue("correct").jsonArray.map { OptionId.of(it.jsonPrimitive.content)!! },
                explanation = q["explanation"]?.jsonPrimitive?.content,
            )
            val name = v.getValue("name").jsonPrimitive.content
            v["canonical"]?.let { assertEquals(it.jsonPrimitive.content, QuestionFingerprint.canonicalJson(question), name) }
            assertEquals(v.getValue("sha256").jsonPrimitive.content, QuestionFingerprint.fingerprint(question), name)
        }
    }

    // ---------- schema và đề mẫu ----------

    @Test
    fun `khoá hợp lệ của từng cấp trùng properties của schema`() {
        val schema = kotlinx.serialization.json.Json.parseToJsonElement(File(Repo.root, "schema/exam-v1.schema.json").readText()).jsonObject
        fun props(obj: JsonObject) = obj.getValue("properties").jsonObject.keys
        val defs = (schema["\$defs"] ?: schema["definitions"])!!.jsonObject
        assertEquals(props(schema), vn.io.nt0.examsuite.core.file.SchemaKeysAccess.exam)
        val found = defs.values.map { it.jsonObject }.filter { "properties" in it }.map { props(it) }.toSet()
        for (level in listOf(vn.io.nt0.examsuite.core.file.SchemaKeysAccess.section, vn.io.nt0.examsuite.core.file.SchemaKeysAccess.question,
            vn.io.nt0.examsuite.core.file.SchemaKeysAccess.option)) {
            assertTrue(level in found, "không thấy cấp $level trong schema: $found")
        }
    }

    @ParameterizedTest(name = "{0}")
    @MethodSource("sampleNames")
    fun `đề mẫu của Thư viện đọc nghiêm được, không có cả warning`(name: String) {
        val package_ = ExamPackageReader.readStrict(Zip.pack(File(Repo.samples, name)))
        val issues = ExamValidator.validate(package_.exam, package_.mediaPaths)
        if (issues.isNotEmpty()) fail<Unit>("$name: $issues")
    }
}
