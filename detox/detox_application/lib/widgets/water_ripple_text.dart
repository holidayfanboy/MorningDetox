import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Wraps a widget (a line of text, the countdown) and makes it look like it
/// is floating on the surface of a pool as a reflection: the whole block
/// slowly rises, falls, drifts sideways and tips a degree or so, while a
/// faint ripple runs through it so the letters never sit perfectly still.
///
/// How it works: the real child is painted almost invisibly (opacity ~0.01)
/// inside a [RepaintBoundary], grabbed to a `ui.Image` a few times a second
/// with `toImageSync`, and that snapshot is redrawn every frame with the
/// buoyant motion applied. Purely visual; the child still lays out at its
/// natural size and its own timers/animations keep running.
class WaterRippleText extends StatefulWidget {
  const WaterRippleText({
    super.key,
    required this.child,
    this.floatAmplitude = 4.0,
    this.rippleAmplitude = 1.5,
    this.tiltDegrees = 1.2,
    this.speed = 1.0,
  });

  final Widget child;

  /// How far, in logical pixels, the whole block drifts up/down and
  /// side-to-side as it bobs. Scale with the text size.
  final double floatAmplitude;

  /// Peak sideways shift of the faint surface ripple running through the
  /// letters (0 disables the ripple, leaving a pure float).
  final double rippleAmplitude;

  /// Gentle peak tip of the block, in degrees.
  final double tiltDegrees;

  /// Multiplies how fast everything moves.
  final double speed;

  @override
  State<WaterRippleText> createState() => _WaterRippleTextState();
}

class _WaterRippleTextState extends State<WaterRippleText>
    with SingleTickerProviderStateMixin {
  final GlobalKey _sourceKey = GlobalKey();

  /// Frame driver; the phase is read off [_clock] so it stays smooth.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat();

  final Stopwatch _clock = Stopwatch()..start();

  ui.Image? _snapshot;
  double _lastCapture = -1.0;
  bool _capturePending = false;

  /// How often to re-grab the child. The countdown digits only change once a
  /// second, so ~10/s keeps them current without the snapshot ever looking
  /// stretched against a just-resized child.
  static const _captureInterval = 0.1;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onFrame);
    _scheduleCapture();
  }

  void _onFrame() {
    final now = _clock.elapsedMilliseconds / 1000.0;
    if (!_capturePending && now - _lastCapture >= _captureInterval) {
      _scheduleCapture();
    }
  }

  void _scheduleCapture() {
    _capturePending = true;
    _lastCapture = _clock.elapsedMilliseconds / 1000.0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _capturePending = false;
      if (!mounted) return;
      final object = _sourceKey.currentContext?.findRenderObject();
      if (object is! RenderRepaintBoundary || object.size.isEmpty) return;
      try {
        final ratio = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 2.0;
        final image = object.toImageSync(pixelRatio: ratio);
        if (!mounted) {
          image.dispose();
          return;
        }
        setState(() {
          _snapshot?.dispose();
          _snapshot = image;
        });
      } catch (_) {
        // Boundary wasn't ready this frame -- the next tick tries again.
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _clock.stop();
    _snapshot?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // The real child, laid out at full size but painted almost invisibly
        // -- it's only here to be snapshotted (and to size the Stack).
        Opacity(
          opacity: snapshot == null ? 1.0 : 0.01,
          child: RepaintBoundary(key: _sourceKey, child: widget.child),
        ),
        if (snapshot != null)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => CustomPaint(
                painter: _FloatingReflectionPainter(
                  image: snapshot,
                  phase: _clock.elapsedMilliseconds / 1000.0 * widget.speed,
                  floatAmplitude: widget.floatAmplitude,
                  rippleAmplitude: widget.rippleAmplitude,
                  tilt: widget.tiltDegrees * pi / 180.0,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FloatingReflectionPainter extends CustomPainter {
  _FloatingReflectionPainter({
    required this.image,
    required this.phase,
    required this.floatAmplitude,
    required this.rippleAmplitude,
    required this.tilt,
  });

  final ui.Image image;
  final double phase;
  final double floatAmplitude;
  final double rippleAmplitude;
  final double tilt;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final iw = image.width.toDouble();
    final ih = image.height.toDouble();

    // Slow buoyant motion of the whole block: a vertical bob, a slower
    // sideways drift, and a gentle tip -- each on its own long period and
    // offset so they never line up into an obvious loop.
    final bob = sin(phase * 0.9) * floatAmplitude;
    final sway =
        sin(phase * 0.55 + 1.3) * floatAmplitude * 0.75 +
        sin(phase * 0.23 + 0.4) * floatAmplitude * 0.35;
    final tip = sin(phase * 0.47 + 0.7) * tilt;

    canvas.save();
    canvas.translate(size.width / 2 + sway, size.height / 2 + bob);
    canvas.rotate(tip);
    canvas.translate(-size.width / 2, -size.height / 2);

    // A faint ripple through the letters so the surface reads as water, not
    // a rigid card sliding around. Small and slow.
    const bandHeight = 2.0;
    final count = (size.height / bandHeight).ceil();
    final paint = Paint()
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.medium;

    for (var i = 0; i < count; i++) {
      final y = i * bandHeight;
      final h = min(bandHeight, size.height - y);
      if (h <= 0) break;

      final v = y / size.height; // 0 at the top, 1 at the bottom
      final dx = rippleAmplitude *
          (0.35 + 0.65 * v) *
          sin(phase * 1.3 + v * 7.0);

      final srcTop = v * ih;
      final srcHeight = (h / size.height) * ih;

      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, srcTop, iw, srcHeight),
        Rect.fromLTWH(dx, y, size.width, h),
        paint,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FloatingReflectionPainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.image != image ||
        oldDelegate.floatAmplitude != floatAmplitude ||
        oldDelegate.rippleAmplitude != rippleAmplitude ||
        oldDelegate.tilt != tilt;
  }
}
