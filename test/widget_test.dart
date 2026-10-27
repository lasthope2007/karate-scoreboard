import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karate_scoreboard/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Z-Score scoreboard fits landscape and shows all controls', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const KarateScoreboardApp());
    await tester.pump();
    // Let the 2.5-second branded splash finish before asserting scoreboard controls.
    await tester.pump(const Duration(milliseconds: 2600));
    await tester.pumpAndSettle();

    expect(find.text('Z-SCORE SCOREBOARD'), findsOneWidget);
    expect(find.text('AKA'), findsOneWidget);
    expect(find.text('AO'), findsOneWidget);
    expect(find.text('START'), findsOneWidget);
    expect(find.text('+1'), findsNWidgets(2));
    expect(find.text('+2'), findsNWidgets(2));
    expect(find.text('+3'), findsNWidgets(2));
    expect(find.textContaining('WARNINGS'), findsNothing);
    for (final label in ['CHUI 1', 'CHUI 2', 'CHUI 3', 'HANSOKU-CHUI', 'HANSOKU']) {
      expect(find.text(label), findsNWidgets(2), reason: 'Both athletes need a $label control');
    }
    expect(find.byTooltip('Award Senshu'), findsNWidgets(2));
    expect(find.byTooltip('Switch sides'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('CHUI 1').first);
    await tester.pump();
    await tester.tap(find.byTooltip('Match history'));
    await tester.pumpAndSettle();
    expect(find.textContaining('CHUI 1 recorded'), findsOneWidget);
    await tester.tap(find.text('CLOSE'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('+3').first);
    await tester.pump();
    expect(find.text('3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
