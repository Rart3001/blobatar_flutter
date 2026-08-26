/// A port of blobatar's `src/styles/compose.ts` and `src/styles/blob.ts`.
///
/// The band table chooses and weights silhouettes (see `shapes.dart`); each
/// silhouette owns its geometry and safe face region; this module owns the
/// shared body and the eye fit.
///
/// Every eye dimension is a fraction of the body radius rather than an
/// absolute unit, and containment — eyes never leaving the face region,
/// geometry never leaving the frame — is guaranteed by construction rather
/// than by sampling. See the `fit` scaling below.
library;

import 'dart:math' as math;
import 'dart:ui';

import 'package:blobatar_flutter/src/styles/shapes.dart';
import 'package:blobatar_flutter/src/traits.dart';

export 'shapes.dart' show BlobBody, BlobPetal, BlobShape, Ellipse;

/// One eye: a superellipse with its own tilt, already fitted to the face.
class BlobEye {
  /// Creates an eye, in viewBox units.
  const BlobEye({
    required this.cx,
    required this.cy,
    required this.rx,
    required this.ry,
    required this.n,
    required this.rot,
  });

  /// Centre x, in viewBox units.
  final double cx;

  /// Centre y, in viewBox units.
  final double cy;

  /// Half-width, in viewBox units.
  final double rx;

  /// Half-height, in viewBox units.
  final double ry;

  /// Superellipse exponent: 2 is an ellipse, higher is capsule-like.
  final double n;

  /// Tilt about the eye's own centre, in degrees.
  final double rot;

  /// This eye with the given fields replaced — how a pose wears an expression
  /// without rebuilding the layout around it.
  BlobEye copyWith(
          {double? cx,
          double? cy,
          double? rx,
          double? ry,
          double? n,
          double? rot,}) =>
      BlobEye(
        cx: cx ?? this.cx,
        cy: cy ?? this.cy,
        rx: rx ?? this.rx,
        ry: ry ?? this.ry,
        n: n ?? this.n,
        rot: rot ?? this.rot,
      );
}

/// The full numeric layout for one blobatar, in 0..100 viewBox units — the
/// same coordinate space upstream's SVG uses, kept here so painters can scale
/// it to any pixel size.
class BlobLayout {
  /// Creates a layout. Produced by [computeLayout]; consumers read it.
  const BlobLayout({
    required this.shape,
    required this.body,
    required this.face,
    required this.petals,
    required this.extra,
    required this.eyes,
    required this.draw,
  });

  /// Which silhouette the seed landed on.
  final BlobShape shape;

  /// The core body, already patched by its shape.
  final BlobBody body;

  /// The region the eyes were fitted against — the body itself for the
  /// silhouettes that are convex around their own centre.
  final Ellipse face;

  /// Circles painted in the head colour alongside the body.
  final List<BlobPetal> petals;

  /// Extra outlines unioned with the core body, already traced.
  final List<Path> extra;

  /// Exactly two: left, then right.
  final List<BlobEye> eyes;

  /// The core path for this silhouette.
  final Path Function(BlobBody b)? draw;

  /// This layout with different eyes — the only part of it a pose touches.
  /// A pose's whole-creature vertical offset rides outside the layout, which
  /// is why `bakePose` hands it back separately.
  BlobLayout copyWith({List<BlobEye>? eyes}) => BlobLayout(
        shape: shape,
        body: body,
        face: face,
        petals: petals,
        extra: extra,
        eyes: eyes ?? this.eyes,
        draw: draw,
      );
}

