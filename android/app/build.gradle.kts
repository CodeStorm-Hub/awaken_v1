plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.awaken.awaken"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        resValues = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.awaken.awaken"
        // minSdk 26: ML Kit pose detection and full-screen-intent alarm behavior
        // are not worth supporting below Android 8.0 (see awaken_app_refined_plan.md §4).
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // dev/prod flavors (refined plan §6 Phase 0). Paired with Dart
    // entrypoints lib/main_dev.dart / lib/main_prod.dart, each pointing at
    // its own .env.client.<flavor> asset — see core/config/env.dart.
    flavorDimensions += "environment"
    productFlavors {
        create("dev") {
            dimension = "environment"
            applicationIdSuffix = ".dev"
            resValue("string", "app_name", "Awaken Dev")
        }
        create("prod") {
            dimension = "environment"
            resValue("string", "app_name", "Awaken")
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            // Was unset — release APKs shipped fully unminified/un-shrunk.
            // Doesn't fix runtime map jank (that's Dart-side), but cuts APK
            // size and install/cold-start overhead for no behavior change.
            // Re-test a real `flutter build apk --release --flavor prod`
            // install after touching plugin versions — R8 stripping is the
            // one thing that can only be caught by an actual release build,
            // not `flutter analyze`/debug runs.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
