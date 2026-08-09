// `kotlin.incremental=false` (see gradle.properties for the full rationale)
// is a Windows-only workaround for the build-tools-api incremental compiler
// failing to close its on-disk caches under this repo's build dir on that
// OS. Injecting it here — into the same `-P`-flag-equivalent property map
// `gradle.properties`/`providers.gradleProperty(...)` reads — rather than
// hardcoding it in `gradle.properties` means Linux/CI builds (and macOS
// contributors) keep incremental Kotlin compilation instead of paying this
// workaround's slower-build cost for a bug that's specific to Windows.
if (System.getProperty("os.name").lowercase().contains("windows")) {
    gradle.startParameter.projectProperties["kotlin.incremental"] = "false"
}

pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.0.1" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
}

include(":app")
