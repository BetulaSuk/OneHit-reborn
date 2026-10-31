import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'info_item_view.dart';

/// Every gesture an item row understands, shared by the minimal window and
/// the list:
///
/// * clicks are read from raw pointer events, so a single click fires at
///   once instead of waiting to see whether a double click follows;
/// * right click (on release);
/// * long press, which starts a drag to a tag zone (whoever handles
///   [onLongPressStart] follows the pointer from there);
/// * plain drag, for moving the window.
class ItemGestures extends StatefulWidget {
  const ItemGestures({
    super.key,
    required this.child,
    this.onTap,
    this.onDoubleTap,
    this.onSecondaryTap,
    this.onLongPressStart,
    this.onPanStart,
    this.onPanUpdate,
    this.onPanEnd,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onSecondaryTap;
  final void Function(Offset global)? onLongPressStart;
  final VoidCallback? onPanStart;
  final void Function(Offset delta)? onPanUpdate;
  final VoidCallback? onPanEnd;

  @override
  State<ItemGestures> createState() => _ItemGesturesState();
}

class _ItemGesturesState extends State<ItemGestures> {
  static const _clickTime = Duration(milliseconds: 350);
  static const _slop = 6.0;

  int? _pointer;
  Offset _downAt = Offset.zero;
  Duration _downTime = Duration.zero;
  bool _secondary = false;

  Duration? _lastClick;
  Offset _lastClickAt = Offset.zero;

  void _down(PointerDownEvent e) {
    _secondary = e.buttons == kSecondaryMouseButton;
    final primary = e.buttons == kPrimaryMouseButton;
    _pointer = (primary || _secondary) && !timeCellPointers.contains(e.pointer)
        ? e.pointer
        : null;
    _downAt = e.position;
    _downTime = e.timeStamp;
  }

  void _up(PointerUpEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    final quick = e.timeStamp - _downTime < _clickTime;
    final still = (e.position - _downAt).distance < _slop;
    if (!quick || !still) return;
    if (_secondary) {
      widget.onSecondaryTap?.call();
      return;
    }
    final last = _lastClick;
    if (last != null &&
        e.timeStamp - last < _clickTime &&
        (e.position - _lastClickAt).distance < _slop * 2) {
      _lastClick = null;
      widget.onDoubleTap?.call();
    } else {
      _lastClick = e.timeStamp;
      _lastClickAt = e.position;
      widget.onTap?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final longPress = w.onLongPressStart != null;
    final pan = w.onPanUpdate != null;
    return Listener(
      onPointerDown: _down,
      onPointerUp: _up,
      onPointerCancel: (_) => _pointer = null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPressStart: longPress
            ? (d) => w.onLongPressStart!(d.globalPosition)
            : null,
        onPanStart: pan ? (_) => w.onPanStart?.call() : null,
        onPanUpdate: pan ? (d) => w.onPanUpdate!(d.delta) : null,
        onPanEnd: pan ? (_) => w.onPanEnd?.call() : null,
        child: w.child,
      ),
    );
  }
}
