import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voyager/config/automotive_config.dart';
import 'package:voyager/theme/voyager_theme.dart';
import 'package:voyager/widgets/automotive_button.dart';

Widget host(Widget child) => MaterialApp(
      theme: VoyagerTheme.dark,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('AutomotiveButton', () {
    testWidgets('is at least as large as the minimum touch target',
        (tester) async {
      await tester.pumpWidget(host(
        const AutomotiveButton(icon: Icons.play_arrow, label: 'Play'),
      ));

      final size = tester.getSize(find.byType(AutomotiveButton));
      expect(size.width, greaterThanOrEqualTo(AutomotiveConfig.minTouchTargetDp));
      expect(
        size.height,
        greaterThanOrEqualTo(AutomotiveConfig.minTouchTargetDp),
      );
    });

    testWidgets('is inert without a callback', (tester) async {
      await tester.pumpWidget(host(
        const AutomotiveButton(icon: Icons.play_arrow, label: 'Play'),
      ));
      // Tapping a disabled button must not throw; it simply does nothing.
      await tester.tap(find.byType(AutomotiveButton));
      await tester.pump();
    });

    testWidgets('fires its callback when enabled', (tester) async {
      var taps = 0;
      await tester.pumpWidget(host(AutomotiveButton(
        icon: Icons.play_arrow,
        label: 'Play',
        onPressed: () => taps++,
      )));

      await tester.tap(find.byType(AutomotiveButton));
      expect(taps, 1);
    });

    testWidgets('keeps the label out of the way when icon-only',
        (tester) async {
      await tester.pumpWidget(host(const AutomotiveButton(
        icon: Icons.play_arrow,
        label: 'Play',
        iconOnly: true,
      )));

      expect(find.text('Play'), findsNothing);
      // The label still reaches assistive technology, which is the point of
      // keeping it a required parameter.
      expect(
        tester.getSemantics(find.byType(AutomotiveButton)).label,
        contains('Play'),
      );
    });
  });
}
