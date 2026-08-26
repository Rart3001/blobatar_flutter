import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:blobatar_flutter/src/color.dart';
import 'package:blobatar_flutter/src/painter.dart';
import 'package:blobatar_flutter/src/styles/layout.dart';
import 'package:blobatar_flutter/src/traits.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const _size = 100.0;

BlobatarPainter _painter(BlobatarBackdrop backdrop) {
  final t = Traits('alain');
  return BlobatarPainter(
    layout: computeLayout(t),
    palette: buildPalette(t.num('hue', 0, 360), tone: t('tone')),
    backdrop: backdrop,
  );
}

/// Rasterizes a painter and returns its pixels, so what the backdrop actually
/// covers can be measured rather than assumed.
Future<ByteData> _raster(BlobatarPainter painter) async {
  final recorder = ui.PictureRecorder();
  painter.paint(ui.Canvas(recorder), const Size(_size, _size));
  final image =
      await recorder.endRecording().toImage(_size.toInt(), _size.toInt());
  final data = (await image.toByteData())!;
  image.dispose();
  return data;
}

int _alphaAt(ByteData px, int x, int y) =>
    px.getUint8((y * _size.toInt() + x) * 4 + 3);

int _opaquePixels(ByteData px) {
  var n = 0;
  for (var i = 3; i < px.lengthInBytes; i += 4) {
    if (px.getUint8(i) > 0) n++;
  }
  return n;
}

void main() {
  group('backdrop', () {
    test('none leaves the corners bare', () async {
      final px = await _raster(_painter(BlobatarBackdrop.none));
      expect(_alphaAt(px, 0, 0), 0);
      expect(_alphaAt(px, 99, 99), 0);
    });

    test('square fills the frame to its corners', () async {
      final px = await _raster(_painter(BlobatarBackdrop.square));
      expect(_alphaAt(px, 0, 0), 255);
      expect(_alphaAt(px, 99, 0), 255);
      expect(_alphaAt(px, 0, 99), 255);
      expect(_alphaAt(px, 99, 99), 255);
    });

    test('circle reaches the edge midpoints but not the corners', () async {
      final px = await _raster(_painter(BlobatarBackdrop.circle));
      expect(_alphaAt(px, 0, 0), 0, reason: 'a circle has no corners');
      expect(_alphaAt(px, 50, 2), 255, reason: 'should touch the top edge');
      expect(_alphaAt(px, 2, 50), 255, reason: 'should touch the left edge');
    });

    test('squircle sits between the circle and the square', () async {
      // The whole point of the shape: rounder than a square, fuller than a
      // circle. Comparing covered area is the direct way to say that.
      final circle =
          _opaquePixels(await _raster(_painter(BlobatarBackdrop.circle)));
      final squircle =
          _opaquePixels(await _raster(_painter(BlobatarBackdrop.squircle)));
      final square =
          _opaquePixels(await _raster(_painter(BlobatarBackdrop.square)));

      expect(squircle, greaterThan(circle));
      expect(squircle, lessThan(square));
      expect(square, _size * _size);
    });

    test('every backdrop still draws the creature', () async {
      // The backdrop is painted first; a bug there could cover the blobatar.
      for (final backdrop in BlobatarBackdrop.values) {
        final px = await _raster(_painter(backdrop));
        expect(_alphaAt(px, 50, 50), 255, reason: '$backdrop lost the body');
      }
    });
  });

  group('shouldRepaint', () {
    test('is false when nothing moved', () {
      final a = _painter(BlobatarBackdrop.none);
      final b = BlobatarPainter(
        layout: a.layout,
        palette: a.palette,
        backdrop: a.backdrop,
      );
      expect(b.shouldRepaint(a), isFalse);
    });

    test('is true for every animated input', () {
      final base = _painter(BlobatarBackdrop.none);
      BlobatarPainter variant({
        Offset? bodyOffset,
        Offset? breatheScale,
        double? bobDy,
        double? eyeBlinkScaleY,
        Offset? gazeOffset,
        Offset? shakeOffset,
        BlobatarBackdrop? backdrop,
      }) =>
          BlobatarPainter(
            layout: base.layout,
            palette: base.palette,
            backdrop: backdrop ?? base.backdrop,
            bodyOffset: bodyOffset ?? base.bodyOffset,
            breatheScale: breatheScale ?? base.breatheScale,
            bobDy: bobDy ?? base.bobDy,
            eyeBlinkScaleY: eyeBlinkScaleY ?? base.eyeBlinkScaleY,
            gazeOffset: gazeOffset ?? base.gazeOffset,
            shakeOffset: shakeOffset ?? base.shakeOffset,
          );

      expect(
          variant(bodyOffset: const Offset(0, 1)).shouldRepaint(base), isTrue,);
      expect(variant(breatheScale: const Offset(1.01, 1)).shouldRepaint(base),
          isTrue,);
      expect(variant(bobDy: -1).shouldRepaint(base), isTrue);
      expect(variant(eyeBlinkScaleY: 0.5).shouldRepaint(base), isTrue);
      expect(
          variant(gazeOffset: const Offset(1, 0)).shouldRepaint(base), isTrue,);
      expect(
        variant(shakeOffset: const Offset(1, 0)).shouldRepaint(base),
        isTrue,
      );
      expect(variant(backdrop: BlobatarBackdrop.circle).shouldRepaint(base),
          isTrue,);
    });
  });
}
