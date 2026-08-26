# Changelog

## 0.1.0

First release. A native Flutter port of
[blobatar](https://github.com/Alain00/blobatar), tracking upstream **2.4.0**
(gen2, ten silhouettes).

- Deterministic generative blob avatars: the same `name` always renders the
  same blobatar. Painted directly with `CustomPainter` and `dart:ui.Path` —
  no SVG layer.
- Ten silhouettes: `round`, `organic`, `boxy`, `capsule`, `nub`, `cloud`,
  `droplet`, `hexagon`, `sun`, `triangle`.
- Fourteen expressions, morphing between one another on upstream's timing and
  easing. `thinking` rocks the eyes; `mad`, `love`, `shy` and `sick` tint the
  palette; `mad`, `scared` and `sick` tremble.
- Idle motion — breathing, bob, blink and gaze — with per-seed periods and
  phases, so a grid reads as a crowd rather than a heartbeat. Off, on hover,
  or always.
- Full OKLCh colour: gamut mapping, a WCAG contrast guarantee held across the
  whole tint mix, and the authored tone ramp.
- Overrides for hue, tone, individual traits and the resolved palette.
- Decorative by default in the semantics tree, with an opt-in
  `semanticLabel`. All motion stops under the platform's reduce-motion
  setting.

**Parity is verified, not asserted.** `tool/extract_upstream_vectors.ts` runs
the JavaScript library and writes the fixture; `test/parity_test.dart`
compares every number with exact equality. 714 assertions green against 2.4.0
over 349 seeds, at least 25 per silhouette, covering precomposed and
decomposed Latin, non-BMP emoji and untrimmed mixed case.

Two documented deviations, both in the README: Unicode normalization is
approximated for common Latin diacritics (Dart ships no NFC), and the
secondary eye "wrap" during a glance is not ported.
