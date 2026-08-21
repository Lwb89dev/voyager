import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voyager/utils/subsonic_api.dart';

void main() {
  group('SubsonicApi authentication', () {
    // Seeded so the salt is reproducible and the URL can be asserted exactly.
    SubsonicApi api() => SubsonicApi(
          endpoint: 'http://music.local:4533',
          username: 'driver',
          password: 'hunter2',
          clientName: 'voyager',
          random: Random(1),
        );

    test('never puts the password in the URL', () {
      final uri = api().uri('ping');
      expect(uri.toString(), isNot(contains('hunter2')));
      expect(uri.queryParameters, isNot(contains('p')));
    });

    test('sends a salted MD5 token matching the salt', () {
      final uri = api().uri('ping');
      final salt = uri.queryParameters['s']!;
      final token = uri.queryParameters['t']!;
      expect(token, md5.convert(utf8.encode('hunter2$salt')).toString());
    });

    test('uses a fresh salt on every request', () {
      // Same instance, two calls: a reused salt would make a captured URL
      // replayable, which is the whole point of the scheme.
      final client = api();
      final first = client.uri('ping').queryParameters['s'];
      final second = client.uri('ping').queryParameters['s'];
      expect(first, isNot(second));
    });

    test('declares an API version that supports token auth', () {
      expect(api().uri('ping').queryParameters['v'], '1.16.1');
    });

    test('does not double the slash when the endpoint has a trailing one', () {
      final client = SubsonicApi(
        endpoint: 'http://music.local:4533/',
        username: 'a',
        password: 'b',
        clientName: 'voyager',
      );
      expect(client.uri('ping').path, '/rest/ping');
    });
  });

  group('SubsonicApi.unwrap', () {
    test('returns the envelope body on success', () {
      final response = SubsonicApi.unwrap({
        'subsonic-response': {'status': 'ok', 'version': '1.16.1'},
      });
      expect(response['version'], '1.16.1');
    });

    test('throws on a failure reported with HTTP 200', () {
      // Subsonic reports wrong credentials as a 200 with status "failed".
      // Trusting the status code alone would read that as an empty library.
      expect(
        () => SubsonicApi.unwrap({
          'subsonic-response': {
            'status': 'failed',
            'error': {'code': 40, 'message': 'Wrong username or password'},
          },
        }),
        throwsA(isA<SubsonicException>()
            .having((e) => e.isAuthFailure, 'isAuthFailure', isTrue)),
      );
    });

    test('throws when the envelope is missing entirely', () {
      expect(
        () => SubsonicApi.unwrap({'something': 'else'}),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
