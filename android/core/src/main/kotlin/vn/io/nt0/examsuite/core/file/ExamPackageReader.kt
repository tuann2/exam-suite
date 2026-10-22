package vn.io.nt0.examsuite.core.file

import vn.io.nt0.examsuite.core.json.JsonObject
import vn.io.nt0.examsuite.core.json.JsonSyntaxException
import vn.io.nt0.examsuite.core.json.StrictJson
import vn.io.nt0.examsuite.core.validation.ExamValidator
import vn.io.nt0.examsuite.core.validation.IssueSeverity
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.IOException
import java.io.InputStream
import java.util.zip.CRC32
import java.util.zip.ZipEntry
import java.util.zip.ZipFile

/**
 * Đọc gói `.exam` ở chế độ **nghiêm** của bản Học viên (docs/product/exam-format.md), cùng kết luận với
 * `ExamPackageReader.read(_, mode: .strict)` của bản macOS trên oracle chung (fixtures/expected-verdicts.json,
 * fixtures/invalid-json). Thứ tự kiểm giữ nguyên như bản macOS:
 *
 * zip mở được → entry (đếm mọi entry, trùng tên `exam.json`/ảnh thì từ chối) → có `exam.json` → giải nén có trần →
 * độ sâu ≤ trần → UTF-8 → phân tích JSON → gốc là object → `formatVersion` → chuyển phiên bản → dấu phẩy thừa → khoá
 * trùng → trường lạ → `null` → giải mã model → kiểm từng ảnh (trần, CRC) → đường dẫn ảnh → ảnh thiếu → kiểm đề.
 *
 * Khác bản macOS: dùng `java.util.zip.ZipFile` (đọc mục lục trung tâm như ZIPFoundation, tên không cờ UTF-8 đọc bằng
 * bảng mã một byte như ZIPFoundation). Tên **có** cờ UTF-8 mà byte không phải UTF-8 (công cụ đặt cờ sai): ZIPFoundation
 * coi tên là rỗng và bỏ entry, `ZipFile` từ chối cả gói (lệch đã biết, Decisions). Trên Android 14+ (ART, targetSdk ≥ 34) `ZipFile` còn từ chối entry tên chứa `..` hoặc bắt
 * đầu bằng `/` (ZipPathValidator) trước khi bộ đọc kịp bỏ qua; app xử lý ở A3a (Decisions). `ZipFile` không cho biết
 * entry là symlink, nên entry symlink được đọc như file thường (nội dung là chữ của đường dẫn đích, không theo liên kết,
 * không chạm hệ thống file); bản macOS bỏ qua chúng. Kết luận chỉ khác ở gói cố tình đặt symlink tên `exam.json` hoặc
 * tên ảnh hợp lệ: cả hai bản đều từ chối hoặc không hiển thị được ảnh đó.
 */
object ExamPackageReader {
    fun readStrict(file: File, limits: ExamPackageLimits = ExamPackageLimits.DEFAULT): ExamPackage =
        openZip(file).use { zip -> read(zip, limits) }

    /** Ảnh của đề đã đọc nghiêm từ chính file đó, kiểm lại trần và CRC. */
    fun readMedia(file: File, path: String, limits: ExamPackageLimits = ExamPackageLimits.DEFAULT): ByteArray =
        openZip(file).use { zip ->
            require(MediaNaming.isValidPath(path)) { "đường dẫn ảnh sai: $path" }
            val entry = zip.getEntry(path) ?: throw ExamFileError.MissingMedia(listOf(path))
            extract(zip, entry, limits.mediaEntryBytes, Budget(limits.totalUncompressedBytes), keep = true)!!
        }

    /**
     * Tên entry không có cờ UTF-8 (bit 11) đọc bằng bảng mã một byte (ZIPFoundation của bản macOS dùng CP437); tên có cờ
     * đọc bằng UTF-8. Mặc định UTF-8 của `ZipFile` từ chối cả gói khi một entry lạ (zip tạo trên Windows) có tên không
     * phải UTF-8, trong khi entry lạ phải được bỏ qua (exam-format.md; review độc lập PR #2, B1; oracle fixtures/packages).
     * Dùng ISO-8859-1 thay CP437 vì có sẵn trên mọi JVM và ART: chỉ tên ASCII (`exam.json`, `media/<hex>.<ext>`) có nghĩa,
     * và mọi bảng mã một byte tương thích ASCII cho cùng kết luận.
     */
    private val legacyNames = Charsets.ISO_8859_1

    private fun openZip(file: File): ZipFile = try {
        ZipFile(file, ZipFile.OPEN_READ, legacyNames)
    } catch (_: IOException) {
        throw ExamFileError.NotAZipArchive
    } catch (_: IllegalArgumentException) {
        throw ExamFileError.NotAZipArchive
    }

