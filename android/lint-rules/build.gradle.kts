// Luật lint riêng của Exam Suite, chạy trong `./gradlew lint` của :app và :data (Decisions A0, plan-android-v1.md
// Phần 4 quy tắc 6: bổ sung vào lớp có sẵn, không viết máy quét riêng).
plugins {
    alias(libs.plugins.kotlin.jvm)
}

kotlin {
    jvmToolchain(17)
}

dependencies {
    compileOnly(libs.lint.api)
    compileOnly(libs.lint.checks)
    testImplementation(libs.lint.api)
    testImplementation(libs.lint.checks)
    testImplementation(libs.lint.tests)
    testImplementation(libs.junit4)
}

tasks.jar {
    manifest { attributes("Lint-Registry-v2" to "vn.io.nt0.examsuite.lint.ExamSuiteIssueRegistry") }
}
