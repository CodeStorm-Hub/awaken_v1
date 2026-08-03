allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// The `alarm` plugin (^5.5.0) still hardcodes compileSdk 34, which fails a
// release build's stricter AAR-metadata check (flutter_fgbg requires
// compileSdk >= 35 from anything in the dependency graph) — debug builds
// don't enforce this, so the gap only shows up in `--release`. Narrowed
// 2026-07-31 from an `allprojects`-wide override (was masking whether any
// other plugin genuinely needed a lower compileSdk) to just this one
// project, confirmed via `flutter build apk --release --flavor prod`: every
// other plugin subproject is already at compileSdk 35+ on its own. Remove
// this once `alarm` ships a release with compileSdk >= 35.
project(":alarm") {
    afterEvaluate {
        if (extensions.findByName("android") != null) {
            val androidExt = extensions.getByName("android")
            if (androidExt is com.android.build.gradle.LibraryExtension) {
                androidExt.compileSdk = 36
            }
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
