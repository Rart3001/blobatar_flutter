/// A faithful port of blobatar's `src/expression.ts`.
///
/// An expression is a named pose the consumer sets and the widget holds —
/// a separate axis from the idle motion in `motion.dart`. Every channel
/// here moves a part the blobatar already has (eyes, body offset); nothing
/// adds a mark, so a blob grows no mouth when it is happy.
///
/// Upstream composes poses through CSS custom properties and keyframes,
/// which has no direct Flutter equivalent. This port keeps the exact same
/// [Pose] channel values (they are the actual design, tuned by hand against
/// reference renders) but applies them by re-running the bake transform
/// every frame against the *current interpolated* pose, rather than
/// splitting a "baked" static path from a CSS-driven animated one. The
/// visual result is the same; see `widget.dart` for how the morph timing
/// (300ms entering / 400ms returning to idle, on the same easing curve
/// upstream uses) is reproduced.
library;

import 'dart:ui';

import 'package:blobatar_flutter/src/color.dart';
import 'package:blobatar_flutter/src/motion.dart';
import 'package:blobatar_flutter/src/styles/layout.dart';
import 'package:flutter/foundation.dart';

/// The channels a pose may touch. Units: scales are factors, `tilt` is
/// degrees, offsets are viewBox units (0..100 space), `heat` and `shake`
/// are 0–1 amounts. The `*2` channels are the *second eye's differential*
/// (added on top of the shared channel, right eye only) — an identity of 0
/// keeps a pose symmetric.
@immutable
class Pose {
  /// Creates a pose. Every channel defaults to its identity, so a pose only
  /// states what it actually changes.
  const Pose({
    this.esx = 1,
    this.esy = 1,
    this.tilt = 0,
    this.edy = 0,
    this.edx = 0,
    this.esx2 = 0,
    this.esy2 = 0,
    this.tilt2 = 0,
    this.edy2 = 0,
    this.lock = 0,
    this.heat = 0,
    this.shake = 0,
    this.rock = 0,
    this.bdy = 0,
  });

  /// Eye width, about each eye's own center.
  final double esx;

  /// Eye height, about each eye's own center.
  final double esy;

  /// Eye tilt, mirrored per side (left: -tilt, right: +tilt, before the
  /// `*2` differential).
  final double tilt;

  /// Eye pair offset, positive = down.
  final double edy;

  /// Eye convergence, positive = apart.
  final double edx;

  /// The right eye's width differential. The `*2` channels are what let one
  /// eye squint while the other stays open — a wink drives all three.
  final double esx2;

  /// The right eye's height differential.
  final double esy2;

  /// The right eye's tilt differential, in degrees.
  final double tilt2;

  /// The right eye's vertical differential. Unlike the other `*2` channels it
  /// has a moving counterpart: see [rock].
  final double edy2;

  /// How much of the seed's own eye lean the pose overrides, 0–1. At 0 the
  /// pose's tilt adds to whatever lean the seed drew; at 1 the seeded lean
  /// is replaced outright by the pose's tilt.
  final double lock;

  /// How far the palette shifts toward its tint target, 0–1.
  final double heat;

  /// Tremor amplitude, 0–1.
  final double shake;

  /// How much of [edy2] is handed to the seesaw loop instead of being baked
  /// onto the right eye, 0–1. At 0 the differential is static; at 1 the pair
  /// swings the same distance symmetrically about its own centre, so each eye
  /// takes `(1 + wrap * phase) / 2` of it, `wrap` being -1 left and +1 right.
  final double rock;

  /// Whole-creature vertical offset, positive = down.
  final double bdy;

  /// The pose that changes nothing — every channel at its default.
  static const identity = Pose();

  /// Linear interpolation between two poses — what the CSS `transition` on
  /// each custom property does, one frame at a time.
  Pose lerp(Pose other, double t) => Pose(
        esx: esx + (other.esx - esx) * t,
        esy: esy + (other.esy - esy) * t,
        tilt: tilt + (other.tilt - tilt) * t,
        edy: edy + (other.edy - edy) * t,
        edx: edx + (other.edx - edx) * t,
        esx2: esx2 + (other.esx2 - esx2) * t,
        esy2: esy2 + (other.esy2 - esy2) * t,
        tilt2: tilt2 + (other.tilt2 - tilt2) * t,
        rock: rock + (other.rock - rock) * t,
        edy2: edy2 + (other.edy2 - edy2) * t,
        lock: lock + (other.lock - lock) * t,
        heat: heat + (other.heat - heat) * t,
        shake: shake + (other.shake - shake) * t,
        bdy: bdy + (other.bdy - bdy) * t,
      );

