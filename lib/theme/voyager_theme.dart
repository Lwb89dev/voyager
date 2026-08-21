import 'package:flutter/material.dart';

/// Voyager's palette, sampled from the app icon.
///
/// The icon is a violet chevron over a near-black plate, and the UI keeps that
/// relationship: an almost-black ground with violet as the only saturated
/// colour. This is not just brand consistency — a dark ground is the correct
/// choice for a screen mounted in a windscreen's line of sight, because a
/// bright one reflects onto the glass at night. The single accent hue also
/// means the few things that must catch the eye (an active route, an incoming
/// call) are the only saturated pixels on screen.
class VoyagerColors {
  const VoyagerColors._();

  /// Sampled from the icon's outer plate.
  static const Color background = Color(0xFF02040F);

  /// The icon's rounded tile — one step up from the ground, used for cards.
  static const Color surface = Color(0xFF0D1024);

  /// A further step up, for controls sitting on a card.
  static const Color surfaceRaised = Color(0xFF161A33);

  /// The left arm of the chevron. The primary action colour.
  static const Color accent = Color(0xFF812DF8);

  /// The right arm — a lighter periwinkle used for secondary emphasis and for
  /// the gradient that pairs with [accent].
  static const Color accentLight = Color(0xFFBCBBFC);

  /// Mid-tone between the two, for progress fills and active indicators.
  static const Color accentMid = Color(0xFF8B5CF6);

  static const Color textPrimary = Color(0xFFEDEBFB);
  static const Color textSecondary = Color(0xFF9A9AB8);
  static const Color border = Color(0xFF242847);

  static const Color success = Color(0xFF3DD68C);
  static const Color warning = Color(0xFFFFB020);
  static const Color danger = Color(0xFFF2555A);

  /// The chevron gradient, reused for headers and the primary button.
  static const LinearGradient chevron = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [accent, accentLight],
  );
}

class VoyagerTheme {
  const VoyagerTheme._();

  /// Voyager ships one theme, not a light/dark pair.
  ///
  /// A light theme would be actively unsafe here: the app is designed to sit
  /// in a driver's peripheral vision for hours, and there is no ambient-light
  /// condition in which a bright dashboard is the better choice. Roadstr,
  /// which is also used as a phone app on foot, does offer both.
  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: VoyagerColors.accent,
      onPrimary: Colors.white,
      secondary: VoyagerColors.accentLight,
      onSecondary: VoyagerColors.background,
      surface: VoyagerColors.surface,
      onSurface: VoyagerColors.textPrimary,
      error: VoyagerColors.danger,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: VoyagerColors.background,
      canvasColor: VoyagerColors.background,
      dividerColor: VoyagerColors.border,
      fontFamily: null,
      appBarTheme: const AppBarTheme(
        backgroundColor: VoyagerColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: VoyagerColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: VoyagerColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: VoyagerColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: VoyagerColors.accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? VoyagerColors.accentLight
              : VoyagerColors.textSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? VoyagerColors.accent
              : VoyagerColors.surfaceRaised,
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: VoyagerColors.accent,
        inactiveTrackColor: VoyagerColors.surfaceRaised,
        thumbColor: VoyagerColors.accentLight,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: VoyagerColors.surfaceRaised,
        contentTextStyle: TextStyle(color: VoyagerColors.textPrimary),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: VoyagerColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titleTextStyle: const TextStyle(
          color: VoyagerColors.textPrimary,
          fontSize: 19,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: const TextStyle(
          color: VoyagerColors.textSecondary,
          fontSize: 14,
          height: 1.5,
        ),
      ),
    );
  }
}
