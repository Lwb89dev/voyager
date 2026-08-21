/// What the user asked for, once a recognised utterance has been parsed.
///
/// Intent parsing is deliberately a closed set rather than free text. Speech
/// recognition running offline on a phone-class CPU is around 85% accurate in
/// a moving car, so the only safe design is a small vocabulary where a
/// misrecognition falls off the end of the list instead of being creatively
/// interpreted into the wrong action.
enum VoiceIntent {
  playMusic,
  pauseMusic,
  nextTrack,
  previousTrack,
  showNavigation,
  showWeather,
  navigateHome,
  cancelRoute,
  readMessages,
  answerCall,
  rejectCall,

  /// Recognised speech that matched nothing. The assistant says so rather
  /// than guessing.
  unknown,
}

class VoiceCommand {
  /// Raw text as returned by the recogniser, kept for the on-screen echo so
  /// the driver can see why the wrong thing happened.
  final String transcript;

  final VoiceIntent intent;

  /// Recogniser confidence in 0..1. Commands below
  /// [VoiceCommand.minConfidence] are downgraded to [VoiceIntent.unknown]
  /// before they reach any plugin.
  final double confidence;

  const VoiceCommand({
    required this.transcript,
    required this.intent,
    required this.confidence,
  });

  /// Chosen empirically against Vosk's small models: below this, false
  /// positives (acting on something the driver never said) outnumber the
  /// commands correctly rescued by a lower bar.
  static const double minConfidence = 0.6;

  bool get isActionable =>
      intent != VoiceIntent.unknown && confidence >= minConfidence;
}
