/// The private silhouette vocabulary — a port of upstream's
/// `src/styles/shapes.ts`.
///
/// A shape is everything the layout needs to draw one silhouette and nothing
/// about *when* to draw it: how much of the frame its core body takes, how it
/// patches that body, what room it leaves the eyes, what it decorates with,
/// and which path primitive traces it. How often it comes up is a property of
/// the band table in `layout.dart`, not of the silhouette.
///
/// Shapes that are parameterizations of another share its implementation
/// rather than restating it: `boxy` is `round` with a squarer `n` and a tilt,
/// `hexagon` is `triangle` with six sides, `cloud` is `organic` with lobes.
library;

import 'dart:math' as math;
import 'dart:ui';

import 'package:blobatar_flutter/src/shape.dart';
import 'package:blobatar_flutter/src/traits.dart';

/// The ten silhouettes of blobatar gen2.
enum BlobShape {
  /// A plain superellipse. The everyday silhouette, and the widest band.
  round,

  /// A closed spline through seeded radii — a blob that is never twice the
  /// same blob. The other everyday silhouette.
  organic,

  /// [round] squared off and tilted.
  boxy,

  /// A squat lozenge: a box with a circle capping each end.
  capsule,

  /// [round] with one or two bumps stuck to its rim.
  nub,

  /// [organic] with lobes crowded along its upper half.
  cloud,

  /// A body with a point tapering off the top, tear-style.
  droplet,

  /// A rounded six-sided polygon.
  hexagon,

  /// [round] ringed by evenly spaced petals.
  sun,

  /// [hexagon] with three sides, resting on its base.
  triangle,
}

/// The body under construction.
///
/// Deliberately mutable, mirroring upstream: a shape patches the shared body
/// in place before the face is measured. Keeping the same seam makes future
/// re-syncs against upstream a reading exercise rather than a translation.
class BlobBody {
  /// Creates the body every shape starts from, before it patches it.
  BlobBody({
    required this.cx,
    required this.cy,
    required this.rx,
    required this.ry,
    required this.n,
    required this.rot,
    required this.radii,
    this.sides,
    this.round,
  });

  /// Centre x, in viewBox units — the 100x100 square the avatar is drawn in.
  double cx;

  /// Centre y, in viewBox units.
  double cy;

  /// Half-width, in viewBox units.
  double rx;

  /// Half-height, in viewBox units.
  double ry;

  /// Superellipse exponent: 2 is an ellipse, higher is squarer.
  double n;

  /// Rotation about the centre, in degrees.
  double rot;

  /// Per-vertex radius multipliers for the spline silhouettes, which is what
  /// makes one [BlobShape.organic] body differ from the next.
  List<double> radii;

  /// Polygon-only, set by the shapes that draw one.
  int? sides;

  /// Corner rounding of a polygon, 0 (sharp) to 1. Polygon-only.
  double? round;
}

/// The region the eyes must fit inside.
class Ellipse {
  /// Creates the face region, in viewBox units.
  const Ellipse(this.cx, this.cy, this.rx, this.ry);

  /// Centre x, in viewBox units.
  final double cx;

  /// Centre y, in viewBox units.
  final double cy;

  /// Half-width, in viewBox units.
  final double rx;

  /// Half-height, in viewBox units.
  final double ry;
}

/// One circle painted in the head colour alongside the core body — a nub, a
/// cloud lobe, a sun ray, a capsule's cap.
class BlobPetal {
  /// Creates a petal, in viewBox units.
  const BlobPetal(this.cx, this.cy, this.r);

  /// Centre x, in viewBox units.
  final double cx;

  /// Centre y, in viewBox units.
  final double cy;

  /// Radius, in viewBox units.
  final double r;
}

/// What a shape decorates its body with.
class Deco {
  /// Circles unioned with the core body by being painted in its colour.
  final List<BlobPetal> petals = [];

  /// Extra outlines unioned with the core body, already traced.
  final List<Path> extra = [];
}

/// One silhouette's whole definition: how big its body is, how it patches
/// that body, what room it leaves the eyes, what it decorates with, and which
/// path primitive traces it.
class ShapeDef {
  /// Creates a silhouette definition. Everything but [name] and [core] has a
  /// shared default, which is why five path calls serve all ten shapes.
  const ShapeDef({
    required this.name,
    required this.core,
    this.body,
    this.face,
    this.decorate,
    this.path,
  });

  /// Which silhouette this defines.
  final BlobShape name;

  /// How much of the frame the core body takes.
  final double core;

  /// Patches the body before the face is measured.
  final void Function(Traits t, BlobBody b)? body;

  /// The region the eyes must fit inside. Omitted, it is the body itself —
  /// what every silhouette convex around its own centre wants, and half the
  /// roster is.
  final Ellipse Function(BlobBody b)? face;

  /// Adds petals and extra outlines around the finished body. Omitted, the
  /// silhouette is its core body and nothing else.
  final void Function(Traits t, BlobBody b, Deco out)? decorate;

  /// The core path. Omitted, a superellipse — free to default to, because the
  /// eyes are superellipses too, so it is in every bundle already.
  final Path Function(BlobBody b)? path;
}

// ---------------------------------------------------------------------------
// The shared implementations. Five path calls serve all ten shapes.

Path _poly(BlobBody b) => polygonPath(
      cx: b.cx,
      cy: b.cy,
      rx: b.rx,
      ry: b.ry,
      sides: b.sides!,
      round: b.round ?? 0.3,
      rot: b.rot,
    );

Path _spline(BlobBody b) =>
    organicBlobPath(b.cx, b.cy, b.rx, b.ry, b.radii, b.rot);

