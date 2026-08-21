import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voyager/models/plugin_manifest.dart';
import 'package:voyager/theme/voyager_theme.dart';
import 'package:voyager/widgets/plugin_placeholder.dart';

Widget host(Widget child) => MaterialApp(
      theme: VoyagerTheme.dark,
      home: Scaffold(body: Center(child: child)),
    );

const manifest = PluginManifest(
  id: 'music',
  label: 'Music',
  icon: Icons.music_note_rounded,
  order: 1,
);

void main() {
  group('PluginPlaceholder', () {
    testWidgets('shows a spinner while a plugin is still loading',
        (tester) async {
      await tester.pumpWidget(host(
        const PluginPlaceholder(manifest: manifest),
      ));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Music'), findsOneWidget);
    });

    testWidgets('shows the reason instead of an endless spinner on failure',
        (tester) async {
      await tester.pumpWidget(host(
        const PluginPlaceholder(
          manifest: manifest,
          error: 'Music server unreachable',
        ),
      ));

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Music server unreachable'), findsOneWidget);
    });
  });
}
