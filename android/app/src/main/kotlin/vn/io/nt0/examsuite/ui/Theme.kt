package vn.io.nt0.examsuite.ui

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color

/**
 * Màu riêng của app, cùng giá trị với `LibraryPalette` của bản macOS (đã có test tương phản ở đó; A4 port test sang
 * Android). Đúng/Sai/cảnh báo luôn đi kèm biểu tượng và chữ, không chỉ dựa vào màu (exam-taking.md).
 */
@Immutable
data class ExamPalette(
    val accent: Color,
    val positive: Color,
    val warning: Color,
    val critical: Color,
    /** Nền nhạt pha màu (dải thông báo, hàng đã chọn): màu với độ mờ này. */
    val tintOpacity: Float = 0.12f,
)

private val LightPalette = ExamPalette(
    accent = Color(0xFF006666),
    positive = Color(0xFF196B2D),
    warning = Color(0xFF934A00),
    critical = Color(0xFFB22719),
)

private val DarkPalette = ExamPalette(
    accent = Color(0xFF4FC9C9),
    positive = Color(0xFF30D158),
    warning = Color(0xFFFF9F0A),
    critical = Color(0xFFFF918A),
)

val LocalExamPalette = staticCompositionLocalOf { LightPalette }

/** Chỉ đổi màu nhấn (teal của bản macOS); nền và chữ giữ mặc định của Material 3 theo sáng/tối của hệ thống. */
@Composable
fun ExamSuiteTheme(dark: Boolean = isSystemInDarkTheme(), content: @Composable () -> Unit) {
    val scheme = if (dark) {
        darkColorScheme(primary = DarkPalette.accent, onPrimary = Color(0xFF003737), secondary = DarkPalette.accent)
    } else {
        lightColorScheme(primary = LightPalette.accent, onPrimary = Color.White, secondary = LightPalette.accent)
    }
    CompositionLocalProvider(LocalExamPalette provides if (dark) DarkPalette else LightPalette) {
        MaterialTheme(colorScheme = scheme, content = content)
    }
}

object ExamTheme {
    val palette: ExamPalette
        @Composable get() = LocalExamPalette.current
}
