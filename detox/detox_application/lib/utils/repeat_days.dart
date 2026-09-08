import 'package:flutter/material.dart';

/// Weekdays in display order, paired with [DateTime.monday]..
/// [DateTime.sunday] (1..7) so they can be stored and compared directly
/// against `DateTime.weekday`.
const repeatDayLabels = {
  DateTime.monday: 'Mon',
  DateTime.tuesday: 'Tue',
  DateTime.wednesday: 'Wed',
  DateTime.thursday: 'Thu',
  DateTime.friday: 'Fri',
  DateTime.saturday: 'Sat',
  DateTime.sunday: 'Sun',
};

/// Short summary of [repeatDays] for a list row, e.g. "Mon, Wed, Fri",
/// "Every day", or null when it's a one-shot alarm (nothing to show).
String? formatRepeatDays(Set<int> repeatDays) {
  if (repeatDays.isEmpty) return null;
  if (repeatDays.length == 7) return 'Every day';
  return repeatDayLabels.entries
      .where((e) => repeatDays.contains(e.key))
      .map((e) => e.value)
      .join(', ');
}

/// The next date/time on or after [from] that falls on one of [repeatDays]
/// at [time], strictly after [from]. Assumes [repeatDays] is non-empty.
DateTime nextRepeatOccurrence({
  required DateTime from,
  required TimeOfDay time,
  required Set<int> repeatDays,
}) {
  for (var offset = 0; offset < 8; offset++) {
    final day = from.add(Duration(days: offset));
    final candidate = DateTime(
      day.year,
      day.month,
      day.day,
      time.hour,
      time.minute,
    );
    if (repeatDays.contains(candidate.weekday) && candidate.isAfter(from)) {
      return candidate;
    }
  }
  // Unreachable when repeatDays is non-empty -- a full week is checked above.
  return from;
}
