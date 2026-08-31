import 'package:blobatar_flutter/blobatar_flutter.dart';
import 'package:blobatar_flutter/src/painter.dart';
import 'package:blobatar_flutter/src/styles/layout.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The eye half-width actually handed to the painter — the cheapest handle
/// on "which pose is on screen right now".
List<BlobEye> _paintedEyes(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.descendant(
      of: find.byType(Blobatar),
      matching: find.byType(CustomPaint),
    ),
  );
  return (paint.painter! as BlobatarPainter).layout.eyes;
}

double _paintedEyeRx(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.descendant(
      of: find.byType(Blobatar),
      matching: find.byType(CustomPaint),
    ),
  );
  return (paint.painter! as BlobatarPainter).layout.eyes[0].rx;
}

Widget _app(BlobatarAnimate animate, Expression expression) => Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: Blobatar(
          name: 'alain',
          size: 100,
          animate: animate,
          expression: expression,
        ),
      ),
    );

void main() {
  group('animate switching', () {
    testWidgets('toggling animate does not throw', (tester) async {
      await tester.pumpWidget(_app(BlobatarAnimate.always, idleExpression));
      await tester.pump(const Duration(seconds: 30));

      await tester.pumpWidget(_app(BlobatarAnimate.none, idleExpression));
      await tester.pump();
      expect(
        tester.takeException(),
        isNull,
        reason: 'stopping the ticker threw',
      );

      await tester.pumpWidget(_app(BlobatarAnimate.hover, idleExpression));
      await tester.pump();
      expect(
        tester.takeException(),
        isNull,
        reason: 'restarting the ticker threw — a single-ticker provider cannot '
            'hand out a second Ticker',
      );

      await tester.pumpWidget(_app(BlobatarAnimate.none, idleExpression));
      await tester.pump();
    });

    testWidgets('a Ticker is actually running again after a restart',
        (tester) async {
      await tester.pumpWidget(_app(BlobatarAnimate.always, idleExpression));
      await tester.pump(const Duration(seconds: 30));
      expect(tester.binding.transientCallbackCount, greaterThan(0));

      await tester.pumpWidget(_app(BlobatarAnimate.none, idleExpression));
      await tester.pump();
      expect(
        tester.binding.transientCallbackCount,
        0,
        reason: 'ticker was not stopped',
      );

      await tester.pumpWidget(_app(BlobatarAnimate.hover, idleExpression));
      await tester.pump();
      tester.takeException();
      expect(
        tester.binding.transientCallbackCount,
        greaterThan(0),
        reason: 'no Ticker is scheduling frames: createTicker threw, so the '
            'widget is frozen for the rest of its life',
      );

      await tester.pumpWidget(_app(BlobatarAnimate.none, idleExpression));
      await tester.pump();
    });

    testWidgets('idle motion resumes after the ticker restarts',
        (tester) async {
      await tester.pumpWidget(_app(BlobatarAnimate.always, idleExpression));
      await tester.pump(const Duration(seconds: 30));

      await tester.pumpWidget(_app(BlobatarAnimate.none, idleExpression));
      await tester.pump();
      await tester.pumpWidget(_app(BlobatarAnimate.always, idleExpression));
      await tester.pump();
      tester.takeException();

      // Breathe/bob move the body every frame; sample twice and require change.
      final samples = <double>[];
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 250));
        final paint = tester.widget<CustomPaint>(
          find.descendant(
            of: find.byType(Blobatar),
            matching: find.byType(CustomPaint),
          ),
        );
        samples.add((paint.painter! as BlobatarPainter).breatheScale.dx);
      }
      expect(
        samples.toSet().length,
        greaterThan(1),
        reason: 'motion never resumed',
      );

      await tester.pumpWidget(_app(BlobatarAnimate.none, idleExpression));
      await tester.pump();
    });
  });

  group('clock continuity', () {
    testWidgets('a morph requested after a restart still completes',
        (tester) async {
      // The clock keeps its own elapsed total across Ticker restarts. Without
      // that, a fresh Ticker reports elapsed from zero while _morphStart still
      // holds a value from the previous one, so `now - _morphStart` stays
      // negative and the morph sits at t=0 until the new Ticker catches up.
      await tester.pumpWidget(_app(BlobatarAnimate.always, idleExpression));
      await tester.pump(const Duration(seconds: 30));
      final idleRx = _paintedEyeRx(tester);

      await tester.pumpWidget(_app(BlobatarAnimate.none, idleExpression));
      await tester.pump();
      await tester.pumpWidget(_app(BlobatarAnimate.always, idleExpression));
      await tester.pump(const Duration(milliseconds: 16));

      await tester.pumpWidget(_app(BlobatarAnimate.always, happyExpression));
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        _paintedEyeRx(tester),
        closeTo(idleRx * 1.72, 0.001),
        reason:
            'the morph never ran: the restarted clock is behind _morphStart',
      );

      await tester.pumpWidget(_app(BlobatarAnimate.none, idleExpression));
      await tester.pump();
    });

    testWidgets(
        'animate and expression changing in the same frame still morphs',
        (tester) async {
      // didUpdateWidget stamps _morphStart from the current clock *before* it
      // restarts the Ticker. If the clock restarted at zero with it, the stamp
      // would sit far in the future and `now - _morphStart` would stay negative
      // for as long as the widget had previously been running — here, 30s of
      // a frozen idle pose. Keeping our own elapsed total across restarts is
      // what makes the two agree.
      await tester.pumpWidget(_app(BlobatarAnimate.always, idleExpression));
      await tester.pump(const Duration(seconds: 30));
      final idleRx = _paintedEyeRx(tester);

      await tester.pumpWidget(_app(BlobatarAnimate.none, idleExpression));
      await tester.pump();

      // Both change at once — no tick in between to resynchronise the stamp.
      await tester.pumpWidget(_app(BlobatarAnimate.always, happyExpression));
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        _paintedEyeRx(tester),
        closeTo(idleRx * 1.72, 0.001),
        reason: 'the morph stalled: _morphStart was stamped on the old clock '
            'and the restarted Ticker reports elapsed from zero',
      );

      await tester.pumpWidget(_app(BlobatarAnimate.none, idleExpression));
      await tester.pump();
    });

    testWidgets('the phase resumes where it stopped, it does not rewind',
        (tester) async {
      // Pausing freezes our clock, so motion picks up mid-cycle rather than
      // snapping back to the start of the breathe loop.
      await tester.pumpWidget(_app(BlobatarAnimate.always, idleExpression));
      await tester.pump(const Duration(milliseconds: 1400)); // mid breathe leg
      await tester.pump(const Duration(milliseconds: 16));

      final paintBefore = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(Blobatar),
          matching: find.byType(CustomPaint),
        ),
      );
      final before = (paintBefore.painter! as BlobatarPainter).breatheScale.dy;
      expect(
        before,
        lessThan(0.999),
        reason: 'not mid-cycle; test is not probing anything',
      );

      await tester.pumpWidget(_app(BlobatarAnimate.none, idleExpression));
      await tester.pump();
      await tester.pumpWidget(_app(BlobatarAnimate.always, idleExpression));
      await tester.pump(const Duration(milliseconds: 16));

      final paintAfter = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(Blobatar),
          matching: find.byType(CustomPaint),
        ),
      );
      final after = (paintAfter.painter! as BlobatarPainter).breatheScale.dy;

      // Amplitude ramps from zero on resume, so `after` sits between rest (1.0)
      // and where the phase left off — never past it, which a rewound or
      // double-counted clock would produce.
      expect(after, lessThanOrEqualTo(1.0));
      expect(
        after,
        greaterThanOrEqualTo(before - 1e-9),
        reason: 'the clock jumped forward: _clockBase was added twice',
      );

      await tester.pumpWidget(_app(BlobatarAnimate.none, idleExpression));
      await tester.pump();
    });
  });

  group('expression morph', () {
    testWidgets('morphs over ~300ms on a long-running clock', (tester) async {
      await tester.pumpWidget(_app(BlobatarAnimate.hover, idleExpression));
      await tester.pump(const Duration(seconds: 30));
      final idleRx = _paintedEyeRx(tester);

      await tester.pumpWidget(_app(BlobatarAnimate.hover, happyExpression));

      await tester.pump(const Duration(milliseconds: 150));
      final midRx = _paintedEyeRx(tester);
      expect(midRx, greaterThan(idleRx), reason: 'morph never started');
      expect(
        midRx,
        lessThan(idleRx * 1.72),
        reason: 'morph jumped instead of easing',
      );

      await tester.pump(const Duration(milliseconds: 200));
      expect(
        _paintedEyeRx(tester),
        closeTo(idleRx * 1.72, 0.001),
        reason: 'morph did not reach the happy pose (esx 1.72)',
      );

      await tester.pumpWidget(_app(BlobatarAnimate.none, idleExpression));
      await tester.pump();
    });

    testWidgets('applies instantly when animate is none', (tester) async {
      await tester.pumpWidget(_app(BlobatarAnimate.none, idleExpression));
      final idleRx = _paintedEyeRx(tester);
      await tester.pumpWidget(_app(BlobatarAnimate.none, happyExpression));
      await tester.pump();
      expect(_paintedEyeRx(tester), closeTo(idleRx * 1.72, 0.001));
    });
  });

  group('rock seesaw (thinking)', () {
    testWidgets('idle poses never rock', (tester) async {
      await tester.pumpWidget(_app(BlobatarAnimate.always, happyExpression));
      await tester.pump(const Duration(milliseconds: 300));
      final a = _paintedEyes(tester);
      await tester.pump(const Duration(milliseconds: 225));
      expect(
        _paintedEyes(tester)[1].cy,
        a[1].cy,
        reason: 'a pose with rock == 0 must not move the eye vertically',
      );
      await tester.pumpWidget(_app(BlobatarAnimate.none, idleExpression));
      await tester.pump();
    });

    testWidgets('the stagger reverses over the 900ms loop', (tester) async {
      await tester.pumpWidget(_app(BlobatarAnimate.always, thinkingExpression));
      await tester.pump(const Duration(milliseconds: 400)); // finish the morph

      // Phase +1 and -1 are half a loop apart; the pair swings symmetrically
      // about its own centre, so the two eyes must trade places.
      final t0 = _paintedEyes(tester);
      await tester.pump(const Duration(milliseconds: 450));
      final t1 = _paintedEyes(tester);

      expect(
        t1[0].cy,
        isNot(closeTo(t0[0].cy, 0.5)),
        reason: 'left eye never moved',
      );
      expect(
        t1[1].cy,
        isNot(closeTo(t0[1].cy, 0.5)),
        reason: 'right eye never moved',
      );
      // Symmetric: what one eye gains the other gives up.
      expect(
        (t0[0].cy + t0[1].cy) / 2,
        closeTo((t1[0].cy + t1[1].cy) / 2, 0.01),
        reason: 'the pair drifted instead of rocking about its centre',
      );

      await tester.pumpWidget(_app(BlobatarAnimate.none, idleExpression));
      await tester.pump();
    });

    testWidgets('the static bake is the loop at phase +1', (tester) async {
      // animate: none holds bakePose's own output; frame zero of the loop must
      // land on the same place, so a static blobatar and an animating one
      // agree at the extreme.
      await tester.pumpWidget(_app(BlobatarAnimate.none, thinkingExpression));
      await tester.pump();
      final static = _paintedEyes(tester);

      await tester.pumpWidget(_app(BlobatarAnimate.always, thinkingExpression));
      await tester
          .pump(const Duration(milliseconds: 900)); // a whole loop: phase +1
      final animated = _paintedEyes(tester);

      expect(animated[0].cy, closeTo(static[0].cy, 0.01));
      expect(animated[1].cy, closeTo(static[1].cy, 0.01));
      await tester.pumpWidget(_app(BlobatarAnimate.none, idleExpression));
      await tester.pump();
    });
  });
}
