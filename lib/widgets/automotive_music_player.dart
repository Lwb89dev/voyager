import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../config/automotive_config.dart';
import '../models/music_track.dart';
import '../plugins/music/music_plugin.dart';
import '../plugins/music/music_state.dart';
import '../screens/music_browser_screen.dart';
import '../theme/voyager_theme.dart';
import 'automotive_button.dart';

/// The music pane: cover art, what is playing, and the transport controls.
///
/// The album grid is behind a button rather than on this screen. Browsing is a
/// parked activity; what belongs on the pane a driver can see while moving is
/// the current track and the transport controls, both large enough to use
/// without aiming.
///
/// Two layouts, chosen by the height actually available rather than by
/// orientation. Portrait's full-bleed pane has well over a thousand logical
/// pixels to work with even after the floating chrome takes its share, and the
/// vertical layout — big artwork, big type, a row of controls — uses that
/// space well. Landscape's pane is under 300 dp tall once the chrome is
/// subtracted, which is not enough room for 140 dp artwork stacked above two
/// more rows each wanting an 80 dp-tall button: that combination is exactly
/// what overflowed before this file kept height in mind at all. The compact
/// form below trades big cover art for a thumbnail and puts everything else in
/// one row, which is the shape that actually fits.
class AutomotiveMusicPlayer extends StatelessWidget {
  final MusicPlugin plugin;

  const AutomotiveMusicPlayer({super.key, required this.plugin});

  /// Below this, the vertical layout's own minimums (140 dp artwork + two
  /// 80 dp-tall control rows + text) no longer fit. Measured with a margin
  /// above the tightest real case (a landscape phone's ~300 dp pane), not
  /// tuned to it exactly — a foldable or a tablet dock should get the same
  /// answer a phone does for the same amount of vertical room.
  static const double _compactHeightThreshold = 420;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: plugin,
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) => _build(
          context,
          plugin.state,
          compact: constraints.maxHeight < _compactHeightThreshold,
        ),
      ),
    );
  }

  Widget _build(BuildContext context, MusicState state, {required bool compact}) {
    if (state.current == null) return _EmptyState(plugin: plugin);

    return ColoredBox(
      color: VoyagerColors.background,
      child: compact
          ? _CompactPlayer(plugin: plugin, state: state)
          : Column(
              children: [
                Expanded(flex: 5, child: _Artwork(track: state.current!)),
                Expanded(flex: 2, child: _NowPlaying(state: state)),
                // flex 3, not 2: two 80 dp button rows plus the gap between
                // them need more height than one row did, now that the Stop
                // button lives in a second row instead of overflowing the
                // first — see _Controls.
                Expanded(
                  flex: 3,
                  child: _Controls(plugin: plugin, state: state),
                ),
              ],
            ),
    );
  }
}

class _Artwork extends StatelessWidget {
  final MusicTrack track;
  const _Artwork({required this.track});

  @override
  Widget build(BuildContext context) {
    final url = track.artworkUrl;
    // Local tracks carry a `content://` album-art URI, which the network image
    // loader cannot open — it would spend a request failing on every track
    // change and land on the same placeholder anyway. Server artwork is http
    // and loads normally.
    if (url == null || !url.startsWith('http')) {
      return const Center(
        child: Icon(Icons.album_rounded, size: 140, color: VoyagerColors.border),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(AutomotiveConfig.gutter),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.contain,
          // No fade: an animation on every track change is movement in the
          // driver's peripheral vision for no information gain.
          fadeInDuration: Duration.zero,
          errorWidget: (_, __, ___) => const Icon(
            Icons.album_rounded,
            size: 140,
            color: VoyagerColors.border,
          ),
        ),
      ),
    );
  }
}

class _NowPlaying extends StatelessWidget {
  final MusicState state;
  const _NowPlaying({required this.state});

  @override
  Widget build(BuildContext context) {
    final track = state.current!;
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: AutomotiveConfig.sectionGap),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            track.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: VoyagerColors.textPrimary,
              fontSize: AutomotiveConfig.primaryTextSize,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            track.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: VoyagerColors.textSecondary,
              fontSize: AutomotiveConfig.secondaryTextSize,
            ),
          ),
          const SizedBox(height: 14),
          _ProgressBar(state: state),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final MusicState state;
  const _ProgressBar({required this.state});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: state.progress,
          minHeight: 8,
          backgroundColor: VoyagerColors.surfaceRaised,
          color: VoyagerColors.accentMid,
        ),
      );
}

class _Controls extends StatelessWidget {
  final MusicPlugin plugin;
  final MusicState state;
  const _Controls({required this.plugin, required this.state});

