import 'dart:async';

import 'package:flutter/material.dart';

import '../services/analytics_service.dart';
import '../services/detox_session_service.dart';
import '../widgets/countdown_text.dart';
import '../widgets/ripple_background.dart';
import '../widgets/sketchy_box.dart';
import '../widgets/water_ripple_text.dart';
import 'alarm_list_screen.dart';

/// Full-screen "stay off your phone" timer, shown right after an alarm is
/// stopped (and again on cold start if the app was killed mid-session).
///
/// In-app back navigation is blocked -- that part is real on both
/// platforms. Leaving the app entirely (Home button, app switcher) cannot
/// be blocked here; on Android a separate accessibility service pulls the
/// user back to this screen, on iOS there is no such mechanism and this is
/// an honor-system timer. Either way, the only sanctioned way to end the
/// session early is the Emergency Unlock button below.
class DetoxLockScreen extends StatefulWidget {
  const DetoxLockScreen({super.key, required this.endAt});

  final DateTime endAt;

  @override
  State<DetoxLockScreen> createState() => _DetoxLockScreenState();
}

class _DetoxLockScreenState extends State<DetoxLockScreen> {
  static const _sessionService = DetoxSessionService();
  static const _analytics = AnalyticsService();

  @override
  void initState() {
    super.initState();
    unawaited(_analytics.screenView('detox_lock'));
  }

  Future<void> _finish({required String reason}) async {
    final startedAt = await _sessionService.startedAt();
    final now = DateTime.now();
    unawaited(
      _analytics.detoxEnded(
        reason: reason,
        plannedMinutes: startedAt == null
            ? 0
            : widget.endAt.difference(startedAt).inMinutes,
        actualMinutes: startedAt == null
            ? 0
            : now.difference(startedAt).inMinutes,
      ),
    );
    await _sessionService.end();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AlarmListScreen()),
      (route) => false,
    );
  }

  Future<void> _confirmEmergencyUnlock() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('UNLOCK'),
        content: const Text(
          "This ends your detox session early. You'll be able to use your "
          'phone right away.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Stay off my phone'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Unlock'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _finish(reason: 'emergency_unlock');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Stack(
          children: [
            const Positioned.fill(
              child: IgnorePointer(child: RippleBackground(seed: 13)),
            ),
            SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    WaterRippleText(
                      floatAmplitude: 2.5,
                      rippleAmplitude: 1.0,
                      tiltDegrees: 0.8,
                      child: SizedBox(
                        width: MediaQuery.sizeOf(context).width * 0.78,
                        child: Text(
                          '“Great things are not done by impulse, but by a '
                          'series of small things brought together.”\n'
                          '- Vincent Van Gogh',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: scheme.onSurface.withValues(alpha: 0.6),
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    WaterRippleText(
                      floatAmplitude: 5.0,
                      rippleAmplitude: 1.8,
                      tiltDegrees: 1.2,
                      child: CountdownText(
                        target: widget.endAt,
                        style: Theme.of(context).textTheme.displayMedium,
                        onReached: () => _finish(reason: 'completed'),
                      ),
                    ),
                    const SizedBox(height: 56),
                    GestureDetector(
                      onTap: _confirmEmergencyUnlock,
                      child: WaterRippleText(
                        floatAmplitude: 3.0,
                        rippleAmplitude: 1.2,
                        tiltDegrees: 0.9,
                        child: SketchyBox(
                          seed: 13,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                          child: Text(
                            'Emergency Unlock',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: scheme.error),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
