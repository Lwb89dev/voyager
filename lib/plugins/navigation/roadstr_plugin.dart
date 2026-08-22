import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:roadstr/screens/map_screen.dart';
import 'package:roadstr/theme/theme_provider.dart';

import '../../models/gesture_event.dart';
import '../../models/plugin_manifest.dart';
import '../../screens/settings_screen.dart';
import '../../utils/logger_automotive.dart';
import '../base_plugin.dart';
import 'navigation_state.dart';

/// Where Roadstr's own bottom bar sends its menu icon, under Voyager.
///
/// A static top-level function rather than a closure so it stays a constant
/// expression — [RoadstrPlugin._map] is `const`, and a lambda capturing
/// instance state could not be. Pushed with the [BuildContext] MapBottomBar's
/// own `onTap` already has, not one captured earlier: this is invoked once,
/// at tap time, and any context from construction time could be stale.
void _openVoyagerSettings(BuildContext context) => Navigator.of(context)
    .push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));

/// Navigation, provided by Roadstr.
///
/// Voyager does not reimplement navigation and does not fork it: it depends on
/// the Roadstr package and mounts its [MapScreen] as the plugin's fullscreen
/// view. Everything that makes Roadstr good — OSRM routing, Overpass POIs,
/// speed cameras, ZTL warnings, Nostr road reports — arrives for free and
/// keeps arriving as Roadstr is updated.
///
/// The cost of that choice is that this plugin is thin by necessity: MapScreen
/// owns its own state and exposes no controller, so Voyager can show it, hide
/// it and sit next to it, but cannot drive it programmatically. Voice commands
/// like "navigate home" will need a small controller surface added on the
/// Roadstr side; until then they are not offered, rather than faked.
class RoadstrPlugin extends BasePlugin {
  /// Built once and reused, never rebuilt.
  ///
  /// This is the whole reason the widget is held in a field: MapScreen's state
  /// holds the tile cache, the position stream subscription and the current
  /// route. Recreating the widget on every plugin switch would tear all of
  /// that down and re-acquire a GPS fix each time the driver glanced at the
  /// music screen and back.
  static const Widget _map = MapScreen(onOpenAppSettings: _openVoyagerSettings);

  // Final for now: Roadstr exposes no route-state stream, so Voyager cannot
  // observe guidance transitions yet and this never changes. It becomes
  // mutable the moment MapScreen grows a controller — see the class comment.
  final NavigationState _state = const NavigationState.idle();
  bool _ready = false;

  NavigationState get state => _state;

  @override
  PluginManifest get manifest => const PluginManifest(
        id: 'navigation',
        label: 'Navigation',
        icon: Icons.navigation_rounded,
        // Always first in the button bar. Drivers reach for it without
        // looking, and a button that moves is a button that gets missed.
        order: 0,
      );

  @override
  bool get isReady => _ready;

  @override
  Future<void> initialize() async {
    // Nothing to await: MapScreen does its own asynchronous setup in
    // initState, and doing any of it here would only delay the first frame
    // without making the map appear any sooner.
    _ready = true;
    notifyListeners();
  }

  /// The map fills the pane and lifts its own controls off the bottom edge —
  /// padding it would leave a dead band where tiles should be.
  @override
  bool get respectsChromeInset => false;

  @override
  Widget buildFullscreenView(BuildContext context) {
    // MapScreen is handed Roadstr's own ThemeData, not Voyager's.
    //
    // Roadstr's widgets read their palette through `RoadstrColors.of(context)`,
    // which resolves a ThemeExtension and dereferences it with `!`. Voyager's
    // theme does not carry that extension, so every Roadstr screen mounted
    // under it died on a null check before painting a single tile — which is
    // what the blank navigation pane actually was.
    //
    // Injecting the extension into Voyager's theme instead would work, but it
    // would also mean Voyager silently owning the look of Roadstr's screens
    // and having to track every change to it. Scoping Roadstr's theme to
    // Roadstr's subtree keeps each app's chrome its own.
    //
    // The theme is Roadstr's own choice, not a fixed dark one. Voyager's chrome
    // stays dark for the reason given in VoyagerTheme — a bright panel in a
    // windscreen mount reflects onto the glass — but the map is the part the
    // driver actually looks at, Roadstr ships eight themes and an automatic
    // sunset switch, and deciding on the user's behalf that they may not have
    // them was overreach. The picker lives in Voyager's settings.
    final theme = context.watch<ThemeProvider>();
    return Theme(data: theme.effectiveThemeData, child: _map);
  }

  @override
  void onVisibilityChanged(bool visible) {
    // Roadstr silences its own logging while guiding; mirror that for
    // Voyager's logger so a route's street names never reach logcat from
    // either side.
    AutomotiveLogger.driving = visible && _state.isGuiding;
  }

  @override
  bool onPhysicalButtonPress(GestureEvent event) {
    // The map deliberately claims no hardware buttons. On a steering wheel the
    // volume rocker belongs to the music plugin, and there is no navigation
    // action worth binding to a physical key that is safe to trigger by
    // accident — least of all cancelling a route.
    return false;
  }
}
