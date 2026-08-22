import 'package:flutter/material.dart';
import 'package:roadstr/l10n/app_localizations.dart';
import 'package:roadstr/services/weather_service.dart' as roadstr;
import 'package:roadstr/utils/units.dart';

import '../config/automotive_config.dart';
import '../plugins/weather/weather_alerts.dart';
import '../plugins/weather/weather_plugin.dart';
import '../theme/voyager_theme.dart';

/// °C→°F when the shared `imperialUnits` setting is on — the same Hive key
/// Roadstr's own [Units] reads for speed and distance, so one toggle (in
/// either app's settings) changes navigation and weather together rather
/// than being two preferences a user has to find twice.
String _formatTemp(double celsius) => Units.imperial
    ? '${(celsius * 9 / 5 + 32).round()}°F'
    : '${celsius.round()}°C';

String _formatWind(double kmh) =>
    '${Units.toDisplaySpeed(kmh).round()} ${Units.speedUnit}';

/// Current conditions, at a size that can be read in the time it takes to
/// check a mirror.
///
/// One temperature, one condition, one wind figure, and a hazard line when
/// there is one. No hourly strip and no five-day forecast: a driver does not
/// plan a week from the dashboard, and the extra rows would push the numbers
/// that matter down to a size that needs a real look.
class AutomotiveWeatherDisplay extends StatelessWidget {
  final WeatherPlugin plugin;

  const AutomotiveWeatherDisplay({super.key, required this.plugin});

  /// Below this, the full-size column (96 sp emoji, 84 sp temperature, place
  /// name, description, wind, and a possible hazard banner, each with its own
  /// gap) no longer fits. A landscape pane behind Voyager's chrome is where
  /// this actually binds — measured with a margin above that case rather than
  /// tuned to it exactly, same reasoning as the music player's own threshold.
  static const double _compactHeightThreshold = 340;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: plugin,
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) => _build(
          context,
          compact: constraints.maxHeight < _compactHeightThreshold,
        ),
      ),
    );
  }

  Widget _build(BuildContext context, {required bool compact}) {
    final data = plugin.data;
    if (data == null) return _Unavailable(error: plugin.error);

    // Roadstr's WeatherData already knows how to describe a WMO code in every
    // language Roadstr ships, so the description comes from there rather than
    // from a second table in Voyager that would drift out of step.
    final l = AppLocalizations.of(context);
    final hazard = WeatherAlerts.assess(data);
    final italian = Localizations.localeOf(context).languageCode == 'it';

    return ColoredBox(
      color: VoyagerColors.background,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AutomotiveConfig.sectionGap),
          child: compact
              ? _CompactConditions(
                  plugin: plugin,
                  data: data,
                  hazard: hazard,
                  message: WeatherAlerts.announcement(data, italian: italian),
                  l: l,
                )
              : _Conditions(
                  plugin: plugin,
                  data: data,
                  hazard: hazard,
                  message: WeatherAlerts.announcement(data, italian: italian),
                  l: l,
                ),
        ),
      ),
    );
  }
}

class _Conditions extends StatelessWidget {
  final WeatherPlugin plugin;
  final roadstr.WeatherData data;
  final DrivingHazard hazard;
  final String? message;
  final AppLocalizations l;

  const _Conditions({
    required this.plugin,
    required this.data,
    required this.hazard,
    required this.message,
    required this.l,
  });

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (plugin.placeName != null) ...[
            _PlaceName(name: plugin.placeName!),
            const SizedBox(height: 10),
          ],
          Text(data.emoji, style: const TextStyle(fontSize: 96)),
          const SizedBox(height: 8),
          Text(
            _formatTemp(data.tempC),
            style: const TextStyle(
              color: VoyagerColors.textPrimary,
              fontSize: 84,
              fontWeight: FontWeight.w300,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            data.localizedDescription(l),
            style: const TextStyle(
              color: VoyagerColors.textPrimary,
              fontSize: AutomotiveConfig.primaryTextSize,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _formatWind(data.windKmh),
            style: const TextStyle(
              color: VoyagerColors.textSecondary,
              fontSize: AutomotiveConfig.secondaryTextSize,
            ),
          ),
          if (hazard != DrivingHazard.none) ...[
            const SizedBox(height: AutomotiveConfig.sectionGap),
            _HazardBanner(hazard: hazard, message: message ?? ''),
          ],
        ],
      );
}

/// The landscape form: everything in one row instead of one column, at sizes
/// chosen to fit a pane that is wide but short rather than tall — the same
/// trade [AutomotiveMusicPlayer]'s own compact layout makes, for the same
/// reason (see its class doc).
class _CompactConditions extends StatelessWidget {
  final WeatherPlugin plugin;
  final roadstr.WeatherData data;
  final DrivingHazard hazard;
  final String? message;
  final AppLocalizations l;

  const _CompactConditions({
    required this.plugin,
    required this.data,
    required this.hazard,
    required this.message,
    required this.l,
  });

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(data.emoji, style: const TextStyle(fontSize: 56)),
          const SizedBox(width: 16),
          Text(
            _formatTemp(data.tempC),
            style: const TextStyle(
              color: VoyagerColors.textPrimary,
              fontSize: 52,
              fontWeight: FontWeight.w300,
              height: 1,
            ),
          ),
          const SizedBox(width: 20),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (plugin.placeName != null) ...[
                  _PlaceName(name: plugin.placeName!),
                  const SizedBox(height: 4),
                ],
                Text(
                  data.localizedDescription(l),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: VoyagerColors.textPrimary,
                    fontSize: AutomotiveConfig.secondaryTextSize,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatWind(data.windKmh),
                  style: const TextStyle(
                    color: VoyagerColors.textSecondary,
                    fontSize: 16,
                  ),
                ),
                if (hazard != DrivingHazard.none) ...[
                  const SizedBox(height: 6),
                  _HazardBanner(hazard: hazard, message: message ?? ''),
                ],
              ],
            ),
          ),
        ],
      );
}

class _PlaceName extends StatelessWidget {
  final String name;
  const _PlaceName({required this.name});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.place_rounded,
            size: 22,
            color: VoyagerColors.textSecondary,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: VoyagerColors.textSecondary,
                fontSize: AutomotiveConfig.secondaryTextSize,
              ),
            ),
          ),
        ],
      );
}

class _HazardBanner extends StatelessWidget {
  final DrivingHazard hazard;
  final String message;

  const _HazardBanner({required this.hazard, required this.message});

  @override
  Widget build(BuildContext context) {
    final colour = hazard == DrivingHazard.severe
        ? VoyagerColors.danger
        : VoyagerColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colour.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, color: colour, size: 28),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              message,
              style: TextStyle(
                color: colour,
                fontSize: AutomotiveConfig.secondaryTextSize,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  final String? error;
  const _Unavailable({this.error});

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: VoyagerColors.background,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 64,
                color: VoyagerColors.textSecondary,
              ),
              const SizedBox(height: AutomotiveConfig.gutter),
              Text(
                error == null
                    ? 'Waiting for a position fix'
                    : 'No weather data',
                style: const TextStyle(
                  color: VoyagerColors.textSecondary,
                  fontSize: AutomotiveConfig.secondaryTextSize,
                ),
              ),
            ],
          ),
        ),
      );
}
