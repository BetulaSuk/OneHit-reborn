import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Turns vertical scrolling into whole steps: +1 for each step down, -1 up.
///
/// A mouse wheel arrives as scroll signals. A precision touchpad on Windows
/// arrives as a pan-zoom gesture instead, which a plain `onPointerSignal`
/// never sees; its pan counts like the wheel the OS would scroll with
/// (fingers up scrolls down, under the default Windows setting).
class ScrollSteps extends StatefulWidget {
  const ScrollSteps({
    super.key,
    required this.onStep,
    required this.child,
    this.wheel = 0,
    this.pan = 24,
  });

  final void Function(int direction) onStep;
  final Widget child;

  /// Wheel delta per step. 0 makes every wheel signal one step.
  final double wheel;

  /// Touchpad travel per step, in logical pixels.
  final double pan;

  @override
  State<ScrollSteps> createState() => _ScrollStepsState();
}

class _ScrollStepsState extends State<ScrollSteps> {
  double _wheel = 0;
  double _pan = 0;

  void _signal(PointerSignalEvent e) {
    if (e is! PointerScrollEvent || e.scrollDelta.dy == 0) return;
    _wheel += e.scrollDelta.dy;
    if (_wheel.abs() < widget.wheel) return;
    final step = _wheel.sign.toInt();
    _wheel = 0;
    widget.onStep(step);
  }

  void _panUpdate(PointerPanZoomUpdateEvent e) {
    _pan -= e.localPanDelta.dy;
    while (_pan.abs() >= widget.pan) {
      final step = _pan.sign.toInt();
      _pan -= step * widget.pan;
      widget.onStep(step);
    }
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerSignal: _signal,
    onPointerPanZoomStart: (_) => _pan = 0,
    onPointerPanZoomUpdate: _panUpdate,
    child: widget.child,
  );
}
