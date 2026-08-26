/// Seed hashing — a faithful port of blobatar's `src/hash.ts`.
///
/// Two guarantees this file exists to provide (same as upstream):
///
/// 1. Avalanche — "roberto" and "roberta" must produce visually unrelated
///    blobatars. Plain FNV-1a does not give you this; the murmur3 finalizer
///    does. (Those two land on different silhouettes, which is the version of
///    this claim the example app puts on screen.)
/// 2. Streaming — the seed is hashed once, then each trait key continues
///    from that state. Trait values are therefore independent of one
///    another, so adding a trait in a later version cannot disturb existing
///    blobatars.
///
/// Every value here is kept as an *unsigned* 32-bit integer (0..0xFFFFFFFF)
/// masked after each bitwise step. That is deliberate: it keeps the code
/// correct both on the Dart VM (64-bit ints) and compiled to JS/Wasm for
/// Flutter web, where integers above 2^53 lose precision. `_imul32` below
/// is the classic 16-bit-split `Math.imul` polyfill for exactly that reason.
library;

import 'dart:convert';

const int _sep = 0xff;

/// 32-bit-safe multiplication, bit-for-bit equivalent to JavaScript's
/// `Math.imul`. Splitting into 16-bit halves keeps every intermediate value
/// under 2^53, so this stays exact when compiled to JavaScript/Wasm.
int _imul32(int a, int b) {
  final au = a & 0xffffffff;
  final bu = b & 0xffffffff;
  final ah = (au >> 16) & 0xffff;
  final al = au & 0xffff;
  final bh = (bu >> 16) & 0xffff;
  final bl = bu & 0xffff;
  final mid = (ah * bl + al * bh) & 0xffff;
  return (al * bl + (mid << 16)) & 0xffffffff;
}

/// Mixes bytes into a 32-bit state.
int _feed(int seed, List<int> bytes) {
  var h = seed;
  for (final byte in bytes) {
    h = _imul32(h ^ byte, 3432918353);
    h = ((h << 13) | (h >> 19)) & 0xffffffff;
  }
  return h;
}

/// murmur3 fmix32 — a bijection on uint32 with full avalanche.
int _finalize(int seed) {
  var h = _imul32(seed ^ (seed >> 16), 2246822507);
  h = _imul32(h ^ (h >> 13), 3266489909);
  return (h ^ (h >> 16)) & 0xffffffff;
}

/// A small composition table for the common Latin combining diacritics
/// (grave, acute, circumflex, tilde, diaeresis, ring above, cedilla).
///
/// Dart's `String` has no built-in Unicode normalization. Upstream relies on
/// JavaScript's `"…".normalize("NFC")` so that a precomposed "é" (U+00E9) and
/// a decomposed "e" + combining acute (U+0065 U+0301) hash identically. This
/// table covers the accented letters you'll actually see in names, emails
/// and handles across the major European languages. It does **not** cover
/// full Unicode NFC (Vietnamese stacked diacritics, Hangul jamo composition,
/// etc.) — if your app needs that, swap this function for a call into a full
/// normalization package (e.g. `unorm_dart`) and everything downstream
/// keeps working unchanged, since only this function's output matters.
const Map<String, String> _composeAccents = {
  'a\u0300': 'à',
  'a\u0301': 'á',
  'a\u0302': 'â',
  'a\u0303': 'ã',
  'a\u0308': 'ä',
  'a\u030A': 'å',
  'e\u0300': 'è',
  'e\u0301': 'é',
  'e\u0302': 'ê',
  'e\u0308': 'ë',
  'i\u0300': 'ì',
  'i\u0301': 'í',
  'i\u0302': 'î',
  'i\u0308': 'ï',
  'o\u0300': 'ò',
  'o\u0301': 'ó',
  'o\u0302': 'ô',
  'o\u0303': 'õ',
  'o\u0308': 'ö',
  'u\u0300': 'ù',
  'u\u0301': 'ú',
  'u\u0302': 'û',
  'u\u0308': 'ü',
  'y\u0301': 'ý',
  'y\u0308': 'ÿ',
  'n\u0303': 'ñ',
  'c\u0327': 'ç',
  's\u0327': 'ş',
  'g\u0306': 'ğ',
  'A\u0300': 'À',
  'A\u0301': 'Á',
  'A\u0302': 'Â',
  'A\u0303': 'Ã',
  'A\u0308': 'Ä',
  'A\u030A': 'Å',
  'E\u0300': 'È',
  'E\u0301': 'É',
  'E\u0302': 'Ê',
  'E\u0308': 'Ë',
  'I\u0300': 'Ì',
  'I\u0301': 'Í',
  'I\u0302': 'Î',
  'I\u0308': 'Ï',
  'O\u0300': 'Ò',
  'O\u0301': 'Ó',
  'O\u0302': 'Ô',
  'O\u0303': 'Õ',
  'O\u0308': 'Ö',
  'U\u0300': 'Ù',
  'U\u0301': 'Ú',
  'U\u0302': 'Û',
  'U\u0308': 'Ü',
  'Y\u0301': 'Ý',
  'N\u0303': 'Ñ',
  'C\u0327': 'Ç',
};

/// Best-effort NFC composition (see [_composeAccents]).
String _nfcLite(String s) {
  final buffer = StringBuffer();
  var i = 0;
  while (i < s.length) {
    if (i + 1 < s.length) {
      final pair = s.substring(i, i + 2);
      final composed = _composeAccents[pair];
      if (composed != null) {
        buffer.write(composed);
        i += 2;
        continue;
      }
    }
    buffer.write(s[i]);
    i++;
  }
  return buffer.toString();
}

/// Normalizes a seed so that inputs a human considers equal hash equally.
///
/// NFC-lite first, so precomposed "é" and decomposed "é" agree for the
/// common Latin cases; then trim, then lowercase. Without this,
/// `Roberto@x.com` and `roberto@x.com` would produce different blobatars for
/// the same person.
String normalizeSeed(String seed) => _nfcLite(seed).trim().toLowerCase();

/// Hashes the seed once into a reusable state. Seeds are encoded to UTF-8
/// bytes first, matching upstream's `TextEncoder` step, so hashing is over
/// codepoints rather than UTF-16 units.
int seedState(String seed, {bool normalize = true}) {
  final s = normalize ? normalizeSeed(seed) : seed;
  final bytes = utf8.encode(s);
  return _feed((1779033703 ^ s.length) & 0xffffffff, bytes);
}

/// Derives one uniform float in [0, 1) for [key], independent of every
/// other key.
double stream(int state, String key) {
  final withSep = _feed(state, const [_sep]);
  final withKey = _feed(withSep, utf8.encode(key));
  return _finalize(withKey) / 4294967296.0;
}
