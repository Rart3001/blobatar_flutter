import 'dart:async';

import 'package:blobatar_flutter/blobatar_flutter.dart';
import 'package:flutter/material.dart';

void main() => runApp(const DemoApp());

/// The seeds the demo grid draws.
///
/// Chosen so the grid shows all ten silhouettes. The band table is weighted —
/// round and organic are the everyday shapes — so an arbitrary list of names
/// lands on five or six of them and the demo quietly under-sells what the
/// library draws. `test/grid_test.dart` keeps this honest.
///
/// Fifteen rather than a round sixteen: at five per row that is three full
/// rows instead of three and a straggler, and the seed it costs was a third
/// `round` in a list whose whole job is showing variety.
///
/// `roberto` and `roberta` are kept adjacent on purpose: one letter apart, and
/// they do not even share a silhouette — `organic` against `nub`. That is the
/// avalanche the hash exists to provide, and it is easier to believe from two
/// names than from a hash diagram.
const demoGridSeeds = [
  'roberto',
  'roberta',
  'ana',
  'bruno',
  'cleo',
  'dario',
  'elena',
  'finn',
  'hugo',
  'iris',
  'kira',
  'nico',
  'renata',
  'priya',
  'yui',
];

/// The demo's root: a dark MaterialApp wrapped around [DemoPage].
class DemoApp extends StatelessWidget {
  /// Creates the demo app.
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'blobatar demo',
      // The simulator only runs debug builds, so the ribbon would otherwise be
      // burned into every screenshot and every frame of the README's GIF.
      debugShowCheckedModeBanner: false,
      // Dark, and this particular dark on purpose. `buildPalette` guarantees
      // the body colour clears 1.5:1 against `#0a0a0b` — every blobatar is
      // built to be legible on that surface, and on a near-white page the
      // pale end of the tone ramp washes out instead. Demoing the library on
      // the background its own contrast guarantee targets is the honest test.
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A0B),
      ),
      home: const DemoPage(),
    );
  }
}

/// The whole demo: a seed field over a grid of blobatars that re-renders as
/// you type.
class DemoPage extends StatefulWidget {
  /// Creates the demo page.
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  static const _initialSeed = 'roberto@example.com';

  /// One beat per expression while the demo is introducing itself.
  ///
  /// The morph itself takes 300-400ms, so the rest of the beat is the pose
  /// standing still and being looked at. Much faster and the grid reads as a
  /// flicker of half-finished morphs rather than fourteen distinct faces.
  static const _cyclePeriod = Duration(milliseconds: 1300);

  String _seed = _initialSeed;

  /// Held by name rather than by [Expression] so the chips can compare keys.
  /// Two expressions could in principle carry the same pose and tint, and a
  /// selection that matched by value would then light up both chips.
  String _expressionName = expressions.keys.first;
  Timer? _cycle;

  @override
  void initState() {
    super.initState();
    // Left to itself, the demo walks the fourteen expressions: a still avatar
    // does not show that the pose system exists, and nobody taps every chip.
    // The first manual pick stops it for good — an app that keeps animating
    // over your choice is fighting you, not demoing.
    _cycle = Timer.periodic(_cyclePeriod, (_) {
      final names = expressions.keys.toList();
      final next = (names.indexOf(_expressionName) + 1) % names.length;
      setState(() => _expressionName = names[next]);
    });
  }

  void _pick(String name) {
    _cycle?.cancel();
    _cycle = null;
    setState(() => _expressionName = name);
  }

  // Owned by the State, not rebuilt in build(): a controller constructed
  // inside build() is replaced on every rebuild, so picking an expression
  // would wipe whatever was half-typed in the field.
  final TextEditingController _seedController =
      TextEditingController(text: _initialSeed);

  @override
  void dispose() {
    _cycle?.cancel();
    _seedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // No AppBar: the point of this screen is the drawing, and a title bar
      // eats the top fifth of a phone to repeat what the grid label already
      // says. Without one, nothing holds the content clear of the status bar
      // and the Dynamic Island — hence SafeArea.
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // The demo names itself once, on the first line, in the same small
            // type as the seed labels — a masthead rather than a title bar,
            // which is what buys the avatar grid the top of the screen.
            Text(
              'blobatar — Flutter port',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Center(
              child: Blobatar(
                name: _seed,
                size: 220,
                backdrop: BlobatarBackdrop.squircle,
                animate: BlobatarAnimate.always,
                expression: expressions[_expressionName]!,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration:
                  const InputDecoration(labelText: 'Seed (name or email)'),
              controller: _seedController,
              onSubmitted: (v) => setState(() => _seed = v),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              // The fourteen labels do not divide evenly into phone-width
              // rows, so one row is always short. Centred, that reads as the
              // shape of the block; left-aligned it reads as a ragged edge.
              alignment: WrapAlignment.center,
              children: expressions.entries.map((e) {
                return ChoiceChip(
                  label: Text(e.key),
                  selected: e.key == _expressionName,
                  // A checkmark widens the selected chip, which reflows the
                  // whole Wrap every time the selection moves. Standing still,
                  // that is a shrug; while the demo is cycling, the entire
                  // chip block jumps once a second.
                  showCheckmark: false,
                  onSelected: (_) => _pick(e.key),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: demoGridSeeds
                  .map(
                    (n) => Column(
                      children: [
                        Blobatar(
                          name: n,
                          size: 64,
                          backdrop: BlobatarBackdrop.circle,
                          animate: BlobatarAnimate.hover,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          n,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
