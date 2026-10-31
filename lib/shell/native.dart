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

/// Dart side of `windows/runner/native_bridge.cpp`: the window's click
/// region and the OLE drop target.
class NativeBridge {
  NativeBridge() {
    _channel.setMethodCallHandler(_handle);
  }

  static const _channel = MethodChannel('onehit/native');

  void Function(Offset position)? onDragOver;
  VoidCallback? onDragLeave;
  void Function(DropData data)? onDrop;

  /// Only these rounded rects (window-local logical px) take clicks; the
  /// rest of the window is see-through for the mouse. Null takes clicks
  /// everywhere.
  Future<void> setRegion(List<RRect>? rects) async {
    try {
      await _channel.invokeMethod('setRegion', [
        for (final r in rects ?? const <RRect>[])
          [r.left, r.top, r.right, r.bottom, r.tlRadiusX],
      ]);
    } on MissingPluginException {
      // Tests and non-Windows hosts have no native side.
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
    }
  }
}
