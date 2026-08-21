import 'package:flutter/material.dart';

import '../config/automotive_config.dart';
import '../plugins/voice/voice_plugin.dart';
import '../theme/voyager_theme.dart';

/// The listening indicator.
///
/// Its only job is to answer "is it hearing me?" without the driver looking
/// for long. A pulsing dot does that in peripheral vision; a waveform or a
/// live transcript would not, and would invite exactly the sustained glance
/// this UI is built to avoid. The transcript appears only after recognition
/// finishes, and only so a misheard command is explicable.
class AutomotiveVoiceAssistant extends StatelessWidget {
  final VoicePlugin plugin;

  const AutomotiveVoiceAssistant({super.key, required this.plugin});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: plugin,
      builder: (context, _) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: VoyagerColors.surface.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: VoyagerColors.accent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PulsingMic(active: plugin.isListening),
            const SizedBox(width: 14),
            Flexible(
              child: Text(
                _label(context),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: VoyagerColors.textPrimary,
                  fontSize: AutomotiveConfig.secondaryTextSize,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _label(BuildContext context) {
    final italian = Localizations.localeOf(context).languageCode == 'it';
    if (plugin.isListening) return italian ? 'Ti ascolto…' : 'Listening…';
    if (!plugin.canListen) {
      return italian
          ? 'Comandi vocali non disponibili'
          : 'Voice commands unavailable';
    }
    return plugin.lastCommand?.transcript ?? (italian ? 'Pronto' : 'Ready');
  }
}

class _PulsingMic extends StatefulWidget {
  final bool active;
  const _PulsingMic({required this.active});

  @override
  State<_PulsingMic> createState() => _PulsingMicState();
}

class _PulsingMicState extends State<_PulsingMic>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_PulsingMic old) {
    super.didUpdateWidget(old);
    // Stopping the controller when inactive matters: an animation ticking
    // behind a hidden overlay wakes the raster thread on every frame while the
    // map is trying to use it.
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.active && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: VoyagerColors.accent
              .withValues(alpha: 0.25 + 0.35 * _controller.value),
        ),
        child: child,
      ),
      child: const Icon(
        Icons.mic_rounded,
        color: VoyagerColors.accentLight,
        size: 26,
      ),
    );
  }
}
