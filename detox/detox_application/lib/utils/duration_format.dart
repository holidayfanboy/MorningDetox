/// Formats a whole number of minutes as "30m" / "1h" / "1h 30m" / "2h" --
/// a compact duration used for the detox-length chips and list captions.
String formatMinutesShort(int minutes) {
  if (minutes < 60) return '${minutes}m';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '${hours}h' : '${hours}h ${rest}m';
}

/// Parses a loosely-typed duration into whole minutes -- the inverse of
/// [formatMinutesShort] for a field the user edits by hand. Accepts
/// "90", "2h", "2h 30m", "2h30", "45m", "1 h 5 m". Returns null when the
/// string carries no digits at all. The result is NOT clamped or snapped --
/// the caller applies its own range and step.
int? parseFlexibleDurationMinutes(String input) {
  final text = input.trim().toLowerCase();
  if (text.isEmpty) return null;

  final hourMatch = RegExp(r'(\d+)\s*h').firstMatch(text);
  final minuteMatch = RegExp(r'(\d+)\s*m').firstMatch(text);

  if (hourMatch == null && minuteMatch == null) {
    final digitsOnly = RegExp(r'^\d+$');
    if (!digitsOnly.hasMatch(text)) return null;
    return int.parse(text);
  }

  final hours = int.tryParse(hourMatch?.group(1) ?? '') ?? 0;
  final minutes = int.tryParse(minuteMatch?.group(1) ?? '') ?? 0;
  return hours * 60 + minutes;
}

/// Formats a [Duration] as "1h 24m 03s" / "24m 03s" / "3s", trimming leading
/// zero units so a countdown reads naturally as it gets shorter.
String formatCountdown(Duration d) {
  if (d.isNegative) d = Duration.zero;
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60);
  final seconds = d.inSeconds.remainder(60);

  final parts = <String>[];
  if (hours > 0) parts.add('${hours}h');
  if (hours > 0 || minutes > 0) {
    parts.add(
      hours > 0 ? '${minutes.toString().padLeft(2, '0')}m' : '${minutes}m',
    );
  }
  parts.add(
    (hours > 0 || minutes > 0)
        ? '${seconds.toString().padLeft(2, '0')}s'
        : '${seconds}s',
  );
  return parts.join(' ');
}

/// Formats a [Duration] as "19 Hours 51 Minutes" / "45 Minutes" / "Less
/// than a minute" -- the coarser, minute-granularity style used for a
/// per-alarm "time until" label in a list, where re-rendering every second
/// would be noise rather than useful precision.
String formatCountdownWords(Duration d) {
  if (d.isNegative) d = Duration.zero;
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60);

  if (hours == 0 && minutes == 0) return 'Less than a minute';

  final parts = <String>[];
  if (hours > 0) parts.add('$hours ${hours == 1 ? 'Hour' : 'Hours'}');
  if (minutes > 0) parts.add('$minutes ${minutes == 1 ? 'Minute' : 'Minutes'}');
  return parts.join(' ');
}
