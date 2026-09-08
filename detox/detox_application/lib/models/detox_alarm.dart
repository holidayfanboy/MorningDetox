import 'dart:convert';

import 'package:alarm/alarm.dart';

/// Default detox length used when a stored alarm's payload is missing or
/// unreadable, so a malformed payload degrades gracefully instead of
/// crashing the list screen.
const defaultDetoxMinutes = 15;

/// The extra data this app attaches to an [AlarmSettings] via its free-form
/// `payload` field, encoded as JSON: `{"detoxMinutes": 30, "label": "Morning"}`.
///
/// Only carries what the OS-armed alarm needs -- not [DetoxAlarm.enabled],
/// since a disabled alarm is never armed with `package:alarm` in the first
/// place (see AlarmRepository).
class DetoxPayload {
  const DetoxPayload({required this.detoxMinutes, this.label});

  final int detoxMinutes;
  final String? label;

  String toJsonString() => jsonEncode({
    'detoxMinutes': detoxMinutes,
    if (label != null) 'label': label,
  });

  /// Defensive: never throws. A null/malformed payload just falls back to
  /// [defaultDetoxMinutes] rather than losing the whole alarm list.
  factory DetoxPayload.fromAlarmSettings(AlarmSettings settings) {
    final raw = settings.payload;
    if (raw == null || raw.isEmpty) {
      return const DetoxPayload(detoxMinutes: defaultDetoxMinutes);
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return const DetoxPayload(detoxMinutes: defaultDetoxMinutes);
      }
      final minutes = decoded['detoxMinutes'];
      return DetoxPayload(
        detoxMinutes: minutes is int && minutes > 0
            ? minutes
            : defaultDetoxMinutes,
        label: decoded['label'] as String?,
      );
    } catch (_) {
      return const DetoxPayload(detoxMinutes: defaultDetoxMinutes);
    }
  }
}

/// The view model screens work with: an alarm plus its detox metadata and
/// whether it's currently armed. This is the app's own source of truth
/// (persisted locally, see AlarmStoreService) -- `package:alarm` only ever
/// knows about the subset that's [enabled], since it has no concept of a
/// disabled-but-remembered alarm.
class DetoxAlarm {
  const DetoxAlarm({
    required this.id,
    required this.dateTime,
    required this.detoxMinutes,
    this.label,
    this.enabled = true,
    this.soundPath,
    this.repeatDays = const {},
  });

  final int id;
  final DateTime dateTime;
  final int detoxMinutes;
  final String? label;
  final bool enabled;

  /// What to arm the OS alarm with, fed straight into
  /// `AlarmSettings.assetAudioPath` -- see [SoundOption]. Null means the
  /// device's default alarm sound.
  final String? soundPath;

  /// Weekdays this alarm repeats on, using [DateTime.monday]..
  /// [DateTime.sunday] (1..7). Empty means a one-shot alarm at [dateTime],
  /// which is consumed after it rings rather than rescheduled -- see
  /// [AlarmRepository.consumeAfterRing].
  final Set<int> repeatDays;

  /// Full local-store serialization, including [enabled] -- distinct from
  /// [DetoxPayload], which only carries what rides along on the armed OS
  /// alarm.
  Map<String, dynamic> toJson() => {
    'id': id,
    'dateTime': dateTime.toIso8601String(),
    'detoxMinutes': detoxMinutes,
    if (label != null) 'label': label,
    'enabled': enabled,
    if (soundPath != null) 'soundPath': soundPath,
    if (repeatDays.isNotEmpty) 'repeatDays': repeatDays.toList()..sort(),
  };

  /// Defensive like [DetoxPayload.fromAlarmSettings]: a malformed entry is
  /// dropped (returns null) rather than crashing the whole list load.
  static DetoxAlarm? fromJson(Map<String, dynamic> json) {
    try {
      final id = json['id'];
      final dateTime = json['dateTime'];
      final minutes = json['detoxMinutes'];
      if (id is! int || dateTime is! String || minutes is! int) return null;
      final rawRepeatDays = json['repeatDays'];
      return DetoxAlarm(
        id: id,
        dateTime: DateTime.parse(dateTime),
        detoxMinutes: minutes > 0 ? minutes : defaultDetoxMinutes,
        label: json['label'] as String?,
        enabled: json['enabled'] as bool? ?? true,
        soundPath: json['soundPath'] as String?,
        repeatDays: rawRepeatDays is List
            ? rawRepeatDays.whereType<int>().where((d) => d >= 1 && d <= 7).toSet()
            : const {},
      );
    } catch (_) {
      return null;
    }
  }

  DetoxAlarm copyWith({
    int? id,
    DateTime? dateTime,
    int? detoxMinutes,
    String? label,
    bool? enabled,
    String? soundPath,
    Set<int>? repeatDays,
  }) {
    return DetoxAlarm(
      id: id ?? this.id,
      dateTime: dateTime ?? this.dateTime,
      detoxMinutes: detoxMinutes ?? this.detoxMinutes,
      label: label ?? this.label,
      enabled: enabled ?? this.enabled,
      soundPath: soundPath ?? this.soundPath,
      repeatDays: repeatDays ?? this.repeatDays,
    );
  }
}
