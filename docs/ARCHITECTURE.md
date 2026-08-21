# Voyager architecture

Voyager is an automotive dashboard: one app that a driver can use at a glance,
combining navigation, music, weather, speech and telephony. It is built on
[Roadstr](https://github.com/roadstrapp/roadstr-app) and shares its principles —
no accounts, no telemetry, no proprietary dependencies.

## The one big decision: Roadstr as a dependency, not a fork

Voyager consumes Roadstr as a Dart path dependency — but not the upstream
checkout directly:

```yaml
dependencies:
  roadstr:
    path: .roadstr        # produced by tools/prepare_roadstr.sh
```

`tools/prepare_roadstr.sh` mirrors `../roadstr` into `.roadstr/` (gitignored),
applies the patches in `patches/roadstr/`, and copies out the runtime assets and
native libraries. Upstream fixes arrive on the next build; Voyager's UI tweaks
ride on top; the upstream checkout is only ever read.

This exists because two requirements pull in opposite directions. Voyager must
track Roadstr, since routing, speed cameras and ZTL handling are exactly what
nobody wants to maintain twice. And Voyager must change Roadstr's map chrome,
because a layout designed for a phone in the hand wastes most of a landscape
dashboard. A fork gives the second and loses the first; editing the upstream
checkout gives both and destroys someone's working tree.

A patch that no longer applies **fails the build**. That is the point: it means
upstream moved underneath a UI change, which is worth looking at now rather than
discovering as a rendering bug three builds later.

Patches are kept small and cosmetic. Anything touching routing, limits, zones or
Nostr belongs upstream in Roadstr.

`RoadstrPlugin` mounts Roadstr's `MapScreen` directly, and Voyager also reuses
its `WeatherService`, `SunCalc` and Kokoro TTS engine. Nothing in the Roadstr
checkout is modified.

The alternative — copying the navigation code into Voyager — was rejected
because navigation is the part that must not rot. Roadstr's routing, speed
cameras, ZTL warnings and Nostr road reports are actively maintained; a fork
would start diverging on day one, and the driver would be the one to find out.

Two consequences follow, and both are load-bearing:

- **Version constraints are inherited.** `flutter_map 8.x`, `latlong2 0.10`,
  `geolocator 14`, `just_audio 0.10`, `web_socket_channel 2.x` — Voyager pins
  the same lines Roadstr resolves. A mismatch on `latlong2` alone would hand
  `MapScreen` and Voyager two incompatible `LatLng` types.
- **`dependency_overrides` must be repeated.** Roadstr overrides
  `geolocator_android` with a vendored fork that has Google Play Services
  stripped out. Overrides only apply from the root package, so Voyager repeats
  the override pointing at the same directory. Drop it and the proprietary blob
  comes straight back into the APK.

Roadstr's settings live in a Hive box named `settings`, opened AES-encrypted
with a key in the Android Keystore. Voyager opens the same box the same way, so
Roadstr's services find their configuration. Voyager's own keys are prefixed
`voyager_`.

## Layout: two of them, and why

The dashboard has a portrait layout and a landscape layout, and they are not
the same widget tree.

Portrait docks the chrome in a `Column` under the plugin. That costs about
145 dp of height — roughly 15% of the screen, which is affordable.

Landscape is how the app is actually used, and there the same 145 dp is 35% of
the screen, taken from the map. So landscape gives the plugin the whole screen
and floats the chrome over it as a pill that collapses to a tab. Two further
details make it work:

- `FullscreenPluginView` takes a `bottomInset` so a plugin's own overlay (the
  music strip, an incoming call) sits above the chrome.
- The plugin subtree is wrapped in a `MediaQuery` whose `viewPadding.bottom` is
  inflated by the chrome's height. Every bottom-anchored control in Roadstr's
  `MapScreen` is positioned as `something + viewPadding.bottom`, so this lifts
  all of them clear at once — no patch, and it keeps working when Roadstr adds
  another button.

## Theming: two apps, two answers

Voyager's own chrome is dark, always. A bright panel in a windscreen mount
reflects onto the glass, and no preference changes that.

The map is a different case, and an earlier version of this got it wrong by
pinning Roadstr to a dark theme. Roadstr ships eight themes and an automatic
sunset switch; the map is the thing being looked at rather than furniture
around it, and which theme suits a given car at a given hour is not Voyager's
call. `RoadstrPlugin` now scopes Roadstr's own `ThemeProvider.effectiveThemeData`
around the map, and Voyager's settings expose the picker and the auto-dark
switch, labelled from Roadstr's own localisations so they read correctly in all
27 languages it supports.

