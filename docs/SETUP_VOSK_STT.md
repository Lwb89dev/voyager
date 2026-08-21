# Speech recognition (Vosk)

**Status: not implemented.** The interface exists, the model path is wired
through settings, and the app degrades cleanly — but `VoskSttWrapper.listen`
recognises nothing and says so rather than returning a plausible-looking empty
result.

Voyager currently speaks and does not listen. Every voice action is reachable
from a physical button or the touchscreen.

## Why it is not shipped half-finished

Vosk's small models are around 85% accurate in a moving car with road noise.
That is a genuinely useful feature and a terrible thing to ship prematurely,
because the missing 15% does not land as "sorry, I did not understand" — it
lands as the car doing something the driver never asked for.

The pieces that guard against that are already in place: a closed vocabulary of
about a dozen commands (`VoiceCommandParser`), and a confidence floor of 0.6
below which a recognised command is downgraded to "not understood" rather than
executed. Both are covered by tests.

## What remains

The part that cannot be written in Dart:

1. Cross-compile `libvosk.so` for `arm64-v8a` and `armeabi-v7a`.
2. Bundle it through `android/app/src/main/jniLibs`.
3. Bind it with `dart:ffi`: a recogniser handle, a 16 kHz mono PCM feed, and a
   JSON result pulled out at the end of each utterance.
4. Run audio capture in an isolate. Feeding 16 000 samples a second through the
   platform thread competes with map rendering for the same frame budget.
5. Flip `_nativeBound` in `lib/plugins/voice/vosk_stt_wrapper.dart`.

Models come from <https://alphacephei.com/vosk/models>. The small ones are
around 50 MB per language; the large ones are far more accurate and far too
slow on phone-class hardware for real-time use.

## Commands the parser already understands

English and Italian, matched as keywords rather than parsed as language:

| Intent | English | Italian |
| --- | --- | --- |
| Next track | "next track", "skip" | "brano successivo", "salta" |
| Previous track | "previous track", "go back" | "brano precedente" |
| Play | "play music", "play something" | "metti la musica" |
| Pause | "pause", "stop the music" | "pausa", "ferma la musica" |
| Show map | "show map", "navigation" | "mostra la mappa" |
| Weather | "weather", "forecast" | "meteo", "previsioni" |

Routing, telephony and message reading are parsed but answer "I cannot do that
yet" — they need control surfaces that Roadstr and the phone bridge do not
expose. Saying so is better than silently doing nothing.
