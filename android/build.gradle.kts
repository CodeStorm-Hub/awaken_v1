allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Force all plugin subprojects to compile against SDK 35 so that the
// flutter_fgbg AAR metadata requirement (compileSdk >= 35) is satisfied
// even for plugins that still hardcode compileSdk 34 (e.g. alarm).
subprojects {
    afterEvaluate {
        if (extensions.findByName("android") != null) {
            val androidExt = extensions.getByName("android")
            if (androidExt is com.android.build.gradle.LibraryExtension) {
                if (androidExt.compileSdkVersion?.let {
                    it.removePrefix("android-").toIntOrNull() ?: 0
                } ?: 0 < 36) {
                    androidExt.compileSdk = 36
                }
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
