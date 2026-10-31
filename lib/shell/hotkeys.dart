import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

/// Parses specs like `ctrl+alt+space` or `win+shift+f9`. Returns null for
/// anything it does not understand.
HotKey? parseHotKey(String spec) {
  final parts = spec.toLowerCase().split('+').map((p) => p.trim()).toList();
  if (parts.isEmpty) return null;
  final modifiers = <HotKeyModifier>[];
  for (final p in parts.sublist(0, parts.length - 1)) {
    final m = switch (p) {
      'ctrl' || 'control' => HotKeyModifier.control,
      'alt' => HotKeyModifier.alt,
      'shift' => HotKeyModifier.shift,
      'win' || 'meta' || 'super' => HotKeyModifier.meta,
      _ => null,
    };
    if (m == null) return null;
    modifiers.add(m);
  }
  final key = _key(parts.last);
  if (key == null) return null;
  return HotKey(key: key, modifiers: modifiers, scope: HotKeyScope.system);
}

PhysicalKeyboardKey? _key(String name) {
  const letters = [
    PhysicalKeyboardKey.keyA,
    PhysicalKeyboardKey.keyB,
    PhysicalKeyboardKey.keyC,
    PhysicalKeyboardKey.keyD,
    PhysicalKeyboardKey.keyE,
    PhysicalKeyboardKey.keyF,
    PhysicalKeyboardKey.keyG,
    PhysicalKeyboardKey.keyH,
    PhysicalKeyboardKey.keyI,
    PhysicalKeyboardKey.keyJ,
    PhysicalKeyboardKey.keyK,
    PhysicalKeyboardKey.keyL,
    PhysicalKeyboardKey.keyM,
    PhysicalKeyboardKey.keyN,
    PhysicalKeyboardKey.keyO,
    PhysicalKeyboardKey.keyP,
    PhysicalKeyboardKey.keyQ,
    PhysicalKeyboardKey.keyR,
    PhysicalKeyboardKey.keyS,
    PhysicalKeyboardKey.keyT,
    PhysicalKeyboardKey.keyU,
    PhysicalKeyboardKey.keyV,
    PhysicalKeyboardKey.keyW,
    PhysicalKeyboardKey.keyX,
    PhysicalKeyboardKey.keyY,
    PhysicalKeyboardKey.keyZ,
  ];
  const digits = [
    PhysicalKeyboardKey.digit0,
    PhysicalKeyboardKey.digit1,
    PhysicalKeyboardKey.digit2,
    PhysicalKeyboardKey.digit3,
    PhysicalKeyboardKey.digit4,
    PhysicalKeyboardKey.digit5,
    PhysicalKeyboardKey.digit6,
    PhysicalKeyboardKey.digit7,
    PhysicalKeyboardKey.digit8,
    PhysicalKeyboardKey.digit9,
  ];
  const functions = [
    PhysicalKeyboardKey.f1,
    PhysicalKeyboardKey.f2,
    PhysicalKeyboardKey.f3,
    PhysicalKeyboardKey.f4,
    PhysicalKeyboardKey.f5,
    PhysicalKeyboardKey.f6,
    PhysicalKeyboardKey.f7,
    PhysicalKeyboardKey.f8,
    PhysicalKeyboardKey.f9,
    PhysicalKeyboardKey.f10,
    PhysicalKeyboardKey.f11,
    PhysicalKeyboardKey.f12,
  ];
  if (name.length == 1) {
    final c = name.codeUnitAt(0);
    if (c >= 0x61 && c <= 0x7a) return letters[c - 0x61];
    if (c >= 0x30 && c <= 0x39) return digits[c - 0x30];
  }
  if (name.startsWith('f')) {
    final n = int.tryParse(name.substring(1));
    if (n != null && n >= 1 && n <= 12) return functions[n - 1];
  }
  return switch (name) {
    'space' => PhysicalKeyboardKey.space,
    'enter' => PhysicalKeyboardKey.enter,
    'tab' => PhysicalKeyboardKey.tab,
    'esc' || 'escape' => PhysicalKeyboardKey.escape,
    '`' || 'backquote' => PhysicalKeyboardKey.backquote,
    _ => null,
  };
}

/// Registers system-wide hotkeys; bad specs are logged and skipped. A key
/// already taken by another app fails silently: the Windows plugin ignores
/// RegisterHotKey's result.
Future<void> registerHotkeys(Map<String, VoidCallback> bindings) async {
  await hotKeyManager.unregisterAll();
  for (final MapEntry(key: spec, value: action) in bindings.entries) {
    final hotKey = parseHotKey(spec);
    if (hotKey == null) {
      debugPrint('OneHit: ignoring hotkey "$spec"');
      continue;
    }
    try {
      await hotKeyManager.register(hotKey, keyDownHandler: (_) => action());
    } on Object catch (e) {
      debugPrint('OneHit: could not register "$spec": $e');
    }
  }
}
