import 'package:flutter_test/flutter_test.dart';
import 'package:karate_scoreboard/main.dart';

void main() {
  testWidgets('scoreboard renders key controls', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(const KarateScoreboardApp());
    expect(find.text('KARATE'), findsOneWidget);
    expect(find.text('KUMITE'), findsOneWidget);
    expect(find.text('START'), findsOneWidget);
    expect(find.text('AKA  /  RED'), findsOneWidget);
    expect(find.text('AO  /  BLUE'), findsOneWidget);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
