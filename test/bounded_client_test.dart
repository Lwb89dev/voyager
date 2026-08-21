import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:voyager/utils/bounded_client.dart';

void main() {
  group('BoundedClient', () {
    test('decodes a JSON object', () async {
      final client = BoundedClient(
        client: MockClient((_) async => http.Response('{"a":1}', 200)),
      );
      expect(await client.getJson(Uri.parse('http://x/y')), {'a': 1});
    });

    test('rejects a body larger than the cap', () async {
      final body = 'x' * 2048;
      final client = BoundedClient(
        client: MockClient((_) async => http.Response(body, 200)),
      );
      expect(
        () => client.getBytes(Uri.parse('http://x/y'), maxBytes: 1024),
        throwsA(isA<ResponseTooLarge>()),
      );
    });

    test('rejects a chunked body without a declared length', () async {
      // The declared-length shortcut cannot help here, so this exercises the
      // streaming cap — the path that actually protects against a server that
      // lies about, or omits, Content-Length.
      final client = BoundedClient(
        client: MockClient.streaming((request, _) async {
          final chunks = Stream.fromIterable(
            List.generate(10, (_) => utf8.encode('y' * 256)),
          );
          return http.StreamedResponse(chunks, 200);
        }),
      );
      expect(
        () => client.getBytes(Uri.parse('http://x/y'), maxBytes: 1024),
        throwsA(isA<ResponseTooLarge>()),
      );
    });

    test('turns a non-200 into a ClientException', () async {
      final client = BoundedClient(
        client: MockClient((_) async => http.Response('nope', 500)),
      );
      expect(
        () => client.getJson(Uri.parse('http://x/y')),
        throwsA(isA<http.ClientException>()),
      );
    });

    test('rejects a JSON array at the top level', () async {
      final client = BoundedClient(
        client: MockClient((_) async => http.Response('[1,2]', 200)),
      );
      expect(
        () => client.getJson(Uri.parse('http://x/y')),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
