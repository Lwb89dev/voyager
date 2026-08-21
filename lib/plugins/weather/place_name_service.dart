import 'package:latlong2/latlong.dart';

import '../../utils/bounded_client.dart';

/// Turns coordinates into the name of a town.
///
/// Roadstr's `RoutingService.reverseGeocodeLabel` was the obvious thing to
/// reuse and is the wrong tool here: it answers at street level, because it
/// exists to label a destination pin — "Via Roma 14" is exactly right for that
/// and useless as a weather dateline. Weather is a regional quantity, so the
/// only honest label for it is the town it was measured in.
///
/// Nominatim's `zoom` parameter does this directly: zoom 10 asks for a
/// city-level match rather than an address, so no parsing of a comma-separated
/// display string is involved.
class PlaceNameService {
  final BoundedClient _http;

  PlaceNameService({BoundedClient? httpClient})
      : _http = httpClient ?? BoundedClient();

  /// City-level detail. Lower zooms give the county, higher ones the street.
  static const int cityZoom = 10;

  /// Nominatim's usage policy requires an identifying User-Agent, and blocks
  /// clients that omit it.
  static const String userAgent = 'Voyager/0.1.0';

  /// The town at [position], or null when the lookup failed or the coordinates
  /// are somewhere with no populated place — mid-ocean, mid-desert.
  ///
  /// The coordinates are rounded to two decimals, roughly 1.1 km, before being
  /// sent. That is the same rounding Roadstr applies to its weather query, and
  /// for the same reason: the answer is identical at town scale, and it denies
  /// Nominatim a street-level fix on a position that is very often someone's
  /// home. Note this is the opposite trade from a destination lookup, where the
  /// exact street *is* the answer being asked for.
  Future<String?> townAt(LatLng position) async {
    final uri = Uri.parse('https://nominatim.openstreetmap.org/reverse').replace(
      queryParameters: {
        'lat': position.latitude.toStringAsFixed(2),
        'lon': position.longitude.toStringAsFixed(2),
        'format': 'json',
        'addressdetails': '1',
        'zoom': '$cityZoom',
      },
    );

    final json = await _http.getJson(
      uri,
      headers: {'User-Agent': userAgent},
      maxBytes: 256 * 1024,
    );
    return townFrom(json);
  }

  /// Extracts the town from a Nominatim reverse response.
  ///
  /// The order matters and is not arbitrary. Nominatim fills whichever of these
  /// keys the local administrative hierarchy uses, and several are often
  /// present at once: an address inside Rome carries both `city` and `state`.
  /// Reading them most-specific first is what returns "Roma" instead of
  /// "Lazio". The last two are a floor for genuinely rural coordinates, where
  /// a county or region is the only name that exists.
  static String? townFrom(Map<String, dynamic> json) {
    final address = json['address'];
    if (address is! Map) return null;

    const keys = [
      'city',
      'town',
      'village',
      'municipality',
      'city_district',
      'county',
      'state',
    ];
    for (final key in keys) {
      final value = address[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  void close() => _http.close();
}
