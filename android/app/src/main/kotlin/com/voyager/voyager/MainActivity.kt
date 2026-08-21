package com.voyager.voyager

import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine

// Extends AudioServiceActivity, not FlutterActivity.
//
// audio_service hands the media session, the notification and the Bluetooth
// AVRCP transport keys to a background engine, and it needs an activity that
// shares that engine to hook them up. With a plain FlutterActivity every call
// into the plugin fails with "The Activity class declared in your
// AndroidManifest.xml is wrong or has not provided the correct FlutterEngine",
// which surfaces in the app as the music plugin refusing to initialise.
class MainActivity : AudioServiceActivity() {
    private var phoneBridge: PhoneBridge? = null
    private var mediaStoreBridge: MediaStoreBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // The bridge is created per engine rather than per process: Flutter
        // may tear the engine down and rebuild it (a config change on some
        // head units does exactly this), and a bridge holding a stale
        // MethodChannel would silently stop delivering calls.
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        phoneBridge = PhoneBridge(this, messenger)
        mediaStoreBridge = MediaStoreBridge(this, messenger)
    }

    override fun onDestroy() {
        phoneBridge?.dispose()
        phoneBridge = null
        mediaStoreBridge?.dispose()
        mediaStoreBridge = null
        super.onDestroy()
    }
}
