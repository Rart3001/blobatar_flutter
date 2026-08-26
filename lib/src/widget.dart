/// The public `Blobatar` widget — the Flutter equivalent of upstream's
/// `<Blobatar name="…" />` React component, and the counterpart of its
/// `react.tsx` rather than of its `index.ts`.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:blobatar_flutter/src/color.dart';
import 'package:blobatar_flutter/src/motion.dart';
import 'package:blobatar_flutter/src/painter.dart';
import 'package:blobatar_flutter/src/pose.dart';
import 'package:blobatar_flutter/src/styles/layout.dart';
import 'package:blobatar_flutter/src/traits.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// When idle motion runs.
enum BlobatarAnimate {
  /// Static. No ticker, no morph — expression changes apply instantly.
  none,

  /// Idle motion (breathe/bob/blink/glance) plays while hovered or
  /// pressed; expression changes morph smoothly.
  hover,

  /// Idle motion always plays. The hover reaction (a small lift) still
  /// applies on top — meant for a single large blobatar (a profile header),
  /// not a grid.
  always,
}

/// Explicit color overrides. Any field left null keeps the value the seed
/// (and [Blobatar.enforceContrast]) would have produced — this bypasses the
/// contrast guarantee for whichever channel you override, same as upstream.
class BlobatarPaletteOverride {
  /// Creates a set of overrides. Every channel left null stays seeded.
  const BlobatarPaletteOverride({this.background, this.head, this.eye});

  /// Replaces the backdrop colour.
  final Color? background;

  /// Replaces the body colour.
  final Color? head;

  /// Replaces the eye colour.
  final Color? eye;
}

/// A deterministic, generative "blob" avatar: the same [name] always
/// renders the same creature. Painted natively with a [CustomPainter] — no
/// SVG involved.
class Blobatar extends StatefulWidget {
  /// Creates a blobatar for [name].
  ///
  /// [name] is the only thing that decides what it looks like; everything
  /// else decides how it is presented.
  const Blobatar({
    required this.name, super.key,
    this.size,
    this.backdrop = BlobatarBackdrop.none,
    this.paletteOverride,
    this.hue,
    this.tone,
    this.traitOverrides,
    this.normalize = true,
    this.enforceContrast = true,
    this.semanticLabel,
    this.animate = BlobatarAnimate.none,
    this.expression = idleExpression,
  });

  /// Who the blobatar is for — a username, display name, email, id. Any
  /// string; the same string always renders the same blobatar.
  final String name;

  /// Side length in logical pixels. Omit to fill and stay square within
  /// whatever the parent gives it.
  final double? size;

  /// What to paint behind the creature.
  final BlobatarBackdrop backdrop;

  /// Explicit color overrides, applied after generation.
  final BlobatarPaletteOverride? paletteOverride;

  /// Hue override in degrees (0–360). Omit to derive it from [name].
  final double? hue;

  /// Tone-swatch position override, 0–1. Omit to derive it from [name].
  final double? tone;

  /// Pins specific trait values instead of deriving them from [name] — see
  /// [TraitOverrides].
  final TraitOverrides? traitOverrides;

  /// Best-effort Unicode NFC normalization before hashing (see
  /// `normalizeSeed`), so visually-equal names hash equally.
  final bool normalize;

  /// Nudges colors to keep WCAG contrast between body/eyes/background.
  final bool enforceContrast;

  /// Accessible label. Omitted entirely from the semantics tree
  /// (decorative) when null, matching upstream's `aria-hidden` default.
  final String? semanticLabel;

  /// When the idle motion layer runs. A platform reduced-motion setting
  /// ([MediaQueryData.disableAnimations]) overrides this: the creature holds
  /// its baked pose no matter what is asked for here.
  final BlobatarAnimate animate;

  /// The pose to wear. Requires [animate] to be set for the change to
  /// morph smoothly; with `animate: BlobatarAnimate.none` it applies
  /// instantly.
  final Expression expression;

  @override
  State<Blobatar> createState() => _BlobatarState();
}

// TickerProviderStateMixin, not the Single- variant: `animate` can change at
// runtime, and each change disposes the old Ticker and asks for a new one.
// SingleTickerProviderStateMixin asserts on the second request.
class _BlobatarState extends State<Blobatar> with TickerProviderStateMixin {
  static const _morphCurve = Cubic(0.45, 0.05, 0.5, 1);

  Ticker? _ticker;

  /// Elapsed time on our own clock. It advances only while a Ticker is
  /// running — pausing freezes it, so motion resumes mid-cycle rather than
  /// snapping back to the start of the breathe loop — but it is never
  /// rewound.
  ///
  /// A Ticker reports elapsed time from *its own* start, so a restart would
  /// otherwise reset time to zero underneath [_morphStart], which
  /// [didUpdateWidget] stamps from this clock before the restart happens.
  /// A widget that changes `animate` and `expression` in the same frame
  /// would then stall its morph for as long as it had previously run.
  Duration _elapsed = Duration.zero;
  Duration _lastTick = Duration.zero;

