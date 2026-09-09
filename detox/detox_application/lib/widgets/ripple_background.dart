import 'dart:math';

import 'package:flutter/material.dart';

/// An ambient, full-bleed background for the lock screen: the whole screen
/// is treated as a still pool, and hand-drawn ripples keep spreading across
/// it -- a droplet lands somewhere, rings wobble outward and fade.
///
/// Purely decorative. Wrap it in an [IgnorePointer] so it never eats taps.
/// Rings are stroked twice with different jitter (the same "hand redrew this
/// line" trick as [SketchyBox]) and coloured from the current theme, so it
/// reads as faint dark rings on white and faint grey rings on black.
class RippleBackground extends StatefulWidget {
  const RippleBackground({super.key, this.seed = 0});

  /// Seeds where ripples appear and how they wobble -- fixed so the motion
  /// is the same each run rather than jittering on rebuild.
  final int seed;

  @override
  State<RippleBackground> createState() => _RippleBackgroundState();
}

class _RippleBackgroundState extends State<RippleBackground>
    with SingleTickerProviderStateMixin {
  /// Frame driver only -- repeats forever; the real clock is [_clock]. Same
  /// AnimationController + AnimatedBuilder idiom used elsewhere in the app.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat();

  final Stopwatch _clock = Stopwatch()..start();
  late final Random _rng = Random(widget.seed);
  final List<_Ripple> _ripples = [];

  /// Wall-clock seconds at which the next droplet should land.
  double _nextSpawn = 0.0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_advance);
    // A few ripples already mid-spread when the screen opens, so it never
    // looks like a dead pool waiting for the first drop.
    for (var i = 0; i < 3; i++) {
      _spawn(now: -_rng.nextDouble() * 4.0);
    }
  }

  void _advance() {
    final now = _clock.elapsedMilliseconds / 1000.0;
    if (now >= _nextSpawn) {
      _spawn(now: now);
      _nextSpawn = now + 0.8 + _rng.nextDouble() * 1.8;
    }
    _ripples.removeWhere((r) => now - r.birth > r.life);
  }

  void _spawn({required double now}) {
    if (_ripples.length > 7) return;
    _ripples.add(
      _Ripple(
        centerFrac: Offset(_rng.nextDouble(), _rng.nextDouble()),
        birth: now,
        life: 4.0 + _rng.nextDouble() * 3.0,
        maxRadiusFrac: 0.35 + _rng.nextDouble() * 0.55,
        rings: 2 + _rng.nextInt(2),
        seed: _rng.nextInt(1 << 30),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _clock.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        size: Size.infinite,
        painter: _RipplePainter(
          ripples: List.of(_ripples),
          now: _clock.elapsedMilliseconds / 1000.0,
          color: color,
        ),
      ),
    );
  }
}

/// One droplet's worth of spreading rings.
class _Ripple {
  _Ripple({
    required this.centerFrac,
    required this.birth,
    required this.life,
    required this.maxRadiusFrac,
    required this.rings,
    required this.seed,
  });

  /// Impact point as a fraction (0..1) of the paint area.
  final Offset centerFrac;
  final double birth;
  final double life;

  /// Outermost ring's final radius, as a fraction of the shorter screen side.
  final double maxRadiusFrac;
  final int rings;
  final int seed;
}

class _RipplePainter extends CustomPainter {
  _RipplePainter({
    required this.ripples,
    required this.now,
    required this.color,
  });

  final List<_Ripple> ripples;
  final double now;
  final Color color;

  /// Ceiling on ring opacity -- kept low so the lock screen stays calm.
  static const _peakAlpha = 0.16;

  @override
  void paint(Canvas canvas, Size size) {
    final shortSide = min(size.width, size.height);

    for (final r in ripples) {
      final age = (now - r.birth) / r.life;
      if (age < 0.0 || age >= 1.0) continue;

      final center = Offset(
        r.centerFrac.dx * size.width,
        r.centerFrac.dy * size.height,
      );
      final maxRadius = r.maxRadiusFrac * shortSide;

      // Rings ease outward and the whole ripple fades as it ages: quick swell
      // in, long fade out.
      final grow = Curves.easeOut.transform(age);
      final fade = age < 0.15
          ? age / 0.15
          : Curves.easeIn.transform(1.0 - (age - 0.15) / 0.85);
      final leadRadius = maxRadius * grow;

      // The impact dab, only for the first instant.
      if (age < 0.16) {
        final k = 1.0 - age / 0.16;
        canvas.drawCircle(
          center,
          shortSide * 0.012 * k,
          Paint()..color = color.withValues(alpha: _peakAlpha * k),
        );
      }

      for (var ring = 0; ring < r.rings; ring++) {
        // Inner rings trail the leading edge by a fixed gap.
        final radius = leadRadius - ring * shortSide * 0.05;
        if (radius < 2.0) continue;

        final ringAlpha = _peakAlpha * fade * (1.0 - ring * 0.28);
        if (ringAlpha <= 0.01) continue;

        final paint = Paint()
          ..color = color.withValues(alpha: ringAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = ring == 0 ? 2.0 : 1.4
          ..strokeCap = StrokeCap.round;

        // Two passes, different jitter -- the hand-drawn double stroke.
        canvas.drawPath(
          _wobblyRing(center, radius, Random(r.seed + ring * 97)),
          paint,
        );
        canvas.drawPath(
          _wobblyRing(center, radius, Random(r.seed + ring * 97 + 1000)),
          paint,
        );
      }
    }
  }

  /// A closed ring of [_segments] short lines with a per-vertex radial wobble.
  /// A fresh `Random(seed)` each frame reproduces the same wobble shape while
  /// the radius grows, so a ring keeps its character as it spreads.
  Path _wobblyRing(Offset center, double radius, Random rng) {
    const segments = 40;
    final wobble = radius * 0.035 + 1.2;
    final path = Path();

    for (var i = 0; i <= segments; i++) {
      final angle = 2 * pi * (i % segments) / segments;
      final rr = radius + wobble * (rng.nextDouble() - 0.5);
      final point = Offset(
        center.dx + rr * cos(angle),
        center.dy + rr * sin(angle),
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _RipplePainter oldDelegate) {
    return oldDelegate.now != now ||
        oldDelegate.color != color ||
        !identical(oldDelegate.ripples, ripples);
  }
}
