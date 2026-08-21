import 'package:flutter/material.dart';

/// Static description of a plugin: everything the dashboard needs to lay out
/// its chrome before the plugin itself has finished initialising.
///
/// Keeping this separate from the plugin instance is what lets the button bar
/// render immediately at startup. A music server that takes four seconds to
/// answer must not delay the first frame, and it does not, because the button
/// bar is drawn from manifests alone.
@immutable
class PluginManifest {
  /// Unique, stable, lowercase. Used as the registry key and persisted in
  /// settings as the "last active plugin", so renaming one is a breaking
  /// change for the user's saved state.
  final String id;

  /// Shown under the button. Short — long labels wrap and wrapping labels are
  /// unreadable at a glance.
  final String label;

  final IconData icon;

  /// Position in the button bar, ascending. Navigation is 0 and stays 0: it
  /// is the plugin the driver reaches for by muscle memory.
  final int order;

  /// Whether the plugin may draw over another plugin's fullscreen view.
  /// Only music, voice and phone do; two overlays are never shown at once.
  final bool providesOverlay;

  /// Which overlay wins when more than one plugin wants to show its own.
  /// Higher takes the screen. A call outranks a listening prompt, which
  /// outranks the music strip: that is the order of how badly each one needs
  /// the driver's attention right now.
  final int overlayPriority;

  /// Whether the plugin can be the fullscreen one. Voice is false — it speaks
  /// and listens over whatever is on screen and has only a status sheet.
  final bool canBeFullscreen;

  /// When false the plugin is registered but hidden: it has no server
  /// configured, no model installed, or no permission granted. The button bar
  /// omits it entirely rather than showing a control that does nothing.
  final bool enabled;

  const PluginManifest({
    required this.id,
    required this.label,
    required this.icon,
    required this.order,
    this.providesOverlay = false,
    this.overlayPriority = 0,
    this.canBeFullscreen = true,
    this.enabled = true,
  });

  PluginManifest copyWith({bool? enabled}) => PluginManifest(
        id: id,
        label: label,
        icon: icon,
        order: order,
        providesOverlay: providesOverlay,
        overlayPriority: overlayPriority,
        canBeFullscreen: canBeFullscreen,
        enabled: enabled ?? this.enabled,
      );
}
