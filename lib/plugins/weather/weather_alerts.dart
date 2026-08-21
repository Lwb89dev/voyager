import 'package:roadstr/services/weather_service.dart' as roadstr;

/// How much a given weather condition should change driving behaviour.
enum DrivingHazard {
  none,

  /// Worth knowing about: wet roads, reduced visibility.
  caution,

  /// Worth saying out loud: ice, heavy snow, thunderstorms, gale-force wind.
  severe,
}

/// Turns raw WMO weather codes into something worth telling a driver.
///
/// Open-Meteo has no severe-weather alert feed that is free of a national
/// warning service, so Voyager does not pretend to issue warnings. What it can
/// honestly do is read the condition code it already has and say when the road
/// is likely to behave differently — which is the part a driver actually acts
/// on.
///
/// The announcement is spoken once per condition change, never repeated on a
/// timer. A voice that says "icy conditions" every ten minutes for two hours
/// gets tuned out, and then it is not a warning any more.
class WeatherAlerts {
  const WeatherAlerts._();

  /// Wind speed at which a high-sided vehicle is genuinely affected. Roughly
  /// Beaufort 8 — the threshold at which bridges start posting warnings.
  static const double galeKmh = 62;

  static DrivingHazard assess(roadstr.WeatherData data) {
    if (_isSevere(data.code) || data.windKmh >= galeKmh) {
      return DrivingHazard.severe;
    }
    if (_isCaution(data.code)) return DrivingHazard.caution;
    return DrivingHazard.none;
  }

  /// Freezing drizzle and freezing rain (56, 57, 66, 67) are the two most
  /// dangerous codes in the whole WMO table: the road ices while looking
  /// merely wet. Thunderstorms with hail (96, 99) and heavy snow (75, 86)
  /// join them.
  static bool _isSevere(int code) =>
      code == 56 ||
      code == 57 ||
      code == 66 ||
      code == 67 ||
      code == 75 ||
      code == 86 ||
      code == 95 ||
      code == 96 ||
      code == 99;

  /// Fog (45, 48), any rain or drizzle, and lighter snow: grip and visibility
  /// are reduced but the road is not treacherous.
  static bool _isCaution(int code) =>
      code == 45 ||
      code == 48 ||
      (code >= 51 && code <= 65) ||
      (code >= 71 && code <= 77) ||
      (code >= 80 && code <= 85);

  /// A short spoken phrase, or null when there is nothing worth saying.
  ///
  /// Deliberately terse. A driver hearing this is already driving; the
  /// sentence has to land in the gap between two navigation instructions.
  static String? announcement(roadstr.WeatherData data, {required bool italian}) {
    switch (assess(data)) {
      case DrivingHazard.severe:
        if (data.windKmh >= galeKmh && !_isSevere(data.code)) {
          return italian ? 'Vento forte. Attenzione.' : 'Strong wind. Take care.';
        }
        return italian
            ? 'Condizioni pericolose: possibile ghiaccio o grandine.'
            : 'Hazardous conditions: ice or hail possible.';
      case DrivingHazard.caution:
        return italian
            ? 'Fondo bagnato o visibilità ridotta.'
            : 'Wet road or reduced visibility.';
      case DrivingHazard.none:
        return null;
    }
  }
}
