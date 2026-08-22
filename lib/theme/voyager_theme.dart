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

/// The same named colours [VoyagerColors] provides as static constants,
/// exposed instead as a [ThemeExtension] so a screen that opts into
/// [VoyagerTheme.light] can be built from `Theme.of(context)` rather than
/// from the dark-only statics. Every field mirrors one of [VoyagerColors]'s.
class VoyagerPalette extends ThemeExtension<VoyagerPalette> {
  final Color background;
  final Color surface;
  final Color surfaceRaised;
  final Color accent;
  final Color accentLight;
  final Color accentMid;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color success;
  final Color warning;
  final Color danger;

  const VoyagerPalette({
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.accent,
    required this.accentLight,
    required this.accentMid,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.success,
    required this.warning,
    required this.danger,
  });

  static const dark = VoyagerPalette(
    background: VoyagerColors.background,
    surface: VoyagerColors.surface,
    surfaceRaised: VoyagerColors.surfaceRaised,
    accent: VoyagerColors.accent,
    accentLight: VoyagerColors.accentLight,
    accentMid: VoyagerColors.accentMid,
    textPrimary: VoyagerColors.textPrimary,
    textSecondary: VoyagerColors.textSecondary,
    border: VoyagerColors.border,
    success: VoyagerColors.success,
    warning: VoyagerColors.warning,
    danger: VoyagerColors.danger,
  );

  /// Same accent hue family, inverted neutral scale — a violet-on-white
  /// counterpart to the icon-sampled dark palette, with the accent and
  /// status colours deepened a step so they still hold contrast on white.
  static const light = VoyagerPalette(
    background: Color(0xFFF5F5FA),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFEDEBF7),
    accent: Color(0xFF6D28D9),
    accentLight: Color(0xFF6D5FD3),
    accentMid: Color(0xFF7C3AED),
    textPrimary: Color(0xFF1A1B2E),
    textSecondary: Color(0xFF5C5C74),
    border: Color(0xFFDCDCE8),
    success: Color(0xFF1FA968),
    warning: Color(0xFFB5760A),
    danger: Color(0xFFD23B41),
  );

  @override
  VoyagerPalette copyWith() => this;

  @override
  VoyagerPalette lerp(ThemeExtension<VoyagerPalette>? other, double t) =>
      other is VoyagerPalette && t >= 0.5 ? other : this;
}

class VoyagerTheme {
  const VoyagerTheme._();

  /// The dashboard's own theme — chrome, the map pane, music, podcasts,
  /// weather. Always this one, never [light]: it sits in a driver's
  /// peripheral vision for hours, and there is no ambient-light condition in
  /// which a bright dashboard is the better choice on a windscreen mount.
  static ThemeData get dark => _themeFor(VoyagerPalette.dark);

  /// For the screens that are explicitly not part of the driving surface —
  /// Settings foremost, used parked rather than glanced at mid-drive — where
  /// staying dark regardless of the rest of the app's theme reads as a bug,
  /// not a safety choice. Opt-in per screen; see `VoyagerScope.matchAmbient`.
  static ThemeData get light => _themeFor(VoyagerPalette.light);

  static ThemeData _themeFor(VoyagerPalette p) {
    final scheme = p == VoyagerPalette.light
        ? ColorScheme.light(
            primary: p.accent,
            onPrimary: Colors.white,
            secondary: p.accentLight,
            onSecondary: Colors.white,
            surface: p.surface,
            onSurface: p.textPrimary,
            error: p.danger,
            onError: Colors.white,
          )
        : ColorScheme.dark(
            primary: p.accent,
            onPrimary: Colors.white,
            secondary: p.accentLight,
            onSecondary: p.background,
            surface: p.surface,
            onSurface: p.textPrimary,
            error: p.danger,
            onError: Colors.white,
          );

    return ThemeData(
      useMaterial3: true,
      brightness:
          p == VoyagerPalette.light ? Brightness.light : Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.background,
      canvasColor: p.background,
      dividerColor: p.border,
      fontFamily: null,
      extensions: [p],
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: p.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: p.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? p.accentLight
              : p.textSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.accent : p.surfaceRaised,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: p.accent,
        inactiveTrackColor: p.surfaceRaised,
        thumbColor: p.accentLight,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.surfaceRaised,
        contentTextStyle: TextStyle(color: p.textPrimary),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titleTextStyle: TextStyle(
          color: p.textPrimary,
          fontSize: 19,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: TextStyle(
          color: p.textSecondary,
          fontSize: 14,
          height: 1.5,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        labelStyle: TextStyle(color: p.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
