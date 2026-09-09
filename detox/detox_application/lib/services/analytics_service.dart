import 'package:firebase_analytics/firebase_analytics.dart';

import 'settings_service.dart';

/// Thin wrapper over Firebase Analytics. Best-effort by design: every call
/// is fire-and-forget and swallows its own errors, the same way the
/// `MethodChannel` bridges in this folder do -- analytics must never be able
/// to break a user flow. Nothing else in `lib/` imports `firebase_analytics`
/// directly, so switching providers later is a one-file change.
///
/// Consumed like the other services: `static const _analytics =
/// AnalyticsService();` on a `State`, then `_analytics.somethingHappened()`.
/// [init] is the one static entry point, called once from `main()`.
class AnalyticsService {
  const AnalyticsService();

  /// Lazily resolved -- only touched after `Firebase.initializeApp()` has
  /// run in `main()`.
  static FirebaseAnalytics get _fa => FirebaseAnalytics.instance;

  /// Applies the user's consent choice and keeps it in sync with the
  /// Settings toggle. Ad / IDFA personalisation signals stay off so there's
  /// no iOS App Tracking Transparency prompt to deal with.
  static Future<void> init() async {
    await _fa.setAnalyticsCollectionEnabled(
      SettingsService.analyticsEnabled.value,
    );
    SettingsService.analyticsEnabled.addListener(() {
      _fa.setAnalyticsCollectionEnabled(SettingsService.analyticsEnabled.value);
    });
  }

  Future<void> _log(String name, [Map<String, Object>? params]) async {
    try {
      await _fa.logEvent(name: name, parameters: params);
    } catch (_) {
      // Swallowed on purpose -- see class doc.
    }
  }

  // ---- app lifecycle -------------------------------------------------------

  /// Cold start. [launchInto] is `alarm_list` / `intro` / `lock`.
  Future<void> appOpened(String launchInto) =>
      _log('app_opened', {'launch_into': launchInto});

  /// Returned to the foreground after being backgrounded.
  Future<void> appForegrounded() => _log('app_foregrounded');

  // ---- detox sessions ----------------------------------------------------

  /// [source] is `alarm` (stopped a ringing alarm) or `detox_now`.
  Future<void> detoxStarted({required String source, required int minutes}) =>
      _log('detox_started', {'source': source, 'minutes': minutes});

  /// [reason] is `completed` (ran to zero) or `emergency_unlock`.
  Future<void> detoxEnded({
    required String reason,
    required int plannedMinutes,
    required int actualMinutes,
  }) => _log('detox_ended', {
    'reason': reason,
    'planned_minutes': plannedMinutes,
    'actual_minutes': actualMinutes,
  });

  // ---- alarms ----------------------------------------------------------

  Future<void> alarmRang() => _log('alarm_rang');

  Future<void> alarmStopped() => _log('alarm_stopped');

  Future<void> alarmCreated({
    required int detoxMinutes,
    required bool repeating,
  }) => _log('alarm_created', {
    'detox_minutes': detoxMinutes,
    'repeating': repeating ? 'true' : 'false',
  });

  Future<void> alarmEdited() => _log('alarm_edited');

  Future<void> alarmDeleted() => _log('alarm_deleted');

  Future<void> alarmToggled(bool enabled) =>
      _log('alarm_toggled', {'enabled': enabled ? 'true' : 'false'});

  // ---- settings ------------------------------------------------------

  Future<void> settingChanged({
    required String setting,
    required String value,
  }) => _log('setting_changed', {'setting': setting, 'value': value});

  // ---- navigation --------------------------------------------------

  /// Manual screen_view -- the app's routes are anonymous
  /// `MaterialPageRoute`s with no names, so the automatic observer can't do
  /// this itself.
  Future<void> screenView(String name) async {
    try {
      await _fa.logScreenView(screenName: name);
    } catch (_) {
      // Swallowed on purpose.
    }
  }
}
