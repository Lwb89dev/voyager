import 'package:flutter/material.dart';

import '../config/automotive_config.dart';
import '../l10n/voyager_strings.dart';
import '../models/music_track.dart';
import '../plugins/music/music_plugin.dart';
import '../theme/voyager_theme.dart';
import '../widgets/voyager_scope.dart';

/// Browsing the library: artists, albums, songs.
///
/// Until now the only way into the music was the shuffle button. That is the
/// right *driving* control — one tap, no reading — but it is a poor library,
/// and it quietly decided that nobody would ever want a particular record.
///
/// So this exists alongside it rather than replacing it. Rows are 72 dp, which
/// is larger than a phone list and smaller than the dashboard's 80 dp floor:
/// browsing is a parked activity, and a list built to automotive sizing would
/// show four items at a time.
class MusicBrowserScreen extends StatelessWidget {
  final MusicPlugin plugin;

  const MusicBrowserScreen({super.key, required this.plugin});

  static Future<void> show(BuildContext context, MusicPlugin plugin) =>
      Navigator.of(context).push<void>(MaterialPageRoute(
        builder: (_) => MusicBrowserScreen(plugin: plugin),
      ));

  @override
  Widget build(BuildContext context) {
    final s = VoyagerStrings.of(context);
    return VoyagerScope(
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          backgroundColor: VoyagerColors.background,
          appBar: AppBar(
            title: Text(s.browseLibrary),
            bottom: TabBar(
              labelColor: VoyagerColors.accentLight,
              unselectedLabelColor: VoyagerColors.textSecondary,
              indicatorColor: VoyagerColors.accent,
              tabs: [
                Tab(text: s.artists),
                Tab(text: s.albums),
                Tab(text: s.songs),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _ArtistList(plugin: plugin, s: s),
              _AlbumList(plugin: plugin, s: s),
              _SongList(plugin: plugin, s: s),
            ],
          ),
        ),
      ),
    );
  }
}

/// One list body, with the three states every one of these tabs can be in.
///
/// Written once because the alternative is three copies that drift: a tab that
/// silently shows nothing when a request fails is the kind of thing that gets
/// reported as "the music is gone".
class _AsyncList<T> extends StatelessWidget {
  final Future<List<T>> future;
  final Widget Function(T item) itemBuilder;
  final String emptyLabel;

  const _AsyncList({
    required this.future,
    required this.itemBuilder,
    required this.emptyLabel,
  });

  @override
  Widget build(BuildContext context) => FutureBuilder<List<T>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: VoyagerColors.accent),
            );
          }
          if (snapshot.hasError) return _Message(text: '${snapshot.error}');
          final items = snapshot.data ?? const [];
          if (items.isEmpty) return _Message(text: emptyLabel);
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (_, i) => itemBuilder(items[i]),
          );
        },
      );
}

class _ArtistList extends StatelessWidget {
  final MusicPlugin plugin;
  final VoyagerStrings s;

  const _ArtistList({required this.plugin, required this.s});

  @override
  Widget build(BuildContext context) => _AsyncList<MusicArtist>(
        future: plugin.artists(),
        emptyLabel: s.libraryEmpty,
        itemBuilder: (artist) => _Row(
          icon: Icons.person_rounded,
          title: artist.name,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => _ArtistAlbums(plugin: plugin, artist: artist, s: s),
          )),
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: VoyagerColors.textSecondary,
          ),
        ),
      );
}

class _ArtistAlbums extends StatelessWidget {
  final MusicPlugin plugin;
  final MusicArtist artist;
  final VoyagerStrings s;

  const _ArtistAlbums({
    required this.plugin,
    required this.artist,
    required this.s,
  });

  @override
  Widget build(BuildContext context) => VoyagerScope(
        child: Scaffold(
          backgroundColor: VoyagerColors.background,
          appBar: AppBar(title: Text(artist.name)),
          body: _AsyncList<MusicAlbum>(
            future: plugin.albumsOfArtist(artist.id),
            emptyLabel: s.libraryEmpty,
            itemBuilder: (album) => _AlbumRow(plugin: plugin, album: album, s: s),
          ),
        ),
      );
}

class _AlbumList extends StatelessWidget {
  final MusicPlugin plugin;
  final VoyagerStrings s;

  const _AlbumList({required this.plugin, required this.s});

  @override
  Widget build(BuildContext context) => _AsyncList<MusicAlbum>(
        future: Future.value(plugin.state.albums),
        emptyLabel: s.libraryEmpty,
        itemBuilder: (album) => _AlbumRow(plugin: plugin, album: album, s: s),
      );
}

class _AlbumRow extends StatelessWidget {
  final MusicPlugin plugin;
  final MusicAlbum album;
  final VoyagerStrings s;

  const _AlbumRow({required this.plugin, required this.album, required this.s});

  @override
  Widget build(BuildContext context) => _Row(
        icon: Icons.album_rounded,
        title: album.name,
        subtitle: album.artist.isEmpty ? null : album.artist,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => _AlbumTracks(plugin: plugin, album: album, s: s),
        )),
        // Playing the whole record is the common intent, so it gets its own
        // target rather than being reachable only through the track list.
        trailing: IconButton(
          icon: const Icon(Icons.play_arrow_rounded,
              color: VoyagerColors.accentLight, size: 30),
          onPressed: () {
            plugin.playAlbum(album);
            Navigator.of(context).popUntil((r) => r.isFirst);
          },
        ),
      );
}

class _AlbumTracks extends StatelessWidget {
  final MusicPlugin plugin;
  final MusicAlbum album;
  final VoyagerStrings s;

  const _AlbumTracks({
    required this.plugin,
    required this.album,
    required this.s,
  });

  @override
  Widget build(BuildContext context) => VoyagerScope(
        child: Scaffold(
          backgroundColor: VoyagerColors.background,
          appBar: AppBar(title: Text(album.name)),
          body: _AsyncList<MusicTrack>(
            future: plugin.tracksOfAlbum(album),
            emptyLabel: s.libraryEmpty,
            itemBuilder: (track) => _Row(
              icon: Icons.music_note_rounded,
              title: track.title,
              subtitle: track.artist.isEmpty ? null : track.artist,
              // Starting from a track plays the rest of the album after it,
              // rather than that one song and then silence.
              onTap: () async {
                await plugin.playAlbumFrom(album, track);
                if (context.mounted) {
                  Navigator.of(context).popUntil((r) => r.isFirst);
                }
              },
            ),
          ),
        ),
      );
}

class _SongList extends StatelessWidget {
  final MusicPlugin plugin;
  final VoyagerStrings s;

  const _SongList({required this.plugin, required this.s});

  @override
  Widget build(BuildContext context) => _AsyncList<MusicTrack>(
        future: plugin.allTracks(),
        emptyLabel: s.libraryEmpty,
        itemBuilder: (track) => _Row(
          icon: Icons.music_note_rounded,
          title: track.title,
          subtitle: track.artist.isEmpty ? null : track.artist,
          onTap: () async {
            await plugin.playTrack(track);
            if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
          },
        ),
      );
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  const _Row({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: VoyagerColors.accentLight, size: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: VoyagerColors.textPrimary,
                        fontSize: 17,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: VoyagerColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      );
}

class _Message extends StatelessWidget {
  final String text;
  const _Message({required this.text});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AutomotiveConfig.sectionGap),
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
