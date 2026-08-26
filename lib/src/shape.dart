/// A faithful port of blobatar's `src/shape.ts` geometry, producing
/// `dart:ui` `Path` objects directly instead of SVG path strings — there is
/// no SVG layer in this port at all.
library;

import 'dart:math' as math;
import 'dart:ui';

/// `|x/a|^n + |y/b|^n = 1`. `n=2` is an ellipse (eyes), `n≈4` a squircle
/// (bodies), `n` large a near-rectangle (boxy bodies). One shape, one
/// continuous knob.
class Superellipse {
  /// Creates a superellipse, in viewBox units.
  const Superellipse({
    required this.cx,
    required this.cy,
    required this.rx,
    required this.ry,
    this.n = 4,
    this.rot = 0,
  });

  /// Centre x, in viewBox units.
  final double cx;

  /// Centre y, in viewBox units.
  final double cy;

  /// Half-width, in viewBox units.
  final double rx;

  /// Half-height, in viewBox units.
  final double ry;

  /// Squareness. Useful range is roughly 1.6 (soft diamond) to 8 (near-rect).
  final double n;

  /// Degrees, clockwise. Baked into the coordinates, exactly like upstream,
  /// so the caller never needs a separate rotation transform.
  final double rot;
}

/// Approximates each quadrant of a superellipse with one cubic Bézier.
///
/// The control offset is chosen so the curve passes exactly through the
/// superellipse's 45° point — at `n=2` that yields 0.5523, the standard
/// circle constant, which is the same derivation upstream uses to sanity
/// check this. Four segments per shape, same as the original.
Path superellipsePath(Superellipse s) {
  // Above n≈5.55 the control offset exceeds the radius and the curve bulges
  // outside its bounding box instead of squaring off. Clamping k trades
  // exactness at the 45° point for a shape that always stays within its
  // stated bounds.
  final k = math.min<double>(1, (8 * math.pow(2, -1 / s.n) - 4) / 3);
  final a = s.rx;
  final b = s.ry;
  final ak = a * k;
  final bk = b * k;

  final pts = <Offset>[
    Offset(a, 0),
    Offset(a, bk),
    Offset(ak, b),
    Offset(0, b),
    Offset(-ak, b),
    Offset(-a, bk),
    Offset(-a, 0),
    Offset(-a, -bk),
    Offset(-ak, -b),
    Offset(0, -b),
    Offset(ak, -b),
    Offset(a, -bk),
    Offset(a, 0),
  ];

  final t = s.rot * math.pi / 180;
  final cosT = math.cos(t);
  final sinT = math.sin(t);
  Offset at(int i) {
    final p = pts[i];
    return Offset(
      s.cx + p.dx * cosT - p.dy * sinT,
      s.cy + p.dx * sinT + p.dy * cosT,
    );
  }

  final start = at(0);
  final path = Path()..moveTo(start.dx, start.dy);
  for (var i = 1; i < 13; i += 3) {
    final c1 = at(i);
    final c2 = at(i + 1);
    final end = at(i + 2);
    path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
  }
  path.close();
  return path;
}

/// An organic closed curve: radii sampled around a circle and joined by a
/// closed Catmull-Rom spline converted to cubic Béziers.
///
/// Catmull-Rom rather than a fitted Bézier because it interpolates its
/// control points exactly, so `radii` (multipliers of the base radius) mean
/// what they say and containment stays predictable — the same reasoning
/// upstream documents.
Path organicBlobPath(
  double cx,
  double cy,
  double rx,
  double ry,
  List<double> radii, [
  double rot = 0,
]) {
  final n = radii.length;
  final t0 = rot * math.pi / 180;
  final pts = List<Offset>.generate(n, (i) {
    final a = t0 + (2 * math.pi * i) / n;
    final m = radii[i];
    return Offset(cx + rx * m * math.cos(a), cy + ry * m * math.sin(a));
  });

  Offset at(int i) => pts[((i % n) + n) % n];

  final first = at(0);
  final path = Path()..moveTo(first.dx, first.dy);
  for (var i = 0; i < n; i++) {
    final p0 = at(i - 1);
    final p1 = at(i);
    final p2 = at(i + 1);
    final p3 = at(i + 2);
    final c1 = Offset(p1.dx + (p2.dx - p0.dx) / 6, p1.dy + (p2.dy - p0.dy) / 6);
    final c2 = Offset(p2.dx - (p3.dx - p1.dx) / 6, p2.dy - (p3.dy - p1.dy) / 6);
    path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
  }
  path.close();
  return path;
}

