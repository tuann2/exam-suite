package vn.io.nt0.examsuite.lint

import com.android.tools.lint.checks.infrastructure.LintDetectorTest
import com.android.tools.lint.checks.infrastructure.TestFile
import com.android.tools.lint.detector.api.Detector
import com.android.tools.lint.detector.api.Issue

/** Đối chứng dương và âm của luật ComposeHardcodedText (Decisions A0). */
class ComposeHardcodedTextDetectorTest : LintDetectorTest() {
    override fun getDetector(): Detector = ComposeHardcodedTextDetector()
    override fun getIssues(): List<Issue> = listOf(ComposeHardcodedTextDetector.ISSUE)

    private val stubs: Array<TestFile> = arrayOf(
        kotlin(
            """
            package androidx.compose.runtime
            annotation class Composable
            """,
        ).indented(),
        kotlin(
            """
            package androidx.compose.material3
            import androidx.compose.runtime.Composable
            @Composable fun Text(text: String, modifier: Any? = null) {}
            """,
        ).indented(),
        kotlin(
            """
            package app
            class SemanticsReceiver { var contentDescription: String = ""; var stateDescription: String = "" }
            fun semantics(block: SemanticsReceiver.() -> Unit) {}
            fun testTag(tag: String) {}
            fun stringResource(id: Int): String = ""
            """,
        ).indented(),
    )

    fun testLiteralInComposableIsReported() {
        lint().files(
            *stubs,
            kotlin(
                """
                package app
                import androidx.compose.material3.Text
                import androidx.compose.runtime.Composable
                @Composable fun Screen() {
                    Text("Thư viện")
                    Text(text = "Library " + "trống")
                    Text("Còn ${'$'}{3} câu")
                }
                """,
            ).indented(),
        ).run().expectErrorCount(3).expectContains("Thư viện").expectContains("ComposeHardcodedText")
    }

    fun testSemanticDescriptionLiteralIsReported() {
        lint().files(
            *stubs,
            kotlin(
                """
                package app
                fun describe() { semantics { contentDescription = "Đánh dấu"; stateDescription = "Đã chọn" } }
                """,
            ).indented(),
        ).run().expectErrorCount(2)
    }

    fun testResourcesSymbolsTagsAndSuppressionAreClean() {
        lint().files(
            *stubs,
            kotlin(
                """
                package app
                import androidx.compose.material3.Text
                import androidx.compose.runtime.Composable
                @Composable fun Screen(count: Int) {
                    Text(stringResource(1))
                    Text("${'$'}count/10")
                    Text(" · ")
                    testTag("library-list")
                    semantics { contentDescription = stringResource(2) }
                }
                @Suppress("ComposeHardcodedText")
                @Composable fun Debug() { Text("chỉ cho bản debug") }
                """,
            ).indented(),
        ).run().expectClean()
    }
}
