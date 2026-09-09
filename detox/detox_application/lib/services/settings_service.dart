import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide preferences set from the Settings screen: the alarm volume,
/// whether the dark ("reversed") theme is on, and whether anonymous usage
/// analytics are shared.
///
/// Unlike the other services in this folder (plain `const` classes with
/// async methods), this one keeps a little live state -- three
/// [ValueNotifier]s -- because the theme has to switch the whole app the
/// instant the toggle is flipped, the volume slider wants to reflect the
/// stored value without every screen re-reading `SharedPreferences`, and
/// [AnalyticsService] watches [analyticsEnabled] to turn collection on and
/// off. Call [load] once at startup (see `main.dart`) to hydrate them.
class SettingsService {
  const SettingsService();

  static const _volumeKey = 'alarm_volume';
  static const _darkModeKey = 'dark_mode';
  static const _analyticsKey = 'analytics_enabled';

  /// Default alarm volume when the user has never touched the slider --
  /// loud, but not pinned to the top.
  static const defaultVolume = 0.8;

  /// Current alarm volume, 0 (mute) .. 1 (max). Fed into
  /// `VolumeSettings.volume` when an alarm is armed (see [AlarmService]).
  static final ValueNotifier<double> volume = ValueNotifier(defaultVolume);

  /// Whether the reversed dark theme is active.
  static final ValueNotifier<bool> darkMode = ValueNotifier(false);

  /// Whether anonymous usage analytics are collected. On by default;
  /// [AnalyticsService.init] applies this and keeps in sync with changes.
  static final ValueNotifier<bool> analyticsEnabled = ValueNotifier(true);

  /// Reads the stored values into the notifiers. Safe to call before
  /// `runApp`; a missing key just leaves the default in place.
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    volume.value = (prefs.getDouble(_volumeKey) ?? defaultVolume).clamp(0.0, 1.0);
    darkMode.value = prefs.getBool(_darkModeKey) ?? false;
    analyticsEnabled.value = prefs.getBool(_analyticsKey) ?? true;
  }

  static Future<void> setVolume(double value) async {
    final clamped = value.clamp(0.0, 1.0);
    volume.value = clamped;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_volumeKey, clamped);
  }

  static Future<void> setDarkMode(bool value) async {
    darkMode.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, value);
  }

  static Future<void> setAnalyticsEnabled(bool value) async {
    analyticsEnabled.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_analyticsKey, value);
  }

  /// The stored volume read straight from disk -- used by [AlarmService] at
  /// arm time so it doesn't depend on [load] having run in this isolate.
  static Future<double> readVolume() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getDouble(_volumeKey) ?? defaultVolume).clamp(0.0, 1.0);
  }
}
