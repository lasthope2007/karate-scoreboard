import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karate_scoreboard/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Z-Score scoreboard renders both athletes and controls', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const KarateScoreboardApp());

    expect(find.text('Z-SCORE'), findsOneWidget);
    expect(find.text('AKA'), findsOneWidget);
    expect(find.text('AO'), findsOneWidget);
    expect(find.text('START'), findsOneWidget);
    expect(find.text('+1'), findsNWidgets(2));
    expect(find.text('+2'), findsNWidgets(2));
    expect(find.text('+3'), findsNWidgets(2));
    expect(find.textContaining('WARNINGS'), findsNWidgets(2));
    expect(find.byTooltip('Award Senshu'), findsNWidgets(2));
    expect(find.byTooltip('Switch sides'), findsOneWidget);
    expect(find.text('CHUI 1'), findsNWidgets(2));
    expect(find.text('CHUI 2'), findsNWidgets(2));
    expect(find.text('CHUI 3'), findsNWidgets(2));
    expect(find.text('HANSOKU-CHUI'), findsNWidgets(2));
    expect(find.text('HANSOKU'), findsNWidgets(2));

    // Every penalty control should update the state and leave an audit event.
    await tester.ensureVisible(find.text('CHUI 1').first);
    await tester.tap(find.text('CHUI 1').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Match history'));
    await tester.pumpAndSettle();
    expect(find.textContaining('CHUI 1 recorded'), findsOneWidget);
    expect(find.textContaining('Score 0 - 0'), findsOneWidget);
    await tester.tap(find.text('CLOSE'));
    await tester.pumpAndSettle();

    // Score events should record the post-action score and the prior value.
    await tester.ensureVisible(find.text('+3').first);
    await tester.tap(find.text('+3').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Match history'));
    await tester.pumpAndSettle();
    expect(find.textContaining('0 → 3'), findsOneWidget);
  });
}
