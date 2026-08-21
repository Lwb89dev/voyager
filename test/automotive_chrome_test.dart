import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voyager/models/plugin_manifest.dart';
import 'package:voyager/theme/voyager_theme.dart';
import 'package:voyager/widgets/automotive_chrome.dart';

const _hostKey = Key('host');

Widget host(Widget child, {double width = 800, double height = 400}) =>
    MaterialApp(
      theme: VoyagerTheme.dark,
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            key: _hostKey,
            width: width,
            height: height,
            child: child,
          ),
        ),
      ),
    );

const nav = PluginManifest(
  id: 'nav',
  label: 'Navigation',
  icon: Icons.navigation_rounded,
  order: 0,
);
const music = PluginManifest(
  id: 'music',
  label: 'Music',
  icon: Icons.music_note_rounded,
  order: 1,
);
const podcast = PluginManifest(
  id: 'podcast',
  label: 'Podcasts',
  icon: Icons.podcasts_rounded,
  order: 2,
);
const weather = PluginManifest(
  id: 'weather',
  label: 'Weather',
  icon: Icons.cloud_rounded,
  order: 3,
);

Widget chrome({
  List<PluginManifest> plugins = const [nav, music, podcast, weather],
  String? activeId = 'nav',
  bool collapsed = false,
  ValueChanged<String>? onSelected,
  VoidCallback? onToggleCollapsed,
}) =>
    AutomotiveChrome(
      plugins: plugins,
      activeId: activeId,
      onSelected: onSelected ?? (_) {},
      onSettings: () {},
      collapsed: collapsed,
      onToggleCollapsed: onToggleCollapsed ?? () {},
    );

void main() {
  group('AutomotiveChrome', () {
    testWidgets('shows every destination plus Settings and Hide',
        (tester) async {
      await tester.pumpWidget(host(chrome()));

      expect(find.byIcon(Icons.navigation_rounded), findsOneWidget);
      expect(find.byIcon(Icons.music_note_rounded), findsOneWidget);
      expect(find.byIcon(Icons.podcasts_rounded), findsOneWidget);
      expect(find.byIcon(Icons.cloud_rounded), findsOneWidget);
      expect(find.byIcon(Icons.settings_rounded), findsOneWidget);
      expect(find.byIcon(Icons.expand_more_rounded), findsOneWidget);
    });

    testWidgets('reports the plugin that was tapped', (tester) async {
      String? selected;
      await tester.pumpWidget(
        host(chrome(onSelected: (id) => selected = id)),
      );

      await tester.tap(find.byIcon(Icons.music_note_rounded));
      expect(selected, 'music');
    });

    testWidgets('collapses to a single handle showing the active icon',
        (tester) async {
      await tester.pumpWidget(host(chrome(collapsed: true, activeId: 'music')));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.music_note_rounded), findsOneWidget);
      expect(find.byIcon(Icons.settings_rounded), findsNothing);
      expect(find.byIcon(Icons.expand_less_rounded), findsOneWidget);
    });

    testWidgets(
        'stays clear of both screen edges on a narrow portrait phone, with '
        'every destination still reachable', (tester) async {
      // Four plugins + Settings + Hide at the 60 dp floor is the shape that
      // used to force this pill edge-to-edge — and, once it was that wide, to
      // overlap Roadstr's own bottom-left bar. Without a clock competing for
      // width, this now comfortably fits inside a ~400 dp-wide phone.
      await tester.pumpWidget(host(chrome(), width: 400, height: 800));

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.navigation_rounded), findsOneWidget);
      expect(find.byIcon(Icons.podcasts_rounded), findsOneWidget);
      expect(find.byIcon(Icons.settings_rounded), findsOneWidget);

      final pill = _pillRect(tester);
      final screen = tester.getRect(find.byKey(_hostKey));
      expect(pill.left, greaterThan(screen.left),
          reason: 'must not touch the left edge');
      expect(pill.right, lessThan(screen.right),
          reason: 'must not touch the right edge');
    });

    testWidgets('holds up under an unusually large number of plugins',
        (tester) async {
      // A defensive check, not a design target: whatever the plugin count
      // grows to, the bar must degrade (scroll, inset from the edges) rather
      // than overflow.
      final many = [
        for (var i = 0; i < 10; i++)
          PluginManifest(
            id: 'p$i',
            label: 'Plugin $i',
            icon: Icons.circle,
            order: i,
          ),
      ];
      await tester.pumpWidget(host(chrome(plugins: many), width: 400));

      expect(tester.takeException(), isNull);
      // Even the scrolling fallback keeps a margin — see the note on
      // AutomotiveChrome._buildBar. Measuring the *viewport* here, not the
      // scrollable content: the content is deliberately wider than the
      // viewport (that is what makes it scrollable) and clipped to it, so the
      // content's own rect is not the one that answers "does this reach the
      // screen edge."
      final viewport = tester.getRect(find.byType(SingleChildScrollView));
      final screen = tester.getRect(find.byKey(_hostKey));
      expect(viewport.left, greaterThan(screen.left));
      expect(viewport.right, lessThan(screen.right));
    });
  });
}

/// The painted pill's bounds.
///
/// [AutomotiveChrome] itself cannot be measured directly: its `Align` expands
/// to fill whatever space its parent offers, which is the *host's* size, not
/// the visually smaller pill positioned inside it. `_Surface` is the widget
/// that actually paints the pill's background, so its rect is the one that
/// answers "does this touch the edge" — found by runtime type name since it
/// is private to automotive_chrome.dart and cannot be imported.
Rect _pillRect(WidgetTester tester) => tester.getRect(find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == '_Surface',
    ));
