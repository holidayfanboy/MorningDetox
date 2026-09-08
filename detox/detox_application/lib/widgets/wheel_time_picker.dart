import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A vertical scroll-wheel time picker (24-hour).
///
/// Drag either column up or down to change the hour / minute, or tap the
/// number to replace the wheel with a field and type the value directly.
class WheelTimePicker extends StatelessWidget {
  const WheelTimePicker({
    super.key,
    required this.initial,
    required this.onChanged,
  });

  final TimeOfDay initial;
  final ValueChanged<TimeOfDay> onChanged;

  static const _itemExtent = 56.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme.displayMedium
        ?.copyWith(fontSize: 44);

    var hour = initial.hour;
    var minute = initial.minute;
    void emit() => onChanged(TimeOfDay(hour: hour, minute: minute));

    return SizedBox(
      height: _itemExtent * 3,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Highlight band behind the centred (selected) row.
          Container(
            height: _itemExtent,
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: scheme.onSurface.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                scheme.surface,
                scheme.surface.withValues(alpha: 0),
                scheme.surface.withValues(alpha: 0),
                scheme.surface,
              ],
              stops: const [0.0, 0.28, 0.72, 1.0],
            ).createShader(bounds),
            blendMode: BlendMode.dstOut,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _WheelColumn(
                  value: hour,
                  count: 24,
                  itemExtent: _itemExtent,
                  textStyle: textStyle,
                  onChanged: (v) {
                    hour = v;
                    emit();
                  },
                ),
                Text(':', style: textStyle),
                _WheelColumn(
                  value: minute,
                  count: 60,
                  itemExtent: _itemExtent,
                  textStyle: textStyle,
                  onChanged: (v) {
                    minute = v;
                    emit();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WheelColumn extends StatefulWidget {
  const _WheelColumn({
    required this.value,
    required this.count,
    required this.itemExtent,
    required this.textStyle,
    required this.onChanged,
  });

  final int value;
  final int count; // 24 for hours, 60 for minutes
  final double itemExtent;
  final TextStyle? textStyle;
  final ValueChanged<int> onChanged;

  @override
  State<_WheelColumn> createState() => _WheelColumnState();
}

class _WheelColumnState extends State<_WheelColumn> {
  late final FixedExtentScrollController _wheel = FixedExtentScrollController(
    initialItem: widget.value,
  );
  final TextEditingController _text = TextEditingController();
  final FocusNode _focus = FocusNode();
  bool _editing = false;

  @override
  void dispose() {
    _wheel.dispose();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startEditing() {
    _text.text = widget.value.toString().padLeft(2, '0');
    _text.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _text.text.length,
    );
    setState(() => _editing = true);
    _focus.requestFocus();
  }

  void _commit() {
    if (!_editing) return;
    final parsed = int.tryParse(_text.text) ?? widget.value;
    final clamped = parsed.clamp(0, widget.count - 1);
    setState(() => _editing = false);
    if (_wheel.hasClients) _wheel.jumpToItem(clamped);
    if (clamped != widget.value) widget.onChanged(clamped);
  }

  @override
  Widget build(BuildContext context) {
    final width = widget.itemExtent * 1.7;

    if (_editing) {
      return SizedBox(
        width: width,
        height: widget.itemExtent,
        child: Center(
          child: TextField(
            controller: _text,
            focusNode: _focus,
            autofocus: true,
            textAlign: TextAlign.center,
            style: widget.textStyle,
            keyboardType: TextInputType.number,
            maxLength: 2,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              counterText: '',
              isCollapsed: true,
              border: InputBorder.none,
            ),
            onTapOutside: (_) => _commit(),
            onEditingComplete: _commit,
            onSubmitted: (_) => _commit(),
          ),
        ),
      );
    }

    return SizedBox(
      width: width,
      child: ListWheelScrollView.useDelegate(
        controller: _wheel,
        itemExtent: widget.itemExtent,
        physics: const FixedExtentScrollPhysics(),
        perspective: 0.003,
        diameterRatio: 1.6,
        onSelectedItemChanged: (i) => widget.onChanged(i % widget.count),
        childDelegate: ListWheelChildLoopingListDelegate(
          children: [
            for (var i = 0; i < widget.count; i++)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _startEditing,
                child: Center(
                  child: Text(
                    i.toString().padLeft(2, '0'),
                    style: widget.textStyle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
