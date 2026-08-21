import 'package:flutter_test/flutter_test.dart';
import 'package:voyager/models/music_track.dart';
import 'package:voyager/plugins/music/media_store_library.dart';

/// One MediaStore row, as the native side hands it over.
Map<String, Object?> row({
  String id = '1',
  String title = 'Cortez the Killer',
  String artist = 'Neil Young',
  String album = 'Zuma',
  String albumId = '10',
  int durationMs = 447000,
  int track = 5,
}) =>
    {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'albumId': albumId,
      'durationMs': durationMs,
      'track': track,
      'uri': 'content://media/external/audio/media/$id',
      'artUri': 'content://media/external/audio/albumart/$albumId',
    };

MediaStoreLibrary libraryOf(List<Map<String, Object?>> rows, {String? folder}) =>
    MediaStoreLibrary(
      folderFilter: folder,
      query: (_) async => rows,
    );

void main() {
  test('reads a row into a playable track', () async {
    final library = libraryOf([row()]);
    final tracks = await library.tracksOf('10');

    expect(tracks, isEmpty, reason: 'nothing is indexed before albums() runs');

    await library.albums();
    final loaded = await library.tracksOf('10');
    expect(loaded.single.title, 'Cortez the Killer');
    expect(loaded.single.duration, const Duration(seconds: 447));
    expect(loaded.single.source, MusicSource.local);
  });

  test('addresses tracks by content URI, not by file path', () async {
    // The whole point of indexing through MediaStore: playback goes through the
    // content resolver, so Voyager never needs filesystem access to the music.
    final library = libraryOf([row()]);
    await library.albums();
    final track = (await library.tracksOf('10')).single;
    expect(track.streamUrl, startsWith('content://'));
  });

  test('groups by album id, not by album name', () async {
    // Two records genuinely called "Greatest Hits" are two albums.
    final library = libraryOf([
      row(id: '1', album: 'Greatest Hits', albumId: '10', artist: 'A'),
      row(id: '2', album: 'Greatest Hits', albumId: '20', artist: 'B'),
    ]);

    final albums = await library.albums();
    expect(albums, hasLength(2));
    expect(albums.map((a) => a.artist), containsAll(['A', 'B']));
  });

  test('keeps the native track ordering within an album', () async {
    // The SQL query orders by track number; re-sorting here by title would
    // shuffle every album back into alphabetical order.
    final library = libraryOf([
      row(id: '1', title: 'Zuma Beach', track: 1),
      row(id: '2', title: 'Anger Moves', track: 2),
    ]);
    await library.albums();
    final tracks = await library.tracksOf('10');
    expect(tracks.map((t) => t.title), ['Zuma Beach', 'Anger Moves']);
  });

  test('labels an album with no name rather than showing a blank row', () async {
    final library = libraryOf([row(album: '', albumId: '99')]);
    final albums = await library.albums();
    expect(albums.single.name, isNotEmpty);
  });

  test('survives a row with missing fields', () async {
    final library = libraryOf([
      {'id': '7', 'albumId': '3', 'uri': 'content://x/7'},
    ]);
    final albums = await library.albums();
    expect(albums, hasLength(1));
    final track = (await library.tracksOf('3')).single;
    expect(track.duration, Duration.zero);
    expect(track.title, '');
  });

  test('shuffle draws from every album', () async {
    final library = libraryOf([
      for (var i = 0; i < 20; i++)
        row(id: '$i', albumId: '${i % 4}', title: 'Track $i'),
    ]);
    await library.albums();
    final shuffled = await library.shuffle();
    expect(shuffled, hasLength(20));
    expect(shuffled.map((t) => t.uniqueId).toSet(), hasLength(20));
  });

  test('sorts albums case-insensitively', () async {
    final library = libraryOf([
      row(id: '1', album: 'zuma', albumId: '1'),
      row(id: '2', album: 'Aurora', albumId: '2'),
    ]);
    final albums = await library.albums();
    expect(albums.map((a) => a.name), ['Aurora', 'zuma']);
  });
}
