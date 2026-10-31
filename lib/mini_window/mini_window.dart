import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../config.dart';
import '../item/info_item.dart';
import '../item/info_item_view.dart';
import '../item/item_cards.dart';
import '../item/item_gestures.dart';
import '../item/item_store.dart';
import '../shell/regions.dart';
import '../shell/shell_actions.dart';
import '../theme/tokens.dart';

/// The always-on-top strip. At rest it shows the pinned item (plus any
/// ended reminders above it). On hover, neighbouring items fade in above
/// and below the strip, which itself never moves.
///
/// Fills the shell's screen-sized stack and draws itself at [anchor].
class MiniWindow extends StatefulWidget {
  const MiniWindow({
    super.key,
    required this.store,
    required this.anchor,
    required this.actions,
    this.config = const OneHitConfig(),
    this.dropTarget,
    this.frozen = false,
  });

  final ItemStore store;

  /// Window-local position of the strip's top-left corner.
  final Offset anchor;
  final ShellActions actions;
  final OneHitConfig config;

  /// Id of the item an outside drag is hovering.
  final String? dropTarget;

  /// True while an item is being dragged to a tag zone or the dial is open:
  /// hover and scrolling pause.
  final bool frozen;

  /// Where the strip's block starts: at the anchor, raised when the inline
  /// editor or a detail card would run off the bottom of the screen. The
  /// anchor itself stays, so the strip returns once the block shrinks.
  static double topFor(double anchorY, double block, double screenHeight) {
    const edge = OH.unit * 2;
    if (block <= OH.stripHeight) return anchorY;
    return math.max(edge, math.min(anchorY, screenHeight - block - edge));
  }

  @override
  State<MiniWindow> createState() => MiniWindowState();
}

