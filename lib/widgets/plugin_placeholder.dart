import 'package:flutter/material.dart';

import '../config/automotive_config.dart';
import '../l10n/voyager_strings.dart';
import '../models/plugin_manifest.dart';
import '../theme/voyager_theme.dart';

/// Shown in place of a plugin's view while it is still initialising, or after
/// it has failed.
///
/// A failed plugin gets a sentence, not a spinner that never stops: a driver
/// who can see "music server unreachable" stops tapping and gets on with
/// driving, which is the entire point.
class PluginPlaceholder extends StatelessWidget {
  final PluginManifest manifest;
  final String? error;

  /// Re-runs the plugin's own [BasePlugin.retry]. Null while a retry is
  /// already in flight, so a driver tapping twice does not queue two of them.
  final VoidCallback? onRetry;

  const PluginPlaceholder({
    super.key,
    required this.manifest,
    this.error,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final failed = error != null;
    return ColoredBox(
      color: VoyagerColors.background,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AutomotiveConfig.sectionGap),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                failed ? Icons.cloud_off_rounded : manifest.icon,
                size: 56,
                color: failed
                    ? VoyagerColors.warning
                    : VoyagerColors.textSecondary,
              ),
              const SizedBox(height: AutomotiveConfig.gutter),
              Text(
                failed ? error! : manifest.label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: VoyagerColors.textPrimary,
                  fontSize: AutomotiveConfig.secondaryTextSize,
                ),
              ),
              if (failed && onRetry != null) ...[
                const SizedBox(height: AutomotiveConfig.sectionGap),
                FilledButton.icon(
                  onPressed: onRetry,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 18),
                    textStyle: const TextStyle(
                      fontSize: AutomotiveConfig.secondaryTextSize,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 26),
                  label: Text(VoyagerStrings.of(context).retry),
                ),
              ],
              if (!failed) ...[
                const SizedBox(height: AutomotiveConfig.sectionGap),
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: VoyagerColors.accent,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
