import 'package:flutter/material.dart';

import '../services/detox_session_service.dart';
import '../utils/duration_format.dart';
import '../widgets/duration_dial.dart';
import '../widgets/sketchy_box.dart';
import '../widgets/water_ripple_text.dart';
import 'detox_lock_screen.dart';

/// Starts an immediate, alarm-less detox session: the user dials in how long
/// their phone should stay locked (up to 6 hours) and taps "Lock now", which
/// drops straight onto [DetoxLockScreen]. Reached from the alarm list's
/// overflow menu.
class DetoxNowScreen extends StatefulWidget {
  const DetoxNowScreen({super.key});

  @override
  State<DetoxNowScreen> createState() => _DetoxNowScreenState();
}

class _DetoxNowScreenState extends State<DetoxNowScreen> {
  static const _maxMinutes = 360;
  static const _stepMinutes = 5;
  static const _minMinutes = 5;
  static const _sessionService = DetoxSessionService();

  int _minutes = 60;
  bool _starting = false;

  Future<void> _lockNow() async {
    if (_starting) return;
    setState(() => _starting = true);
    // No backing alarm -- alarmId is stored but never read (the accessibility
    // service enforces the lock purely off detox_active + detox_end_at_millis).
    await _sessionService.start(alarmId: -1, minutes: _minutes);
    if (!mounted) return;
    final endAt = DateTime.now().add(Duration(minutes: _minutes));
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => DetoxLockScreen(endAt: endAt)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 0, 0),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Back to alarms',
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DurationDial(
                    minutes: _minutes,
                    maxMinutes: _maxMinutes,
                    stepMinutes: _stepMinutes,
                    minMinutes: _minMinutes,
                    seed: 21,
                    size: 320,
                    onChanged: (m) => setState(() => _minutes = m),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        WaterRippleText(
                          floatAmplitude: 2.0,
                          rippleAmplitude: 0.9,
                          tiltDegrees: 0.6,
                          child: SizedBox(
                            width: 150,
                            child: Text(
                              'Lock your\nphone for...',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: scheme.onSurface.withValues(
                                      alpha: 0.6,
                                    ),
                                  ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        _EditableDuration(
                          minutes: _minutes,
                          onChanged: (m) => setState(
                            () => _minutes = m.clamp(_minMinutes, _maxMinutes),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 44),
                  GestureDetector(
                    onTap: _starting ? null : _lockNow,
                    child: WaterRippleText(
                      floatAmplitude: 3.0,
                      rippleAmplitude: 1.2,
                      tiltDegrees: 0.9,
                      child: SketchyBox(
                        seed: 21,
                        borderRadius: 3,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 18,
                        ),
                        child: Text(
                          _starting ? '...' : 'Lock now',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The big duration readout inside the dial. Shows "1h 30m"; tapping it swaps
/// in a text field so the value can be typed on the phone keyboard
/// ("2h 30m", "150", "45m" all parse). Same tap-to-edit idiom as
/// `_WheelColumn` in `wheel_time_picker.dart`.
class _EditableDuration extends StatefulWidget {
  const _EditableDuration({required this.minutes, required this.onChanged});

  final int minutes;
  final ValueChanged<int> onChanged;

  @override
  State<_EditableDuration> createState() => _EditableDurationState();
}

class _EditableDurationState extends State<_EditableDuration> {
  final TextEditingController _text = TextEditingController();
  final FocusNode _focus = FocusNode();
  bool _editing = false;

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startEditing() {
    _text.text = formatMinutesShort(widget.minutes);
    _text.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _text.text.length,
    );
    setState(() => _editing = true);
    _focus.requestFocus();
  }

  void _commit() {
    if (!_editing) return;
    setState(() => _editing = false);
    final parsed = parseFlexibleDurationMinutes(_text.text);
    if (parsed == null) return;
    final snapped = (parsed / 5).round() * 5;
    if (snapped != widget.minutes) widget.onChanged(snapped);
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.displayMedium?.copyWith(
      fontSize: 40,
    );

    if (_editing) {
      return SizedBox(
        width: 150,
        child: TextField(
          controller: _text,
          focusNode: _focus,
          autofocus: true,
          textAlign: TextAlign.center,
          style: style,
          keyboardType: TextInputType.text,
          maxLength: 7,
          decoration: const InputDecoration(
            counterText: '',
            isCollapsed: true,
            border: InputBorder.none,
          ),
          onTapOutside: (_) => _commit(),
          onEditingComplete: _commit,
          onSubmitted: (_) => _commit(),
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _startEditing,
      child: Text(formatMinutesShort(widget.minutes), style: style),
    );
  }
}
