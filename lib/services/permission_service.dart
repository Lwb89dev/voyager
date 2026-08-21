import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../utils/logger_automotive.dart';

/// State of one permission, as the onboarding needs to show it.
enum PermissionState {
  /// Never asked, or asked and dismissed. Asking again will show the dialog.
  askable,

  granted,

  /// Refused permanently — on Android, refused twice. The system will not show
  /// the dialog again, so the only route left is the app's settings page.
  blocked,

  /// The device cannot do this at all: no SIM, no microphone, no GPS.
  unavailable,
}

/// The runtime permissions Voyager asks for, in one place.
///
/// Location goes through geolocator, because geolocator needs to be the one to
/// know; everything else goes through permission_handler. The split is not
/// elegant, but having two packages disagree about whether location was
/// granted is worse than one asymmetric method.
///
/// Nothing here is requested at launch. Each permission is asked for by the
/// screen that needs it, with the reason on screen next to the button — a
/// dialog that appears with no explanation gets refused, and on Android a
/// second refusal is permanent.
class PermissionService {
  const PermissionService._();

  // ── Location ────────────────────────────────────────────────────────────

  static Future<PermissionState> locationState() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      // The permission may well be granted; the radio is switched off. Treated
      // as askable so the user is sent to the system toggle rather than being
      // told the permission is broken.
      return PermissionState.askable;
    }
    return _fromGeolocator(await Geolocator.checkPermission());
  }

  static Future<PermissionState> requestLocation() async {
    final current = await Geolocator.checkPermission();
    if (current == LocationPermission.deniedForever) {
      return PermissionState.blocked;
    }
    return _fromGeolocator(await Geolocator.requestPermission());
  }

  static PermissionState _fromGeolocator(LocationPermission permission) {
    switch (permission) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return PermissionState.granted;
      case LocationPermission.deniedForever:
        return PermissionState.blocked;
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        return PermissionState.askable;
    }
  }

  // ── Notifications ───────────────────────────────────────────────────────

  /// Guidance and playback controls live in a notification, so on Android 13+
  /// a refused notification permission means no media controls on the lock
  /// screen and no visible turn prompts with the screen off. Audio still
  /// plays, which is why this is asked for rather than demanded.
  static Future<PermissionState> notificationState() =>
      _state(Permission.notification);

  static Future<PermissionState> requestNotifications() =>
      _request(Permission.notification);

  // ── Telephony and messaging ─────────────────────────────────────────────

  /// Phone and SMS are requested together: the phone plugin is only useful
  /// with both, and asking twice in a row for what the user experiences as one
  /// feature is how permission fatigue starts.
  ///
  /// Returns granted only when every permission in the group was granted —
  /// a half-granted phone plugin would show callers but be unable to answer.
  static Future<PermissionState> telephonyState() async {
    final states = await Future.wait([
      _state(Permission.phone),
      _state(Permission.sms),
      _state(Permission.contacts),
    ]);
    return _combine(states);
  }

  static Future<PermissionState> requestTelephony() async {
    final results = await [
      Permission.phone,
      Permission.sms,
      // Only so an incoming call can show a name instead of a number. Voyager
      // never reads the contact list itself; Android resolves the single
      // number on the native side.
      Permission.contacts,
    ].request();
    final states = results.values.map(_fromStatus).toList();
    return _combine(states);
  }

  // ── Audio files on the device ───────────────────────────────────────────

  /// Reading the shared music library.
  ///
  /// permission_handler's `Permission.audio` maps to READ_MEDIA_AUDIO on
  /// Android 13+ and to READ_EXTERNAL_STORAGE below it, which is exactly the
  /// split the manifest declares. Without it the local library is empty no
  /// matter which folder the user points at.
  static Future<PermissionState> audioState() => _state(Permission.audio);

  static Future<PermissionState> requestAudio() => _request(Permission.audio);

  // ── Microphone, for when Vosk lands ─────────────────────────────────────

  static Future<PermissionState> microphoneState() =>
      _state(Permission.microphone);

  static Future<PermissionState> requestMicrophone() =>
      _request(Permission.microphone);

  /// Opens the app's page in the system settings. The only way back from
  /// [PermissionState.blocked].
  static Future<bool> openSettings() => openAppSettings();

  static Future<PermissionState> _state(Permission permission) async {
    try {
      return _fromStatus(await permission.status);
    } catch (error) {
      AutomotiveLogger.warn('Permissions', '${permission.value}: $error');
      return PermissionState.unavailable;
    }
  }

  static Future<PermissionState> _request(Permission permission) async {
    try {
      return _fromStatus(await permission.request());
    } catch (error) {
      AutomotiveLogger.warn('Permissions', '${permission.value}: $error');
      return PermissionState.unavailable;
    }
  }

  static PermissionState _fromStatus(PermissionStatus status) {
    if (status.isGranted || status.isLimited || status.isProvisional) {
      return PermissionState.granted;
    }
    if (status.isPermanentlyDenied) return PermissionState.blocked;
    if (status.isRestricted) return PermissionState.unavailable;
    return PermissionState.askable;
  }

  /// The weakest state in the group wins, because the feature needs all of it.
  static PermissionState _combine(List<PermissionState> states) {
    if (states.contains(PermissionState.unavailable)) {
      return PermissionState.unavailable;
    }
    if (states.contains(PermissionState.blocked)) return PermissionState.blocked;
    if (states.contains(PermissionState.askable)) return PermissionState.askable;
    return PermissionState.granted;
  }
}