class MiniWindowState extends State<MiniWindow>
    with TickerProviderStateMixin, WindowListener {
  /// Hover wanted: the area grows to hold the preview rows.
  bool _expanded = false;

  /// Preview rows visible; trails [_expanded] so rows fade instead of pop.
  bool _preview = false;

  bool _moving = false;
  double _wheel = 0;
  Timer? _leave;

  /// Bumped on every hover change so a pending expand or collapse can tell
  /// it has gone stale.
  int _hoverGen = 0;

  InfoItem? _editing;
  final _editText = TextEditingController();
  final _editFocus = FocusNode();

  /// Scroll position in rows. 0 = pinned item at the strip, -1 and
  /// `visible.length` are the add slots at either end.
  late final AnimationController _scroll = AnimationController.unbounded(
    vsync: this,
  );
  double _target = 0;

  int get _radius => widget.config.previewRadius;

  ItemStore get _store => widget.store;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStore);
    windowManager.addListener(this);
  }

  @override
  void didUpdateWidget(MiniWindow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.frozen && !oldWidget.frozen) _collapseNow();
  }

  @override
  void dispose() {
    _store.removeListener(_onStore);
    windowManager.removeListener(this);
    _leave?.cancel();
    _scroll.dispose();
    _editText.dispose();
    _editFocus.dispose();
    super.dispose();
  }

  void _onStore() {
    final editing = _editing;
    if (editing != null && _store.byId(editing.id) == null) _editing = null;
    setState(() {});
  }

  @override
  void onWindowBlur() {
    if (_editing != null) _commit();
  }

  // Editing --------------------------------------------------------------

  /// Opens the strip for typing into [item] (pinning it first).
  Future<void> edit(InfoItem item) async {
    if (item != _store.pinned) _store.pin(item);
    _collapseNow();
    setState(() {
      _editing = item;
      _editText.text = item.text;
      _editText.selection = TextSelection.collapsed(offset: item.text.length);
    });
    await windowManager.focus();
    _editFocus.requestFocus();
  }

  void _create() {
    final item = _store.create();
    edit(item);
  }

  void _commit() {
    final item = _editing;
    if (item == null) return;
    final text = _editText.text.trim();
    setState(() => _editing = null);
    if (text.isEmpty) {
      _store.remove(item);
    } else if (text != item.text) {
      _store.setText(item, text);
    }
  }

  void _cancel() {
    final item = _editing;
    if (item == null) return;
    setState(() => _editing = null);
    if (item.text.isEmpty) _store.remove(item);
  }

  // Hover ----------------------------------------------------------------

  bool get _busy => _editing != null || _moving || widget.frozen;

  void _enter() {
    _leave?.cancel();
    if (_busy) return;
    final gen = ++_hoverGen;
    if (!_expanded) {
      setState(() => _expanded = true);
      // One frame with the rows transparent, so they fade in.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && gen == _hoverGen && _expanded) {
          setState(() => _preview = true);
        }
      });
    } else if (!_preview) {
      // Back while the rows were fading out: keep them.
      setState(() => _preview = true);
    }
  }

  void _exit() {
    if (_moving) return;
    _leave?.cancel();
    _leave = Timer(const Duration(milliseconds: 140), () async {
      if (!mounted || _moving) return;
      final gen = ++_hoverGen;
      setState(() => _preview = false);
      _scrollTo(0);
      await Future<void>.delayed(OH.settle);
      if (!mounted || gen != _hoverGen) return;
      setState(() => _expanded = false);
    });
  }

  void _collapseNow() {
    _leave?.cancel();
    _hoverGen++;
    _scroll.value = 0;
    _target = 0;
    if (_expanded || _preview) {
      setState(() {
        _expanded = false;
        _preview = false;
      });
    }
  }

  void _scrollTo(double target) {
    _target = target;
    _scroll.animateTo(target, duration: OH.settle, curve: Curves.easeOutExpo);
  }

  void _onWheel(PointerSignalEvent e) {
    if (e is! PointerScrollEvent || !_preview || _busy) return;
    _wheel += e.scrollDelta.dy;
    if (_wheel.abs() < 40) return;
    // Wheel down always moves the rows up, whichever way the list runs.
    final step = _wheel.sign * (_flipped ? -1 : 1);
    _wheel = 0;
    final n = _store.visible.length;
    final next = (_target + step).clamp(-1.0, n.toDouble());
    if (next != _target) _scrollTo(next);
  }

  void _onPointerDown(PointerDownEvent e) {
    if (e.buttons & kMiddleMouseButton != 0) _scrollTo(0);
  }

  void _select(InfoItem item, int index) {
    final offset = index - _scroll.value;
    if (item != _store.pinned) _store.pin(item);
    widget.actions.select(item);
    _scroll.value = -offset;
    _scrollTo(0);
  }

  // Moving and tag dragging ----------------------------------------------

  void _moveStart() {
    _moving = true;
    _leave?.cancel();
    widget.actions.holdFull();
  }

  void _moveEnd() {
    if (!_moving) return;
    _moving = false;
    widget.actions.releaseFull();
    widget.actions.moveDone();
  }

  /// Gestures for a row; [strip] rows also move the window and open the
  /// list on double click.
  Widget _gestures({
    required InfoItem? item,
    required bool strip,
    required Widget child,
    VoidCallback? onTap,
  }) {
    final actions = widget.actions;
    return Builder(
      builder: (context) => ItemGestures(
        onTap: onTap,
        onDoubleTap: strip ? actions.openList : null,
        onSecondaryTap: item == null ? null : () => edit(item),
        onLongPressStart: item == null
            ? null
            : (p) => actions.tagDragStart(item, globalRect(context), p),
        onPanStart: strip ? _moveStart : null,
        onPanUpdate: strip ? actions.moveBy : null,
        onPanEnd: strip ? _moveEnd : null,
        child: child,
      ),
    );
  }

  // Layout ---------------------------------------------------------------

  Color? _ringFor(InfoItem item) =>
      widget.dropTarget == item.id ? OH.ink : null;

  double get _stripBlock => _blockFor(expanded: _expanded);

  double _blockFor({required bool expanded}) {
    if (_editing != null) return InlineEditor.height;
    final pinned = _store.pinned;
    if (!expanded && pinned != null && pinned.detail) {
      return OH.stripHeight + widget.config.detailHeight;
    }
    return OH.stripHeight;
  }

  // From the resting block, so hovering a raised detail card (which folds
  // it to the strip) leaves the strip where it is.
  double get _top => MiniWindow.topFor(
    widget.anchor.dy,
    _blockFor(expanded: false),
    MediaQuery.sizeOf(context).height,
  );

  /// Rows that fit on screen above and below the strip.
  (int, int) get _room {
    final top = _top;
    final bottom = MediaQuery.sizeOf(context).height - top - OH.stripHeight;
    return (
      math.max(0, top ~/ OH.rowPitch),
      math.max(0, bottom ~/ OH.rowPitch),
    );
  }

  /// Preview rows above and below the strip: [_radius] each way, except
  /// that rows with no room near a screen edge go to the other side.
  (int, int) get _reach {
    final (up, down) = _room;
    final total = 2 * _radius;
    final below = math.min<int>(total - math.min(_radius, up), down);
    return (math.min<int>(total - below, up), below);
  }

  /// Near the bottom edge the list runs upward: the items after the pinned
  /// one stack above the strip instead of off screen below it.
  bool get _flipped {
    final (up, down) = _room;
    return down < _radius && up > down;
  }

  @override
  Widget build(BuildContext context) {
    final alerts = _editing == null ? _store.alerts : const <InfoItem>[];
    // Ended reminders stack above the strip, or below it at the top edge.
    final alertsBelow = alerts.length > _room.$1;
    final alertRows = alerts.length * OH.rowPitch;
    final (up, down) = _reach;
    final double above = _expanded
        ? up * OH.rowPitch
        : (alertsBelow ? 0 : alertRows);
    final double below = _expanded
        ? down * OH.rowPitch
        : (alertsBelow ? alertRows : 0);
    final block = _stripBlock;

    return Stack(
      children: [
        Positioned(
          left: widget.anchor.dx,
          top: _top - above,
          width: OH.stripWidth,
          height: above + block + below,
          child: HitRegion(
            radius: OH.radius,
            child: Listener(
              onPointerSignal: _onWheel,
              onPointerDown: _onPointerDown,
              child: MouseRegion(
                hitTestBehavior: HitTestBehavior.opaque,
                onEnter: (_) => _enter(),
                onExit: (_) => _exit(),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: _expanded
                      ? [_previewRows(above, up, down)]
                      : _restRows(alerts, above, alertsBelow, block),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _restRows(
    List<InfoItem> alerts,
    double stripTop,
    bool alertsBelow,
    double block,
  ) {
    final store = _store;
    final pinned = store.pinned;
    final editing = _editing;

    final Widget strip;
    if (editing != null) {
      strip = InlineEditor(
        item: editing,
        controller: _editText,
        focusNode: _editFocus,
        onCommit: _commit,
        onCancel: _cancel,
      );
    } else if (pinned == null) {
      strip = _gestures(
        item: null,
        strip: true,
        onTap: _create,
        child: AddSlot(),
      );
    } else {
      strip = _gestures(
        item: pinned,
        strip: true,
        child: pinned.detail
            ? DetailCard(
                item: pinned,
                now: store.now,
                height: widget.config.detailHeight,
                onTimeTap: () => store.toggleTime(pinned),
                ring: _ringFor(pinned),
              )
            : InfoItemView(
                item: pinned,
                now: store.now,
                onTimeTap: () => store.toggleTime(pinned),
                ring: _ringFor(pinned),
              ),
      );
    }

    return [
      for (var k = 0; k < alerts.length; k++)
        Positioned(
          left: 0,
          top: alertsBelow
              ? stripTop + block + OH.rowGap + k * OH.rowPitch
              : k * OH.rowPitch,
          child: _gestures(
            item: alerts[k],
            strip: false,
            onTap: () => store.pin(alerts[k]),
            child: InfoItemView(
              item: alerts[k],
              now: store.now,
              ring: _ringFor(alerts[k]),
            ),
          ),
        ),
      Positioned(left: 0, top: stripTop, child: strip),
    ];
  }

  Widget _previewRows(double stripTop, int up, int down) {
    final store = _store;
    final items = store.visible;
    final dir = _flipped ? -1 : 1;
    return AnimatedBuilder(
      animation: _scroll,
      builder: (context, _) {
        final pos = _scroll.value;
        final rows = <(double, Widget)>[];
        for (var i = -1; i <= items.length; i++) {
          // Rows from the strip, negative above it.
          final r = dir * (i - pos);
          final d = r.abs();
          final reach = r < 0 ? up : down;
          if (d > reach + 0.5) continue;
          final atStrip = d < 0.5;
          final fade = atStrip ? 1.0 : _fade(d, reach);
          final item = (i >= 0 && i < items.length) ? items[i] : null;
          final Widget view;
          if (item == null) {
            view = _gestures(
              item: null,
              strip: false,
              onTap: _create,
              child: AddSlot(fade: fade),
            );
          } else {
            view = _gestures(
              item: item,
              strip: atStrip,
              // Includes the row scrolled into the strip's slot: clicking
              // it pins it.
              onTap: () => _select(item, i),
              child: InfoItemView(
                item: item,
                now: store.now,
                lifted: atStrip,
                fade: fade,
                ring: _ringFor(item),
                onTimeTap: () => store.toggleTime(item),
              ),
            );
          }
          rows.add((
            d,
            Positioned(
              key: ValueKey(item?.id ?? 'add$i'),
              left: 0,
              top: stripTop + r * OH.rowPitch,
              child: AnimatedOpacity(
                opacity: atStrip || _preview ? 1 : 0,
                duration: OH.quick,
                child: MouseRegion(
                  cursor: atStrip
                      ? MouseCursor.defer
                      : SystemMouseCursors.click,
                  child: view,
                ),
              ),
            ),
          ));
        }
        // Nearest rows paint last so the strip sits on top.
        rows.sort((a, b) => b.$1.compareTo(a.$1));
        return Stack(
          clipBehavior: Clip.none,
          children: [for (final r in rows) r.$2],
        );
      },
    );
  }

  /// 1 at the strip, falling to ~0.25 at the preview edge [reach] rows
  /// away (slower when one side holds more than two rows).
  double _fade(double d, int reach) {
    if (reach == 0) return 0;
    final step = math.min(0.375, 0.75 / reach);
    return (1 - step * d).clamp(0.0, 1.0) *
        (d > reach ? (reach + 0.5 - d) * 2 : 1);
  }
}
