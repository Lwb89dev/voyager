import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voyager/models/gesture_event.dart';
import 'package:voyager/models/plugin_manifest.dart';
import 'package:voyager/plugins/base_plugin.dart';
import 'package:voyager/services/plugin_service.dart';

/// A plugin whose behaviour the tests control: how long it takes, whether it
/// fails, and which buttons it claims.
class FakePlugin extends BasePlugin {
  FakePlugin(
    this._id, {
    this.order = 0,
    this.overlay = false,
    this.overlayPriority = 0,
    this.showingOverlay = true,
    this.fullscreen = true,
    this.failsWith,
    this.delay = Duration.zero,
    this.claimsButton,
  });

  final String _id;
  final int order;
  final bool overlay;
  final int overlayPriority;
  final bool showingOverlay;
  final bool fullscreen;
  final Object? failsWith;
  final Duration delay;
  final PhysicalButton? claimsButton;

  bool _ready = false;
  String? _error;
  final List<bool> visibilityChanges = [];
  int buttonsSeen = 0;

  @override
  PluginManifest get manifest => PluginManifest(
        id: _id,
        label: _id,
        icon: Icons.abc,
        order: order,
        providesOverlay: overlay,
        overlayPriority: overlayPriority,
        canBeFullscreen: fullscreen,
      );

  @override
  bool get wantsOverlay => overlay && showingOverlay;

  @override
  bool get isReady => _ready;

  @override
  String? get initializationError => _error;

  @override
  Future<void> initialize() async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (failsWith != null) {
      _error = failsWith.toString();
      return;
    }
    _ready = true;
    notifyListeners();
  }

  @override
  Widget buildFullscreenView(BuildContext context) => const SizedBox();

  @override
  void onVisibilityChanged(bool visible) => visibilityChanges.add(visible);

  @override
  bool onPhysicalButtonPress(GestureEvent event) {
    buttonsSeen++;
    return event.button == claimsButton;
  }
}

GestureEvent press(PhysicalButton button) =>
    GestureEvent(button: button, at: DateTime.now());

