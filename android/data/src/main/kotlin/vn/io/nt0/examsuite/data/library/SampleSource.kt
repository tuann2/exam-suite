package vn.io.nt0.examsuite.data.library

import android.content.res.AssetManager

/** Nguồn đề mẫu: mỗi đề là một thư mục (`exam.json` + `media/`), như `Packages/.../LibraryData/Resources/Samples`. */
interface SampleSource {
    fun names(): List<String>

    /** Các file của đề, đường dẫn trong gói (`exam.json`, `media/<tên>`) kèm nội dung, theo thứ tự tên. */
    fun files(name: String): List<Pair<String, ByteArray>>
}

/**
 * Đề mẫu đóng trong assets của `:data` (thư mục Samples dùng chung với bản macOS, cấu hình ở build.gradle.kts). Mỗi thư
 * mục gốc có `exam.json` là một đề (quy tắc đề mẫu của library.md).
 */
class AssetSampleSource(private val assets: AssetManager) : SampleSource {
    /**
     * Thư mục gốc có `exam.json`. `AssetManager.list` của Android trả tên con trực tiếp, của Robolectric trả đường dẫn
     * đệ quy: lấy đoạn đầu rồi thử mở `exam.json` để đúng ở cả hai (gốc assets còn có thư mục hệ thống như `images`).
     */
    override fun names(): List<String> = assets.list("")!!.map { it.substringBefore('/') }.distinct()
        .filter { name -> runCatching { assets.open("$name/$EXAM_FILE").close() }.isSuccess }
        .sorted()

    override fun files(name: String): List<Pair<String, ByteArray>> {
        val files = mutableListOf(EXAM_FILE to assets.open("$name/$EXAM_FILE").use { it.readBytes() })
        assets.list("$name/media")?.map { it.substringAfterLast('/') }?.distinct()?.sorted()?.forEach { media ->
            files += "media/$media" to assets.open("$name/media/$media").use { it.readBytes() }
        }
        return files
    }

    companion object {
        const val EXAM_FILE = "exam.json"
    }
}
