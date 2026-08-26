/// A port of blobatar's idle motion layer (`src/animate.ts` +
/// `src/motion.css`).
///
/// Upstream drives this with CSS `@keyframes` and registered custom
/// properties, which has no Flutter equivalent — this file reimplements the
/// same *design* (seeded per-blobatar phase/period so a grid reads as a
/// crowd rather than a heartbeat; the same breathe/bob/blink timings; the
/// same six-direction saccade) as plain functions of elapsed milliseconds,
/// called once per frame from a [Ticker] in `widget.dart`.
///
/// Faithfully ported: breathe and bob periods and amplitudes, the blink
/// hold/close/open timing, the saccade fixation directions and their
/// per-seed magnitude/period/phase, and the shake tremor. Simplified:
/// upstream's "wrap" layer also foreshortens and subtly tilts the eyes
/// during a saccade (a few hundredths of a degree, tuned per fixation) —
/// this port keeps the dominant translate but not that secondary polish
/// pass, so a glance here reads as a look rather than a look-plus-lean.
library;

import 'package:blobatar_flutter/blobatar_flutter.dart' show Pose;
import 'package:blobatar_flutter/src/pose.dart' show Pose;
import 'package:blobatar_flutter/src/traits.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/scheduler.dart' show Ticker;

/// Per-seed idle timing, derived once from the hashed traits — analogous to
/// upstream's `motionVars`.
class MotionSeed {
  /// Creates a motion seed. Normally read from traits by [computeMotionSeed]
  /// rather than written out.
  const MotionSeed({
    required this.breathePhaseMs,
    required this.bobPhaseMs,
    required this.blinkPeriodMs,
    required this.blinkPhaseMs,
    required this.lookX,
    required this.lookMagX,
    required this.lookY,
    required this.lookMagY,
    required this.saccadePeriodMs,
    required this.saccadePhaseMs,
  });

  /// Where in the breathe cycle this blobatar starts, in milliseconds. Phases
  /// are seeded so a grid reads as a crowd rather than a heartbeat.
  final double breathePhaseMs;

  /// Where in the bob cycle this blobatar starts, in milliseconds.
  final double bobPhaseMs;

  /// How long between blinks, in milliseconds.
  final double blinkPeriodMs;

  /// Where in the blink cycle this blobatar starts, in milliseconds.
  final double blinkPhaseMs;

  /// Signed look magnitude on X — sign is seeded independently of magnitude
  /// so a seed can never land near zero and "never look anywhere".
  final double lookX;
  /// The unsigned magnitude behind [lookX], in viewBox units. Kept alongside
  /// the signed value so a consumer can ask how far this blobatar glances
  /// without asking which way.
  final double lookMagX;

  /// Signed look magnitude on Y, seeded the same way as [lookX].
  final double lookY;

  /// The unsigned magnitude behind [lookY], in viewBox units.
  final double lookMagY;

  /// How long a full six-fixation saccade round takes, in milliseconds.
  final double saccadePeriodMs;

  /// Where in the saccade round this blobatar starts, in milliseconds.
  final double saccadePhaseMs;
}

/// Reads one blobatar's idle timing out of its traits.
///
/// Keyed reads, like every other trait: the phases a seed gets are as fixed as
/// the silhouette it gets.
MotionSeed computeMotionSeed(Traits t) {
  final blink = t.num('motion.blink', 3500, 6500).roundToDouble();
  final saccade = t.num('motion.saccade', 4200, 7600).roundToDouble();
  final lookMagX = t.num('motion.lookX', 1, 2.2);
  final lookMagY = t.num('motion.lookY', 0.8, 1.7);

  return MotionSeed(
    breathePhaseMs: t.num('motion.phase', 0, 2800),
    bobPhaseMs: t.num('motion.bob', 0, 3400),
    blinkPeriodMs: blink,
    blinkPhaseMs: t.num('motion.blinkPhase', 0, blink),
    lookX: lookMagX * (t.boolean('motion.lookXFlip') ? -1 : 1),
    lookMagX: lookMagX,
    lookY: lookMagY * (t.boolean('motion.lookYFlip') ? -1 : 1),
    lookMagY: lookMagY,
    saccadePeriodMs: saccade,
    saccadePhaseMs: t.num('motion.saccadePhase', 0, saccade),
  );
}

