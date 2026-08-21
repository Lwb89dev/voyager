import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:voyager/models/plugin_manifest.dart';
import 'package:voyager/plugins/base_plugin.dart';
import 'package:voyager/services/automotive_gesture_service.dart';
import 'package:voyager/services/automotive_ui_service.dart';
import 'package:voyager/services/plugin_service.dart';
import 'package:voyager/theme/voyager_theme.dart';
import 'package:voyager/widgets/automotive_dashboard.dart';

/// A plugin with a view the test can find, standing in for a real one.
///
/// The real plugins are not used here on purpose: the music plugin wants an
/// audio session, the navigation plugin wants a GPS fix, and the phone plugin
/// wants a SIM. What this test is actually about is the dashboard — that the
/// chrome renders, that switching panes works, and that a plugin which never
/// comes up degrades to a message instead of a blank screen.
class StubPlugin extends BasePlugin {
  StubPlugin(this._id, this._order, {this.failsWith});

  final String _id;
  final int _order;
  final String? failsWith;
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
  String? get initializationError => failsWith;

  @override
  Future<void> initialize() async {
    _ready = failsWith == null;
    notifyListeners();
  }

  @override
  Widget buildFullscreenView(BuildContext context) =>
      Center(child: Text('$_id pane'));
}

Future<void> pumpDashboard(WidgetTester tester, PluginService plugins) async {
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
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows the first plugin and its button bar', (tester) async {
    final plugins = PluginService()
      ..register(StubPlugin('navigation', 0))
      ..register(StubPlugin('music', 1));
    await plugins.initializeAll();

    await pumpDashboard(tester, plugins);

    expect(find.text('navigation pane'), findsOneWidget);
    expect(find.text('music'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('switches panes without losing the other one', (tester) async {
    final plugins = PluginService()
      ..register(StubPlugin('navigation', 0))
      ..register(StubPlugin('music', 1));
    await plugins.initializeAll();
    await pumpDashboard(tester, plugins);

    await tester.tap(find.text('music'));
    await tester.pumpAndSettle();

    expect(plugins.active?.id, 'music');
    // Both panes are still in the tree — the IndexedStack keeps the map alive
    // so returning to it does not re-acquire a fix.
    expect(find.text('navigation pane', skipOffstage: false), findsOneWidget);
  });

  testWidgets('a failed plugin shows its reason, not a blank pane',
      (tester) async {
    final plugins = PluginService()
      ..register(StubPlugin('music', 0, failsWith: 'Music server unreachable'));
    await plugins.initializeAll();

    await pumpDashboard(tester, plugins);

    expect(find.text('Music server unreachable'), findsOneWidget);
  });
}
