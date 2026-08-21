import 'package:flutter/foundation.dart';

/// Logging that goes quiet once the car is moving.
///
/// Two reasons, both borrowed from Roadstr's own policy. First, privacy: route
/// legs, street names and coordinates must not end up in logcat, where any
/// app holding READ_LOGS on an older device could read them. Second, cost:
/// `debugPrint` is synchronous and rate-limited, and a chatty log during a
/// navigation frame is a real source of jank.
class AutomotiveLogger {
  const AutomotiveLogger._();

  /// Set by the navigation plugin whenever guidance starts or stops.
  static bool driving = false;

  /// Diagnostics. Dropped in release builds and while driving.
  static void debug(String tag, String message) {
    if (kReleaseMode || driving) return;
    debugPrint('[$tag] $message');
  }

  /// Something went wrong but the app carries on. Kept while driving, because
  /// a silently failing music server is exactly what we need to see later —
  /// but never in release, for the privacy reason above.
  static void warn(String tag, String message) {
    if (kReleaseMode) return;
    debugPrint('[$tag] WARN $message');
  }

  /// Unrecoverable for the subsystem involved. Always emitted in debug;
  /// in release only the tag survives, never the message body, which may
  /// contain a server URL or a place name.
  static void error(String tag, String message, [Object? cause]) {
    if (kReleaseMode) {
      debugPrint('[$tag] error');
      return;
    }
    debugPrint('[$tag] ERROR $message${cause == null ? '' : ' — $cause'}');
  }
}
