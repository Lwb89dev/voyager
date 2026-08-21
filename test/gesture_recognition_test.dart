import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voyager/models/gesture_event.dart';
import 'package:voyager/services/automotive_gesture_service.dart';

KeyEvent down(LogicalKeyboardKey key) => KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.keyA,
      logicalKey: key,
      timeStamp: Duration.zero,
    );

KeyEvent up(LogicalKeyboardKey key) => KeyUpEvent(
      physicalKey: PhysicalKeyboardKey.keyA,
      logicalKey: key,
      timeStamp: Duration.zero,
    );

KeyEvent repeat(LogicalKeyboardKey key) => KeyRepeatEvent(
      physicalKey: PhysicalKeyboardKey.keyA,
      logicalKey: key,
      timeStamp: Duration.zero,
    );

void main() {
  // dispose() detaches from HardwareKeyboard, which needs a binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  late AutomotiveGestureService service;
  late List<GestureEvent> seen;

  setUp(() {
    service = AutomotiveGestureService();
    seen = [];
    service.events.listen(seen.add);
  });

  tearDown(() => service.dispose());

  test('media keys are always claimed', () async {
    expect(service.handleKeyEvent(down(LogicalKeyboardKey.mediaTrackNext)),
        isTrue);
    await pumpEventQueue();
    expect(seen.single.button, PhysicalButton.mediaNext);
  });

  test('volume keys pass through to the system by default', () async {
    // Swallowing the volume keys on a device that is not in a car — or on a
    // head unit whose wheel already sends media keys — would break volume
    // control entirely, so the remap is opt-in.
    expect(service.handleKeyEvent(down(LogicalKeyboardKey.audioVolumeUp)),
        isFalse);
    await pumpEventQueue();
    expect(seen, isEmpty);
  });

  test('volume keys become track skips once remapped', () async {
    service.remapVolumeKeys = true;
    expect(service.handleKeyEvent(down(LogicalKeyboardKey.audioVolumeUp)),
        isTrue);
    expect(service.handleKeyEvent(down(LogicalKeyboardKey.audioVolumeDown)),
        isTrue);
    await pumpEventQueue();
    expect(seen.map((e) => e.button),
        [PhysicalButton.volumeUp, PhysicalButton.volumeDown]);
  });

  test('key-up events are ignored', () async {
    service.handleKeyEvent(up(LogicalKeyboardKey.mediaTrackNext));
    await pumpEventQueue();
    expect(seen, isEmpty);
  });

  test('a held key is reported as a repeat', () async {
    service.handleKeyEvent(repeat(LogicalKeyboardKey.mediaTrackNext));
    await pumpEventQueue();
    expect(seen.single.isRepeat, isTrue);
  });

  test('unmapped keys are left alone', () async {
    expect(service.handleKeyEvent(down(LogicalKeyboardKey.keyQ)), isFalse);
    await pumpEventQueue();
    expect(seen, isEmpty);
  });

  test('the assistant key maps to voice', () async {
    service.handleKeyEvent(down(LogicalKeyboardKey.launchAssistant));
    await pumpEventQueue();
    expect(seen.single.button, PhysicalButton.voice);
  });
}
