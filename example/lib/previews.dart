/// Widget previews for the whole visual vocabulary.
///
/// Run `flutter widget-preview start` from this directory, or open the Flutter
/// Widget Preview tab in the IDE. Every silhouette, every expression and every
/// backdrop renders side by side without launching the app, which is the
/// fastest way to see what a change to the painter did.
///
/// The silhouettes are pinned with `traitOverrides` rather than by hunting for
/// seeds that happen to land on them: a trait override is a position in [0, 1)
/// in the same units the hash produces, so `{'shape': 0.11}` sits in `round`'s
/// band and always will.
library;

import 'package:blobatar_flutter/blobatar_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

const _seed = 'roberto@example.com';

/// Public because @Preview only accepts literals and public symbols.
const previewSize = Size(220, 260);

/// The surface `buildPalette` guarantees the body colour clears 1.5:1
/// against. Previewing on anything lighter flatters the pale end of the tone
/// ramp and hides what the guarantee is actually for.
const previewSurface = Color(0xFF0A0A0B);

/// Midpoints of each band in `shapes.dart`, so a preview keeps naming the
/// silhouette it claims to even if a neighbouring edge moves.
const _shapeBands = <String, double>{
  'round': 0.11,
  'organic': 0.35,
  'boxy': 0.54,
  'capsule': 0.65,
  'nub': 0.745,
  'cloud': 0.825,
  'droplet': 0.888,
  'hexagon': 0.933,
  'sun': 0.965,
  'triangle': 0.99,
};

Widget _tile(String label, Widget child) => ColoredBox(
      color: previewSurface,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            child,
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(fontSize: 13, color: Colors.white70),
            ),
          ],
        ),
      ),
    );

Widget _shape(String name) => _tile(
      name,
      Blobatar(
        name: _seed,
        size: 160,
        backdrop: BlobatarBackdrop.squircle,
        traitOverrides: {'shape': _shapeBands[name]!},
      ),
    );

/// A plain superellipse — the everyday silhouette, and the widest band.
@Preview(name: 'round', group: 'Silhouettes', size: previewSize)
Widget silhouetteRound() => _shape('round');

/// A closed spline through seeded radii: never twice the same blob.
@Preview(name: 'organic', group: 'Silhouettes', size: previewSize)
Widget silhouetteOrganic() => _shape('organic');

/// `round`, squared off and tilted.
@Preview(name: 'boxy', group: 'Silhouettes', size: previewSize)
Widget silhouetteBoxy() => _shape('boxy');

/// A squat lozenge — a box with a circle capping each end.
@Preview(name: 'capsule', group: 'Silhouettes', size: previewSize)
Widget silhouetteCapsule() => _shape('capsule');

/// `round` with one or two bumps stuck to its rim.
@Preview(name: 'nub', group: 'Silhouettes', size: previewSize)
Widget silhouetteNub() => _shape('nub');

/// `organic` with lobes crowded along its upper half.
@Preview(name: 'cloud', group: 'Silhouettes', size: previewSize)
Widget silhouetteCloud() => _shape('cloud');

/// A body with a point tapering off the top, tear-style.
@Preview(name: 'droplet', group: 'Silhouettes', size: previewSize)
Widget silhouetteDroplet() => _shape('droplet');

/// A rounded six-sided polygon.
@Preview(name: 'hexagon', group: 'Silhouettes', size: previewSize)
Widget silhouetteHexagon() => _shape('hexagon');

/// `round` ringed by evenly spaced petals.
@Preview(name: 'sun', group: 'Silhouettes', size: previewSize)
Widget silhouetteSun() => _shape('sun');

/// `hexagon` with three sides, resting on its base.
@Preview(name: 'triangle', group: 'Silhouettes', size: previewSize)
Widget silhouetteTriangle() => _shape('triangle');

Widget _expression(String name) => _tile(
      name,
      Blobatar(
        name: _seed,
        size: 160,
        backdrop: BlobatarBackdrop.squircle,
        // `thinking` rocks and the tinting poses tremble, so the previews
        // animate — a still frame of `mad` is not what `mad` looks like.
        animate: BlobatarAnimate.always,
        expression: expressions[name]!,
      ),
    );

