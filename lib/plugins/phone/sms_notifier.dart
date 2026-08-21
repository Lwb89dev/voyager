import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../utils/logger_automotive.dart';

class SmsMessage {
  final String sender;
  final String body;
  final DateTime at;

  const SmsMessage({
    required this.sender,
    required this.body,
    required this.at,
  });
}

/// Incoming text messages, surfaced for the length of one drive and no longer.
///
/// The retention policy is the whole design here. Messages live in memory,
/// capped at [_maxRetained], and are dropped when the app exits. Nothing is
/// written to Hive, nothing is written to a log, and there is no history
/// screen — because a message list that survives the drive turns a car
/// dashboard into a second copy of someone's inbox, sitting in a device
/// mounted in plain view on a windscreen.
class SmsNotifier extends ChangeNotifier {
  static const MethodChannel _channel =
      MethodChannel('com.voyager.voyager/sms');

  /// Enough to catch up on what arrived during a stretch of concentration,
  /// not enough to be an archive.
  static const int _maxRetained = 10;

  final List<SmsMessage> _messages = [];
  bool _available = false;

  List<SmsMessage> get messages => List.unmodifiable(_messages);
  SmsMessage? get latest => _messages.isEmpty ? null : _messages.first;
  bool get isAvailable => _available;

  Future<void> startListening() async {
    _channel.setMethodCallHandler(_onNativeCall);
    try {
      _available = await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } on PlatformException catch (error) {
      AutomotiveLogger.warn('SMS', 'unavailable: ${error.code}');
      _available = false;
    } on MissingPluginException {
      _available = false;
    }
    notifyListeners();
  }

  Future<void> _onNativeCall(MethodCall call) async {
    if (call.method != 'messageReceived') return;
    final args = (call.arguments as Map?) ?? const {};
    _messages.insert(
      0,
      SmsMessage(
        sender: (args['sender'] ?? '').toString(),
        body: (args['body'] ?? '').toString(),
        at: DateTime.now(),
      ),
    );
    if (_messages.length > _maxRetained) _messages.removeLast();
    notifyListeners();
  }

  /// Drops everything. Called when the user leaves the phone pane, so a
  /// passenger picking the device up later finds nothing.
  void clear() {
    if (_messages.isEmpty) return;
    _messages.clear();
    notifyListeners();
  }
}
