import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/music_track.dart';
import '../../models/plugin_manifest.dart';
import '../../utils/logger_automotive.dart';
import '../../widgets/automotive_podcast_view.dart';
import '../base_plugin.dart';
import '../music/audio_service_wrapper.dart';
import 'podcast_models.dart';
import 'podcast_repository.dart';

/// Podcasts: subscriptions, episodes, playback.
///
/// A separate plugin from music rather than a tab inside it, because they are
/// different activities with different controls — you shuffle music and you
/// resume a podcast — but they deliberately share one audio handler. That is
/// what makes the media notification, the queue and the steering-wheel buttons
/// behave identically whichever is playing, and what stops both from playing
/// at once.
class PodcastPlugin extends BasePlugin {
  final PodcastRepository repository;

  VoyagerAudioHandler? _audio;
  StreamSubscription<Duration>? _positionSub;
  bool _ready = false;
  String? _error;

  MusicTrack? _current;
  Duration _position = Duration.zero;
  bool _playing = false;

  PodcastPlugin({PodcastRepository? repository})
      : repository = repository ?? PodcastRepository();

  /// The episode currently loaded in the shared queue, filtered to "actually
  /// a podcast" — see the identical reasoning on `MusicPlugin._ownTrack`. When
  /// music owns the queue instead, this is null and the Podcast tab shows its
  /// subscription list rather than someone else's now-playing card.
  MusicTrack? get nowPlaying => _current;
  Duration get position => _position;
  bool get isPlaying => _playing;

  /// Progress in 0..1, or null when the episode's duration is unknown — some
  /// feeds simply do not report one.
  double? get progress {
    final total = _current?.duration;
    if (total == null || total.inMilliseconds <= 0) return null;
    return (_position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
  }

  @override
  PluginManifest get manifest => const PluginManifest(
        id: 'podcast',
        label: 'Podcasts',
        icon: Icons.podcasts_rounded,
        order: 3,
      );

  @override
  bool get isReady => _ready;

  @override
  String? get initializationError => _error;

  @override
  Future<void> initialize() async {
    try {
      // Shares the handler with music: whichever starts last owns the queue.
      _audio = await AudioServiceBootstrap.instance();
      _watchPlayer();
      _ready = true;
    } catch (error) {
      AutomotiveLogger.error('Podcast', 'initialisation failed', error);
      _error = error.toString();
    }
    notifyListeners();
  }

  /// Mirrors the shared player into local state, exactly as `MusicPlugin`
  /// does for its own tab — both listen to the same handler and each shows
  /// only the slice that belongs to it.
  void _watchPlayer() {
    final audio = _audio;
    if (audio == null) return;
    _positionSub = audio.player
        .createPositionStream(
          minPeriod: const Duration(milliseconds: 500),
          maxPeriod: const Duration(milliseconds: 500),
        )
        .listen(_onPosition);
    audio.player.playerStateStream.listen(_onPlayerState);
  }

  MusicTrack? get _ownTrack {
    final track = _audio?.currentTrack;
    if (track == null || track.source != MusicSource.podcast) return null;
    return track;
  }

  void _onPosition(Duration position) {
    _current = _ownTrack;
    _position = position;
    notifyListeners();
  }

  void _onPlayerState(dynamic playerState) {
    _current = _ownTrack;
    _playing = _current != null && (_audio?.player.playing ?? false);
    notifyListeners();
  }

  List<PodcastSubscription> get subscriptions => repository.subscriptions();

  Future<List<PodcastEpisode>> episodes(PodcastSubscription podcast) =>
      repository.episodes(podcast);

  Future<void> subscribe(PodcastSubscription podcast) async {
    await repository.subscribe(podcast);
    notifyListeners();
  }

  Future<void> unsubscribe(String feedUrl) async {
    await repository.unsubscribe(feedUrl);
    notifyListeners();
  }

  /// Plays [episode], with the rest of the list queued behind it.
  ///
  /// Queued in feed order — newest first — which is the order the list is in.
  /// An episode is a long thing to sit through, so what follows matters less
  /// than it does for music, but silence at the end of a two-hour drive is
  /// worse than the next episode starting.
  Future<void> play(
    PodcastEpisode episode,
    List<PodcastEpisode> queue,
  ) async {
    final audio = _audio;
    if (audio == null) return;
    final tracks = [for (final e in queue) e.toTrack()];
    final index = queue.indexWhere((e) => e.guid == episode.guid);
    await audio.setQueue(tracks, startIndex: index < 0 ? 0 : index);
    await audio.play();
  }

  Future<void> togglePlayPause() async => _audio?.togglePlayPause();
  Future<void> next() async => _audio?.skipToNext();
  Future<void> previous() async => _audio?.skipToPrevious();

  /// Stops playback and forgets the queue — the Podcast tab's close button,
  /// same distinction from pause as `MusicPlugin.stopAndClose`.
  ///
  /// Local state is updated directly here for the same reason it is in
  /// `MusicPlugin.stopAndClose`: `clearQueue()` does not emit a position or
  /// player-state event, which are the only streams [_onPosition] and
  /// [_onPlayerState] react to, so nothing would otherwise pick up that the
  /// queue is now empty.
  Future<void> stopAndClose() async {
    if (_ownTrack == null) return;
    await _audio?.stop();
    await _audio?.clearQueue();
    _current = null;
    _playing = false;
    _position = Duration.zero;
    notifyListeners();
  }

  @override
  Widget buildFullscreenView(BuildContext context) =>
      AutomotivePodcastView(plugin: this);

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }
}
