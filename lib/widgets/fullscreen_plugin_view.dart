import 'package:flutter/material.dart';

import '../config/automotive_config.dart';
import '../plugins/base_plugin.dart';
import '../services/plugin_service.dart';
import 'plugin_placeholder.dart';

/// The main pane: the active plugin's view, with any overlay stacked on top.
///
/// Every registered plugin's fullscreen view is kept alive in an [IndexedStack]
/// rather than built on demand. That costs memory — the map keeps its tiles,
/// the music screen keeps its decoded artwork — and buys the thing that
/// matters far more in a car: switching to navigation and back is instant, with
/// no GPS re-acquisition and no white flash while a map redraws. A dashboard
/// that stutters when the driver looks at it is a dashboard the driver stares
/// at for longer.
class FullscreenPluginView extends StatelessWidget {
  final PluginService service;

  /// Space to keep clear at the bottom, so a plugin's overlay sits above
  /// Voyager's floating chrome instead of underneath it. Zero in portrait,
  /// where the chrome is docked and takes its own room.
  final double bottomInset;

  const FullscreenPluginView({
    super.key,
    required this.service,
    this.bottomInset = 0,
  });

  @override
  Widget build(BuildContext context) {
    final plugins =
        service.visiblePlugins.where((p) => p.manifest.canBeFullscreen).toList();
    if (plugins.isEmpty) return const SizedBox.expand();

    final activeIndex = plugins.indexWhere((p) => p.id == service.active?.id);
    final overlay = service.overlay?.buildOverlay(context);

    return Stack(
      children: [
        Positioned.fill(
          child: IndexedStack(
            index: activeIndex < 0 ? 0 : activeIndex,
            sizing: StackFit.expand,
            children: plugins.map((p) => _paneFor(context, p)).toList(),
          ),
        ),
        if (overlay != null)
          Positioned(
            left: AutomotiveConfig.gutter,
            right: AutomotiveConfig.gutter,
            bottom: AutomotiveConfig.gutter + bottomInset,
            child: overlay,
          ),
      ],
    );
  }

  Widget _paneFor(BuildContext context, BasePlugin plugin) {
    final pane = !plugin.isReady || plugin.initializationError != null
        ? PluginPlaceholder(
            manifest: plugin.manifest,
            error: plugin.initializationError,
          )
        : plugin.buildFullscreenView(context);

    if (!plugin.respectsChromeInset || bottomInset == 0) return pane;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: pane,
    );
  }
}
