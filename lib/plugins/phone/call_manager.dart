import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../utils/logger_automotive.dart';

/// An incoming or ongoing call, as reported by the platform.
class CallInfo {
  /// Contact name when Android could resolve one, otherwise null. Resolution
  /// happens on the native side against the phone's own contact store; Voyager
  /// never reads contacts itself and never caches what comes back.
  final String? name;

  final String number;
  final DateTime since;

  const CallInfo({required this.number, this.name, required this.since});

  /// What to show on the big card. A number is better than nothing, but a name
  /// is what lets someone decide without reading digits at speed.
  String get display => name?.isNotEmpty == true ? name! : number;
}

/// Call state over Android's Telecom framework.
///
/// The heavy lifting is native: a `CallScreeningService`/`InCallService` sees
/// the call and pushes it here over a method channel. Doing it from Dart is
/// not possible — Android will not surface call state to a Flutter plugin
/// without a registered telecom component.
///
/// Answering works over Bluetooth HFP when the phone is paired to the car:
/// Voyager asks Telecom to accept, and the audio routes to whichever device
/// owns the HFP connection. Voyager never touches the audio itself.
class CallManager extends ChangeNotifier {
  static const MethodChannel _channel =
      MethodChannel('com.voyager.voyager/phone');

  CallInfo? _current;
  bool _available = false;

  CallInfo? get current => _current;

  /// False when the permissions were denied or the device has no telephony —
  /// a tablet in a van, most commonly. The phone plugin hides itself entirely
  /// in that case.
  bool get isAvailable => _available;

  Future<void> initialize() async {
    _channel.setMethodCallHandler(_onNativeCall);
    try {
      _available = await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } on PlatformException catch (error) {
      AutomotiveLogger.warn('Phone', 'telephony unavailable: ${error.code}');
      _available = false;
    } on MissingPluginException {
      // Expected on desktop and in unit tests, where the native side is not
      // registered at all.
      _available = false;
    }
    notifyListeners();
  }

  Future<void> _onNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'incomingCall':
        final args = (call.arguments as Map?) ?? const {};
        _current = CallInfo(
          number: (args['number'] ?? '').toString(),
          name: args['name']?.toString(),
          since: DateTime.now(),
        );
      case 'callEnded':
        _current = null;
      default:
        AutomotiveLogger.warn('Phone', 'unknown method ${call.method}');
        return;
    }
    notifyListeners();
  }

  Future<void> answer() => _invoke('answerCall');
  Future<void> reject() => _invoke('rejectCall');

  Future<void> _invoke(String method) async {
    try {
      await _channel.invokeMethod(method);
    } on PlatformException catch (error) {
      AutomotiveLogger.error('Phone', 'invoke $method failed', error.code);
    }
  }
}
