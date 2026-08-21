/// Voyager collects nothing, sends nothing and stores no identifiers.
///
/// This file exists as an executable statement of that: it is the only
/// "analytics" entry point in the codebase, and every method is a no-op. If a
/// dependency is ever added that wants an analytics sink, wire it here so the
/// refusal stays in one visible place rather than being scattered.
class Analytics {
  const Analytics._();

  /// Intentionally does nothing.
  static void event(String name, [Map<String, Object?>? properties]) {}

  /// Intentionally does nothing.
  static void screen(String name) {}

  /// Intentionally does nothing. Crashes are surfaced to the user in-app; they
  /// are never uploaded.
  static void crash(Object error, StackTrace stack) {}

  /// Always false. Kept as a getter so UI can honestly show "telemetry: off"
  /// without special-casing.
  static bool get enabled => false;
}
