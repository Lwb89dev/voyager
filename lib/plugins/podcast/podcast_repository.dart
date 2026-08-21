import 'dart:io';

import 'package:hive/hive.dart';
import 'package:podcast_search/podcast_search.dart' as ps;

import '../../utils/bounded_client.dart';
import '../../utils/logger_automotive.dart';
import 'podcast_models.dart';

/// Subscriptions, feed loading and directory search.
///
/// Built on `podcast_search`, a Dart library (MIT) that handles the iTunes and
/// PodcastIndex directories and the RSS parsing, including the Podcasting 2.0
/// tags. The obvious alternative — AntennaPod — is a standalone Android
/// application with no library artifact, so there is nothing to link against
/// however good it is; the same is true of Podstr, which is a React web app for
/// *publishing* and whose output is an ordinary RSS feed this can subscribe to
/// like any other. See docs/OPEN_SOURCE_STACK.md.
///
/// Search goes to the iTunes directory, which needs no key and no account.
/// PodcastIndex would need credentials, so it is not wired up: a feature that
/// makes the user register somewhere is not one Voyager turns on by default.
class PodcastRepository {
  static const String _subscriptionsKey = 'voyager_podcast_subscriptions';

  final ps.Search _search;
  final BoundedClient _http;

  PodcastRepository({ps.Search? search, BoundedClient? httpClient})
      : _search = search ?? ps.Search(),
        _http = httpClient ?? BoundedClient();

  List<PodcastSubscription> subscriptions() {
    final raw = Hive.box('settings').get(_subscriptionsKey) as List?;
    if (raw == null) return const [];
    return raw
        .whereType<Map>()
        .map(PodcastSubscription.fromMap)
        .where((s) => s.feedUrl.isNotEmpty)
        .toList();
  }

  Future<void> subscribe(PodcastSubscription podcast) async {
    final current = subscriptions();
    if (current.contains(podcast)) return;
    await _store([...current, podcast]);
  }

  Future<void> unsubscribe(String feedUrl) async {
    await _store(subscriptions().where((s) => s.feedUrl != feedUrl).toList());
  }

  Future<void> _store(List<PodcastSubscription> list) => Hive.box('settings')
      .put(_subscriptionsKey, [for (final s in list) s.toMap()]);

  /// Loads a feed and returns its playable episodes, newest first.
  ///
  /// Capped at [maxEpisodes]: a long-running show has thousands, and a list
  /// that long is neither scrollable in a car nor worth the parse time.
  Future<List<PodcastEpisode>> episodes(
    PodcastSubscription subscription, {
    int maxEpisodes = 50,
  }) async {
    final feed = await _loadFeed(subscription.feedUrl);
    final title = feed.title?.isNotEmpty == true ? feed.title! : subscription.title;
    final episodes = <PodcastEpisode>[];

    for (final item in feed.episodes) {
      // An episode with no enclosure is a text post in the feed. It is not
      // something that can be played, so it is not something to list.
      final url = item.contentUrl;
      if (url == null || url.isEmpty) continue;
      episodes.add(PodcastEpisode(
        guid: item.guid.isEmpty ? url : item.guid,
        title: item.title,
        podcastTitle: title,
        audioUrl: url,
        duration: item.duration ?? Duration.zero,
        published: item.publicationDate,
        imageUrl: item.imageUrl ?? feed.image,
      ));
      if (episodes.length >= maxEpisodes) break;
    }
    return episodes;
  }

  /// Reads a feed just far enough to name it, for the "add by URL" flow.
  Future<PodcastSubscription> describe(String feedUrl) async {
    final feed = await _loadFeed(feedUrl);
    return PodcastSubscription(
      feedUrl: feedUrl,
      title: feed.title?.isNotEmpty == true ? feed.title! : feedUrl,
      imageUrl: feed.image,
    );
  }

  /// Fetches a feed through [BoundedClient] rather than `podcast_search`'s own
  /// `Feed.loadFeed`, which buffers the response with no size cap of its own.
  /// A feed URL is user-supplied — a malicious or simply broken one answering
  /// with an unbounded body would otherwise OOM-kill the app mid-drive, the
  /// same failure `BoundedClient`'s doc comment describes for music servers.
  /// `podcast_search` does expose a bounded entry point, `loadFeedFile`, so the
  /// bytes are fetched here and handed to the library only after the cap has
  /// already been enforced.
  Future<ps.Podcast> _loadFeed(String url) async {
    final bytes = await _http.getBytes(Uri.parse(url), maxBytes: 20 * 1024 * 1024);
    final temp = await File(
      '${Directory.systemTemp.path}/voyager_feed_${DateTime.now().microsecondsSinceEpoch}.xml',
    ).create();
    try {
      await temp.writeAsBytes(bytes);
      return await ps.Feed.loadFeedFile(file: temp.path);
    } finally {
      await temp.delete();
    }
  }

  /// Directory search, returning subscriptions ready to add.
  Future<List<PodcastSubscription>> search(String term) async {
    if (term.trim().isEmpty) return const [];
    try {
      final result = await _search.search(term.trim(), limit: 25);
      return [
        for (final item in result.items)
          if (item.feedUrl != null && item.feedUrl!.isNotEmpty)
            PodcastSubscription(
              feedUrl: item.feedUrl!,
              title: item.trackName ?? item.collectionName ?? item.feedUrl!,
              imageUrl: item.artworkUrl100 ?? item.artworkUrl60,
            ),
      ];
    } catch (error) {
      AutomotiveLogger.warn('Podcast', 'search failed: $error');
      rethrow;
    }
  }
}
