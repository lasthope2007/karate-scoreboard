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
    expect(find.textContaining('FOULS / WARNINGS'), findsNWidgets(2));
  });
}
