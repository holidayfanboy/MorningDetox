import 'dart:async';

import 'package:flutter/material.dart';

import '../services/accessibility_bridge.dart';
import '../services/analytics_service.dart';
import '../widgets/sketchy_box.dart';

/// Android-only explainer for turning on the accessibility service that
/// pulls the user back to the Detox lock screen if they leave the app
/// mid-session. This can only guide the user to the system Settings screen
/// -- Android doesn't allow granting it programmatically.
class AccessibilityPermissionScreen extends StatelessWidget {
  const AccessibilityPermissionScreen({super.key});

  static const _bridge = AccessibilityBridge();
  static const _analytics = AnalyticsService();

  @override
  Widget build(BuildContext context) {
    unawaited(_analytics.screenView('accessibility_permission'));
    return Scaffold(
      appBar: AppBar(title: const Text('Real Blocking')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Without this, Morning Detox can only ask you nicely to '
                'stay off your phone -- you can always leave the app.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Text(
                "Turning on Accessibility access lets Morning Detox bring "
                'you back to the lock screen if you try to leave during a '
                'detox session. You can still end a session early with '
                'Emergency Unlock -- this just closes the easy way out.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: _bridge.openSettings,
                child: SketchyBox(
                  seed: 21,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Text(
                    'Open Accessibility Settings',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
