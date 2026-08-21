import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../../models/music_track.dart';
import '../../utils/logger_automotive.dart';

/// The background audio handler: what actually plays sound.
///
/// This runs inside audio_service's background isolate binding, which is what
/// gives Voyager a media notification, lock-screen controls, and — the part
/// that matters in a car — working Bluetooth AVRCP buttons on the steering
/// wheel. Without audio_service, `just_audio` alone stops when the app is
/// backgrounded and the wheel controls do nothing.
class VoyagerAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  /// The output equalizer, inserted into the player's pipeline.
  ///
  /// It has to be attached at construction: just_audio builds the platform
  /// audio session from the pipeline when the player is created, and an effect
  /// added afterwards has nothing to attach to. It stays disabled until the
  /// user turns it on, so the default path is bit-identical to no equalizer.
  final AndroidEqualizer equalizer = AndroidEqualizer();

  late final AudioPlayer _player = AudioPlayer(
    audioPipeline: AudioPipeline(androidAudioEffects: [equalizer]),
  );

  /// Queue in Voyager's own model, parallel to [queue]'s MediaItems. Kept
  /// because MediaItem cannot carry [MusicSource] without stuffing it into
  /// `extras` and casting it back out at every read.
  final List<MusicTrack> _tracks = [];

  VoyagerAudioHandler() {
    _player.playbackEventStream.listen(_broadcastState, onError: _onError);
    _player.currentIndexStream.listen(_onIndexChanged);
  }

  AudioPlayer get player => _player;

  /// Completes once a source has been loaded, which is the earliest the
  /// platform equalizer exists and can report its bands.
  Future<void> get sourceLoaded => _sourceLoaded.future;
  final Completer<void> _sourceLoaded = Completer<void>();
  List<MusicTrack> get tracks => List.unmodifiable(_tracks);

  MusicTrack? get currentTrack {
    final index = _player.currentIndex;
    if (index == null || index < 0 || index >= _tracks.length) return null;
    return _tracks[index];
  }

  /// Replaces the queue and starts playing at [startIndex].
  ///
  /// Uses a gapless concatenating source rather than loading one track at a
  /// time: a two-second silence between tracks on an album is exactly the sort
  /// of thing that makes a driver reach for the screen.
  Future<void> setQueue(List<MusicTrack> tracks, {int startIndex = 0}) async {
    if (tracks.isEmpty) return;
    _tracks
      ..clear()
      ..addAll(tracks);
    queue.add(tracks.map(_toMediaItem).toList());
    mediaItem.add(_toMediaItem(tracks[startIndex.clamp(0, tracks.length - 1)]));

    final sources = tracks.map((t) => AudioSource.uri(Uri.parse(t.streamUrl)));
    await _player.setAudioSources(
      sources.toList(),
      initialIndex: startIndex.clamp(0, tracks.length - 1),
      initialPosition: Duration.zero,
    );
    if (!_sourceLoaded.isCompleted) _sourceLoaded.complete();
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  /// Empties the queue after a [stop], so [currentTrack] and [mediaItem]
  /// genuinely go back to nothing rather than remembering the last track.
  ///
  /// `just_audio`'s `stop()` halts playback but leaves the audio sources and
  /// `currentIndex` in place — reasonable for a transport "stop" button that
  /// expects a later "play" to resume where it left off, wrong for the
  /// dashboard's close button, which means "I am done, forget this queue."
  /// Without this, [currentTrack] kept returning the closed track and the
  /// "now playing" card the driver just dismissed reappeared on the next
  /// rebuild.
  Future<void> clearQueue() async {
    _tracks.clear();
    queue.add(const []);
    mediaItem.add(null);
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() async {
    // The behaviour every car stereo has: the first press restarts the track,
    // and only a second press within a few seconds goes back one. Skipping
    // straight back is almost never what someone means three minutes into a
    // song.
    if (_player.position > const Duration(seconds: 3)) {
      await _player.seek(Duration.zero);
      return;
    }
    await _player.seekToPrevious();
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= _tracks.length) return;
    await _player.seek(Duration.zero, index: index);
  }

  Future<void> togglePlayPause() =>
      _player.playing ? pause() : play();

  void _onIndexChanged(int? index) {
    if (index == null || index < 0 || index >= _tracks.length) return;
    mediaItem.add(_toMediaItem(_tracks[index]));
  }

  void _onError(Object error, StackTrace stack) {
    // A dead stream URL must not kill playback of the rest of the queue: an
    // expired Subsonic token or a single unreadable file is a normal event on
    // a self-hosted server.
    AutomotiveLogger.error('Audio', 'playback error', error);
  }

  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        playing ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {MediaAction.seek},
      androidCompactActionIndices: const [0, 1, 2],
      processingState: _processingState(),
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    ));
  }

  AudioProcessingState _processingState() {
    switch (_player.processingState) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  static MediaItem _toMediaItem(MusicTrack track) => MediaItem(
        id: track.uniqueId,
        title: track.title,
        artist: track.artist,
        album: track.album,
        duration: track.duration == Duration.zero ? null : track.duration,
        artUri: track.artworkUrl == null ? null : Uri.parse(track.artworkUrl!),
      );

  Future<void> disposePlayer() => _player.dispose();
}

/// Creates and registers the background handler.
///
/// Must be called exactly once per process. audio_service throws on a second
/// registration, which is why this is a top-level function guarded by a
/// completer rather than something a plugin can call in its constructor.
class AudioServiceBootstrap {
  const AudioServiceBootstrap._();

  /// The in-flight or completed initialisation.
  ///
  /// A Future rather than the handler itself, because two plugins ask for it
  /// at the same moment: music and podcasts both come up during
  /// `initializeAll`, which runs them concurrently. Caching only the finished
  /// handler left a window where both saw null and both called
  /// `AudioService.init` — which may run once per process, so the second one
  /// threw and that plugin never became ready.
  static Future<VoyagerAudioHandler>? _pending;

  static Future<VoyagerAudioHandler> instance() {
    return _pending ??= _create();
  }

  static Future<VoyagerAudioHandler> _create() async {
    final handler = await AudioService.init(
      builder: VoyagerAudioHandler.new,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.voyager.voyager.audio',
        androidNotificationChannelName: 'Voyager playback',
        // The notification must survive the app being swept out of recents:
        // in a car the app is frequently backgrounded by a navigation prompt
        // or an incoming call, and playback stopping at that point is a
        // distraction, not a feature.
        androidStopForegroundOnPause: false,
        androidNotificationOngoing: false,
      ),
    );
    return handler;
  }
}
