import 'dart:io';

import '../../utils/logger_automotive.dart';

/// Offline speech recognition through Vosk.
///
/// **Status: not implemented.** The interface is here, the model path is
/// wired through settings, and the voice plugin degrades cleanly when
/// recognition is unavailable — but [listen] does not yet recognise anything,
/// and says so rather than returning a plausible-looking empty string.
///
/// What remains is the part that cannot be faked in Dart: `libvosk.so` has to
/// be cross-compiled for arm64-v8a and armeabi-v7a, bundled through
/// `android/app/src/main/jniLibs`, and bound with `dart:ffi` — a recogniser
/// handle, a PCM feed at 16 kHz mono, and a JSON result pulled out at the end
/// of each utterance. Audio capture then has to run in an isolate, because
/// feeding 16 000 samples a second through the platform thread competes with
/// map rendering for the same frame budget.
///
/// Until that lands, Voyager speaks but does not listen, and every voice
/// action is reachable from a physical button. That is a deliberate ordering:
/// a speech recogniser that is 85% accurate in a moving car is a feature worth
/// having and a terrible thing to ship half-finished, because the 15% lands as
/// the app doing something the driver did not ask for.
class VoskSttWrapper {
  final String modelPath;

  VoskSttWrapper({required this.modelPath});

  bool _modelPresent = false;

  /// True only when a model directory exists *and* the native library is
  /// bound. The second half is always false today.
  bool get isAvailable => _modelPresent && _nativeBound;

  /// Flipped on when the FFI binding lands. Kept as a named constant rather
  /// than a TODO comment so the honest answer is visible in the debugger and
  /// in Settings, not just in the source.
  static const bool _nativeBound = false;

  Future<void> initialize() async {
    _modelPresent = await Directory(modelPath).exists();
    if (!_modelPresent) {
      AutomotiveLogger.warn('STT', 'no Vosk model at $modelPath');
      return;
    }
    if (!_nativeBound) {
      AutomotiveLogger.warn('STT', 'model found but libvosk is not bound yet');
    }
  }

  /// Listens for one utterance.
  ///
  /// Returns null when recognition is unavailable — which today is always.
  /// Callers must treat null as "the user said nothing usable" and fall back
  /// to on-screen or physical controls.
  Future<String?> listen(Duration timeout) async {
    if (!isAvailable) return null;
    throw UnimplementedError('Vosk FFI binding is not implemented yet');
  }

  void dispose() {}
}
