import 'dart:async';

import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';

import '../models/detox_alarm.dart';
import '../services/alarm_repository.dart';
import '../services/analytics_service.dart';
import '../services/detox_session_service.dart';
import '../widgets/sketchy_box.dart';
import 'detox_lock_screen.dart';

/// Shown while an alarm is ringing. The only action is Stop -- there's no
/// snooze, since a deferred detox window adds complexity the product didn't
/// ask for. Stopping starts the detox session and replaces this screen with
/// the lock screen in one step.
class RingScreen extends StatefulWidget {
  const RingScreen({super.key, required this.alarmSettings});

  final AlarmSettings alarmSettings;

  @override
  State<RingScreen> createState() => _RingScreenState();
}

class _RingScreenState extends State<RingScreen> {
  static const _repository = AlarmRepository();
  static const _sessionService = DetoxSessionService();
  static const _analytics = AnalyticsService();
  bool _stopping = false;

  @override
  void initState() {
    super.initState();
    unawaited(_analytics.screenView('ring'));
  }

  Future<void> _stop() async {
    if (_stopping) return;
    setState(() => _stopping = true);
    final payload = DetoxPayload.fromAlarmSettings(widget.alarmSettings);
    unawaited(_analytics.alarmStopped());
    unawaited(
      _analytics.detoxStarted(
        source: 'alarm',
        minutes: payload.detoxMinutes,
      ),
    );
    await _repository.consumeAfterRing(widget.alarmSettings.id);
    await _sessionService.start(
      alarmId: widget.alarmSettings.id,
      minutes: payload.detoxMinutes,
    );
    if (!mounted) return;
    final endAt = DateTime.now().add(Duration(minutes: payload.detoxMinutes));
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => DetoxLockScreen(endAt: endAt)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('wake up', style: Theme.of(context).textTheme.displayMedium),
              const SizedBox(height: 8),
              Text(
                TimeOfDay.now().format(context),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 48),
              GestureDetector(
                onTap: _stopping ? null : _stop,
                child: SketchyBox(
                  seed: 9,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 20,
                  ),
                  child: Text(
                    _stopping ? '...' : "I'm up",
                    style: Theme.of(context).textTheme.titleLarge,
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
