import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../config.dart';
import '../strings.dart';
import 'info_item.dart';
import 'item_store.dart';

/// Local JSON files in the app's support folder:
/// `items.json` (the list), `state.json` (window position) and
/// `config.json` (user settings, see `config.dart`).
class Storage {
  Storage(this.dir);

  final Directory dir;
  Timer? _pending;

  File get _items => File('${dir.path}${Platform.pathSeparator}items.json');
  File get _state => File('${dir.path}${Platform.pathSeparator}state.json');
  File get config => File('${dir.path}${Platform.pathSeparator}config.json');

  /// Saved items, or the first-run tips when nothing has been saved yet.
  Future<List<InfoItem>> loadItems() async {
    try {
      if (await _items.exists()) {
        final list = jsonDecode(await _items.readAsString()) as List;
        return [
          for (final e in list)
            InfoItem.fromJson((e as Map).cast<String, Object?>()),
        ];
      }
    } on Object catch (e) {
      debugPrint('OneHit: could not read items: $e');
      // Keep the unreadable file for the user instead of overwriting it.
      await _items.rename('${_items.path}.broken');
    }
    return firstRunItems();
  }

  /// Debounced so a burst of edits writes once.
  void saveItems(ItemStore store) {
    _pending?.cancel();
    _pending = Timer(const Duration(milliseconds: 400), () {
      _write(_items, jsonEncode(store.toJson()));
    });
  }

  Future<void> flush(ItemStore store) async {
    _pending?.cancel();
    await _write(_items, jsonEncode(store.toJson()));
  }

  Future<Offset?> loadAnchor() async {
    try {
      if (!await _state.exists()) return null;
      final json = jsonDecode(await _state.readAsString()) as Map;
      final a = json['anchor'] as List?;
      if (a == null || a.length != 2) return null;
      return Offset((a[0] as num).toDouble(), (a[1] as num).toDouble());
    } on Object {
      return null;
    }
  }

  void saveAnchor(Offset anchor) => _write(
    _state,
    jsonEncode({
      'anchor': [anchor.dx, anchor.dy],
    }),
  );

  void saveConfig(OneHitConfig config) =>
      _write(this.config, OneHitConfig.encode(config));

  /// Writes through a temp file so a crash never leaves half a file.
  Future<void> _write(File file, String text) async {
    try {
      await dir.create(recursive: true);
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(text, flush: true);
      await tmp.rename(file.path);
    } on Object catch (e) {
      debugPrint('OneHit: could not save ${file.path}: $e');
    }
  }
}

/// What a new user sees: each tip is itself an item showing the gesture.
List<InfoItem> firstRunItems() => [
  InfoItem(
    id: 'tip-hover',
    text: strings.tipHover,
    icon: 'idea',
    time: TimeTag(
      kind: TimeKind.timer,
      remaining: const Duration(minutes: 25),
      running: false,
    ),
  ),
  InfoItem(id: 'tip-edit', text: strings.tipEdit, icon: 'notes'),
  InfoItem(id: 'tip-tag', text: strings.tipTag, icon: 'flag'),
  InfoItem(id: 'tip-list', text: strings.tipList, icon: 'event'),
  InfoItem(id: 'tip-image', text: strings.tipImage, icon: 'star'),
];
