import java.security.MessageDigest

plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.plugin.compose")
}

val upstream = rootDir.parentFile.resolve(".roadstr-native")

android {
    namespace = "app.roadstr"
    compileSdk = 36
    ndkVersion = "27.1.12297006"

    defaultConfig {
        minSdk = 24
        externalNativeBuild {
            cmake {
                cppFlags += "-std=c++17"
            }
        }
    }

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        compose = true
    }

    sourceSets {
        getByName("main") {
            kotlin.directories.addAll(
                listOf(
                    upstream.resolve("native-android/app/src/main/kotlin"),
                    upstream.resolve("native-android/app/src/system/kotlin"),
                    upstream.resolve("android/app/src/main/kotlin/app/roadstr/core"),
                    upstream.resolve("android/app/src/main/kotlin/app/roadstr/offlinestt"),
                    upstream.resolve("android/app/src/main/kotlin/app/roadstr/feature"),
                    upstream.resolve("android/app/src/main/kotlin/app/roadstr/service/discovery"),
                    upstream.resolve("android/app/src/main/kotlin/app/roadstr/service/hazards"),
                    upstream.resolve("android/app/src/main/kotlin/app/roadstr/service/location"),
                    upstream.resolve("android/app/src/main/kotlin/app/roadstr/service/meshcore"),
                    upstream.resolve("android/app/src/main/kotlin/app/roadstr/service/network"),
                    upstream.resolve("android/app/src/main/kotlin/app/roadstr/service/nostr"),
                    upstream.resolve("android/app/src/main/kotlin/app/roadstr/service/notifications"),
                    upstream.resolve("android/app/src/main/kotlin/app/roadstr/service/offline"),
                    upstream.resolve("android/app/src/main/kotlin/app/roadstr/service/routing"),
                    upstream.resolve("android/app/src/main/kotlin/app/roadstr/service/search"),
                    upstream.resolve("android/app/src/main/kotlin/app/roadstr/service/speech"),
                    upstream.resolve("android/app/src/main/kotlin/app/roadstr/service/transit"),
                ).map(File::getAbsolutePath),
            )
            res.directories.add(upstream.resolve("android/app/src/main/res").absolutePath)
            assets.directories.add(upstream.resolve("assets").absolutePath)
            jniLibs.directories.add(upstream.resolve("android/app/src/main/jniLibs").absolutePath)
            manifest.srcFile(upstream.resolve("native-android/app/src/main/AndroidManifest.xml"))
        }
    }

    externalNativeBuild {
        cmake {
            path = upstream.resolve("native-android/app/src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    api("org.bouncycastle:bcprov-jdk18on:1.86")
    api("com.squareup.okhttp3:okhttp:4.12.0")
    api("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.10.2")
    api("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")
    implementation("io.github.rallista:valhalla-mobile:0.6.4")
    implementation("io.github.rallista:valhalla-models-config:0.6.0")
    implementation("io.github.rallista:valhalla-models:0.6.0")
    implementation("com.squareup.moshi:moshi-kotlin:1.15.1")
    implementation("com.microsoft.onnxruntime:onnxruntime-android:1.23.0")

    val composeBom = platform("androidx.compose:compose-bom:2026.06.01")
    api(composeBom)
    api("androidx.activity:activity-compose:1.13.0")
    api("androidx.compose.material:material-icons-extended")
    api("androidx.compose.material3:material3")
    api("androidx.compose.ui:ui-tooling-preview")
    api("androidx.lifecycle:lifecycle-runtime-compose:2.10.0")
    debugImplementation("androidx.compose.ui:ui-tooling")

    implementation("org.maplibre.gl:android-sdk-opengl") {
        version {
            strictly("13.5.2")
        }
        because("Roadstr audits one BSD-2-Clause MapLibre Native binary")
    }
}

val bundledNativeChecksums = mapOf(
    "android/app/src/main/jniLibs/arm64-v8a/libespeak-ng.so" to "92882558288c48340e73947f80b01f62dae25911e30ebb1b3942b9bec4054cbf",
    "android/app/src/main/jniLibs/armeabi-v7a/libespeak-ng.so" to "ee42b95d2e91dc8be72df2711007a6fb711c0cde3dc25e88ec2b300e38d6c65b",
    "android/app/src/main/jniLibs/x86_64/libespeak-ng.so" to "0078c57e5a0e15b5fcde9235f84a93ed9e4e49348851d07dadb157eee0edffef",
    "android/app/src/main/jniLibs/arm64-v8a/libc++_shared.so" to "e69496a4aeb51ebe61d0775ae9fefc76eee640f12317aa5174da67e5d4ec8fd6",
    "android/app/src/main/jniLibs/arm64-v8a/libofflinestt_armv8.so" to "dda2250ae4b23541b0081a0db90d65fa1b208ed1d8a3195ec7a4dfdb43924e69",
    "android/app/src/main/jniLibs/arm64-v8a/libofflinestt_dotprod.so" to "91fa13dc428599a18d13858ebbd69d2237e205d026cf336baa8dcb25ac802888",
    "android/app/src/main/jniLibs/arm64-v8a/libofflinestt_cpu_probe.so" to "d69225d765cf9ffffe8cad25b6d27805e679ee4623707003ccd299eddfbf5984",
    "assets/espeak-ng-data.tar.gz" to "ecf9859bd233a19830c0cb048dc2c2f5162a2e4ab2de637cd2f2fabeb63ad84b",
    "android/app/src/main/assets/offline_catalog/geonames-cities15000.tsv.gz" to "0507efa5d7f3e4abd0f72d645b64b25194a33dfaa468c198da59509b2cb8b665",
)

val verifyBundledNativeAssets by tasks.registering {
    val checkedFiles = bundledNativeChecksums.keys.map { upstream.resolve(it) }
    inputs.files(checkedFiles)
    doLast {
        for ((path, expected) in bundledNativeChecksums) {
            val artifact = upstream.resolve(path)
            check(artifact.isFile) { "Missing bundled native artifact: $path" }
            val actual = MessageDigest.getInstance("SHA-256").digest(artifact.readBytes())
                .joinToString("") { "%02x".format(it) }
            check(actual == expected) { "Bundled native artifact failed SHA-256 verification: $path" }
        }
    }
}

tasks.named("preBuild").configure {
    dependsOn(verifyBundledNativeAssets)
}
