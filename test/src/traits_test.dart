import 'package:blobatar_flutter/src/traits.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('trait overrides', () {
    // Overrides are positions in [0, 1), the same units the hash produces, so
    // there is nothing a seed can express that an override cannot and nothing
    // an override can express that a seed could not have.
    test('are clamped rather than trusted', () {
      // Exactly 1 would index one past the end of a `pick` list and one past
      // `max` in `intRange` — undefined options and out-of-range counts, from
      // an input that looks entirely reasonable to whoever typed it.
      expect(Traits('a', overrides: {'k': 1.0})('k'), lessThan(1.0));
      expect(Traits('a', overrides: {'k': 5.0})('k'), lessThan(1.0));
      expect(Traits('a', overrides: {'k': 0.0})('k'), 0.0);
      expect(Traits('a', overrides: {'k': -3.0})('k'), 0.0);
    });

    test('a clamped override still selects the last option', () {
      const options = ['a', 'b', 'c'];
      expect(Traits('x', overrides: {'k': 1.0}).pick('k', options), 'c');
      expect(Traits('x', overrides: {'k': 0.0}).pick('k', options), 'a');
    });

    test('pass through untouched inside the range', () {
      expect(Traits('a', overrides: {'k': 0.25})('k'), 0.25);
    });

    test('leave every other key alone', () {
      final plain = Traits('alain');
      final pinned = Traits('alain', overrides: {'shape': 0.5});
      expect(pinned('shape'), 0.5);
      for (final key in ['hue', 'tone', 'body.r', 'eye.gap']) {
        expect(pinned(key), plain(key), reason: '$key moved');
      }
    });
  });

  group('readers', () {
    test('pick spreads across the whole list', () {
      const options = [0, 1, 2, 3];
      final counts = <int, int>{};
      for (var i = 0; i < 4000; i++) {
        final v = Traits('seed$i').pick('k', options);
        counts[v] = (counts[v] ?? 0) + 1;
      }
      expect(counts.keys.toSet(), options.toSet());
      for (final c in counts.values) {
        expect(c, greaterThan(700), reason: 'lopsided: $counts');
      }
    });

    test('pick never indexes past the end', () {
      for (var i = 0; i < 5000; i++) {
        expect(Traits('s$i').pick('k', const ['only']), 'only');
      }
    });

    test('intRange is inclusive at both ends', () {
      final seen = <int>{};
      for (var i = 0; i < 4000; i++) {
        seen.add(Traits('seed$i').intRange('k', 2, 5));
      }
      expect(seen, {2, 3, 4, 5});
    });

    test('jitter is symmetric about zero', () {
      var sum = 0.0;
      var min = 0.0;
      var max = 0.0;
      for (var i = 0; i < 6000; i++) {
        final v = Traits('seed$i').jitter('k', 2);
        sum += v;
        if (v < min) min = v;
        if (v > max) max = v;
      }
      expect(min, greaterThanOrEqualTo(-2));
      expect(max, lessThan(2));
      expect(sum / 6000, closeTo(0, 0.06));
    });

    test('boolean honours its probability', () {
      var hits = 0;
      for (var i = 0; i < 6000; i++) {
        if (Traits('seed$i').boolean('k', 0.25)) hits++;
      }
      expect(hits / 6000, closeTo(0.25, 0.03));
    });
  });
}
