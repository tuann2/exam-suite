plugins {
    alias(libs.plugins.android.library)
}

android {
    namespace = "vn.io.nt0.examsuite.data"
    compileSdk = 37

    defaultConfig {
        minSdk = 31
    }

    testOptions {
        unitTests.isIncludeAndroidResources = true
    }

    lint {
        warningsAsErrors = true
        abortOnError = true
    }
}

// Đề mẫu của Thư viện dùng chung với bản macOS, đọc tại chỗ, không chép (plan-android-v1.md Phần 2, A2).
androidComponents {
    onVariants { variant ->
        variant.sources.assets?.addStaticSourceDirectory(
            rootProject.file("../Packages/ExamFeatures/Sources/LibraryData/Resources/Samples").absolutePath,
        )
    }
}

kotlin {
    jvmToolchain(17)
}

dependencies {
    implementation(project(":core"))
    lintChecks(project(":lint-rules"))
    testImplementation(libs.junit4)
    testImplementation(libs.robolectric)
    testImplementation(libs.androidx.test.ext.junit)
}
