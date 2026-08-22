import 'package:flutter/material.dart';

import '../models/gesture_event.dart';
import '../models/plugin_manifest.dart';

/// Contract every Voyager feature implements.
///
/// A plugin owns its own state, its own initialisation and its own views. The
/// dashboard knows only this interface, which is what keeps adding a feature
/// from turning into a dashboard rewrite: a new plugin is one file plus one
/// registration line.
///
/// Lifecycle, in order:
///
///   1. Constructed — cheap, synchronous, no I/O. Constructors run during
///      `initState`, so anything slow here costs a dropped first frame.
///   2. [initialize] — async, may fail. The dashboard renders the plugin's
///      button as soon as the manifest exists, and its view only once
///      [isReady] turns true, so a slow or unreachable backend degrades to a
///      loading state instead of blocking the app.
///   3. Running — [buildFullscreenView] and [buildOverlay] are called on every
///      relevant frame and must be cheap and side-effect free.
///   4. [dispose] — release sockets, audio focus, isolates and native handles.
///
/// Plugins extend [ChangeNotifier]: the dashboard listens and rebuilds. Call
/// `notifyListeners` when [isReady] changes or when displayed state moves.
abstract class BasePlugin extends ChangeNotifier {
  /// Static description. Must be available immediately after construction —
  /// it is read before [initialize] has been awaited.
  PluginManifest get manifest;

  String get id => manifest.id;

  /// True once [initialize] has completed successfully. False while loading
  /// and false again after a failed initialisation, in which case
  /// [initializationError] explains why.
  bool get isReady;

  /// Set when initialisation failed. The dashboard shows this to the user
  /// instead of an empty pane — a driver who sees "music server unreachable"
  /// stops poking at the screen.
  String? get initializationError => null;

  /// Acquire resources. Must not throw: catch, record the failure in
  /// [initializationError], and return. A plugin that throws here would take
  /// down the whole dashboard with it.
  Future<void> initialize();

  /// Tries again after a failed [initialize] — offered to the user as a
  /// button on [PluginPlaceholder] rather than requiring a full app restart,
  /// which was previously the only way back from, say, a permission the user
  /// denied and then granted from Settings without Voyager ever finding out.
  ///
  /// The default just re-runs [initialize]; a plugin whose failure needs more
  /// than that first — re-requesting a permission, for instance — overrides
  /// this instead of leaving the user to work out where to go by themselves.
  Future<void> retry() => initialize();

  /// The plugin as the main pane. Only called when [isReady].
  Widget buildFullscreenView(BuildContext context);

  /// A compact strip drawn above another plugin's fullscreen view — the music
  /// mini-player over the map, for instance. Null means no overlay.
  Widget? buildOverlay(BuildContext context) => null;

  /// Whether this plugin has something to show over another plugin right now.
  ///
  /// Separate from [buildOverlay] because the dashboard must decide *which*
  /// overlay wins before it has a BuildContext to build any of them, and
  /// because a plugin that wants the overlay also wants the hardware buttons
  /// — the routing in [PluginService] keys off this.
  bool get wantsOverlay => false;

  /// A hardware key press routed to this plugin. Return true to consume the
  /// event; return false and the dashboard offers it to the next plugin, then
  /// to its own default handling.
  ///
  /// Only the active plugin and plugins with a visible overlay are offered
  /// events, so a background plugin can never steal the wheel controls.
  bool onPhysicalButtonPress(GestureEvent event) => false;

  /// Whether the dashboard should keep its floating chrome clear of this
  /// plugin's view by padding the bottom of it.
  ///
  /// True for every plugin that lays out ordinary content, which would
  /// otherwise be partly covered. False for a plugin that wants the full bleed
  /// and places its own furniture — the map is the case: it draws edge to edge
  /// on purpose and offsets its own controls from the padding it is given.
  bool get respectsChromeInset => true;

  /// Called when this plugin becomes, or stops being, the fullscreen one.
  /// Use it to throttle work that only matters while visible — map tile
  /// prefetching, artwork decoding, weather polling.
  void onVisibilityChanged(bool visible) {}
}
