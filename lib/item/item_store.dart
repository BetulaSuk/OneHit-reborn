import 'dart:async';

import 'package:flutter/foundation.dart';

import 'info_item.dart';

/// Ordered item list plus the once-a-second clock that drives countdowns.
///
/// The first floating item is the pinned one the minimal window shows.
/// Every mutation goes through this class so it can save and notify.
class ItemStore extends ChangeNotifier {
  ItemStore(List<InfoItem> items, {this.onSave}) : _items = items {
    _apply(DateTime.now());
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  final List<InfoItem> _items;
  late final Timer _clock;
  DateTime now = DateTime.now();

  /// Called after every content change (not on clock ticks).
  final void Function(ItemStore store)? onSave;

  /// Every item, floating ones first, each group in list order.
  List<InfoItem> get all => [...visible, ..._items.where((i) => i.sunk)];

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

  InfoItem? byId(String id) {
    for (final i in _items) {
      if (i.id == id) return i;
    }
    return null;
  }

  List<Map<String, Object?>> toJson() => [
    for (final i in _items) i.toJson(DateTime.now()),
  ];

  void tick() {
    now = DateTime.now();
    _apply(now);
    notifyListeners();
  }

  void _changed() {
    tick();
    onSave?.call(this);
  }

  /// A new empty item at the top, so the minimal window shows it.
  InfoItem create() {
    final item = InfoItem(
      id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      text: '',
    );
    _items.insert(0, item);
    _changed();
    return item;
  }

  void remove(InfoItem item) {
    if (_items.remove(item)) _changed();
  }

  /// Moves [item] to the top so the minimal window shows it.
  void pin(InfoItem item) {
    if (item.sunk) item.sunk = false;
    if (_items.remove(item)) _items.insert(0, item);
    _changed();
  }

  /// Turns the floating items round by one: forward sends the pinned item
  /// to the end, [back] pins the last one.
  void rotate({bool back = false}) {
    final v = visible;
    if (v.length < 2) return;
    if (back) return pin(v.last);
    _items.remove(v.first);
    _items.insert(_items.indexOf(v.last) + 1, v.first);
    _changed();
  }

  void setText(InfoItem item, String text) {
    item.text = text;
    _changed();
  }

  /// Pasted text goes on the end of the item's text.
  void appendText(InfoItem item, String text) {
    final add = text.trim();
    if (add.isEmpty) return;
    final base = item.text.trimRight();
    item.text = base.isEmpty ? add : '$base $add';
    _changed();
  }

  void setIcon(InfoItem item, String icon) {
    item.icon = icon;
    item.image = null;
    _changed();
  }

  void setImage(InfoItem item, Uint8List? png) {
    item.image = png;
    _changed();
  }

  void setSunk(InfoItem item, bool sunk) {
    item.sunk = sunk;
    _changed();
  }

  void setDetail(InfoItem item, bool detail) {
    item.detail = detail;
    _changed();
  }

  /// Adds a time tag, or re-adjusts the existing one.
  void setTime(InfoItem item, Duration remaining, TimeKind kind) {
    final now = DateTime.now();
    final tag = item.time;
    if (tag == null) {
      item.time = TimeTag(kind: kind, remaining: remaining, now: now);
    } else {
      tag.kind = kind;
      tag.set(remaining, now);
    }
    _changed();
  }

  void clearTime(InfoItem item) {
    item.time = null;
    _changed();
  }

  void toggleTime(InfoItem item) {
    if (item.sunk) return;
    item.time?.toggle(DateTime.now());
    _changed();
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
