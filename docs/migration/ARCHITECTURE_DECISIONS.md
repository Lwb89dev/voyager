# Native architecture decisions

## D-01: Consume Roadstr source as a pinned Gradle library

Decision: build Voyager as a native Android application and include Roadstr's Flutter-free `native-android/app` source tree as `:roadstr-integration`, at a reviewed tag/commit. Do not copy navigation, routing, Nostr, search, transit, offline, or Journey implementations into Voyager packages.

Roadstr 1.2.3 still publishes an application rather than library modules, but its production `android/app` already compiles the same native sources used by the Flutter-free road-test shell. Voyager owns a small AAR build configuration that points at those pinned source trees; it duplicates build inputs, not feature implementations. A public embedding surface is less invasive than a Voyager-specific fork. The integration patches are applied to a generated, gitignored upstream mirror and are independently reviewable.

Consequences:

- Upstream updates require patch/API checks and Voyager regression tests before the pin moves.
- Roadstr's package remains `app.roadstr` internally; only Voyager's application ID is `com.voyager.voyager`.
- Roadstr resources and native assets are packaged through the AAR. Its road-test launcher is removed from Voyager's merged manifest.
- A future upstream set of published library modules should replace this compatibility mode without changing Voyager feature boundaries.

Rejected: a permanent source fork, an independently maintained routing engine, embedding the Flutter MapScreen, and depending on an untested moving `main`.

## D-02: Keep one process-owned navigation runtime

Voyager's activity uses Roadstr's live store names and `NativeGuidanceRuntimeHolder`. The map composition remains mounted below other dashboard panes, so changing tabs does not destroy the renderer. Navigation sessions, GPS, voice guidance, rerouting, and foreground-service ownership remain Roadstr code.

Voyager may add an embedding API and automotive chrome, but must not add a second GPS stream or navigation session. Voice commands must call an explicit navigation controller API; opening the map is not navigation success.

## D-03: Voyager features are native modules outside Roadstr logic

Music, podcasts, weather, automotive phone integration, dashboard plugins, physical-key routing, and voice command dispatch live under Voyager packages. Media3 is the single music/podcast playback architecture. Network clients have strict deadlines and byte limits. Independent plugin initialization uses a `SupervisorJob`; feature failures do not cancel navigation.

Compose state is collected with lifecycle awareness. ViewModels/state holders own feature state. The native UI targets phones and tablets, not Android Auto/Automotive OS privileges.

## D-04: Migration is fail-closed and non-destructive

Preserve `com.voyager.voyager`, the existing external signing configuration, backup-disabled behavior, and a version code above 6. The legacy source remains untouched.

The old encrypted Hive and Flutter secure-storage formats require their real decoders. If a temporary headless Flutter reader is used, it is isolated in `legacy-migration`, has no UI or production feature role, and is removable after a proven native decoder exists. No encrypted bytes are blindly reinterpreted.

Migration order is `read -> validate -> stage -> commit -> reopen/verify -> mark complete`. Failure leaves legacy files intact and offers retry or an explicit informed skip. Imported Nostr private keys are never retained; Amber remains supported and an old nsec login migrates to logged-out with a notice.

## D-05: Privacy and permissions are runtime constraints

No Play Services, Firebase, analytics, ads, tracking, mandatory account, or cloud speech. Network security config limits cleartext to explicit user-configured LAN services rather than allowing arbitrary HTTP by default. Secrets use non-exportable Android Keystore keys and are excluded from logs.

Bluetooth is requested only for MeshCore pairing or a user-enabled integration. Microphone access is only during explicit listening. Telephony controls appear only when the platform role/permission and real action are both available. GPS speed is not represented as verified parked state.

## D-06: Evidence levels stay separate

JVM tests, Compose/instrumentation tests, live-network probes, signed-APK checks, and physical-device checks are different evidence. Upstream's device results do not validate Voyager. Experimental MeshCore, offline-STT phone behavior, real-radio compatibility, and all unexecuted device checks remain explicitly unverified.
