import 'package:flutter/material.dart';

import '../config/automotive_config.dart';
import '../models/plugin_manifest.dart';
import '../theme/voyager_theme.dart';

/// Voyager's own controls, drawn as a floating pill over the active plugin.
///
/// The only chrome the dashboard has, in every orientation. A docked bar below
/// the plugin — the original portrait layout — costs about 145 dp of height
/// unconditionally: 15% of a phone held upright, more like a third of the same
/// phone in a dashboard mount, taken from the one thing the driver is actually
/// looking at. Floating it costs a strip of map instead, and collapsing it
/// costs almost nothing.
///
/// No clock. An earlier version put one here, reasoning that landscape has no
/// spare furniture for a clock elsewhere — true, but beside the point: every
/// screenshot of this app shows Android's own status bar clock at the top
/// already, because [SystemUiMode.edgeToEdge] keeps it visible. Duplicating it
/// here bought nothing and cost real width: on a ~400 dp portrait phone, a
/// clock plus six 60 dp destinations (four plugins, Settings, Hide) forced
/// this pill wide enough to reach both screen edges, which is also wide enough
/// to reach into the corner Roadstr's own compact bar lives in. Dropping the
/// clock is what makes the pill narrow enough to stay clear of both.
///
/// [_buildBar] still degrades if a future plugin count outgrows even that: a
/// horizontally scrolling row, inset from the edges rather than filling them,
/// as a last resort that keeps every control reachable without ever painting a
/// diagnostic overflow banner over the app.
class AutomotiveChrome extends StatelessWidget {
  final List<PluginManifest> plugins;
  final String? activeId;
  final ValueChanged<String> onSelected;
  final VoidCallback onSettings;

  /// Collapsed, the chrome is a single tab showing the active plugin's icon.
  final bool collapsed;
  final VoidCallback onToggleCollapsed;

  const AutomotiveChrome({
    super.key,
    required this.plugins,
    required this.activeId,
    required this.onSelected,
    required this.onSettings,
    required this.collapsed,
    required this.onToggleCollapsed,
  });

  /// Height the plugin beneath must keep clear, including the margin. Used both
  /// to place the plugin's own overlay and to tell Roadstr's map how much bottom
  /// padding to respect, so its floating controls rise above this instead of
  /// hiding underneath it.
  static double reservedHeight({required bool collapsed}) =>
      collapsed ? 52 : 84;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: AnimatedSize(
            duration: AutomotiveConfig.transition,
            curve: Curves.easeOut,
            child: collapsed ? _buildHandle(context) : _buildBar(context),
          ),
        ),
      ),
    );
  }

  /// Collapsed: one tab, showing which plugin is in front and nothing else.
  ///
  /// Deliberately still a large target — it is the way back to every control,
  /// and a driver reaching for it is doing so without looking.
  Widget _buildHandle(BuildContext context) {
    final active = plugins.where((p) => p.id == activeId);
    final icon = active.isEmpty ? Icons.expand_less_rounded : active.first.icon;

    return _Surface(
      onTap: onToggleCollapsed,
      child: SizedBox(
        height: 44,
        width: 116,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: VoyagerColors.accentLight),
            const SizedBox(width: 8),
            const Icon(
              Icons.expand_less_rounded,
              size: 22,
              color: VoyagerColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBar(BuildContext context) {
    final destinations = plugins.where((p) => p.canBeFullscreen).toList();
    // Plugins, plus Settings and Hide, which are always present.
    final buttonsWidth = (destinations.length + 2) * 60.0;
    const gaps = 10.0 + 6.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final row = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 10),
            for (final plugin in destinations)
              _ChromeButton(
                icon: plugin.icon,
                label: plugin.label,
                selected: plugin.id == activeId,
                onPressed: () => onSelected(plugin.id),
              ),
            _ChromeButton(
              icon: Icons.settings_rounded,
              label: 'Settings',
              onPressed: onSettings,
            ),
            _ChromeButton(
              icon: Icons.expand_more_rounded,
              label: 'Hide',
              onPressed: onToggleCollapsed,
            ),
            const SizedBox(width: 6),
          ],
        );

        // Last resort, not the everyday path: without a clock to feed it,
        // six 60 dp destinations plus Settings and Hide need ~490 px, which
        // fits every phone width seen in practice with margin to spare. A
        // future plugin count that outgrows it still degrades to a scrolling
        // bar rather than an overflow banner — inset from the edges, never
        // filling them, so it can never reach into the corner Roadstr's own
        // compact bar occupies.
        final fits = constraints.maxWidth >= buttonsWidth + gaps;
        if (!fits) {
          // A bare Padding around the scrollview does not produce a visual
          // margin here: SingleChildScrollView fills whatever width it is
          // offered along its scroll axis rather than shrinking to content,
          // so the padding's own size becomes child-width-plus-32, and if the
          // child greedily claims all of it the total is right back to the
          // full available width. An explicit width on the outer box is what
          // actually reserves the margin.
          final margined = (constraints.maxWidth - 32).clamp(0.0, double.infinity);
          return SizedBox(
            width: margined,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _Surface(child: SizedBox(height: 76, child: row)),
            ),
          );
        }
        return _Surface(child: SizedBox(height: 76, child: row));
      },
    );
  }
}

class _Surface extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _Surface({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            // Nearly opaque rather than translucent: map tiles showing through
            // the controls is the kind of thing that looks good in a screenshot
            // and is unreadable over a junction.
            color: VoyagerColors.surface.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: VoyagerColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      );
}

/// A chrome button. Smaller than [AutomotiveButton]'s 80 dp floor — 60 dp — and
/// that is a deliberate, bounded exception: the alternative is a bar tall
/// enough to hide the road ahead. Every action behind these buttons is also
/// reachable from the steering wheel, which needs no target at all.
class _ChromeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  const _ChromeButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 60,
            height: 60,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? VoyagerColors.accent.withValues(alpha: 0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              size: 28,
              color: selected
                  ? VoyagerColors.accentLight
                  : VoyagerColors.textPrimary,
            ),
          ),
        ),
      );
}
