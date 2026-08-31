import 'package:blobatar_example/main.dart';
import 'package:blobatar_flutter/blobatar_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Blobatar mainAvatar(WidgetTester tester) =>
      tester.widget<Blobatar>(find.byType(Blobatar).first);

  group('demo end-to-end', () {
    testWidgets('typing a seed and submitting it repaints the avatar',
        (tester) async {
      // Not pumpAndSettle: the main avatar animates continuously
      // (BlobatarAnimate.always), so frames never stop being scheduled and
      // pumpAndSettle would wait for a settle that never comes.
      await tester.pumpWidget(const DemoApp());
      await tester.pump();

      expect(mainAvatar(tester).name, 'roberto@example.com');

      await tester.enterText(find.byType(TextField), 'renata');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(mainAvatar(tester).name, 'renata');
    });

    testWidgets(
        'picking an expression chip applies it and stops the auto-cycle',
        (tester) async {
      await tester.pumpWidget(const DemoApp());
      await tester.pump();

      expect(
        mainAvatar(tester).expression,
        idleExpression,
        reason: 'the demo opens on the idle pose',
      );

      await tester.tap(find.widgetWithText(ChoiceChip, 'happy'));
      await tester.pump();

      expect(mainAvatar(tester).expression, happyExpression);

      // The demo auto-cycles through every expression on a timer (see
      // main.dart's _cyclePeriod) until the first manual pick, which is
      // supposed to cancel it for good. Advancing well past one full cycle
      // and finding 'happy' undisturbed is what actually proves the timer
      // was cancelled, rather than merely having landed on 'happy' by luck.
      await tester.pump(const Duration(seconds: 20));
      expect(
        mainAvatar(tester).expression,
        happyExpression,
        reason: 'picking an expression must cancel the auto-cycle timer',
      );
    });
  });
}
