import 'package:shared_preferences/shared_preferences.dart';

/// Tracks the active "don't use your phone" session.
///
/// These keys are the entire Dart<->native contract for the Android
/// accessibility service (see DetoxAccessibilityService.kt): it reads this
/// same shared_preferences file directly, without going through a
/// MethodChannel, so a session can be detected even before the Flutter
/// engine is running again.
///
/// IMPORTANT for anyone touching the native side: the `shared_preferences`
/// plugin stores these under the file `FlutterSharedPreferences` with every
/// key prefixed `flutter.` (e.g. `flutter.detox_active`), and stores Dart
/// `int` values via `putLong`, not `putInt` -- the Kotlin service must read
/// them with `getLong`/`getBoolean` under the prefixed key names or it will
/// silently see "no active session".
class DetoxSessionService {
  const DetoxSessionService();

  static const keyActive = 'detox_active';
  static const keyEndAtMillis = 'detox_end_at_millis';
  static const keyAlarmId = 'detox_alarm_id';

  /// When the current session began. Dart-only (the native accessibility
  /// service never reads it); used to report how long a session actually
  /// ran when it ends -- see [startedAt].
  static const keyStartedAtMillis = 'detox_started_at_millis';

  Future<void> start({required int alarmId, required int minutes}) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final endAt = now.add(Duration(minutes: minutes));
    await prefs.setBool(keyActive, true);
    await prefs.setInt(keyEndAtMillis, endAt.millisecondsSinceEpoch);
    await prefs.setInt(keyAlarmId, alarmId);
    await prefs.setInt(keyStartedAtMillis, now.millisecondsSinceEpoch);
  }

  /// Start time of the current session, or null if it was never recorded
  /// (e.g. a session started before this key existed).
  Future<DateTime?> startedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt(keyStartedAtMillis);
    return millis == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<void> end() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyActive, false);
  }

  /// Null when no session is active or it has already expired.
  Future<DateTime?> activeEndAt() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(keyActive) != true) return null;
    final millis = prefs.getInt(keyEndAtMillis);
    if (millis == null) return null;
    final endAt = DateTime.fromMillisecondsSinceEpoch(millis);
    if (endAt.isBefore(DateTime.now())) return null;
    return endAt;
  }

  Future<bool> isActiveNow() async => (await activeEndAt()) != null;
}
