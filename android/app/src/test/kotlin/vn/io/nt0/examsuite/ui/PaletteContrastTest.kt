package vn.io.nt0.examsuite.ui

import androidx.compose.material3.ColorScheme
import androidx.compose.material3.surfaceColorAtElevation
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.compositeOver
import androidx.compose.ui.unit.dp
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.pow
import kotlin.math.roundToInt

/**
 * Tương phản của bảng màu riêng (`ExamPalette`) và nền nhạt pha màu trên nền Material 3 thật của app, sáng và tối
 * (library.md phương án 8, accessibility-localization.md; như `PaletteContrastTests` của bản macOS). Chữ nhỏ ≥ 4,5:1,
 * biểu tượng và thanh điểm ≥ 3:1. Màu mặc định của Material 3 (`onSurfaceVariant`, `outline`…) không thuộc quy tắc, như
 * màu ngữ nghĩa của hệ thống ở bản macOS; chữ `onSurface` đặt trên nền nhạt của app thì có kiểm, vì nền đó là của app.
 */
class PaletteContrastTest {
    private val themes = listOf(false, true)

    /** Nền mà chữ, biểu tượng màu của bảng đặt lên: màn, bảng kéo lên, thanh trên khi cuộn, thanh dưới, hộp thoại. */
    private fun backgrounds(scheme: ColorScheme) = mapOf(
        "background" to scheme.background,
        "surface" to scheme.surface,
        "surfaceContainerLow (bảng kéo lên)" to scheme.surfaceContainerLow,
        "surfaceContainer (thanh trên khi cuộn)" to scheme.surfaceContainer,
        "thanh dưới (tonalElevation 3dp)" to scheme.surfaceColorAtElevation(3.dp),
        "surfaceContainerHigh (hộp thoại: nút chữ teal)" to scheme.surfaceContainerHigh,
    )

    /** Màu dùng cho chữ nhỏ: "Bạn chọn", nhãn Đề mẫu (teal), "Đúng", "Sai", "Đã đánh dấu", "Phần yếu nhất", đồng hồ. */
    private fun textColors(dark: Boolean): Map<String, Color> {
        val palette = examPalette(dark)
        return mapOf(
            "primary" to examColorScheme(dark).primary,
            "positive" to palette.positive,
            "warning" to palette.warning,
            "critical" to palette.critical,
        )
    }

    /** Nền nhạt: màu với độ mờ `tintOpacity` trên nền (hàng lựa chọn, dải cảnh báo, dải chào mừng, ô bảng câu hỏi). */
    private fun tint(color: Color, opacity: Float, base: Color) = color.copy(alpha = opacity).compositeOver(base)

    @Test
    fun paletteTextOnEveryBackground() = forEachTheme { dark, scheme ->
        for ((bgName, bg) in backgrounds(scheme)) {
            for ((name, color) in textColors(dark)) assertContrast(SMALL_TEXT, color, bg, "$name trên $bgName", dark)
        }
    }

    @Test
    fun paletteTextOnOptionRows() = forEachTheme { dark, scheme ->
        // Hàng lựa chọn có nền nhạt của Đúng, Sai hay đang chọn; trên đó là chữ "Đúng", "Sai", "Bạn chọn", "Đáp án đúng".
        val opacity = examPalette(dark).tintOpacity
        val rowTints = listOf("primary", "positive", "critical")
        for (tintName in rowTints) {
            val row = tint(textColors(dark).getValue(tintName), opacity, scheme.surface)
            for (textName in rowTints) {
                assertContrast(SMALL_TEXT, textColors(dark).getValue(textName), row, "$textName trên hàng nền nhạt $tintName", dark)
            }
        }
    }

    @Test
    fun onSurfaceTextOnEveryTint() = forEachTheme { dark, scheme ->
        val opacity = examPalette(dark).tintOpacity
        for ((bgName, bg) in backgrounds(scheme)) {
            for ((name, color) in textColors(dark)) {
                assertContrast(SMALL_TEXT, scheme.onSurface, tint(color, opacity, bg), "onSurface trên nền nhạt $name của $bgName", dark)
            }
        }
    }

