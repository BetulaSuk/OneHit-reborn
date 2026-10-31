import 'package:flutter/material.dart';

import 'item/info_item.dart';
import 'item/item_store.dart';
import 'strings.dart';

/// A drop zone shown around the window while an item is dragged by long
/// press. Dropping the item on it applies the zone's tag.
class TagZone {
  const TagZone({
    required this.id,
    required this.label,
    required this.icon,
    required this.onDrop,
    this.square = false,
    this.activeLabel,
  });

  final String id;
  final String label;
  final IconData icon;

  /// Square zones are taller (the time zone); the rest are pills.
  final bool square;

  /// Label for the dragged item when it differs from [label], e.g. "Float"
  /// for an item that is already sunk. The built-in zones use it to follow
  /// the language setting.
  final String Function(InfoItem item)? activeLabel;

  final void Function(TagDropContext context) onDrop;
}

/// What a zone can do with the item dropped on it.
class TagDropContext {
  TagDropContext({
    required this.store,
    required this.item,
    required this.openTimeDial,
  });

  final ItemStore store;
  final InfoItem item;

  /// Opens the ring dial for setting the item's countdown.
  final VoidCallback openTimeDial;
}

/// Extension point. Plugins are registered in `main.dart`; each can add tag
/// zones and watch the store. Plugin data belongs in [InfoItem.extra],
/// which is saved with the item.
abstract class OneHitPlugin {
  String get id;

  List<TagZone> get zones => const [];

  void attach(ItemStore store) {}

  void detach() {}
}

/// The default tags from the product concept.
List<TagZone> builtInZones() => [
  TagZone(
    id: 'sink',
    label: strings.sink,
    icon: Icons.swap_vert_rounded,
    activeLabel: (item) => item.sunk ? strings.float : strings.sink,
    onDrop: (c) => c.store.setSunk(c.item, !c.item.sunk),
  ),
  TagZone(
    id: 'time',
    label: strings.time,
    icon: Icons.timer_rounded,
    square: true,
    activeLabel: (_) => strings.time,
    onDrop: (c) => c.openTimeDial(),
  ),
  TagZone(
    id: 'detail',
    label: strings.detail,
    icon: Icons.unfold_more_rounded,
    activeLabel: (item) => item.detail ? strings.undetail : strings.detail,
    onDrop: (c) => c.store.setDetail(c.item, !c.item.detail),
  ),
];
