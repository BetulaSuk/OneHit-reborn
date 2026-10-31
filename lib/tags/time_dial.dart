import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../editor/side_editor.dart';
import '../item/info_item.dart';
import '../item/info_item_view.dart';
import '../strings.dart';
import '../theme/tokens.dart';

/// Sets an item's countdown on an activity ring: one lap is one hour, up to
/// twelve. Turn it by dragging (from anywhere on the dial, the knob follows)
/// or with the wheel; the hours and minutes below also scroll on their own.
class TimeDial extends StatefulWidget {
  const TimeDial({
    super.key,
    required this.item,
    required this.now,
    required this.onConfirm,
    required this.onCancel,
    this.onRemove,
  });

  static const double width = OH.stripWidth + OH.unit * 8;

  final InfoItem item;
  final DateTime now;
  final void Function(Duration remaining, TimeKind kind) onConfirm;
  final VoidCallback onCancel;

  /// Only offered when the item already has a time tag.
  final VoidCallback? onRemove;

  @override
  State<TimeDial> createState() => _TimeDialState();
}

class _TimeDialState extends State<TimeDial> {
  static const int _max = 12 * 60;

  /// Minutes, kept fractional while dragging so slow turns still move.
  late double _value;
  late TimeKind _kind;
  double? _lastAngle;
  final _focus = FocusNode();

  int get _minutes => _value.round().clamp(0, _max);

