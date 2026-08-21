# Writing a Voyager plugin

A plugin is one class extending `BasePlugin`, plus one registration line in
`main.dart`. Nothing else in the app needs to change.

## Minimum viable plugin

```dart
class ParkingPlugin extends BasePlugin {
  bool _ready = false;

  @override
  PluginManifest get manifest => const PluginManifest(
        id: 'parking',
        label: 'Parking',
        icon: Icons.local_parking_rounded,
        order: 5,
      );

  @override
  bool get isReady => _ready;

  @override
  Future<void> initialize() async {
    // Never throw. Catch, record, and let the dashboard show the reason.
    _ready = true;
    notifyListeners();
  }

  @override
  Widget buildFullscreenView(BuildContext context) => const ParkingView();
}
```

Register it in `_registerPlugins` in `lib/main.dart`:

```dart
plugins.register(ParkingPlugin());
```

## Rules that are not negotiable

**`initialize` must not throw.** `PluginService` contains a thrown exception,
but a plugin that relies on that is a plugin whose user sees a generic error
instead of "parking API unreachable". Catch, set an error string, return.

**Constructors do no I/O.** They run during `initState`, before the first
frame. Anything slow belongs in `initialize`.

**`buildFullscreenView` and `buildOverlay` are pure.** They are called on every
relevant frame. Starting a request or a timer from a build method will start
one per frame.

**Call `notifyListeners` when displayed state changes**, and no more often than
that. The dashboard rebuilds on every notification, and it is competing with
map rendering for the frame budget. If a source emits faster than a human can
read (a playback position, a GPS fix), sample it — the music plugin throttles
position updates to 500 ms for exactly this reason.

## Manifest flags

| Flag | Meaning |
| --- | --- |
| `order` | Position in the button bar. Navigation is 0 and stays 0. |
| `canBeFullscreen` | False for plugins that only overlay, like voice. |
| `providesOverlay` | Permission to draw over another plugin. Pair it with `wantsOverlay`. |
| `enabled` | False hides the plugin entirely — use it when the feature has no server, no model or no permission. A visible button that leads nowhere is worse than no button. |

## Overlays

An overlay draws over another plugin's fullscreen view. Only one is shown at a
time, and only plugins whose manifest says `providesOverlay: true` are eligible.

Overlays are *derived*, never switched on: override `wantsOverlay` to say
whether you have something to show right now, and `PluginService` picks the
eligible plugin with the highest `overlayPriority` that is not already
fullscreen. An overlay that has to be enabled separately is an overlay that
ends up still showing after the thing it was showing has gone.

```dart
@override
bool get wantsOverlay => calls.current != null;

@override
Widget? buildOverlay(BuildContext context) =>
    wantsOverlay ? IncomingCallOverlay(plugin: this) : null;
```

Current priorities: phone `3` (a ringing call), voice `2` (listening), music
`1` (a track playing).

Keep overlays short. They cover the map, and the map is the road ahead. The
music strip is one line of text plus three controls; the call card is the one
exception allowed to be large, because the alternative is the driver reaching
for a phone.

## Hardware buttons

```dart
@override
bool onPhysicalButtonPress(GestureEvent event) {
  if (event.button != PhysicalButton.voice) return false;
  unawaited(listenOnce());
  return true;   // consumed — no other plugin sees it
}
```

Only the overlay plugin and the active plugin are offered events, in that
order. Return false for anything you do not handle.

Do not bind destructive actions to a physical key. There is no confirmation
step available to someone who is driving.

## UI conventions

Use `AutomotiveButton` for anything a driver touches in motion: it enforces the
80 dp minimum target and always carries a semantic label. `AutomotiveConfig`
holds the spacing, type sizes and palette; `VoyagerColors` holds the palette
sampled from the app icon.

Settings screens are the exception — they are used parked, so they use ordinary
Material controls at ordinary sizes.

## Testing a plugin

Inject the dependency that talks to the outside world, the way `MusicPlugin`
takes a `libraryOverride` and `SpeechService` takes a `KokoroTtsService`. Then
the lifecycle, the state transitions and the button routing are all testable
without a device — see `test/plugin_lifecycle_test.dart` for the fake-plugin
pattern.
