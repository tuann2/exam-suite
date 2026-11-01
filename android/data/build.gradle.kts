plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.ksp)
    alias(libs.plugins.androidx.room)
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

// Schema Room xuất ra và commit: mỗi phiên bản một file JSON, đổi schema phải tăng phiên bản kèm bước chuyển và test
// (như "không sửa LibrarySchemaV1" của bản macOS). Test mở kho v1 từ file này (LibraryDatabaseSchemaTest).
room {
    schemaDirectory("$projectDir/schemas")
}

// Đề mẫu của Thư viện dùng chung với bản macOS, đọc tại chỗ, không chép (plan-android-v1.md Phần 2, A2).
androidComponents {
    onVariants { variant ->
        variant.sources.assets?.addStaticSourceDirectory(
            rootProject.file("../Packages/SharedFeatures/Sources/LibraryData/Resources/Samples").absolutePath,
        )
    }
}

kotlin {
    jvmToolchain(17)
}

dependencies {
    api(project(":core"))
    implementation(libs.androidx.room.runtime)
    implementation(libs.androidx.room.ktx)
    implementation(libs.androidx.sqlite.framework)
    ksp(libs.androidx.room.compiler)
    implementation(libs.androidx.datastore.preferences)
    implementation(libs.kotlinx.coroutines.core)
    lintChecks(project(":lint-rules"))

    testImplementation(libs.junit4)
    testImplementation(libs.robolectric)
    testImplementation(libs.androidx.test.ext.junit)
    testImplementation(libs.androidx.room.testing)
    testImplementation(libs.kotlinx.coroutines.test)
}
