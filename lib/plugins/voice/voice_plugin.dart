import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/gesture_event.dart';
import '../../models/plugin_manifest.dart';
import '../../models/voice_command.dart';
import '../../services/open_source_config.dart';
import '../../services/plugin_service.dart';
import '../../utils/logger_automotive.dart';
import '../../widgets/automotive_voice_assistant.dart';
import '../base_plugin.dart';
import '../music/music_plugin.dart';
import 'speech_service.dart';
import 'voice_command_parser.dart';
import 'vosk_stt_wrapper.dart';

/// Speech in both directions: Voyager talking, and — once Vosk is bound —
/// Voyager listening.
///
/// This plugin is never the fullscreen one. Speech happens over whatever is on
/// screen; putting it behind a tab would mean navigating away from the map to
/// ask a question, which defeats the purpose.
class VoicePlugin extends BasePlugin {
  final OpenSourceConfig config;

  /// Needed to act on a command: voice is the one plugin whose whole job is
  /// making other plugins do things.
  final PluginService plugins;

  final SpeechService speech;
  VoskSttWrapper? _stt;
  VoiceCommandParser _parser = const VoiceCommandParser(italian: false);

  bool _ready = false;
  bool _listening = false;
  VoiceCommand? _lastCommand;

  VoicePlugin({
    required this.config,
    required this.plugins,
    SpeechService? speechService,
  }) : speech = speechService ?? SpeechService();

  bool get isListening => _listening;
  bool get canListen => _stt?.isAvailable ?? false;
  VoiceCommand? get lastCommand => _lastCommand;

  @override
  PluginManifest get manifest => const PluginManifest(
        id: 'voice',
        label: 'Voice',
        icon: Icons.mic_rounded,
        order: 5,
        // Speech is an overlay concern, not a destination.
        canBeFullscreen: false,
        providesOverlay: true,
        // Above music, below a call: the driver pressed the key a moment ago
        // and needs to know it is listening.
        overlayPriority: 2,
      );

  @override
  bool get isReady => _ready;

  @override
  Future<void> initialize() async {
    await speech.initialize(_languageCode);
    if (config.hasVosk) {
      _stt = VoskSttWrapper(modelPath: config.voskModelPath!);
      await _stt!.initialize();
    }
    _ready = true;
    notifyListeners();
  }

  /// Language for both synthesis and command matching.
  ///
  /// Read from the platform rather than from Voyager's settings: the user
  /// already chose a system language, and asking a second time is a setting
  /// nobody wants to maintain.
  String get _languageCode =>
      WidgetsBinding.instance.platformDispatcher.locale.languageCode;

  void configureLanguage(String languageCode) {
    speech.setLanguage(languageCode);
    _parser = VoiceCommandParser(italian: languageCode == 'it');
  }

  Future<void> say(String text, {bool urgent = false}) =>
      speech.speak(text, urgent: urgent);

  /// Captures one utterance and acts on it.
  ///
  /// Returns the command that was executed, or null when recognition is
  /// unavailable or nothing usable was heard. The caller is expected to have
  /// given some non-visual feedback first (a tone, a haptic) — a driver who
  /// pressed the wheel button needs to know the app is listening without
  /// looking at it.
  Future<VoiceCommand?> listenOnce() async {
    final stt = _stt;
    if (stt == null || !stt.isAvailable) {
      await say(_parser.italian
          ? 'I comandi vocali non sono disponibili.'
          : 'Voice commands are not available.');
      return null;
    }

    _listening = true;
    notifyListeners();
    try {
      final transcript = await stt.listen(const Duration(seconds: 6));
      if (transcript == null) return null;
      final command = _parser.parse(transcript);
      _lastCommand = command;
      await _execute(command);
      return command;
    } catch (error) {
      AutomotiveLogger.warn('Voice', 'listen failed: $error');
      return null;
    } finally {
      _listening = false;
      notifyListeners();
    }
  }

  Future<void> _execute(VoiceCommand command) async {
    if (!command.isActionable) {
      await say(_parser.italian ? 'Non ho capito.' : "I didn't catch that.");
      return;
    }
    final music = plugins.byId('music');
    switch (command.intent) {
      case VoiceIntent.playMusic:
        await (music as MusicPlugin?)?.shuffleAll();
      case VoiceIntent.pauseMusic:
        await (music as MusicPlugin?)?.togglePlayPause();
      case VoiceIntent.nextTrack:
        await (music as MusicPlugin?)?.next();
      case VoiceIntent.previousTrack:
        await (music as MusicPlugin?)?.previous();
      case VoiceIntent.showNavigation:
        plugins.activate('navigation');
      case VoiceIntent.showWeather:
        plugins.activate('weather');
      default:
        // Routing, telephony and message reading need a control surface that
        // Roadstr and the phone plugin do not expose yet. Saying so is better
        // than silently doing nothing.
        await say(_parser.italian
            ? 'Non posso ancora farlo.'
            : 'I cannot do that yet.');
    }
  }

  @override
  Widget buildFullscreenView(BuildContext context) =>
      // Never reached: the manifest forbids fullscreen. Implemented anyway
      // because the base class requires it, and returning the status sheet
      // keeps a future change from producing a blank pane.
      AutomotiveVoiceAssistant(plugin: this);

  @override
  bool get wantsOverlay => _listening;

  @override
  Widget? buildOverlay(BuildContext context) =>
      _listening ? AutomotiveVoiceAssistant(plugin: this) : null;

  @override
  bool onPhysicalButtonPress(GestureEvent event) {
    if (event.button != PhysicalButton.voice) return false;
    unawaited(listenOnce());
    return true;
  }

  @override
  void dispose() {
    _stt?.dispose();
    unawaited(speech.dispose());
    super.dispose();
  }
}
