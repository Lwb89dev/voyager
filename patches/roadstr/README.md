# Voyager's patches to Roadstr

Voyager consumes Roadstr as a source dependency and needs a few UI changes that
only make sense inside Voyager: a full-width band or a bottom sheet that is
right for a phone in the hand collides with Voyager's own floating chrome,
which is present in every orientation. These patches are how those changes are
kept without forking, and without ever writing into the upstream checkout.

`tools/prepare_roadstr.sh` mirrors `../roadstr` into `.roadstr/` and applies
everything here, in filename order. The pubspec's path dependency points at the
mirror. Run it after every `git pull` in Roadstr — upstream fixes arrive on the
next build, and these patches ride on top.

## Rules

- **Never edit `.roadstr/` by hand.** The next run of the script overwrites it.
- **Keep patches small and cosmetic.** Anything that changes routing, speed
  limits, ZTL handling or Nostr behaviour belongs upstream in Roadstr, not
  here — that is the part Voyager explicitly does not want to maintain twice.
- **A failing patch fails the build.** That is deliberate. It means upstream
  moved under it and the change needs re-examining.

## Design: always compact, not orientation-gated

An earlier version of these patches switched on `MediaQuery` orientation —
full-size, full-width in portrait; compact and floating in landscape — because
Voyager's own dashboard originally docked its chrome in a `Column` in portrait,
giving Roadstr's on-map controls an untouched strip below the map. Voyager's
dashboard now floats its chrome over a full-bleed map in *every* orientation
(see `lib/widgets/automotive_dashboard.dart`), so Roadstr's own bottom bar, nav
panel, place card and route sheet share the same physical screen as that chrome
regardless of how the device is held. The patches were rewritten to apply the
compact, floating form unconditionally rather than re-deriving a second set of
"portrait-safe" positions.

**Known side effect:** forcing `land`/`voyagerLandscape` to a compile-time
`true` leaves the original portrait-sized branches of several `x ? a : b`
expressions unreachable. `dart analyze` run directly against `.roadstr/`
reports these as `dead_code` warnings — intentional, and confined to the
vendored mirror. `flutter analyze` from the Voyager project root does not
descend into a path dependency's own sources, so these never appear in
Voyager's own analyzer output.

## Rebasing a patch that stopped applying

```bash
cp ../roadstr/lib/screens/map_screen.dart /tmp/orig.dart
cp /tmp/orig.dart /tmp/patched.dart
$EDITOR /tmp/patched.dart                       # redo the change by hand
cd /tmp && diff -u orig.dart patched.dart > /tmp/new.patch
# fix the paths in the header to a/lib/... and b/lib/..., then replace the file
```

## Current patches

| Patch | What it does | Why |
| --- | --- | --- |
| `0001-voyager-map-screen.patch` | Caps the search bar and its results list to 560 dp; positions the GPS cursor from the real viewport height instead of a hard-coded 800 px; keeps the current-street label, the ZTL/arrival banners and the speed-limit sign clear of Voyager's own chrome; routes the nav panel, place card, route-preview and transit panels through the host's own reserved height (`padding.bottom`) rather than the system's alone. The left/right FAB columns and `MapBottomBar` instead read `voyagerSideInset`: the system inset in landscape (level with Voyager's chrome, sharing its row) and the host's reserved height in portrait (stacked above it). | Full-width UI compresses to nothing useful once Voyager's chrome shares the screen; the 800 px cursor math only ever matched a portrait phone. `MapBottomBar` and the corner FABs were first pinned to the system inset alone, on the assumption that Voyager's pill never reaches the corners they live in — true only as long as that pill stays narrower than the screen, which stopped holding in portrait once the plugin count and display cutout made it wide enough to invade the corner. Stacking everything above the chrome fixed the overlap but also broke the landscape layout, where the pill is narrow enough that the corners *are* free at its own height — a bar or FAB column stacked a full chrome-height above it there just floats disconnected in the middle of the screen instead of sharing Voyager's row the way it always used to. `voyagerSideInset` keeps both: stacked where sharing the row would overlap, level where it would not. |
| `0002-voyager-map-chrome.patch` | `MapBottomBar` (Notifiche / Profilo / Menu) is always the compact, icon-only, bottom-left form. | The full-width version is a band roughly a fifth of the screen tall, and on any screen where Voyager's own chrome is also present it either overlaps it or gets overlapped. |
| `0003-voyager-nav-hud.patch` | `NavInstruction` and `NavPanel` are always the compact floating card. | Same reasoning — the full-size forms were sized for a phone that owns the whole screen, which is never true here. |
| `0004-voyager-route-panels.patch` | The route-choice panel is always the compact bar: itineraries as chips, a close target, a "start navigation" target — no drag handle, transport-mode picker, avoid-tolls toggle or weather line. | Those are pre-trip settings; the panel's job in Voyager is the one decision left at the wheel — which route, then go. |
| `0005-voyager-place-info-panel.patch` | The place-info sheet is always the compact card: name, one line of address, close, "navigate here". | The full sheet is a place *browser* (photo, Wikipedia summary, opening hours); the right shape for deciding where to go, the wrong one once that decision is made. |
| `0006-voyager-profile-login-fix.patch` | Sets `_targetPubHex` in both `_loginWithAmber` and `_loginWithNsec`, alongside `_npub`/`_flavor`. | **Not a Voyager-specific change** — this is a genuine bug in Roadstr's own `profile_screen.dart`: `_loggedIn` and `_isOwnProfile` both read `_targetPubHex`, which neither login method ever set, so a successful login (Amber or nsec) left the profile screen reading as logged out. Patched here only because Voyager needed it working now; the same one-line fix belongs in Roadstr's own repo, at which point this patch should stop applying (cleanly) and can be deleted. |