  /// What [_elapsed] had reached when the current Ticker started.
  Duration _clockBase = Duration.zero;

  bool _hovered = false;
  double _amp = 0;
  double _lift = 0;

  late Traits _traits;
  late BlobLayout _rawLayout;
  late BlobatarPalette _basePalette;

  /// Resolved once per (palette, tint) rather than every frame — see
  /// [tintTargetFor], which is ~28us and the single most expensive thing a
  /// frame does outside `paint`.
  TintTarget? _tintTarget;
  late MotionSeed _motionSeed;

  late Pose _fromPose;
  late Expression _toExpr;
  Duration _morphStart = Duration.zero;
  Duration _morphDuration = const Duration(milliseconds: 300);

  // The values actually painted; kept as state so `animate: none` can skip
  // the ticker entirely and still render correctly.
  Pose _pose = Pose.identity;
  Offset _breathe = const Offset(1, 1);
  double _bob = 0;
  double _blink = 1;
  Offset _gaze = Offset.zero;
  Offset _shake = Offset.zero;
  double? _rockPhase;

  /// Read here rather than in the Ticker callback: registering an inherited
  /// dependency belongs in the build/dependency phase, not in a callback that
  /// fires between frames.
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _fromPose = widget.expression.pose;
    _toExpr = widget.expression;
    _recomputeStatic();
    _pose = widget.expression.pose;
    _maybeStartTicker();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }

  @override
  void didUpdateWidget(covariant Blobatar old) {
    super.didUpdateWidget(old);

    final staticInputsChanged = old.name != widget.name ||
        old.normalize != widget.normalize ||
        old.enforceContrast != widget.enforceContrast ||
        old.hue != widget.hue ||
        old.tone != widget.tone ||
        !_mapEquals(old.traitOverrides, widget.traitOverrides) ||
        old.paletteOverride?.background != widget.paletteOverride?.background ||
        old.paletteOverride?.head != widget.paletteOverride?.head ||
        old.paletteOverride?.eye != widget.paletteOverride?.eye;
    if (staticInputsChanged) _recomputeStatic();

    if (old.expression != widget.expression) {
      if (widget.animate == BlobatarAnimate.none) {
        _pose = widget.expression.pose;
        _toExpr = widget.expression;
        _resolveTint();
      } else {
        _fromPose = _pose;
        _toExpr = widget.expression;
        _resolveTint();
        _morphStart = _elapsed;
        final entering = widget.expression != idleExpression;
        _morphDuration = Duration(milliseconds: entering ? 300 : 400);
      }
    }

    if (old.animate != widget.animate) _maybeStartTicker();
  }

  bool _mapEquals(Map<String, double>? a, Map<String, double>? b) {
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }

  void _recomputeStatic() {
    _traits = Traits(widget.name,
        normalize: widget.normalize, overrides: widget.traitOverrides,);
    _rawLayout = computeLayout(_traits);
    _motionSeed = computeMotionSeed(_traits);

    final hue = widget.hue ?? _traits.num('hue', 0, 360);
    final tone = widget.tone ?? _traits('tone');
    var palette =
        buildPalette(hue, enforceContrast: widget.enforceContrast, tone: tone);
    final override = widget.paletteOverride;
    if (override != null) {
      palette = palette.copyWith(
          bg: override.background, head: override.head, eye: override.eye,);
    }
    _basePalette = palette;
    _resolveTint();
  }

  void _resolveTint() {
    final tint = _toExpr.tint;
    _tintTarget = tint == null ? null : tintTargetFor(_basePalette, tint);
  }

  void _maybeStartTicker() {
    final shouldTick = widget.animate != BlobatarAnimate.none;
    if (shouldTick && _ticker == null) {
      // Resume our clock where the last Ticker left it, so a morph in flight
      // and the seeded motion phases both carry over instead of rewinding.
      _clockBase = _elapsed;
      _lastTick = _elapsed;
      final ticker = createTicker(_onTick);
      // A TickerFuture only completes when the ticker is stopped, which for a
      // looping idle animation is disposal — there is nothing to await.
      unawaited(ticker.start());
      _ticker = ticker;
    } else if (!shouldTick && _ticker != null) {
      _ticker!.dispose();
      _ticker = null;
      // Snap to rest so a mode switch never strands mid-motion.
      setState(() {
        _pose = widget.expression.pose;
        _breathe = const Offset(1, 1);
        _bob = 0;
        _blink = 1;
        _gaze = Offset.zero;
        _shake = Offset.zero;
        _rockPhase = null;
        _amp = 0;
        _lift = 0;
      });
    }
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    final now = _clockBase + elapsed;
    final dtMs = (now - _lastTick).inMicroseconds / 1000;
    _lastTick = now;
    _elapsed = now;

    final reduceMotion = _reduceMotion;

    // Hover-gated amplitude, eased with a fixed time-constant so it is
    // frame-rate independent.
    final ampTarget = widget.animate == BlobatarAnimate.always
        ? 1.0
        : (widget.animate == BlobatarAnimate.hover && _hovered ? 1.0 : 0.0);
    _amp = _approach(_amp, ampTarget, dtMs, 260);
    // The hover lift is decorative motion like everything else here, so it is
    // gated too: under reduced motion a hovered blobatar simply does not lift.
    final lift =
        _approach(_lift, (_hovered && !reduceMotion) ? 1.0 : 0.0, dtMs, 200);

    // Expression morph.
    final morphMs = (now - _morphStart).inMicroseconds / 1000;
    final rawT = _morphDuration.inMilliseconds == 0
        ? 1.0
        : (morphMs / _morphDuration.inMilliseconds).clamp(0.0, 1.0);
    final pose = _fromPose.lerp(
        _toExpr.pose, reduceMotion ? 1.0 : _morphCurve.transform(rawT),);

    var breathe = const Offset(1, 1);
    var bob = 0.0;
    var blink = 1.0;
    var gaze = Offset.zero;
    var shake = Offset.zero;
    double? rock;

    if (!reduceMotion) {
      final ms = now.inMicroseconds / 1000;
      breathe = breatheScale(ms, _motionSeed, _amp);
      bob = bobOffset(ms, _motionSeed, _amp);
      blink = eyeBlinkScaleY(ms, _motionSeed, _amp);
      gaze = saccadeOffset(ms, _motionSeed, _amp);
      // Shake is a pose-driven tremor, not hover-gated — it plays whenever
      // an expression with `shake > 0` (mad, sick, scared) is active and
      // `animate` is set at all, matching upstream.
      shake = shakeOffset(ms, pose.shake);
      // Not hover-gated either: a rocking pose rocks whenever it is worn.
      rock = pose.rock > 0 ? rockPhase(ms) : null;
    }

    // Only mark dirty when something the painter reads actually moved.
    //
    // Without this, an unhovered `BlobatarAnimate.hover` avatar rebuilt and
    // repainted on every single frame while rendering the identical picture:
    // the amplitude gate is 0, so every motion function returns its rest
    // value, but the Ticker fired and setState ran regardless. A grid of 48
    // of them — the arrangement this package recommends hover mode for — was
    // burning ~48 repaints a frame to show nothing changing. Reduced motion
    // sat in the same trap.
    //
    // `_lift` is compared too because `build` reads it directly; it is
    // assigned outside setState, so skipping the call has to account for it.
    final unchanged = pose == _pose &&
        breathe == _breathe &&
        bob == _bob &&
        blink == _blink &&
        gaze == _gaze &&
        shake == _shake &&
        rock == _rockPhase &&
        lift == _lift;
    if (unchanged) return;

    setState(() {
      _pose = pose;
      _breathe = breathe;
      _bob = bob;
      _blink = blink;
      _gaze = gaze;
      _shake = shake;
      _rockPhase = rock;
      _lift = lift;
    });
  }

  /// Eases [current] toward [target] with a fixed time constant, so the rate
  /// does not depend on how long the last frame took. `1 - e^(-dt/tau)` and
  /// not `dt/tau`: the linear form is only an approximation of this for small
  /// `dt`, and drifts once frames get long — exactly when a dropped frame
  /// makes the difference visible.
  double _approach(double current, double target, double dtMs, double tauMs) {
    if (dtMs <= 0) return current;
    final t = 1 - math.exp(-dtMs / tauMs);
    return current + (target - current) * t;
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baked = bakePose(_rawLayout, _pose, rockPhase: _rockPhase);
    var palette = _basePalette;
    final tint = _toExpr.tint;
    if (tint != null) {
      palette = tintPalette(palette, _pose.heat, tint, target: _tintTarget);
    }

    final liftScale = 1 + 0.04 * _lift;
    final liftDy = -1.5 * _lift;

    // One animating blobatar otherwise drags every sibling into its repaint:
    // measured at 48 of 48 painted per frame in a grid where one animates,
    // against 1 of 48 with this boundary. The layer it allocates is only
    // wasted when *every* avatar in a grid animates, which the README already
    // advises against.
    Widget painted = RepaintBoundary(
        child: CustomPaint(
      painter: BlobatarPainter(
        layout: baked.layout,
        palette: palette,
        backdrop: widget.backdrop,
        bodyOffset: Offset(0, baked.bdy),
        breatheScale: Offset(liftScale * _breathe.dx, liftScale * _breathe.dy),
        bobDy: liftDy + _bob,
        eyeBlinkScaleY: _blink,
        gazeOffset: _gaze,
        shakeOffset: _shake,
      ),
    ),);

    if (widget.size != null) {
      painted =
          SizedBox(width: widget.size, height: widget.size, child: painted);
    } else {
      painted = AspectRatio(aspectRatio: 1, child: painted);
    }

    if (widget.animate != BlobatarAnimate.none) {
      painted = MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: painted,
      );
    }

    final label = widget.semanticLabel;
    return Semantics(
      label: label,
      image: label != null,
      excludeSemantics: label == null,
      child: painted,
    );
  }
}
