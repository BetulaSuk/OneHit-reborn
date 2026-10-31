import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// User-adjustable behaviour, read from `config.json` in the app's support
/// folder. A missing file is written out with the defaults so it can be
/// edited by hand; unknown or bad values fall back to the defaults.
class OneHitConfig {
  const OneHitConfig({
    this.previewRadius = 2,
    this.detailHeight = 160,
    this.toggleHotkey = 'ctrl+alt+o',
    this.listHotkey = 'ctrl+alt+l',
  });

  /// Rows shown above and below the strip while hovering. 2 means at most
  /// five items are visible at once.
  final int previewRadius;

  /// Extra height of the minimal window for an item with the detail tag.
  final double detailHeight;

  /// Shows and focuses the window, or hides it when it is already focused.
  final String toggleHotkey;

  /// Opens or closes the detailed list.
  final String listHotkey;

  Map<String, Object?> toJson() => {
    'previewRadius': previewRadius,
    'detailHeight': detailHeight,
    'toggleHotkey': toggleHotkey,
    'listHotkey': listHotkey,
  };

  factory OneHitConfig.fromJson(Map<String, Object?> json) {
    const d = OneHitConfig();
    T pick<T>(String key, T fallback) {
      final v = json[key];
      if (v is T) return v;
      if (fallback is double && v is num) return v.toDouble() as T;
      return fallback;
    }

    return OneHitConfig(
      previewRadius: pick('previewRadius', d.previewRadius).clamp(0, 6),
      detailHeight: pick('detailHeight', d.detailHeight).clamp(60.0, 600.0),
      toggleHotkey: pick('toggleHotkey', d.toggleHotkey),
      listHotkey: pick('listHotkey', d.listHotkey),
    );
  }

  static Future<OneHitConfig> load(File file) async {
    try {
      if (await file.exists()) {
        final json = jsonDecode(await file.readAsString()) as Map;
        return OneHitConfig.fromJson(json.cast<String, Object?>());
      }
      await file.parent.create(recursive: true);
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(const OneHitConfig()),
      );
    } on Object catch (e) {
      debugPrint('OneHit: using default config: $e');
    }
    return const OneHitConfig();
  }
}
