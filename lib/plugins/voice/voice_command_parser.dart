import '../../models/voice_command.dart';

/// Maps a recognised utterance onto one of a small, fixed set of intents.
///
/// Keyword matching, not natural-language understanding, and that is the right
/// tool: the vocabulary is a dozen commands, the recogniser is imperfect, and
/// the cost of a creative interpretation is the car doing something the driver
/// did not ask for. Anything that does not match cleanly becomes
/// [VoiceIntent.unknown] and the assistant says it did not understand.
class VoiceCommandParser {
  const VoiceCommandParser({required this.italian});

  final bool italian;

  /// Phrases per intent, checked in order. Longer, more specific phrases must
  /// come first: "previous track" contains "track", and matching the shorter
  /// key first would send every command to the same intent.
  static const Map<VoiceIntent, List<String>> _english = {
    VoiceIntent.previousTrack: ['previous track', 'previous song', 'go back'],
    VoiceIntent.nextTrack: ['next track', 'next song', 'skip'],
    VoiceIntent.pauseMusic: ['pause', 'stop the music', 'stop music'],
    VoiceIntent.playMusic: ['play music', 'play something', 'play'],
    VoiceIntent.navigateHome: ['navigate home', 'take me home', 'go home'],
    VoiceIntent.cancelRoute: ['cancel route', 'stop navigation'],
    VoiceIntent.showNavigation: ['show map', 'show navigation', 'navigation'],
    VoiceIntent.showWeather: ['weather', 'forecast'],
    VoiceIntent.readMessages: ['read messages', 'read my messages'],
    VoiceIntent.answerCall: ['answer', 'pick up', 'take the call'],
    VoiceIntent.rejectCall: ['reject', 'hang up', 'decline'],
  };

  static const Map<VoiceIntent, List<String>> _italian = {
    VoiceIntent.previousTrack: [
      'brano precedente',
      'canzone precedente',
      'torna indietro'
    ],
    VoiceIntent.nextTrack: ['brano successivo', 'canzone successiva', 'salta'],
    VoiceIntent.pauseMusic: ['pausa', 'ferma la musica'],
    VoiceIntent.playMusic: ['metti la musica', 'metti qualcosa', 'suona'],
    VoiceIntent.navigateHome: [
      'portami a casa',
      'naviga verso casa',
      'vai a casa'
    ],
    VoiceIntent.cancelRoute: ['annulla percorso', 'ferma la navigazione'],
    VoiceIntent.showNavigation: ['mostra la mappa', 'mappa', 'navigazione'],
    VoiceIntent.showWeather: ['meteo', 'previsioni'],
    VoiceIntent.readMessages: ['leggi i messaggi', 'leggi messaggi'],
    VoiceIntent.answerCall: ['rispondi', 'prendi la chiamata'],
    VoiceIntent.rejectCall: ['rifiuta', 'riaggancia'],
  };

  VoiceCommand parse(String transcript, {double confidence = 1.0}) {
    final normalised = _normalise(transcript);
    final phrases = italian ? _italian : _english;

    for (final entry in phrases.entries) {
      if (entry.value.any(normalised.contains)) {
        return VoiceCommand(
          transcript: transcript,
          intent: entry.key,
          confidence: confidence,
        );
      }
    }
    return VoiceCommand(
      transcript: transcript,
      intent: VoiceIntent.unknown,
      confidence: confidence,
    );
  }

  /// Lowercases, strips punctuation and collapses whitespace, so "Next track!"
  /// and "next   track" are the same utterance. Accented characters are left
  /// alone — stripping them would merge Italian words that differ only by an
  /// accent.
  static String _normalise(String input) => input
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w\sàèéìòù]', unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
