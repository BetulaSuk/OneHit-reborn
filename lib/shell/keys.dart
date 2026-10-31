import 'package:flutter/services.dart';

/// Key names as config.json spells them ('a', '5', 'f5', 'space', ',' ...)
/// with their Windows virtual-key codes.
final Map<String, int> _codes = {
  for (var c = 0x61; c <= 0x7a; c++) String.fromCharCode(c): c - 0x20,
  for (var c = 0x30; c <= 0x39; c++) String.fromCharCode(c): c,
  for (var n = 1; n <= 12; n++) 'f$n': 0x6f + n,
  'space': 0x20,
  'enter': 0x0d,
  'tab': 0x09,
  'backspace': 0x08,
  'insert': 0x2d,
  'delete': 0x2e,
  'home': 0x24,
  'end': 0x23,
  'pageup': 0x21,
  'pagedown': 0x22,
  'left': 0x25,
  'up': 0x26,
  'right': 0x27,
  'down': 0x28,
  '`': 0xc0,
  '-': 0xbd,
  '=': 0xbb,
  '[': 0xdb,
  ']': 0xdd,
  r'\': 0xdc,
  ';': 0xba,
  "'": 0xde,
  ',': 0xbc,
  '.': 0xbe,
  '/': 0xbf,
};

final Map<int, String> _names = {
  for (final e in _codes.entries) e.value: e.key,
};

bool isKeyName(String name) => _codes.containsKey(name);

/// The name of a virtual-key code, or null for keys OneHit does not bind.
String? keyNameOf(int vk) => _names[vk];

/// The name of a key from a Flutter key event.
String? keyNameOfEvent(LogicalKeyboardKey key) {
  final label = key.keyLabel.toLowerCase();
  final name = switch (label) {
    ' ' => 'space',
    'arrow up' => 'up',
    'arrow down' => 'down',
    'arrow left' => 'left',
    'arrow right' => 'right',
    'page up' => 'pageup',
    'page down' => 'pagedown',
    _ => label,
  };
  return isKeyName(name) ? name : null;
}

/// How a key name is shown: `L`, `F5`, `Space`, `↑`.
String keyLabel(String name) {
  if (name.length == 1) return name.toUpperCase();
  return switch (name) {
    'up' => '↑',
    'down' => '↓',
    'left' => '←',
    'right' => '→',
    'pageup' => 'PgUp',
    'pagedown' => 'PgDn',
    _ => name[0].toUpperCase() + name.substring(1),
  };
}

const _modifiers = {'ctrl': 2, 'alt': 1, 'shift': 4, 'win': 8};
const _modifierLabels = {
  'ctrl': 'Ctrl',
  'alt': 'Alt',
  'shift': 'Shift',
  'win': 'Win',
};

/// A prefix like `ctrl+alt+o`: one or more modifiers and one key.
class Chord {
  const Chord(this.modifiers, this.key);

  /// In `ctrl, alt, shift, win` order.
  final List<String> modifiers;
  final String key;

  static Chord? parse(String spec) {
    final parts = spec.toLowerCase().split('+').map((p) => p.trim()).toList();
    if (parts.length < 2) return null;
    final key = parts.last;
    final mods = parts.sublist(0, parts.length - 1).toSet();
    if (!isKeyName(key) || !mods.every(_modifiers.containsKey)) return null;
    return Chord([
      for (final m in _modifiers.keys)
        if (mods.contains(m)) m,
    ], key);
  }

  /// The chord being pressed now, from a key event and the held modifiers.
  static Chord? pressed(LogicalKeyboardKey key) {
    final name = keyNameOfEvent(key);
    final hw = HardwareKeyboard.instance;
    final mods = [
      if (hw.isControlPressed) 'ctrl',
      if (hw.isAltPressed) 'alt',
      if (hw.isShiftPressed) 'shift',
      if (hw.isMetaPressed) 'win',
    ];
    return name == null || mods.isEmpty ? null : Chord(mods, name);
  }

  /// RegisterHotKey's MOD_* flags.
  int get flags => modifiers.fold(0, (f, m) => f | _modifiers[m]!);

  int get virtualKey => _codes[key]!;

  String get label => [
    for (final m in modifiers) _modifierLabels[m]!,
    keyLabel(key),
  ].join(' + ');

  @override
  String toString() => [...modifiers, key].join('+');
}
