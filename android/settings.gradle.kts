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
    // Required by the maplibre_android plugin's own build.gradle.kts, pulled
    // in transitively now that Roadstr's map rendering runs on MapLibre.
    // Declared here, at the root, because that is where Gradle resolves a
    // plugin id applied deeper in the build — Roadstr's own settings.gradle.kts
    // declares the identical version.
    id("org.jlleitschuh.gradle.ktlint") version "12.1.1" apply false
}

include(":app")