  @override
  bool operator ==(Object other) =>
      other is Pose &&
      esx == other.esx &&
      esy == other.esy &&
      tilt == other.tilt &&
      edy == other.edy &&
      edx == other.edx &&
      esx2 == other.esx2 &&
      esy2 == other.esy2 &&
      tilt2 == other.tilt2 &&
      edy2 == other.edy2 &&
      rock == other.rock &&
      lock == other.lock &&
      heat == other.heat &&
      shake == other.shake &&
      bdy == other.bdy;

  @override
  int get hashCode => Object.hash(esx, esy, tilt, edy, edx, esx2, esy2, tilt2,
      edy2, lock, heat, shake, rock, bdy,);
}

/// A pose plus (optionally) the palette tint it wears.
@immutable
class Expression {
  /// Creates an expression from a pose and, for the ones that recolour, a
  /// tint.
  const Expression(this.pose, [this.tint]);

  /// How the eyes and body are held.
  final Pose pose;

  /// Where the palette heads, for the expressions that recolour. Null leaves
  /// the seeded palette alone.
  final Tint? tint;

  @override
  bool operator ==(Object other) =>
      other is Expression && pose == other.pose && tint == other.tint;

  @override
  int get hashCode => Object.hash(pose, tint);
}

/// The resting face: the layout as the seed built it, nothing added.
const idleExpression = Expression(Pose.identity);

/// Wide flat arcs riding high: the universal smiling squint.
const happyExpression = Expression(Pose(
  esx: 1.72,
  esy: 0.3,
  tilt: 8,
  edy: -1.5,
  edx: 1.5,
  esx2: 0.08,
  esy2: 0.05,
  tilt2: -16,
  lock: 1,
  bdy: -2.2,
),);

/// Small eyes, low and drifted apart, over a body that sinks.
const sadExpression = Expression(Pose(
  esx: 0.6,
  esy: 0.56,
  tilt: 26,
  edy: 3.6,
  edx: 1.9,
  esx2: -0.05,
  esy2: -0.07,
  tilt2: -7,
  lock: 1,
  bdy: 2.6,
),);

/// A hard V of flat bars over a body that compresses, leans and runs hot.
const madExpression = Expression(
  Pose(
    esx: 1.85,
    esy: 0.26,
    tilt: -33,
    edy: 0.4,
    edx: 0.6,
    esy2: -0.03,
    tilt2: 5,
    lock: 1,
    heat: 0.62,
    shake: 0.55,
    bdy: 0.8,
  ),
  hotTint,
);

/// Eyes enlarged rather than squashed — the antipode of `mad`.
const surprisedExpression = Expression(Pose(
  esx: 1.34,
  esy: 1.2,
  tilt: -6,
  edy: -1.05,
  edx: 0.5,
  esx2: 0.05,
  esy2: 0.07,
  tilt2: 3,
  lock: 1,
  bdy: -1.4,
),);

/// One eye a flat arc, the other open.
const winkExpression = Expression(Pose(
  esx: 1.32,
  esy: 0.76,
  tilt: 5,
  edy: -0.6,
  edx: 0.8,
  esx2: 0.26,
  esy2: -0.56,
  tilt2: -11,
  lock: 1,
  bdy: -1.1,
),);

/// Flat bars with no angle in them, sitting low over a sunk body.
const sleepyExpression = Expression(Pose(
  esx: 1.14,
  esy: 0.22,
  edy: 2.4,
  edx: 0.3,
  esx2: -0.04,
  esy2: 0.03,
  tilt2: 4,
  lock: 1,
  bdy: 1.2,
),);

/// Half-lidded, lifted, and leaning in parallel (a cocked head, not a brow).
const smugExpression = Expression(Pose(
  esx: 1.3,
  esy: 0.42,
  tilt: 18,
  edy: -0.5,
  edx: 0.5,
  esx2: 0.06,
  esy2: -0.06,
  tilt2: -36,
  lock: 1,
  bdy: -1,
),);

/// One eye narrowed, the other open.
const unsureExpression = Expression(Pose(
  esx: 0.95,
  esy: 1.02,
  tilt: 4,
  edy: -0.2,
  edx: 0.3,
  esx2: 0.24,
  esy2: -0.44,
  tilt2: -18,
  lock: 1,
),);

/// Small eyes held high and pulled together, over a body that trembles.
const scaredExpression = Expression(Pose(
  esx: 0.78,
  esy: 0.96,
  tilt: -12,
  edy: -1.5,
  edx: -0.8,
  esx2: -0.04,
  esy2: 0.05,
  tilt2: 4,
  lock: 1,
  shake: 0.35,
  bdy: -0.6,
),);

/// Tall narrow eyes, drawn together, lifted, and rose.
const loveExpression = Expression(
  Pose(
    esx: 0.86,
    esy: 1.28,
    tilt: -14,
    edy: -0.5,
    edx: -0.35,
    esx2: 0.05,
    esy2: 0.06,
    tilt2: 6,
    lock: 1,
    heat: 0.6,
    bdy: -1.6,
  ),
  roseTint,
);

