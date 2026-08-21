import 'dart:io';

import 'package:hive/hive.dart';

import '../../services/permission_service.dart';
import '../../utils/logger_automotive.dart';

/// Finding, choosing and remembering where the device's music lives.
///
/// The first version of this scanned `getExternalStorageDirectories(music)`,
/// which sounds right and is not: on Android that returns the app's *private*
/// media directory — `/Android/data/com.voyager.voyager/files/Music` — which is
/// empty for every user who has never copied anything into it. Hence "no
/// playable audio files were found". Real music lives in the shared volume, and
/// getting at it takes a permission and, usually, the user pointing at it.
class MusicFolderService {
  const MusicFolderService._();

  static const String _folderKey = 'voyager_music_folder';

  /// Where music actually sits on a stock Android device, in the order worth
  /// trying. Enough that most people never need the folder picker at all.
  static const List<String> candidateRoots = [
    '/storage/emulated/0/Music',
    '/storage/emulated/0/Download',
    '/sdcard/Music',
  ];

  /// The shared volume roots the folder browser starts from.
  static const List<String> browseRoots = [
    '/storage/emulated/0',
    '/sdcard',
  ];

  /// The folder the user chose, or null if they never did.
  static String? get chosenFolder {
    final value = Hive.box('settings').get(_folderKey) as String?;
    if (value == null || value.trim().isEmpty) return null;
    return value;
  }

  static Future<void> setChosenFolder(String? path) =>
      Hive.box('settings').put(_folderKey, path);

  /// Reading audio needs READ_MEDIA_AUDIO from Android 13 and
  /// READ_EXTERNAL_STORAGE before it. permission_handler maps
  /// [PermissionService.requestAudio] onto whichever applies.
  static Future<PermissionState> requestAccess() =>
      PermissionService.requestAudio();

  static Future<PermissionState> accessState() => PermissionService.audioState();

  /// Directories to scan: the chosen folder if there is one, otherwise every
  /// candidate root that exists.
  ///
  /// The fallback matters. A user who skipped the picker still gets their music
  /// if it is in the obvious place, and only has to go looking when it is not.
  static Future<List<Directory>> foldersToScan() async {
    final chosen = chosenFolder;
    if (chosen != null) {
      final directory = Directory(chosen);
      if (await directory.exists()) return [directory];
      // The card was pulled, or the folder was renamed. Fall through to the
      // defaults rather than reporting an empty library.
      AutomotiveLogger.warn('Music', 'chosen folder is gone: $chosen');
    }

    final found = <Directory>[];
    for (final path in candidateRoots) {
      final directory = Directory(path);
      if (await directory.exists()) found.add(directory);
    }
    return found;
  }

  /// Sub-directories of [path], for the folder browser.
  ///
  /// Returns an empty list rather than throwing when the directory cannot be
  /// listed: on a scoped-storage device some paths are simply not readable, and
  /// a browser that crashes on one of them is worse than one that shows it as
  /// empty.
  static Future<List<Directory>> subdirectories(String path) async {
    try {
      final entries = await Directory(path).list(followLinks: false).toList();
      final directories = entries.whereType<Directory>().toList();
      // Hidden directories are noise here — no one keeps their albums in
      // `.thumbnails`.
      directories.removeWhere((d) => _basename(d.path).startsWith('.'));
      directories.sort((a, b) => _basename(a.path)
          .toLowerCase()
          .compareTo(_basename(b.path).toLowerCase()));
      return directories;
    } on FileSystemException catch (error) {
      AutomotiveLogger.warn('Music', 'cannot list $path: ${error.message}');
      return const [];
    }
  }

  /// Whether [path] can actually be read. Used to reject a chosen folder while
  /// the user is still looking at the picker, rather than at the next traffic
  /// light.
  static Future<bool> isReadable(String path) async {
    try {
      await Directory(path).list(followLinks: false).first;
      return true;
    } on StateError {
      // Empty directory. Readable, just empty.
      return true;
    } on FileSystemException {
      return false;
    }
  }

  static String _basename(String path) {
    final index = path.lastIndexOf('/');
    return index < 0 ? path : path.substring(index + 1);
  }

  static String displayName(String path) => _basename(path);
}