double _easeInOut(double x) =>
    x < 0.5 ? 2 * x * x : 1 - ((-2 * x + 2) * (-2 * x + 2)) / 2;
double _easeIn(double x) => x * x;
double _easeOut(double x) => 1 - (1 - x) * (1 - x);

/// Breathe: a slight squash-and-stretch, alternating over a 2800ms leg in
/// each direction (5600ms full cycle), gated by [amp] (0 = still, 1 = full
/// amplitude — the hover/always gate).
Offset breatheScale(double elapsedMs, MotionSeed seed, double amp) {
  const legMs = 2800.0;
  final pos = (elapsedMs + seed.breathePhaseMs) % (legMs * 2);
  final leg = pos < legMs ? pos / legMs : (2 * legMs - pos) / legMs;
  final progress = _easeInOut(leg) * amp;
  return Offset(1 + 0.022 * progress, 1 - 0.018 * progress);
}

/// Bob: a 3400ms vertical drift, deliberately not a multiple of breathe's
/// period so the two drift in and out of phase.
double bobOffset(double elapsedMs, MotionSeed seed, double amp) {
  const legMs = 3400.0;
  final pos = (elapsedMs + seed.bobPhaseMs) % (legMs * 2);
  final leg = pos < legMs ? pos / legMs : (2 * legMs - pos) / legMs;
  final progress = _easeInOut(leg) * amp;
  return -1.1 * progress;
}

/// Blink: eyes are open for 97.2% of the (seeded) period, close quickly,
/// then reopen — a short window at the end of a long hold, so the blink's
/// real duration scales with the period (a slower blinker reads sleepier).
double eyeBlinkScaleY(double elapsedMs, MotionSeed seed, double amp) {
  final period = seed.blinkPeriodMs;
  if (period <= 0) return 1;
  final pos = (elapsedMs + seed.blinkPhaseMs) % period;
  final pct = pos / period * 100;
  if (pct < 97.2) return 1;
  if (pct < 98.6) {
    final local = (pct - 97.2) / (98.6 - 97.2);
    return 1 - 0.92 * amp * _easeIn(local);
  }
  final local = (pct - 98.6) / (100 - 98.6);
  return (1 - 0.92 * amp) + 0.92 * amp * _easeOut(local);
}

/// Six seeded fixations around the compass plus a return to center,
/// expressed as jump-then-hold stops (percent through the saccade period,
/// direction coefficients). Faithful to upstream's `@keyframes mo-saccade`.
const List<({double pct, double dx, double dy})> _saccadeStops = [
  (pct: 0, dx: 0, dy: 0),
  (pct: 15, dx: 0, dy: 0),
  (pct: 16.5, dx: -0.8, dy: -0.9),
  (pct: 31, dx: -0.8, dy: -0.9),
  (pct: 32.5, dx: 1.0, dy: 0.1),
  (pct: 47, dx: 1.0, dy: 0.1),
  (pct: 48.5, dx: -0.15, dy: 0.85),
  (pct: 63, dx: -0.15, dy: 0.85),
  (pct: 64.5, dx: 0.75, dy: -0.8),
  (pct: 79, dx: 0.75, dy: -0.8),
  (pct: 80.5, dx: -1.0, dy: -0.15),
  (pct: 98.5, dx: -1.0, dy: -0.15),
  (pct: 100, dx: 0, dy: 0),
];

