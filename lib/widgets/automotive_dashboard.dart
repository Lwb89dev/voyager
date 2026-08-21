import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';

import '../models/gesture_event.dart';
import '../screens/settings_screen.dart';
import '../services/automotive_gesture_service.dart';
import '../services/automotive_ui_service.dart';
import '../services/plugin_service.dart';
import 'automotive_chrome.dart';
import 'fullscreen_plugin_view.dart';
import 'voyager_scope.dart';

/// The dashboard: the active plugin, full-bleed, with Voyager's own controls
/// floating over it.
///
/// One layout, not two. An earlier version docked the chrome in a `Column` in
/// portrait and only floated it in landscape, on the reasoning that portrait
/// had 15% of the screen to spare for furniture and landscape did not. That
/// reasoning was sound and the conclusion was wrong: floating costs nothing
/// docking does not also cost, it looks the same in every orientation, and
/// maintaining two layouts meant maintaining two sets of Roadstr patches to
/// keep the map's own controls clear of each one (see
/// `patches/roadstr/README.md`). One floating layout, used everywhere, is
/// both the better UI and the smaller amount of code.
///
/// It owns no feature state. Everything it shows comes from [PluginService].
class AutomotiveDashboard extends StatefulWidget {
  const AutomotiveDashboard({super.key});

  @override
  State<AutomotiveDashboard> createState() => _AutomotiveDashboardState();
}

class _AutomotiveDashboardState extends State<AutomotiveDashboard> {
  static const _collapsedKey = 'voyager_chrome_collapsed';

  StreamSubscription<GestureEvent>? _buttonSub;
  late bool _collapsed;

  @override
  void initState() {
    super.initState();
    _collapsed =
        Hive.box('settings').get(_collapsedKey, defaultValue: false) as bool;
    final gestures = context.read<AutomotiveGestureService>();
    _buttonSub = gestures.events.listen(_onButton);
  }

  void _onButton(GestureEvent event) {
    final plugins = context.read<PluginService>();
    if (plugins.dispatchButton(event)) return;
    // Nothing claimed it. The menu key is the one Voyager handles itself:
    // whatever the driver was doing, it goes back to the map — and brings the
    // controls back with it, so the way out is never hidden.
    if (event.button != PhysicalButton.menu) return;
    plugins.activate('navigation');
    if (_collapsed) _toggleCollapsed();
  }

  void _toggleCollapsed() {
    setState(() => _collapsed = !_collapsed);
    Hive.box('settings').put(_collapsedKey, _collapsed);
  }

  @override
  void dispose() {
    _buttonSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plugins = context.watch<PluginService>();
    final ui = context.watch<AutomotiveUiService>();

    // Plus the system's own bottom inset: the chrome sits inside a SafeArea,
    // so its real footprint is its height *and* whatever the gesture bar
    // reserves underneath it. Reserving only the height left a strip of every
    // plugin pane behind the bar.
    final reserved = AutomotiveChrome.reservedHeight(collapsed: _collapsed) +
        MediaQuery.of(context).viewPadding.bottom;

    return VoyagerScope(
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: _withBottomInset(
                context,
                reserved,
                FullscreenPluginView(service: plugins, bottomInset: reserved),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AutomotiveChrome(
                plugins: plugins.manifests,
                activeId: plugins.active?.id,
                onSelected: plugins.activate,
                onSettings: () => _openSettings(context),
                collapsed: _collapsed,
                onToggleCollapsed: _toggleCollapsed,
              ),
            ),
            // The night scrim goes over everything, chrome included: a bright
            // row of icons at the bottom of the screen reflects onto the
            // windscreen just as well as a bright map does.
            if (ui.dimOpacity > 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: ui.dimOpacity),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Adds the chrome's height to the bottom padding the plugin subtree sees,
  /// so the plugin's own bottom-anchored furniture sits above it.
  ///
  /// `padding` only, deliberately: `viewPadding` is left truthful.
  ///
  /// Roadstr reads `viewPadding.bottom` for everything along the bottom
  /// edge — its floating buttons, its modal sheets, its own compact bar — and
  /// inflating that value moved all of them, so a parking sheet gained 132 px
  /// of padding and overflowed, and a bar meant to sit level with this chrome
  /// floated halfway up the screen. Each needed its own cap, which is a rule
  /// nobody would remember the next time Roadstr adds a sheet.
  ///
  /// Splitting the two makes it one rule instead: `viewPadding` is what the
  /// system reserves, `padding` is what *this host* reserves, and the patches
  /// in `patches/roadstr/` point the panels that must clear the chrome at the
  /// second one. Everything else keeps working untouched.
  Widget _withBottomInset(BuildContext context, double extra, Widget child) {
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(
        padding: media.padding.copyWith(
          bottom: media.padding.bottom + extra,
        ),
      ),
      child: child,
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );
  }
}
