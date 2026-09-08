import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/detox_alarm.dart';

/// The app's own source of truth for the full alarm list, including
/// disabled ones. `package:alarm` only ever knows about alarms that are
/// currently armed, so it can't answer "what did the user configure but
/// turn off" -- this can.
class AlarmStoreService {
  const AlarmStoreService();

  static const _key = 'all_alarms';

  Future<List<DetoxAlarm>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const [];
    final alarms = <DetoxAlarm>[];
    for (final entry in raw) {
      try {
        final decoded = jsonDecode(entry);
        if (decoded is! Map<String, dynamic>) continue;
        final alarm = DetoxAlarm.fromJson(decoded);
        if (alarm != null) alarms.add(alarm);
      } catch (_) {
        // Skip a corrupted entry rather than losing the whole list.
      }
    }
    alarms.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return alarms;
  }

  Future<void> _saveAll(List<DetoxAlarm> alarms) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      alarms.map((a) => jsonEncode(a.toJson())).toList(),
    );
  }

  Future<void> upsert(DetoxAlarm alarm) async {
    final all = await loadAll();
    final index = all.indexWhere((a) => a.id == alarm.id);
    if (index >= 0) {
      all[index] = alarm;
    } else {
      all.add(alarm);
    }
    await _saveAll(all);
  }

  Future<void> remove(int id) async {
    final all = await loadAll();
    all.removeWhere((a) => a.id == id);
    await _saveAll(all);
  }
}
