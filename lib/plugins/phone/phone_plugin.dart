import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/plugin_manifest.dart';
import '../../widgets/automotive_phone_display.dart';
import '../base_plugin.dart';
import '../voice/voice_plugin.dart';
import 'call_manager.dart';
import 'sms_notifier.dart';

/// Calls and messages, kept to what can be handled without picking anything up.
///
/// There is no dialler and no contact list. Placing a call means choosing a
/// name from a list of hundreds, which is among the worst things a driver can
/// do with a touchscreen; Voyager deliberately does not offer it. What it does
/// offer is the half that is safe: seeing who is calling, answering or
/// rejecting with one large button, and hearing a message read aloud.
class PhonePlugin extends BasePlugin {
  final CallManager calls;
  final SmsNotifier sms;

  /// Optional. When present, incoming messages can be spoken instead of read.
  final VoicePlugin? voice;

  /// Whether an arriving message is read aloud. Off by default: a message read
  /// out with a passenger in the car is a privacy decision that belongs to the
  /// user, not to a default.
  bool readAloud = false;

  bool _ready = false;

  PhonePlugin({CallManager? callManager, SmsNotifier? smsNotifier, this.voice})
      : calls = callManager ?? CallManager(),
        sms = smsNotifier ?? SmsNotifier();

  @override
  PluginManifest get manifest => PluginManifest(
        id: 'phone',
        label: 'Phone',
        icon: Icons.phone_rounded,
        order: 6,
        providesOverlay: true,
        // Highest: a ringing phone is the one thing allowed to cover the road
        // ahead, because the alternative is the driver reaching for a handset.
        overlayPriority: 3,
        // Hidden outright when the device cannot do telephony, rather than
        // shown as a button that opens an apologetic empty screen.
        enabled: _ready && (calls.isAvailable || sms.isAvailable),
      );

  @override
  bool get isReady => _ready;

  @override
  Future<void> initialize() async {
    await calls.initialize();
    await sms.startListening();
    calls.addListener(notifyListeners);
    sms.addListener(_onMessage);
    _ready = true;
    notifyListeners();
  }

  void _onMessage() {
    notifyListeners();
    final message = sms.latest;
    if (!readAloud || message == null || voice == null) return;
    // Not urgent: a text must never interrupt a turn instruction.
    unawaited(voice!.say('${message.sender}: ${message.body}'));
  }

  @override
  Widget buildFullscreenView(BuildContext context) =>
      AutomotivePhoneDisplay(plugin: this);

  /// Only a live call. A message that arrived is not a reason to cover the
  /// map — it waits for the pane, or gets read aloud.
  @override
  bool get wantsOverlay => calls.current != null;

  @override
  Widget? buildOverlay(BuildContext context) =>
      wantsOverlay ? IncomingCallOverlay(plugin: this) : null;

  @override
  void dispose() {
    calls.removeListener(notifyListeners);
    sms.removeListener(_onMessage);
    calls.dispose();
    sms.dispose();
    super.dispose();
  }
}
