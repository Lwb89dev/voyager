import 'package:flutter/material.dart';

import '../l10n/voyager_strings.dart';
import '../plugins/podcast/podcast_models.dart';
import '../plugins/podcast/podcast_plugin.dart';
import '../theme/voyager_theme.dart';
import '../widgets/voyager_scope.dart';

/// Adding a show: by name, or by feed URL.
///
/// Both, because they serve different people. Search covers the directory and
/// needs no account; the URL field covers everything the directory does not —
/// a private feed, a self-hosted one, or a Podstr instance, which publishes an
/// ordinary RSS feed and so needs no special support at all.
class PodcastAddScreen extends StatefulWidget {
  final PodcastPlugin plugin;

  const PodcastAddScreen({super.key, required this.plugin});

  static Future<void> show(BuildContext context, PodcastPlugin plugin) =>
      Navigator.of(context).push<void>(MaterialPageRoute(
        builder: (_) => PodcastAddScreen(plugin: plugin),
      ));

  @override
  State<PodcastAddScreen> createState() => _PodcastAddScreenState();
}

class _PodcastAddScreenState extends State<PodcastAddScreen> {
  final _controller = TextEditingController();
  List<PodcastSubscription> _results = const [];
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _looksLikeUrl {
    final text = _controller.text.trim();
    return text.startsWith('http://') || text.startsWith('https://');
  }

  /// One button for both paths: what was typed decides which.
  ///
  /// Asking the user to choose "search" or "add by URL" first is a decision
  /// they should not have to make — a string starting with `http` is never a
  /// search term.
  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_looksLikeUrl) {
        final show = await widget.plugin.repository.describe(
          _controller.text.trim(),
        );
        await widget.plugin.subscribe(show);
        if (mounted) Navigator.of(context).pop();
        return;
      }
      final results = await widget.plugin.repository.search(_controller.text);
      if (mounted) setState(() => _results = results);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = VoyagerStrings.of(context);
    return VoyagerScope(
      child: Scaffold(
        backgroundColor: VoyagerColors.background,
        appBar: AppBar(title: Text(s.addPodcast)),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autocorrect: false,
                      onSubmitted: (_) => _submit(),
                      style: const TextStyle(
                        color: VoyagerColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: s.searchOrFeedUrl,
                        filled: true,
                        fillColor: VoyagerColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: Text(_looksLikeUrl ? s.add : s.searchAction),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: VoyagerColors.danger,
                    fontSize: 13,
                  ),
                ),
              ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: VoyagerColors.accent),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (_, i) {
                  final show = _results[i];
                  return ListTile(
                    leading: const Icon(
                      Icons.podcasts_rounded,
                      color: VoyagerColors.accentLight,
                    ),
                    title: Text(
                      show.title,
                      style: const TextStyle(color: VoyagerColors.textPrimary),
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.add_circle_outline_rounded,
                        color: VoyagerColors.accentLight,
                      ),
                      onPressed: () async {
                        await widget.plugin.subscribe(show);
                        if (context.mounted) Navigator.of(context).pop();
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
