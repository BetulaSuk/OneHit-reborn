import 'package:flutter/widgets.dart';

import '../item/info_item.dart';

/// What the windows ask of the shell that owns the screen: moving, switching
/// between the minimal window and the list, and the overlays that live
/// outside either window (tag zones, the time dial).
abstract interface class ShellActions {
  /// Moves the window by [delta]; the shell keeps it inside the work area.
  void moveBy(Offset delta);

  /// Called when a move ends, to persist the position.
  void moveDone();

  void openList();
  void openMini();

  /// The item that paste and drops without a target apply to.
  void select(InfoItem item);

  /// Long press started on [item], whose row occupies [row] on screen.
  void tagDragStart(InfoItem item, Rect row, Offset pointer);
  void tagDragMove(Offset pointer);
  void tagDragEnd(Offset pointer);

  void openTimeDial(InfoItem item);

  /// Makes the whole window take the mouse until [releaseFull].
  void holdFull();
  void releaseFull();
}

/// Screen rect of the widget that owns [context].
Rect globalRect(BuildContext context) {
  final box = context.findRenderObject()! as RenderBox;
  return box.localToGlobal(Offset.zero) & box.size;
}
