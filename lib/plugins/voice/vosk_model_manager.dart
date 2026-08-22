import 'dart:async';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../services/open_source_config.dart';

/// A small Vosk model, downloadable straight from the source Voyager ships
/// commands for — see `docs/SETUP_VOSK_STT.md`. Sizes are approximate, from
/// the official catalogue at https://alphacephei.com/vosk/models; actual
/// integrity checking is the ZIP's own per-entry CRC32, verified during
/// extraction, since Alphacephei does not publish checksums to compare
/// against up front.
class VoskModel {
  final String languageCode;
  final String label;
  final String url;
  final int approxSizeBytes;

  const VoskModel({
    required this.languageCode,
    required this.label,
    required this.url,
    required this.approxSizeBytes,
  });

  static const it = VoskModel(
    languageCode: 'it',
    label: 'Italiano',
    url: 'https://alphacephei.com/vosk/models/vosk-model-small-it-0.22.zip',
    approxSizeBytes: 48 * 1024 * 1024,
  );

  static const en = VoskModel(
    languageCode: 'en',
    label: 'English',
    url: 'https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip',
    approxSizeBytes: 40 * 1024 * 1024,
  );

  static const all = [it, en];

  static VoskModel? forLanguage(String languageCode) =>
      all.where((m) => m.languageCode == languageCode).firstOrNull;
}

/// Downloads and unpacks a Vosk speech-recognition model, mirroring the shape
/// of Roadstr's `KokoroModelManager` — a singleton so a download survives a
/// settings-screen rebuild, with progress and error broadcast streams.
///
/// This is the half of speech recognition that is genuinely just plumbing: a
/// zip fetched and extracted to disk. The half that is not — binding
/// `libvosk.so` through FFI and actually running recognition — is tracked
/// separately in `VoskSttWrapper` and `docs/SETUP_VOSK_STT.md`. A downloaded
/// model makes [OpenSourceConfig.hasVosk] true and gives that future binding
/// something to load; it does not, on its own, make Voyager listen.
class VoskModelManager {
  VoskModelManager._();
  static final VoskModelManager instance = VoskModelManager._();

  Directory? _dir;

  bool _downloading = false;
  double _lastProgress = 0;

  final _progressCtrl = StreamController<double>.broadcast();
  final _errorCtrl = StreamController<String>.broadcast();

  bool get isDownloading => _downloading;
  double get lastProgress => _lastProgress;
  Stream<double> get progressStream => _progressCtrl.stream;
  Stream<String> get errorStream => _errorCtrl.stream;

  Future<Directory> _voskDir() async {
    if (_dir != null) return _dir!;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/vosk');
    if (!await dir.exists()) await dir.create(recursive: true);
    _dir = dir;
    return dir;
  }

  /// Where a downloaded model for [languageCode] lives once extracted — the
  /// path `VoskSttWrapper` expects, and what `startDownload` writes into
  /// `OpenSourceConfig.voskModelPath` on success.
  Future<String> modelPath(String languageCode) async =>
      '${(await _voskDir()).path}/$languageCode';

  Future<bool> isReady(String languageCode) async {
    final dir = Directory(await modelPath(languageCode));
    if (!await dir.exists()) return false;
    // A real Vosk model directory always has these two — cheap enough to
    // check that a half-extracted or manually-deleted model reports false
    // rather than a stale true.
    final hasAm = await File('${dir.path}/am/final.mdl').exists();
    final hasConf = await Directory('${dir.path}/conf').exists();
    return hasAm && hasConf;
  }

  /// Start a background download+extract for [languageCode]. A no-op if a
  /// download is already running, or if there is no small model for that
  /// language — Vosk's catalogue does not cover every language Voyager's own
  /// UI does.
  void startDownload(String languageCode) {
    if (_downloading) return;
    final model = VoskModel.forLanguage(languageCode);
    if (model == null) {
      _errorCtrl.add('No Vosk model available for "$languageCode"');
      return;
    }
    unawaited(_download(model));
  }

