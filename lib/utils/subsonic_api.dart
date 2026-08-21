import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Request construction for the Subsonic API, which Navidrome implements.
///
/// The important part is authentication. The original Subsonic scheme puts the
/// password in the query string, either in the clear or hex-encoded — which is
/// not encryption, just an inconvenience. Since API version 1.13.0 the
/// supported scheme is a salted hash: the client picks a fresh random salt per
/// request and sends `t = md5(password + salt)` alongside it, so the password
/// itself never crosses the wire and a captured URL cannot be replayed against
/// a different salt.
///
/// MD5 is not a defensible choice in 2026, but it is what the protocol
/// mandates; the mitigation that matters is that the plaintext password stays
/// on the device. Any Navidrome release from the last several years accepts
/// this scheme.
class SubsonicApi {
  /// The lowest API version implementing salted-token auth. Servers older than
  /// this would need the plaintext scheme, which Voyager will not send.
  static const String apiVersion = '1.16.1';

  final String endpoint;
  final String username;
  final String password;
  final String clientName;

  /// Injectable so tests can assert on an exact URL. Production uses a
  /// cryptographically secure generator.
  final Random _random;

  SubsonicApi({
    required this.endpoint,
    required this.username,
    required this.password,
    required this.clientName,
    Random? random,
  }) : _random = random ?? Random.secure();

  /// Builds a request URI for [method] with a fresh salt.
  ///
  /// Calling this twice with identical arguments yields two different URLs;
  /// that is the point, so never cache the result.
  Uri uri(String method, [Map<String, String> params = const {}]) {
    final salt = _salt();
    final base = endpoint.endsWith('/')
        ? endpoint.substring(0, endpoint.length - 1)
        : endpoint;
    return Uri.parse('$base/rest/$method').replace(queryParameters: {
      ...params,
      'u': username,
      't': token(password, salt),
      's': salt,
      'v': apiVersion,
      'c': clientName,
      'f': 'json',
    });
  }

  /// `md5(password + salt)`, lowercase hex — the `t` parameter.
  static String token(String password, String salt) =>
      md5.convert(utf8.encode('$password$salt')).toString();

  /// A fresh salt. The spec requires at least six characters; twelve hex
  /// characters (48 bits) makes collisions between concurrent requests a
  /// non-issue without bloating the URL.
  String _salt() {
    const alphabet = '0123456789abcdef';
    return List.generate(
      12,
      (_) => alphabet[_random.nextInt(alphabet.length)],
    ).join();
  }

  /// Unwraps the `subsonic-response` envelope and converts a server-reported
  /// failure into an exception.
  ///
  /// Subsonic answers errors with HTTP 200 and `status: "failed"` in the body,
  /// so checking the status code alone silently accepts "wrong password" as a
  /// successful, empty library.
  static Map<String, dynamic> unwrap(Map<String, dynamic> json) {
    final response = json['subsonic-response'];
    if (response is! Map<String, dynamic>) {
      throw const FormatException('Missing subsonic-response envelope');
    }
    if (response['status'] != 'ok') {
      final error = response['error'];
      final message = error is Map ? error['message'] : null;
      final code = error is Map ? error['code'] : null;
      throw SubsonicException(
        message?.toString() ?? 'Unknown server error',
        code is int ? code : null,
      );
    }
    return response;
  }
}

class SubsonicException implements Exception {
  final String message;

  /// Subsonic error code, when the server sent one. 40 is bad credentials and
  /// 30 is a server too old for this client — both worth telling the user
  /// apart from a generic failure.
  final int? code;

  const SubsonicException(this.message, [this.code]);

  bool get isAuthFailure => code == 40;
  bool get isVersionTooOld => code == 30;

  @override
  String toString() => 'Subsonic error${code == null ? '' : ' $code'}: $message';
}
