import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Thrown when a response exceeds the caller's byte budget.
class ResponseTooLarge implements Exception {
  final int maxBytes;
  const ResponseTooLarge(this.maxBytes);

  @override
  String toString() => 'Response exceeded $maxBytes bytes';
}

/// An [http.Client] wrapper that refuses to buffer an unbounded response.
///
/// Voyager points at servers the user configured, on networks Voyager cannot
/// vouch for — a mistyped port, a captive portal, or a compromised LAN box can
/// all answer a `getAlbumList` request with a gigabyte of garbage. Without a
/// cap that becomes an OOM kill while the driver is mid-route, which is a far
/// worse failure than an error message.
///
/// Roadstr solves the same problem with its own `BoundedHttp`, but that class
/// creates its client internally and so cannot be exercised from a test. Here
/// the client is injected, which means the code paths the tests run are
/// exactly the ones that ship.
class BoundedClient {
  final http.Client _inner;
  final Duration timeout;

  BoundedClient({http.Client? client, this.timeout = const Duration(seconds: 10)})
      : _inner = client ?? http.Client();

  /// GETs [uri] and decodes the body as JSON.
  ///
  /// Throws [ResponseTooLarge] as soon as the cap is passed, without waiting
  /// for the rest of the body, and [http.ClientException] on transport errors.
  Future<Map<String, dynamic>> getJson(
    Uri uri, {
    Map<String, String>? headers,
    int maxBytes = 8 * 1024 * 1024,
  }) async {
    final body = await getBytes(uri, headers: headers, maxBytes: maxBytes);
    final decoded = jsonDecode(utf8.decode(body));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected a JSON object at the top level');
    }
    return decoded;
  }

  /// GETs [uri], accumulating at most [maxBytes] before aborting.
  Future<List<int>> getBytes(
    Uri uri, {
    Map<String, String>? headers,
    required int maxBytes,
  }) async {
    final request = http.Request('GET', uri);
    if (headers != null) request.headers.addAll(headers);

    final response = await _inner.send(request).timeout(timeout);
    if (response.statusCode != 200) {
      throw http.ClientException('HTTP ${response.statusCode}', uri);
    }
    // Trust the declared length when the server sends one, so an oversized
    // body costs nothing to reject.
    final declared = response.contentLength;
    if (declared != null && declared > maxBytes) {
      throw ResponseTooLarge(maxBytes);
    }
    return _collect(response.stream, maxBytes).timeout(timeout);
  }

  static Future<List<int>> _collect(
    http.ByteStream stream,
    int maxBytes,
  ) async {
    final buffer = <int>[];
    await for (final chunk in stream) {
      buffer.addAll(chunk);
      if (buffer.length > maxBytes) throw ResponseTooLarge(maxBytes);
    }
    return buffer;
  }

  void close() => _inner.close();
}
