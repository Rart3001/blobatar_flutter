/// Everything decorative stops under the platform's reduce-motion setting.
///
/// The pose still applies — it simply arrives without the transition — so a
/// consumer setting `expression` still gets the expression.
library;

import 'dart:ui';

import 'package:blobatar_flutter/blobatar_flutter.dart';
import 'package:blobatar_flutter/src/painter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app({required bool reduceMotion, required Expression expression}) =>
    MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: Blobatar(
            name: 'alain',
            size: 100,
            animate: BlobatarAnimate.always,
            expression: expression,
          ),
        ),
      ),
    );

BlobatarPainter _painter(WidgetTester tester) => tester
    .widget<CustomPaint>(find.descendant(
      of: find.byType(Blobatar),
      matching: find.byType(CustomPaint),
    ),)
    .painter! as BlobatarPainter;

void main() {
  testWidgets('idle motion does not run', (tester) async {
    await tester
        .pumpWidget(_app(reduceMotion: true, expression: idleExpression));
    await tester.pump(const Duration(milliseconds: 600));

    final p = _painter(tester);
    expect(p.breatheScale, const Offset(1, 1), reason: 'breathing');
    expect(p.bobDy, 0, reason: 'bob');
    expect(p.eyeBlinkScaleY, 1, reason: 'blink');
    expect(p.gazeOffset, Offset.zero, reason: 'gaze');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a tremor pose does not tremble', (tester) async {
    await tester
        .pumpWidget(_app(reduceMotion: true, expression: madExpression));
    await tester.pump(const Duration(milliseconds: 600));
    expect(_painter(tester).shakeOffset, Offset.zero);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the expression still applies, just without the morph',
      (tester) async {
    await tester
        .pumpWidget(_app(reduceMotion: true, expression: idleExpression));
    await tester.pump(const Duration(milliseconds: 100));
    final idleRx = _painter(tester).layout.eyes[0].rx;

    await tester
        .pumpWidget(_app(reduceMotion: true, expression: happyExpression));
    await tester.pump(const Duration(milliseconds: 16)); // one frame, not 300ms

    expect(_painter(tester).layout.eyes[0].rx, closeTo(idleRx * 1.72, 0.001),
        reason: 'the pose must arrive immediately, not ease in',);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('hovering does not lift', (tester) async {
    await tester
        .pumpWidget(_app(reduceMotion: true, expression: idleExpression));
    await tester.pump(const Duration(milliseconds: 100));
    final resting = _painter(tester).breatheScale;

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: tester.getCenter(find.byType(Blobatar)));
    await tester.pump(const Duration(milliseconds: 600));

    expect(_painter(tester).breatheScale, resting,
        reason: 'the hover lift is decorative motion and must be gated too',);
    expect(_painter(tester).bobDy, 0);

    await gesture.removePointer();
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
