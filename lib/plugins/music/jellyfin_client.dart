import '../../models/music_track.dart';
import '../../utils/bounded_client.dart';

/// Jellyfin access over its native REST API.
///
/// Jellyfin also speaks a Subsonic compatibility layer, but only partially and
/// only when the server admin enabled the plugin, so Voyager uses the native
/// API: it is the path that is always available on a stock install.
///
/// Authentication is an API key created in the Jellyfin dashboard rather than
/// a username and password. That is deliberately the only supported method —
/// a key is revocable from the server without changing the account password,
/// which is the right property for a credential living in a device mounted on
/// a windscreen.
class JellyfinClient {
  final String endpoint;
  final String apiKey;

  /// Jellyfin scopes library queries per user, so the user's id is required
  /// alongside the key. It is shown in the dashboard next to the profile.
  final String userId;

  final BoundedClient _http;

  JellyfinClient({
    required String endpoint,
    required this.apiKey,
    required this.userId,
    BoundedClient? httpClient,
  })  : endpoint = endpoint.endsWith('/')
            ? endpoint.substring(0, endpoint.length - 1)
            : endpoint,
        _http = httpClient ?? BoundedClient();

  /// Jellyfin expects the token in a header, not the query string — which is
  /// why, unlike Subsonic, the credential never appears in a URL that might be
  /// logged by a proxy.
  Map<String, String> get _headers => {
        'X-Emby-Token': apiKey,
        'Accept': 'application/json',
      };

  Uri _uri(String path, [Map<String, String> query = const {}]) =>
      Uri.parse('$endpoint$path').replace(queryParameters: query);

  /// Verifies the key and the server's reachability.
  Future<void> ping() async {
    await _http.getJson(
      _uri('/System/Info'),
      headers: _headers,
      maxBytes: 256 * 1024,
    );
  }

  Future<List<MusicAlbum>> recentAlbums({int limit = 60}) async {
    final json = await _http.getJson(
      _uri('/Users/$userId/Items', {
        'IncludeItemTypes': 'MusicAlbum',
        'Recursive': 'true',
        'SortBy': 'DateCreated',
        'SortOrder': 'Descending',
        'Limit': '$limit',
      }),
      headers: _headers,
      maxBytes: 4 * 1024 * 1024,
    );
    return _items(json).map(_album).toList();
  }

  Future<List<MusicAlbum>> favouriteAlbums({int limit = 60}) async {
    final json = await _http.getJson(
      _uri('/Users/$userId/Items', {
        'IncludeItemTypes': 'MusicAlbum',
        'Recursive': 'true',
        'Filters': 'IsFavorite',
        'Limit': '$limit',
      }),
      headers: _headers,
      maxBytes: 4 * 1024 * 1024,
    );
    return _items(json).map(_album).toList();
  }

  Future<List<MusicTrack>> albumTracks(String albumId) async {
    final json = await _http.getJson(
      _uri('/Users/$userId/Items', {
        'ParentId': albumId,
        'IncludeItemTypes': 'Audio',
        'SortBy': 'ParentIndexNumber,IndexNumber,SortName',
      }),
      headers: _headers,
      maxBytes: 4 * 1024 * 1024,
    );
    return _items(json).map(_track).toList();
  }

  Future<List<MusicTrack>> randomTracks({int limit = 50}) async {
    final json = await _http.getJson(
      _uri('/Users/$userId/Items', {
        'IncludeItemTypes': 'Audio',
        'Recursive': 'true',
        'SortBy': 'Random',
        'Limit': '$limit',
      }),
      headers: _headers,
      maxBytes: 4 * 1024 * 1024,
    );
    return _items(json).map(_track).toList();
  }

  /// A direct-play URL.
  ///
  /// `static=true` tells Jellyfin to serve the original file instead of
  /// transcoding. In a car that is what we want: transcoding adds latency at
  /// track change and puts load on a server that is often a low-power box, and
  /// the formats a phone cannot decode natively are vanishingly rare.
  String streamUrl(String itemId) => _uri('/Audio/$itemId/stream', {
        'static': 'true',
        'api_key': apiKey,
      }).toString();

  String artworkUrl(String itemId, {int size = 512}) =>
      _uri('/Items/$itemId/Images/Primary', {
        'maxWidth': '$size',
        'quality': '90',
      }).toString();

  static List<Map> _items(Map<String, dynamic> json) {
    final items = json['Items'];
    if (items is! List) return const [];
    return items.whereType<Map>().toList();
  }

  MusicAlbum _album(Map json) {
    final id = json['Id'].toString();
    return MusicAlbum(
      id: id,
      source: MusicSource.jellyfin,
      name: (json['Name'] ?? '').toString(),
      artist: (json['AlbumArtist'] ?? '').toString(),
      artworkUrl: artworkUrl(id),
    );
  }

  /// Falls back to the first entry of the `Artists` array when the item has no
  /// album artist — common for compilations and for singles ripped loose.
  static String? _firstArtist(Map json) {
    final artists = json['Artists'];
    if (artists is! List || artists.isEmpty) return null;
    return artists.first?.toString();
  }

  MusicTrack _track(Map json) {
    final id = json['Id'].toString();
    // Jellyfin reports durations in "ticks" of 100 nanoseconds, so ten million
    // of them make a second. Dividing into microseconds keeps sub-second
    // precision that a plain seconds conversion would throw away.
    final ticks = (json['RunTimeTicks'] as num?)?.toInt() ?? 0;
    return MusicTrack(
      id: id,
      source: MusicSource.jellyfin,
      title: (json['Name'] ?? '').toString(),
      artist: (json['AlbumArtist'] ?? _firstArtist(json) ?? '').toString(),
      album: (json['Album'] ?? '').toString(),
      duration: Duration(microseconds: ticks ~/ 10),
      streamUrl: streamUrl(id),
      artworkUrl: json['AlbumId'] == null
          ? artworkUrl(id)
          : artworkUrl(json['AlbumId'].toString()),
    );
  }

  void close() => _http.close();
}
