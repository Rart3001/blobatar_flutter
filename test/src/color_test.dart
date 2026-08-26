import 'package:blobatar_flutter/src/color.dart';
import 'package:blobatar_flutter/src/hash.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('tone swatch selection', () {
    test('tone 1.0 lands on the last swatch, not the first', () {
      // The tone ramp is ordered pastel -> ... -> ink. At 1.0 the caller is
      // asking for the far end of the ramp, so it must agree with its
      // neighbour just below rather than wrapping around to pastel.
      final justBelow = buildPalette(200, tone: 0.999);
      final atOne = buildPalette(200, tone: 1);
      // The default tone happens to be 0.0, but this test is about what tone
      // 0.0 *means*, so it says so.
      // ignore: avoid_redundant_argument_values
      final atZero = buildPalette(200, tone: 0);

      expect(atOne.head, justBelow.head,
          reason: 'tone 1.0 must be continuous with 0.999',);
      expect(atOne.head, isNot(atZero.head),
          reason: 'tone 1.0 wrapped around to the pastel swatch',);
    });

    test('the ramp is a step function with no wrap-around', () {
      // Walking 0 -> 1 must visit each swatch once and never return to one it
      // already left.
      final seen = <int>[];
      for (var i = 0; i <= 1000; i++) {
        final head = buildPalette(200, tone: i / 1000).head.toARGB32();
        if (seen.isEmpty || seen.last != head) {
          expect(seen, isNot(contains(head)),
              reason:
                  'swatch reappeared after being left, at tone ${i / 1000}',);
          seen.add(head);
        }
      }
      expect(seen.length, 6, reason: 'expected the six authored tone swatches');
    });

    test('out-of-range tone is clamped, not wrapped', () {
      expect(
        buildPalette(200, tone: 2).head,
        buildPalette(200, tone: 1).head,
      );
      expect(
        buildPalette(200, tone: -1).head,
        // Same as above: the explicit 0.0 is the assertion, not noise.
        // ignore: avoid_redundant_argument_values
        buildPalette(200, tone: 0).head,
      );
    });
  });

  group('seeded tone stays in range', () {
    test('stream never reaches 1.0, so no seed can hit the boundary', () {
      var max = 0.0;
      for (var i = 0; i < 20000; i++) {
        final v = stream(seedState('seed$i'), 'tone');
        expect(v, greaterThanOrEqualTo(0.0));
        expect(v, lessThan(1.0));
        if (v > max) max = v;
      }
      expect(max, greaterThan(0.999),
          reason: 'sample never approached the top',);
    });
  });
}
