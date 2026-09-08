import 'package:shared_preferences/shared_preferences.dart';

/// Tracks whether the intro/title screen has already been shown once.
class FirstLaunchService {
  const FirstLaunchService();

  static const _key = 'first_launch_seen';

  Future<bool> hasSeenIntro() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }
}
