import 'dart:async';

import 'package:alarm/alarm.dart';
import 'package:alarm/utils/alarm_set.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/detox_alarm.dart';
import '../services/accessibility_bridge.dart';
import '../services/alarm_repository.dart';
import '../services/analytics_service.dart';
import '../theme/app_theme.dart';
import '../utils/duration_format.dart';
import '../utils/repeat_days.dart';
import '../widgets/toggle_dot.dart';
import 'accessibility_permission_screen.dart';
import 'allowed_apps_screen.dart';
import 'detox_now_screen.dart';
import 'edit_alarm_screen.dart';
import 'settings_screen.dart';

class AlarmListScreen extends StatefulWidget {
  const AlarmListScreen({super.key});

  @override
  State<AlarmListScreen> createState() => _AlarmListScreenState();
}

class _AlarmListScreenState extends State<AlarmListScreen> {
  static const _repository = AlarmRepository();
  static const _accessibilityBridge = AccessibilityBridge();
  static const _analytics = AnalyticsService();

  List<DetoxAlarm> _alarms = [];
  bool _showAccessibilityBanner = false;
  StreamSubscription<AlarmSet>? _scheduledSubscription;
  Timer? _minuteTicker;

  /// Id of the alarm whose swipe-to-delete button is currently revealed --
  /// at most one at a time, so opening a new row's action closes any other.
  int? _openAlarmId;

  @override
  void initState() {
    super.initState();
    unawaited(_analytics.screenView('alarm_list'));
    unawaited(_load());
    _scheduledSubscription = Alarm.scheduled.listen((_) => unawaited(_load()));
    unawaited(_refreshAccessibilityBanner());
    // The per-row "time until" labels only need minute precision, so a
    // single shared ticker is enough -- not a timer per row.
    _minuteTicker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _scheduledSubscription?.cancel();
    _minuteTicker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final alarms = await _repository.loadAlarms();
    if (!mounted) return;
    setState(() => _alarms = alarms);
  }

