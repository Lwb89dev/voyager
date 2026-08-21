import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:just_audio/just_audio.dart';

import '../../utils/logger_automotive.dart';

/// The output equalizer, and the settings that outlive a drive.
///
/// The equalizer itself is Android's own `AudioEffect`, attached to the
/// player's audio session by just_audio — there is no DSP here, and no reason
/// for any: the platform effect runs below the decoder, costs no measurable
/// CPU, and applies to whatever is playing without Voyager touching samples.
///
/// A car is the place this actually earns its keep. Cabin acoustics, road noise
/// that swallows everything below about 200 Hz at speed, and factory speakers
/// with their own ideas — the correction that makes a car sound right is not
/// the one that makes headphones sound right, which is why the gains are stored
/// per install rather than following the user around.
class EqualizerController extends ChangeNotifier {
  /// Band count is decided by the platform effect, not by Voyager — Android
  /// reports how many bands the device's equalizer has, typically five.
  final AndroidEqualizer equalizer;

  AndroidEqualizerParameters? _parameters;
  bool _enabled = false;
  bool _ready = false;

  EqualizerController({AndroidEqualizer? effect})
      : equalizer = effect ?? AndroidEqualizer();

  static const String _enabledKey = 'voyager_eq_enabled';
  static const String _gainsKey = 'voyager_eq_gains';
  static const String _presetKey = 'voyager_eq_preset';

  /// True once the platform has reported its band layout. Until then there is
  /// nothing to draw: the number of bands and their centre frequencies are the
  /// device's answer, not a guess Voyager can make in advance.
  bool get isReady => _ready;
  bool get isEnabled => _enabled;

  AndroidEqualizerParameters? get parameters => _parameters;
  List<AndroidEqualizerBand> get bands => _parameters?.bands ?? const [];

  double get minDecibels => _parameters?.minDecibels ?? -15;
  double get maxDecibels => _parameters?.maxDecibels ?? 15;

  String get presetName =>
      Hive.box('settings').get(_presetKey, defaultValue: EqualizerPreset.flat.name)
          as String;

  /// Attaches to the running player and restores the saved curve.
  ///
  /// Must be called after the player has loaded a source: the platform effect
  /// does not exist — and cannot report its bands — until there is an audio
  /// session to attach to. Calling it earlier simply never completes, which is
  /// why this is driven by the first successful load rather than by startup.
  Future<void> initialize() async {
    try {
      _parameters = await equalizer.parameters;
      _ready = true;

      final box = Hive.box('settings');
      _enabled = box.get(_enabledKey, defaultValue: false) as bool;
      await equalizer.setEnabled(_enabled);

      final saved = (box.get(_gainsKey) as List?)?.cast<double>();
      if (saved != null) {
        await _applyGains(saved);
      } else {
        // Nothing saved, so the bands hold whatever the device's equalizer was
        // last left at — which is not necessarily flat. Claiming "flat" while
        // the sliders sit at +3 makes the preset chips lie about what is being
        // heard, so the label follows the hardware rather than the other way
        // round.
        await _rememberPreset(_looksFlat ? EqualizerPreset.flat : EqualizerPreset.custom);
      }
    } catch (error) {
      // Some devices ship without a usable equalizer effect, and a few report
      // one that throws on attach. Music must keep playing regardless — the UI
      // shows the equalizer as unavailable instead of failing the plugin.
      AutomotiveLogger.warn('Equalizer', 'unavailable: $error');
      _ready = false;
    }
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    await Hive.box('settings').put(_enabledKey, value);
    try {
      await equalizer.setEnabled(value);
    } catch (error) {
      AutomotiveLogger.warn('Equalizer', 'enable failed: $error');
    }
    notifyListeners();
  }

  /// Sets one band's gain in decibels, clamped to what the device accepts.
  ///
  /// Persisted immediately rather than on some "done" action: this is dragged
  /// with a finger and has no natural end, and a curve that survives only if
  /// you leave the screen the right way is a curve people lose.
  Future<void> setGain(int bandIndex, double decibels) async {
    final band = bands.elementAtOrNull(bandIndex);
    if (band == null) return;

    await band.setGain(decibels.clamp(minDecibels, maxDecibels));
    await _persistGains();
    await _rememberPreset(EqualizerPreset.custom);
    notifyListeners();
  }

  /// Applies a named curve.
  ///
  /// Presets are expressed as fractions of the device's own range rather than
  /// absolute decibels, because that range differs per device — ±15 dB on one,
  /// ±12 on another. A preset written in absolute values would be a different
  /// shape on every phone.
  Future<void> applyPreset(EqualizerPreset preset) async {
    final shape = preset.shape(bands.length);
    final gains = [
      for (final fraction in shape)
        fraction >= 0 ? fraction * maxDecibels : fraction * -minDecibels,
    ];
    await _applyGains(gains);
    if (!_enabled && preset != EqualizerPreset.flat) await setEnabled(true);
    await _rememberPreset(preset);
    notifyListeners();
  }

