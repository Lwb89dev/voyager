import 'dart:async';

import 'package:flutter/material.dart';
import 'package:roadstr/services/kokoro/kokoro_model_manager.dart';
import 'package:roadstr/services/kokoro/kokoro_tts_service.dart';
import 'package:roadstr/services/kokoro/kokoro_voices.dart';

import '../l10n/voyager_strings.dart';
import '../plugins/voice/vosk_model_manager.dart';
import '../theme/voyager_theme.dart';

enum _ModelStatus { unknown, notDownloaded, downloading, ready, unsupported }

/// Kokoro's model-download card: status, a progress bar while fetching, and —
/// once ready — the gender/speed controls a driver actually cares about.
///
/// Shared between Settings and onboarding (see [VoskVoiceCard]'s doc for why
/// that sharing matters): the exact same widget, so a driver who skipped this
/// during setup sees the identical control later rather than a differently
/// laid out "second chance" version.
class KokoroVoiceCard extends StatefulWidget {
  final VoyagerPalette vc;
  const KokoroVoiceCard({super.key, required this.vc});

  @override
  State<KokoroVoiceCard> createState() => _KokoroVoiceCardState();
}

class _KokoroVoiceCardState extends State<KokoroVoiceCard> {
  _ModelStatus _status = _ModelStatus.unknown;
  double _progress = 0;
  String? _error;
  bool _previewing = false;

  final _previewTts = KokoroTtsService();
  StreamSubscription<double>? _progressSub;
  StreamSubscription<String>? _errorSub;

  @override
  void initState() {
    super.initState();
    final mgr = KokoroModelManager.instance;
    if (mgr.isDownloading) {
      _status = _ModelStatus.downloading;
      _progress = mgr.lastProgress;
    } else {
      unawaited(_check());
    }
    _progressSub = mgr.progressStream.listen((p) {
      if (!mounted) return;
      setState(() {
        _progress = p;
        if (p >= 1.0) _status = _ModelStatus.ready;
      });
    });
    _errorSub = mgr.errorStream.listen((err) {
      if (!mounted) return;
      setState(() {
        _status = _ModelStatus.notDownloaded;
        _error = err;
      });
    });
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    _errorSub?.cancel();
    unawaited(_previewTts.dispose());
    super.dispose();
  }

  Future<void> _check() async {
    final ready =
        await KokoroModelManager.instance.isReady(kokoroSupportedLanguages);
    if (mounted) {
      setState(() =>
          _status = ready ? _ModelStatus.ready : _ModelStatus.notDownloaded);
    }
  }

  void _download() {
    setState(() {
      _status = _ModelStatus.downloading;
      _progress = 0;
      _error = null;
    });
    KokoroModelManager.instance.startDownload(kokoroSupportedLanguages);
  }

  Future<void> _preview(String gender) async {
    if (_status != _ModelStatus.ready || _previewing) return;
    final uiLang = Localizations.localeOf(context).languageCode;
    final lang = kokoroSupportedLanguages.contains(uiLang) ? uiLang : 'en';
    setState(() => _previewing = true);
    try {
      _previewTts.setGender(gender);
      await _previewTts.init(lang);
      await _previewTts.previewVoice();
    } finally {
      if (mounted) setState(() => _previewing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = VoyagerStrings.of(context);
    final vc = widget.vc;
    return _VoiceCard(
      vc: vc,
      icon: Icons.record_voice_over_rounded,
      title: s.kokoroCardTitle,
      body: s.kokoroCardBody,
      status: _status,
      progress: _progress,
      error: _error,
      onDownload: _download,
      trailing: _status == _ModelStatus.ready
          ? _GenderSpeedControls(
              vc: vc, previewing: _previewing, onPreview: _preview)
          : null,
    );
  }
}

class _GenderSpeedControls extends StatelessWidget {
  final VoyagerPalette vc;
  final bool previewing;
  final ValueChanged<String> onPreview;

  const _GenderSpeedControls({
    required this.vc,
    required this.previewing,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    final s = VoyagerStrings.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: previewing ? null : () => onPreview('f'),
              icon: const Icon(Icons.female_rounded, size: 16),
              label: Text(s.kokoroVoiceFemale),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: previewing ? null : () => onPreview('m'),
              icon: const Icon(Icons.male_rounded, size: 16),
              label: Text(s.kokoroVoiceMale),
            ),
          ),
        ],
      ),
    );
  }
}

