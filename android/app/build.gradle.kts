import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ── Release signing ───────────────────────────────────────────────────────────
// Create android/key.properties with your keystore details; see
// android/key.properties.template. It is gitignored and must stay that way.
//
// Without it Gradle emits an *unsigned* release rather than falling back to the
// debug key. A debug-signed artifact that calls itself a release is the one
// outcome worth failing for: it installs, it looks right, and it can never be
// updated by a properly signed build afterwards.
val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties()
if (keyPropertiesFile.exists()) {
    keyProperties.load(FileInputStream(keyPropertiesFile))
}

fun signingProperty(name: String): String =
    (keyProperties[name] as String?)?.takeIf(String::isNotBlank)
        ?: throw GradleException("Missing signing property '$name' in ${keyPropertiesFile.path}")

val hasReleaseSigningConfig = keyPropertiesFile.exists()
val releaseStoreFile = if (hasReleaseSigningConfig) file(signingProperty("storeFile")) else null
if (hasReleaseSigningConfig && releaseStoreFile?.isFile != true) {
    throw GradleException("Release keystore not found: ${releaseStoreFile?.path}")
}

android {
    namespace = "com.voyager.voyager"
    // Pinned to 36 rather than flutter.compileSdkVersion: several AndroidX
    // libraries pulled in transitively (annotation-experimental 1.4,
    // exifinterface 1.4) refuse to build against anything lower. Roadstr pins
    // the same value for the same reason.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications requires it: it uses java.time on API
        // levels that predate it, and desugaring is what backports those
        // classes rather than raising minSdk past the head units Voyager
        // targets.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.voyager.voyager"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // API 26 is the floor for two hard requirements: TelecomManager's
        // acceptRingingCall (call answering) and the notification-channel API
        // audio_service needs for its media notification.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasReleaseSigningConfig) {
                keyAlias = signingProperty("keyAlias")
                keyPassword = signingProperty("keyPassword")
                storeFile = releaseStoreFile
                storePassword = signingProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseSigningConfig) {
                signingConfigs.getByName("release")
            } else {
                null
            }

            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // ContextCompat.registerReceiver with RECEIVER_NOT_EXPORTED, required from
    // Android 14 and used by PhoneBridge.
    implementation("androidx.core:core-ktx:1.13.1")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
