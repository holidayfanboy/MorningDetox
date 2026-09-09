import 'dart:async';

import 'package:flutter/material.dart';

import '../services/analytics_service.dart';

/// Shown only once, on the very first launch. Tapping anywhere moves on.
class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    unawaited(const AnalyticsService().screenView('intro'));
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onContinue,
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Morning\nDetox',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayMedium
                      ?.copyWith(height: 1.1),
                ),
                const SizedBox(height: 24),
                Text(
                  'wake up,\nthen put it down',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 48),
                Text(
                  'tap to begin',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
