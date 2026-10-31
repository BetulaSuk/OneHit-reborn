import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:window_manager/window_manager.dart';

import '../config.dart';
import '../item/icon_image.dart';
import '../item/info_item.dart';
import '../item/info_item_view.dart';
import '../item/item_store.dart';
import '../item/storage.dart';
import '../list_window/list_window.dart';
import '../mini_window/mini_window.dart';
import '../plugin.dart';
import '../tags/tag_layer.dart';
import '../tags/time_dial.dart';
import '../theme/tokens.dart';
import 'beside.dart';
import 'hotkeys.dart';
import 'native.dart';
import 'regions.dart';
import 'shell_actions.dart';

/// Owns the screen. The OS window covers the work area; this widget draws
/// the minimal window or the list at the saved position, and the overlays
/// that belong outside them: tag zones while dragging, and the time dial.
/// It also routes drops, pastes and hotkeys to the right item.
class OneHitShell extends StatefulWidget {
  const OneHitShell({
    super.key,
    required this.store,
    required this.config,
    required this.storage,
    required this.native,
    required this.zones,
    required this.anchor,
  });

  final ItemStore store;
  final OneHitConfig config;
  final Storage storage;
  final NativeBridge native;
  final List<TagZone> zones;

  /// Strip position in window-local logical px.
  final Offset anchor;

  @override
  State<OneHitShell> createState() => _OneHitShellState();
}

class _TagDrag {
  _TagDrag(this.item, this.origin, this.grab, this.pointer, this.zones);

  final InfoItem item;
  final Rect origin;
  final Offset grab;
  Offset pointer;
  final List<(TagZone, Rect)> zones;
  String? hovered;
  bool returning = false;
}

class _OneHitShellState extends State<OneHitShell> implements ShellActions {
  late final RegionRegistry _regions = RegionRegistry(widget.native);
  late Offset _anchor = widget.anchor;
  bool _list = false;
  String? _selectedId;
  String? _dropTarget;
  _TagDrag? _drag;
  InfoItem? _dial;

