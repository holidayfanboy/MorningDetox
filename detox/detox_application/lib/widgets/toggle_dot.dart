import 'dart:math';

import 'package:flutter/material.dart';

/// The alarm on/off control: a hand-drawn circle, filled solid when on and
/// just an outline when off -- a checkbox-style toggle rather than an iOS
/// switch, to match the app's sketchy visual language.
///
/// Turning it *on* plays a short "ink drop" animation: a droplet falls onto
/// the top of the circle and the fill spreads out from that point. Turning
/// it *off* is instant -- the fill just disappears.
class ToggleDot extends StatefulWidget {
  const ToggleDot({
    super.key,
    required this.value,
    required this.onChanged,
    this.seed = 0,
    this.size = 30,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final int seed;
  final double size;

  @override
  State<ToggleDot> createState() => _ToggleDotState();
}

class _ToggleDotState extends State<ToggleDot>
    with SingleTickerProviderStateMixin {
  /// 0.0 = outline only, 1.0 = fully filled. Seeded from the prop so a dot
  /// that first builds already-on shows a full circle with no drop.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
    value: widget.value ? 1.0 : 0.0,
  );

  @override
  void didUpdateWidget(covariant ToggleDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value == oldWidget.value) return;
    if (widget.value) {
      _controller.forward(from: 0); // off -> on: play the ink drop
    } else {
      _controller.value = 0; // on -> off: instant, stops any in-flight fill
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Read outside the AnimatedBuilder so a theme-only recolour (dark mode)
    // still repaints even when this dot's value hasn't changed.
    final color = Theme.of(context).colorScheme.onSurface;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.onChanged(!widget.value),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => CustomPaint(
              painter: _DotPainter(
                progress: _controller.value,
                color: color,
                seed: widget.seed,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DotPainter extends CustomPainter {
  _DotPainter({
    required this.progress,
    required this.color,
    required this.seed,
  });

  /// Fill state / animation position: 0 = outline only, 1 = solid fill.
  final double progress;
  final Color color;
  final int seed;

  /// Fraction of [progress] spent on the falling droplet; the rest is the
  /// radial spread. ~120ms of the 450ms total.
  static const _dropEnd = 0.27;

  /// The landing-splat blob and the fading ring that ride the fill front --
  /// small hand-drawn liveliness. Flip to false to drop them entirely.
  static const _ripple = true;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(seed);
    // Build the path first: _wobblyCircle consumes `rng` in a fixed order,
    // and nothing below may pull from it before then, or the jitter shifts.
    final path = _wobblyCircle(size, rng);

    final baseRadius = min(size.width, size.height) / 2 - 2;
    final topAnchor = Offset(size.width / 2, size.height / 2 - baseRadius);

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    final fill = Paint()..color = color;

    // Settled states.
    if (progress <= 0.0) {
      canvas.drawPath(path, stroke);
      return;
    }
    if (progress >= 1.0) {
      canvas.drawPath(path, fill);
      canvas.drawPath(path, stroke);
      return;
    }

    // Drop phase: a droplet accelerates down onto the top of the circle.
    if (progress < _dropEnd) {
      final t = Curves.easeIn.transform(progress / _dropEnd);
      final startY = topAnchor.dy - baseRadius * 1.6;
      final y = startY + (topAnchor.dy - startY) * t;
      canvas.drawCircle(Offset(topAnchor.dx, y), baseRadius * 0.20, fill);
      canvas.drawPath(path, stroke);
      return;
    }

    // Spread phase: the fill grows radially from the contact point,
    // decelerating into "full", clipped so it can't bleed past the outline.
    final s = Curves.easeOut.transform(
      (progress - _dropEnd) / (1.0 - _dropEnd),
    );
    final reach = 2 * baseRadius * 1.10 * s;

    canvas.save();
    canvas.clipPath(path);
    canvas.drawCircle(topAnchor, reach, fill);

    if (_ripple) {
      // The impact blob shrinking away over the first quarter of the spread,
      // squashed vertically -- bridges the gap between the landed droplet and
      // a near-zero fill radius.
      if (s < 0.25) {
        final k = 1.0 - s / 0.25;
        canvas.save();
        canvas.translate(topAnchor.dx, topAnchor.dy);
        canvas.scale(1.0, 0.55);
        canvas.drawCircle(Offset.zero, baseRadius * 0.20 * k, fill);
        canvas.restore();
      }
      // A single faint ring riding the fill front.
      final ringAlpha = (1.0 - s) * 0.22;
      if (ringAlpha > 0.01) {
        canvas.drawCircle(
          topAnchor,
          reach,
          Paint()
            ..color = color.withValues(alpha: ringAlpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }
    canvas.restore();

    // Outline always last and unclipped, so it stays crisp throughout.
    canvas.drawPath(path, stroke);
  }

  Path _wobblyCircle(Size size, Random rng) {
    const pointCount = 14;
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = min(size.width, size.height) / 2 - 2;
    final path = Path();

    for (var i = 0; i <= pointCount; i++) {
      final angle = 2 * pi * (i % pointCount) / pointCount;
      final jitter = baseRadius * 0.06 * (rng.nextDouble() - 0.5);
      final radius = baseRadius + jitter;
      final point = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
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
  bool shouldRepaint(covariant _DotPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.seed != seed;
  }
}
