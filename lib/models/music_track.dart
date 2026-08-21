/// A single playable track, normalised across music backends.
///
/// Navidrome (Subsonic) and Jellyfin describe songs differently — different
/// field names, different id shapes, different duration units. Everything above
/// the client layer speaks only [MusicTrack], so adding a third backend later
/// means writing one client, not touching the player, the queue or the UI.
class MusicTrack {
  /// Backend-local identifier. Only meaningful together with [source].
  final String id;

  /// Which backend this track came from.
  final MusicSource source;

  final String title;
  final String artist;
  final String album;

  /// Track length. Zero when the backend does not report one — the player
  /// treats zero as "unknown" and relies on the decoder instead.
  final Duration duration;

  /// Fully-resolved, directly playable URL, credentials included where the
  /// backend requires them in the query string (Subsonic does).
  final String streamUrl;

  /// Cover art URL, or null when the backend has no artwork for the track.
  final String? artworkUrl;

  const MusicTrack({
    required this.id,
    required this.source,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.streamUrl,
    this.artworkUrl,
  });

  /// Stable identity across backends, used as the audio_service media id and
  /// as the queue de-duplication key.
  String get uniqueId => '${source.name}:$id';

  @override
  bool operator ==(Object other) =>
      other is MusicTrack && other.uniqueId == uniqueId;

  @override
  int get hashCode => uniqueId.hashCode;

  @override
  String toString() => '$artist — $title';
}

enum MusicSource {
  navidrome,
  jellyfin,

  /// Files on the device itself. The fallback when no server is reachable,
  /// and the only source that keeps working with no network at all.
  local,

  /// A podcast episode, from a subscribed RSS feed. Shares the player and the
  /// queue with music because from the audio stack's point of view it is the
  /// same thing: a URL, a title and a duration.
  podcast,
}

/// An album as listed by a backend. Deliberately thin: the browse UI shows a
/// grid of covers and nothing else, so anything more would be dead weight.
class MusicAlbum {
  final String id;
  final MusicSource source;
  final String name;
  final String artist;
  final String? artworkUrl;

  const MusicAlbum({
    required this.id,
    required this.source,
    required this.name,
    required this.artist,
    this.artworkUrl,
  });
}

class MusicArtist {
  final String id;
  final MusicSource source;
  final String name;

  const MusicArtist({
    required this.id,
    required this.source,
    required this.name,
  });
}
