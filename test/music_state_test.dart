import 'package:flutter_test/flutter_test.dart';
import 'package:voyager/models/music_track.dart';
import 'package:voyager/plugins/music/music_state.dart';

MusicTrack track({Duration duration = const Duration(minutes: 4)}) => MusicTrack(
      id: '1',
      source: MusicSource.navidrome,
      title: 'Cortez',
      artist: 'Neil Young',
      album: 'Zuma',
      duration: duration,
      streamUrl: 'http://x/1',
    );

void main() {
  group('progress', () {
    test('is the fraction played', () {
      final state = MusicState(
        status: MusicStatus.playing,
        source: MusicSource.navidrome,
        current: track(),
        position: const Duration(minutes: 1),
      );
      expect(state.progress, closeTo(0.25, 0.001));
    });

    test('is null when the track length is unknown', () {
      // A zero duration means "the server did not say", not "zero seconds
      // long". Returning 0 here would render a bar pinned at empty for the
      // whole track, which reads as a stall.
      final state = MusicState(
        status: MusicStatus.playing,
        source: MusicSource.local,
        current: track(duration: Duration.zero),
        position: const Duration(seconds: 30),
      );
      expect(state.progress, isNull);
    });

    test('is null with no track at all', () {
      const state = MusicState.initial();
      expect(state.progress, isNull);
    });

    test('clamps a position past the end', () {
      final state = MusicState(
        status: MusicStatus.playing,
        source: MusicSource.navidrome,
        current: track(),
        position: const Duration(minutes: 9),
      );
      expect(state.progress, 1.0);
    });
  });

  test('tracks compare by source and id, not by title', () {
    final navidrome = track();
    final jellyfin = MusicTrack(
      id: '1',
      source: MusicSource.jellyfin,
      title: 'Cortez',
      artist: 'Neil Young',
      album: 'Zuma',
      duration: const Duration(minutes: 4),
      streamUrl: 'http://y/1',
    );
    expect(navidrome, isNot(jellyfin));
    expect(navidrome.uniqueId, 'navidrome:1');
  });
}
