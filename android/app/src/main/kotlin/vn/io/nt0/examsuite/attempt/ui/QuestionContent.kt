package vn.io.nt0.examsuite.attempt.ui

import android.graphics.BitmapFactory
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.rememberTransformableState
import androidx.compose.foundation.gestures.transformable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalWindowInfo
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import vn.io.nt0.examsuite.R
import vn.io.nt0.examsuite.core.text.Markdown

/** Markdown cơ bản của nội dung đề (đậm, nghiêng, mã trong dòng; exam-format.md) thành chữ có kiểu. */
fun markdownAnnotated(source: String): AnnotatedString = buildAnnotatedString {
    for (span in Markdown.spans(source)) {
        val style = SpanStyle(
            fontWeight = if (span.bold) FontWeight.Bold else null,
            fontStyle = if (span.italic) FontStyle.Italic else null,
            fontFamily = if (span.code) FontFamily.Monospace else null,
        )
        withStyle(style) { append(span.text) }
    }
}

/** Chữ Markdown; trình đọc màn hình đọc chữ trơn (không đọc ký hiệu). */
@Composable
fun MarkdownText(source: String, modifier: Modifier = Modifier, style: TextStyle = MaterialTheme.typography.bodyLarge) {
    Text(text = remember(source) { markdownAnnotated(source) }, modifier = modifier, style = style)
}

/** Ảnh của câu: đọc từ file đề đã sao chép vào app, giải mã theo bề rộng hiển thị (plan-android-v1.md Phần 5). */
interface QuestionImages {
    /** Ảnh có sẵn (preview, bộ nhớ đệm); null thì đọc bằng `bytes`. */
    fun cached(path: String): ImageBitmap? = null

    /** Byte của ảnh trong gói đề; ném lỗi nếu không đọc được. */
    suspend fun bytes(path: String): ByteArray
}

val LocalQuestionImages = staticCompositionLocalOf<QuestionImages?> { null }

private sealed interface ImageState {
    data object Loading : ImageState

    data class Loaded(val bitmap: ImageBitmap) : ImageState

    data object Failed : ImageState
}

/** Giải mã với `inSampleSize` để ảnh lớn không chiếm bộ nhớ vượt quá bề rộng cần hiện. */
internal fun decodeSampled(bytes: ByteArray, maxWidthPx: Int): ImageBitmap? {
    val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
    BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
    if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
    var sample = 1
    while (bounds.outWidth / (sample * 2) >= maxWidthPx) sample *= 2
    val options = BitmapFactory.Options().apply { inSampleSize = sample }
    return BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options)?.asImageBitmap()
}

/** Ảnh vừa khung, chạm để phóng to (hộp toàn màn hình, chụm hai ngón để phóng). */
@Composable
fun QuestionImage(path: String, modifier: Modifier = Modifier) {
    val images = LocalQuestionImages.current
    // Gấp đôi bề rộng cửa sổ: đủ nét khi phóng to mà không giải mã ảnh gốc hàng chục megapixel.
    val widthPx = LocalWindowInfo.current.containerSize.width.coerceAtLeast(1) * 2
    val state by produceState<ImageState>(images?.cached(path)?.let { ImageState.Loaded(it) } ?: ImageState.Loading, path, images) {
        if (value is ImageState.Loaded) return@produceState
        value = try {
            val bytes = images?.bytes(path) ?: throw IllegalStateException("không có nguồn ảnh")
            withContext(Dispatchers.Default) { decodeSampled(bytes, widthPx) }?.let { ImageState.Loaded(it) } ?: ImageState.Failed
        } catch (e: kotlinx.coroutines.CancellationException) {
            throw e
        } catch (_: Exception) {
            ImageState.Failed
        }
    }
    var zoomed by rememberSaveable { mutableStateOf(false) }
    when (val s = state) {
        ImageState.Loading -> Box(modifier.fillMaxWidth().heightIn(min = 120.dp))
        ImageState.Failed -> Row(
            modifier.fillMaxWidth().padding(vertical = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(painterResource(R.drawable.ic_warning), contentDescription = null, tint = MaterialTheme.colorScheme.error)
            Text(stringResource(R.string.image_unavailable), style = MaterialTheme.typography.bodyMedium)
        }
        is ImageState.Loaded -> {
            val description = stringResource(R.string.question_image)
            val hint = stringResource(R.string.question_image_enlarge)
            Image(
                bitmap = s.bitmap,
                contentDescription = null,
                contentScale = ContentScale.Fit,
                modifier = modifier
                    .fillMaxWidth()
                    .heightIn(max = 360.dp)
                    .clickable { zoomed = true }
                    .semantics {
                        contentDescription = description
                        onClick(label = hint) { zoomed = true; true }
                    },
            )
            if (zoomed) ZoomedImage(s.bitmap) { zoomed = false }
        }
    }
}

@Composable
private fun ZoomedImage(bitmap: ImageBitmap, onDismiss: () -> Unit) {
    Dialog(onDismissRequest = onDismiss, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        var scale by remember { mutableFloatStateOf(1f) }
        var offsetX by remember { mutableFloatStateOf(0f) }
        var offsetY by remember { mutableFloatStateOf(0f) }
        val transform = rememberTransformableState { zoom, pan, _ ->
            scale = (scale * zoom).coerceIn(1f, 6f)
            offsetX += pan.x
            offsetY += pan.y
        }
        Surface(Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.surface) {
            Box(Modifier.fillMaxSize()) {
                Image(
                    bitmap = bitmap,
                    contentDescription = stringResource(R.string.question_image_enlarged),
                    contentScale = ContentScale.Fit,
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(8.dp)
                        .transformable(transform)
                        .graphicsLayer(scaleX = scale, scaleY = scale, translationX = offsetX, translationY = offsetY),
                )
                IconButton(
                    onClick = onDismiss,
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .padding(8.dp)
                        .background(MaterialTheme.colorScheme.surfaceVariant, RoundedCornerShape(50)),
                ) {
                    Icon(painterResource(R.drawable.ic_close), contentDescription = stringResource(R.string.close))
                }
            }
        }
    }
}

/** Khung giải thích (Kiểm tra đáp án, Xem lại bài). */
@Composable
fun ExplanationBox(text: String, modifier: Modifier = Modifier) {
    Surface(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(8.dp),
        color = MaterialTheme.colorScheme.surfaceVariant,
    ) {
        Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(stringResource(R.string.explanation), style = MaterialTheme.typography.titleSmall)
            MarkdownText(text, style = MaterialTheme.typography.bodyMedium)
        }
    }
}

/** Biểu tượng nhỏ cùng chữ (Đúng, Sai, Bạn chọn…): luôn có chữ, không chỉ màu. */
@Composable
fun IconLabel(iconRes: Int, text: String, color: androidx.compose.ui.graphics.Color, modifier: Modifier = Modifier) {
    Row(modifier, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        Icon(painterResource(iconRes), contentDescription = null, tint = color, modifier = Modifier.size(18.dp))
        Text(text, style = MaterialTheme.typography.labelLarge, color = color)
    }
}
