import 'dart:math';

import 'package:flutter/material.dart';

/// The alarm on/off control: a hand-drawn circle, filled solid when on and
/// just an outline when off -- a checkbox-style toggle rather than an iOS
/// switch, to match the app's sketchy visual language.
class ToggleDot extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _DotPainter(filled: value, color: color, seed: seed),
          ),
        ),
      ),
    );
  }
}

class _DotPainter extends CustomPainter {
  _DotPainter({required this.filled, required this.color, required this.seed});

  final bool filled;
  final Color color;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _wobblyCircle(size, Random(seed));
    if (filled) {
      canvas.drawPath(path, Paint()..color = color);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round,
    );
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
    return oldDelegate.filled != filled ||
        oldDelegate.color != color ||
        oldDelegate.seed != seed;
  }
}
