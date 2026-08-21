# ── Voyager ProGuard / R8 rules ───────────────────────────────────────────────
#
# Adapted from Roadstr's, because Voyager ships Roadstr's plugin set plus its
# own. Every rule here exists because R8 full-mode strips classes that are only
# ever reached through reflection or JNI — the compiler cannot see those call
# sites, so it has to be told.

# Flutter engine. Everything except the Play Store deferred-component manager
# and the Play Store split Application: Voyager has neither, and keeping them
# drags dangling com.google.android.play.core.* references into the dex —
# symbols nothing can reach, which F-Droid's scanner nonetheless reports as
# Google dependencies.
-keep class !io.flutter.embedding.engine.deferredcomponents.**,!io.flutter.embedding.android.FlutterPlayStoreSplitApplication,io.flutter.** { *; }
-dontwarn io.flutter.**
-dontwarn com.google.android.play.core.**

# Kotlin coroutines
-keep class kotlinx.coroutines.** { *; }
-dontwarn kotlinx.coroutines.**

# Hive — reflection for Box and TypeAdapter
-keep class com.hivedb.** { *; }

# Plugins reached through JNI or reflection
-keep class com.baseflow.geolocator.** { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keep class dev.fluttercommunity.plus.sensors.** { *; }
-keep class com.baseflow.permissionhandler.** { *; }

# audio_service and its media session. The service, the media-button receiver
# and the activity are all named in the manifest and instantiated by the
# system, so nothing in the code references them.
-keep class com.ryanheise.audioservice.** { *; }
-keep class com.ryanheise.just_audio.** { *; }

# Voyager's own native bridge — MainActivity and PhoneBridge are reached from
# the manifest and from Dart method channels respectively.
-keep class com.voyager.voyager.** { *; }

# ONNX Runtime (flutter_onnxruntime), which loads libonnxruntime.so over JNI.
-keep class ai.onnxruntime.** { *; }
-keep class com.masicai.flutteronnxruntime.** { *; }
-dontwarn ai.onnxruntime.**

# Nostr / crypto paths used by Roadstr
-dontwarn org.bouncycastle.**
-dontwarn org.conscrypt.**
-dontwarn org.openjsse.**
