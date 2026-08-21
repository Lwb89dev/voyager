import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:voyager/models/plugin_manifest.dart';
import 'package:voyager/plugins/base_plugin.dart';
import 'package:voyager/services/automotive_gesture_service.dart';
import 'package:voyager/services/automotive_ui_service.dart';
import 'package:voyager/services/plugin_service.dart';
import 'package:voyager/theme/voyager_theme.dart';
import 'package:voyager/widgets/automotive_chrome.dart';
import 'package:voyager/widgets/automotive_dashboard.dart';

class StubPlugin extends BasePlugin {
  StubPlugin(this._id, this._order);

  final String _id;
  final int _order;
  bool _ready = false;

  @override
  PluginManifest get manifest => PluginManifest(
        id: _id,
        label: _id,
        icon: Icons.circle,
        order: _order,
      );

  @override
  bool get isReady => _ready;

  @override
  Future<void> initialize() async {
    _ready = true;
    notifyListeners();
  }

  @override
  Widget buildFullscreenView(BuildContext context) =>
      Center(child: Text('$_id pane'));
}

Future<void> pump(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final plugins = PluginService()
    ..register(StubPlugin('navigation', 0))
    ..register(StubPlugin('music', 1));
  await plugins.initializeAll();

  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: plugins),
      ChangeNotifierProvider.value(value: AutomotiveUiService()),
      Provider.value(value: AutomotiveGestureService()),
    ],
    child: MaterialApp(
      theme: VoyagerTheme.dark,
      home: const AutomotiveDashboard(),
    ),
  ));
  await tester.pump();
}

void main() {
  late Directory hiveDir;

  setUpAll(() async {
    // The dashboard reads and writes the collapsed flag, so it needs a real box.
    hiveDir = await Directory.systemTemp.createTemp('voyager_test');
    Hive.init(hiveDir.path);
    await Hive.openBox('settings');
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDir.delete(recursive: true);
  });

  setUp(() => Hive.box('settings').clear());

  // One floating layout, used in every orientation — see the class doc on
  // AutomotiveDashboard for why the portrait/landscape split it replaced was
  // removed rather than kept alongside it.
  for (final orientation in ['portrait', 'landscape']) {
    final size = orientation == 'portrait'
        ? const Size(1080, 2400)
        : const Size(2400, 1080);

    testWidgets('$orientation: the chrome floats over a full-bleed plugin',
        (tester) async {
      await pump(tester, size);

      expect(find.byType(AutomotiveChrome), findsOneWidget);

      final pane = tester.getRect(find.text('navigation pane'));
      final screen = tester.getRect(find.byType(AutomotiveDashboard));
      final reserved = AutomotiveChrome.reservedHeight(collapsed: false);

      // Centred in what is left, which is the screen minus the chrome — not
      // squeezed into 7/10 of the height the way a docked bar would leave it.
      expect(pane.center.dy, closeTo((screen.height - reserved) / 2, 4));
      expect(pane.center.dy, lessThan(screen.height * 0.5));
    });
  }

  testWidgets('collapsing reclaims height from the chrome', (tester) async {
    expect(
      AutomotiveChrome.reservedHeight(collapsed: true),
      lessThan(AutomotiveChrome.reservedHeight(collapsed: false)),
    );
  });
}