    @Test
    fun iconsOnTheirTints() = forEachTheme { dark, scheme ->
        val palette = examPalette(dark)
        val opacity = palette.tintOpacity
        // Dải cảnh báo/hết giờ: biểu tượng cùng màu với nền nhạt của dải.
        for (color in listOf(palette.warning, palette.critical)) {
            assertContrast(ICON, color, tint(color, opacity, scheme.surface), "biểu tượng dải ${color.hex()}", dark)
        }
        // Ô bảng câu hỏi đã trả lời trong bảng kéo lên: chấm teal và cờ cam trên nền nhạt teal.
        val answeredCell = tint(scheme.primary, opacity, scheme.surfaceContainerLow)
        assertContrast(ICON, scheme.primary, answeredCell, "chấm đã trả lời", dark)
        assertContrast(ICON, palette.warning, answeredCell, "cờ trên ô đã trả lời", dark)
    }

    @Test
    fun scoreBarsAgainstTrack() = forEachTheme { dark, scheme ->
        // Thanh điểm (Đậu/Không đậu) và thanh của từng phần trên rãnh surfaceVariant.
        val palette = examPalette(dark)
        for (fill in listOf(palette.positive, palette.critical, scheme.primary)) {
            assertContrast(ICON, fill, scheme.surfaceVariant, "thanh ${fill.hex()} trên rãnh", dark)
        }
    }

    @Test
    fun onPrimaryOnPrimaryButtons() = forEachTheme { dark, scheme ->
        assertContrast(SMALL_TEXT, scheme.onPrimary, scheme.primary, "chữ của nút chính", dark)
    }

    @Test
    fun paletteMatchesMacOS() {
        // Cùng giá trị `LibraryPalette` của bản macOS (đã kiểm ở đó trên nền macOS), để hai bản trông như một.
        assertEquals(listOf("006666", "196B2D", "934A00", "B22719"), with(examPalette(false)) { listOf(accent, positive, warning, critical) }.map { it.hex() })
        assertEquals(listOf("4FC9C9", "30D158", "FF9F0A", "FF918A"), with(examPalette(true)) { listOf(accent, positive, warning, critical) }.map { it.hex() })
    }

    @Test
    fun negativeControlSwappedThemesFail() {
        // Đối chứng âm: màu của giao diện này đặt lên nền của giao diện kia thì không đạt, nên phép đo bắt được màu sai.
        val light = examColorScheme(false)
        val dark = examColorScheme(true)
        assertTrue(contrast(examPalette(true).warning, light.surface) < SMALL_TEXT)
        assertTrue(contrast(examPalette(true).positive, light.surface) < SMALL_TEXT)
        assertTrue(contrast(examPalette(false).critical, dark.surface) < SMALL_TEXT)
        assertTrue(contrast(examPalette(false).accent, dark.surfaceContainerLow) < SMALL_TEXT)
    }

    private fun forEachTheme(body: (dark: Boolean, scheme: ColorScheme) -> Unit) {
        for (dark in themes) body(dark, examColorScheme(dark))
    }

    private fun assertContrast(minimum: Double, foreground: Color, background: Color, what: String, dark: Boolean) {
        val ratio = contrast(foreground, background)
        val theme = if (dark) "tối" else "sáng"
        assertTrue("$what ($theme): ${foreground.hex()} trên ${background.hex()} = %.2f:1 < $minimum:1".format(ratio), ratio >= minimum)
    }

    private companion object {
        const val SMALL_TEXT = 4.5
        const val ICON = 3.0

        /** Tỉ lệ tương phản WCAG 2 của hai màu đặc. */
        fun contrast(a: Color, b: Color): Double {
            val (high, low) = listOf(luminance(a), luminance(b)).sortedDescending()
            return (high + 0.05) / (low + 0.05)
        }

        fun luminance(c: Color): Double {
            require(c.alpha == 1f) { "màu phải đặc: ${c.hex()}" }
            fun channel(v: Float): Double = if (v <= 0.04045f) v / 12.92 else ((v + 0.055) / 1.055).pow(2.4)
            return 0.2126 * channel(c.red) + 0.7152 * channel(c.green) + 0.0722 * channel(c.blue)
        }

        fun Color.hex(): String = "%02X%02X%02X".format((red * 255).roundToInt(), (green * 255).roundToInt(), (blue * 255).roundToInt())
    }
}
