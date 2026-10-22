package vn.io.nt0.examsuite.data

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

/** Test của khung A0: Robolectric chạy được và đề mẫu dùng chung có trong assets của :data. */
@RunWith(AndroidJUnit4::class)
class SampleAssetsTest {
    private val samplesDir = File("../../Packages/ExamFeatures/Sources/LibraryData/Resources/Samples")

    @Test
    fun sampleExamsArePackagedAsAssets() {
        val assets = ApplicationProvider.getApplicationContext<Context>().assets
        val onDisk = samplesDir.list()!!.filter { File(samplesDir, "$it/${SampleExams.EXAM_FILE}").isFile }.sorted()

        val packaged = onDisk.filter { name -> assets.list(name)!!.contains(SampleExams.EXAM_FILE) }
        assertEquals(2, onDisk.size)
        assertEquals(onDisk, packaged)
    }
}
