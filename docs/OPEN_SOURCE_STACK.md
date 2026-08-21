# The open-source stack

Voyager has no proprietary dependencies, no accounts, no telemetry and no
first-party servers. This is the complete list of what it uses and what leaves
the device.

## Components

| Concern | Tool | Licence | Where it runs |
| --- | --- | --- | --- |
| Navigation | [Roadstr](https://github.com/roadstrapp/roadstr-app) | GPL v3 | On device |
| Routing | OSRM / GraphHopper | BSD / Apache 2.0 | Public or self-hosted |
| Maps | OpenStreetMap | ODbL | Tile servers |
| POIs, zones, cameras | Overpass API, Nominatim | ODbL | Public |
| Road reports | Nostr relays | — | Public relays |
| Music | Navidrome (Subsonic API) | GPL v3 | Your server |
| Music (alternative) | Jellyfin | GPL v2 | Your server |
| Music (offline) | Files on the device | — | On device |
| Playback | just_audio + audio_service | MIT | On device |
| Speech output | Kokoro (ONNX) | Apache 2.0 | On device |
| Speech output (fallback) | eSpeak-NG | GPL v3 | On device |
| Speech input | Vosk — *not implemented* | Apache 2.0 | On device |
| Weather | Open-Meteo | CC BY-SA | Public, keyless |
| Location | Android LocationManager | AOSP | On device |
| Telephony | Android Telecom | AOSP | On device |
| Storage | Hive (AES) + Android Keystore | Apache 2.0 | On device |
| State | provider | MIT | On device |

## What leaves the device

Everything below happens only when the corresponding feature is used.

| Goes to | What | When |
| --- | --- | --- |
| Routing provider | Origin, destination, waypoints | Computing a route |
| Tile servers | Tile coordinates, IP | Panning the map |
| Overpass / Nominatim | Search terms, coarse area | Searching, POIs, zones |
| Open-Meteo | Coordinates rounded to 2 dp | Weather refresh |
| Nostr relays | City-level geohash; exact position when *you* report | Road reports |
| Your music server | Track requests, salted auth token | Playback |

Nothing else. No analytics endpoint exists in the codebase —
`lib/utils/analytics_disabled.dart` is the only "analytics" entry point and
every method in it is a no-op.

## What never leaves the device

- Speech synthesis and (eventually) recognition — both run locally.
- Incoming calls and messages. Displayed, optionally spoken, then dropped.
  Never written to storage, never transmitted.
- Server credentials. AES-encrypted in Hive, key in the Android Keystore.
- Favourites and parked position — Roadstr's, and local unless you export them.

## Deliberate exclusions

**Google Play Services.** Excluded at the Gradle root
(`exclude(group = "com.google.android.gms")`), and location goes through
Android's own `LocationManager` via Roadstr's vendored `geolocator_android`
fork. Excluding it downstream would not be enough — the dependency belongs to
the plugin's own configurations.

**Firebase, Crashlytics, any crash reporter.** A crash report contains a stack
trace, and a stack trace from a navigation app contains coordinates.

**Cloud speech.** Sending a car's microphone to a server is the single worst
privacy trade in an automotive app.

## Licence

Voyager is GPL v3, inherited from Roadstr and eSpeak-NG. It is F-Droid
buildable: no proprietary dependencies, reproducible Gradle configuration, and
models downloaded at runtime rather than bundled.

## Cost

Nothing. Open-Meteo needs no key, OSM tiles are free within their usage policy,
Nostr relays are public. The only hardware anyone needs is whatever runs the
music server, and files on the device work without even that.
