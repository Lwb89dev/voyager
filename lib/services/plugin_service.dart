import 'package:flutter/foundation.dart';

import '../models/gesture_event.dart';
import '../models/plugin_manifest.dart';
import '../plugins/base_plugin.dart';
import '../utils/logger_automotive.dart';

/// Owns the plugin instances: registration, initialisation, focus and teardown.
///
/// The dashboard talks to this and never to a plugin's constructor, which is
/// what allows plugins to be enabled or disabled at runtime as servers and
/// permissions come and go.
class PluginService extends ChangeNotifier {
  final Map<String, BasePlugin> _plugins = {};

  String? _activeId;
  bool _initialized = false;

  /// Registered plugins in button-bar order, hidden ones excluded.
  List<BasePlugin> get visiblePlugins {
    final list = _plugins.values.where((p) => p.manifest.enabled).toList();
    list.sort((a, b) => a.manifest.order.compareTo(b.manifest.order));
    return list;
  }

  List<PluginManifest> get manifests =>
      visiblePlugins.map((p) => p.manifest).toList();

  BasePlugin? get active => _activeId == null ? null : _plugins[_activeId];
  bool get isInitialized => _initialized;

  /// The plugin currently entitled to draw over the active one, if any.
  ///
  /// Derived rather than set: an overlay is a consequence of a plugin's state
  /// — a track is playing, a call is ringing — and anything that has to be
  /// switched on separately will sooner or later be left on after the thing it
  /// was showing has gone.
  ///
  /// The active plugin is never its own overlay: it already owns the screen.
  BasePlugin? get overlay {
    final candidates = _plugins.values.where(_isOverlayCandidate).toList();
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) =>
        b.manifest.overlayPriority.compareTo(a.manifest.overlayPriority));
    return candidates.first;
  }

  bool _isOverlayCandidate(BasePlugin plugin) =>
      plugin.manifest.enabled &&
      plugin.manifest.providesOverlay &&
      plugin.wantsOverlay &&
      plugin.id != _activeId;

  BasePlugin? byId(String id) => _plugins[id];

  /// Registers a plugin. Registration is synchronous and cheap; the expensive
  /// part happens in [initializeAll].
  void register(BasePlugin plugin) {
    if (_plugins.containsKey(plugin.id)) {
      throw StateError('Plugin "${plugin.id}" is already registered.');
    }
    _plugins[plugin.id] = plugin;
    plugin.addListener(notifyListeners);
  }

  /// Initialises every registered plugin concurrently.
  ///
  /// Concurrently, not in sequence: the music plugin waits on a network round
  /// trip, the voice plugin on loading a ~90 MB ONNX model, the phone plugin
  /// on a permission dialog. Serialised, that is a visibly slow startup for no
  /// reason — none of them depend on each other.
  ///
  /// A plugin that fails stays registered and reports its error through
  /// [BasePlugin.initializationError]; the rest of the dashboard is unaffected.
  Future<void> initializeAll() async {
    await Future.wait(_plugins.values.map(_initializeOne));
    _activeId ??= visiblePlugins
        .where((p) => p.manifest.canBeFullscreen)
        .map((p) => p.id)
        .firstOrNull;
    _initialized = true;
    notifyListeners();
  }

  Future<void> _initializeOne(BasePlugin plugin) async {
    try {
      await plugin.initialize();
      AutomotiveLogger.debug('Plugins', '${plugin.id} ready=${plugin.isReady}');
    } catch (error, stack) {
      // BasePlugin.initialize is documented as never throwing. If one does
      // anyway, contain it here: a broken plugin must not prevent the others
      // from coming up.
      AutomotiveLogger.error('Plugins', 'init ${plugin.id} failed', error);
      assert(() {
        debugPrintStack(stackTrace: stack);
        return true;
      }());
    }
  }

  /// Brings a plugin to the foreground. Unknown ids and plugins that cannot be
  /// fullscreen are ignored rather than throwing — this is called from touch
  /// handlers and voice commands, where a bad id is a bug to log, not a crash
  /// to show a driver.
  void activate(String id) {
    final plugin = _plugins[id];
    if (plugin == null || !plugin.manifest.canBeFullscreen) {
      AutomotiveLogger.warn('Plugins', 'cannot activate "$id"');
      return;
    }
    if (_activeId == id) return;

    _plugins[_activeId]?.onVisibilityChanged(false);
    _activeId = id;
    plugin.onVisibilityChanged(true);
    notifyListeners();
  }

  /// Routes a hardware key press. The overlay plugin gets first refusal
  /// because it is the one the driver just interacted with — if the music
  /// strip is up, the wheel buttons belong to music, not to the map beneath.
  bool dispatchButton(GestureEvent event) {
    final candidates = [overlay, active].nonNulls;
    for (final plugin in candidates) {
      if (plugin.onPhysicalButtonPress(event)) return true;
    }
    return false;
  }

  @override
  void dispose() {
    for (final plugin in _plugins.values) {
      plugin.removeListener(notifyListeners);
      plugin.dispose();
    }
    _plugins.clear();
    super.dispose();
  }
}