/// Vosk's model-download card.
///
/// Deliberately the same widget in Settings and onboarding: the user asked
/// for the download to be reachable from both places for the person who
/// skips it during setup, and the surest way to keep those two in sync as the
/// card's own logic changes later is for them to be the same widget rather
/// than two hand-copied ones that drift apart.
class VoskVoiceCard extends StatefulWidget {
  final VoyagerPalette vc;
  const VoskVoiceCard({super.key, required this.vc});

  @override
  State<VoskVoiceCard> createState() => _VoskVoiceCardState();
}

class _VoskVoiceCardState extends State<VoskVoiceCard> {
  _ModelStatus _status = _ModelStatus.unknown;
  double _progress = 0;
  String? _error;

  StreamSubscription<double>? _progressSub;
  StreamSubscription<String>? _errorSub;

  String get _languageCode =>
      WidgetsBinding.instance.platformDispatcher.locale.languageCode;

  @override
  void initState() {
    super.initState();
    final mgr = VoskModelManager.instance;
    if (VoskModel.forLanguage(_languageCode) == null) {
      _status = _ModelStatus.unsupported;
    } else if (mgr.isDownloading) {
      _status = _ModelStatus.downloading;
      _progress = mgr.lastProgress;
    } else {
      unawaited(_check());
    }
    _progressSub = mgr.progressStream.listen((p) {
      if (!mounted) return;
      setState(() {
        _progress = p;
        if (p >= 1.0) _status = _ModelStatus.ready;
      });
    });
    _errorSub = mgr.errorStream.listen((err) {
      if (!mounted) return;
      setState(() {
        _status = _ModelStatus.notDownloaded;
        _error = err;
      });
    });
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    _errorSub?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    final ready = await VoskModelManager.instance.isReady(_languageCode);
    if (mounted) {
      setState(() =>
          _status = ready ? _ModelStatus.ready : _ModelStatus.notDownloaded);
    }
  }

  void _download() {
    setState(() {
      _status = _ModelStatus.downloading;
      _progress = 0;
      _error = null;
    });
    VoskModelManager.instance.startDownload(_languageCode);
  }

  @override
  Widget build(BuildContext context) {
    final s = VoyagerStrings.of(context);
    return _VoiceCard(
      vc: widget.vc,
      icon: Icons.mic_rounded,
      title: s.voskCardTitle,
      body: s.voskCardBody,
      status: _status,
      progress: _progress,
      error: _error,
      onDownload: _download,
      unsupportedMessage: s.voskUnsupportedLanguage,
    );
  }
}

class _VoiceCard extends StatelessWidget {
  final VoyagerPalette vc;
  final IconData icon;
  final String title;
  final String body;
  final _ModelStatus status;
  final double progress;
  final String? error;
  final VoidCallback onDownload;
  final Widget? trailing;
  final String? unsupportedMessage;

  const _VoiceCard({
    required this.vc,
    required this.icon,
    required this.title,
    required this.body,
    required this.status,
    required this.progress,
    required this.error,
    required this.onDownload,
    this.trailing,
    this.unsupportedMessage,
  });

  @override
  Widget build(BuildContext context) {
    final s = VoyagerStrings.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: vc.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: vc.accentLight, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: vc.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (status == _ModelStatus.ready)
                Icon(Icons.check_circle_rounded, color: vc.success, size: 20),
            ],
          ),
          const SizedBox(height: 6),
          Text(body, style: TextStyle(color: vc.textSecondary, fontSize: 12)),
          if (status == _ModelStatus.unsupported) ...[
            const SizedBox(height: 10),
            Text(unsupportedMessage ?? '',
                style: TextStyle(
                    color: vc.textSecondary,
                    fontSize: 12,
                    fontStyle: FontStyle.italic)),
          ] else if (status == _ModelStatus.downloading) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: vc.border,
                color: vc.accent,
                minHeight: 5,
              ),
            ),
            const SizedBox(height: 4),
            Text('${(progress * 100).round()}% · ${s.voiceModelDownloading}',
                style: TextStyle(color: vc.textSecondary, fontSize: 11)),
          ] else if (status == _ModelStatus.notDownloaded ||
              status == _ModelStatus.unknown) ...[
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(s.voiceModelError(error!),
                  style: TextStyle(color: vc.danger, fontSize: 11)),
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onDownload,
                style: FilledButton.styleFrom(
                  backgroundColor: vc.accent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                icon: const Icon(Icons.download_rounded, size: 20),
                label: Text(
                    error == null ? s.voiceModelDownload : s.voiceModelRetry),
              ),
            ),
          ],
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