/// A plain rectangle, used as the straight run of a capsule. The rounded ends
/// are drawn as circles by the decoration layer rather than folded in here,
/// so the capsule stays two primitives the bundle already carries.
Path boxPath(double cx, double cy, double rx, double ry) =>
    Path()..addRect(Rect.fromLTRB(cx - rx, cy - ry, cx + rx, cy + ry));

/// A regular polygon with rounded corners, each corner a single quadratic
/// through the true vertex.
///
/// [round] is halved because the cut is taken from *both* ends of every edge:
/// at 1 each end reaches the midpoint and they meet exactly, so anything above
/// that would have the two cuts cross and the outline fold back on itself.
Path polygonPath({
  required double cx,
  required double cy,
  required double rx,
  required double ry,
  required int sides,
  double round = 0.3,
  double rot = 0,
}) {
  final k = round > 0 ? (round < 1 ? round / 2 : 0.5) : 0.0;
  // -90 degrees so a vertex sits at the top: a triangle points up and rests on
  // a flat edge, which is the orientation anybody who asks for one means.
  final t0 = rot * math.pi / 180 - math.pi / 2;
  final v = List<Offset>.generate(sides, (i) {
    final a = t0 + (2 * math.pi * i) / sides;
    return Offset(cx + rx * math.cos(a), cy + ry * math.sin(a));
  });

  Offset at(int i) => v[((i % sides) + sides) % sides];

  /// The cut point on the edge leaving vertex [i] toward vertex [j].
  Offset cut(int i, int j) {
    final p0 = at(i);
    final p1 = at(j);
    return Offset(p0.dx + (p1.dx - p0.dx) * k, p0.dy + (p1.dy - p0.dy) * k);
  }

  final start = cut(0, -1);
  final path = Path()..moveTo(start.dx, start.dy);
  for (var i = 0; i < sides; i++) {
    final vert = at(i);
    final end = cut(i, i + 1);
    path.quadraticBezierTo(vert.dx, vert.dy, end.dx, end.dy);
    // The straight run to the next corner's cut. Omitted when the cuts meet,
    // so a fully rounded polygon does not emit `sides` zero-length lines.
    if (k < 0.5) {
      final next = cut(i + 1, i);
      path.lineTo(next.dx, next.dy);
    }
  }
  return path..close();
}

/// The point of a droplet: two straight flanks rising from the ellipse's
/// tangent points to an apex, eased at the top so the tip is not a spike.
///
/// In the circle the ellipse is an affine image of, the tangent points sit at
/// angle `acos(1/tip)` from the apex direction. Affine maps preserve tangency,
/// so scaling those two points by [rx] and [ry] is exact, not an approximation.
Path taperPath(double cx, double cy, double rx, double ry, double tip) {
  final t = math.max(1.05, tip);
  final tx = rx * math.sqrt(1 - 1 / (t * t));
  final ty = cy - ry / t;
  final apex = cy - t * ry;
  // How far up each flank the eased point takes over. Small, so the flanks
  // stay straight enough to read as a taper.
  final px = tx * 0.14;
  final py = ty + 0.86 * (apex - ty);
  return Path()
    ..moveTo(cx - tx, ty)
    ..lineTo(cx - px, py)
    ..quadraticBezierTo(cx, apex, cx + px, py)
    ..lineTo(cx + tx, ty)
    ..close();
}
