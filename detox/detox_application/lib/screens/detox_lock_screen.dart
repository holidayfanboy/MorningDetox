import 'package:flutter/material.dart';

import '../services/detox_session_service.dart';
import '../widgets/countdown_text.dart';
import '../widgets/sketchy_box.dart';
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
class DetoxLockScreen extends StatelessWidget {
  const DetoxLockScreen({super.key, required this.endAt});

  final DateTime endAt;

  static const _sessionService = DetoxSessionService();

  Future<void> _finish(BuildContext context) async {
    await _sessionService.end();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AlarmListScreen()),
      (route) => false,
    );
  }

  Future<void> _confirmEmergencyUnlock(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Emergency unlock?'),
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
    if (confirmed == true && context.mounted) {
      await _finish(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'phone-free time',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 12),
                CountdownText(
                  target: endAt,
                  style: Theme.of(context).textTheme.displayMedium,
                  onReached: () => _finish(context),
                ),
                const SizedBox(height: 56),
                GestureDetector(
                  onTap: () => _confirmEmergencyUnlock(context),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
