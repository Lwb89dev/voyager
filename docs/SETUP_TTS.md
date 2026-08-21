# Speech output

> **This replaces the Piper TTS plan.** The original architecture called for
> Piper bound over FFI. Roadstr already ships a working neural TTS — Kokoro,
> running through `flutter_onnxruntime`, with an eSpeak-NG phonemizer,
> per-language voices, an LRU disk cache and a priority queue that stops a
> hazard alert cutting a turn instruction in half. Adding Piper would have
> meant a second ~60 MB model, a second FFI surface to maintain, and two
> different voices depending on which subsystem was speaking. Voyager uses
> Kokoro through `SpeechService`.

## The two engines

| | Kokoro | eSpeak-NG |
| --- | --- | --- |
| Quality | Natural, roughly 8/10 | Robotic, roughly 6/10 |
| Size | ~90 MB per voice | Already bundled |
| Latency | ~200 ms to first audio | Near-instant |
| Needs | A downloaded model | Nothing |

Both run entirely on the device. Neither sends a single byte anywhere — the
whole point of not using a cloud TTS is that a route's street names are exactly
what you do not want leaving the car.

## Installing a Kokoro voice

Voyager reads the same model Roadstr does. If you already use Roadstr with
Kokoro enabled, there is nothing to do.

Otherwise, download a voice from Roadstr's onboarding (Settings → Voice) or
place the model where Voyager expects it and set the path in Voyager's Hive
settings under `voyager_kokoro_model_path`.

Settings → Voice shows which engine is actually in use, so you never have to
guess whether the model was picked up.

## Falling back

There is no fallback logic in Voyager. `KokoroTtsService` falls back to
eSpeak-NG on its own when no model is installed, which is why `SpeechService`
is a thin adapter and not a dispatcher.

If speech fails entirely, navigation still works: every instruction is on
screen, and the app is silent rather than broken.

## Priorities

Two levels, and the distinction matters at speed:

- **Urgent** — turn instructions, hazards. Interrupts whatever ambient
  utterance is playing.
- **Normal** — messages read aloud, confirmations. Waits its turn.

Never mark a confirmation urgent. An instruction cut in half by "message from
Anna" is worse than no message at all.
