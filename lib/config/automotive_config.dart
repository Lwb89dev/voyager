import 'package:flutter/material.dart';

/// Layout, timing and touch-target constants for the in-car UI.
///
/// The numbers here are not arbitrary: they come from the automotive HMI
/// guidelines Voyager follows (see docs/AUTOMOTIVE_UX_GUIDELINES.md). Anything
/// a driver touches while moving must be reachable without aiming, which in
/// practice means large targets, high contrast and no more than three taps to
/// any primary action.
class AutomotiveConfig {
  const AutomotiveConfig._();

  /// Vertical split of the dashboard, as flex weights.
  ///
  /// The active plugin owns the great majority of the screen; the system bar
  /// and the button bar are fixed furniture below it.
  static const int pluginFlex = 7;
  static const int systemBarFlex = 1;
  static const int buttonBarFlex = 2;

  /// Minimum touch target. NHTSA driver-distraction guidance and the Android
  /// for Cars guidelines both land around 12 mm of physical size; at the
  /// ~160 dpi baseline of a logical pixel that is roughly 76 dp. We round up.
  static const double minTouchTargetDp = 80;

  /// Minimum font sizes. Glanceable text has to be readable at arm's length
  /// in bright sunlight, which rules out the usual 14 sp body text.
  static const double primaryTextSize = 28;
  static const double secondaryTextSize = 20;
  static const double captionTextSize = 16;

  /// A driver's glance away from the road should stay under two seconds
  /// (NHTSA). Transitions longer than this force a second glance, so every
  /// animation in the dashboard is capped well below it.
  static const Duration maxGlance = Duration(seconds: 2);
  static const Duration transition = Duration(milliseconds: 180);

  /// How long the music overlay stays expanded before collapsing itself back
  /// to the mini strip. Prevents the map from being hidden indefinitely
  /// because someone tapped the overlay and then started driving.
  static const Duration overlayAutoCollapse = Duration(seconds: 12);

  /// Screen-brightness targets used by [AutomotiveUiService], as a fraction of
  /// the maximum. Night driving with a full-brightness screen is genuinely
  /// dangerous, so the night value is deliberately low.
  static const double dayBrightness = 1.0;
  static const double nightBrightness = 0.35;

  /// Spacing scale. Generous, because dense layouts are unreadable in motion.
  static const double gutter = 16;
  static const double sectionGap = 24;

  /// Palette. The dashboard is dark-first: a bright background at night
  /// reflects off the windscreen.
  static const Color background = Color(0xFF0B0F14);
  static const Color surface = Color(0xFF161C24);
  static const Color accent = Color(0xFF4FC3F7);
  static const Color onSurface = Color(0xFFE8EDF2);
  static const Color onSurfaceMuted = Color(0xFF9AA7B4);
  static const Color danger = Color(0xFFEF5350);
}
