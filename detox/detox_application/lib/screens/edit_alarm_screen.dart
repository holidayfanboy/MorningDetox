import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/detox_alarm.dart';
import '../models/sound_option.dart';
import '../services/alarm_repository.dart';
import '../services/alarm_service.dart';
import '../services/alarm_sound_service.dart';
import '../utils/duration_format.dart';
import '../utils/repeat_days.dart';
import '../widgets/sketchy_box.dart';
import '../widgets/wheel_time_picker.dart';

/// Add/edit screen. Pass an existing [alarm] to edit it, or null to create
/// a new one. Pops with `true` if the caller should reload the alarm list.
class EditAlarmScreen extends StatefulWidget {
  const EditAlarmScreen({super.key, this.alarm});

  final DetoxAlarm? alarm;

  @override
  State<EditAlarmScreen> createState() => _EditAlarmScreenState();
}

class _EditAlarmScreenState extends State<EditAlarmScreen> {
  static const _repository = AlarmRepository();
  static const _soundService = AlarmSoundService();

  /// Quick-pick durations offered below the manual field, in minutes.
  static const _detoxPresets = [30, 60, 90, 120];

  late bool _creating;
  late DateTime _selectedDateTime;
  late int _detoxMinutes;
  late String? _soundPath;
  late Set<int> _repeatDays;
  late TextEditingController _labelController;
  late TextEditingController _detoxController;
  List<SoundOption> _customSounds = [];
  bool _saving = false;
  bool _soundExpanded = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.alarm;
    _creating = existing == null;
    if (existing == null) {
      final now = DateTime.now().add(const Duration(minutes: 1));
      _selectedDateTime = now.copyWith(second: 0, millisecond: 0);
      _detoxMinutes = defaultDetoxMinutes;
      _soundPath = null;
      _repeatDays = {};
      _labelController = TextEditingController();
    } else {
      _selectedDateTime = existing.dateTime;
      _detoxMinutes = existing.detoxMinutes;
      _soundPath = existing.soundPath;
      _repeatDays = {...existing.repeatDays};
      _labelController = TextEditingController(text: existing.label ?? '');
    }
    _detoxController = TextEditingController(text: _detoxMinutes.toString());
    unawaited(_loadCustomSounds());
  }

  Future<void> _loadCustomSounds() async {
    final sounds = await _soundService.loadCustom();
    if (!mounted) return;
    setState(() => _customSounds = sounds);
  }

  Future<void> _importSound() async {
    final sound = await _soundService.import();
    if (sound == null || !mounted) return;
    setState(() {
      _customSounds = [sound, ..._customSounds];
      _soundPath = sound.path;
      _soundExpanded = false;
    });
  }

  Future<void> _deleteCustomSound(SoundOption sound) async {
    await _soundService.deleteCustom(sound);
    if (!mounted) return;
    setState(() {
      _customSounds = _customSounds.where((s) => s.path != sound.path).toList();
      if (_soundPath == sound.path) _soundPath = null;
    });
  }

  void _selectSound(String? path) {
    setState(() {
      _soundPath = path;
      _soundExpanded = false;
    });
  }

  /// Name of the currently selected sound, for the collapsed control --
  /// falls back to 'Default' if the stored path no longer matches any
  /// built-in or custom sound (e.g. a deleted custom file).
  String get _selectedSoundLabel {
    if (_soundPath == null) return 'Default';
    for (final sound in [...AlarmSoundService.builtIn, ..._customSounds]) {
      if (sound.path == _soundPath) return sound.name;
    }
    return 'Default';
  }

  /// One row in the expanded sound list -- selected row gets a highlighted
  /// background, matching the collapsed control it opens from.
  Widget _soundOptionRow({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? leadingIcon,
    VoidCallback? onDelete,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              color: selected
                  ? scheme.onSurface.withValues(alpha: 0.08)
                  : null,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                if (leadingIcon != null) ...[
                  Icon(leadingIcon, size: 18, color: scheme.onSurface),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (onDelete != null)
                  GestureDetector(
                    onTap: onDelete,
                    child: Icon(
                      Icons.close,
                      size: 18,
                      color: scheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _labelController.dispose();
    _detoxController.dispose();
    super.dispose();
  }

  void _setDetoxMinutes(int minutes) {
    setState(() => _detoxMinutes = minutes.clamp(1, 24 * 60));
  }

  void _applyPreset(int minutes) {
    _setDetoxMinutes(minutes);
    _detoxController.text = minutes.toString();
    _detoxController.selection = TextSelection.collapsed(
      offset: _detoxController.text.length,
    );
  }

  /// Roll the chosen time forward to its next occurrence -- the next
  /// matching weekday if repeat days are set, otherwise tomorrow -- so an
  /// alarm set for a moment that already passed today doesn't ring today.
  void _setTime(TimeOfDay time) {
    setState(() => _selectedDateTime = _nextOccurrence(time));
  }

  void _toggleRepeatDay(int day) {
    setState(() {
      _repeatDays = {..._repeatDays};
      if (!_repeatDays.remove(day)) _repeatDays.add(day);
      _selectedDateTime = _nextOccurrence(
        TimeOfDay.fromDateTime(_selectedDateTime),
      );
    });
  }

  DateTime _nextOccurrence(TimeOfDay time) {
    final now = DateTime.now();
    if (_repeatDays.isNotEmpty) {
      return nextRepeatOccurrence(from: now, time: time, repeatDays: _repeatDays);
    }
    var next = now.copyWith(
      hour: time.hour,
      minute: time.minute,
      second: 0,
      millisecond: 0,
      microsecond: 0,
    );
    if (next.isBefore(now)) next = next.add(const Duration(days: 1));
    return next;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final id = _creating ? AlarmService.newId() : widget.alarm!.id;
    final label = _labelController.text.trim();
    final alarm = DetoxAlarm(
      id: id,
      dateTime: _selectedDateTime,
      detoxMinutes: _detoxMinutes,
      label: label.isEmpty ? null : label,
      enabled: widget.alarm?.enabled ?? true,
      soundPath: _soundPath,
      repeatDays: _repeatDays,
    );
    await _repository.save(alarm);
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pop(context, true);
  }

  Future<void> _delete() async {
    final existing = widget.alarm;
    if (existing == null) return;
    await _repository.delete(existing.id);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_creating ? 'New Alarm' : 'Edit Alarm'),
        leading: TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '...' : 'Save'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              WheelTimePicker(
                initial: TimeOfDay.fromDateTime(_selectedDateTime),
                onChanged: _setTime,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  for (final entry in repeatDayLabels.entries)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: GestureDetector(
                          onTap: () => _toggleRepeatDay(entry.key),
                          child: SketchyBox(
                            seed: entry.key,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 8,
                            ),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: _repeatDays.contains(entry.key)
                                    ? scheme.onSurface.withValues(alpha: 0.18)
                                    : null,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Center(
                                child: Text(
                                  entry.value,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        fontWeight: _repeatDays.contains(
                                          entry.key,
                                        )
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 32),
              Text('Memo', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _labelController,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isCollapsed: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                  hintText: 'Morning, Gym, ...',
                ),
              ),
              const SizedBox(height: 32),
              Text(
                "Stay off your phone for",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  IntrinsicWidth(
                    child: TextField(
                      controller: _detoxController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      style: Theme.of(context).textTheme.displayMedium
                          ?.copyWith(fontSize: 40),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isCollapsed: true,
                        hintText: '30',
                      ),
                      onChanged: (value) {
                        final parsed = int.tryParse(value);
                        if (parsed != null && parsed > 0) {
                          _setDetoxMinutes(parsed);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'minutes',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final minutes in _detoxPresets)
                    GestureDetector(
                      onTap: () => _applyPreset(minutes),
                      child: SketchyBox(
                        seed: minutes,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: _detoxMinutes == minutes
                                ? scheme.onSurface.withValues(alpha: 0.08)
                                : null,
                          ),
                          child: Text(
                            formatMinutesShort(minutes),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 32),
              Text(
                'Alarm Sound',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => setState(() => _soundExpanded = !_soundExpanded),
                child: SketchyBox(
                  seed: 7,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selectedSoundLabel,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      AnimatedRotation(
                        turns: _soundExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 150),
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          color: scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_soundExpanded) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: scheme.onSurface.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Column(
                    children: [
                      _soundOptionRow(
                        label: 'Default',
                        selected: _soundPath == null,
                        onTap: () => _selectSound(null),
                      ),
                      for (final sound in AlarmSoundService.builtIn)
                        _soundOptionRow(
                          label: sound.name,
                          selected: _soundPath == sound.path,
                          onTap: () => _selectSound(sound.path),
                        ),
                      for (final sound in _customSounds)
                        _soundOptionRow(
                          label: sound.name,
                          selected: _soundPath == sound.path,
                          onTap: () => _selectSound(sound.path),
                          onDelete: () => _deleteCustomSound(sound),
                        ),
                      _soundOptionRow(
                        label: 'Add mp3',
                        selected: false,
                        leadingIcon: Icons.add,
                        onTap: _importSound,
                      ),
                    ],
                  ),
                ),
              ],
              if (!_creating) ...[
                const SizedBox(height: 40),
                TextButton(
                  onPressed: _delete,
                  child: Text(
                    'Delete Alarm',
                    style: TextStyle(color: scheme.error),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
