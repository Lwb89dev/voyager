import '../../models/music_track.dart';

/// What the music plugin is doing, as a value the UI can switch on.
enum MusicStatus {
  /// No backend configured and no local files found.
  unavailable,

  /// Talking to the server for the first time.
  loading,

  /// Library loaded, nothing playing yet.
  idle,

  playing,
  paused,

  /// The backend answered with an error, or stopped answering. [MusicState]
  /// carries the reason.
  failed,
}

/// Immutable snapshot of the music plugin, rebuilt on every change.
///
/// A value type rather than a bag of mutable fields on the plugin: the player
/// emits position updates several times a second, and having the UI diff whole
/// snapshots is what keeps a stray `setState` from rebuilding the map beneath
/// the overlay.
class MusicState {
  final MusicStatus status;
  final MusicSource source;
  final List<MusicAlbum> albums;
  final MusicTrack? current;
  final Duration position;

  /// Server or filesystem error, in a form fit to show a user. Null unless
  /// [status] is [MusicStatus.failed].
  final String? error;

  const MusicState({
    required this.status,
    required this.source,
    this.albums = const [],
    this.current,
    this.position = Duration.zero,
    this.error,
  });

  const MusicState.initial()
      : status = MusicStatus.loading,
        source = MusicSource.local,
        albums = const [],
        current = null,
        position = Duration.zero,
        error = null;

  bool get isPlaying => status == MusicStatus.playing;

  /// Playback progress in 0..1, or null when the track length is unknown —
  /// which is the honest answer for a live stream or a file whose duration the
  /// server did not report. The UI shows an indeterminate bar for null rather
  /// than a bar stuck at zero.
  double? get progress {
    final total = current?.duration;
    if (total == null || total.inMilliseconds <= 0) return null;
    return (position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
  }

  MusicState copyWith({
    MusicStatus? status,
    MusicSource? source,
    List<MusicAlbum>? albums,
    MusicTrack? current,
    Duration? position,
    String? error,
    // `current: null` is indistinguishable from "not passed" through `??`, so
    // clearing the now-playing track needs its own explicit flag rather than
    // overloading the nullable parameter. Without it, closing the player
    // could never make `current` actually become null.
    bool clearCurrent = false,
  }) =>
      MusicState(
        status: status ?? this.status,
        source: source ?? this.source,
        albums: albums ?? this.albums,
        current: clearCurrent ? null : (current ?? this.current),
        position: position ?? this.position,
        error: error,
      );
}
