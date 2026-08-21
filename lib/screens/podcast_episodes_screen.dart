import 'package:flutter/material.dart';

import '../l10n/voyager_strings.dart';
import '../plugins/podcast/podcast_models.dart';
import '../plugins/podcast/podcast_plugin.dart';
import '../theme/voyager_theme.dart';
import '../widgets/voyager_scope.dart';

/// One show's episodes, newest first.
class PodcastEpisodesScreen extends StatelessWidget {
  final PodcastPlugin plugin;
  final PodcastSubscription podcast;

  const PodcastEpisodesScreen({
    super.key,
    required this.plugin,
    required this.podcast,
  });

  static Future<void> open(
    BuildContext context,
    PodcastPlugin plugin,
    PodcastSubscription subscription,
  ) =>
      Navigator.of(context).push<void>(MaterialPageRoute(
        builder: (_) =>
            PodcastEpisodesScreen(plugin: plugin, podcast: subscription),
      ));

  @override
  Widget build(BuildContext context) {
    final s = VoyagerStrings.of(context);
    return VoyagerScope(
      child: Scaffold(
        backgroundColor: VoyagerColors.background,
        appBar: AppBar(
          title: Text(podcast.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(
              tooltip: s.unsubscribe,
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () async {
                await plugin.unsubscribe(podcast.feedUrl);
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
          ],
        ),
        body: FutureBuilder<List<PodcastEpisode>>(
          future: plugin.episodes(podcast),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(color: VoyagerColors.accent),
              );
            }
            if (snapshot.hasError) {
              return _Message(text: s.feedFailed('${snapshot.error}'));
            }
            final episodes = snapshot.data ?? const [];
            if (episodes.isEmpty) return _Message(text: s.noEpisodes);

            return ListView.builder(
              itemCount: episodes.length,
              itemBuilder: (_, i) => _EpisodeRow(
                episode: episodes[i],
                onPlay: () async {
                  await plugin.play(episodes[i], episodes);
                  if (context.mounted) {
                    Navigator.of(context).popUntil((r) => r.isFirst);
                  }
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EpisodeRow extends StatelessWidget {
  final PodcastEpisode episode;
  final VoidCallback onPlay;

  const _EpisodeRow({required this.episode, required this.onPlay});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onPlay,
        child: Container(
          constraints: const BoxConstraints(minHeight: 76),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Icon(
                Icons.play_circle_outline_rounded,
                color: VoyagerColors.accentLight,
                size: 30,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      episode.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: VoyagerColors.textPrimary,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _subtitle(episode),
                      style: const TextStyle(
                        color: VoyagerColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  /// Date and length, the two things that decide whether an episode fits the
  /// drive ahead. A feed that reports neither gets neither, rather than a row
  /// of dashes.
  static String _subtitle(PodcastEpisode episode) {
    final parts = <String>[];
    final published = episode.published;
    if (published != null) {
      parts.add('${published.day}/${published.month}/${published.year}');
    }
    if (episode.duration > Duration.zero) {
      final minutes = episode.duration.inMinutes;
      parts.add(minutes >= 60
          ? '${minutes ~/ 60} h ${minutes % 60} min'
          : '$minutes min');
    }
    return parts.join(' · ');
  }
}

class _Message extends StatelessWidget {
  final String text;
  const _Message({required this.text});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: VoyagerColors.textSecondary,
              fontSize: 15,
            ),
          ),
        ),
      );
}
