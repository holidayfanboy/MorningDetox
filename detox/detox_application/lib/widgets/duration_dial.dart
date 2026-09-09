import 'dart:math';

import 'package:flutter/material.dart';

/// A hand-drawn circular dial for picking a duration by dragging. The full
/// circle represents [maxMinutes]; the filled arc grows clockwise from 12
/// o'clock as the value goes up. Dragging anywhere on the dial is a relative
/// gesture -- the first touch never jumps the value, so the centre content
/// stays tappable -- and winding past 12 o'clock does not snap between empty
/// and full.
///
/// Controlled: it never holds the duration itself, it reports snapped,
/// clamped minutes through [onChanged] and redraws from [minutes].
class DurationDial extends StatefulWidget {
  const DurationDial({
    super.key,
    required this.minutes,
    required this.onChanged,
    required this.child,
    this.maxMinutes = 360,
    this.stepMinutes = 5,
    this.minMinutes = 5,
    this.size = 320,
    this.seed = 21,
  });

  /// Current value, in minutes.
  final int minutes;

  /// Fired with a value already snapped to [stepMinutes] and clamped to
  /// [minMinutes]..[maxMinutes]; only when it actually changes.
  final ValueChanged<int> onChanged;

  /// Content shown in the middle of the ring (the label + editable time).
  final Widget child;

  final int maxMinutes;
  final int stepMinutes;
  final int minMinutes;
  final double size;
  final int seed;

  @override
  State<DurationDial> createState() => _DurationDialState();
}

class _DurationDialState extends State<DurationDial>
    with SingleTickerProviderStateMixin {
  /// 0 = empty ring, 1 = full ring. Mirrors `minutes / maxMinutes`; seeded
  /// inline so the first frame is already at the right fill.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
    value: widget.minutes / widget.maxMinutes,
  );

  bool _dragging = false;

  /// Accumulated fraction across the current drag, and the last pointer
  /// angle (as a fraction of a turn) it was measured against.
  double _accum = 0;
  double _lastFrac = 0;

  @override
  void didUpdateWidget(covariant DurationDial oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.minutes == oldWidget.minutes) return;
    final target = widget.minutes / widget.maxMinutes;
    if (_dragging) {
      _controller.value = target; // follow the finger 1:1
    } else {
      _controller.animateTo(target, curve: Curves.easeOut);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Pointer angle as a fraction of a full turn, measured clockwise from 12
  /// o'clock, wrapped into [0, 1).
  double _fracFromLocal(Offset local) {
    final c = widget.size / 2;
    final raw = atan2(local.dy - c, local.dx - c) + pi / 2;
    final frac = raw / (2 * pi);
    return frac - frac.floor();
  }

  void _onPanStart(DragStartDetails details) {
    _dragging = true;
    _accum = (widget.minutes / widget.maxMinutes).clamp(0.0, 1.0);
    _lastFrac = _fracFromLocal(details.localPosition);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final frac = _fracFromLocal(details.localPosition);
    var d = frac - _lastFrac;
    if (d > 0.5) d -= 1;
    if (d < -0.5) d += 1;
    _lastFrac = frac;
    _accum = (_accum + d).clamp(0.0, 1.0);

    final raw = _accum * widget.maxMinutes;
    final snapped = (raw / widget.stepMinutes).round() * widget.stepMinutes;
    final clamped = snapped.clamp(widget.minMinutes, widget.maxMinutes);
    if (clamped != widget.minutes) widget.onChanged(clamped);
  }

  void _onPanEnd(DragEndDetails details) {
    _dragging = false;
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: SizedBox.square(
        dimension: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => CustomPaint(
                  painter: _DialPainter(
                    fraction: _controller.value,
                    color: color,
                    seed: widget.seed,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(48),
              child: widget.child,
            ),
          ],
        ),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter({
    required this.fraction,
    required this.color,
    required this.seed,
  });

  final double fraction;
  final Color color;
  final int seed;

  static const _trackSegments = 44;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 6;

    // Build every wobbly path before pulling any other value from its rng,
    // so the seeded jitter order stays deterministic.
    final trackA = _wobblyRing(center, radius, Random(seed));
    final trackB = _wobblyRing(center, radius, Random(seed + 1000));

    final track = Paint()
      ..color = color.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(trackA, track);
    canvas.drawPath(trackB, track);

    const start = -pi / 2;
    final sweep = fraction.clamp(0.0, 1.0) * 2 * pi;

    if (sweep > 0.001) {
      final segments = max(2, (fraction.clamp(0.0, 1.0) * _trackSegments).round());
      final arcA = _wobblyArc(center, radius, start, sweep, segments, Random(seed + 7));
      final arcB =
          _wobblyArc(center, radius, start, sweep, segments, Random(seed + 1007));
      final arc = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(arcA, arc);
      canvas.drawPath(arcB, arc);
    }

    // Knob at the arc's leading edge -- always drawn so there's a grab point
    // even at the minimum.
    final theta = start + sweep;
    final knobCenter = Offset(
      center.dx + radius * cos(theta),
      center.dy + radius * sin(theta),
    );
    final knob = _wobblyBlob(knobCenter, 9, Random(seed + 31));
    canvas.drawPath(knob, Paint()..color = color);
    canvas.drawPath(
      knob,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round,
    );
  }

  /// Closed 44-gon with a small radial wobble -- the hand-drawn ring.
  Path _wobblyRing(Offset center, double radius, Random rng) {
    final wobble = radius * 0.03 + 1.0;
    final path = Path();
    for (var i = 0; i <= _trackSegments; i++) {
      final angle = 2 * pi * (i % _trackSegments) / _trackSegments;
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

  /// Open polyline along an arc, same radial wobble as [_wobblyRing].
  Path _wobblyArc(
    Offset center,
    double radius,
    double startAngle,
    double sweep,
    int segments,
    Random rng,
  ) {
    final wobble = radius * 0.03 + 1.0;
    final path = Path();
    for (var i = 0; i <= segments; i++) {
      final angle = startAngle + sweep * (i / segments);
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
    return path;
  }

  /// Small closed blob for the drag knob.
  Path _wobblyBlob(Offset center, double radius, Random rng) {
    const points = 10;
    final path = Path();
    for (var i = 0; i <= points; i++) {
      final angle = 2 * pi * (i % points) / points;
      final rr = radius + radius * 0.18 * (rng.nextDouble() - 0.5);
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
  bool shouldRepaint(covariant _DialPainter oldDelegate) {
    return oldDelegate.fraction != fraction ||
        oldDelegate.color != color ||
        oldDelegate.seed != seed;
  }
}
