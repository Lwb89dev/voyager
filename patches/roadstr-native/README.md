# Roadstr native integration patches

These patches are applied by `tools/update_roadstr.sh` to the generated `.roadstr-native` mirror. They are not a second navigation implementation and must stay small enough to propose as general upstream modularization changes.

- `0001-reusable-native-library.patch`: exposes the existing Compose activity/runtime for embedding and moves the unchanged guidance holder into the shared Flutter-free source graph. Voyager's separate AAR build includes the production navigation services. Default upstream application behavior remains unchanged.
- `0002-voice-embedding.patch`: exposes the existing speech gateways to the host activity without introducing a second speech engine.
- `0003-brightness-embedding-policy.patch`: adds an optional host-provided maximum screen-brightness policy. Upstream remains at 1.0 by default; Voyager supplies 0.75 and applies it to the runtime and settings slider.

Rebase against the exact pin in `roadstr-integration/upstream.properties`. Never skip a failed hunk or edit the generated mirror as a substitute for updating the patch.
