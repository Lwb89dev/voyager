import 'dart:io';

import 'package:flutter/material.dart';

import '../config/automotive_config.dart';
import '../l10n/voyager_strings.dart';
import '../plugins/music/music_folder_service.dart';
import '../services/permission_service.dart';
import '../theme/voyager_theme.dart';
import '../widgets/voyager_scope.dart';

/// Lets the user point Voyager at the folder their music is in.
///
/// A plain directory browser rather than the system document picker. The system
/// picker returns a SAF tree URI, which Dart's `dart:io` cannot open — the app
/// would end up holding a path it is unable to read and reporting an empty
/// library for a folder full of music. With READ_MEDIA_AUDIO granted, ordinary
/// path access to the shared volume works, so a browser built on `Directory`
/// gives a path that is usable by the thing that will actually do the scanning.
///
/// Used parked, never while driving, so it uses ordinary control sizes.
class MusicFolderScreen extends StatefulWidget {
  const MusicFolderScreen({super.key});

  /// Returns the chosen path, or null if the user backed out.
  static Future<String?> show(BuildContext context) =>
      Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const MusicFolderScreen()),
      );

  @override
  State<MusicFolderScreen> createState() => _MusicFolderScreenState();
}

class _MusicFolderScreenState extends State<MusicFolderScreen> {
  PermissionState _access = PermissionState.askable;
  String? _current;
  List<Directory> _entries = const [];
  bool _loading = true;
  List<String> _chosen = const [];

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final access = await MusicFolderService.accessState();
    if (!mounted) return;
    setState(() {
      _access = access;
      _chosen = MusicFolderService.chosenFolders;
    });
    if (access == PermissionState.granted) await _openFirstReadableRoot();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _removeFolder(String path) async {
    await MusicFolderService.removeFolder(path);
    if (mounted) setState(() => _chosen = MusicFolderService.chosenFolders);
  }

  Future<void> _requestAccess() async {
    if (_access == PermissionState.blocked) {
      await PermissionService.openSettings();
      await _start();
      return;
    }
    final result = await MusicFolderService.requestAccess();
    if (!mounted) return;
    setState(() => _access = result);
    if (result == PermissionState.granted) await _openFirstReadableRoot();
  }

  /// Devices disagree about which of `/storage/emulated/0` and `/sdcard` is
  /// real, and one of them is usually a symlink to the other. Try each and open
  /// the first that lists.
  Future<void> _openFirstReadableRoot() async {
    for (final root in MusicFolderService.browseRoots) {
      if (!await Directory(root).exists()) continue;
      final entries = await MusicFolderService.subdirectories(root);
      if (entries.isEmpty) continue;
      if (!mounted) return;
      setState(() {
        _current = root;
        _entries = entries;
      });
      return;
    }
    if (mounted) setState(() => _current = null);
  }

  Future<void> _open(String path) async {
    setState(() => _loading = true);
    final entries = await MusicFolderService.subdirectories(path);
    if (!mounted) return;
    setState(() {
      _current = path;
      _entries = entries;
      _loading = false;
    });
  }

  void _goUp() {
    final current = _current;
    if (current == null) return;
    final index = current.lastIndexOf('/');
    if (index <= 0) return;
    _open(current.substring(0, index));
  }

