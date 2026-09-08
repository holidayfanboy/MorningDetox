import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide preferences set from the Settings screen: the alarm volume and
/// whether the dark ("reversed") theme is on.
///
/// Unlike the other services in this folder (plain `const` classes with
/// async methods), this one keeps a little live state -- two
/// [ValueNotifier]s -- because the theme has to switch the whole app the
/// instant the toggle is flipped, and the volume slider wants to reflect the
/// stored value without every screen re-reading `SharedPreferences`. Call
/// [load] once at startup (see `main.dart`) to hydrate them.
class SettingsService {
  const SettingsService();

  static const _volumeKey = 'alarm_volume';
  static const _darkModeKey = 'dark_mode';

  /// Default alarm volume when the user has never touched the slider --
  /// loud, but not pinned to the top.
  static const defaultVolume = 0.8;

  /// Current alarm volume, 0 (mute) .. 1 (max). Fed into
  /// `VolumeSettings.volume` when an alarm is armed (see [AlarmService]).
  static final ValueNotifier<double> volume = ValueNotifier(defaultVolume);

  /// Whether the reversed dark theme is active.
  static final ValueNotifier<bool> darkMode = ValueNotifier(false);

  /// Reads the stored values into the notifiers. Safe to call before
  /// `runApp`; a missing key just leaves the default in place.
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    volume.value = (prefs.getDouble(_volumeKey) ?? defaultVolume).clamp(0.0, 1.0);
    darkMode.value = prefs.getBool(_darkModeKey) ?? false;
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

  /// The stored volume read straight from disk -- used by [AlarmService] at
  /// arm time so it doesn't depend on [load] having run in this isolate.
  static Future<double> readVolume() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getDouble(_volumeKey) ?? defaultVolume).clamp(0.0, 1.0);
  }
}