/// The resting face: the layout as the seed built it, nothing added.
@Preview(name: 'idle', group: 'Expressions', size: previewSize)
Widget expressionIdle() => _expression('idle');

/// Wide flat arcs riding high — the universal smiling squint.
@Preview(name: 'happy', group: 'Expressions', size: previewSize)
Widget expressionHappy() => _expression('happy');

/// Small eyes, low and drifted apart, over a body that sinks.
@Preview(name: 'sad', group: 'Expressions', size: previewSize)
Widget expressionSad() => _expression('sad');

/// A hard V of flat bars over a body that compresses and runs hot.
@Preview(name: 'mad', group: 'Expressions', size: previewSize)
Widget expressionMad() => _expression('mad');

/// Eyes enlarged rather than squashed — the antipode of `mad`.
@Preview(name: 'surprised', group: 'Expressions', size: previewSize)
Widget expressionSurprised() => _expression('surprised');

/// One eye a flat arc, the other open.
@Preview(name: 'wink', group: 'Expressions', size: previewSize)
Widget expressionWink() => _expression('wink');

/// Flat bars with no angle in them, sitting low over a sunk body.
@Preview(name: 'sleepy', group: 'Expressions', size: previewSize)
Widget expressionSleepy() => _expression('sleepy');

/// Half-lidded and leaning in parallel: a cocked head, not a brow.
@Preview(name: 'smug', group: 'Expressions', size: previewSize)
Widget expressionSmug() => _expression('smug');

/// One eye narrowed, the other open.
@Preview(name: 'unsure', group: 'Expressions', size: previewSize)
Widget expressionUnsure() => _expression('unsure');

/// Small eyes held high and pulled together, over a trembling body.
@Preview(name: 'scared', group: 'Expressions', size: previewSize)
Widget expressionScared() => _expression('scared');

/// Tall narrow eyes, drawn together, lifted, and rose.
@Preview(name: 'love', group: 'Expressions', size: previewSize)
Widget expressionLove() => _expression('love');

/// Small squeezed eyes, low and wide apart, over a blushing body.
@Preview(name: 'shy', group: 'Expressions', size: previewSize)
Widget expressionShy() => _expression('shy');

/// Worried flat bars over a body that sinks, greens and trembles.
@Preview(name: 'sick', group: 'Expressions', size: previewSize)
Widget expressionSick() => _expression('sick');

/// Eyes dropped low and staggered, rocking slowly — a look held somewhere
/// else rather than at you.
@Preview(name: 'thinking', group: 'Expressions', size: previewSize)
Widget expressionThinking() => _expression('thinking');

Widget _backdrop(String label, BlobatarBackdrop backdrop) =>
    _tile(label, Blobatar(name: _seed, size: 160, backdrop: backdrop));

/// No backdrop — the creature on whatever is behind it.
@Preview(name: 'none', group: 'Backdrops', size: previewSize)
Widget backdropNone() => _backdrop('none', BlobatarBackdrop.none);

/// The full square of the frame.
@Preview(name: 'square', group: 'Backdrops', size: previewSize)
Widget backdropSquare() => _backdrop('square', BlobatarBackdrop.square);

/// A circle inscribed in the frame.
@Preview(name: 'circle', group: 'Backdrops', size: previewSize)
Widget backdropCircle() => _backdrop('circle', BlobatarBackdrop.circle);

/// The rounded square between the two.
@Preview(name: 'squircle', group: 'Backdrops', size: previewSize)
Widget backdropSquircle() => _backdrop('squircle', BlobatarBackdrop.squircle);

/// The avalanche, side by side: one letter apart, nothing in common.
@Preview(name: 'roberto vs roberta', group: 'Determinism', size: Size(320, 200))
Widget avalanche() => ColoredBox(
      color: previewSurface,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final seed in ['roberto', 'roberta'])
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Blobatar(
                      name: seed,
                      size: 110,
                      backdrop: BlobatarBackdrop.circle,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      seed,
                      style:
                          const TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
