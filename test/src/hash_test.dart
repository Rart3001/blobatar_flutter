import 'package:blobatar_flutter/src/hash.dart';
import 'package:flutter_test/flutter_test.dart';

// Every accented character below is written as an explicit \uXXXX escape,
// precomposed and decomposed alike -- never as a literal source glyph. The
// two forms render identically once composed, so a literal glyph in this
// file would make it impossible to tell, just by reading it, which form a
// test actually exercises, or to notice a copy-paste that quietly collapsed
// a decomposed pair back into its precomposed counterpart.
void main() {
  group('normalizeSeed', () {
    test('trims and lowercases', () {
      expect(normalizeSeed('  Roberto  '), 'roberto');
    });

    test('a precomposed and a decomposed accent normalize identically', () {
      // Precomposed: 'e' with an acute accent as one code point (U+00E9).
      // Decomposed: 'e' + a combining acute accent (U+0301) -- two code
      // points that render the same way. Without NFC-lite these are
      // different strings, and therefore different people.
      const precomposed = 'caf\u00e9';
      const decomposed = 'cafe\u0301';
      expect(
        precomposed,
        isNot(decomposed),
        reason: 'test is vacuous otherwise',
      );
      expect(normalizeSeed(precomposed), normalizeSeed(decomposed));
      expect(normalizeSeed(decomposed), precomposed);
    });

    test('composition runs before lowercasing, not after', () {
      // If lowercasing ran first, the uppercase combining pair ('E' +
      // U+0301) would never match the (lowercase-keyed) composition table
      // entry, and this decomposed input would stay two code points apart
      // instead of composing to U+00C9 before being lowercased to U+00E9.
      const decomposedUppercase = 'E\u0301cole';
      expect(normalizeSeed(decomposedUppercase), '\u00e9cole');
    });

    test('covers tilde, cedilla and ring above, not just acute', () {
      // Each assertion feeds the table's decomposed key and checks the
      // precomposed target it must produce (see _composeAccents in
      // hash.dart).
      expect(normalizeSeed('n\u0303o'), '\u00f1o');
      expect(normalizeSeed('c\u0327a'), '\u00e7a');
      expect(normalizeSeed('a\u030angstrom'), '\u00e5ngstrom');
    });

    test('a combining mark outside the table is left untouched', () {
      // The table only covers the common Latin letters (see hash.dart); it
      // is not a general NFC implementation, so an uncovered base+combiner
      // pair -- 'x' has no accented forms in the table -- must pass through
      // as two separate code points rather than being silently dropped.
      const uncomposed = 'x\u0301';
      expect(normalizeSeed(uncomposed), uncomposed);
    });

    test('non-BMP characters survive untouched', () {
      // A surrogate pair must not be mistaken for a base+combiner pair by
      // the two-code-unit lookahead in _nfcLite.
      const unicorn = '\u{1f984}';
      const cafe = 'caf\u00e9';
      expect(normalizeSeed(unicorn), unicorn);
      expect(normalizeSeed('$unicorn $cafe'), '$unicorn $cafe');
    });
  });

  group('seedState', () {
    test('is deterministic', () {
      expect(seedState('roberto'), seedState('roberto'));
    });

    test('normalizes by default, so case is not significant', () {
      expect(seedState('Roberto'), seedState('roberto'));
    });

    test('normalize: false hashes the raw seed, case included', () {
      expect(
        seedState('Roberto', normalize: false),
        isNot(seedState('roberto', normalize: false)),
      );
    });
  });

  group('stream', () {
    test('is deterministic for a given state and key', () {
      final state = seedState('roberto');
      expect(stream(state, 'shape'), stream(state, 'shape'));
    });

    test('different keys derive independent values from the same state', () {
      // The whole point of streaming (see hash.dart's doc comment) is that
      // trait keys do not disturb one another. This is not proof of
      // independence, but a same-state, different-key collision here would
      // be a real regression, not noise.
      final state = seedState('roberto');
      expect(stream(state, 'shape'), isNot(stream(state, 'palette')));
    });

    test('avalanches: neighbouring seeds diverge sharply', () {
      // README's example: "roberto" and "roberta" must be visually
      // unrelated, not a near-miss. This checks the property the murmur3
      // finalizer exists to provide, without depending on upstream's exact
      // numbers the way test/parity_test.dart does.
      final a = stream(seedState('roberto'), 'shape');
      final b = stream(seedState('roberta'), 'shape');
      expect((a - b).abs(), greaterThan(0.1));
    });

    test('stays within [0, 1) across many seeds', () {
      for (var i = 0; i < 2000; i++) {
        final v = stream(seedState('seed$i'), 'shape');
        expect(v, greaterThanOrEqualTo(0.0));
        expect(v, lessThan(1.0));
      }
    });
  });
}
