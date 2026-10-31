import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'native.dart';

/// The OS window covers the whole work area but only the parts wrapped in
/// [HitRegion] take the mouse; clicks anywhere else fall through to the
/// desktop. After every frame the registry collects the current rects and
/// sends them to the native side when they changed.
class RegionRegistry {
  RegionRegistry(this._native) {
    SchedulerBinding.instance.addPersistentFrameCallback((_) => _sync());
  }

  final NativeBridge _native;
  final Set<RenderHitRegion> _boxes = {};
  // Never equal to a real region, so the first frame always sends.
  List<RRect>? _sent = [RRect.zero];
  int _fullHolds = 0;

  /// While held, the whole window takes the mouse: for drags that may leave
  /// every region, and for drop zones laid out around the window.
  void holdFull() {
    _fullHolds++;
    _schedule();
  }

  void releaseFull() {
    if (_fullHolds > 0) _fullHolds--;
    _schedule();
  }

  void _schedule() => SchedulerBinding.instance.scheduleFrame();

  void _sync() {
    final List<RRect>? next;
    if (_fullHolds > 0) {
      next = null;
    } else {
      next = [
        for (final b in _boxes)
          if (b.attached && b.hasSize) b.globalRRect(),
      ];
    }
    if (_same(next, _sent)) return;
    _sent = next;
    _native.setRegion(next);
  }

  static bool _same(List<RRect>? a, List<RRect>? b) {
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class RegionScope extends InheritedWidget {
  const RegionScope({super.key, required this.registry, required super.child});

  final RegionRegistry registry;

  static RegionRegistry? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RegionScope>()?.registry;

  @override
  bool updateShouldNotify(RegionScope old) => old.registry != registry;
}

/// Marks its child's box (grown by [inflate], for shadows) as part of the
/// window that takes the mouse.
class HitRegion extends SingleChildRenderObjectWidget {
  const HitRegion({
    super.key,
    this.inflate = shadow,
    this.radius = 0,
    super.child,
  });

  /// Room for [OH.lift]: the shadow falls 8px down with a 24px blur.
  static const EdgeInsets shadow = EdgeInsets.fromLTRB(16, 12, 16, 28);

  final EdgeInsets inflate;
  final double radius;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderHitRegion(RegionScope.maybeOf(context), inflate, radius);

  @override
  void updateRenderObject(BuildContext context, RenderHitRegion renderObject) {
    renderObject
      ..registry = RegionScope.maybeOf(context)
      ..inflate = inflate
      ..radius = radius;
  }
}

class RenderHitRegion extends RenderProxyBox {
  RenderHitRegion(this._registry, this.inflate, this.radius);

  RegionRegistry? _registry;
  EdgeInsets inflate;
  double radius;

  set registry(RegionRegistry? value) {
    if (value == _registry) return;
    _registry?._boxes.remove(this);
    _registry = value;
    if (attached) _registry?._boxes.add(this);
  }

  RRect globalRRect() {
    final origin = localToGlobal(Offset.zero);
    final rect = inflate.inflateRect(origin & size);
    return RRect.fromRectAndRadius(
      rect,
      Radius.circular(radius == 0 ? 0 : radius + inflate.left),
    );
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _registry?._boxes.add(this);
  }

  @override
  void detach() {
    _registry?._boxes.remove(this);
    _registry?._schedule();
    super.detach();
  }
}