  @override
  Widget build(BuildContext context) {
    // Two rows, not six buttons in one: at 80 dp minimum touch target each,
    // six in a row need 480 dp and a phone-width portrait pane has about 410
    // — the row overflowed rather than shrinking anything below the target
    // size. Splitting keeps every button full-size: transport (the controls
    // reached for while driving) on top, the occasional actions below.
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AutomotiveButton(
              icon: Icons.skip_previous_rounded,
              label: 'Previous',
              iconOnly: true,
              onPressed: plugin.previous,
            ),
            const SizedBox(width: 16),
            AutomotiveButton(
              icon: state.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              label: state.isPlaying ? 'Pause' : 'Play',
              iconOnly: true,
              selected: true,
              onPressed: plugin.togglePlayPause,
            ),
            const SizedBox(width: 16),
            AutomotiveButton(
              icon: Icons.skip_next_rounded,
              label: 'Next',
              iconOnly: true,
              onPressed: plugin.next,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AutomotiveButton(
              icon: Icons.shuffle_rounded,
              label: 'Shuffle',
              iconOnly: true,
              onPressed: plugin.shuffleAll,
            ),
            const SizedBox(width: 16),
            AutomotiveButton(
              icon: Icons.library_music_rounded,
              label: 'Library',
              iconOnly: true,
              onPressed: () => MusicBrowserScreen.show(context, plugin),
            ),
            const SizedBox(width: 16),
            AutomotiveButton(
              icon: Icons.close_rounded,
              label: 'Stop',
              iconOnly: true,
              onPressed: plugin.stopAndClose,
            ),
          ],
        ),
      ],
    );
  }
}

/// The landscape form: a thumbnail, title/artist/progress, and controls, all
/// in one row sized to whatever height the pane actually has.
///
/// Every control here is a bounded exception to [AutomotiveButton]'s 80 dp
/// floor, on the same reasoning as the floating chrome — a control this row
/// cannot be as tall as the pane itself, and every action it carries is also
/// reachable from the steering wheel or the full player in portrait.
class _CompactPlayer extends StatelessWidget {
  final MusicPlugin plugin;
  final MusicState state;

  const _CompactPlayer({required this.plugin, required this.state});

  @override
  Widget build(BuildContext context) {
    final track = state.current!;
    return Padding(
      padding: const EdgeInsets.all(AutomotiveConfig.gutter),
      child: Row(
        children: [
          _CompactArtwork(track: track),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: VoyagerColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  track.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: VoyagerColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                _ProgressBar(state: state),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _CompactControl(
            icon: Icons.skip_previous_rounded,
            label: 'Previous',
            onPressed: plugin.previous,
          ),
          _CompactControl(
            icon: state.isPlaying
                ? Icons.pause_rounded
                : Icons.play_arrow_rounded,
            label: state.isPlaying ? 'Pause' : 'Play',
            selected: true,
            onPressed: plugin.togglePlayPause,
          ),
          _CompactControl(
            icon: Icons.skip_next_rounded,
            label: 'Next',
            onPressed: plugin.next,
          ),
          _CompactControl(
            icon: Icons.library_music_rounded,
            label: 'Library',
            onPressed: () => MusicBrowserScreen.show(context, plugin),
          ),
          _CompactControl(
            icon: Icons.close_rounded,
            label: 'Stop',
            onPressed: plugin.stopAndClose,
          ),
        ],
      ),
    );
  }
}

class _CompactArtwork extends StatelessWidget {
  final MusicTrack track;
  const _CompactArtwork({required this.track});

  @override
  Widget build(BuildContext context) {
    final url = track.artworkUrl;
    const size = 96.0;
    if (url == null || !url.startsWith('http')) {
      return const SizedBox(
        width: size,
        height: size,
        child: Icon(Icons.album_rounded, size: 48, color: VoyagerColors.border),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        fadeInDuration: Duration.zero,
        errorWidget: (_, __, ___) => const SizedBox(
          width: size,
          height: size,
          child: Icon(Icons.album_rounded, size: 48, color: VoyagerColors.border),
        ),
      ),
    );
  }
}

class _CompactControl extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  const _CompactControl({
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
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? VoyagerColors.accent.withValues(alpha: 0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                size: 24,
                color: selected
                    ? VoyagerColors.accentLight
                    : VoyagerColors.textPrimary,
              ),
            ),
          ),
        ),
      );
}

/// Shown when the library loaded but nothing is playing yet.
///
/// One enormous button, because "play something" is the only music action that
/// is genuinely safe to perform while moving, and it should be reachable
/// without reading anything.
class _EmptyState extends StatelessWidget {
  final MusicPlugin plugin;
  const _EmptyState({required this.plugin});

  @override
  Widget build(BuildContext context) {
    final albums = plugin.state.albums;
    return ColoredBox(
      color: VoyagerColors.background,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AutomotiveConfig.sectionGap),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                albums.isEmpty
                    ? 'No music found'
                    : '${albums.length} albums available',
                style: const TextStyle(
                  color: VoyagerColors.textSecondary,
                  fontSize: AutomotiveConfig.secondaryTextSize,
                ),
              ),
              const SizedBox(height: AutomotiveConfig.sectionGap),
              FilledButton.icon(
                onPressed: albums.isEmpty ? null : plugin.shuffleAll,
                icon: const Icon(Icons.shuffle_rounded, size: 32),
                label: const Text(
                  'Play something',
                  style: TextStyle(
                    fontSize: AutomotiveConfig.primaryTextSize,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 26,
                  ),
                ),
              ),
              const SizedBox(height: AutomotiveConfig.gutter),
              // The way in for anyone who wants a particular record rather
              // than whatever comes up.
              OutlinedButton.icon(
                onPressed: albums.isEmpty
                    ? null
                    : () => MusicBrowserScreen.show(context, plugin),
                icon: const Icon(Icons.library_music_rounded, size: 26),
                label: const Text(
                  'Browse the library',
                  style: TextStyle(fontSize: AutomotiveConfig.secondaryTextSize),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: VoyagerColors.textPrimary,
                  side: const BorderSide(color: VoyagerColors.border),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
