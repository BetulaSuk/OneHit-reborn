import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// What was dropped on the window from another app.
class DropData {
  const DropData({
    required this.position,
    this.files = const [],
    this.url = '',
    this.text = '',
  });

  final Offset position;
  final List<String> files;
  final String url;
  final String text;
}

/// A monitor, as `displays` reports it.
class DisplayInfo {
  const DisplayInfo({
    required this.id,
    required this.name,
    required this.primary,
    required this.left,
    required this.width,
    required this.height,
    required this.scale,
  });

  /// Device name like `\\.\DISPLAY2`.
  final String id;

  /// The monitor's model, when Windows knows it.
  final String name;
  final bool primary;

  /// Physical pixels.
  final int left;
  final int width;
  final int height;
  final double scale;

  /// The number Windows gives it, from the device name.
  String get number => RegExp(r'\d+$').firstMatch(id)?.group(0) ?? '';
}

/// A font family: [family] for text styles, [name] to show.
typedef FontName = ({String family, String name});

/// Dart side of `windows/runner/native_bridge.cpp`: the window's click
/// region, the OLE drop target, the tray icon, the prefix key, monitors,
/// fonts and launching at sign-in.
class NativeBridge {
  NativeBridge() {
    _channel.setMethodCallHandler(_handle);
  }

  static const _channel = MethodChannel('onehit/native');

  void Function(Offset position)? onDragOver;
  VoidCallback? onDragLeave;
  void Function(DropData data)? onDrop;
  VoidCallback? onTrayClick;
  void Function(String id)? onTrayMenu;

  /// The prefix was pressed; the next key follows as [onPrefixKey] (a
  /// virtual-key code), or [onPrefixEnd] when none came in time.
  VoidCallback? onPrefix;
  void Function(int vk)? onPrefixKey;
  VoidCallback? onPrefixEnd;

  /// Only these rounded rects (window-local logical px) take clicks; the
  /// rest of the window is see-through for the mouse. Null takes clicks
  /// everywhere; an empty list nowhere.
  Future<void> setRegion(List<RRect>? rects) async {
    try {
      if (rects == null) {
        await _channel.invokeMethod('setRegion');
        return;
      }
      await _channel.invokeMethod('setRegion', [
        for (final r in rects) [r.left, r.top, r.right, r.bottom, r.tlRadiusX],
      ]);
    } on MissingPluginException {
      // Tests and non-Windows hosts have no native side.
    }
  }

  /// Shows or updates the notification-area icon. A null entry in [items]
  /// is a separator.
  Future<void> setTray(String tip, List<(String, String)?> items) =>
      _call<void>('setTray', {
        'tip': tip,
        'items': [
          for (final i in items) i == null ? ['', ''] : [i.$1, i.$2],
        ],
      });

  /// Registers the prefix (MOD_* [flags] and a virtual key); null clears
  /// it. False when another app owns the combination.
  Future<bool> setPrefix(int? flags, int? vk) async =>
      await _call<bool>(
        'setPrefix',
        flags == null ? null : {'mods': flags, 'vk': vk},
      ) ??
      true;

  Future<void> endPrefix() => _call<void>('endPrefix');

  Future<List<DisplayInfo>> displays() async => [
    for (final d in await _call<List>('displays') ?? const [])
      DisplayInfo(
        id: d['id'] as String,
        name: d['name'] as String,
        primary: d['primary'] as bool,
        left: d['left'] as int,
        width: d['width'] as int,
        height: d['height'] as int,
        scale: (d['scale'] as num).toDouble(),
      ),
  ]..sort((a, b) => a.left.compareTo(b.left));

  /// Covers the work area of display [id] (the primary one when it is
  /// gone). Returns the display used and its work area in logical px.
  Future<(String, Size)?> placeOn(String id) async {
    final m = await _call<Map>('placeOn', id);
    if (m == null) return null;
    return (
      m['id'] as String,
      Size((m['width'] as num).toDouble(), (m['height'] as num).toDouble()),
    );
  }

  /// Installed font families, without the hidden ones Windows names with a
  /// leading dot.
  Future<List<FontName>> fonts() async => [
    for (final f in await _call<List>('fonts') ?? const [])
      if (!(f[0] as String).startsWith('.'))
        (family: f[0] as String, name: f[1] as String),
  ];

  Future<bool> autostart() async => await _call<bool>('autostart') ?? false;

  Future<void> setAutostart(bool on) => _call<void>('setAutostart', on);

  Future<T?> _call<T>(String method, [Object? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null;
    }
  }

  Future<void> _handle(MethodCall call) async {
    final args = call.arguments;
    Offset at() {
      final m = args as Map;
      return Offset((m['x'] as num).toDouble(), (m['y'] as num).toDouble());
    }

    switch (call.method) {
      case 'dragOver':
        onDragOver?.call(at());
      case 'dragLeave':
        onDragLeave?.call();
      case 'drop':
        final m = args as Map;
        onDrop?.call(
          DropData(
            position: at(),
            files: [for (final f in m['files'] as List? ?? const []) '$f'],
            url: m['url'] as String? ?? '',
            text: m['text'] as String? ?? '',
          ),
        );
      case 'trayClick':
        onTrayClick?.call();
      case 'trayMenu':
        onTrayMenu?.call(args as String);
      case 'prefix':
        onPrefix?.call();
      case 'prefixKey':
        onPrefixKey?.call(args as int);
      case 'prefixEnd':
        onPrefixEnd?.call();
    }
  }
}