  /// Adds the current folder to the chosen set — it does not leave the
  /// browser, so a second and third folder are as many taps away as the
  /// first rather than a whole separate visit to this screen each time.
  Future<void> _choose() async {
    final current = _current;
    if (current == null) return;
    if (!await MusicFolderService.isReadable(current)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(VoyagerStrings.of(context).folderUnreadable)),
      );
      return;
    }
    await MusicFolderService.addFolder(current);
    if (mounted) setState(() => _chosen = MusicFolderService.chosenFolders);
  }

  @override
  Widget build(BuildContext context) {
    final s = VoyagerStrings.of(context);
    return VoyagerScope(
      child: Scaffold(
        backgroundColor: VoyagerColors.background,
        appBar: AppBar(
          title: Text(s.chooseMusicFolder),
          actions: [
            if (_access == PermissionState.granted && _current != null)
              TextButton(
                onPressed: _chosen.contains(_current) ? null : _choose,
                child: Text(
                  _chosen.contains(_current) ? s.folderAdded : s.useThisFolder,
                  style: TextStyle(
                    color: _chosen.contains(_current)
                        ? VoyagerColors.textSecondary
                        : VoyagerColors.accentLight,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        body: _body(s),
      ),
    );
  }

  Widget _body(VoyagerStrings s) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: VoyagerColors.accent),
      );
    }
    if (_access != PermissionState.granted) {
      return _AccessGate(s: s, state: _access, onGrant: _requestAccess);
    }
    if (_current == null) return _Message(text: s.folderUnreadable);

    return Column(
      children: [
        if (_chosen.isNotEmpty)
          _ChosenFolders(folders: _chosen, onRemove: _removeFolder),
        _PathBar(path: _current!, onUp: _goUp),
        Expanded(
          child: _entries.isEmpty
              ? _Message(text: s.folderNoSubfolders)
              : ListView.builder(
                  itemCount: _entries.length,
                  itemBuilder: (context, index) {
                    final directory = _entries[index];
                    return ListTile(
                      leading: const Icon(
                        Icons.folder_rounded,
                        color: VoyagerColors.accentLight,
                      ),
                      title: Text(
                        MusicFolderService.displayName(directory.path),
                        style: const TextStyle(
                          color: VoyagerColors.textPrimary,
                        ),
                      ),
                      onTap: () => _open(directory.path),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ChosenFolders extends StatelessWidget {
  final List<String> folders;
  final ValueChanged<String> onRemove;

  const _ChosenFolders({required this.folders, required this.onRemove});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        color: VoyagerColors.surfaceRaised,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final folder in folders)
              Chip(
                label: Text(MusicFolderService.displayName(folder)),
                labelStyle: const TextStyle(color: VoyagerColors.textPrimary),
                backgroundColor: VoyagerColors.surface,
                side: const BorderSide(color: VoyagerColors.border),
                deleteIcon: const Icon(Icons.close_rounded,
                    size: 16, color: VoyagerColors.textSecondary),
                onDeleted: () => onRemove(folder),
              ),
          ],
        ),
      );
}

class _PathBar extends StatelessWidget {
  final String path;
  final VoidCallback onUp;

  const _PathBar({required this.path, required this.onUp});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        color: VoyagerColors.surface,
        child: Row(
          children: [
            IconButton(
              onPressed: onUp,
              icon: const Icon(Icons.arrow_upward_rounded),
              color: VoyagerColors.textPrimary,
            ),
            Expanded(
              child: Text(
                path,
                maxLines: 1,
                // Truncate from the left: the end of a path says which folder
                // you are in, the start says which volume, and only one of
                // those is in question while browsing.
                overflow: TextOverflow.ellipsis,
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  color: VoyagerColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
}

class _AccessGate extends StatelessWidget {
  final VoyagerStrings s;
  final PermissionState state;
  final VoidCallback onGrant;

  const _AccessGate({
    required this.s,
    required this.state,
    required this.onGrant,
  });

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AutomotiveConfig.sectionGap),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.folder_off_rounded,
                size: 56,
                color: VoyagerColors.textSecondary,
              ),
              const SizedBox(height: AutomotiveConfig.gutter),
              Text(
                s.storageAccessWhy,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: VoyagerColors.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: AutomotiveConfig.sectionGap),
              FilledButton(
                onPressed: onGrant,
                child: Text(
                  state == PermissionState.blocked
                      ? s.permOpenSettings
                      : s.permGrant,
                ),
              ),
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
              fontSize: 14,
            ),
          ),
        ),
      );
}
