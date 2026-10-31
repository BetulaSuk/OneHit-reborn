import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../config.dart';
import '../item/info_item.dart';
import '../item/info_item_view.dart';
import '../item/item_store.dart';
import '../theme/tokens.dart';

/// The always-on-top strip. At rest it shows the pinned item (plus any
/// ended reminders above it). On hover the OS window grows above and below
/// so neighbouring items can fade in around the strip, which itself never
/// moves on screen.
class MiniWindow extends StatefulWidget {
  const MiniWindow({
    super.key,
    required this.store,
    required this.anchor,
    this.config = const OneHitConfig(),
  });

  final ItemStore store;

  /// Screen position (logical px) of the strip's top-left corner.
  final Offset anchor;
  final OneHitConfig config;

  @override
  State<MiniWindow> createState() => _MiniWindowState();
}

class _MiniWindowState extends State<MiniWindow>
    with TickerProviderStateMixin {
  late Offset _anchor = widget.anchor;

  /// Hover wanted; drives the OS window size.
  bool _expanded = false;

  /// Preview rows visible; trails [_expanded] so rows fade instead of pop.
  bool _preview = false;

  bool _dragging = false;
  double _wheel = 0;
  Timer? _leave;
  double _appliedTopExtra = 0;

  /// Bumped on every hover change so a pending expand or collapse can tell
  /// it has gone stale.
  int _hoverGen = 0;

  /// Strip offset and mode for each content height we have asked the OS
  /// for. Layout looks up the window's actual height here, so a frame drawn
  /// before a resize lands still puts the strip where it is on screen.
  final Map<int, ({double top, bool expanded})> _layouts = {};

  /// Scroll position in rows. 0 = pinned item at the strip, -1 and
  /// `visible.length` are the add slots at either end.
  late final AnimationController _scroll = AnimationController.unbounded(
    vsync: this,
  );
  double _target = 0;

  int get _radius => widget.config.previewRadius;

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onStore);
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyBounds());
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStore);
    _leave?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  int _alertCount = 0;

  void _onStore() {
    final n = widget.store.alerts.length;
    if (n != _alertCount) {
      _alertCount = n;
      if (!_expanded) _applyBounds();
    }
    setState(() {});
  }

  double _topExtraFor(bool expanded) => expanded
      ? _radius * OH.rowPitch
      : widget.store.alerts.length * OH.rowPitch;

  double _bottomExtraFor(bool expanded) => expanded ? _radius * OH.rowPitch : 0;

  Future<void> _applyBounds() async {
    final top = _topExtraFor(_expanded);
    final bottom = _bottomExtraFor(_expanded);
    final height = OH.stripHeight + top + bottom;
    _appliedTopExtra = top;
    _layouts[height.round()] = (top: top, expanded: _expanded);
    await windowManager.setBounds(
      Rect.fromLTWH(
        _anchor.dx - OH.margin,
        _anchor.dy - OH.margin - top,
        OH.stripWidth + OH.margin * 2,
        height + OH.margin * 2,
      ),
    );
  }

  // Window drag: a plain drag on the strip moves the window. Long press is
  // reserved for tag dragging. startDragging returns when the OS move loop
  // ends; hover changes are held until then so the window keeps its shape
  // under the cursor.
  Future<void> _startDrag(DragStartDetails _) async {
    if (_dragging) return;
    _dragging = true;
    _leave?.cancel();
    await windowManager.startDragging();
    final b = await windowManager.getBounds();
    _anchor = Offset(b.left + OH.margin, b.top + OH.margin + _appliedTopExtra);
    _dragging = false;
  }

  void _enter() {
    _leave?.cancel();
    final gen = ++_hoverGen;
    if (!_expanded) {
      setState(() => _expanded = true);
      _applyBounds().then((_) {
        if (mounted && gen == _hoverGen) setState(() => _preview = true);
      });
    } else if (!_preview) {
      // Back while the rows were fading out: keep the window open.
      setState(() => _preview = true);
    }
  }

  void _exit() {
    if (_dragging) return;
    _leave?.cancel();
    _leave = Timer(const Duration(milliseconds: 140), () async {
      if (!mounted || _dragging) return;
      final gen = ++_hoverGen;
      setState(() => _preview = false);
      _scrollTo(0);
      await Future<void>.delayed(OH.settle);
      if (!mounted || gen != _hoverGen) return;
      setState(() => _expanded = false);
      _applyBounds();
    });
  }

  void _scrollTo(double target) {
    _target = target;
    _scroll.animateTo(target, duration: OH.settle, curve: Curves.easeOutExpo);
  }

  void _onWheel(PointerSignalEvent e) {
    if (e is! PointerScrollEvent || !_preview) return;
    _wheel += e.scrollDelta.dy;
    if (_wheel.abs() < 40) return;
    final step = _wheel.sign;
    _wheel = 0;
    final n = widget.store.visible.length;
    final next = (_target + step).clamp(-1.0, n.toDouble());
    if (next != _target) _scrollTo(next);
  }

  void _onPointerDown(PointerDownEvent e) {
    if (e.buttons & kMiddleMouseButton != 0) _scrollTo(0);
  }

  void _select(InfoItem item, int index) {
    final offset = index - _scroll.value;
    widget.store.pin(item);
    _scroll.value = -offset;
    _scrollTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return Listener(
      onPointerSignal: _onWheel,
      onPointerDown: _onPointerDown,
      child: Padding(
        // Hover counts over the rows only, not the transparent shadow margin.
        padding: const EdgeInsets.all(OH.margin),
        child: MouseRegion(
          hitTestBehavior: HitTestBehavior.opaque,
          onEnter: (_) => _enter(),
          onExit: (_) => _exit(),
          child: LayoutBuilder(
            builder: (context, c) {
              // Lay out from the window's actual height, not from state, so
              // the strip stays put during the frame where the OS resize lags.
              final layout =
                  _layouts[c.maxHeight.round()] ??
                  (
                    top: math.max(0.0, c.maxHeight - OH.stripHeight),
                    expanded: false,
                  );
              final stripTop = layout.top;

              return Stack(
                clipBehavior: Clip.none,
                children: _expanded && layout.expanded
                    ? _previewRows(store, stripTop)
                    : _restRows(store, stripTop),
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _restRows(ItemStore store, double stripTop) {
    final pinned = store.pinned;
    final alerts = store.alerts;
    return [
      for (var k = 0; k < alerts.length; k++)
        Positioned(
          left: 0,
          top: stripTop - (alerts.length - k) * OH.rowPitch,
          child: GestureDetector(
            onTap: () => store.pin(alerts[k]),
            child: InfoItemView(item: alerts[k], now: store.now),
          ),
        ),
      Positioned(
        left: 0,
        top: stripTop,
        child: GestureDetector(
          onPanStart: _startDrag,
          child: pinned == null
              ? const _AddSlot()
              : InfoItemView(
                  item: pinned,
                  now: store.now,
                  onTimeTap: () => store.toggleTime(pinned),
                ),
        ),
      ),
    ];
  }

  List<Widget> _previewRows(ItemStore store, double stripTop) {
    final items = store.visible;
    return [
      AnimatedBuilder(
        animation: _scroll,
        builder: (context, _) {
          final pos = _scroll.value;
          final rows = <Widget>[];
          for (var i = -1; i <= items.length; i++) {
            final d = (i - pos).abs();
            if (d > _radius + 0.5) continue;
            final atStrip = d < 0.5;
            final fade = atStrip ? 1.0 : _fade(d);
            final item = (i >= 0 && i < items.length) ? items[i] : null;
            final child = item == null
                ? _AddSlot(fade: fade)
                : InfoItemView(
                    item: item,
                    now: store.now,
                    lifted: atStrip,
                    fade: fade,
                    onTimeTap: () => store.toggleTime(item),
                  );
            rows.add(
              Positioned(
                key: ValueKey(item?.id ?? 'add$i'),
                left: 0,
                top: stripTop + (i - pos) * OH.rowPitch,
                child: AnimatedOpacity(
                  opacity: atStrip || _preview ? 1 : 0,
                  duration: OH.quick,
                  child: MouseRegion(
                    cursor: item == null
                        ? MouseCursor.defer
                        : SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: item == null ? null : () => _select(item, i),
                      onPanStart: atStrip ? _startDrag : null,
                      child: child,
                    ),
                  ),
                ),
              ),
            );
          }
          // Nearest rows paint last so the strip sits on top.
          rows.sort((a, b) {
            double dist(Widget w) {
              final p = w as Positioned;
              return ((p.top! - stripTop) / OH.rowPitch).abs();
            }

            return dist(b).compareTo(dist(a));
          });
          return Stack(clipBehavior: Clip.none, children: rows);
        },
      ),
    ];
  }

  /// 1 at the strip, falling to ~0.25 at the preview edge.
  double _fade(double d) =>
      (1 - 0.375 * d).clamp(0.0, 1.0) *
      (d > _radius ? (_radius + 0.5 - d) * 2 : 1);
}

/// Green slot at either end of the list for adding a new item.
class _AddSlot extends StatelessWidget {
  const _AddSlot({this.fade = 1});

  final double fade;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: OH.stripWidth,
      height: OH.stripHeight,
      decoration: ShapeDecoration(
        color: OH.addFill.withValues(alpha: 0.94 + 0.06 * fade),
        shape: const StadiumBorder(
          side: BorderSide(color: OH.addInk, width: 1.5),
        ),
      ),
      alignment: Alignment.center,
      child: Opacity(
        opacity: fade,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded, size: 20, color: OH.addInk),
            const SizedBox(width: OH.unit),
            Text('新建信息', style: OH.itemText.copyWith(color: OH.addInk)),
          ],
        ),
      ),
    );
  }
}