  Future<void> _refreshAccessibilityBanner() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final enabled = await _accessibilityBridge.isEnabled();
    if (!mounted) return;
    setState(() => _showAccessibilityBanner = !enabled);
  }

  Future<void> _openEditor([DetoxAlarm? alarm]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EditAlarmScreen(alarm: alarm)),
    );
    if (changed == true) unawaited(_load());
  }

  Future<void> _toggle(DetoxAlarm alarm, bool value) async {
    setState(() {
      final index = _alarms.indexWhere((a) => a.id == alarm.id);
      if (index >= 0) _alarms[index] = alarm.copyWith(enabled: value);
    });
    unawaited(_analytics.alarmToggled(value));
    await _repository.setEnabled(alarm, value);
    unawaited(_load());
  }

  Future<void> _delete(DetoxAlarm alarm) async {
    if (_openAlarmId == alarm.id) setState(() => _openAlarmId = null);
    await _repository.delete(alarm.id);
    unawaited(_load());
  }

  /// The soonest enabled alarm still ahead of now, or null if there isn't
  /// one -- used for the single "next alarm" summary under the title,
  /// rather than repeating it on every row.
  DetoxAlarm? get _nextAlarm {
    final now = DateTime.now();
    final upcoming = _alarms
        .where((a) => a.enabled && a.dateTime.isAfter(now))
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return upcoming.isEmpty ? null : upcoming.first;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dividerColor = scheme.onSurface.withValues(alpha: 0.15);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  PopupMenuButton<VoidCallback>(
                    icon: const Icon(Icons.more_horiz, size: 28),
                    tooltip: 'Menu',
                    onSelected: (action) => action(),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SettingsScreen(),
                          ),
                        ),
                        child: Text(
                          'Settings',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      PopupMenuItem(
                        value: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DetoxNowScreen(),
                          ),
                        ),
                        child: Text(
                          'Detox Now',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (defaultTargetPlatform == TargetPlatform.android)
                    IconButton(
                      icon: const Icon(Icons.apps_rounded, size: 28),
                      tooltip: 'Allowed Apps',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AllowedAppsScreen(),
                        ),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.add_rounded, size: 32),
                    onPressed: () => _openEditor(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Morning Detox',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  if (_nextAlarm case final next?) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Next: ${TimeOfDay.fromDateTime(next.dateTime).format(context)} • '
                      '${formatCountdownWords(next.dateTime.difference(DateTime.now()))}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (_showAccessibilityBanner)
              GestureDetector(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AccessibilityPermissionScreen(),
                    ),
                  );
                  unawaited(_refreshAccessibilityBanner());
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: dividerColor),
                      bottom: BorderSide(color: dividerColor),
                    ),
                  ),
                  child: Text(
                    'Turn on real blocking for Android →',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            Expanded(
              child: _alarms.isEmpty
                  ? Center(
                      child: Text(
                        'No alarms set',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: scheme.onSurface.withValues(alpha: 0.4),
                            ),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: _alarms.length,
                      itemBuilder: (context, index) {
                        final alarm = _alarms[index];
                        return _SwipeableAlarmRow(
                          key: ValueKey(alarm.id),
                          alarm: alarm,
                          dividerColor: dividerColor,
                          isOpen: _openAlarmId == alarm.id,
                          onOpenChanged: (open) => setState(
                            () => _openAlarmId = open ? alarm.id : null,
                          ),
                          onTap: () => _openEditor(alarm),
                          onToggle: (value) => _toggle(alarm, value),
                          onDelete: () => _delete(alarm),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Wraps [_AlarmRow] with a swipe-to-reveal red Delete button, matching the
/// standard iOS/Android list-row delete gesture: dragging the row left
/// reveals the button behind its right edge; tapping the button deletes,
/// tapping the row while revealed just closes it back up.
class _SwipeableAlarmRow extends StatefulWidget {
  const _SwipeableAlarmRow({
    super.key,
    required this.alarm,
    required this.dividerColor,
    required this.isOpen,
    required this.onOpenChanged,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
  });

  final DetoxAlarm alarm;
  final Color dividerColor;
  final bool isOpen;
  final ValueChanged<bool> onOpenChanged;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  @override
  State<_SwipeableAlarmRow> createState() => _SwipeableAlarmRowState();
}

class _SwipeableAlarmRowState extends State<_SwipeableAlarmRow>
    with SingleTickerProviderStateMixin {
  static const _actionWidth = 88.0;
  static const _flingVelocity = 300.0;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
    value: widget.isOpen ? 1 : 0,
  );

  @override
  void didUpdateWidget(covariant _SwipeableAlarmRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isOpen && _controller.value > 0) {
      _controller.animateTo(0, curve: Curves.easeOut);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0;
    _controller.value = (_controller.value - delta / _actionWidth).clamp(
      0.0,
      1.0,
    );
  }

  void _handleDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final open =
        velocity < -_flingVelocity ||
        (_controller.value > 0.5 && velocity <= _flingVelocity);
    _controller.animateTo(open ? 1 : 0, curve: Curves.easeOut);
    widget.onOpenChanged(open);
  }

  void _close() {
    _controller.animateTo(0, curve: Curves.easeOut);
    widget.onOpenChanged(false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final row = ColoredBox(
      color: scheme.surface,
      child: _AlarmRow(
        alarm: widget.alarm,
        dividerColor: widget.dividerColor,
        onTap: widget.onTap,
        onToggle: widget.onToggle,
      ),
    );

    return AnimatedBuilder(
      animation: _controller,
      child: row,
      builder: (context, child) {
        final revealed = _actionWidth * _controller.value;
        return Stack(
          children: [
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: widget.onDelete,
                  child: Container(
                    width: _actionWidth,
                    color: scheme.error,
                    alignment: Alignment.center,
                    child: Text(
                      'Delete',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(
                            color: scheme.onError,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ),
              ),
            ),
            Transform.translate(
              offset: Offset(-revealed, 0),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: _handleDragUpdate,
                onHorizontalDragEnd: _handleDragEnd,
                child: _controller.value > 0
                    ? GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _close,
                        child: AbsorbPointer(child: child),
                      )
                    : child,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AlarmRow extends StatelessWidget {
  const _AlarmRow({
    required this.alarm,
    required this.dividerColor,
    required this.onTap,
    required this.onToggle,
  });

  final DetoxAlarm alarm;
  final Color dividerColor;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final timeOfDay = TimeOfDay.fromDateTime(alarm.dateTime);
    final hour = timeOfDay.hour.toString().padLeft(2, '0');
    final minute = timeOfDay.minute.toString().padLeft(2, '0');
    final dimColor = scheme.onSurface.withValues(
      alpha: alarm.enabled ? 0.55 : 0.3,
    );
    final ink = alarm.enabled
        ? scheme.onSurface
        : scheme.onSurface.withValues(alpha: 0.35);

    final bigStyle = Theme.of(context).textTheme.displayLarge
        ?.copyWith(color: ink, letterSpacing: AppTheme.clockLetterSpacing);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: dividerColor)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (alarm.label != null && alarm.label!.isNotEmpty)
                    Text(
                      alarm.label!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: ink,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  Text('$hour:$minute', style: bigStyle),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock, size: 14, color: dimColor),
                      const SizedBox(width: 4),
                      Text(
                        '${formatMinutesShort(alarm.detoxMinutes)} • '
                        '${formatCountdownWords(alarm.dateTime.difference(DateTime.now()))}',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: dimColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (formatRepeatDays(alarm.repeatDays) case final repeat?)
                    Text(
                      repeat,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: dimColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
            ToggleDot(
              value: alarm.enabled,
              seed: alarm.id,
              onChanged: onToggle,
            ),
          ],
        ),
      ),
    );
  }
}
