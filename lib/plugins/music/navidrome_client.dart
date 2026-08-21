import '../../models/music_track.dart';
import '../../utils/bounded_client.dart';
import '../../utils/subsonic_api.dart';

/// Navidrome access over the Subsonic API.
///
/// Only the handful of endpoints the car UI actually uses are implemented.
/// Browsing a 40 000-track library on a touchscreen at a traffic light is not
/// a thing anyone should do, so Voyager exposes recently-added and starred
/// albums and a flat album list, and nothing resembling a file browser.
class NavidromeClient {
  final SubsonicApi _api;
  final BoundedClient _http;

  NavidromeClient({
    required String endpoint,
    required String username,
    required String password,
    BoundedClient? httpClient,
  })  : _api = SubsonicApi(
          endpoint: endpoint,
          username: username,
          password: password,
          clientName: 'voyager',
        ),
        _http = httpClient ?? BoundedClient();

  /// Verifies credentials and server version.
  ///
  /// `ping` is the only endpoint guaranteed to exist on every Subsonic-ish
  /// server, which makes it the right probe for the "Test connection" button:
  /// a failure here is unambiguously about reachability or credentials, not
  /// about an unimplemented feature.
  Future<void> ping() async {
    final json = await _http.getJson(_api.uri('ping'), maxBytes: 64 * 1024);
    SubsonicApi.unwrap(json);
  }

  /// Albums, newest first. [size] is capped by the server at 500.
  Future<List<MusicAlbum>> recentAlbums({int size = 60}) async {
    final json = await _http.getJson(
      _api.uri('getAlbumList2', {'type': 'newest', 'size': '$size'}),
      maxBytes: 4 * 1024 * 1024,
    );
    final response = SubsonicApi.unwrap(json);
    final list = response['albumList2'];
    final albums = list is Map ? list['album'] : null;
    if (albums is! List) return const [];
    return albums.whereType<Map>().map(_album).toList();
  }

  /// Albums the user starred on the server. The natural "my music" shortlist
  /// for a car: short, curated and stable between drives.
  Future<List<MusicAlbum>> starredAlbums() async {
    final json = await _http.getJson(
      _api.uri('getStarred2'),
      maxBytes: 4 * 1024 * 1024,
    );
    final response = SubsonicApi.unwrap(json);
    final starred = response['starred2'];
    final albums = starred is Map ? starred['album'] : null;
    if (albums is! List) return const [];
    return albums.whereType<Map>().map(_album).toList();
  }

  Future<List<MusicTrack>> albumTracks(String albumId) async {
    final json = await _http.getJson(
      _api.uri('getAlbum', {'id': albumId}),
      maxBytes: 4 * 1024 * 1024,
    );
    final response = SubsonicApi.unwrap(json);
    final album = response['album'];
    final songs = album is Map ? album['song'] : null;
    if (songs is! List) return const [];
    return songs.whereType<Map>().map(_track).toList();
  }

  /// A ready-made queue of random tracks — the "just play something" button,
  /// which is the only music interaction that is genuinely safe while moving.
  Future<List<MusicTrack>> randomTracks({int size = 50}) async {
    final json = await _http.getJson(
      _api.uri('getRandomSongs', {'size': '$size'}),
      maxBytes: 4 * 1024 * 1024,
    );
    final response = SubsonicApi.unwrap(json);
    final random = response['randomSongs'];
    final songs = random is Map ? random['song'] : null;
    if (songs is! List) return const [];
    return songs.whereType<Map>().map(_track).toList();
  }

  /// Direct stream URL for [trackId], credentials embedded.
  ///
  /// Subsonic has no way to authenticate a media URL out of band, so the token
  /// necessarily travels in the query string. Because the salt is fresh per
  /// call, the URL cannot be handed to just_audio and then reused later — each
  /// playback needs a newly built URL, which is why this is called at enqueue
  /// time rather than cached on [MusicTrack].
  String streamUrl(String trackId) =>
      _api.uri('stream', {'id': trackId}).toString();

  String artworkUrl(String coverId, {int size = 512}) =>
      _api.uri('getCoverArt', {'id': coverId, 'size': '$size'}).toString();

  MusicAlbum _album(Map json) {
    final id = json['id'].toString();
    return MusicAlbum(
      id: id,
      source: MusicSource.navidrome,
      name: (json['name'] ?? json['title'] ?? '').toString(),
      artist: (json['artist'] ?? '').toString(),
      artworkUrl: json['coverArt'] == null
          ? null
          : artworkUrl(json['coverArt'].toString()),
    );
  }

  MusicTrack _track(Map json) {
    final id = json['id'].toString();
    return MusicTrack(
      id: id,
      source: MusicSource.navidrome,
      title: (json['title'] ?? '').toString(),
      artist: (json['artist'] ?? '').toString(),
      album: (json['album'] ?? '').toString(),
      // Subsonic reports whole seconds; a missing duration means "unknown",
      // which the player treats as "ask the decoder".
      duration: Duration(seconds: (json['duration'] as num?)?.toInt() ?? 0),
      streamUrl: streamUrl(id),
      artworkUrl: json['coverArt'] == null
          ? null
          : artworkUrl(json['coverArt'].toString()),
    );
  }

  void close() => _http.close();
}
