import '../../models/music_track.dart';
import 'jellyfin_client.dart';
import 'navidrome_client.dart';

/// One way to read a music library, whichever backend is behind it.
///
/// The plugin holds a [MusicLibrary] and never a client, which is what keeps
/// "which server am I on" out of the player, the queue and every widget.
abstract class MusicLibrary {
  MusicSource get source;

  /// Fails loudly if the backend is unreachable or the credentials are wrong.
  /// Called before anything else so the plugin can report a clear error rather
  /// than an empty library.
  Future<void> verify();

  /// Albums to show on the browse screen: starred first, then recent, because
  /// a curated shortlist is what someone can pick from at a traffic light.
  Future<List<MusicAlbum>> albums();

  Future<List<MusicTrack>> tracksOf(String albumId);

  /// A shuffled queue for the "just play something" action.
  Future<List<MusicTrack>> shuffle();

  /// Every artist in the library, for browsing.
  ///
  /// Derived from [albums] by default, which is correct for any backend and
  /// cheap for the ones that already hold the whole library in memory. A
  /// backend with a real artist endpoint should override it — the derived list
  /// only knows the artists that appear as album artists, so a guest on one
  /// track is invisible to it.
  Future<List<MusicArtist>> artists() async {
    final byName = <String, MusicArtist>{};
    for (final album in await albums()) {
      if (album.artist.isEmpty) continue;
      byName.putIfAbsent(
        album.artist.toLowerCase(),
        () => MusicArtist(id: album.artist, source: source, name: album.artist),
      );
    }
    final list = byName.values.toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  /// That artist's albums. Matched by name in the default implementation,
  /// which is what the derived [artists] list uses as its id.
  Future<List<MusicAlbum>> albumsOfArtist(String artistId) async {
    final wanted = artistId.toLowerCase();
    return (await albums())
        .where((a) => a.artist.toLowerCase() == wanted)
        .toList();
  }

  /// Every track, for browsing by song.
  ///
  /// Backends stream this from the album list by default. It is the one browse
  /// mode that can be genuinely large — tens of thousands of rows on a
  /// well-stocked server — so the UI paginates rather than asking for
  /// everything at once where the backend supports it.
  Future<List<MusicTrack>> allTracks() async {
    final tracks = <MusicTrack>[];
    for (final album in await albums()) {
      tracks.addAll(await tracksOf(album.id));
    }
    return tracks;
  }

  void close() {}
}

class NavidromeLibrary extends MusicLibrary {
  final NavidromeClient client;
  NavidromeLibrary(this.client);

  @override
  MusicSource get source => MusicSource.navidrome;

  @override
  Future<void> verify() => client.ping();

  @override
  Future<List<MusicAlbum>> albums() async {
    final starred = await client.starredAlbums();
    final recent = await client.recentAlbums();
    return _merge(starred, recent);
  }

  @override
  Future<List<MusicTrack>> tracksOf(String albumId) =>
      client.albumTracks(albumId);

  @override
  Future<List<MusicTrack>> shuffle() => client.randomTracks();

  @override
  void close() => client.close();
}

class JellyfinLibrary extends MusicLibrary {
  final JellyfinClient client;
  JellyfinLibrary(this.client);

  @override
  MusicSource get source => MusicSource.jellyfin;

  @override
  Future<void> verify() => client.ping();

  @override
  Future<List<MusicAlbum>> albums() async {
    final favourites = await client.favouriteAlbums();
    final recent = await client.recentAlbums();
    return _merge(favourites, recent);
  }

  @override
  Future<List<MusicTrack>> tracksOf(String albumId) =>
      client.albumTracks(albumId);

  @override
  Future<List<MusicTrack>> shuffle() => client.randomTracks();

  @override
  void close() => client.close();
}

/// Preferred list first, then the rest, without duplicates and in order.
List<MusicAlbum> _merge(List<MusicAlbum> preferred, List<MusicAlbum> rest) {
  final seen = preferred.map((a) => a.id).toSet();
  return [...preferred, ...rest.where((a) => seen.add(a.id))];
}
