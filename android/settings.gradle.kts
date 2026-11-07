pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.application") version "9.0.1" apply false
    id("com.android.library") version "9.0.1" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.2.20" apply false
}

rootProject.name = "voyager-native"

val roadstrRoot = rootDir.parentFile.resolve(".roadstr-native")
if (!roadstrRoot.resolve("native-android/app/src/main/kotlin").isDirectory) {
    throw GradleException("Roadstr is not prepared. Run tools/update_roadstr.sh first.")
}
include(":app", ":roadstr-integration")
project(":roadstr-integration").projectDir = rootDir.parentFile.resolve("roadstr-integration")
