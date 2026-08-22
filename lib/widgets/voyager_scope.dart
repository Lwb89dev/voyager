import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../theme/voyager_theme.dart';

/// Applies Voyager's own theme to the subtree.
///
/// The root `MaterialApp` carries **Roadstr's** theme, not Voyager's, and that
/// is the opposite of what it looks like it should be. The reason is where the
/// routes come from: Roadstr's profile, notifications and settings screens are
/// pushed by Roadstr's own code onto the root navigator, so nothing Voyager
/// wraps around the map can reach them. With Voyager's theme at the root they
/// rendered in Voyager's palette — a Roadstr screen that did not look like
/// Roadstr, and that ignored the theme the user had chosen for it.
///
/// So the root belongs to the app whose screens Voyager cannot wrap, and
/// Voyager wraps its own — which it can, because it builds them itself. Every
/// Voyager screen starts with one of these.
class VoyagerScope extends StatelessWidget {
  final Widget child;

  /// True for a screen that is not part of the driving surface — used
  /// parked, not glanced at mid-drive — where staying dark regardless of the
  /// user's own light/dark choice reads as a bug rather than a safety
  /// measure. The dashboard, map, music and podcast panes leave this false:
  /// see the class doc on [VoyagerTheme.dark] for why they always stay dark.
  final bool matchAmbient;

  const VoyagerScope(
      {super.key, required this.child, this.matchAmbient = false});

  static const lightThemeKey = 'voyager_light_theme';

  @override
  Widget build(BuildContext context) {
    final light = matchAmbient &&
        (Hive.box('settings').get(lightThemeKey, defaultValue: false) as bool);
    return Theme(
      data: light ? VoyagerTheme.light : VoyagerTheme.dark,
      child: child,
    );
  }
}
