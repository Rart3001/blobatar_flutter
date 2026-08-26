/// A faithful port of blobatar's `src/color.ts`.
///
/// Hue is the only value the seed controls; lightness and chroma come from
/// six authored tone swatches, which is what makes every blobatar look like
/// it came from the same designer rather than from a random number
/// generator. Colors are resolved through OKLCh so the contrast guarantee is
/// enforced against real sRGB luminance rather than assumed from OKLab
/// lightness (which drifts by up to ~1.4:1 between hues at equal L).
library;

import 'dart:math' as math;
import 'dart:ui';

import 'package:blobatar_flutter/src/traits.dart' show Traits;
import 'package:flutter/foundation.dart';

double _cbrt(double x) =>
    x < 0 ? -math.pow(-x, 1 / 3).toDouble() : math.pow(x, 1 / 3).toDouble();

/// A colour in Oklch — the space every blend here happens in, because mixing
/// in it keeps lightness and chroma perceptually even instead of dipping grey
/// through the middle the way sRGB does.
class Oklch {
  /// Creates a colour from its lightness, chroma and hue.
  const Oklch(this.l, this.c, this.h);

  /// Perceptual lightness, 0 (black) to 1 (white).
  final double l;

  /// Chroma — distance from grey. Unbounded in principle, small in practice.
  final double c;

  /// Hue, in degrees.
  final double h;

  /// This colour with the given channels replaced.
  Oklch copyWith({double? l, double? c, double? h}) =>
      Oklch(l ?? this.l, c ?? this.c, h ?? this.h);
}

List<double> _toLinear(Oklch o) {
  final r = o.h * math.pi / 180;
  final a = o.c * math.cos(r);
  final b = o.c * math.sin(r);

  final l_ = o.l + 0.3963377774 * a + 0.2158037573 * b;
  final m_ = o.l - 0.1055613458 * a - 0.0638541728 * b;
  final s_ = o.l - 0.0894841775 * a - 1.291485548 * b;

  final ll = l_ * l_ * l_;
  final mm = m_ * m_ * m_;
  final ss = s_ * s_ * s_;

  return [
    4.0767416621 * ll - 3.3077115913 * mm + 0.2309699292 * ss,
    -1.2684380046 * ll + 2.6097574011 * mm - 0.3413193965 * ss,
    -0.0041960863 * ll - 0.7034186147 * mm + 1.707614701 * ss,
  ];
}

bool _inGamut(List<double> rgb) =>
    rgb.every((v) => v >= -1e-4 && v <= 1 + 1e-4);

/// Resolves to in-gamut linear sRGB, reducing chroma if needed. Chroma is
/// the right axis to give up: lowering it desaturates, while clipping
/// channels shifts hue.
List<double> _resolve(Oklch color) {
  var rgb = _toLinear(color);
  if (!_inGamut(rgb)) {
    var lo = 0.0;
    var hi = color.c;
    for (var i = 0; i < 12; i++) {
      final mid = (lo + hi) / 2;
      if (_inGamut(_toLinear(color.copyWith(c: mid)))) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    rgb = _toLinear(color.copyWith(c: lo));
  }
  return rgb.map((v) => v.clamp(0.0, 1.0)).toList();
}

double _luminance(Oklch color) {
  final rgb = _resolve(color);
  return 0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2];
}