  ItemStore get _store => widget.store;
  Size get _work => MediaQuery.sizeOf(context);

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStore);
    widget.native
      ..onDragOver = _dragOver
      ..onDragLeave = (() => setState(() => _dropTarget = null))
      ..onDrop = _drop;
    registerHotkeys({
      widget.config.toggleHotkey: _toggleWindow,
      widget.config.listHotkey: _toggleList,
    });
  }

  @override
  void dispose() {
    _store.removeListener(_onStore);
    super.dispose();
  }

  void _onStore() {
    if (_selectedId != null && _store.byId(_selectedId!) == null) {
      _selectedId = null;
    }
    final dial = _dial;
    if (dial != null && _store.byId(dial.id) == null) _dial = null;
    setState(() {});
  }

  // Geometry --------------------------------------------------------------

  Rect get _stripRect => _anchor & const Size(OH.stripWidth, OH.stripHeight);

  /// The list opens so that its first row lands where the strip was.
  Rect get _listRect {
    final work = _work;
    final size = Size(
      ListWindow.width,
      math.min(ListWindow.heightFor(_store.all.length), work.height / 2),
    );
    final want =
        _anchor - const Offset(ListWindow.pad, ListWindow.header + OH.unit);
    return _keepOn(want, size) & size;
  }

  Rect get _windowRect => _list ? _listRect : _stripRect;

  Offset _keepOn(Offset at, Size size) {
    const edge = OH.unit * 2;
    final work = _work;
    return Offset(
      at.dx.clamp(edge, math.max(edge, work.width - size.width - edge)),
      at.dy.clamp(edge, math.max(edge, work.height - size.height - edge)),
    );
  }

  // ShellActions ------------------------------------------------------------

  @override
  void moveBy(Offset delta) {
    setState(() {
      if (_list) {
        // Move the list as a whole, then derive the anchor back from it.
        final rect = _listRect;
        final moved = _keepOn(rect.topLeft + delta, rect.size);
        _anchor += moved - rect.topLeft;
      } else {
        _anchor = _keepOn(
          _anchor + delta,
          const Size(OH.stripWidth, OH.stripHeight),
        );
      }
    });
  }

  @override
  void moveDone() => widget.storage.saveAnchor(_anchor);

  @override
  void openList() => setState(() => _list = true);

  @override
  void openMini() => setState(() => _list = false);

  @override
  void select(InfoItem item) => setState(() => _selectedId = item.id);

  @override
  void holdFull() => _regions.holdFull();

  @override
  void releaseFull() => _regions.releaseFull();

  @override
  void tagDragStart(InfoItem item, Rect row, Offset pointer) {
    if (_drag != null) return;
    final zones = [...widget.zones];
    holdFull();
    setState(() {
      _drag = _TagDrag(
        item,
        row,
        pointer - row.topLeft,
        pointer,
        layoutZones(zones, _windowRect, _work),
      );
    });
  }

  @override
  void tagDragMove(Offset pointer) {
    final drag = _drag;
    if (drag == null || drag.returning) return;
    setState(() {
      drag.pointer = pointer;
      drag.hovered = null;
      for (final (zone, rect) in drag.zones) {
        if (rect.inflate(OH.unit * 2).contains(pointer)) drag.hovered = zone.id;
      }
    });
  }

  @override
  void tagDragEnd(Offset pointer) {
    final drag = _drag;
    if (drag == null || drag.returning) return;
    tagDragMove(pointer);
    final hit = drag.zones.where((z) => z.$1.id == drag.hovered).firstOrNull;
    setState(() => drag.returning = true);
    if (hit != null) {
      hit.$1.onDrop(
        TagDropContext(
          store: _store,
          item: drag.item,
          openTimeDial: () => openTimeDial(drag.item),
        ),
      );
    }
    Timer(OH.settle, () {
      if (!mounted || _drag != drag) return;
      setState(() => _drag = null);
      releaseFull();
    });
  }

  @override
  Future<void> openTimeDial(InfoItem item) async {
    setState(() => _dial = item);
    await windowManager.focus();
  }

  void _closeDial() => setState(() => _dial = null);

  // Hotkeys -----------------------------------------------------------------

  Future<void> _toggleWindow() async {
    // The window sits on top without focus most of the time, so visibility
    // alone decides.
    if (await windowManager.isVisible()) {
      await windowManager.hide();
    } else {
      await windowManager.show();
      await windowManager.focus();
    }
  }

  Future<void> _toggleList() async {
    final visible = await windowManager.isVisible();
    setState(() => _list = !visible || !_list);
    await windowManager.show();
    await windowManager.focus();
  }

  // Drops and paste ---------------------------------------------------------

  /// The item under [p], or the item the current window stands for.
  InfoItem? _itemAt(Offset p) {
    final result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(result, p, View.of(context).viewId);
    for (final entry in result.path) {
      final target = entry.target;
      if (target is RenderMetaData && target.metaData is ItemTag) {
        return _store.byId((target.metaData as ItemTag).id);
      }
    }
    return _target;
  }

  InfoItem? get _target => _list
      ? (_selectedId == null ? null : _store.byId(_selectedId!))
      : _store.pinned;

  void _dragOver(Offset p) {
    final id = _itemAt(p)?.id;
    if (id != _dropTarget) setState(() => _dropTarget = id);
  }

  Future<void> _drop(DropData data) async {
    final item = _itemAt(data.position);
    setState(() => _dropTarget = null);
    if (item == null) return;
    for (final f in data.files) {
      if (!looksLikeImagePath(f)) continue;
      final png = await iconFromFile(f);
      if (png != null) return _store.setImage(item, png);
    }
    final url = httpUrl(data.url) ?? httpUrl(data.text);
    if (url != null) {
      final png = await iconFromUrl(url);
      if (png != null) return _store.setImage(item, png);
    }
    if (data.files.isEmpty) _store.appendText(item, data.text);
  }

  Future<void> _paste() async {
    var item = _target;
    final image = await Pasteboard.image;
    if (image != null) {
      final png = await makeIcon(image);
      if (png != null && item != null) return _store.setImage(item, png);
    }
    for (final f in await Pasteboard.files()) {
      if (!looksLikeImagePath(f) || item == null) continue;
      final png = await iconFromFile(f);
      if (png != null) return _store.setImage(item, png);
    }
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    if (text == null || text.trim().isEmpty) return;
    item ??= _store.create();
    _store.appendText(item, text);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    // Text fields handle their own keys.
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused?.findAncestorWidgetOfExactType<EditableText>() != null) {
      return KeyEventResult.ignored;
    }
    final ctrl = HardwareKeyboard.instance.isControlPressed;
    if (ctrl && e.logicalKey == LogicalKeyboardKey.keyV) {
      _paste();
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.escape && _list && _dial == null) {
      openMini();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // Build -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final drag = _drag;
    final dial = _dial;
    final dim = drag != null && !drag.returning;
    return RegionScope(
      registry: _regions,
      child: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedOpacity(
                opacity: dim ? 0.4 : 1,
                duration: OH.quick,
                child: _list
                    ? ListWindow(
                        store: _store,
                        rect: _listRect,
                        actions: this,
                        selectedId: _selectedId,
                        dropTarget: _dropTarget,
                      )
                    : MiniWindow(
                        store: _store,
                        anchor: _anchor,
                        actions: this,
                        config: widget.config,
                        dropTarget: _dropTarget,
                        frozen: drag != null || dial != null,
                      ),
              ),
            ),
            if (drag != null)
              Positioned.fill(
                child: TagLayer(
                  zones: drag.zones,
                  item: drag.item,
                  now: _store.now,
                  origin: drag.origin,
                  ghostAt: drag.pointer - drag.grab,
                  hovered: drag.hovered,
                  returning: drag.returning,
                ),
              ),
            if (dial != null)
              Positioned.fill(
                child: CustomSingleChildLayout(
                  delegate: BesideDelegate(target: _windowRect),
                  child: HitRegion(
                    radius: OH.unit * 6,
                    child: TimeDial(
                      key: ValueKey(dial.id),
                      item: dial,
                      now: _store.now,
                      onCancel: _closeDial,
                      onRemove: dial.time == null
                          ? null
                          : () {
                              _store.clearTime(dial);
                              _closeDial();
                            },
                      onConfirm: (remaining, kind) {
                        _store.setTime(dial, remaining, kind);
                        _closeDial();
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