  Future<void> _applyGains(List<double> gains) async {
    for (var i = 0; i < bands.length && i < gains.length; i++) {
      await bands[i].setGain(gains[i].clamp(minDecibels, maxDecibels));
    }
    await _persistGains();
  }

  /// True when every band is within half a decibel of zero — close enough that
  /// calling it flat is honest, and loose enough to survive a device that
  /// reports its neutral position as 0.2 dB.
  bool get _looksFlat => bands.every((band) => band.gain.abs() < 0.5);

  Future<void> _persistGains() => Hive.box('settings')
      .put(_gainsKey, [for (final band in bands) band.gain]);

  Future<void> _rememberPreset(EqualizerPreset preset) =>
      Hive.box('settings').put(_presetKey, preset.name);
}

/// Curves worth having in a car, as fractions of the device's gain range.
enum EqualizerPreset {
  /// Everything at zero. Not the same as "off": the effect stays attached,
  /// which makes A/B against a preset instant.
  flat,

  /// Lifts the bottom two bands. The one that matters at speed: road and wind
  /// noise mask low frequencies almost completely above about 100 km/h.
  roadNoise,

  /// Presence lift around the mid-high bands, bass trimmed. For spoken audio,
  /// where bass is only masking the consonants that carry the words.
  speech,

  /// The classic smile. Loud, fatiguing, and what people actually want on a
  /// long empty motorway.
  boost,

  /// V-shaped: lifted low end and lifted highs, mids pulled back. Derived from
  /// Winamp's classic "Rock" library preset (70/180/320/600/1000/3000/6000/
  /// 12000/14000/16000 Hz values 45/40/23/19/26/39/47/50/50/50 against its
  /// 33 = 0 dB centre) — a 25-year-old curve that has been carried into most
  /// consumer equalizers since, which is as close to a genre standard as this
  /// space has.
  rock,

  /// Forward low-mids and mids for vocals, highs pulled back to stay smooth.
  /// Same Winamp library, "Pop" preset (29/40/44/45/41/30/28/28/29/29).
  pop,

  /// Warm low end, a cleared-out 400 Hz to keep upright bass and piano from
  /// turning boxy, and a gentle lift above 8 kHz for cymbal and brass air —
  /// the shape recurring across jazz-EQ guides (e.g. Music Guy Mixing's and
  /// Outer Audio's jazz EQ write-ups), since no major preset library ships a
  /// dedicated "Jazz" curve to draw from directly.
  jazz,

  /// The guitarist's "scoop": bass and treble up, the 300 Hz-1 kHz body of a
  /// distorted mid-range pulled down so it does not turn to mud, presence
  /// raised back for attack. The scoop itself is a decades-old convention in
  /// metal amp/cab EQ; shaped here for listening rather than performing.
  metal,

  /// Sub-bass lifted hard for 808s and kick, a shallow dip around 100-150 Hz
  /// so that boost does not turn boomy, and a presence lift at 3-5 kHz for
  /// vocal snap and snare attack — the pattern shared by hip-hop EQ guides
  /// (Outer Audio, Cryo Mix's rap-vocal guide, Position Is Everything).
  rap,

  /// Whatever the user dragged the sliders to.
  custom;

  /// The gain shape, one value per band, each in -1..1.
  ///
  /// Interpolated across however many bands the device reports, so a five-band
  /// equalizer and a ten-band one get the same curve rather than the same
  /// numbers in the wrong places.
  List<double> shape(int bandCount) {
    if (bandCount <= 0) return const [];
    final anchors = switch (this) {
      EqualizerPreset.flat => const [0.0, 0.0, 0.0, 0.0, 0.0],
      EqualizerPreset.roadNoise => const [0.75, 0.5, 0.0, 0.1, 0.2],
      EqualizerPreset.speech => const [-0.4, -0.2, 0.3, 0.5, 0.2],
      EqualizerPreset.boost => const [0.6, 0.25, -0.2, 0.3, 0.55],
      EqualizerPreset.rock => const [0.35, -0.44, -0.26, 0.37, 0.63],
      EqualizerPreset.pop => const [0.06, 0.43, 0.30, -0.15, -0.16],
      EqualizerPreset.jazz => const [0.15, -0.20, 0.10, -0.05, 0.20],
      EqualizerPreset.metal => const [0.45, -0.35, -0.10, 0.35, 0.45],
      EqualizerPreset.rap => const [0.55, -0.15, 0.10, 0.30, 0.15],
      EqualizerPreset.custom => const [0.0, 0.0, 0.0, 0.0, 0.0],
    };
    return resample(anchors, bandCount);
  }

  /// Linear resampling of [anchors] onto [count] points, endpoints preserved.
  @visibleForTesting
  static List<double> resample(List<double> anchors, int count) {
    if (count == 1) return [anchors.first];
    return [
      for (var i = 0; i < count; i++)
        _interpolate(anchors, i / (count - 1) * (anchors.length - 1)),
    ];
  }

  static double _interpolate(List<double> anchors, double position) {
    final lower = position.floor();
    final upper = position.ceil();
    if (lower == upper) return anchors[lower];
    final t = position - lower;
    return anchors[lower] * (1 - t) + anchors[upper] * t;
  }
}
