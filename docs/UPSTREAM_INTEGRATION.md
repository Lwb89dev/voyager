# Roadstr upstream integration

## Integrated revision

Voyager integrates Roadstr **1.2.3**, commit `043abd770ce6d3e6ac83be08dd727782b44ccc6d`. At the initial audit, upstream `main` was `9cb5352905358be586bdfa701efc296469f63a47` and differed from the tag only in F-Droid metadata. The stable production commit, not moving `main`, is the build input.

`roadstr-integration/upstream.properties` is the authoritative pin. The upstream mirror is `.roadstr-native/`, which is generated and gitignored.

## Integration shape

The local `:roadstr-integration` Android library build points at the pinned `.roadstr-native` source trees. It compiles Roadstr's real native `core`, `feature`, and `service` sources, resources, assets, MapLibre renderer, voice runtime, offline package support, and application gateways. Voyager adds the production navigation/foreground runtime from the same pinned revision. Roadstr's own application build files are not modified.

Small patches under `patches/roadstr-native/` provide only:

1. public/protected embedding hooks for the existing activity and runtime;
2. inclusion of the production guidance runtime in the Flutter-free source graph;
3. API visibility adjustments required for reuse;
4. an optional host-provided screen-brightness ceiling, defaulting to upstream's existing behavior and set to 0.75 by Voyager.

They do not replace routing, navigation, protocols, search, storage, or feature logic. Any broader modularization should be proposed upstream independently.

## Updating

Run:

```bash
tools/update_roadstr.sh
```

The updater:

1. reads the repository URL and full commit SHA from the pin;
2. creates or resets only the marked, generated mirror;
3. fetches and checks out that exact revision;
4. verifies the resulting `HEAD` byte for byte;
5. checks and applies every integration patch, failing loudly on drift;
6. runs Roadstr integration compilation, Voyager JVM tests, and the debug APK build.

Do not edit `.roadstr-native/` manually. Changes intended for upstream must be isolated as commits/patches and reviewed separately. Do not move the pin until the complete update run is green and the parity matrix has been reviewed for upstream changes.

For a quick local verification without changing the pin, use the same script; reproducibility comes from the SHA, not from a branch name.

## Compatibility failure policy

A patch conflict, removed public type, changed storage contract, resource failure, test failure, or APK failure blocks the update. Never skip a patch, exclude a failing feature, or silently fall back to an older source file to make the build green.

The CI upstream-compatibility workflow performs the same clean mirror/patch/build sequence. Release workflows must use the checked-in pin and must not fetch `main` opportunistically.

## Upstream documentation caveat

Some files under `docs/kotlin-rewrite/` preserve historical milestones and contradict the current production README/source. Audits must inspect the selected source revision and release changelog. Documentation alone is not runtime evidence.
