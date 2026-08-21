/// Physical controls Voyager reacts to.
///
/// These are not screen gestures. On a car head unit the important inputs are
/// the steering-wheel remote and the hardware keys on the dock, because they
/// can be operated without looking. Android delivers most of them as ordinary
/// key events; a few arrive over Bluetooth AVRCP instead.
enum PhysicalButton {
  /// Steering-wheel volume rocker. Voyager maps these to previous/next track
  /// rather than volume when music has focus — car volume is already handled
  /// by the amplifier, and track skipping is the action drivers actually want
  /// on the wheel.
  volumeUp,
  volumeDown,

  /// The dedicated voice key (KEYCODE_VOICE_ASSIST), where the unit has one.
  voice,

  /// Menu / back / mode key. Returns to the navigation plugin.
  menu,

  /// AVRCP transport keys, when the remote sends those instead.
  mediaNext,
  mediaPrevious,
  mediaPlayPause,
}

/// A button press with the moment it happened.
///
/// The timestamp is what makes long-press and double-press detection possible
/// without every consumer keeping its own stopwatch.
class GestureEvent {
  final PhysicalButton button;
  final DateTime at;

  /// True when the key event was a repeat produced by the driver holding the
  /// button down, rather than a fresh press.
  final bool isRepeat;

  const GestureEvent({
    required this.button,
    required this.at,
    this.isRepeat = false,
  });

  @override
  String toString() => 'GestureEvent(${button.name}, repeat=$isRepeat)';
}
