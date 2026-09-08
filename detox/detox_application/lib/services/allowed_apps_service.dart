import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// The set of apps that stay reachable during a detox lock session --
/// global, not per-alarm, so there's exactly one list to manage.
///
/// Read directly (as plain JSON under a single `String` key, not a
/// `StringList`) by `DetoxAccessibilityService.kt` on the native side, the
/// same way `DetoxSessionService` is -- see that class's doc comment for why
/// `setStringList` is avoided: its on-disk encoding is a plugin
/// implementation detail not worth relying on from Kotlin.
class AllowedAppsService {
  const AllowedAppsService();

  static const _key = 'allowed_packages';

  Future<Set<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const {};
      return decoded.whereType<String>().toSet();
    } catch (_) {
      return const {};
    }
  }

  Future<void> save(Set<String> packageNames) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(packageNames.toList()));
  }
}
