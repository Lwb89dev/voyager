import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:roadstr/services/weather_service.dart' as roadstr;

import '../../models/plugin_manifest.dart';
import '../../utils/logger_automotive.dart';
import '../../widgets/automotive_weather_display.dart';
import '../base_plugin.dart';
import 'place_name_service.dart';

/// Current conditions from Open-Meteo.
///
/// The network call itself is Roadstr's `WeatherService`, reused rather than
/// rewritten. That is not laziness: Roadstr rounds the coordinates to two
/// decimals before querying, because a destination is very often someone's
/// home and Open-Meteo's own grid is 1–11 km wide, so the rounding costs
/// nothing in accuracy and denies the API a street-level fix. Reimplementing
/// the call in Voyager would mean reimplementing that decision, and sooner or
/// later forgetting it.
class WeatherPlugin extends BasePlugin {
  /// How often conditions are refreshed while the plugin is on screen.
  ///
  /// Open-Meteo updates its model hourly, so polling faster returns identical
  /// bytes. Ten minutes keeps a long drive's forecast current without turning
  /// a free service into something Voyager abuses.
  static const Duration refreshInterval = Duration(minutes: 10);

  /// Distance the car must cover before a refresh is worth making regardless
  /// of the timer. Weather is a regional quantity; 25 km is roughly where it
  /// starts being a different one.
  static const double refreshDistanceMetres = 25000;

  /// Injectable so the tests can drive the parsing without a network call.
  final PlaceNameService places;

  WeatherPlugin({PlaceNameService? placeNameService})
      : places = placeNameService ?? PlaceNameService();

  roadstr.WeatherData? _data;
  String? _placeName;
  LatLng? _lastPosition;
  DateTime? _lastFetch;
  Timer? _timer;
  bool _ready = false;
  String? _error;

  roadstr.WeatherData? get data => _data;
  String? get error => _error;

  /// The town the reading is from — "Roma", not "Via Roma 14, Trastevere,
  /// Roma". A street address is the wrong grain for a regional measurement and
  /// takes two lines to say what one word says.
  ///
  /// Null until the lookup answers, or when it failed; the display omits the
  /// line rather than falling back to coordinates, which tell a driver nothing.
  String? get placeName => _placeName;

  @override
  PluginManifest get manifest => const PluginManifest(
        id: 'weather',
        label: 'Weather',
        icon: Icons.cloud_rounded,
        order: 4,
      );

  @override
  bool get isReady => _ready;

  @override
  Future<void> initialize() async {
    // Ready immediately: the plugin has nothing to acquire, and an unreachable
    // Open-Meteo should show "no data" inside a working screen rather than
    // disabling the button.
    _ready = true;
    notifyListeners();
    unawaited(refresh());
  }

  @override
  void onVisibilityChanged(bool visible) {
    _timer?.cancel();
    if (!visible) return;
    // Poll only while the pane is actually being looked at. A weather request
    // every ten minutes for a screen nobody has opened is pure battery and
    // radio wake-ups on a device that is already running a GPS.
    _timer = Timer.periodic(refreshInterval, (_) => refresh());
    unawaited(refresh());
  }

  /// Fetches conditions for the current position, unless a recent enough
  /// result is already in hand.
  Future<void> refresh({bool force = false}) async {
    try {
      final position = await _currentPosition();
      if (!force && !_needsRefresh(position)) return;
      final fetched = await roadstr.WeatherService.fetch(position);
      if (fetched == null) throw StateError('Open-Meteo returned no data');
      _data = fetched;
      _lastPosition = position;
      _lastFetch = DateTime.now();
      _error = null;
      // Painted as soon as the temperature is in hand; the place name arrives
      // a moment later and slots in. Waiting for both would leave the pane
      // empty for the length of two round trips instead of one.
      notifyListeners();
      await _resolvePlaceName(position);
    } catch (error) {
      AutomotiveLogger.warn('Weather', 'refresh failed: $error');
      _error = error.toString();
    }
    notifyListeners();
  }

  /// Names the town the reading came from.
  Future<void> _resolvePlaceName(LatLng position) async {
    try {
      _placeName = await places.townAt(position);
    } catch (error) {
      // A missing name costs one line of the display. Never let it discard a
      // temperature that was fetched successfully.
      AutomotiveLogger.warn('Weather', 'reverse geocode failed: $error');
      _placeName = null;
    }
    notifyListeners();
  }

  bool _needsRefresh(LatLng position) {
    final previous = _lastPosition;
    final at = _lastFetch;
    if (previous == null || at == null) return true;
    if (DateTime.now().difference(at) >= refreshInterval) return true;
    final moved = const Distance().as(LengthUnit.Meter, previous, position);
    return moved >= refreshDistanceMetres;
  }

  Future<LatLng> _currentPosition() async {
    // Medium accuracy on purpose: weather needs a town, not a lane, and a
    // high-accuracy fix spins the GPS up for no benefit.
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 15),
      ),
    );
    return LatLng(position.latitude, position.longitude);
  }

  @override
  Widget buildFullscreenView(BuildContext context) =>
      AutomotiveWeatherDisplay(plugin: this);

  @override
  void dispose() {
    _timer?.cancel();
    places.close();
    super.dispose();
  }
}
