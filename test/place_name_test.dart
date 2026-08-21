import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:voyager/plugins/weather/place_name_service.dart';
import 'package:voyager/utils/bounded_client.dart';

void main() {
  group('townFrom', () {
    test('prefers the city over the region containing it', () {
      // Nominatim fills several levels at once. Reading the region first is how
      // a weather pane ends up saying "Lazio" when the driver is in Rome.
      final town = PlaceNameService.townFrom({
        'address': {'road': 'Via Roma', 'city': 'Roma', 'state': 'Lazio'},
      });
      expect(town, 'Roma');
    });

    test('never returns a street or a house number', () {
      final town = PlaceNameService.townFrom({
        'address': {'house_number': '14', 'road': 'Via Roma', 'town': 'Tivoli'},
      });
      expect(town, 'Tivoli');
    });

    test('falls back down the hierarchy for a village', () {
      final town = PlaceNameService.townFrom({
        'address': {'village': 'Norcia', 'county': 'Perugia'},
      });
      expect(town, 'Norcia');
    });

    test('accepts a county when nothing more specific exists', () {
      // Rural coordinates genuinely have no populated place; a county is then
      // the only true answer.
      final town = PlaceNameService.townFrom({
        'address': {'county': 'Perugia', 'country': 'Italia'},
      });
      expect(town, 'Perugia');
    });

    test('returns null rather than a country', () {
      expect(
        PlaceNameService.townFrom({'address': {'country': 'Italia'}}),
        isNull,
      );
    });

    test('survives a response with no address at all', () {
      expect(PlaceNameService.townFrom({'error': 'Unable to geocode'}), isNull);
    });

    test('ignores an empty string', () {
      final town = PlaceNameService.townFrom({
        'address': {'city': '   ', 'town': 'Assisi'},
      });
      expect(town, 'Assisi');
    });
  });

  group('townAt', () {
    late List<http.Request> seen;

    PlaceNameService serviceReturning(Map<String, dynamic> body) {
      seen = [];
      return PlaceNameService(
        httpClient: BoundedClient(
          client: MockClient((request) async {
            seen.add(request);
            return http.Response(jsonEncode(body), 200);
          }),
        ),
      );
    }

    test('asks for city-level detail, not an address', () async {
      await serviceReturning({'address': {'city': 'Roma'}})
          .townAt(const LatLng(41.9028, 12.4964));
      expect(seen.single.url.queryParameters['zoom'], '10');
    });

    test('rounds the coordinates before sending them', () async {
      // Two decimals is ~1.1 km. Identical answer at town scale, and it denies
      // Nominatim a street-level fix on what is often the driver's home.
      await serviceReturning({'address': {'city': 'Roma'}})
          .townAt(const LatLng(41.902782, 12.496366));
      final query = seen.single.url.queryParameters;
      expect(query['lat'], '41.90');
      expect(query['lon'], '12.50');
    });

    test('identifies itself, as Nominatim requires', () async {
      await serviceReturning({'address': {'city': 'Roma'}})
          .townAt(const LatLng(41.9, 12.5));
      expect(seen.single.headers['User-Agent'], contains('Voyager'));
    });
  });
}
