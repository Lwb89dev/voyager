import 'package:flutter/material.dart';

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

  const VoyagerScope({super.key, required this.child});

  @override
  Widget build(BuildContext context) =>
      Theme(data: VoyagerTheme.dark, child: child);
}