/// Both eyes glancing together, in viewBox px.
Offset saccadeOffset(double elapsedMs, MotionSeed seed, double amp) {
  final period = seed.saccadePeriodMs;
  if (period <= 0) return Offset.zero;
  final pos = (elapsedMs + seed.saccadePhaseMs) % period;
  final pct = pos / period * 100;

  for (var i = 0; i < _saccadeStops.length - 1; i++) {
    final a = _saccadeStops[i];
    final b = _saccadeStops[i + 1];
    if (pct >= a.pct && pct <= b.pct) {
      final t = b.pct == a.pct ? 0.0 : (pct - a.pct) / (b.pct - a.pct);
      final dxCoef = a.dx + (b.dx - a.dx) * t;
      final dyCoef = a.dy + (b.dy - a.dy) * t;
      return Offset(dxCoef * seed.lookX * amp, dyCoef * seed.lookY * amp);
    }
  }
  return Offset.zero;
}

/// A held tremor (irregular, not a sinusoid, so it reads as a shake rather
/// than an orbit), amplitude given by [Pose.shake].
const List<({double pct, double dx, double dy})> _shakeStops = [
  (pct: 0, dx: 0.62, dy: -0.34),
  (pct: 25, dx: -0.7, dy: 0.22),
  (pct: 50, dx: 0.38, dy: 0.66),
  (pct: 75, dx: -0.44, dy: -0.6),
  (pct: 100, dx: 0.62, dy: -0.34),
];

/// The tremor offset at [elapsedMs], scaled by [shakeAmp], in viewBox units.
///
/// A 112ms loop through five keyframes, matching upstream's `shake` keyframes
/// stop for stop. Not hover-gated: a pose with `shake > 0` trembles whenever
/// it is worn. Returns [Offset.zero] when the pose does not shake at all.
Offset shakeOffset(double elapsedMs, double shakeAmp) {
  if (shakeAmp <= 0) return Offset.zero;
  const periodMs = 112.0;
  final pct = (elapsedMs % periodMs) / periodMs * 100;
  for (var i = 0; i < _shakeStops.length - 1; i++) {
    final a = _shakeStops[i];
    final b = _shakeStops[i + 1];
    if (pct >= a.pct && pct <= b.pct) {
      final t = (pct - a.pct) / (b.pct - a.pct);
      final dx = a.dx + (b.dx - a.dx) * t;
      final dy = a.dy + (b.dy - a.dy) * t;
      return Offset(dx * shakeAmp, dy * shakeAmp);
    }
  }
  return Offset.zero;
}

/// The seesaw phase, +1 -> -1 -> +1 over 900ms on CSS's `ease-in-out`.
///
/// 1 to -1 rather than 0 to 1 so the *stagger* reverses instead of appearing
/// and vanishing. Frame zero is the extreme, which is exactly what `bakePose`
/// emits — so a static render and the first animated frame agree, and reduced
/// motion can simply hold the baked pose.
///
/// Like [shakeOffset] this is not hover-gated: it plays whenever a pose with
/// `rock > 0` is worn. At `rock == 0` — every expression but `thinking` — the
/// share below discards it entirely, so nothing starts and nothing stops.
double rockPhase(double elapsedMs) {
  const periodMs = 900.0;
  const easeInOut = Cubic(0.42, 0, 0.58, 1);
  final pos = (elapsedMs % periodMs) / periodMs;
  // CSS applies the timing function between each pair of keyframes, not once
  // across the whole loop.
  if (pos < 0.5) return 1 - 2 * easeInOut.transform(pos / 0.5);
  return -1 + 2 * easeInOut.transform((pos - 0.5) / 0.5);
}

/// How much of [Pose.edy2] one eye carries.
///
/// At `rock == 0` this is upstream's static selector: all of it on the right
/// eye, none on the left. As `rock` rises the pair swings the same distance
/// symmetrically about its own centre instead, each eye taking
/// `(1 + wrap * phase) / 2`, with `wrap` -1 on the left and +1 on the right.
/// At phase +1 that expression *is* the static selector on both eyes, which is
/// why the baked stagger is exactly the loop's own extreme and needs no
/// compensating term.
double rockShare(double rock, double phase, {required bool right}) {
  final sel = right ? 1.0 : 0.0;
  if (rock <= 0) return sel;
  final wrap = right ? 1.0 : -1.0;
  return sel * (1 - rock) + rock * ((1 + wrap * phase) / 2);
}