/// WCAG contrast ratio between two OKLCh colors.
double contrastRatio(Oklch a, Oklch b) {
  final x = _luminance(a);
  final y = _luminance(b);
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

/// Pushes [fg]'s lightness away from [bg] until the pair clears [min].
/// Walks in the direction it is already leaning first, so a dark ink on a
/// light body gets darker rather than flipping to light.
Oklch ensureContrast(Oklch fg, Oklch bg, double min) {
  if (contrastRatio(fg, bg) >= min) return fg;

  final lean = fg.l >= bg.l ? 1 : -1;
  for (final dir in [lean, -lean]) {
    var probe = fg;
    for (var i = 0; i < 60; i++) {
      final newL = (probe.l + dir * 0.02).clamp(0.0, 1.0);
      probe = probe.copyWith(l: newL);
      if (contrastRatio(probe, bg) >= min) return probe;
      if (probe.l == 0 || probe.l == 1) break;
    }
  }
  final black = fg.copyWith(l: 0, c: 0);
  final white = fg.copyWith(l: 1, c: 0);
  return contrastRatio(black, bg) >= contrastRatio(white, bg) ? black : white;
}

/// OKLCh -> sRGB [Color].
Color toColor(Oklch color) {
  final rgb = _resolve(color);
  int channel(double v) {
    final s = v <= 0.0031308 ? 12.92 * v : 1.055 * math.pow(v, 1 / 2.4) - 0.055;
    return (s * 255).round().clamp(0, 255);
  }

  return Color.fromARGB(255, channel(rgb[0]), channel(rgb[1]), channel(rgb[2]));
}

/// sRGB [Color] -> OKLCh. The inverse of [toColor], used to re-derive a
/// starting point for expression tints from a palette that may include a
/// caller-supplied override.
Oklch fromColor(Color color) {
  double toLinearChannel(double c01) {
    final s = c01;
    return s <= 0.04045
        ? s / 12.92
        : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
  }

  final r = toLinearChannel(color.r);
  final g = toLinearChannel(color.g);
  final b = toLinearChannel(color.b);

  final l = _cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
  final m = _cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
  final s = _cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);

  final a = 1.9779984951 * l - 2.428592205 * m + 0.4505937099 * s;
  final bb = 0.0259040371 * l + 0.7827717662 * m - 0.808675766 * s;

  return Oklch(
    0.2104542553 * l + 0.793617785 * m - 0.0040720468 * s,
    math.sqrt(a * a + bb * bb),
    math.atan2(bb, a) * 180 / math.pi,
  );
}

/// Blend two colors in OKLab — `color-mix(in oklab, …)`, done here. Lerping
/// cartesian a/b rather than polar c/h, since a hue lerp would swing a
/// desaturated color around the wheel and pick up chroma neither endpoint
/// has.
Oklch mixOklch(Oklch a, Oklch b, double t) {
  double rad(double v) => v * math.pi / 180;
  final ax = a.c * math.cos(rad(a.h));
  final ay = a.c * math.sin(rad(a.h));
  final bx = b.c * math.cos(rad(b.h));
  final by = b.c * math.sin(rad(b.h));
  final x = ax + (bx - ax) * t;
  final y = ay + (by - ay) * t;
  return Oklch(a.l + (b.l - a.l) * t, math.sqrt(x * x + y * y),
      math.atan2(y, x) * 180 / math.pi,);
}

/// Blends two sRGB colours [t] of the way from [a] to [b], travelling through
/// Oklch rather than straight across sRGB.
Color mixColor(Color a, Color b, double t) =>
    toColor(mixOklch(fromColor(a), fromColor(b), t));

/// Where a tinting expression heads. See [hotTint] etc. below.
@immutable
class Tint {
  /// Creates a tint. See the named tints below for the ones in use.
  const Tint({
    required this.h,
    required this.l,
    required this.pull,
    required this.c,
  });

  /// Hue the body arrives at, in degrees. Reached outright, not approached.
  final double h;

  /// Lightness it heads toward.
  final double l;

  /// How far of the way to [l] the body actually travels, 0–1.
  final double pull;

  /// Chroma floor. The body never desaturates on the way.
  final double c;

  @override
  bool operator ==(Object other) =>
      other is Tint &&
      h == other.h &&
      l == other.l &&
      pull == other.pull &&
      c == other.c;

  @override
  int get hashCode => Object.hash(h, l, pull, c);
}

/// Red, and only 60% of the way there in lightness, so the tone set
/// survives the trip. Used by the `mad` expression.
const hotTint = Tint(h: 27, l: 0.58, pull: 0.6, c: 0.18);

/// Used by the `love` expression.
const roseTint = Tint(h: 358, l: 0.72, pull: 0.55, c: 0.16);

/// Used by the `shy` expression. Travels only 0.4 of the way and lands pale.
const blushTint = Tint(h: 12, l: 0.84, pull: 0.4, c: 0.1);

/// Used by the `sick` expression.
const bileTint = Tint(h: 142, l: 0.66, pull: 0.6, c: 0.13);

const _darkSurface = Oklch(0.145, 0, 0); // ≈ #0a0a0b
const _surfaceFloor = 1.5;

/// A hair over the 4.5:1 the walk asserts, to absorb 8-bit quantization.
const _tintFloor = 4.55;

