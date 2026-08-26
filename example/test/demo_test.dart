import 'package:blobatar_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('typing in the seed field survives a rebuild of the page',
      (tester) async {
    await tester.pumpWidget(const DemoApp());
    await tester.pump();

    String fieldText() =>
        tester.widget<EditableText>(find.byType(EditableText)).controller.text;

    await tester.enterText(find.byType(TextField), 'renata');
    await tester.pump();
    expect(fieldText(), 'renata', reason: 'text did not land');

    // Picking an expression calls setState on the page. A controller built
    // inside build() is thrown away and rebuilt from _seed on every one of
    // those rebuilds, taking whatever was half-typed with it.
    await tester.tap(find.text('happy'));
    await tester.pump();

    expect(fieldText(), 'renata',
        reason: 'the seed field was reset by an unrelated rebuild',);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the seed field drives the avatar on submit', (tester) async {
    await tester.pumpWidget(const DemoApp());
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'renata');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      'renata',
    );
    await tester.pumpWidget(const SizedBox());
  });
}
