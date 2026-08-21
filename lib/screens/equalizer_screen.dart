import 'package:flutter/material.dart';

import '../config/automotive_config.dart';
import '../l10n/voyager_strings.dart';
import '../plugins/music/equalizer_controller.dart';
import '../theme/voyager_theme.dart';
import '../widgets/voyager_scope.dart';

/// The equalizer: a switch, four presets, and one slider per band.
///
/// Used parked. Dragging a slider to hear the difference is the opposite of a
/// two-second glance, so this is deliberately not built to automotive sizing —
/// the presets are what a driver reaches for in motion, and they are one tap
/// each.
class EqualizerScreen extends StatelessWidget {
  final EqualizerController controller;

  const EqualizerScreen({super.key, required this.controller});

  static Future<void> show(
    BuildContext context,
    EqualizerController controller,
  ) =>
      Navigator.of(context).push<void>(MaterialPageRoute(
        builder: (_) => EqualizerScreen(controller: controller),
      ));

  @override
  Widget build(BuildContext context) {
    final s = VoyagerStrings.of(context);
    return VoyagerScope(
      child: Scaffold(
        backgroundColor: VoyagerColors.background,
        appBar: AppBar(title: Text(s.equalizer)),
        body: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => _body(context, s),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, VoyagerStrings s) {
    if (!controller.isReady) return _Unavailable(s: s);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        SwitchListTile(
          value: controller.isEnabled,
          onChanged: controller.setEnabled,
          title: Text(
            s.equalizerEnabled,
            style: const TextStyle(color: VoyagerColors.textPrimary),
          ),
          subtitle: Text(
            s.equalizerEnabledWhy,
            style: const TextStyle(
              color: VoyagerColors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: AutomotiveConfig.gutter),
        _Presets(controller: controller, s: s),
        const SizedBox(height: AutomotiveConfig.sectionGap),
        _Bands(controller: controller),
      ],
    );
  }
}

class _Presets extends StatelessWidget {
  final EqualizerController controller;
  final VoyagerStrings s;

  const _Presets({required this.controller, required this.s});

  @override
  Widget build(BuildContext context) {
    final current = controller.presetName;
    // "custom" is a state the sliders put you in, never something to choose,
    // so it is not offered as a chip.
    final offered = EqualizerPreset.values
        .where((p) => p != EqualizerPreset.custom)
        .toList();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final preset in offered)
          ChoiceChip(
            selected: current == preset.name,
            onSelected: (_) => controller.applyPreset(preset),
            label: Text(s.presetName(preset.name)),
            labelStyle: TextStyle(
              color: current == preset.name
                  ? Colors.white
                  : VoyagerColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            selectedColor: VoyagerColors.accent,
            backgroundColor: VoyagerColors.surface,
            side: const BorderSide(color: VoyagerColors.border),
            showCheckmark: false,
          ),
        if (current == EqualizerPreset.custom.name)
          Chip(
            label: Text(s.presetName(EqualizerPreset.custom.name)),
            labelStyle: const TextStyle(color: VoyagerColors.accentLight),
            backgroundColor: VoyagerColors.surfaceRaised,
            side: const BorderSide(color: VoyagerColors.border),
          ),
      ],
    );
  }
}

class _Bands extends StatelessWidget {
  final EqualizerController controller;

  const _Bands({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < controller.bands.length; i++)
          Expanded(
            child: _Band(
              controller: controller,
              index: i,
            ),
          ),
      ],
    );
  }
}

class _Band extends StatelessWidget {
  final EqualizerController controller;
  final int index;

  const _Band({required this.controller, required this.index});

  @override
  Widget build(BuildContext context) {
    final band = controller.bands[index];
    return Column(
      children: [
        Text(
          _gainLabel(band.gain),
          style: const TextStyle(
            color: VoyagerColors.textSecondary,
            fontSize: 12,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        SizedBox(
          height: 220,
          child: RotatedBox(
            quarterTurns: 3,
            child: Slider(
              value: band.gain.clamp(
                controller.minDecibels,
                controller.maxDecibels,
              ),
              min: controller.minDecibels,
              max: controller.maxDecibels,
              onChanged: (value) => controller.setGain(index, value),
            ),
          ),
        ),
        Text(
          _frequencyLabel(band.centerFrequency),
          style: const TextStyle(
            color: VoyagerColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// Centre frequencies arrive in hertz.
  ///
  /// Android's own `Equalizer.getCenterFreq` reports millihertz, which is what
  /// this originally divided by — and every band then rendered as "0 Hz" or
  /// "1 Hz". just_audio has already converted by the time the value reaches
  /// Dart: a five-band equalizer reports 60, 230, 910, 3600, 14000, which are
  /// the textbook centres in hertz and nonsense as millihertz.
  static String _frequencyLabel(double hertz) {
    if (hertz >= 1000) {
      final kilohertz = hertz / 1000;
      final rounded = kilohertz >= 10 ? kilohertz.round().toString()
          : kilohertz.toStringAsFixed(1);
      return '$rounded kHz';
    }
    return '${hertz.round()} Hz';
  }

  static String _gainLabel(double decibels) {
    final rounded = decibels.round();
    return rounded > 0 ? '+$rounded' : '$rounded';
  }
}

class _Unavailable extends StatelessWidget {
  final VoyagerStrings s;
  const _Unavailable({required this.s});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AutomotiveConfig.sectionGap),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.graphic_eq_rounded,
                size: 56,
                color: VoyagerColors.textSecondary,
              ),
              const SizedBox(height: AutomotiveConfig.gutter),
              Text(
                s.equalizerUnavailable,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: VoyagerColors.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
}