/// The palette a tinting expression heads toward, given the one it is
/// tinting from. Derived per-seed rather than a single authored color,
/// because the eye flips between near-black and near-white with the body's
/// lightness and no fixed red clears 4.5:1 against both. Walks the whole
/// mix, not merely the endpoints, since a straight OKLab line between two
/// passing pairs is not itself a passing pair everywhere along it.
(Color, Color) tintedPair(Color head, Color eye, Tint t) {
  final base = fromColor(head);
  final baseEye = fromColor(eye);

  var hotHead =
      Oklch(base.l + (t.l - base.l) * t.pull, math.max(base.c, t.c), t.h);
  hotHead = ensureContrast(hotHead, _darkSurface, _surfaceFloor);

  var hotEye = ensureContrast(baseEye, hotHead, _tintFloor);

  final dir = hotEye.l >= hotHead.l ? 1 : -1;
  final headColor = toColor(hotHead);

  for (var pass = 0; pass < 40; pass++) {
    final eyeColor = toColor(hotEye);
    var worst = double.infinity;
    for (var i = 0; i <= 10; i++) {
      final tt = i / 10;
      final mixedEye = fromColor(mixColor(eye, eyeColor, tt));
      final mixedHead = fromColor(mixColor(head, headColor, tt));
      worst = math.min(worst, contrastRatio(mixedEye, mixedHead));
    }
    if (worst >= _tintFloor) return (headColor, eyeColor);
    final newL = (hotEye.l + dir * 0.02).clamp(0.0, 1.0);
    if (newL == hotEye.l) return (headColor, eyeColor);
    hotEye = hotEye.copyWith(l: newL);
  }
  return (headColor, toColor(hotEye));
}

class _Tone {
  const _Tone(this.l, this.c);
  final double l;
  final double c;
}

/// Thresholds are cumulative, so pale and mid tones dominate and the
/// near-black body stays a rare find.
const _tones = <({double upTo, _Tone tone})>[
  (upTo: 0.2, tone: _Tone(0.86, 0.085)), // pastel
  (upTo: 0.36, tone: _Tone(0.9, 0.028)), // pale neutral
  (upTo: 0.62, tone: _Tone(0.73, 0.135)), // mid
  (upTo: 0.8, tone: _Tone(0.62, 0.165)), // deep
  (upTo: 0.93, tone: _Tone(0.87, 0.16)), // bright
  (upTo: 1.0, tone: _Tone(0.34, 0.035)), // ink
];

/// The thresholds are exclusive upper bounds, so the last one (1.0) is never
/// matched by `v < entry.upTo`. Falling through therefore means [v] is at or
/// past the top of the ramp and belongs to the *last* swatch — returning the
/// first one would wrap `tone: 1.0` around to pastel, the opposite end.
///
/// No seed can reach here: `stream` returns [0, 1), and [Traits.call] clamps
/// overrides to just under 1. Only an explicit `Blobatar(tone: …)` at or
/// above 1.0 lands on this branch, so changing it leaves every existing
/// blobatar untouched.
_Tone _toneAt(double v) {
  for (final entry in _tones) {
    if (v < entry.upTo) return entry.tone;
  }
  return _tones.last.tone;
}

/// A resolved blobatar palette: background, body and eye colors.
class BlobatarPalette {
  /// Creates a palette. Normally produced by `buildPalette` from a seed
  /// rather than written out.
  const BlobatarPalette({
    required this.bg,
    required this.head,
    required this.eye,
  });

  /// Behind the creature, painted only when a backdrop is asked for.
  final Color bg;

  /// The body and everything unioned with it.
  final Color head;

  /// The eyes.
  final Color eye;

  /// This palette with the given colours replaced — how
  /// `BlobatarPaletteOverride` applies without touching the seeded ramp.
  BlobatarPalette copyWith({Color? bg, Color? head, Color? eye}) =>
      BlobatarPalette(
        bg: bg ?? this.bg,
        head: head ?? this.head,
        eye: eye ?? this.eye,
      );
}

/// Builds the palette for a hue/tone pair. [tone] is a raw 0–1 position in
/// the swatch set (the same units [Traits] reads it in), not degrees.
BlobatarPalette buildPalette(double hue,
    {bool enforceContrast = true, double tone = 0,}) {
  final t = _toneAt(tone);
  var head = ensureContrast(Oklch(t.l, t.c, hue), _darkSurface, _surfaceFloor);
  // Polarity follows the body: dark eyes on a light body, light eyes on a
  // dark one, so the ink tone never renders an invisible face.
  var eye =
      head.l >= 0.5 ? const Oklch(0.17, 0.02, 0) : const Oklch(0.97, 0.012, 0);
  eye = eye.copyWith(h: hue);
  final bg = Oklch(0.965, 0.01, hue);

  if (enforceContrast) {
    head = ensureContrast(head, bg, 1.25);
    eye = ensureContrast(eye, head, 4.5);
  }

  return BlobatarPalette(
      bg: toColor(bg), head: toColor(head), eye: toColor(eye),);
}
