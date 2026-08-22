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

  /// Superseded by [_foldersKey] — read once, at startup, to migrate anyone
  /// who chose a folder before Voyager supported more than one. Never written
  /// to again.
  static const String _legacyFolderKey = 'voyager_music_folder';
  static const String _foldersKey = 'voyager_music_folders';

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

  /// Every folder the user has chosen, oldest first. Empty if they never
  /// picked one — the scan then falls back to [candidateRoots].
  ///
  /// Reads the pre-multi-folder key on first access after an update and
  /// carries its value over, so nobody's existing choice silently vanishes.
  static List<String> get chosenFolders {
    final box = Hive.box('settings');
    final stored = box.get(_foldersKey) as List?;
    if (stored != null) return stored.cast<String>();

    final legacy = box.get(_legacyFolderKey) as String?;
    if (legacy != null && legacy.trim().isNotEmpty) {
      box.put(_foldersKey, [legacy]);
      return [legacy];
    }
    return const [];
  }

  /// The first chosen folder, or null — kept only for the handful of callers
  /// (a settings summary line) that want one line of text rather than a list.
  static String? get chosenFolder =>
      chosenFolders.isEmpty ? null : chosenFolders.first;

  static Future<void> addFolder(String path) async {
    final current = chosenFolders;
    if (current.contains(path)) return;
    await Hive.box('settings').put(_foldersKey, [...current, path]);
  }

  static Future<void> removeFolder(String path) async {
    final current = chosenFolders.where((f) => f != path).toList();
    await Hive.box('settings').put(_foldersKey, current);
  }

  /// Reading audio needs READ_MEDIA_AUDIO from Android 13 and
  /// READ_EXTERNAL_STORAGE before it. permission_handler maps
  /// [PermissionService.requestAudio] onto whichever applies.
  static Future<PermissionState> requestAccess() =>
      PermissionService.requestAudio();

  static Future<PermissionState> accessState() =>
      PermissionService.audioState();

  /// Directories to scan: every chosen folder that still exists, or every
  /// candidate root that exists if none was ever chosen.
  ///
  /// The fallback matters. A user who skipped the picker still gets their music
  /// if it is in the obvious place, and only has to go looking when it is not.
  static Future<List<Directory>> foldersToScan() async {
    final chosen = chosenFolders;
    if (chosen.isNotEmpty) {
      final found = <Directory>[];
      for (final path in chosen) {
        final directory = Directory(path);
        if (await directory.exists()) {
          found.add(directory);
        } else {
          // The card was pulled, or the folder was renamed. Skip it rather
          // than failing the whole scan — the other chosen folders, if any,
          // still deserve to be read.
          AutomotiveLogger.warn('Music', 'chosen folder is gone: $path');
        }
      }
      if (found.isNotEmpty) return found;
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
