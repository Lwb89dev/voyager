import 'package:hive/hive.dart';

/// Every external endpoint Voyager can talk to, in one place.
///
/// All of it is optional and all of it is self-hostable. A field left null
/// means "that service is off", and the corresponding plugin registers itself
/// as disabled rather than showing a button that leads to an error. The one
/// exception is Open-Meteo, which needs no account, no key and no setup, so it
/// is a constant rather than a setting.
class OpenSourceConfig {
  /// Navidrome base URL, e.g. `http://192.168.1.100:4533`. No trailing slash.
  final String? navidromeEndpoint;
  final String? navidromeUsername;

  /// Stored in the AES-encrypted Hive settings box, never in plaintext.
  /// Subsonic's salted-token auth means this is only ever hashed onto the
  /// wire, but it is still a reusable credential at rest.
  final String? navidromePassword;

  /// Jellyfin base URL, e.g. `http://192.168.1.100:8096`.
  final String? jellyfinEndpoint;
  final String? jellyfinApiKey;
  final String? jellyfinUserId;

  /// Directory holding the Kokoro ONNX voice model, when the user has
  /// installed one. Null falls back to eSpeak-NG, which Roadstr already
  /// bundles: robotic but always available and about 30 MB smaller.
  final String? kokoroModelPath;

  /// Vosk speech model directory. Null disables speech recognition entirely
  /// and the voice plugin becomes speech-output-only.
  final String? voskModelPath;

  const OpenSourceConfig({
    this.navidromeEndpoint,
    this.navidromeUsername,
    this.navidromePassword,
    this.jellyfinEndpoint,
    this.jellyfinApiKey,
    this.jellyfinUserId,
    this.kokoroModelPath,
    this.voskModelPath,
  });

  /// Open-Meteo: free, keyless, CC BY-SA. Nothing to configure, so nothing is
  /// stored — a URL the user cannot change is not a setting.
  static const String openMeteoEndpoint =
      'https://api.open-meteo.com/v1/forecast';

  /// Client identifier sent to Subsonic servers. Servers show it in their
  /// session list, so it should say what it actually is.
  static const String clientName = 'voyager';

  bool get hasNavidrome =>
      _isSet(navidromeEndpoint) &&
      _isSet(navidromeUsername) &&
      _isSet(navidromePassword);

  bool get hasJellyfin =>
      _isSet(jellyfinEndpoint) && _isSet(jellyfinApiKey) &&
      _isSet(jellyfinUserId);

  bool get hasKokoro => _isSet(kokoroModelPath);
  bool get hasVosk => _isSet(voskModelPath);

  static bool _isSet(String? value) => value != null && value.trim().isNotEmpty;

  /// Reads the config out of the Hive `settings` box.
  ///
  /// That box is shared with Roadstr's own settings and is opened encrypted in
  /// `main`, so this must not be called before initialisation has finished.
  /// Keys are prefixed `voyager_` to stay clear of Roadstr's own keys in the
  /// same box.
  static OpenSourceConfig load() {
    final box = Hive.box('settings');
    String? read(String key) => box.get('voyager_$key') as String?;
    return OpenSourceConfig(
      navidromeEndpoint: read('navidrome_endpoint'),
      navidromeUsername: read('navidrome_username'),
      navidromePassword: read('navidrome_password'),
      jellyfinEndpoint: read('jellyfin_endpoint'),
      jellyfinApiKey: read('jellyfin_api_key'),
      jellyfinUserId: read('jellyfin_user_id'),
      kokoroModelPath: read('kokoro_model_path'),
      voskModelPath: read('vosk_model_path'),
    );
  }

  Future<void> save() async {
    final box = Hive.box('settings');
    await box.putAll({
      'voyager_navidrome_endpoint': navidromeEndpoint,
      'voyager_navidrome_username': navidromeUsername,
      'voyager_navidrome_password': navidromePassword,
      'voyager_jellyfin_endpoint': jellyfinEndpoint,
      'voyager_jellyfin_api_key': jellyfinApiKey,
      'voyager_jellyfin_user_id': jellyfinUserId,
      'voyager_kokoro_model_path': kokoroModelPath,
      'voyager_vosk_model_path': voskModelPath,
    });
  }

  OpenSourceConfig copyWith({
    String? navidromeEndpoint,
    String? navidromeUsername,
    String? navidromePassword,
    String? jellyfinEndpoint,
    String? jellyfinApiKey,
    String? jellyfinUserId,
    String? kokoroModelPath,
    String? voskModelPath,
  }) =>
      OpenSourceConfig(
        navidromeEndpoint: navidromeEndpoint ?? this.navidromeEndpoint,
        navidromeUsername: navidromeUsername ?? this.navidromeUsername,
        navidromePassword: navidromePassword ?? this.navidromePassword,
        jellyfinEndpoint: jellyfinEndpoint ?? this.jellyfinEndpoint,
        jellyfinApiKey: jellyfinApiKey ?? this.jellyfinApiKey,
        jellyfinUserId: jellyfinUserId ?? this.jellyfinUserId,
        kokoroModelPath: kokoroModelPath ?? this.kokoroModelPath,
        voskModelPath: voskModelPath ?? this.voskModelPath,
      );
}