/// Small squeezed eyes, low and wide apart, over a body that sinks and
/// blushes.
const shyExpression = Expression(
  Pose(
    esx: 0.62,
    esy: 0.5,
    tilt: 10,
    edy: 1.4,
    edx: -0.2,
    esx2: -0.05,
    esy2: -0.04,
    tilt2: -8,
    lock: 1,
    heat: 0.55,
    bdy: 0.9,
  ),
  blushTint,
);

/// Flat bars slumped into a worried shape, over a body that sinks, greens
/// and trembles.
const sickExpression = Expression(
  Pose(
    esx: 1.25,
    esy: 0.34,
    tilt: 20,
    edy: 1.8,
    edx: 0.8,
    esx2: 0.05,
    esy2: -0.05,
    tilt2: -6,
    lock: 1,
    heat: 0.6,
    shake: 0.18,
    bdy: 1.4,
  ),
  bileTint,
);

/// Eyes dropped low and staggered, the pair rocking slowly — a look held
/// somewhere else rather than at you. gen2's fourteenth expression, and the
/// only one that uses [Pose.edy2] and [Pose.rock].
const thinkingExpression = Expression(Pose(
  esx: 1.15,
  esy: 0.62,
  edy: 4.2,
  edx: 0.4,
  esx2: 0.02,
  esy2: 0.06,
  edy2: -8.4,
  lock: 1,
  rock: 0.8,
  bdy: -0.4,
),);

/// Every named expression, for pickers/demos.
const Map<String, Expression> expressions = {
  'idle': idleExpression,
  'happy': happyExpression,
  'sad': sadExpression,
  'mad': madExpression,
  'surprised': surprisedExpression,
  'wink': winkExpression,
  'sleepy': sleepyExpression,
  'smug': smugExpression,
  'unsure': unsureExpression,
  'scared': scaredExpression,
  'love': loveExpression,
  'shy': shyExpression,
  'sick': sickExpression,
  'thinking': thinkingExpression,
};

/// Applies a pose to a layout's eyes, and returns the whole-body offset
/// ([Pose.bdy]) for the caller to translate by. A faithful port of
/// upstream's `bakePose`.
/// [rockPhase] drives the seesaw when the pose has `rock > 0`; leave it null
/// for the static bake, which is upstream's `bakePose` exactly.
({BlobLayout layout, double bdy}) bakePose(BlobLayout layout, Pose p,
    {double? rockPhase,}) {
  final newEyes = List<BlobEye>.generate(2, (i) {
    final right = i == 1;
    final e = layout.eyes[i];
    final share = rockPhase == null
        ? (right ? 1.0 : 0.0)
        : rockShare(p.rock, rockPhase, right: right);
    return e.copyWith(
      cx: e.cx + p.edx * (right ? 1 : -1),
      cy: e.cy + p.edy + p.edy2 * share,
      rx: e.rx * (p.esx + (right ? p.esx2 : 0)),
      ry: e.ry * (p.esy + (right ? p.esy2 : 0)),
      rot: e.rot * (1 - p.lock) +
          (p.tilt + (right ? p.tilt2 : 0)) * (right ? 1 : -1),
    );
  });
  return (layout: layout.copyWith(eyes: newEyes), bdy: p.bdy);
}

/// The endpoint a tint heads toward.
///
/// This is the expensive half — it walks the whole mix looking for the eye
/// lightness that holds 4.55:1 everywhere along it, which measures at ~28us
/// against ~0.2us for everything else a frame does outside `paint`. It does
/// not depend on `heat`, so a widget morphing through a tint resolves it once
/// per (palette, tint) and reuses it for every frame.
TintTarget tintTargetFor(BlobatarPalette pal, Tint tint) {
  final (head, eye) = tintedPair(pal.head, pal.eye, tint);
  return (head: head, eye: eye);
}

/// The resolved endpoint of a tint. See [tintTargetFor].
typedef TintTarget = ({Color head, Color eye});

/// Mixes [pal] toward [tint] by [heat] (0–1), holding the contrast
/// guarantee across the whole mix. A faithful port of upstream's
/// `tintWith`.
///
/// Pass [target] to skip re-deriving the endpoint; it must be the value
/// [tintTargetFor] returns for this same palette and tint.
BlobatarPalette tintPalette(BlobatarPalette pal, double heat, Tint tint,
    {TintTarget? target,}) {
  if (heat <= 0) return pal;
  final t = target ?? tintTargetFor(pal, tint);
  return pal.copyWith(
    head: mixColor(pal.head, t.head, heat),
    eye: mixColor(pal.eye, t.eye, heat),
  );
}
