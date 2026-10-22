plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.compose.screenshot)
}

android {
    namespace = "vn.io.nt0.examsuite"
    compileSdk = 37

    defaultConfig {
        applicationId = "vn.io.nt0.examsuite.android"
        minSdk = 31
        targetSdk = 37
        versionCode = 1
        versionName = "0.0.1"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        // Mỗi test chạy trong tiến trình riêng, dữ liệu app xoá trước mỗi test (plan-android-v1.md Phần 4).
        testInstrumentationRunnerArguments["clearPackageData"] = "true"
    }

    buildTypes {
        // Bản debug cài cạnh bản phát hành, không bao giờ đụng dữ liệu của nó (plan-android-v1.md Phần 1.3 cũ).
        debug {
            applicationIdSuffix = ".debug"
        }
    }

    buildFeatures {
        compose = true
    }

    testOptions {
        execution = "ANDROIDX_TEST_ORCHESTRATOR"
    }

    lint {
        warningsAsErrors = true
        abortOnError = true
    }

    experimentalProperties["android.experimental.enableScreenshotTest"] = true
}

kotlin {
    jvmToolchain(17)
}

dependencies {
    implementation(project(":core"))
    lintChecks(project(":lint-rules"))
    implementation(project(":data"))
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.kotlinx.coroutines.core)
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.tooling.preview)
    debugImplementation(libs.androidx.compose.ui.tooling)
    debugImplementation(libs.androidx.compose.ui.test.manifest)

    // Model trình bày và model màn làm bài là Kotlin thuần: test JVM, không cần Robolectric (plan-android-v1.md Phần 4).
    testImplementation(libs.junit4)
    testImplementation(libs.kotlinx.coroutines.test)

    androidTestImplementation(platform(libs.androidx.compose.bom))
    androidTestImplementation(libs.androidx.compose.ui.test.junit4)
    androidTestImplementation(libs.androidx.compose.ui.test.junit4.accessibility)
    androidTestImplementation(libs.androidx.test.ext.junit)
    androidTestImplementation(libs.androidx.test.runner)
    androidTestUtil(libs.androidx.test.orchestrator)

    screenshotTestImplementation(platform(libs.androidx.compose.bom))
    screenshotTestImplementation(libs.screenshot.validation.api)
    screenshotTestImplementation(libs.androidx.compose.ui.tooling)
}
