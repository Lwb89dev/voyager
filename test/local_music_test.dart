import 'package:flutter_test/flutter_test.dart';
import 'package:voyager/plugins/music/local_music_library.dart';
import 'package:voyager/plugins/music/music_folder_service.dart';

void main() {
  group('MusicLibraryUnavailable', () {
    test('tells a missing permission apart from an empty folder', () {
      // These two failures look identical from the outside and need completely
      // different actions from the user, which is why they are separate cases
      // rather than one "no music found".
      const missing =
          MusicLibraryUnavailable(MusicLibraryProblem.permissionMissing);
      const empty = MusicLibraryUnavailable(
        MusicLibraryProblem.folderEmpty,
        path: '/storage/emulated/0/Music',
      );

      expect(missing.toString(), contains('cannot read'));
      expect(empty.toString(), contains('/storage/emulated/0/Music'));
      expect(missing.toString(), isNot(empty.toString()));
    });

    test('names the folder it looked in', () {
      const problem = MusicLibraryUnavailable(
        MusicLibraryProblem.folderEmpty,
        path: '/sdcard/Albums',
      );
      expect(problem.toString(), contains('/sdcard/Albums'));
    });

    test('copes with an empty-folder error that has no path', () {
      const problem = MusicLibraryUnavailable(MusicLibraryProblem.folderEmpty);
      expect(problem.toString(), isNotEmpty);
    });
  });

  group('MusicFolderService', () {
    test('does not look in the app-private media directory', () {
      // The original bug: getExternalStorageDirectories(music) returns
      // /Android/data/<package>/files/Music, which is empty for everyone who
      // has never copied files into it by hand.
      for (final root in MusicFolderService.candidateRoots) {
        expect(root, isNot(contains('Android/data')));
      }
    });

    test('looks in the places music actually lives', () {
      expect(
        MusicFolderService.candidateRoots,
        contains('/storage/emulated/0/Music'),
      );
    });

    test('shows the folder name rather than the whole path', () {
      expect(
        MusicFolderService.displayName('/storage/emulated/0/Music/Neil Young'),
        'Neil Young',
      );
    });

    test('copes with a path that has no separator', () {
      expect(MusicFolderService.displayName('Music'), 'Music');
    });
  });
}
