/// Deterministic, generative blob avatars — a native Flutter port of
/// [blobatar](https://github.com/Alain00/blobatar).
///
/// This file is the package's public surface and nothing else: every name a
/// consumer can reach is re-exported from here, and the implementation lives
/// under `src/`. Mirrors upstream's `index.ts`, which is a barrel for the
/// same reason — what the package promises should be readable in one screen,
/// without a widget's state machine in the way.
library;

export 'src/color.dart'
    show BlobatarPalette, Tint, bileTint, blushTint, hotTint, roseTint;
export 'src/hash.dart' show normalizeSeed;
export 'src/painter.dart' show BlobatarBackdrop;
export 'src/pose.dart'
    show
        Expression,
        Pose,
        expressions,
        happyExpression,
        idleExpression,
        loveExpression,
        madExpression,
        sadExpression,
        scaredExpression,
        shyExpression,
        sickExpression,
        sleepyExpression,
        smugExpression,
        surprisedExpression,
        thinkingExpression,
        unsureExpression,
        winkExpression;
export 'src/styles/layout.dart' show BlobLayout, BlobShape;
export 'src/traits.dart' show TraitOverrides;
export 'src/widget.dart'
    show Blobatar, BlobatarAnimate, BlobatarPaletteOverride;
