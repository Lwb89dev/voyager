import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:roadstr/services/sun_calc.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../config/automotive_config.dart';
import '../utils/logger_automotive.dart';

/// Screen management: keeping it awake, and dimming it after dark.
///
/// Dimming is done by painting a translucent black scrim over the app rather
/// than by setting the system brightness. That is a deliberate trade: changing
/// system brightness needs another platform plugin, leaves the device dimmed
/// after Voyager exits, and fights with whatever automatic brightness the ROM
/// is doing. A scrim affects only Voyager's own pixels, disappears the moment
/// the app does, and is exactly as effective at the thing that matters — not
/// throwing a bright rectangle onto the windscreen at night.
///
/// Day and night come from the sun's position, computed on the device from the
/// last known coordinates using Roadstr's [SunCalc]. No light sensor, because
/// a device on a dashboard mount is as likely to be in its own shadow as in
/// the sun, and no network call, because the sun's position is arithmetic.
class AutomotiveUiService extends ChangeNotifier {
  bool _keepAwake = true;
  bool _nightDimming = true;
  bool _isNight = false;
  LatLng? _position;
  Timer? _timer;

  bool get keepAwake => _keepAwake;
  bool get nightDimming => _nightDimming;
  bool get isNight => _isNight;

  /// Opacity of the scrim to paint over the whole app, 0 when it is daytime or
  /// dimming is off.
  double get dimOpacity {
    if (!_nightDimming || !_isNight) return 0;
    return 1 - AutomotiveConfig.nightBrightness;
  }

  Future<void> initialize({bool keepAwake = true, bool nightDimming = true}) async {
    _nightDimming = nightDimming;
    await setKeepAwake(keepAwake);
    // Re-evaluate every quarter hour: sunset moves by at most a couple of
    // minutes a day, so anything faster is a wake-up for nothing.
    _timer = Timer.periodic(const Duration(minutes: 15), (_) => _evaluate());
  }

  Future<void> setKeepAwake(bool value) async {
    _keepAwake = value;
    try {
      await WakelockPlus.toggle(enable: value);
    } catch (error) {
      AutomotiveLogger.warn('UI', 'wakelock unavailable: $error');
    }
    notifyListeners();
  }

  void setNightDimming(bool value) {
    _nightDimming = value;
    _evaluate();
  }

  /// Feeds the service a position. Called by the navigation plugin as fixes
  /// arrive; without one, [isNight] stays false and the screen is never
  /// dimmed, which is the safe default.
  void updatePosition(LatLng position) {
    _position = position;
    _evaluate();
  }

  void _evaluate() {
    final position = _position;
    if (position == null) return;
    final now = DateTime.now().toUtc();
    final times = SunCalc.sunTimes(position.latitude, position.longitude, now);
    final night = _isAfterDark(now, times);
    if (night == _isNight) return;
    _isNight = night;
    notifyListeners();
  }

  /// Polar day and polar night both report a null rise or set. Treating a
  /// missing sunset as "never dark" is right above the Arctic circle in
  /// summer, and treating a missing sunrise as "always dark" is right there in
  /// winter — which is what these two fallbacks do.
  static bool _isAfterDark(
    DateTime now,
    ({DateTime? rise, DateTime? set}) times,
  ) {
    final rise = times.rise;
    final set = times.set;
    if (set == null) return false;
    if (rise == null) return true;
    return now.isAfter(set) || now.isBefore(rise);
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(WakelockPlus.disable());
    super.dispose();
  }
}
