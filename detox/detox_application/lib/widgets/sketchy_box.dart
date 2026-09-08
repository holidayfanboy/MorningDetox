import 'dart:math';

import 'package:flutter/material.dart';

/// Draws a rounded-rect-ish border made of slightly wobbly bezier segments,
/// stroked twice with different jitter -- the classic "rough.js" hand-drawn
/// look, without pulling in a whole sketch-rendering package for a 5-screen
/// app. Colors always come from the current [ThemeData], never a literal.
class SketchyBox extends StatelessWidget {
  const SketchyBox({
    super.key,
    required this.child,
    this.seed = 0,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 18,
    this.strokeWidth = 2.2,
  });

  final Widget child;
  final int seed;
  final EdgeInsets padding;
  final double borderRadius;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    return CustomPaint(
      painter: _SketchyPainter(
        seed: seed,
        color: color,
        borderRadius: borderRadius,
        strokeWidth: strokeWidth,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// [SketchyBox] plus tap handling and centered text -- the button used
/// throughout the app instead of a plain [ElevatedButton].
class SketchyButton extends StatelessWidget {
  const SketchyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.seed = 0,
    this.filled = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final int seed;

  /// When true, fills with the primary color and inverts the text color --
  /// used for the single primary action on a screen.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: SketchyBox(
          seed: seed,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: filled ? scheme.onSurface.withValues(alpha: 0.04) : null,
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
      ),
    );
  }
}

class _SketchyPainter extends CustomPainter {
  _SketchyPainter({
    required this.seed,
    required this.color,
    required this.borderRadius,
    required this.strokeWidth,
  });

  final int seed;
  final Color color;
  final double borderRadius;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Two slightly different-jittered passes over the same base rect gives
    // the double-stroke "hand redrew this line" effect. The seed is fixed
    // per-widget (not time-based) so the wobble doesn't jitter on rebuild.
    canvas.drawPath(_wobblyRoundedRect(size, Random(seed)), paint);
    canvas.drawPath(_wobblyRoundedRect(size, Random(seed + 1000)), paint);
  }

  Path _wobblyRoundedRect(Size size, Random rng) {
    double j() => (rng.nextDouble() - 0.5) * 3.0;

    final r = borderRadius;
    final w = size.width;
    final h = size.height;
    final path = Path();

    path.moveTo(r + j(), j());
    path.quadraticBezierTo(w / 2 + j(), j(), w - r + j(), j());
    path.quadraticBezierTo(w + j(), j(), w + j(), r + j());
    path.quadraticBezierTo(w + j(), h / 2 + j(), w + j(), h - r + j());
    path.quadraticBezierTo(w + j(), h + j(), w - r + j(), h + j());
    path.quadraticBezierTo(w / 2 + j(), h + j(), r + j(), h + j());
    path.quadraticBezierTo(j(), h + j(), j(), h - r + j());
    path.quadraticBezierTo(j(), h / 2 + j(), j(), r + j());
    path.quadraticBezierTo(j(), j(), r + j(), j());
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _SketchyPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.seed != seed ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