/// Fits the eye cluster against the silhouette's face region on both axes.
///
/// The two-axis measurement is what lets a wide-but-short face (a capsule) and
/// a narrow one (a triangle's lower half) both hold the same eye vocabulary:
/// the cluster is scaled as a unit until it fits the tighter of the two.
List<BlobEye> _faceFit(Traits t, BlobBody b, Ellipse face) {
  final rx = b.rx;
  final er0 = t.num('eye.rx', 0.075, 0.105) * rx;
  final ratio = t.num('eye.ratio', 1.9, 3.2);
  final scale = t.num('eye.scale', 0.78, 1.24);
  final stretch = t.num('eye.stretch', 0.85, 1.18);
  final clearance = t.num('eye.gap', 0.1, 0.24) * rx;
  final wide = er0 * math.max(1, scale);
  final tall = er0 * ratio * math.max(1, scale * stretch);
  final gap0 = wide + rx * 0.03 + clearance;

  final gx = t.jitter('gaze.x', 0.09) * face.rx;
  final gy = t.num('gaze.y', -0.2, 0.08) * face.ry;
  final dy = t.jitter('eye.dy', 0.04) * face.ry;
  final reach = _hypot(wide, tall);
  final need = _hypot(
    (gx.abs() + gap0 + reach) / face.rx,
    (gy.abs() + dy.abs() + reach) / face.ry,
  );
  final fit = need > 0.9 ? 0.9 / need : 1.0;

  final er = er0 * fit;
  final eyeRy = er * ratio;
  final gap = gap0 * fit;

  // Lean is bounded by the clearance rather than drawn freely, so a tilted
  // pair can never sweep into each other.
  final room = math.max<double>(0, math.min<double>(1, clearance / tall));
  final bound = math.min<double>(12, math.asin(room) * 180 / math.pi);
  final lean = t.num('eye.lean', -1, 1) * bound;
  final leaned = lean + t.jitter('eye.lean2', 3.5);
  final lean2 = math.max<double>(-12, math.min<double>(12, leaned));

  final cx = face.cx + gx * fit;
  final cy = face.cy + gy * fit;
  return [
    BlobEye(
        cx: cx - gap,
        cy: cy,
        rx: er,
        ry: eyeRy,
        n: t.num('eye.n', 3.5, 6),
        rot: lean,),
    BlobEye(
      cx: cx + gap,
      cy: cy + dy * fit,
      rx: er * scale,
      ry: eyeRy * scale * stretch,
      n: t.num('eye.n', 3.5, 6),
      rot: lean2,
    ),
  ];
}

/// `Math.hypot` with two arguments, reproducing **V8's** result bit for bit.
///
/// This is not `sqrt(a*a + b*b)`, and the difference is not academic: upstream
/// computes the eye fit through `Math.hypot`, and that function is *not*
/// bit-stable across JavaScript engines. V8 (Chrome, Edge, Node) evaluates it
/// as the scaled form below; JavaScriptCore (Safari, Bun) uses a
/// correctly-rounded algorithm that disagrees in roughly a third of inputs, by
/// one unit in the last place.
///
/// Upstream's *rendered* output is unaffected: it serializes SVG coordinates
/// through `Math.round(v * 100) / 100`, which absorbs the difference on every
/// seed measured (0 of 349). The divergence survives only in the unrounded
/// numbers its `layout()` export returns — and this port paints from those
/// directly, with no rounding step to hide behind, so it has to choose an
/// engine.
///
/// It chooses V8, because that is what the large majority of blobatar's users
/// see. The gap reaches the 16th significant digit, around 1e-13 of a pixel at
/// any real render size, so nothing is visibly different either way; it is
/// exact equality in the parity suite that forces the choice to be made
/// explicitly rather than by accident.
///
/// Verified against both engines over 300k random pairs; see
/// tool/extract_upstream_vectors.ts, which normalizes the fixture to V8.
double _hypot(double a, double b) {
  final absA = a.abs();
  final absB = b.abs();
  final max = absA > absB ? absA : absB;
  if (max == 0) return 0;
  final x = absA / max;
  final y = absB / max;
  return math.sqrt(x * x + y * y) * max;
}

ShapeDef _pick(double v) {
  for (final band in bands) {
    if (v < band.upTo) return band.shape;
  }
  return bands.last.shape;
}

/// Reads a whole blobatar out of one trait source: silhouette, body, face
/// region, decorations and the fitted pair of eyes.
///
/// Pure and total — the same traits always produce the same layout, which is
/// what makes a seed a name rather than a roll.
BlobLayout computeLayout(Traits t) {
  final shape = _pick(t('shape'));
  final r = t.num('body.r', 31, 38) * shape.core;

  final ptsCount = t.intRange('body.pts', 6, 8);
  final body = BlobBody(
    cx: 50 + t.jitter('body.x', 1.5),
    cy: 50 + t.jitter('body.y', 1.5),
    rx: r,
    ry: r * t.num('body.ratio', 0.92, 1.08),
    n: t.num('body.n', 1.9, 2.5),
    rot: 0,
    radii:
        List<double>.generate(ptsCount, (i) => 1 + t.jitter('body.r$i', 0.16)),
  );
  shape.body?.call(t, body);

  // The body itself when the shape names no face, which is what a silhouette
  // convex around its own centre wants — and it already carries the four
  // fields a face is.
  final face =
      shape.face?.call(body) ?? Ellipse(body.cx, body.cy, body.rx, body.ry);

  final deco = Deco();
  shape.decorate?.call(t, body, deco);

  return BlobLayout(
    shape: shape.name,
    body: body,
    face: face,
    petals: deco.petals,
    extra: deco.extra,
    eyes: _faceFit(t, body, face),
    draw: shape.path,
  );
}
