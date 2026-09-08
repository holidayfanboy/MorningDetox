import 'dart:async';

import 'package:flutter/material.dart';

import '../utils/duration_format.dart';

/// A [Text] that ticks once a second toward [target], calling [onReached]
/// once when the target is hit (e.g. to auto-advance a screen).
class CountdownText extends StatefulWidget {
  const CountdownText({
    super.key,
    required this.target,
    this.style,
    this.onReached,
  });

  final DateTime target;
  final TextStyle? style;
  final VoidCallback? onReached;

  @override
  State<CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<CountdownText> {
  Timer? _timer;
  bool _reachedFired = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    final remaining = widget.target.difference(DateTime.now());
    if (remaining <= Duration.zero && !_reachedFired) {
      _reachedFired = true;
      widget.onReached?.call();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.target.difference(DateTime.now());
    return Text(formatCountdown(remaining), style: widget.style);
  }
}
