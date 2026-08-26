import 'package:blobatar_example/main.dart';
import 'package:blobatar_flutter/src/styles/layout.dart';
import 'package:blobatar_flutter/src/traits.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the demo grid shows every silhouette', () {
    // The band table is weighted, so an arbitrary list of names lands on five
    // or six shapes and the demo under-sells what the library draws. This is
    // the only place that would notice.
    final shown =
        demoGridSeeds.map((n) => computeLayout(Traits(n)).shape).toSet();
    final missing =
        BlobShape.values.where((s) => !shown.contains(s)).map((s) => s.name);
    expect(
      shown,
      BlobShape.values.toSet(),
      reason: 'missing: ${missing.toList()}',
    );
  });

  test('the avalanche pair leads the grid, and diverges', () {
    // The README and `demoGridSeeds`' own doc both claim these two are one
    // letter apart and do not even share a silhouette. Prose cannot check
    // itself, and a reshuffle of the list would quietly retire the claim.
    expect(demoGridSeeds.take(2), ['roberto', 'roberta']);

    final shapes =
        ['roberto', 'roberta'].map((n) => computeLayout(Traits(n)).shape);
    expect(
      shapes,
      [BlobShape.organic, BlobShape.nub],
      reason: 'the avalanche pair no longer draws what the docs say it draws',
    );
  });
}
