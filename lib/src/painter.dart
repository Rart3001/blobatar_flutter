/// Draws a resolved [BlobLayout] + [BlobatarPalette] onto a canvas, with
/// optional live breathe/bob/blink/gaze/shake offsets layered on top.
///
/// There is no SVG anywhere in this port: geometry is built straight into
/// `dart:ui` `Path`s (see `shape.dart`) and painted with plain fills.
library;

import 'dart:math' as math;

import 'package:blobatar_flutter/blobatar_flutter.dart' show Pose;
import 'package:blobatar_flutter/src/color.dart';
import 'package:blobatar_flutter/src/pose.dart' show Pose;
import 'package:blobatar_flutter/src/shape.dart';
import 'package:blobatar_flutter/src/styles/layout.dart';
import 'package:flutter/rendering.dart';

/// The shape painted behind the creature in the palette's background colour.
enum BlobatarBackdrop {
  /// No backdrop at all — the creature sits on whatever is behind it.
  none,

  /// The full square of the frame.
  square,

  /// A circle inscribed in the frame.
  circle,

  /// A rounded square between the two — the default elsewhere in the package.
  squircle,
}

/// Paints one blobatar: a resolved layout in a palette, plus whatever the
/// idle motion layer is offering this frame.
class BlobatarPainter extends CustomPainter {
  /// Creates a painter. Every motion parameter defaults to rest, so a static
  /// render only has to pass the layout and the palette.
  BlobatarPainter({
    required this.layout,
    required this.palette,
    this.backdrop = BlobatarBackdrop.none,
    this.bodyOffset = Offset.zero,
    this.breatheScale = const Offset(1, 1),
    this.bobDy = 0,
    this.eyeBlinkScaleY = 1,
    this.gazeOffset = Offset.zero,
    this.shakeOffset = Offset.zero,
  });

  /// The already-posed layout (see `pose.dart`'s `bakePose`) — eye
  /// position/size/tilt already reflect the current expression.
  final BlobLayout layout;

  /// The colours to paint it in.
  final BlobatarPalette palette;

  /// What to paint behind it, if anything.
  final BlobatarBackdrop backdrop;

  /// Whole-creature offset from [Pose.bdy], in viewBox units.
  final Offset bodyOffset;

  /// (scaleX, scaleY) from the breathe loop.
  final Offset breatheScale;

  /// Vertical offset from the bob loop, in viewBox units.
  final double bobDy;

  /// Multiplies both eyes' height about their own centers.
  final double eyeBlinkScaleY;

  /// Both eyes translated together, from the saccade loop.
  final Offset gazeOffset;

  /// Whole-creature tremor offset, from [Pose.shake].
  final Offset shakeOffset;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 100;
    canvas
      ..save()
      ..scale(scale, scale);

    if (backdrop != BlobatarBackdrop.none) {
      canvas.drawPath(_backdropPath(backdrop), Paint()..color = palette.bg);
    }

    // Breathe + bob apply about the viewBox center (50, 50), matching
    // upstream's `transform-box: view-box; transform-origin: center`.
    canvas
      ..save()
      ..translate(50, 50)
      ..translate(shakeOffset.dx, shakeOffset.dy)
      ..translate(0, bobDy)
      ..scale(breatheScale.dx, breatheScale.dy)
      ..translate(-50, -50)
      ..translate(bodyOffset.dx, bodyOffset.dy);

    final headPaint = Paint()..color = palette.head;
    for (final p in layout.petals) {
      canvas.drawCircle(Offset(p.cx, p.cy), p.r, headPaint);
    }
    // Outlines the silhouette unions with its core body — the droplet's point.
    // Drawn before the body so the seam between them is covered by it.
    for (final path in layout.extra) {
      canvas.drawPath(path, headPaint);
    }
    // Each silhouette names its own path primitive; the ones that do not are
    // superellipses, which the eyes need anyway.
    final draw = layout.draw;
    final bodyPath = draw != null
        ? draw(layout.body)
        : superellipsePath(
            Superellipse(
              cx: layout.body.cx,
              cy: layout.body.cy,
              rx: layout.body.rx,
              ry: layout.body.ry,
              n: layout.body.n,
              rot: layout.body.rot,
            ),
          );
    canvas.drawPath(bodyPath, headPaint);

    final eyePaint = Paint()..color = palette.eye;
    for (final e in layout.eyes) {
      // Blink scales the eye along its *own* axis, not the canvas's: bracket
      // the scale with the eye's own rotation (rotate in, scale, rotate back
      // out) so a leaned capsule closes across its own width instead of
      // shearing. Same trick upstream's stylesheet documents at length.
      final rotRad = e.rot * math.pi / 180;
      canvas
        ..save()
        ..translate(gazeOffset.dx, gazeOffset.dy)
        ..translate(e.cx, e.cy)
        ..rotate(rotRad)
        ..scale(1, eyeBlinkScaleY)
        ..rotate(-rotRad)
        ..translate(-e.cx, -e.cy)
        ..drawPath(
          superellipsePath(
            Superellipse(
              cx: e.cx,
              cy: e.cy,
              rx: e.rx,
              ry: e.ry,
              n: e.n,
              rot: e.rot,
            ),
          ),
          eyePaint,
        )
        ..restore();
    }

    canvas
      ..restore()
      ..restore();
  }

  Path _backdropPath(BlobatarBackdrop bg) => switch (bg) {
        BlobatarBackdrop.square => Path()
          ..addRect(const Rect.fromLTWH(0, 0, 100, 100)),
        BlobatarBackdrop.circle => superellipsePath(
            const Superellipse(cx: 50, cy: 50, rx: 50, ry: 50, n: 2),
          ),
        // `none` never reaches here — paint skips the backdrop entirely —
        // but the switch is exhaustive over the enum, so it shares the
        // squircle's arm rather than needing a fallback the compiler cannot
        // check.
        BlobatarBackdrop.squircle || BlobatarBackdrop.none => superellipsePath(
            const Superellipse(cx: 50, cy: 50, rx: 50, ry: 50, n: 6),
          ),
      };

  @override
  bool shouldRepaint(covariant BlobatarPainter old) =>
      old.layout != layout ||
      old.palette != palette ||
      old.backdrop != backdrop ||
      old.bodyOffset != bodyOffset ||
      old.breatheScale != breatheScale ||
      old.bobDy != bobDy ||
      old.eyeBlinkScaleY != eyeBlinkScaleY ||
      old.gazeOffset != gazeOffset ||
      old.shakeOffset != shakeOffset;
}