  @override
  void initState() {
    super.initState();
    final time = widget.item.time;
    if (time == null || time.state(widget.now) == TimeState.ended) {
      _value = 25;
    } else {
      _value = (time.remaining(widget.now).inSeconds / 60).ceilToDouble();
    }
    _kind = time?.kind ?? TimeKind.reminder;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _add(double minutes) =>
      setState(() => _value = (_minutes + minutes).clamp(0, _max).toDouble());

  void _confirm() => widget.onConfirm(Duration(minutes: _minutes), _kind);

  static double _angle(Offset local, double size) {
    final v = local - Offset(size / 2, size / 2);
    return math.atan2(v.dy, v.dx);
  }

  void _turn(Offset local, double size) {
    final a = _angle(local, size);
    final last = _lastAngle;
    _lastAngle = a;
    if (last == null) return;
    var d = a - last;
    // Unwrap so crossing the top keeps counting into the next lap.
    if (d > math.pi) d -= 2 * math.pi;
    if (d < -math.pi) d += 2 * math.pi;
    setState(() {
      _value = (_value + d / (2 * math.pi) * 60).clamp(0, _max.toDouble());
    });
  }

  void _wheel(PointerSignalEvent e, double step) {
    if (e is PointerScrollEvent) _add(e.scrollDelta.dy < 0 ? step : -step);
  }

  KeyEventResult _key(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.escape) {
      widget.onCancel();
    } else if (k == LogicalKeyboardKey.enter ||
        k == LogicalKeyboardKey.numpadEnter) {
      _confirm();
    } else if (k == LogicalKeyboardKey.arrowUp) {
      _add(1);
    } else if (k == LogicalKeyboardKey.arrowDown) {
      _add(-1);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    const ring = 224.0;
    final m = _minutes;
    return Focus(
      focusNode: _focus,
      onKeyEvent: _key,
      child: Container(
        width: TimeDial.width,
        padding: const EdgeInsets.all(OH.unit * 4),
        decoration: const ShapeDecoration(
          color: OH.ground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(OH.unit * 6)),
          ),
          shadows: OH.lift,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InfoItemView(item: widget.item, now: widget.now, lifted: false),
            const SizedBox(height: OH.unit * 4),
            Listener(
              onPointerSignal: (e) => _wheel(e, 5),
              child: GestureDetector(
                onPanStart: (d) {
                  _lastAngle = null;
                  _turn(d.localPosition, ring);
                },
                onPanUpdate: (d) => _turn(d.localPosition, ring),
                onPanEnd: (_) => setState(() => _value = _minutes.toDouble()),
                child: MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: SizedBox.square(
                    dimension: ring,
                    child: CustomPaint(
                      painter: RingPainter(minutes: _value),
                      child: Center(
                        child: Text(
                          m >= 60 ? strings.laps(m ~/ 60) : '',
                          style: OH.itemText.copyWith(color: OH.inkSoft),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: OH.unit * 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Digits(
                  value: m ~/ 60,
                  label: strings.hours,
                  onWheel: (e) => _wheel(e, 60),
                  onStep: (s) => _add(60.0 * s),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: OH.unit),
                  child: Text(':', style: _digitStyle),
                ),
                _Digits(
                  value: m % 60,
                  label: strings.minutes,
                  onWheel: (e) => _wheel(e, 1),
                  onStep: (s) => _add(s.toDouble()),
                ),
              ],
            ),
            const SizedBox(height: OH.unit * 4),
            KindSwitch(
              kind: _kind,
              onChanged: (k) => setState(() => _kind = k),
            ),
            const SizedBox(height: OH.unit * 4),
            Row(
              children: [
                if (widget.onRemove != null)
                  TextButton(
                    onPressed: widget.onRemove,
                    style: _flat,
                    child: Text(strings.removeTime),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: widget.onCancel,
                  style: _flat,
                  child: Text(strings.cancel),
                ),
                const SizedBox(width: OH.unit * 2),
                FilledButton(
                  onPressed: m == 0 ? null : _confirm,
                  style: FilledButton.styleFrom(
                    backgroundColor: OH.ink,
                    foregroundColor: OH.ground,
                    textStyle: OH.itemText,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  child: Text(strings.ok),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

ButtonStyle get _flat =>
    TextButton.styleFrom(foregroundColor: OH.ink, textStyle: OH.itemText);

TextStyle get _digitStyle => OH.timeText.copyWith(fontSize: 40);

/// Two digits that scroll (wheel) or drag (up and down) on their own.
class _Digits extends StatefulWidget {
  const _Digits({
    required this.value,
    required this.label,
    required this.onWheel,
    required this.onStep,
  });

  final int value;
  final String label;
  final void Function(PointerSignalEvent e) onWheel;
  final void Function(int steps) onStep;

  @override
  State<_Digits> createState() => _DigitsState();
}

class _DigitsState extends State<_Digits> {
  bool _hover = false;
  double _drag = 0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.label,
      value: '${widget.value}',
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeUpDown,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Listener(
          onPointerSignal: widget.onWheel,
          child: GestureDetector(
            onVerticalDragUpdate: (d) {
              _drag -= d.delta.dy;
              while (_drag.abs() >= 14) {
                widget.onStep(_drag.sign.toInt());
                _drag -= _drag.sign * 14;
              }
            },
            onVerticalDragEnd: (_) => _drag = 0,
            child: AnimatedContainer(
              duration: OH.quick,
              padding: const EdgeInsets.symmetric(
                horizontal: OH.unit * 2,
                vertical: OH.unit,
              ),
              decoration: BoxDecoration(
                color: _hover ? OH.discFill : Colors.transparent,
                borderRadius: BorderRadius.circular(OH.unit * 3),
              ),
              child: Text(
                widget.value.toString().padLeft(2, '0'),
                style: _digitStyle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The activity ring: track, first lap, and the overflow lap laid over it
/// in a deeper green that blends in near the start and casts a shadow at
/// its cap. A white knob marks the end.
class RingPainter extends CustomPainter {
  RingPainter({required this.minutes});

  final double minutes;

  static const double stroke = 26;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = (size.shortestSide - stroke) / 2 - 4;
    final box = Rect.fromCircle(center: c, radius: r);
    const top = -math.pi / 2;

    Paint arc(Color color) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;

    canvas.drawCircle(c, r, arc(OH.runTrack));

    final laps = minutes / 60;
    final first = laps.clamp(0.0, 1.0);
    if (first > 0) {
      canvas.drawArc(box, top, 2 * math.pi * first, false, arc(OH.runLap));
    }

    var endAngle = top + 2 * math.pi * first;
    if (laps > 1) {
      final frac = laps - laps.floor();
      final sweep = 2 * math.pi * (frac == 0 ? 1 : frac);
      endAngle = top + sweep;
      final end = c + Offset(math.cos(endAngle), math.sin(endAngle)) * r;
      // Shadow under the overflow cap, so it reads as passing over the lap.
      canvas.drawCircle(
        end + const Offset(0, 2),
        stroke / 2,
        Paint()
          ..color = const Color(0x40000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      final blend = math.min(0.35, sweep) / sweep;
      // Butt start: a round start cap would fall before the gradient's
      // start angle and show the deep colour there. The end cap is drawn
      // as a disc instead.
      final paint = arc(OH.runOver)
        ..strokeCap = StrokeCap.butt
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: sweep,
          colors: const [OH.runLap, OH.runOver],
          stops: [0, blend],
          transform: const GradientRotation(top),
        ).createShader(box);
      canvas.drawArc(box, top, sweep, false, paint);
      canvas.drawCircle(end, stroke / 2, Paint()..color = OH.runOver);
    }

    // Knob.
    final knob = c + Offset(math.cos(endAngle), math.sin(endAngle)) * r;
    canvas.drawCircle(
      knob + const Offset(0, 1.5),
      stroke / 2 - 2,
      Paint()
        ..color = const Color(0x33000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawCircle(knob, stroke / 2 - 3, Paint()..color = OH.ground);
  }

  @override
  bool shouldRepaint(RingPainter old) => old.minutes != minutes;
}
