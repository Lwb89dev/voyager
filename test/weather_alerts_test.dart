import 'package:flutter_test/flutter_test.dart';
import 'package:roadstr/services/weather_service.dart';
import 'package:voyager/plugins/weather/weather_alerts.dart';

WeatherData weather({required int code, double wind = 5}) =>
    WeatherData(tempC: 4, code: code, windKmh: wind);

void main() {
  group('WeatherAlerts.assess', () {
    test('clear skies are not a hazard', () {
      expect(WeatherAlerts.assess(weather(code: 0)), DrivingHazard.none);
    });

    test('freezing rain is severe', () {
      // 66 and 67 ice the road while it still looks merely wet — the single
      // most dangerous pair of codes in the WMO table.
      expect(WeatherAlerts.assess(weather(code: 66)), DrivingHazard.severe);
      expect(WeatherAlerts.assess(weather(code: 67)), DrivingHazard.severe);
    });

    test('hail-bearing thunderstorms are severe', () {
      expect(WeatherAlerts.assess(weather(code: 96)), DrivingHazard.severe);
    });

    test('ordinary rain is caution, not severe', () {
      expect(WeatherAlerts.assess(weather(code: 61)), DrivingHazard.caution);
    });

    test('fog is caution', () {
      expect(WeatherAlerts.assess(weather(code: 45)), DrivingHazard.caution);
    });

    test('gale-force wind is severe even under a clear sky', () {
      expect(
        WeatherAlerts.assess(weather(code: 0, wind: 80)),
        DrivingHazard.severe,
      );
    });

    test('a stiff breeze below the gale threshold is not', () {
      expect(
        WeatherAlerts.assess(weather(code: 0, wind: 61)),
        DrivingHazard.none,
      );
    });
  });

  group('WeatherAlerts.announcement', () {
    test('says nothing when there is nothing to say', () {
      expect(
        WeatherAlerts.announcement(weather(code: 0), italian: false),
        isNull,
      );
    });

    test('names wind specifically when wind is the reason', () {
      final message = WeatherAlerts.announcement(
        weather(code: 0, wind: 80),
        italian: false,
      );
      expect(message, contains('wind'));
    });

    test('speaks Italian when asked', () {
      final message =
          WeatherAlerts.announcement(weather(code: 66), italian: true);
      expect(message, contains('ghiaccio'));
    });
  });
}
