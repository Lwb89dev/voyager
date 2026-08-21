import '../../models/music_track.dart';

/// A subscribed feed, as Voyager stores it.
///
/// Deliberately thin. Everything else — episode list, descriptions, artwork —
/// is re-read from the feed on refresh rather than cached in the settings box,
/// because a podcast's back catalogue is not something to keep a stale copy of
/// in a key-value store meant for preferences.
class PodcastSubscription {
  final String feedUrl;
  final String title;
  final String? imageUrl;

  const PodcastSubscription({
    required this.feedUrl,
    required this.title,
    this.imageUrl,
  });

  Map<String, Object?> toMap() =>
      {'feedUrl': feedUrl, 'title': title, 'imageUrl': imageUrl};

  static PodcastSubscription fromMap(Map map) => PodcastSubscription(
        feedUrl: (map['feedUrl'] ?? '').toString(),
        title: (map['title'] ?? '').toString(),
        imageUrl: map['imageUrl'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      other is PodcastSubscription && other.feedUrl == feedUrl;

  @override
  int get hashCode => feedUrl.hashCode;
}

/// One episode, already reduced to what the player and the list need.
class PodcastEpisode {
  final String guid;
  final String title;
  final String podcastTitle;
  final String audioUrl;
  final Duration duration;
  final DateTime? published;
  final String? imageUrl;

  const PodcastEpisode({
    required this.guid,
    required this.title,
    required this.podcastTitle,
    required this.audioUrl,
    required this.duration,
    this.published,
    this.imageUrl,
  });

  /// Episodes play through the same audio handler as music: same queue, same
  /// notification, same steering-wheel buttons. Converting here rather than
  /// teaching the player about a second type is what keeps that true.
  MusicTrack toTrack() => MusicTrack(
        id: guid,
        source: MusicSource.podcast,
        title: title,
        artist: podcastTitle,
        album: podcastTitle,
        duration: duration,
        streamUrl: audioUrl,
        artworkUrl: imageUrl,
      );
}
