import 'dart:async';

import 'package:alarm/alarm.dart';
import 'package:alarm/utils/alarm_set.dart';
import 'package:flutter/material.dart';

import 'screens/alarm_list_screen.dart';
import 'screens/detox_lock_screen.dart';
import 'screens/intro_screen.dart';
import 'screens/ring_screen.dart';
import 'services/detox_session_service.dart';
import 'services/first_launch_service.dart';
import 'services/permission_service.dart';
import 'theme/app_theme.dart';

/// Root navigator, used by [AppRoot] to push screens (the ringing alarm,
/// a re-shown lock screen) from outside whatever screen currently has
/// context, since those events can happen at any point in the app's life.
final rootNavigatorKey = GlobalKey<NavigatorState>();

class DetoxApp extends StatelessWidget {
  const DetoxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'Morning Detox',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AppRoot(),
    );
  }
}

/// Decides what the app should show at cold start (a resumed detox session
/// takes priority over the intro screen, which takes priority over the
/// normal alarm list), and reacts to two things for the whole app lifetime:
/// an alarm starting to ring, and the app resuming while a session is
/// still active (the common path is the Android accessibility service
/// re-fronting an already-showing lock screen, so this is mostly a
/// safety net for "the app process was killed mid-session").
class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> with WidgetsBindingObserver {
  static const _firstLaunchService = FirstLaunchService();
  static const _sessionService = DetoxSessionService();
  static const _permissionService = PermissionService();

  Widget? _home;
  StreamSubscription<AlarmSet>? _ringingSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_decideInitialScreen());
    unawaited(
      _permissionService.checkNotificationPermission().then(
        (_) => _permissionService.checkAndroidScheduleExactAlarmPermission(),
      ),
    );
    _ringingSubscription = Alarm.ringing.listen(_onRingingChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ringingSubscription?.cancel();
    super.dispose();
  }

  Future<void> _decideInitialScreen() async {
    final endAt = await _sessionService.activeEndAt();
    if (endAt != null) {
      if (!mounted) return;
      setState(() => _home = DetoxLockScreen(endAt: endAt));
      return;
    }
    final seenIntro = await _firstLaunchService.hasSeenIntro();
    if (!mounted) return;
    setState(() {
      _home = seenIntro
          ? const AlarmListScreen()
          : IntroScreen(onContinue: _finishIntro);
    });
  }

  Future<void> _finishIntro() async {
    await _firstLaunchService.markSeen();
    if (!mounted) return;
    setState(() => _home = const AlarmListScreen());
  }

  void _onRingingChanged(AlarmSet alarmSet) {
    if (alarmSet.alarms.isEmpty) return;
    rootNavigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => RingScreen(alarmSettings: alarmSet.alarms.first),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(_checkSessionOnResume());
  }

  Future<void> _checkSessionOnResume() async {
    final endAt = await _sessionService.activeEndAt();
    if (endAt == null) return;
    rootNavigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => DetoxLockScreen(endAt: endAt)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final home = _home;
    if (home == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    return home;
  }
}
