import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/gesture_event.dart';

/// Turns hardware key presses into [GestureEvent]s the dashboard can route.
///
/// The events that matter in a car arrive as ordinary Android key events: the
/// steering-wheel remote is wired to the volume keys on most head units, and
/// AVRCP transport keys come through as media keys. Voyager intercepts them
/// rather than letting the system handle them, which is what lets the volume
/// rocker skip tracks instead of changing a volume the car stereo already
/// controls.
///
/// Uses [HardwareKeyboard] rather than the older RawKeyboard API, which
/// Flutter has deprecated.
class AutomotiveGestureService {
  final _controller = StreamController<GestureEvent>.broadcast();

  Stream<GestureEvent> get events => _controller.stream;

  /// Whether the volume keys are remapped to track skipping.
  ///
  /// Off by default and switched on in Settings, because on a phone used
  /// outside the car — or on a head unit whose wheel controls are wired to the
  /// media keys already — silently swallowing the volume keys is hostile.
  bool remapVolumeKeys = false;

  void attach() => HardwareKeyboard.instance.addHandler(handleKeyEvent);
  void detach() => HardwareKeyboard.instance.removeHandler(handleKeyEvent);

  /// Returns true when the event was consumed and must not propagate.
  ///
  /// Public and named rather than a closure so the tests can drive it with
  /// synthesised key events, which is the only way to cover this without a
  /// device that has a steering wheel attached.
  @visibleForTesting
  bool handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    final button = _map(event.logicalKey);
    if (button == null) return false;
    if (_isVolume(button) && !remapVolumeKeys) return false;

    _controller.add(GestureEvent(
      button: button,
      at: DateTime.now(),
      isRepeat: event is KeyRepeatEvent,
    ));
    return true;
  }

  static bool _isVolume(PhysicalButton button) =>
      button == PhysicalButton.volumeUp || button == PhysicalButton.volumeDown;

  static PhysicalButton? _map(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.audioVolumeUp) return PhysicalButton.volumeUp;
    if (key == LogicalKeyboardKey.audioVolumeDown) {
      return PhysicalButton.volumeDown;
    }
    if (key == LogicalKeyboardKey.mediaTrackNext) {
      return PhysicalButton.mediaNext;
    }
    if (key == LogicalKeyboardKey.mediaTrackPrevious) {
      return PhysicalButton.mediaPrevious;
    }
    if (key == LogicalKeyboardKey.mediaPlayPause) {
      return PhysicalButton.mediaPlayPause;
    }
    if (key == LogicalKeyboardKey.launchAssistant) return PhysicalButton.voice;
    if (key == LogicalKeyboardKey.contextMenu) return PhysicalButton.menu;
    return null;
  }

  void dispose() {
    detach();
    _controller.close();
  }
}
