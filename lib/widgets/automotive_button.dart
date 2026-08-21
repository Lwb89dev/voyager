import 'package:flutter/material.dart';

import '../config/automotive_config.dart';
import '../theme/voyager_theme.dart';

/// A touch target sized for someone who is not looking at it.
///
/// Everything about this widget follows from that: at least 80 dp square so it
/// can be hit with a thumb from muscle memory, an icon large enough to be
/// identified peripherally, and a label that is always present — an unlabelled
/// icon costs a second glance to decode, and a second glance is the thing the
/// whole UI exists to avoid.
class AutomotiveButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  /// Draws the button in the accent colour. Used for the active plugin in the
  /// button bar and for the primary transport control.
  final bool selected;

  /// Suppresses the label. Only for controls whose icon is universal — play,
  /// pause, skip — and never in the button bar.
  final bool iconOnly;

  /// Overrides [AutomotiveConfig.minTouchTargetDp].
  ///
  /// A bounded exception, not a way to shrink buttons freely: the floor exists
  /// because a driver hits these without looking, and going below it is only
  /// defensible when the alternative is worse — the music overlay's transport
  /// row and the landscape chrome both make the same trade at 56–60 dp rather
  /// than let their strip cover a meaningful slice of the map. The button bar
  /// needs the same escape hatch: five destinations at a strict 80 dp floor do
  /// not fit a portrait phone's width at all, labelled or not.
  final double? minSize;

  const AutomotiveButton({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.selected = false,
    this.iconOnly = false,
    this.minSize,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final foreground = _foreground(enabled);

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          constraints: BoxConstraints(
            minWidth: minSize ?? AutomotiveConfig.minTouchTargetDp,
            minHeight: minSize ?? AutomotiveConfig.minTouchTargetDp,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? VoyagerColors.accent.withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 34, color: foreground),
              if (!iconOnly) ...[
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: AutomotiveConfig.captionTextSize,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _foreground(bool enabled) {
    if (!enabled) return VoyagerColors.textSecondary.withValues(alpha: 0.4);
    return selected ? VoyagerColors.accentLight : VoyagerColors.textPrimary;
  }
}
