import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.compose.screenshot)
}

// Ký bản phát hành bằng keystore của Nt0, giữ ngoài repo (plan-android-v1.md A4; docs/process/android-release.md): file thuộc
// tính `~/.config/exam-suite/android-signing.properties` (hoặc đường dẫn trong biến EXAMSUITE_ANDROID_SIGNING) có
// storeFile, storePassword, keyAlias, keyPassword. Không có file thì bản release không được ký (CI không build release).
val releaseSigning: Properties? = run {
    val explicit = System.getenv("EXAMSUITE_ANDROID_SIGNING")?.let(::File)
    if (explicit != null && !explicit.isFile) error("EXAMSUITE_ANDROID_SIGNING trỏ tới file không có: $explicit")
    val file = (explicit ?: File(System.getProperty("user.home"), ".config/exam-suite/android-signing.properties"))
        .takeIf { it.isFile } ?: return@run null
    Properties().apply { file.inputStream().use(::load) }.also { props ->
        val missing = listOf("storeFile", "storePassword", "keyAlias", "keyPassword").filter { props.getProperty(it).isNullOrBlank() }
        if (missing.isNotEmpty()) error("$file thiếu ${missing.joinToString()} (docs/process/android-release.md)")
    }
}

android {
    namespace = "vn.io.nt0.examsuite"
    compileSdk = 37

    defaultConfig {
        applicationId = "vn.io.nt0.examsuite.android"
        minSdk = 31
        targetSdk = 37
        // Mỗi bản phát hành tăng versionCode (Android không cài đè bản có số nhỏ hơn); tag `android-v<versionName>`.
        versionCode = 1
        versionName = "0.1.0"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        // Mỗi test chạy trong tiến trình riêng, dữ liệu app xoá trước mỗi test (plan-android-v1.md Phần 4).
        testInstrumentationRunnerArguments["clearPackageData"] = "true"
    }

    signingConfigs {
        if (releaseSigning != null) {
            create("release") {
                storeFile = file(releaseSigning.getProperty("storeFile"))
                storePassword = releaseSigning.getProperty("storePassword")
                keyAlias = releaseSigning.getProperty("keyAlias")
                keyPassword = releaseSigning.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        // Bản debug cài cạnh bản phát hành, không bao giờ đụng dữ liệu của nó (plan-android-v1.md Phần 1.3 cũ).
        debug {
            applicationIdSuffix = ".debug"
        }
        // Chưa bật R8 ở 0.1.0: test Compose chạy trên bản debug, bản rút gọn chưa có test luồng (Decisions A4).
        release {
            signingConfig = signingConfigs.findByName("release")
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

// Gói .exam nhị phân dùng chung với lõi Swift (fixtures/packages) làm assets của test trên máy: luồng mở `.exam` từ app
// khác và đọc gói trên ART (ZipPathValidator của Android 14+). File .oef (fixtures/oef) làm Java resource thay vì assets:
// hai thư mục cùng có expected.json, gộp assets từ cả hai báo trùng tên.
androidComponents {
    onVariants { variant ->
        variant.androidTest?.sources?.assets?.addStaticSourceDirectory(rootProject.file("../fixtures/packages").absolutePath)
        variant.androidTest?.sources?.resources?.addStaticSourceDirectory(rootProject.file("../fixtures/oef").absolutePath)
    }
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
    // Kiểu của `:data` mà app dùng trực tiếp: kho Room (`LibraryStore.open`) và DataStore của cài đặt.
    implementation(libs.androidx.room.runtime)
    implementation(libs.androidx.datastore.preferences)
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
