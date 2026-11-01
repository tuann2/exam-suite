package vn.io.nt0.examsuite.attempt.ui

import android.text.format.DateFormat
import androidx.compose.runtime.Composable
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import vn.io.nt0.examsuite.R
import vn.io.nt0.examsuite.core.session.SessionMode
import java.text.NumberFormat
import java.text.SimpleDateFormat
import java.time.Instant
import java.util.Date
import java.util.GregorianCalendar
import java.util.Locale
import java.util.TimeZone

/**
 * Số, phần trăm, ngày giờ theo **ngôn ngữ giao diện** (ngôn ngữ mà strings.xml ra: `interface_language`), không theo
 * vùng của máy (accessibility-localization.md, Ngôn ngữ). Thang 1000 luôn là số trơn.
 */
object Fmt {
    fun number(value: Int, locale: Locale): String = NumberFormat.getIntegerInstance(locale).format(value)

    fun number(value: Long, locale: Locale): String = NumberFormat.getIntegerInstance(locale).format(value)

    fun percent(value: Int, locale: Locale): String = NumberFormat.getPercentInstance(locale).format(value / 100.0)

    /** Ngày giờ dạng số theo mẫu của ngôn ngữ ("14:05 15/10/2026", "10/15/2026, 2:05 PM"), lịch Gregorian. */
    fun dateTime(instant: Instant, locale: Locale, timeZone: TimeZone = TimeZone.getDefault()): String =
        SimpleDateFormat(DateFormat.getBestDateTimePattern(locale, "yMdjm"), locale).apply {
            calendar = GregorianCalendar(timeZone, locale)
        }.format(Date.from(instant))

    /** Ngày dạng số theo mẫu của ngôn ngữ ("22/10/2026", "10/22/2026"). */
    fun date(instant: Instant, locale: Locale, timeZone: TimeZone = TimeZone.getDefault()): String =
        SimpleDateFormat(DateFormat.getBestDateTimePattern(locale, "yMd"), locale).apply {
            calendar = GregorianCalendar(timeZone, locale)
        }.format(Date.from(instant))
}

/** Múi giờ hiện ngày giờ; ảnh chụp màn hình cố định để không phụ thuộc máy ghi ảnh. */
val LocalTimeZone = staticCompositionLocalOf<TimeZone> { TimeZone.getDefault() }

@Composable
@ReadOnlyComposable
fun interfaceLocale(): Locale = Locale.forLanguageTag(stringResource(R.string.interface_language))

@Composable
@ReadOnlyComposable
fun num(value: Int): String = Fmt.number(value, interfaceLocale())

@Composable
@ReadOnlyComposable
fun num(value: Long): String = Fmt.number(value, interfaceLocale())

@Composable
@ReadOnlyComposable
fun percentText(value: Int): String = Fmt.percent(value, interfaceLocale())

@Composable
@ReadOnlyComposable
fun modeText(mode: SessionMode): String = stringResource(if (mode == SessionMode.PRACTICE) R.string.mode_practice else R.string.mode_exam)

/** Thời lượng bằng chữ: "1 giờ 5 phút", "12 phút 5 giây", "45 giây". */
@Composable
@ReadOnlyComposable
fun durationText(totalSeconds: Long): String {
    val total = maxOf(0L, totalSeconds)
    val hours = (total / 3600).toInt()
    val minutes = (total % 3600 / 60).toInt()
    val seconds = (total % 60).toInt()
    val parts = buildList {
        if (hours > 0) add(pluralStringResource(R.plurals.duration_hours, hours, num(hours)))
        if (minutes > 0) add(pluralStringResource(R.plurals.duration_minutes, minutes, num(minutes)))
        if (hours == 0 && (seconds > 0 || minutes == 0)) add(pluralStringResource(R.plurals.duration_seconds, seconds, num(seconds)))
    }
    return parts.joinToString(" ")
}

/** Chênh lệch % so với lần trước: "+8%", "−5%", "bằng". */
@Composable
@ReadOnlyComposable
fun percentDelta(delta: Int): String = when {
    delta > 0 -> stringResource(R.string.delta_plus, percentText(delta))
    delta < 0 -> stringResource(R.string.delta_minus, percentText(-delta))
    else -> stringResource(R.string.delta_same)
}
