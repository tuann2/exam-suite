package vn.io.nt0.examsuite

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.json.JSONObject
import vn.io.nt0.examsuite.core.file.ExamDecoderAccess
import vn.io.nt0.examsuite.core.file.ExamFileError
import vn.io.nt0.examsuite.core.file.ExamPackageReader
import vn.io.nt0.examsuite.core.file.OefProblem
import vn.io.nt0.examsuite.core.file.OefReader
import vn.io.nt0.examsuite.data.library.LibraryItem
import vn.io.nt0.examsuite.data.library.LibraryQuery
import vn.io.nt0.examsuite.data.library.LibrarySort
import java.io.File
import java.util.UUID

/**
 * Hành vi của nền tảng mà test JVM không thấy (không mở màn hình): đọc gói dùng chung `fixtures/packages` trên ART (Android
 * 14+ có ZipPathValidator, app tắt ở Application), sắp xếp tên tiếng Việt bằng ICU của Android, và đọc `.oef` của oracle
 * `fixtures/oef` (giải mã UTF-8, NFC của ART khác JDK).
 */
@RunWith(AndroidJUnit4::class)
class PlatformTest {
    @Test
    fun sharedPackagesReadStrictlyOnDevice() {
        val assets = InstrumentationRegistry.getInstrumentation().context.assets
        for (name in listOf("pack-exam-py.exam", "non-utf8-junk-name.exam")) {
            val file = File(Flow.app.cacheDir, name)
            assets.open(name).use { input -> file.outputStream().use { input.copyTo(it) } }
            assertEquals(name, 5, ExamPackageReader.readStrict(file).exam.questionCount)
        }
    }

    /** Phần đọc nghiêm của `fixtures/oef/expected.json`, như `SharedOracleTest` trên JVM (file là Java resource của test). */
    @Test
    fun oefOracleReadsStrictlyOnDevice() {
        fun resource(name: String) = requireNotNull(javaClass.classLoader?.getResourceAsStream(name)) { name }.use { it.readBytes() }
        val files = JSONObject(resource("expected.json").decodeToString()).getJSONObject("files")
        var checked = 0
        for (name in files.keys()) {
            val expected = files.getJSONObject(name).getJSONObject("strict")
            val result = runCatching { OefReader.convert(resource("$name.oef")) }
            checked++
            if (expected.has("error")) {
                assertEquals(name, expected.getString("error"), result.exceptionOrNull()?.let(::oefCode) ?: "ok")
                continue
            }
            val conversion = result.getOrThrow()
            assertEquals(name, ExamDecoderAccess.decode(expected.getJSONObject("exam").toString().toByteArray()), conversion.exam)
            val media = expected.getJSONArray("media").let { array -> (0 until array.length()).map { array.getString(it) }.toSet() }
            assertEquals(name, media, conversion.media.keys)
        }
        assertEquals(32, checked)
    }

    /** Mã lỗi như oracle (`oef.malformed:4`, `validationFailed:titleEmpty,…`); tên mã vấn đề theo bản macOS. */
    private fun oefCode(error: Throwable): String = when (error) {
        is ExamFileError.Oef -> "oef." + when (val p = error.problem) {
            OefProblem.LegacyFormat -> "legacyFormat"
            is OefProblem.Malformed -> "malformed:${p.offset}"
            OefProblem.NoQuestions -> "noQuestions"
            is OefProblem.TooLarge -> "tooLarge:${p.limit.raw}:${p.value}"
            is OefProblem.ImageTooLarge -> "imageTooLarge:${p.place.section}/${p.place.question}:${p.limit}"
            is OefProblem.UnknownFields -> "unknownFields:" + p.paths.joinToString(",")
            OefProblem.PassmarkOutOfRange -> "passmarkOutOfRange"
            is OefProblem.UnsupportedImage -> "unsupportedImage:${p.place.section}/${p.place.question}"
            is OefProblem.TooManyOptions -> "tooManyOptions:${p.place.section}/${p.place.question}:${p.count}"
            is OefProblem.DuplicateOptionLetter -> "duplicateOptionLetter:${p.place.section}/${p.place.question}:${p.letter}"
            is OefProblem.AnswerNotInOptions -> "answerNotInOptions:${p.place.section}/${p.place.question}:" + p.letters.joinToString(",")
        }
        is ExamFileError.ValidationFailed -> "validationFailed:" + error.issues.joinToString(",") { issue ->
            val parts = issue.code.name.lowercase().split('_')
            (parts.first() + parts.drop(1).joinToString("") { it.replaceFirstChar(Char::uppercase) }).replace("Id", "ID")
        }
        else -> error.toString()
    }

    @Test
    fun vietnameseTitleOrderOnIcu() {
        fun item(title: String) = LibraryItem(
            UUID.nameUUIDFromBytes(title.toByteArray()), title, null, 1, 1, 0, 10, 50, false, 1, 1, 0, 0, false, null,
        )
        val titles = listOf("Đê", "Bê", "Ân", "An", "Dê", "Ăn")
        assertEquals(listOf("An", "Ăn", "Ân", "Bê", "Dê", "Đê"), LibraryQuery.sort(titles.map(::item), LibrarySort.TITLE).map { it.title })
    }
}
