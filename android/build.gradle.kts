allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

// ── No proprietary Google libraries, anywhere in the build ───────────────────
// Inherited from Roadstr, and it has to be repeated here: the exclusion belongs
// to the plugin's own configurations, so applying it only in :app would still
// leave Play Services compiled and packaged. Voyager reads location through
// Android's own LocationManager on every path (the vendored geolocator_android
// fork), so these classes could never execute anyway — they would just sit in
// the APK making the app look dependent on something it deliberately avoids.
allprojects {
    configurations.all {
        exclude(group = "com.google.android.gms")
        exclude(group = "com.google.android.play")
    }
}

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // Force compileSdk 36 and a single NDK across every plugin module.
    //
    // Two separate problems, one fix. Several Flutter plugins pulled in through
    // Roadstr still declare compileSdk 33 (amberflutter), which no longer
    // builds against current AndroidX. And the plugins declare conflicting NDK
    // versions — 27.1 is the one eSpeak-NG is compiled with and the one the
    // F-Droid recipe installs, and letting a second version in would mean both
    // another gigabyte of download and an F-Droid build that fails outright.
    afterEvaluate {
        extensions.findByType(com.android.build.gradle.BaseExtension::class)
            ?.apply {
                compileSdkVersion(36)
                ndkVersion = "27.1.12297006"
            }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
