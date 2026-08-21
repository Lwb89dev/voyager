import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:voyager/models/music_track.dart';
import 'package:voyager/plugins/music/navidrome_client.dart';
import 'package:voyager/utils/bounded_client.dart';
import 'package:voyager/utils/subsonic_api.dart';

/// A Subsonic server that answers [body] wrapped in a successful envelope.
NavidromeClient clientReturning(Map<String, dynamic> body) => NavidromeClient(
      endpoint: 'http://music.local:4533',
      username: 'driver',
      password: 'hunter2',
      httpClient: BoundedClient(
        client: MockClient((_) async => http.Response(
              jsonEncode({
                'subsonic-response': {'status': 'ok', ...body},
              }),
              200,
              headers: {'content-type': 'application/json'},
            )),
      ),
    );

void main() {
  group('NavidromeClient', () {
    test('ping succeeds against a healthy server', () async {
      await clientReturning(const {}).ping();
    });

    test('ping surfaces a credential failure', () async {
      final client = NavidromeClient(
        endpoint: 'http://music.local:4533',
        username: 'driver',
        password: 'wrong',
        httpClient: BoundedClient(
          client: MockClient((_) async => http.Response(
                jsonEncode({
                  'subsonic-response': {
                    'status': 'failed',
                    'error': {'code': 40, 'message': 'Wrong password'},
                  },
                }),
                200,
              )),
        ),
      );
      expect(client.ping, throwsA(isA<SubsonicException>()));
    });

    test('parses albums, including the title/name alias', () async {
      final albums = await clientReturning({
        'albumList2': {
          'album': [
            {'id': '1', 'name': 'Ragged Glory', 'artist': 'Neil Young',
             'coverArt': 'al-1'},
            // Some servers send `title` where others send `name`.
            {'id': '2', 'title': 'Zuma', 'artist': 'Neil Young'},
          ],
        },
      }).recentAlbums();

      expect(albums, hasLength(2));
      expect(albums.first.name, 'Ragged Glory');
      expect(albums.last.name, 'Zuma');
      expect(albums.first.artworkUrl, contains('getCoverArt'));
      expect(albums.last.artworkUrl, isNull);
    });

    test('returns an empty list when the album list is absent', () async {
      // A server with an empty library omits the key rather than sending [].
      expect(await clientReturning(const {}).recentAlbums(), isEmpty);
    });

    test('parses tracks with source and duration', () async {
      final tracks = await clientReturning({
        'album': {
          'song': [
            {'id': '9', 'title': 'Cortez', 'artist': 'Neil Young',
             'album': 'Zuma', 'duration': 447},
          ],
        },
      }).albumTracks('2');

      expect(tracks.single.source, MusicSource.navidrome);
      expect(tracks.single.duration, const Duration(seconds: 447));
      expect(tracks.single.uniqueId, 'navidrome:9');
    });

    test('treats a missing duration as unknown rather than guessing', () async {
      final tracks = await clientReturning({
        'album': {
          'song': [
            {'id': '9', 'title': 'Cortez'},
          ],
        },
      }).albumTracks('2');
      expect(tracks.single.duration, Duration.zero);
    });

    test('builds a stream URL carrying auth but not the password', () {
      final url = clientReturning(const {}).streamUrl('42');
      expect(url, contains('/rest/stream'));
      expect(url, contains('id=42'));
      expect(url, contains('t='));
      expect(url, isNot(contains('hunter2')));
    });
  });
}
