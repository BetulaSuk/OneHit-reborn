import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';

/// Places a panel to the right of [target] when it fits on screen, else to
/// the left. Vertically it starts at [top], or centres on [target] when
/// [top] is null, and is kept on screen.
class BesideDelegate extends SingleChildLayoutDelegate {
  BesideDelegate({required this.target, this.top});

  final Rect target;
  final double? top;

  static const double gap = OH.unit * 3;
  static const double edge = OH.unit * 2;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final child = childSize;
    final right = target.right + gap;
    var x = right + child.width <= size.width - edge
        ? right
        : target.left - gap - child.width;
    if (x < edge) x = (size.width - child.width - edge).clamp(edge, right);
    final want = top ?? target.center.dy - child.height / 2;
    final maxY = size.height - child.height - edge;
    final y = maxY < edge ? edge : want.clamp(edge, maxY);
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(BesideDelegate old) =>
      old.target != target || old.top != top;
}
