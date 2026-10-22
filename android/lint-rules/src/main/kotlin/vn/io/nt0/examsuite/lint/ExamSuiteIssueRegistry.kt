package vn.io.nt0.examsuite.lint

import com.android.tools.lint.client.api.IssueRegistry
import com.android.tools.lint.client.api.Vendor
import com.android.tools.lint.detector.api.CURRENT_API
import com.android.tools.lint.detector.api.Issue

class ExamSuiteIssueRegistry : IssueRegistry() {
    override val issues: List<Issue> = listOf(ComposeHardcodedTextDetector.ISSUE)
    override val api: Int = CURRENT_API
    override val minApi: Int = 14
    override val vendor: Vendor = Vendor(vendorName = "Exam Suite", identifier = "exam-suite")
}
