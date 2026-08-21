import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:voyager/models/music_track.dart';
import 'package:voyager/plugins/music/jellyfin_client.dart';
import 'package:voyager/utils/bounded_client.dart';

void main() {
  late List<http.Request> seen;

  JellyfinClient clientReturning(Map<String, dynamic> body) {
    seen = [];
    return JellyfinClient(
      endpoint: 'http://media.local:8096/',
      apiKey: 'key-123',
      userId: 'user-1',
      httpClient: BoundedClient(
        client: MockClient((request) async {
          seen.add(request);
          return http.Response(jsonEncode(body), 200);
        }),
      ),
    );
  }

  group('JellyfinClient', () {
    test('sends the token as a header, never in the query string', () async {
      await clientReturning(const {'Items': []}).recentAlbums();
      expect(seen.single.headers['X-Emby-Token'], 'key-123');
      expect(seen.single.url.query, isNot(contains('key-123')));
    });

    test('strips a trailing slash from the endpoint', () async {
      await clientReturning(const {'Items': []}).recentAlbums();
      expect(seen.single.url.path, '/Users/user-1/Items');
    });

    test('converts RunTimeTicks to a duration', () async {
      // Ticks are 100 ns each: 4 470 000 000 of them are 447 seconds.
      final tracks = await clientReturning({
        'Items': [
          {'Id': 'a', 'Name': 'Cortez', 'AlbumArtist': 'Neil Young',
           'Album': 'Zuma', 'RunTimeTicks': 4470000000},
        ],
      }).albumTracks('z');
      expect(tracks.single.duration, const Duration(seconds: 447));
      expect(tracks.single.source, MusicSource.jellyfin);
    });

    test('falls back to the first listed artist on a compilation', () async {
      final tracks = await clientReturning({
        'Items': [
          {'Id': 'a', 'Name': 'Track', 'Artists': ['Guest', 'Other']},
        ],
      }).albumTracks('z');
      expect(tracks.single.artist, 'Guest');
    });

    test('requests direct play rather than a transcode', () {
      final url = clientReturning(const {'Items': []}).streamUrl('a');
      expect(url, contains('static=true'));
    });

    test('survives a response with no Items key', () async {
      expect(await clientReturning(const {}).recentAlbums(), isEmpty);
    });
  });
}