Ellipse Function(BlobBody) _shrunk(double k) =>
    (b) => Ellipse(b.cx, b.cy, b.rx * k, b.ry * k);

Ellipse _splineFace(BlobBody b) => _shrunk(b.radii.reduce(math.min) * 0.95)(b);
Ellipse _polyFace(BlobBody b) => _shrunk(0.84)(b);

// ---------------------------------------------------------------------------

const _round = ShapeDef(name: BlobShape.round, core: 1);

const _organic = ShapeDef(
  name: BlobShape.organic,
  core: 0.98,
  path: _spline,
  face: _splineFace,
);

/// `round`, squared off and tilted. Same path, different parameters.
final _boxy = ShapeDef(
  name: BlobShape.boxy,
  core: 0.86,
  body: (t, b) => b
    ..n = t.num('body.n', 3.4, 6)
    ..rot = t.num('body.rot', -20, 20),
);

final _capsule = ShapeDef(
  name: BlobShape.capsule,
  core: 1.02,
  body: (t, b) => b.ry *= t.num('capsule.squat', 0.55, 0.68),
  face: _shrunk(0.94),
  decorate: (t, b, out) {
    for (final s in [-1, 1]) {
      out.petals.add(BlobPetal(b.cx + s * (b.rx - b.ry), b.cy, b.ry));
    }
  },
  path: (b) => boxPath(b.cx, b.cy, b.rx - b.ry, b.ry),
);

final _nub = ShapeDef(
  name: BlobShape.nub,
  core: 0.88,
  decorate: (t, b, out) {
    final count = t.intRange('nub.n', 1, 2);
    for (var i = 0; i < count; i++) {
      final a = t.num('nub.a$i', 0, 2 * math.pi);
      out.petals.add(
        BlobPetal(
          b.cx + math.cos(a) * b.rx * 0.88,
          b.cy + math.sin(a) * b.rx * 0.88,
          b.rx * t.num('nub.r$i', 0.24, 0.4),
        ),
      );
    }
  },
);

/// `organic`, with lobes on the upper half.
final _cloud = ShapeDef(
  name: BlobShape.cloud,
  core: 0.78,
  face: _splineFace,
  path: _spline,
  decorate: (t, b, out) {
    final count = t.intRange('cloud.n', 4, 6);
    for (var i = 0; i < count; i++) {
      final a = math.pi + (math.pi * (i + 0.5)) / count;
      out.petals.add(
        BlobPetal(
          b.cx + math.cos(a) * b.rx * 0.8,
          b.cy + math.sin(a) * b.rx * 0.5,
          b.rx * t.num('cloud.r$i', 0.44, 0.62),
        ),
      );
    }
  },
);

final _droplet = ShapeDef(
  name: BlobShape.droplet,
  core: 0.78,
  // Shifted down by what the taper adds above, so the whole silhouette — head
  // and point together — sits centred in the frame rather than the head alone.
  // `n` is pinned to a true ellipse, the curve the taper is tangent to.
  body: (t, b) => b
    ..cy += 0.22 * b.ry
    ..n = 2,
  face: (b) => Ellipse(b.cx, b.cy + b.ry * 0.05, b.rx * 0.88, b.ry * 0.88),
  decorate: (t, b, out) => out.extra
      .add(taperPath(b.cx, b.cy, b.rx, b.ry, t.num('droplet.tip', 1.4, 1.65))),
);

final _hexagon = ShapeDef(
  name: BlobShape.hexagon,
  core: 1.05,
  path: _poly,
  face: _polyFace,
  body: (t, b) => b
    ..sides = 6
    ..rot = t.num('body.rot', -12, 12)
    ..round = t.num('poly.round', 0.24, 0.5),
);

final _sun = ShapeDef(
  name: BlobShape.sun,
  core: 0.7,
  decorate: (t, b, out) {
    final count = t.intRange('sun.n', 6, 9);
    final dist = b.rx * t.num('sun.dist', 1, 1.08);
    final pr = b.rx * t.num('sun.r', 0.2, 0.26);
    final off = t.num('sun.rot', 0, 2 * math.pi);
    for (var i = 0; i < count; i++) {
      final a = off + (2 * math.pi * i) / count;
      out.petals.add(
        BlobPetal(b.cx + math.cos(a) * dist, b.cy + math.sin(a) * dist, pr),
      );
    }
  },
);

/// `hexagon` with three sides, and a tighter tilt so it rests on its base.
final _triangle = ShapeDef(
  name: BlobShape.triangle,
  core: 1.15,
  path: _poly,
  body: (t, b) => b
    ..sides = 3
    ..rot = t.num('body.rot', -5, 5)
    ..round = t.num('poly.round', 0.24, 0.5),
  face: (b) => Ellipse(b.cx, b.cy + b.ry * 0.1, b.rx * 0.54, b.ry * 0.36),
);

/// `[shape, upper edge of its band in [0, 1)]`, in order.
///
/// Weighted rather than uniform: round and organic are the everyday shapes,
/// while the louder silhouettes stay finds. These bands, the layout ranges in
/// `layout.dart`, and the tone set together form gen2's frozen seed->look
/// mapping — changing any of them changes what every existing seed renders.
final List<({ShapeDef shape, double upTo})> bands = [
  (shape: _round, upTo: 0.22),
  (shape: _organic, upTo: 0.48),
  (shape: _boxy, upTo: 0.6),
  (shape: _capsule, upTo: 0.7),
  (shape: _nub, upTo: 0.79),
  (shape: _cloud, upTo: 0.86),
  (shape: _droplet, upTo: 0.915),
  (shape: _hexagon, upTo: 0.95),
  (shape: _sun, upTo: 0.98),
  (shape: _triangle, upTo: 1),
];
