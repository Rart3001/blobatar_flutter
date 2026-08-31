/// An animating blobatar must not drag anything around it into its repaint.
///
/// This is behavioural, not a timing benchmark: it counts how many times an
/// ancestor's painter is asked to paint, which is deterministic. Without the
/// RepaintBoundary inside [Blobatar], one animating avatar in a grid of 48
/// repainted all 48 every frame, because they shared a layer.
library;

import 'dart:ui';

import 'package:blobatar_flutter/blobatar_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _CountingPainter extends CustomPainter {
  _CountingPainter(this.onPaint);
  final void Function() onPaint;
  @override
  void paint(Canvas canvas, Size size) => onPaint();
  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

void main() {
  testWidgets('an animating blobatar does not repaint its neighbours',
      (tester) async {
    var ancestorPaints = 0;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: CustomPaint(
          foregroundPainter: _CountingPainter(() => ancestorPaints++),
          child: Wrap(
            children: List.generate(
              48,
              (i) => Blobatar(
                name: 'seed$i',
                size: 32,
                // Exactly one animates — the hover-grid case the README
                // recommends, and the one where isolation is worth a layer.
                animate: i == 0 ? BlobatarAnimate.always : BlobatarAnimate.none,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    ancestorPaints = 0;
    for (var f = 0; f < 30; f++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(
      ancestorPaints,
      0,
      reason: 'the animating blobatar dirtied the layer it shares with its '
          '47 static neighbours, so all of them repainted every frame',
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('an idle hover-mode blobatar stops doing work', (tester) async {
    // Hover mode is what this package recommends for grids, so the common
    // case is a great many of these with nobody hovering any of them. The
    // amplitude gate is 0 there, every motion function returns its rest
    // value, and the picture is identical frame after frame — so the frames
    // should stop.
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Blobatar(name: 'a', size: 32, animate: BlobatarAnimate.hover),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600)); // let amp settle to 0

    expect(
      await _repaintingFrames(tester, 30),
      0,
      reason: 'an unhovered blobatar repainted while nothing was moving',
    );

    // The control: once hovered it must animate on every frame.
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: tester.getCenter(find.byType(Blobatar)));
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      await _repaintingFrames(tester, 30),
      30,
      reason: 'hovering did not start the motion',
    );

    await gesture.removePointer();
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}

/// How many of the next [frames] hand the CustomPaint a different painter —
/// which is what a rebuild-and-repaint looks like from outside.
Future<int> _repaintingFrames(WidgetTester tester, int frames) async {
  Object? last = tester.widget<CustomPaint>(find.byType(CustomPaint)).painter;
  var changed = 0;
  for (var f = 0; f < frames; f++) {
    await tester.pump(const Duration(milliseconds: 16));
    final p = tester.widget<CustomPaint>(find.byType(CustomPaint)).painter;
    if (!identical(p, last)) changed++;
    last = p;
  }
  return changed;
}
