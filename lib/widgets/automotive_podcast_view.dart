import 'package:flutter/material.dart';

import '../config/automotive_config.dart';
import '../l10n/voyager_strings.dart';
import '../plugins/podcast/podcast_models.dart';
import '../plugins/podcast/podcast_plugin.dart';
import '../screens/podcast_add_screen.dart';
import '../screens/podcast_episodes_screen.dart';
import '../theme/voyager_theme.dart';

/// The podcast pane: the shows you subscribe to, and a way to add one.
///
/// No episode list here, deliberately. The pane is what a driver may glance
/// at; choosing an episode is reading, and reading belongs on the screen you
/// open on purpose.
class AutomotivePodcastView extends StatelessWidget {
  final PodcastPlugin plugin;

  const AutomotivePodcastView({super.key, required this.plugin});

  @override
  Widget build(BuildContext context) {
    final s = VoyagerStrings.of(context);
    return ListenableBuilder(
      listenable: plugin,
      builder: (context, _) {
        final shows = plugin.subscriptions;
        return ColoredBox(
          color: VoyagerColors.background,
          // Bottom is left to FullscreenPluginView's own bottomInset padding
          // — a second one here would double it. Top has nothing else
          // providing it: the subscription list and the now-playing bar both
          // start flush with the top of this pane, which is the status bar's
          // own row in edge-to-edge mode.
          child: SafeArea(
            top: true,
            bottom: false,
            child: Column(
              children: [
                if (plugin.nowPlaying != null) _NowPlayingBar(plugin: plugin),
                Expanded(
                  child: shows.isEmpty
                      ? _Empty(plugin: plugin, s: s)
                      : _ShowGrid(plugin: plugin, shows: shows, s: s),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The one place a playing episode is shown at all.
///
/// Deliberately confined to this tab rather than floating over every screen —
/// see `AutomotiveChrome`'s doc for why a persistent playback bar covering the
/// map, the settings list and the navigation panel cost more than it gave
/// back. Music makes the identical choice with `AutomotiveMusicPlayer`; the
/// two never show each other's track, because [PodcastPlugin.nowPlaying] and
/// `MusicPlugin`'s own now-playing are filtered to opposite halves of the one
/// shared queue.
class _NowPlayingBar extends StatelessWidget {
  final PodcastPlugin plugin;
  const _NowPlayingBar({required this.plugin});

  @override
  Widget build(BuildContext context) {
    final episode = plugin.nowPlaying!;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: const BoxDecoration(
        color: VoyagerColors.surface,
        border: Border(bottom: BorderSide(color: VoyagerColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.podcasts_rounded,
                color: VoyagerColors.accentLight,
                size: 26,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      episode.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: VoyagerColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      episode.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: VoyagerColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              _NowPlayingControl(
                icon: Icons.skip_previous_rounded,
                label: 'Previous',
                onPressed: plugin.previous,
              ),
              _NowPlayingControl(
                icon: plugin.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                label: plugin.isPlaying ? 'Pause' : 'Play',
                selected: true,
                onPressed: plugin.togglePlayPause,
              ),
              _NowPlayingControl(
                icon: Icons.skip_next_rounded,
                label: 'Next',
                onPressed: plugin.next,
              ),
              _NowPlayingControl(
                icon: Icons.close_rounded,
                label: 'Stop',
                onPressed: plugin.stopAndClose,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: plugin.progress,
              minHeight: 6,
              backgroundColor: VoyagerColors.surfaceRaised,
              color: VoyagerColors.accentMid,
            ),
          ),
        ],
      ),
    );
  }
}

class _NowPlayingControl extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  const _NowPlayingControl({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Semantics(
          button: true,
          label: label,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? VoyagerColors.accent.withValues(alpha: 0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 22,
                color: selected
                    ? VoyagerColors.accentLight
                    : VoyagerColors.textPrimary,
              ),
            ),
          ),
        ),
      );
}

class _Empty extends StatelessWidget {
  final PodcastPlugin plugin;
  final VoyagerStrings s;

  const _Empty({required this.plugin, required this.s});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AutomotiveConfig.sectionGap),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.podcasts_rounded,
                size: 56,
                color: VoyagerColors.textSecondary,
              ),
              const SizedBox(height: AutomotiveConfig.gutter),
              Text(
                s.noSubscriptions,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: VoyagerColors.textSecondary,
                  fontSize: AutomotiveConfig.secondaryTextSize,
                ),
              ),
              const SizedBox(height: AutomotiveConfig.sectionGap),
              FilledButton.icon(
                onPressed: () => PodcastAddScreen.show(context, plugin),
                icon: const Icon(Icons.add_rounded, size: 28),
                label: Text(
                  s.addPodcast,
                  style: const TextStyle(
                    fontSize: AutomotiveConfig.secondaryTextSize,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _ShowGrid extends StatelessWidget {
  final PodcastPlugin plugin;
  final List<PodcastSubscription> shows;
  final VoyagerStrings s;

  const _ShowGrid({
    required this.plugin,
    required this.shows,
    required this.s,
  });

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: shows.length,
              itemBuilder: (_, i) => _ShowRow(plugin: plugin, show: shows[i]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: OutlinedButton.icon(
              onPressed: () => PodcastAddScreen.show(context, plugin),
              icon: const Icon(Icons.add_rounded),
              label: Text(s.addPodcast),
              style: OutlinedButton.styleFrom(
                foregroundColor: VoyagerColors.textPrimary,
                side: const BorderSide(color: VoyagerColors.border),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
              ),
            ),
          ),
        ],
      );
}

class _ShowRow extends StatelessWidget {
  final PodcastPlugin plugin;
  final PodcastSubscription show;

  const _ShowRow({required this.plugin, required this.show});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => PodcastEpisodesScreen.open(context, plugin, show),
        child: Container(
          constraints: const BoxConstraints(minHeight: 76),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(
                Icons.podcasts_rounded,
                color: VoyagerColors.accentLight,
                size: 26,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  show.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: VoyagerColors.textPrimary,
                    fontSize: AutomotiveConfig.secondaryTextSize,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: VoyagerColors.textSecondary,
              ),
            ],
          ),
        ),
      );
}