    private fun read(zip: ZipFile, limits: ExamPackageLimits): ExamPackage {
        var manifest: ZipEntry? = null
        val media = mutableListOf<ZipEntry>()
        val mediaNames = HashSet<String>()
        var count = 0
        val entries = try {
            zip.entries().toList()
        } catch (_: IllegalArgumentException) {
            throw ExamFileError.NotAZipArchive
        }
        for (entry in entries) {
            count += 1
            if (count > limits.entryCount) {
                throw ExamFileError.TooLarge(ExamPackageLimits.ENTRY_COUNT_NAME, limits.entryCount.toLong())
            }
            if (entry.isDirectory) continue
            when {
                entry.name == ExamFormat.MANIFEST_NAME -> {
                    if (manifest != null) throw ExamFileError.DuplicateEntry(entry.name)
                    manifest = entry
                }
                MediaNaming.isValidPath(entry.name) -> {
                    if (!mediaNames.add(entry.name)) throw ExamFileError.DuplicateEntry(entry.name)
                    media += entry
                }
            }
        }
        val manifestEntry = manifest ?: throw ExamFileError.MissingManifest

        val budget = Budget(limits.totalUncompressedBytes)
        val bytes = extract(zip, manifestEntry, limits.manifestBytes, budget, keep = true)!!
        val root = parseManifest(bytes, limits)
        val exam = try {
            ExamDecoder.decode(root)
        } catch (e: DecodeException) {
            throw ExamFileError.InvalidJson(e.problem)
        }

        // Kiểm mọi ảnh có tên hợp lệ (trần, CRC) như bản macOS giải nén chúng; không giữ dữ liệu.
        for (entry in media) extract(zip, entry, limits.mediaEntryBytes, budget, keep = false)

        val seen = HashSet<String>()
        val images = exam.allQuestions.mapNotNull { it.image }
        val invalid = images.filter { !MediaNaming.isValidPath(it) && seen.add(it) }
        if (invalid.isNotEmpty()) throw ExamFileError.InvalidMediaPath(invalid)
        val missing = images.distinct().filter { it !in mediaNames }
        if (missing.isNotEmpty()) throw ExamFileError.MissingMedia(missing)
        val errors = ExamValidator.validate(exam, availableMedia = mediaNames).filter { it.severity == IssueSeverity.ERROR }
        if (errors.isNotEmpty()) throw ExamFileError.ValidationFailed(errors)
        return ExamPackage(exam, mediaNames.toSet())
    }

    /** Từ byte của `exam.json` tới object gốc đã qua mọi kiểm của chế độ nghiêm trước bước giải mã model. */
    internal fun parseManifest(bytes: ByteArray, limits: ExamPackageLimits = ExamPackageLimits.DEFAULT): JsonObject {
        if (StrictJson.depthExceeds(bytes, limits.maxJsonDepth)) throw ExamFileError.TooDeep(limits.maxJsonDepth)
        val text = StrictJson.decodeUtf8(bytes) ?: throw ExamFileError.InvalidJson(JsonProblem.NotUtf8)
        val parsed = try {
            StrictJson.parse(text)
        } catch (e: JsonSyntaxException) {
            throw ExamFileError.InvalidJson(JsonProblem.Unparsable(e.message ?: ""))
        }
        val root = parsed.root as? JsonObject ?: throw ExamFileError.InvalidJson(JsonProblem.RootNotObject)

        val versionValue = root.entries["formatVersion"] ?: throw ExamFileError.InvalidJson(JsonProblem.MissingFormatVersion)
        val version = try {
            ExamDecoder.asLong(versionValue, "formatVersion")
        } catch (_: DecodeException) {
            throw ExamFileError.InvalidJson(JsonProblem.FormatVersionNotInteger)
        }
        if (version > ExamFormat.CURRENT_VERSION) throw ExamFileError.UnsupportedVersion(version, ExamFormat.CURRENT_VERSION)
        if (version < 1) throw ExamFileError.InvalidVersion(version)
        // v1 là phiên bản đầu: chưa có bước chuyển nào. Khi có v2, thêm bước v1 → v2 ở đây (kèm fixture, test).
        if (version < ExamFormat.CURRENT_VERSION) throw ExamFileError.MigrationFailed(version, MigrationProblem.MISSING_STEP)

        if (parsed.trailingCommas.isNotEmpty()) throw ExamFileError.InvalidJson(JsonProblem.TrailingCommas(parsed.trailingCommas))
        if (parsed.duplicateKeys.isNotEmpty()) throw ExamFileError.DuplicateJsonKeys(parsed.duplicateKeys)
        val unknown = ExamSchemaKeys.unknownFieldPaths(root)
        if (unknown.isNotEmpty()) throw ExamFileError.UnknownFields(unknown)
        val nulls = ExamSchemaKeys.nullValuePaths(root)
        if (nulls.isNotEmpty()) throw ExamFileError.NullValues(nulls)
        return root
    }

    private class Budget(val total: Long) {
        var used = 0L
    }

    /**
     * Giải nén một entry có trần: kích thước khai báo vượt trần entry hoặc làm tổng vượt trần → `TooLarge` trước khi giải
     * nén; dữ liệu thật dài hơn khai báo, CRC sai, luồng hỏng → `CorruptedEntry`. `java.util.zip.ZipFile` không tự so
     * CRC nên so ở đây (như bản macOS né lỗi của ZIPFoundation).
     */
    private fun extract(zip: ZipFile, entry: ZipEntry, entryLimit: Long, budget: Budget, keep: Boolean): ByteArray? {
        val declared = entry.size
        if (declared < 0) throw ExamFileError.CorruptedEntry(entry.name)
        if (declared > entryLimit) throw ExamFileError.TooLarge(entry.name, entryLimit)
        if (budget.used + declared > budget.total) {
            throw ExamFileError.TooLarge(ExamPackageLimits.TOTAL_SIZE_NAME, budget.total)
        }
        val crc = CRC32()
        val out = if (keep) ByteArrayOutputStream(declared.toInt()) else null
        var total = 0L
        try {
            zip.getInputStream(entry).use { input: InputStream ->
                val buffer = ByteArray(64 * 1024)
                while (true) {
                    val n = input.read(buffer)
                    if (n < 0) break
                    total += n
                    if (total > declared) throw ExamFileError.CorruptedEntry(entry.name)
                    crc.update(buffer, 0, n)
                    out?.write(buffer, 0, n)
                }
            }
        } catch (e: ExamFileError) {
            throw e
        } catch (_: Exception) {
            throw ExamFileError.CorruptedEntry(entry.name)
        }
        if (total != declared || crc.value != entry.crc) throw ExamFileError.CorruptedEntry(entry.name)
        budget.used += total
        return out?.toByteArray()
    }
}
