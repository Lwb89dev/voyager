import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/gesture_event.dart';
import '../../models/music_track.dart';
import '../../models/plugin_manifest.dart';
import '../../services/open_source_config.dart';
import '../../utils/logger_automotive.dart';
import '../../widgets/automotive_music_player.dart';
import '../base_plugin.dart';
import 'audio_service_wrapper.dart';
import 'equalizer_controller.dart';
import 'jellyfin_client.dart';
import 'media_store_library.dart';
import 'music_library.dart';
import 'music_state.dart';
import 'navidrome_client.dart';

/// Playback, the library and the two music views.
///
/// Backend choice is resolved once at initialisation and never revisited at
/// runtime: Navidrome if configured, else Jellyfin, else whatever is on the
/// device. Falling back mid-drive would mean the queue silently changing
/// underneath the driver, which is worse than an error message.
class MusicPlugin extends BasePlugin {
  final OpenSourceConfig config;

  /// Injected by the tests with a fake; null in production, where the real
  /// library is built from [config].
  final MusicLibrary? libraryOverride;

  MusicLibrary? _library;
  VoyagerAudioHandler? _audio;
  EqualizerController? _equalizer;
  StreamSubscription<Duration>? _positionSub;

  MusicState _state = const MusicState.initial();
  bool _ready = false;
  String? _error;

  MusicPlugin({required this.config, this.libraryOverride});

  MusicState get state => _state;

  /// The output equalizer, or null before the audio handler exists.
  EqualizerController? get equalizer => _equalizer;

  @override
  PluginManifest get manifest => PluginManifest(
        id: 'music',
        label: 'Music',
        icon: Icons.music_note_rounded,
        order: 1,
        providesOverlay: true,
        // Lowest of the three: a track playing is the least urgent reason to
        // cover the map.
        overlayPriority: 1,
      );

  @override
  bool get isReady => _ready;

  @override
  String? get initializationError => _error;

  @override
  Future<void> initialize() async {
    try {
      _audio = await AudioServiceBootstrap.instance();
      _equalizer = EqualizerController(effect: _audio!.equalizer);
      // The platform effect only exists once there is an audio session, so the
      // saved curve is restored after the first track loads rather than now.
      unawaited(_audio!.sourceLoaded.then((_) => _equalizer!.initialize()));
      _library = libraryOverride ?? await _buildLibrary();
      await _library!.verify();
      final albums = await _library!.albums();
      _state = _state.copyWith(
        status: MusicStatus.idle,
        source: _library!.source,
        albums: albums,
      );
      _ready = true;
      _watchPlayer();
    } catch (error) {
      // Never rethrow: a music server that is down must cost the driver a
      // greyed-out button, not the dashboard.
      AutomotiveLogger.error('Music', 'initialisation failed', error);
      _error = _describe(error);
      _state = _state.copyWith(status: MusicStatus.failed, error: _error);
    }
    notifyListeners();
  }

  Future<MusicLibrary> _buildLibrary() async {
    if (config.hasNavidrome) {
      return NavidromeLibrary(NavidromeClient(
        endpoint: config.navidromeEndpoint!,
        username: config.navidromeUsername!,
        password: config.navidromePassword!,
      ));
    }
    if (config.hasJellyfin) {
      return JellyfinLibrary(JellyfinClient(
        endpoint: config.jellyfinEndpoint!,
        apiKey: config.jellyfinApiKey!,
        userId: config.jellyfinUserId!,
      ));
    }
    return MediaStoreLibrary.forDevice();
  }

  /// Mirrors the player's position into [state].
  ///
  /// Sampled at 500 ms rather than subscribing to the raw position stream:
  /// the raw stream fires far more often than a progress bar 8 logical pixels
  /// tall can show, and every extra tick is a rebuild competing with map
  /// rendering for the same frame budget.
  void _watchPlayer() {
    final audio = _audio;
    if (audio == null) return;
    // Both periods, not just the minimum: just_audio defaults maxPeriod to
    // 200 ms and asserts minPeriod <= maxPeriod, so raising only the floor
    // threw the moment the music pane was opened.
    _positionSub = audio.player
        .createPositionStream(
          minPeriod: const Duration(milliseconds: 500),
          maxPeriod: const Duration(milliseconds: 500),
        )
        .listen(_onPosition);
    audio.player.playerStateStream.listen(_onPlayerState);
  }

  /// The shared queue's current track, filtered to "actually music."
  ///
  /// Music and podcasts play through the same [VoyagerAudioHandler] so the
  /// media notification, the queue and the steering-wheel buttons behave
  /// identically whichever is playing. That sharing means this plugin's own
  /// position/state stream fires just as often when a *podcast* episode is
  /// playing — without this filter the Music tab would show a podcast under
  /// "now playing," which is exactly the cross-tab leakage the two tabs are
  /// meant not to have.
  MusicTrack? get _ownTrack {
    final track = _audio?.currentTrack;
    if (track == null || track.source == MusicSource.podcast) return null;
    return track;
  }

