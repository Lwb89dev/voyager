import 'dart:io';

import '../../models/music_track.dart';
import '../../services/permission_service.dart';
import 'music_folder_service.dart';
import 'music_library.dart';

/// Why the local library could not be opened.
enum MusicLibraryProblem {
  /// READ_MEDIA_AUDIO (or READ_EXTERNAL_STORAGE) was never granted. Nothing on
  /// the shared volume is readable until it is.
  permissionMissing,

  /// No folder was chosen and none of the usual locations exist.
  noFolderChosen,

  /// The folder is readable and holds nothing Voyager can play.
  folderEmpty,
}

class MusicLibraryUnavailable implements Exception {
  final MusicLibraryProblem problem;
  final String? path;

  const MusicLibraryUnavailable(this.problem, {this.path});

  @override
  String toString() {
    switch (problem) {
      case MusicLibraryProblem.permissionMissing:
        return 'Voyager cannot read audio files yet — grant access in Settings';
      case MusicLibraryProblem.noFolderChosen:
        return 'No music folder chosen';
      case MusicLibraryProblem.folderEmpty:
        return 'No playable audio in ${path ?? 'the chosen folder'}';
    }
  }
}

/// Audio files already on the device.
///
/// This is the floor Voyager never falls through: no server, no network, no
/// credentials, and it still plays music. It matters more than it looks — a
/// self-hosted library is unreachable exactly when a car is most likely to be
/// somewhere interesting.
///
/// The scan is deliberately shallow in ambition: filenames and folder names,
/// no tag parsing. Reading ID3 frames off a thousand files on a phone costs
/// seconds of startup, and the folder layout that people who curate their own
/// music already use — Artist/Album/NN Title.mp3 — carries the same
/// information for free.
class LocalMusicLibrary extends MusicLibrary {
  /// Extensions just_audio can decode on Android without transcoding.
  static const _audioExtensions = {
    '.mp3',
    '.m4a',
    '.aac',
    '.flac',
    '.ogg',
    '.opus',
    '.wav',
  };

  /// Guard against walking an entire 256 GB card. A car library is a few
  /// thousand files; anything beyond this is a wrong directory, not a big
  /// collection.
  static const _maxFiles = 5000;

  final List<Directory> _roots;
  final Map<String, List<MusicTrack>> _byAlbum = {};
  final List<MusicAlbum> _albums = [];

  LocalMusicLibrary._(this._roots);

  /// Builds a library over the folder the user chose, or over the usual
  /// locations when they never chose one.
  ///
  /// Note what this deliberately does *not* use: `getExternalStorageDirectories`
  /// with the music type. That returns the app's own private media directory,
  /// which is empty on every device where the user has not copied files into it
  /// by hand — the original cause of "no playable audio files were found".
  static Future<LocalMusicLibrary> forDevice() async =>
      LocalMusicLibrary._(await MusicFolderService.foldersToScan());

  @override
  MusicSource get source => MusicSource.local;

  @override
  Future<void> verify() async {
    // Say which of the two failures it is. "No music found" when the folder was
    // never chosen is a setup step; the same message when the permission is
    // missing sends the user hunting through their filesystem for a problem
    // that is not there.
    final access = await MusicFolderService.accessState();
    if (access != PermissionState.granted) {
      throw const MusicLibraryUnavailable(
        MusicLibraryProblem.permissionMissing,
      );
    }
    if (_roots.isEmpty) {
      throw const MusicLibraryUnavailable(MusicLibraryProblem.noFolderChosen);
    }

    await _scan();
    if (_albums.isEmpty) {
      throw MusicLibraryUnavailable(
        MusicLibraryProblem.folderEmpty,
        path: _roots.first.path,
      );
    }
  }

  @override
  Future<List<MusicAlbum>> albums() async {
    if (_albums.isEmpty) await _scan();
    return List.unmodifiable(_albums);
  }

  @override
  Future<List<MusicTrack>> tracksOf(String albumId) async =>
      List.unmodifiable(_byAlbum[albumId] ?? const []);

  @override
  Future<List<MusicTrack>> shuffle() async {
    final all = _byAlbum.values.expand((tracks) => tracks).toList();
    all.shuffle();
    return all.take(50).toList();
  }

  Future<void> _scan() async {
    _byAlbum.clear();
    _albums.clear();
    var seen = 0;
    for (final root in _roots) {
      seen += await _scanRoot(root, budget: _maxFiles - seen);
      if (seen >= _maxFiles) break;
    }
    _byAlbum.forEach(_recordAlbum);
    _albums.sort((a, b) => a.name.compareTo(b.name));
  }

  Future<int> _scanRoot(Directory root, {required int budget}) async {
    if (!await root.exists() || budget <= 0) return 0;
    var count = 0;
    // followLinks: false — a symlink loop under a music folder would otherwise
    // walk forever, and there is no legitimate reason for one to be there.
    final stream = root.list(recursive: true, followLinks: false);
    await for (final entity in stream) {
      if (count >= budget) break;
      if (entity is! File || !_isAudio(entity.path)) continue;
      _add(entity);
      count++;
    }
    return count;
  }

  static bool _isAudio(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0) return false;
    return _audioExtensions.contains(path.substring(dot).toLowerCase());
  }

  void _add(File file) {
    final segments = file.uri.pathSegments;
    final fileName = segments.last;
    final albumName = segments.length >= 2 ? segments[segments.length - 2] : '';
    final artistName =
        segments.length >= 3 ? segments[segments.length - 3] : '';
    final albumId = '$artistName/$albumName';

    _byAlbum.putIfAbsent(albumId, () => []).add(MusicTrack(
          id: file.path,
          source: MusicSource.local,
          title: _titleOf(fileName),
          artist: artistName,
          album: albumName,
          // Unknown until the decoder opens the file; MusicState renders an
          // indeterminate progress bar for a zero duration.
          duration: Duration.zero,
          streamUrl: file.uri.toString(),
        ));
  }

  void _recordAlbum(String albumId, List<MusicTrack> tracks) {
    tracks.sort((a, b) => a.title.compareTo(b.title));
    _albums.add(MusicAlbum(
      id: albumId,
      source: MusicSource.local,
      name: tracks.first.album.isEmpty ? albumId : tracks.first.album,
      artist: tracks.first.artist,
    ));
  }

  /// Nothing to release: the scan holds no handles, only paths.
  @override
  void close() {}

  /// Strips the extension and a leading track number: "03 - Cortez.flac"
  /// becomes "Cortez".
  static String _titleOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    final stem = dot < 0 ? fileName : fileName.substring(0, dot);
    return stem.replaceFirst(RegExp(r'^\s*\d{1,3}\s*[-._)]?\s*'), '');
  }
}
