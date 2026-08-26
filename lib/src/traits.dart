/// A faithful port of blobatar's `src/traits.ts`.
///
/// Every value is addressed by a string key rather than drawn from a
/// sequential stream, so trait keys are an append-only namespace: adding a
/// new keyed read anywhere in the layout leaves every other trait —
/// therefore every existing blobatar — untouched.
library;

import 'package:blobatar_flutter/src/hash.dart';

/// Fixed values for individual traits, keyed exactly as the layout reads
/// them — `{'eye.gap': 0.82}`.
///
/// Every value is the position in [0, 1) that the hash would otherwise have
/// produced. There is nothing a seed can express that an override cannot,
/// and nothing an override can express that a seed could not have.
typedef TraitOverrides = Map<String, double>;

/// A trait reader bound to one hashed seed.
///
/// Call it like a function — `t('shape')` — for the raw [0, 1) stream value,
/// or use [num], [intRange], [pick], [boolean] and [jitter] to read it into
/// friendlier units. (Named `intRange`/`boolean` rather than `int`/`bool`
/// because those are reserved type names in Dart.)
class Traits {
  /// Binds a trait reader to [seed].
  ///
  /// [normalize] trims, lowercases and composes combining marks, so that
  /// `Roberto` and ` roberto ` are one name, as are the precomposed and
  /// decomposed spellings of `robérto`. It does *not* strip accents —
  /// `robérto` and `roberto` stay two different people, deliberately. Pass
  /// false only to read a seed exactly as given. [overrides] pins individual
  /// traits, bypassing the hash for those keys alone.
  Traits(String seed, {bool normalize = true, TraitOverrides? overrides})
      : _state = seedState(seed, normalize: normalize),
        _overrides = overrides;

  final int _state;
  final TraitOverrides? _overrides;

  /// Uniform float in [0, 1) for [key], independent of every other key.
  ///
  /// Overrides are clamped rather than trusted, mirroring upstream: a value
  /// of exactly 1 would select one past the end of a [pick] list, so it is
  /// pulled back to just under 1.
  double call(String key) {
    final o = _overrides?[key];
    if (o == null) return stream(_state, key);
    if (o <= 0) return 0;
    if (o < 1) return o;
    return 0.999999;
  }

  /// Uniform float in [min, max).
  double num(String key, double min, double max) =>
      min + call(key) * (max - min);

  /// Uniform integer in [min, max].
  int intRange(String key, int min, int max) =>
      min + (call(key) * (max - min + 1)).floor();

  /// Uniform choice. Appending to [options] remaps existing seeds — freeze
  /// the list contents the same way upstream freezes a `pick` array.
  T pick<T>(String key, List<T> options) =>
      options[(call(key) * options.length).floor()];

  /// True with probability [p].
  bool boolean(String key, [double p = 0.5]) => call(key) < p;

  /// Symmetric jitter in [-amount, amount).
  double jitter(String key, double amount) => (call(key) * 2 - 1) * amount;
}