  void _onPosition(Duration position) {
    final own = _ownTrack;
    _state = _state.copyWith(
      position: position,
      current: own,
      clearCurrent: own == null,
    );
    notifyListeners();
  }

  void _onPlayerState(dynamic playerState) {
    final own = _ownTrack;
    final playing = own != null && (_audio?.player.playing ?? false);
    _state = _state.copyWith(
      status: own == null ? MusicStatus.idle : (playing ? MusicStatus.playing : MusicStatus.paused),
      current: own,
      clearCurrent: own == null,
    );
    notifyListeners();
  }

  // ── Actions ─────────────────────────────────────────────────────────────

  Future<void> playAlbum(MusicAlbum album) async {
    final library = _library;
    if (library == null) return;
    await _play(await library.tracksOf(album.id));
  }

  /// Starts an album at [track] and keeps the rest of it queued behind.
  ///
  /// Picking a song from a record almost never means "play this and then
  /// stop", so the queue is the album from that point rather than one track.
  Future<void> playAlbumFrom(MusicAlbum album, MusicTrack track) async {
    final library = _library;
    if (library == null) return;
    final tracks = await library.tracksOf(album.id);
    final index = tracks.indexWhere((t) => t.uniqueId == track.uniqueId);
    if (index < 0) return _play(tracks);
    await _audio?.setQueue(tracks, startIndex: index);
    await _audio?.play();
  }

  /// Plays one track on its own — chosen from the flat song list, where there
  /// is no album context to continue into.
  Future<void> playTrack(MusicTrack track) => _play([track]);

  Future<List<MusicArtist>> artists() async =>
      await _library?.artists() ?? const [];

  Future<List<MusicAlbum>> albumsOfArtist(String artistId) async =>
      await _library?.albumsOfArtist(artistId) ?? const [];

  Future<List<MusicTrack>> tracksOfAlbum(MusicAlbum album) async =>
      await _library?.tracksOf(album.id) ?? const [];

  Future<List<MusicTrack>> allTracks() async =>
      await _library?.allTracks() ?? const [];

  /// The one-tap action: a shuffled queue, playing immediately. This is the
  /// only music control the UI encourages using while moving.
  Future<void> shuffleAll() async {
    final library = _library;
    if (library == null) return;
    await _play(await library.shuffle());
  }

  Future<void> _play(List<MusicTrack> tracks) async {
    if (tracks.isEmpty || _audio == null) return;
    await _audio!.setQueue(tracks);
    await _audio!.play();
  }

  Future<void> togglePlayPause() async => _audio?.togglePlayPause();
  Future<void> next() async => _audio?.skipToNext();
  Future<void> previous() async => _audio?.skipToPrevious();

  /// Stops playback and forgets the queue — distinct from pause, which keeps
  /// the track loaded so a second tap resumes it. This is the dashboard's
  /// close button: the driver is done, not merely distracted.
  ///
  /// [MusicState] is rebuilt here directly rather than left to [_onPosition]/
  /// [_onPlayerState]: those only fire from the player's own position/state
  /// streams, and clearing the queue does not emit either — `stop()` already
  /// fired its one state event before `clearQueue()` ran, so without this the
  /// "now playing" card the driver just dismissed stayed on screen, paused,
  /// until something else happened to play.
  Future<void> stopAndClose() async {
    if (_ownTrack == null) return;
    await _audio?.stop();
    await _audio?.clearQueue();
    _state = _state.copyWith(status: MusicStatus.idle, clearCurrent: true);
    notifyListeners();
  }

  // ── Plugin surface ──────────────────────────────────────────────────────

  @override
  Widget buildFullscreenView(BuildContext context) =>
      AutomotiveMusicPlayer(plugin: this);

  // No overlay: playback controls live only on the Music tab now. A bar that
  // floated over every other screen looked like a persistent feature but
  // actually cost the driver a slice of the map, the settings list and the
  // navigation panel for as long as anything was playing — and it could not
  // be dismissed short of stopping the music entirely.

  @override
  bool onPhysicalButtonPress(GestureEvent event) {
    switch (event.button) {
      case PhysicalButton.volumeUp:
      case PhysicalButton.mediaNext:
        unawaited(next());
        return true;
      case PhysicalButton.volumeDown:
      case PhysicalButton.mediaPrevious:
        unawaited(previous());
        return true;
      case PhysicalButton.mediaPlayPause:
        unawaited(togglePlayPause());
        return true;
      default:
        return false;
    }
  }

  static String _describe(Object error) {
    final text = error.toString();
    // Strip the exception class name: "SubsonicException: Wrong username or
    // password" is developer-facing, the tail alone is what a driver needs.
    final colon = text.indexOf(': ');
    return colon < 0 ? text : text.substring(colon + 2);
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _library?.close();
    super.dispose();
  }
}
