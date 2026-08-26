import 'package:blobatar_flutter/src/motion.dart';
import 'package:blobatar_flutter/src/traits.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final seed = computeMotionSeed(Traits('alain'));

  group('blink', () {
    test('holds open for most of the period, then closes and reopens', () {
      final period = seed.blinkPeriodMs;
      // Upstream's shape: open until 97.2% of the period, shut by 98.6%, open
      // again by 100%. Sampling the whole cycle is the only way to see it —
      // the closed window is 1.4% wide.
      double at(double pct) =>
          eyeBlinkScaleY(pct / 100 * period - seed.blinkPhaseMs, seed, 1);

      expect(at(50), 1, reason: 'should be wide open mid-cycle');
      expect(at(97), 1, reason: 'should not have started closing yet');
      // The closed extreme: 1 - 0.92, reached where the closing and opening
      // halves meet. The two branches must agree there or the eye would jump.
      expect(at(98.6), closeTo(0.08, 1e-9), reason: 'should be shut');
      expect(at(99.9), greaterThan(0.9), reason: 'should have reopened');
    });

    test('never turns the eye inside out', () {
      for (var i = 0; i < 2000; i++) {
        final v = eyeBlinkScaleY(i * 3.7, seed, 1);
        expect(v, greaterThanOrEqualTo(0));
        expect(v, lessThanOrEqualTo(1));
      }
    });

    test('the amplitude gate holds the eye open', () {
      for (var i = 0; i < 2000; i++) {
        expect(eyeBlinkScaleY(i * 3.7, seed, 0), 1);
      }
    });
  });

  group('tremor', () {
    test('displaces, and scales with the pose amount', () {
      // A tremor reads as a shake rather than an orbit, so it is sampled
      // across its 112ms loop rather than trusted at one instant.
      var maxHalf = 0.0;
      var maxFull = 0.0;
      for (var ms = 0.0; ms < 112; ms += 0.5) {
        maxHalf = [maxHalf, shakeOffset(ms, 0.5).distance]
            .reduce((a, b) => a > b ? a : b);
        maxFull = [maxFull, shakeOffset(ms, 1).distance]
            .reduce((a, b) => a > b ? a : b);
      }
      expect(maxHalf, greaterThan(0));
      expect(maxFull, closeTo(maxHalf * 2, 1e-9));
    });

    test('is exactly nothing at zero amplitude', () {
      for (var ms = 0.0; ms < 500; ms += 1.3) {
        expect(shakeOffset(ms, 0), Offset.zero);
      }
    });

    test('loops seamlessly', () {
      expect(shakeOffset(0, 1).dx, closeTo(shakeOffset(112, 1).dx, 1e-9));
      expect(shakeOffset(0, 1).dy, closeTo(shakeOffset(112, 1).dy, 1e-9));
    });
  });

  group('seesaw', () {
    test('swings between the extremes and returns', () {
      expect(rockPhase(0), closeTo(1, 1e-9));
      expect(rockPhase(450), closeTo(-1, 1e-9));
      expect(rockPhase(900), closeTo(1, 1e-9));
    });

    test('stays inside its range', () {
      for (var ms = 0.0; ms < 3000; ms += 2.7) {
        expect(rockPhase(ms), inInclusiveRange(-1, 1));
      }
    });

    test('at rest the whole differential sits on the right eye', () {
      expect(rockShare(0, rockPhase(0), right: true), 1);
      expect(rockShare(0, rockPhase(0), right: false), 0);
    });

    test('phase +1 matches the static bake on both eyes', () {
      // This is why bakePose needs no compensating term: frame zero of the
      // loop *is* what it emits.
      expect(rockShare(0.8, 1, right: true), closeTo(1, 1e-9));
      expect(rockShare(0.8, 1, right: false), closeTo(0, 1e-9));
    });

    test('a full rock trades the stagger between the eyes', () {
      expect(rockShare(1, -1, right: true), closeTo(0, 1e-9));
      expect(rockShare(1, -1, right: false), closeTo(1, 1e-9));
      // Symmetric about the pair's centre at every phase.
      for (var ms = 0.0; ms < 900; ms += 11) {
        final p = rockPhase(ms);
        expect(rockShare(1, p, right: true) + rockShare(1, p, right: false),
            closeTo(1, 1e-9),);
      }
    });
  });

  group('breathe and bob', () {
    test('stay within their documented amplitudes', () {
      for (var ms = 0.0; ms < 12000; ms += 7) {
        final b = breatheScale(ms, seed, 1);
        expect(b.dx, inInclusiveRange(1, 1.022));
        expect(b.dy, inInclusiveRange(0.982, 1));
        expect(bobOffset(ms, seed, 1), inInclusiveRange(-1.1, 0));
      }
    });

    test('are exactly at rest when the gate is shut', () {
      for (var ms = 0.0; ms < 12000; ms += 7) {
        expect(breatheScale(ms, seed, 0), const Offset(1, 1));
        expect(bobOffset(ms, seed, 0), 0);
      }
    });

    test('different seeds are out of phase with each other', () {
      // A grid should read as a crowd, not a heartbeat.
      final other = computeMotionSeed(Traits('renata'));
      expect(breatheScale(1000, seed, 1).dx,
          isNot(closeTo(breatheScale(1000, other, 1).dx, 1e-4)),);
    });
  });
}