void main() {
  group('registration', () {
    test('rejects a duplicate id', () {
      final service = PluginService()..register(FakePlugin('music'));
      expect(() => service.register(FakePlugin('music')), throwsStateError);
    });

    test('orders visible plugins by manifest order', () async {
      final service = PluginService()
        ..register(FakePlugin('c', order: 2))
        ..register(FakePlugin('a', order: 0))
        ..register(FakePlugin('b', order: 1));
      await service.initializeAll();
      expect(service.manifests.map((m) => m.id), ['a', 'b', 'c']);
    });
  });

  group('initialisation', () {
    test('runs plugins concurrently, not one after another', () async {
      // Three plugins that each take 100 ms. Serialised they would need 300 ms;
      // the assertion is deliberately loose enough not to be flaky on a loaded
      // machine but tight enough to fail if they are awaited in sequence.
      final service = PluginService();
      for (var i = 0; i < 3; i++) {
        service.register(
          FakePlugin('p$i', order: i, delay: const Duration(milliseconds: 100)),
        );
      }
      final watch = Stopwatch()..start();
      await service.initializeAll();
      watch.stop();
      expect(watch.elapsedMilliseconds, lessThan(250));
    });

    test('a failing plugin does not stop the others', () async {
      final good = FakePlugin('good', order: 1);
      final service = PluginService()
        ..register(FakePlugin('bad', order: 0, failsWith: 'server down'))
        ..register(good);

      await service.initializeAll();

      expect(good.isReady, isTrue);
      expect(service.byId('bad')!.isReady, isFalse);
      expect(service.byId('bad')!.initializationError, 'server down');
    });

    test('activates the first fullscreen-capable plugin', () async {
      final service = PluginService()
        ..register(FakePlugin('voice', order: 0, fullscreen: false))
        ..register(FakePlugin('map', order: 1));
      await service.initializeAll();
      expect(service.active?.id, 'map');
    });
  });

  group('activation', () {
    test('notifies both plugins on a switch', () async {
      final map = FakePlugin('map', order: 0);
      final music = FakePlugin('music', order: 1);
      final service = PluginService()..register(map)..register(music);
      await service.initializeAll();

      service.activate('music');

      expect(map.visibilityChanges, [false]);
      expect(music.visibilityChanges, [true]);
    });

    test('ignores a plugin that cannot be fullscreen', () async {
      final service = PluginService()
        ..register(FakePlugin('map', order: 0))
        ..register(FakePlugin('voice', order: 1, fullscreen: false));
      await service.initializeAll();

      service.activate('voice');

      expect(service.active?.id, 'map');
    });

    test('ignores an unknown id instead of throwing', () async {
      final service = PluginService()..register(FakePlugin('map'));
      await service.initializeAll();
      service.activate('nope');
      expect(service.active?.id, 'map');
    });
  });

  group('overlay', () {
    test('is null when no plugin wants one', () async {
      final service = PluginService()
        ..register(FakePlugin('map'))
        ..register(FakePlugin('music', order: 1, overlay: true,
            showingOverlay: false));
      await service.initializeAll();
      expect(service.overlay, isNull);
    });

    test('is the plugin that wants one', () async {
      final service = PluginService()
        ..register(FakePlugin('map'))
        ..register(FakePlugin('music', order: 1, overlay: true));
      await service.initializeAll();
      expect(service.overlay?.id, 'music');
    });

    test('ignores a plugin that does not advertise one', () async {
      // wantsOverlay alone is not enough: the manifest is what says a plugin
      // is allowed to cover the map at all.
      final service = PluginService()..register(FakePlugin('map'));
      await service.initializeAll();
      expect(service.overlay, isNull);
    });

    test('never overlays the plugin that is already fullscreen', () async {
      final service = PluginService()
        ..register(FakePlugin('music', overlay: true));
      await service.initializeAll();
      expect(service.active?.id, 'music');
      expect(service.overlay, isNull);
    });

    test('the highest priority wins when several want one', () async {
      final service = PluginService()
        ..register(FakePlugin('map'))
        ..register(FakePlugin('music', order: 1, overlay: true,
            overlayPriority: 1))
        ..register(FakePlugin('phone', order: 2, overlay: true,
            overlayPriority: 3));
      await service.initializeAll();
      expect(service.overlay?.id, 'phone');
    });
  });

  group('button routing', () {
    test('offers the event to the overlay before the active plugin', () async {
      final map = FakePlugin('map', claimsButton: PhysicalButton.menu);
      final music = FakePlugin(
        'music',
        order: 1,
        overlay: true,
        claimsButton: PhysicalButton.volumeUp,
      );
      final service = PluginService()..register(map)..register(music);
      await service.initializeAll();

      expect(service.dispatchButton(press(PhysicalButton.volumeUp)), isTrue);
      // The map never saw it: the overlay consumed it first.
      expect(map.buttonsSeen, 0);
    });

    test('falls through to the active plugin when unclaimed', () async {
      final map = FakePlugin('map', claimsButton: PhysicalButton.menu);
      final music = FakePlugin('music', order: 1, overlay: true);
      final service = PluginService()..register(map)..register(music);
      await service.initializeAll();

      expect(service.dispatchButton(press(PhysicalButton.menu)), isTrue);
      expect(map.buttonsSeen, 1);
    });

    test('reports an event nobody claimed', () async {
      final service = PluginService()..register(FakePlugin('map'));
      await service.initializeAll();
      expect(service.dispatchButton(press(PhysicalButton.voice)), isFalse);
    });

    test('does not offer events to a background plugin', () async {
      final hidden = FakePlugin('weather', order: 2);
      final service = PluginService()
        ..register(FakePlugin('map'))
        ..register(hidden);
      await service.initializeAll();

      service.dispatchButton(press(PhysicalButton.voice));

      expect(hidden.buttonsSeen, 0);
    });
  });
}
