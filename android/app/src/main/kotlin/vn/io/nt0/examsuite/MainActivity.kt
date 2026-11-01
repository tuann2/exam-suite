package vn.io.nt0.examsuite

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.viewModels
import vn.io.nt0.examsuite.app.AppModel
import vn.io.nt0.examsuite.app.AppRoot
import vn.io.nt0.examsuite.ui.ExamSuiteTheme

/** Một Activity cho cả app; nhận `.exam` và `.oef` từ app khác qua "Mở bằng" (VIEW) và "Chia sẻ" (SEND). */
class MainActivity : ComponentActivity() {
    private val model: AppModel by viewModels()

    // Hộp chọn file của hệ điều hành không biết MIME của .exam, .oef (spike A0): lọc mọi file, app tự kiểm nội dung.
    private val picker = registerForActivityResult(ActivityResultContracts.OpenDocument()) { uri -> uri?.let(model::add) }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        if (savedInstanceState == null) incomingUri(intent)?.let(model::receive)
        setContent { ExamSuiteTheme { AppRoot(model) { picker.launch(arrayOf("*/*")) } } }
    }

    override fun onStart() {
        super.onStart()
        model.inForeground = true
    }

    override fun onStop() {
        super.onStop()
        if (!isChangingConfigurations) model.inForeground = false
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        incomingUri(intent)?.let(model::receive)
    }

    private fun incomingUri(intent: Intent?): Uri? = when (intent?.action) {
        Intent.ACTION_VIEW -> intent.data
        Intent.ACTION_SEND -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(Intent.EXTRA_STREAM)
        }
        else -> null
    }
}
