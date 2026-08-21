import 'package:flutter/services.dart';

import '../../models/music_track.dart';
import '../../services/permission_service.dart';
import '../../utils/logger_automotive.dart';
import 'local_music_library.dart';
import 'music_folder_service.dart';
import 'music_library.dart';

/// The device's music, read from Android's own media index.
///
/// One query returns every audio file on the device with its tags already
/// parsed. The directory walk this replaces had to open files to learn anything
/// beyond their names, took seconds over a real library, and — under scoped
/// storage — could not reliably read the shared volume at all.
///
/// Tracks are addressed by `content://` URI rather than by path, so ExoPlayer
/// opens them through the content resolver and Voyager never needs filesystem
/// access to the music itself.
class MediaStoreLibrary extends MusicLibrary {
  static const MethodChannel _channel =
      MethodChannel('com.voyager.voyager/media_store');

  /// Optional subtree filter. Set when the user picked a specific folder;
  /// null indexes everything, which is what most people want.
  final String? folderFilter;

  /// Injectable so the tests can feed a fixed cursor result without a device.
  final Future<List<Object?>> Function(String? pathPrefix) _query;

  final Map<String, List<MusicTrack>> _byAlbum = {};
  final List<MusicAlbum> _albums = [];

  MediaStoreLibrary({
    this.folderFilter,
    Future<List<Object?>> Function(String? pathPrefix)? query,
  }) : _query = query ?? _platformQuery;

  static Future<List<Object?>> _platformQuery(String? pathPrefix) async =>
      await _channel.invokeMethod<List<Object?>>(
        'queryAudio',
        {'pathPrefix': pathPrefix},
      ) ??
      const [];

  /// Builds a library over the user's chosen folder, or over everything.
  static MediaStoreLibrary forDevice() =>
      MediaStoreLibrary(folderFilter: MusicFolderService.chosenFolder);

  @override
  MusicSource get source => MusicSource.local;

  @override
  Future<void> verify() async {
    final access = await MusicFolderService.accessState();
    if (access != PermissionState.granted) {
      throw const MusicLibraryUnavailable(
        MusicLibraryProblem.permissionMissing,
      );
    }

    await _load();
    if (_albums.isEmpty) {
      throw MusicLibraryUnavailable(
        MusicLibraryProblem.folderEmpty,
        path: folderFilter,
      );
    }
  }

  Future<void> _load() async {
    _byAlbum.clear();
    _albums.clear();

    final rows = await _query(folderFilter);
    for (final row in rows) {
      if (row is! Map) continue;
      _add(row);
    }

    _byAlbum.forEach(_recordAlbum);
    _albums.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    AutomotiveLogger.debug(
      'Music',
      'indexed ${rows.length} tracks in ${_albums.length} albums',
    );
  }

  void _add(Map row) {
    // Grouping by album id rather than by album name: two different records can
    // share a title, and "Greatest Hits" is not one album.
    final albumId = (row['albumId'] ?? '').toString();
    _byAlbum.putIfAbsent(albumId, () => []).add(MusicTrack(
          id: (row['id'] ?? '').toString(),
          source: MusicSource.local,
          title: _text(row['title']),
          artist: _text(row['artist']),
          album: _text(row['album']),
          duration: Duration(
            milliseconds: (row['durationMs'] as num?)?.toInt() ?? 0,
          ),
          streamUrl: (row['uri'] ?? '').toString(),
          artworkUrl: (row['artUri'] as String?)?.isNotEmpty == true
              ? row['artUri'] as String
              : null,
        ));
  }

  void _recordAlbum(String albumId, List<MusicTrack> tracks) {
    // The native query already orders by track number; nothing to re-sort.
    final first = tracks.first;
    _albums.add(MusicAlbum(
      id: albumId,
      source: MusicSource.local,
      name: first.album.isEmpty ? _unknownAlbum : first.album,
      artist: first.artist,
      artworkUrl: first.artworkUrl,
    ));
  }

  @override
  Future<List<MusicAlbum>> albums() async {
    if (_albums.isEmpty) await _load();
    return List.unmodifiable(_albums);
  }

  @override
  Future<List<MusicTrack>> tracksOf(String albumId) async =>
      List.unmodifiable(_byAlbum[albumId] ?? const []);

  /// Overridden because the whole index is already in memory: this sees every
  /// artist on every track, not only the ones credited as album artist.
  @override
  Future<List<MusicArtist>> artists() async {
    if (_albums.isEmpty) await _load();
    // Keyed case-insensitively: tags are typed by hand and by a dozen
    // different rippers, so "30 Seconds to Mars" and "30 Seconds To Mars" are
    // one band listed twice unless the key ignores case.
    final byName = <String, MusicArtist>{};
    for (final track in _byAlbum.values.expand((t) => t)) {
      if (track.artist.isEmpty) continue;
      byName.putIfAbsent(
        track.artist.toLowerCase(),
        () => MusicArtist(
            id: track.artist, source: MusicSource.local, name: track.artist),
      );
    }
    final list = byName.values.toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  @override
  Future<List<MusicTrack>> allTracks() async {
    if (_albums.isEmpty) await _load();
    final tracks = _byAlbum.values.expand((t) => t).toList();
    tracks.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return tracks;
  }

  /// Tracks credited to [artistId], across every album.
  Future<List<MusicTrack>> tracksOfArtist(String artistId) async {
    if (_albums.isEmpty) await _load();
    final wanted = artistId.toLowerCase();
    return _byAlbum.values
        .expand((t) => t)
        .where((t) => t.artist.toLowerCase() == wanted)
        .toList();
  }

  @override
  Future<List<MusicTrack>> shuffle() async {
    final all = _byAlbum.values.expand((tracks) => tracks).toList();
    all.shuffle();
    return all.take(50).toList();
  }

  /// MediaStore writes an empty string where a tag is missing (the native side
  /// already normalises Android's literal `<unknown>`). The UI needs something
  /// to draw, and a blank row reads as a rendering bug.
  static String _text(Object? value) => (value ?? '').toString();

  static const String _unknownAlbum = 'Unknown album';

  @override
  void close() {}
}