  Future<void> _download(VoskModel model) async {
    _downloading = true;
    _lastProgress = 0;
    _progressCtrl.add(0);
    final dir = await _voskDir();
    // Downloaded under a `.part` name so a half-written file never looks like
    // a finished one, then renamed to `.zip` before extraction —
    // `extractFileToDisk` below picks its decoder from the file extension,
    // and ".part" isn't one it recognises: it throws "No file extension
    // detected" (as `ArgumentError.value(inputPath, ...)`) rather than
    // extracting a file that is, in fact, a complete zip.
    final partPath = '${dir.path}/${model.languageCode}.zip.part';
    final zipPath = '${dir.path}/${model.languageCode}.zip';
    final partFile = File(partPath);
    final zipFile = File(zipPath);
    try {
      final client = http.Client();
      try {
        final request = http.Request('GET', Uri.parse(model.url));
        final response =
            await client.send(request).timeout(const Duration(seconds: 20));
        if (response.statusCode != 200) {
          throw Exception('Vosk download failed (${response.statusCode})');
        }
        final total = response.contentLength ?? model.approxSizeBytes;
        final sink = partFile.openWrite();
        var received = 0;
        try {
          await response.stream
              .timeout(const Duration(seconds: 30))
              .forEach((chunk) {
            sink.add(chunk);
            received += chunk.length;
            if (total > 0) {
              final p = (received / total).clamp(0.0, 0.95);
              _lastProgress = p;
              _progressCtrl.add(p);
            }
          });
        } finally {
          await sink.close();
        }
      } finally {
        client.close();
      }

      if (await zipFile.exists()) await zipFile.delete();
      await partFile.rename(zipPath);

      // Extracted into a fresh, uniquely-named directory rather than
      // straight into the model's own folder, then swapped into place only
      // once fully built. Extracting in place — delete the old folder,
      // recreate it, extract — left a window where a retry's fresh files and
      // a previous attempt's leftovers could collide on Android's storage
      // layer: renaming a just-extracted subfolder (e.g. `am/`) onto one of
      // the same name that a prior run had already left behind, only
      // partially cleaned up, failed with "OS error: directory not empty,
      // errno 39" instead of extracting a working model. Building somewhere
      // nothing else has ever written to removes the collision entirely.
      final scratchDir = await Directory.systemTemp
          .createTemp('voyager_vosk_${model.languageCode}_');
      try {
        // Extraction is the real integrity check: a truncated or corrupt
        // download fails a CRC32 check inside the archive package rather
        // than silently producing a model that loads garbage.
        await extractFileToDisk(zipPath, scratchDir.path);

        // The zip contains one top-level folder (e.g.
        // vosk-model-small-it-0.22/) rather than the model files directly —
        // flatten it so modelPath() points straight at am/, conf/, etc.
        final entries = await scratchDir.list().toList();
        if (entries.length == 1 && entries.first is Directory) {
          final inner = entries.first as Directory;
          for (final child in await inner.list().toList()) {
            await child
                .rename('${scratchDir.path}/${child.uri.pathSegments.last}');
          }
          await inner.delete(recursive: true);
        }

        final hasAm = await File('${scratchDir.path}/am/final.mdl').exists();
        final hasConf = await Directory('${scratchDir.path}/conf').exists();
        if (!hasAm || !hasConf) {
          throw Exception('Vosk model extracted but looks incomplete');
        }

        final targetDir = Directory(await modelPath(model.languageCode));
        if (await targetDir.exists()) {
          await targetDir.delete(recursive: true);
        }
        await scratchDir.rename(targetDir.path);

        final config = OpenSourceConfig.load();
        await config.copyWith(voskModelPath: targetDir.path).save();
      } finally {
        if (await scratchDir.exists()) await scratchDir.delete(recursive: true);
      }

      _lastProgress = 1.0;
      _progressCtrl.add(1.0);
    } catch (e) {
      _errorCtrl.add(e.toString());
    } finally {
      if (await partFile.exists()) await partFile.delete();
      if (await zipFile.exists()) await zipFile.delete();
      _downloading = false;
    }
  }
}
