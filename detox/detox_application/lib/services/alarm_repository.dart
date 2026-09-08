import 'package:flutter/material.dart';

import '../models/detox_alarm.dart';
import '../utils/repeat_days.dart';
import 'alarm_service.dart';
import 'alarm_store_service.dart';

/// What screens actually talk to for alarm data. The local store
/// ([AlarmStoreService]) is the source of truth for the list -- including
/// disabled alarms -- and this keeps `package:alarm`'s armed set in sync
/// with it: an enabled alarm is armed with the OS, a disabled one isn't.
class AlarmRepository {
  const AlarmRepository({
    this.store = const AlarmStoreService(),
    this.native = const AlarmService(),
  });

  final AlarmStoreService store;
  final AlarmService native;

  Future<List<DetoxAlarm>> loadAlarms() => store.loadAll();

  Future<void> save(DetoxAlarm alarm) async {
    await store.upsert(alarm);
    if (alarm.enabled) {
      await native.arm(alarm);
    } else {
      await native.disarm(alarm.id);
    }
  }

  Future<void> delete(int id) async {
    await store.remove(id);
    await native.disarm(id);
  }

  /// Flips [alarm]'s enabled state. Re-enabling an alarm whose time has
  /// already passed rolls it forward -- to the next matching weekday for a
  /// repeating alarm, or by a day for a one-shot one -- otherwise arming it
  /// would try to schedule the past.
  Future<void> setEnabled(DetoxAlarm alarm, bool enabled) async {
    var next = alarm.copyWith(enabled: enabled);
    if (enabled && next.dateTime.isBefore(DateTime.now())) {
      next = next.copyWith(dateTime: _rollForward(next));
    }
    await save(next);
  }

  DateTime _rollForward(DetoxAlarm alarm) {
    if (alarm.repeatDays.isEmpty) {
      return alarm.dateTime.add(const Duration(days: 1));
    }
    return nextRepeatOccurrence(
      from: DateTime.now(),
      time: TimeOfDay.fromDateTime(alarm.dateTime),
      repeatDays: alarm.repeatDays,
    );
  }

  /// A one-shot alarm (no repeat days) is consumed once it's rung and been
  /// stopped, rather than left behind as a stale disabled entry. A
  /// repeating alarm is instead rescheduled to its next matching weekday
  /// and re-armed.
  Future<void> consumeAfterRing(int id) async {
    DetoxAlarm? alarm;
    for (final a in await store.loadAll()) {
      if (a.id == id) {
        alarm = a;
        break;
      }
    }
    if (alarm == null || alarm.repeatDays.isEmpty) {
      await store.remove(id);
      await native.disarm(id);
      return;
    }
    await save(alarm.copyWith(dateTime: _rollForward(alarm)));
  }
}
