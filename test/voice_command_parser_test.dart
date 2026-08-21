import 'package:flutter_test/flutter_test.dart';
import 'package:voyager/models/voice_command.dart';
import 'package:voyager/plugins/voice/voice_command_parser.dart';

void main() {
  const english = VoiceCommandParser(italian: false);
  const italian = VoiceCommandParser(italian: true);

  group('English', () {
    test('matches the plain phrases', () {
      expect(english.parse('next track').intent, VoiceIntent.nextTrack);
      expect(english.parse('pause').intent, VoiceIntent.pauseMusic);
      expect(english.parse('take me home').intent, VoiceIntent.navigateHome);
    });

    test('prefers the longer phrase when one contains the other', () {
      // "previous track" also contains no shorter key, but "next track" and
      // "skip" both map to nextTrack while "go back" must not be read as
      // "next": ordering in the table is what prevents that.
      expect(english.parse('previous track').intent, VoiceIntent.previousTrack);
      expect(english.parse('go back').intent, VoiceIntent.previousTrack);
    });

    test('ignores case, punctuation and extra words', () {
      expect(english.parse('Erm, NEXT TRACK please!').intent,
          VoiceIntent.nextTrack);
    });

    test('returns unknown rather than guessing', () {
      expect(english.parse('open the pod bay doors').intent,
          VoiceIntent.unknown);
    });
  });

  group('Italian', () {
    test('matches Italian phrases', () {
      expect(italian.parse('brano successivo').intent, VoiceIntent.nextTrack);
      expect(italian.parse('portami a casa').intent, VoiceIntent.navigateHome);
      expect(italian.parse('che meteo fa').intent, VoiceIntent.showWeather);
    });

    test('keeps accented characters intact', () {
      // Stripping accents would merge words that differ only by one.
      expect(italian.parse('più').intent, VoiceIntent.unknown);
    });

    test('does not match English phrases', () {
      expect(italian.parse('next track').intent, VoiceIntent.unknown);
    });
  });

  group('confidence gate', () {
    test('a low-confidence match is not actionable', () {
      final command = english.parse('next track', confidence: 0.4);
      expect(command.intent, VoiceIntent.nextTrack);
      // The intent is still reported so the UI can echo what was heard, but
      // acting on it is refused: a false positive here means the car does
      // something the driver never asked for.
      expect(command.isActionable, isFalse);
    });

    test('a confident match is actionable', () {
      expect(english.parse('next track', confidence: 0.9).isActionable, isTrue);
    });

    test('unknown is never actionable, however confident', () {
      expect(english.parse('gibberish', confidence: 1.0).isActionable, isFalse);
    });
  });
}
