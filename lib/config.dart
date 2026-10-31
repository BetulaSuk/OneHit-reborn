import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'shell/keys.dart';

/// What the key after the prefix can do.
enum Command {
  toggle('显示或隐藏浮窗', 'h'),
  list('打开或关闭列表', 'l'),
  create('新建信息', 'n'),
  edit('编辑当前信息', 'e'),
  paste('剪贴板存为新信息', 'v'),
  time('给当前信息定时', 't'),
  pause('暂停或继续计时', 'p'),
  next('下一条信息', 'j'),
  previous('上一条信息', 'k'),
  settings('打开设置', 's');

  const Command(this.label, this.defaultKey);

  final String label;
  final String defaultKey;
}

/// User-adjustable behaviour, read from `config.json` in the app's support
/// folder and changed from the settings panel. A missing file is written
/// out with the defaults so it can be edited by hand; unknown or bad values
/// fall back to the defaults.
@immutable
class OneHitConfig {
  const OneHitConfig({
    this.previewRadius = 2,
    this.detailHeight = 160,
    this.prefix = 'ctrl+alt+o',
    this.keys = const {},
    this.display = '',
    this.fontFamily = '',
    this.fontSize = 15,
  });

  /// Rows shown around the strip while hovering. 2 means at most five
  /// items are visible at once.
  final int previewRadius;

  /// Extra height of the minimal window for an item with the detail tag.
  final double detailHeight;

  /// The global key that starts a shortcut, like `ctrl+alt+o`.
  final String prefix;

  /// Keys that differ from [Command.defaultKey]; see [keyFor].
  final Map<Command, String> keys;

  /// Device name of the monitor to show on; empty for the primary one.
  final String display;

  /// Empty for the design's own font.
  final String fontFamily;
  final double fontSize;

  String keyFor(Command c) => keys[c] ?? c.defaultKey;

  /// The command bound to [key], if any.
  Command? commandFor(String key) {
    for (final c in Command.values) {
      if (keyFor(c) == key) return c;
    }
    return null;
  }

  /// Binds [key] to [command]; a command that had it takes the old key.
  OneHitConfig bind(Command command, String key) {
    final next = {for (final c in Command.values) c: keyFor(c)};
    final other = commandFor(key);
    if (other != null && other != command) next[other] = next[command]!;
    next[command] = key;
    next.removeWhere((c, k) => k == c.defaultKey);
    return copyWith(keys: next);
  }

  OneHitConfig copyWith({
    int? previewRadius,
    double? detailHeight,
    String? prefix,
    Map<Command, String>? keys,
    String? display,
    String? fontFamily,
    double? fontSize,
  }) => OneHitConfig(
    previewRadius: previewRadius ?? this.previewRadius,
    detailHeight: detailHeight ?? this.detailHeight,
    prefix: prefix ?? this.prefix,
    keys: keys ?? this.keys,
    display: display ?? this.display,
    fontFamily: fontFamily ?? this.fontFamily,
    fontSize: fontSize ?? this.fontSize,
  );

  Map<String, Object?> toJson() => {
    'previewRadius': previewRadius,
    'detailHeight': detailHeight,
    'prefix': prefix,
    'keys': {for (final c in Command.values) c.name: keyFor(c)},
    'display': display,
    'fontFamily': fontFamily,
    'fontSize': fontSize,
  };

  factory OneHitConfig.fromJson(Map<String, Object?> json) {
    const d = OneHitConfig();
    T pick<T>(String key, T fallback) {
      final v = json[key];
      if (v is T) return v;
      if (fallback is double && v is num) return v.toDouble() as T;
      return fallback;
    }

    final prefix = pick('prefix', d.prefix);
    final keys = <Command, String>{};
    final rawKeys = json['keys'];
    if (rawKeys is Map) {
      for (final c in Command.values) {
        final k = rawKeys[c.name];
        if (k is String && isKeyName(k) && k != c.defaultKey) keys[c] = k;
      }
    }
    return OneHitConfig(
      previewRadius: pick('previewRadius', d.previewRadius).clamp(0, 6),
      detailHeight: pick('detailHeight', d.detailHeight).clamp(60.0, 600.0),
      prefix: Chord.parse(prefix) == null ? d.prefix : prefix,
      keys: keys,
      display: pick('display', d.display),
      fontFamily: pick('fontFamily', d.fontFamily),
      fontSize: pick('fontSize', d.fontSize).clamp(12.0, 20.0),
    );
  }

  static Future<OneHitConfig> load(File file) async {
    try {
      if (await file.exists()) {
        final json = jsonDecode(await file.readAsString()) as Map;
        return OneHitConfig.fromJson(json.cast<String, Object?>());
      }
      await file.parent.create(recursive: true);
      await file.writeAsString(encode(const OneHitConfig()));
    } on Object catch (e) {
      debugPrint('OneHit: using default config: $e');
    }
    return const OneHitConfig();
  }

  static String encode(OneHitConfig c) =>
      const JsonEncoder.withIndent('  ').convert(c);
}

/// The config in effect. Settings replace it; every change is saved.
class ConfigStore extends ValueNotifier<OneHitConfig> {
  ConfigStore(super.value, {required this.onSave});

  final void Function(OneHitConfig config) onSave;

  void update(OneHitConfig next) {
    value = next;
    onSave(next);
  }
}
