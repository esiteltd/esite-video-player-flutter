import 'package:esite_flutter_player_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the backend, play and scenario sections', (
    tester,
  ) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.pump();

    expect(find.text('Backend'), findsOneWidget);
    expect(find.text('Play by video UUID'), findsOneWidget);
    expect(find.text('Stub scenarios'), findsOneWidget);

    // Every scenario should be offered.
    for (final scenario in Scenario.values) {
      expect(find.text(scenario.label), findsOneWidget);
    }
  });

  testWidgets('hides the stub scenarios when a real backend is selected', (
    tester,
  ) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.pump();

    await tester.tap(find.text('Use built-in stub backend'));
    await tester.pump();

    expect(find.text('Base URL'), findsOneWidget);
    expect(find.text('Enable the stub backend to run these.'), findsOneWidget);
  });
}
