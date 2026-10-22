// :core là Kotlin JVM thuần: không có Android SDK trên classpath, nên lõi không thể import android.* (ADR 0011).
plugins {
    alias(libs.plugins.kotlin.jvm)
    alias(libs.plugins.kotlin.serialization)
}

kotlin {
    jvmToolchain(17)
}

dependencies {
    implementation(libs.kotlinx.serialization.json)
    testImplementation(platform(libs.junit.bom))
    testImplementation(libs.junit.jupiter)
    testRuntimeOnly(libs.junit.platform.launcher)
}

// Oracle dùng chung với bản Swift đọc tại chỗ từ fixtures/ của repo, không chép (plan-android-v1.md Phần 2).
val fixturesDir = rootProject.layout.projectDirectory.dir("../fixtures")

tasks.test {
    useJUnitPlatform()
    inputs.dir(fixturesDir).withPropertyName("fixtures").withPathSensitivity(PathSensitivity.RELATIVE)
    systemProperty("examsuite.fixtures", fixturesDir.asFile.absolutePath)
}