The root `MaterialApp` theme carries whichever Roadstr palette is current as a
`ThemeExtension`. That is not cosmetic: Roadstr's profile, notifications and
settings screens are pushed onto the root navigator, so they build outside the
scoped theme, and `RoadstrColors.of(context)` dereferences the extension with
`!` — without it they crash before painting.

## Layers

```
main.dart
  ├─ opens the encrypted Hive settings box
  ├─ builds services      (PluginService, gestures, UI/dimming)
  ├─ registers plugins    (navigation, music, weather, voice, phone)
  └─ runApp → VoyagerApp → _StartupGate → AutomotiveDashboard

AutomotiveDashboard
  ├─ FullscreenPluginView   — the active plugin, plus any overlay
  ├─ AutomotiveSystemBar    — clock and one status line
  └─ AutomotiveButtonBar    — one button per plugin, plus Settings
```

The dashboard holds no feature state. Everything it draws comes from
`PluginService`, which is what keeps adding a sixth plugin from being a change
to the dashboard.

## The plugin contract

`BasePlugin` (`lib/plugins/base_plugin.dart`) is a `ChangeNotifier` with a
four-stage lifecycle: construct (cheap, synchronous), `initialize` (async, may
fail), run (`buildFullscreenView` / `buildOverlay`), `dispose`.

Three properties of the design matter:

**Manifests are separate from instances.** `PluginManifest` is available
immediately after construction, so the button bar renders on the first frame
even though the music server has not answered yet.

**Initialisation is concurrent and failure-isolated.** `initializeAll` runs
every plugin's `initialize` in parallel — they do not depend on each other, and
serialising a network round trip behind a 90 MB model load is visible startup
latency for nothing. A plugin that fails stays registered and reports through
`initializationError`; its pane shows the reason instead of a spinner.

**Views are kept alive.** `FullscreenPluginView` uses an `IndexedStack`, so
switching to music and back does not tear down the map, drop the tile cache or
re-acquire a GPS fix.

## Input routing

Hardware keys — the steering-wheel remote, AVRCP transport keys, the assistant
key — arrive through `AutomotiveGestureService` and are offered to the overlay
plugin first, then the active one. The overlay itself is derived from plugin
state (`wantsOverlay` plus `overlayPriority`), so the plugin holding the
driver's attention is also the one holding the buttons. Background plugins never see them, so music
cannot steal the wheel while it is not on screen.

The volume-key remap (wheel rocker → previous/next track) is opt-in. Swallowing
volume keys unconditionally would break volume control on a device that is not
in a car.

## Music: indexing and output

Local music is indexed through Android's **MediaStore**, over a method channel
(`MediaStoreBridge.kt`), not by walking directories from Dart. One query returns
every audio file with its tags already parsed; a filesystem walk had to open
files to learn anything beyond their names, and under scoped storage could not
reliably read the shared volume at all. Tracks are addressed by `content://`
URI, so ExoPlayer opens them through the resolver and Voyager needs no
filesystem access to the music itself.

The approach is Auxio's. Auxio itself could not be reused — it is a standalone
Kotlin application rather than a library, so there is no code to link against
even though its GPL-3 licence would have allowed it.

The **equalizer** is Android's own `AudioEffect`, attached to the player's
session by just_audio's `AudioPipeline`. No DSP in Voyager: the platform effect
runs below the decoder at no measurable cost. Presets are stored as fractions of
the device's own gain range, because that range differs per device — a preset in
absolute decibels would be a different curve on every phone.

## Where the boundaries are honest

- **Navigation is display-only from Voyager's side.** `MapScreen` exposes no
  controller, so Voyager can show it and sit next to it but cannot start a
  route programmatically. "Navigate home" as a voice command therefore does not
  exist yet, rather than existing and doing nothing.
- **Speech recognition is not implemented.** `VoskSttWrapper` has the
  interface, the model path and the degradation path; the native binding is
  missing and `isAvailable` returns false. See `docs/SETUP_VOSK_STT.md`.
- **There is no dialler.** Choosing a contact from a list while driving is
  among the worst things a touchscreen can ask for. Voyager answers, rejects
  and reads — nothing else.

## Testing

`flutter test` covers the parts that can be tested without a car: Subsonic
authentication, both music clients (through `MockClient`), the bounded HTTP
reader, plugin lifecycle and routing, the voice command parser, weather hazard
assessment, key mapping, and the automotive widgets' touch-target guarantees.

Playback, telephony and TTS need a device; they are exercised by hand against
the checklist in `docs/AUTOMOTIVE_UX_GUIDELINES.md`.
