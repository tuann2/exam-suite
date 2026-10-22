package vn.io.nt0.examsuite.lint

import com.android.tools.lint.client.api.UElementHandler
import com.android.tools.lint.detector.api.Category
import com.android.tools.lint.detector.api.Detector
import com.android.tools.lint.detector.api.Implementation
import com.android.tools.lint.detector.api.Issue
import com.android.tools.lint.detector.api.JavaContext
import com.android.tools.lint.detector.api.Scope
import com.android.tools.lint.detector.api.Severity
import com.android.tools.lint.detector.api.SourceCodeScanner
import org.jetbrains.uast.UBinaryExpression
import org.jetbrains.uast.UCallExpression
import org.jetbrains.uast.UElement
import org.jetbrains.uast.UExpression
import org.jetbrains.uast.ULiteralExpression
import org.jetbrains.uast.UPolyadicExpression
import org.jetbrains.uast.UQualifiedReferenceExpression
import org.jetbrains.uast.USimpleNameReferenceExpression
import org.jetbrains.uast.skipParenthesizedExprDown

/**
 * Chữ giao diện phải lấy từ `strings.xml` (`stringResource`), không viết thẳng trong Compose. Android Lint có sẵn
 * (`HardcodedText`) chỉ quét layout XML, không thấy `Text("…")` (spike A0, docs/plans/active/android-v1.md).
 *
 * Bắt: chuỗi literal có ít nhất một chữ cái truyền vào hàm `@Composable` (kể cả `Text`, `Button`… của Material), và
 * chuỗi literal có chữ cái gán cho `contentDescription`/`stateDescription` trong `semantics { }`. Không bắt: chuỗi
 * không có chữ cái (dấu, số), đối số của hàm thường (`Modifier.testTag("…")`, log), annotation (`@Preview(name = …)`).
 */
class ComposeHardcodedTextDetector : Detector(), SourceCodeScanner {
    override fun getApplicableUastTypes(): List<Class<out UElement>> =
        listOf(UCallExpression::class.java, UBinaryExpression::class.java)

    override fun createUastHandler(context: JavaContext): UElementHandler = object : UElementHandler() {
        override fun visitCallExpression(node: UCallExpression) {
            val method = node.resolve() ?: return
            if (!method.hasAnnotation(COMPOSABLE)) return
            node.valueArguments.forEach { report(context, it) }
        }

        override fun visitBinaryExpression(node: UBinaryExpression) {
            if (node.operatorIdentifier?.name != "=") return
            val name = when (val left = node.leftOperand) {
                is USimpleNameReferenceExpression -> left.identifier
                is UQualifiedReferenceExpression -> (left.selector as? USimpleNameReferenceExpression)?.identifier
                else -> null
            }
            if (name in SEMANTIC_TEXT_PROPERTIES) report(context, node.rightOperand)
        }
    }

    private fun report(context: JavaContext, argument: UExpression) {
        val expression = argument.skipParenthesizedExprDown()
        val text = literalText(expression)
        if (text.none { it.isLetter() }) return
        context.report(
            ISSUE,
            expression,
            context.getLocation(expression),
            "Chữ giao diện \"${text.take(40)}\" viết thẳng trong Compose: thêm vào res/values/strings.xml (tiếng Việt) " +
                "và values-en/strings.xml, rồi dùng stringResource(R.string.…).",
        )
    }

    /** Phần chữ literal của biểu thức: chuỗi, string template ("Còn ${'$'}n câu") và phép ghép `+`, đệ quy. */
    private fun literalText(expression: UExpression): String = when (expression) {
        is ULiteralExpression -> expression.value as? String ?: ""
        is UPolyadicExpression -> expression.operands.joinToString("") { literalText(it.skipParenthesizedExprDown()) }
        else -> ""
    }

    companion object {
        private const val COMPOSABLE = "androidx.compose.runtime.Composable"
        private val SEMANTIC_TEXT_PROPERTIES = setOf("contentDescription", "stateDescription")

        val ISSUE: Issue = Issue.create(
            id = "ComposeHardcodedText",
            briefDescription = "Chữ giao diện viết thẳng trong Compose",
            explanation = """
                Mọi chữ giao diện lấy từ strings.xml để có bản tiếng Anh và để MissingTranslation kiểm được \
                (docs/product/accessibility-localization.md, ADR 0011). Chuỗi không phải giao diện thì dùng \
                @Suppress("ComposeHardcodedText") kèm lý do.
            """,
            category = Category.I18N,
            priority = 7,
            severity = Severity.ERROR,
            implementation = Implementation(ComposeHardcodedTextDetector::class.java, Scope.JAVA_FILE_SCOPE),
        )
    }
}
