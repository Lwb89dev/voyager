import 'package:roadstr/services/kokoro/kokoro_tts_service.dart';

import '../../utils/logger_automotive.dart';

/// Speech output for Voyager, backed by Roadstr's Kokoro engine.
///
/// The original plan called for Piper TTS bound over FFI. That was the right
/// call when the plan was written and is the wrong one now: Roadstr already
/// ships a working neural TTS — Kokoro running through flutter_onnxruntime,
/// with an eSpeak-NG phonemizer, per-language voices, an LRU disk cache and a
/// priority queue that keeps a hazard alert from cutting a turn instruction in
/// half. Adding Piper would mean a second ~60 MB model, a second FFI surface
/// to maintain, and two voices that sound different depending on which
/// subsystem is speaking.
///
/// So this is a thin adapter, and the interesting decisions all live behind
/// it: [KokoroTtsService] falls back to eSpeak-NG on its own when no voice
/// model is installed, which is why there is no fallback logic here.
class SpeechService {
  final KokoroTtsService _tts;

  /// Injectable for tests, which pass a fake rather than loading a 90 MB ONNX
  /// model into a unit-test process.
  SpeechService({KokoroTtsService? tts}) : _tts = tts ?? KokoroTtsService();

  bool _ready = false;
  bool get isReady => _ready;

  Future<void> initialize(String languageCode) async {
    try {
      await _tts.init(languageCode);
      _ready = _tts.isReady;
    } catch (error) {
      // Speech is an enhancement, not a requirement: navigation works silently
      // and the driver still sees every instruction on screen.
      AutomotiveLogger.warn('Speech', 'init failed: $error');
      _ready = false;
    }
  }

  /// Speaks [text].
  ///
  /// [urgent] maps to Kokoro's priority path, which interrupts whatever
  /// ambient utterance is playing. Reserve it for things a driver must hear
  /// now — a manoeuvre, a hazard — and never for confirmations.
  Future<void> speak(String text, {bool urgent = false}) async {
    if (!_ready || text.trim().isEmpty) return;
    await _tts.speak(text, priority: urgent);
  }

  Future<void> stop() => _tts.stop();

  void setLanguage(String languageCode) => _tts.setLanguage(languageCode);
  void setVolume(double volume) => _tts.setVolume(volume);
  void setSpeed(double speed) => _tts.setSpeed(speed);
  void setGender(String gender) => _tts.setGender(gender);

  /// Speaks a fixed sample phrase in the current language/gender/speed, so a
  /// choice in Settings can be judged immediately rather than on the next
  /// real turn instruction.
  Future<void> previewVoice() => _tts.previewVoice();

  Future<void> dispose() => _tts.dispose();
}
