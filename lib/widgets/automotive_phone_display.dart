import 'package:flutter/material.dart';

import '../config/automotive_config.dart';
import '../plugins/phone/phone_plugin.dart';
import '../plugins/phone/sms_notifier.dart';
import '../theme/voyager_theme.dart';

/// The phone pane: the current call if there is one, otherwise recent messages.
class AutomotivePhoneDisplay extends StatelessWidget {
  final PhonePlugin plugin;

  const AutomotivePhoneDisplay({super.key, required this.plugin});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: plugin,
      builder: (context, _) {
        if (plugin.calls.current != null) {
          return _CallCard(plugin: plugin, compact: false);
        }
        return _MessageList(messages: plugin.sms.messages);
      },
    );
  }
}

/// The call card as an overlay over the map.
///
/// A call arriving during navigation is the one event allowed to cover the
/// road ahead, because the alternative is the driver reaching for a phone.
class IncomingCallOverlay extends StatelessWidget {
  final PhonePlugin plugin;

  const IncomingCallOverlay({super.key, required this.plugin});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: plugin,
        builder: (context, _) => plugin.calls.current == null
            ? const SizedBox.shrink()
            : _CallCard(plugin: plugin, compact: true),
      );
}

class _CallCard extends StatelessWidget {
  final PhonePlugin plugin;

  /// Overlay form: same two actions, less vertical space.
  final bool compact;

  const _CallCard({required this.plugin, required this.compact});

  @override
  Widget build(BuildContext context) {
    final call = plugin.calls.current!;
    return Container(
      padding: EdgeInsets.all(compact ? 16 : AutomotiveConfig.sectionGap),
      decoration: BoxDecoration(
        color: VoyagerColors.surface,
        borderRadius: BorderRadius.circular(compact ? 20 : 0),
        border: compact ? Border.all(color: VoyagerColors.accent) : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            call.display,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: VoyagerColors.textPrimary,
              fontSize: compact ? 26 : 44,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: compact ? 12 : AutomotiveConfig.sectionGap),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _CallAction(
                icon: Icons.call_end_rounded,
                colour: VoyagerColors.danger,
                label: 'Reject',
                onPressed: plugin.calls.reject,
              ),
              _CallAction(
                icon: Icons.call_rounded,
                colour: VoyagerColors.success,
                label: 'Answer',
                onPressed: plugin.calls.answer,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Answer and reject, at the largest size anything in Voyager gets.
///
/// They are also placed as far apart as the row allows: these two buttons are
/// pressed under time pressure and without looking, and they are the one pair
/// in the app where hitting the wrong one cannot be undone.
class _CallAction extends StatelessWidget {
  final IconData icon;
  final Color colour;
  final String label;
  final VoidCallback onPressed;

  const _CallAction({
    required this.icon,
    required this.colour,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(shape: BoxShape.circle, color: colour),
            child: Icon(icon, size: 44, color: Colors.white),
          ),
        ),
      );
}

class _MessageList extends StatelessWidget {
  final List<SmsMessage> messages;
  const _MessageList({required this.messages});

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const ColoredBox(
        color: VoyagerColors.background,
        child: Center(
          child: Text(
            'No messages',
            style: TextStyle(
              color: VoyagerColors.textSecondary,
              fontSize: AutomotiveConfig.secondaryTextSize,
            ),
          ),
        ),
      );
    }

    return ColoredBox(
      color: VoyagerColors.background,
      child: ListView.separated(
        padding: const EdgeInsets.all(AutomotiveConfig.gutter),
        itemCount: messages.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _MessageCard(message: messages[index]),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final SmsMessage message;
  const _MessageCard({required this.message});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AutomotiveConfig.gutter),
        decoration: BoxDecoration(
          color: VoyagerColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.sender,
              style: const TextStyle(
                color: VoyagerColors.accentLight,
                fontSize: AutomotiveConfig.secondaryTextSize,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message.body,
              // Three lines is where a message stops being glanceable. A
              // longer one is truncated on purpose: reading the rest is what
              // the read-aloud switch is for.
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: VoyagerColors.textPrimary,
                fontSize: AutomotiveConfig.secondaryTextSize,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
}
