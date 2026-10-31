import 'dart:async';

import 'package:flutter/foundation.dart';

import 'info_item.dart';

/// Ordered item list plus the once-a-second clock that drives countdowns.
class ItemStore extends ChangeNotifier {
  ItemStore(List<InfoItem> items) : _items = items {
    _apply(DateTime.now());
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  final List<InfoItem> _items;
  late final Timer _clock;
  DateTime now = DateTime.now();

  /// Items that may appear in the minimal window, in list order.
  List<InfoItem> get visible => [
    for (final i in _items)
      if (!i.sunk) i,
  ];

  InfoItem? get pinned {
    for (final i in _items) {
      if (!i.sunk) return i;
    }
    return null;
  }

  /// Ended reminders that are not on screen and need to announce themselves.
  List<InfoItem> get alerts {
    final top = pinned;
    return [
      for (final i in _items)
        if (!i.sunk &&
            i != top &&
            i.time?.kind == TimeKind.reminder &&
            i.time!.state(now) == TimeState.ended)
          i,
    ];
  }

  void tick() {
    now = DateTime.now();
    _apply(now);
    notifyListeners();
  }

  /// Moves [item] to the top so the minimal window shows it.
  void pin(InfoItem item) {
    if (_items.remove(item)) _items.insert(0, item);
    tick();
  }

  void toggleTime(InfoItem item) {
    item.time?.toggle(DateTime.now());
    tick();
  }

  void _apply(DateTime now) {
    final top = pinned;
    for (final item in _items) {
      final t = item.time;
      if (t == null) continue;
      if (item.sunk) {
        t.pause(now);
      } else if (t.kind == TimeKind.timer && !t.manual) {
        item == top ? t.start(now) : t.pause(now);
      }
    }
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }
}
