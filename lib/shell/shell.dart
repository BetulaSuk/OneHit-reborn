import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
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
import '../settings/about_panel.dart';
import '../settings/settings_panel.dart';
import '../tags/tag_layer.dart';
import '../tags/time_dial.dart';
import '../theme/tokens.dart';
import 'beside.dart';
import 'keys.dart';
import 'native.dart';
import 'prefix_hint.dart';
import 'regions.dart';
import 'shell_actions.dart';

/// Owns the screen. The OS window covers the work area; this widget draws
/// the minimal window or the list at the saved position, and the overlays
/// that belong outside them: tag zones while dragging, the time dial, the
/// settings and about panels. It also routes drops, pastes, the tray icon
/// and prefix shortcuts.
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
  final ConfigStore config;
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

enum _Panel { settings, about }

class _OneHitShellState extends State<OneHitShell> implements ShellActions {
  late final RegionRegistry _regions = RegionRegistry(widget.native);
  late Offset _anchor = widget.anchor;
  bool _list = false;
  String? _selectedId;
  String? _dropTarget;
  _TagDrag? _drag;
  bool _following = false;
  InfoItem? _dial;
  _Panel? _panel;
  final _mini = GlobalKey<MiniWindowState>();

  bool _shown = true;

  /// The prefix was pressed and the next key is awaited.
  bool _prefix = false;

  /// False when another app holds the prefix combination.
  bool _prefixFree = true;

  /// The settings panel is recording a new prefix.
  bool _recordingPrefix = false;

  late OneHitConfig _config = widget.config.value;

  ItemStore get _store => widget.store;
  Size get _work => MediaQuery.sizeOf(context);

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStore);
    widget.native
      ..onDragOver = _dragOver
      ..onDragLeave = (() => setState(() => _dropTarget = null))
      ..onDrop = _drop
      ..onTrayClick = _focusMini
      ..onTrayMenu = _onTrayMenu
      ..onPrefix = (() => setState(() => _prefix = true))
      ..onPrefixKey = _onPrefixKey
      ..onPrefixEnd = (() => setState(() => _prefix = false));
    widget.config.addListener(_onConfig);
    _registerPrefix();
    _updateTray();
  }

  @override
  void dispose() {
    _store.removeListener(_onStore);
    widget.config.removeListener(_onConfig);
    if (_following) _stopFollowing();
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

  void _onConfig() {
    final old = _config;
    final c = _config = widget.config.value;
    applyFont(c);
    if (c.prefix != old.prefix) _registerPrefix();
    if (c.display != old.display) _moveTo(c.display);
    setState(() {});
  }

  /// Moves the window to another display, keeping the strip at the same
  /// relative spot.
  Future<void> _moveTo(String display) async {
    final from = _work;
    final placed = await widget.native.placeOn(display);
    if (placed == null || !mounted) return;
    final to = placed.$2;
    const edge = OH.unit * 2;
    setState(() {
      _anchor = Offset(
        (_anchor.dx / from.width * to.width).clamp(
          edge,
          math.max(edge, to.width - OH.stripWidth - edge),
        ),
        (_anchor.dy / from.height * to.height).clamp(
          edge,
          math.max(edge, to.height - OH.stripHeight - edge),
        ),
      );
    });
    widget.storage.saveAnchor(_anchor);
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
    _following = true;
    GestureBinding.instance.pointerRouter.addGlobalRoute(_followDrag);
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

  /// The drag follows raw pointer events rather than the row's gesture
  /// detector: the row that started it can be rebuilt away (the minimal
  /// window collapses its preview when a drag begins), and its detector
  /// would never report the release.
  void _followDrag(PointerEvent e) {
    if (e is PointerMoveEvent) {
      _dragMove(e.position);
    } else if (e is PointerUpEvent || e is PointerCancelEvent) {
      _stopFollowing();
      _dragEnd(e.position, drop: e is PointerUpEvent);
    }
  }

  void _stopFollowing() {
    _following = false;
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_followDrag);
  }

  void _dragMove(Offset pointer) {
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

  void _dragEnd(Offset pointer, {required bool drop}) {
    final drag = _drag;
    if (drag == null || drag.returning) return;
    _dragMove(pointer);
    final hit = drop
        ? drag.zones.where((z) => z.$1.id == drag.hovered).firstOrNull
        : null;
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

  // Showing, the tray and the prefix ------------------------------------------

  Future<void> _setShown(bool show) async {
    if (show) {
      await windowManager.show();
      await windowManager.focus();
    } else {
      await windowManager.hide();
    }
    setState(() => _shown = show);
    _updateTray();
  }

  // The window sits on top without focus most of the time, so visibility
  // alone decides.
  Future<void> _toggleWindow() async =>
      _setShown(!await windowManager.isVisible());

  Future<void> _toggleList() async {
    final visible = await windowManager.isVisible();
    setState(() => _list = !visible || !_list);
    await _setShown(true);
  }

  /// Tray click: bring back the minimal window and give it the keyboard.
  Future<void> _focusMini() async {
    setState(() => _list = false);
    await _setShown(true);
  }

  void _updateTray() => widget.native.setTray('OneHit', [
    ('settings', '设置…'),
    ('about', '关于 OneHit'),
    null,
    ('toggle', _shown ? '隐藏浮窗' : '显示浮窗'),
    null,
    ('quit', '退出'),
  ]);

  void _onTrayMenu(String id) {
    switch (id) {
      case 'settings':
        _openPanel(_Panel.settings);
      case 'about':
        _openPanel(_Panel.about);
      case 'toggle':
        _setShown(!_shown);
      case 'quit':
        _quit();
    }
  }

  Future<void> _quit() async {
    await widget.storage.flush(_store);
    await windowManager.destroy();
  }

  Future<void> _openPanel(_Panel panel) async {
    setState(() => _panel = panel);
    await _setShown(true);
  }

  void _closePanel() => setState(() => _panel = null);

  Future<void> _registerPrefix() async {
    final chord = Chord.parse(_config.prefix);
    final free = _recordingPrefix || chord == null
        ? await widget.native.setPrefix(null, null)
        : await widget.native.setPrefix(chord.flags, chord.virtualKey);
    if (mounted && !_recordingPrefix) setState(() => _prefixFree = free);
  }

  void _recordPrefix(bool recording) {
    _recordingPrefix = recording;
    _registerPrefix();
  }

  void _onPrefixKey(int vk) {
    setState(() => _prefix = false);
    final name = keyNameOf(vk);
    final command = name == null ? null : _config.commandFor(name);
    if (command != null) _run(command);
  }

  Future<void> _run(Command command) async {
    final pinned = _store.pinned;
    switch (command) {
      case Command.toggle:
        await _toggleWindow();
      case Command.list:
        await _toggleList();
      case Command.create:
        await _editInMini(_store.create());
      case Command.edit:
        if (pinned != null) await _editInMini(pinned);
      case Command.paste:
        await _pasteNew();
      case Command.time:
        if (pinned == null) return;
        await _focusMini();
        await openTimeDial(pinned);
      case Command.pause:
        if (pinned?.time != null) _store.toggleTime(pinned!);
      case Command.next:
        _store.rotate();
      case Command.previous:
        _store.rotate(back: true);
      case Command.settings:
        await _openPanel(_Panel.settings);
    }
  }

  Future<void> _editInMini(InfoItem item) async {
    await _focusMini();
    // The minimal window may only be built in the next frame.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _mini.currentState?.edit(item),
    );
  }

  /// The clipboard as a new item: its text, or its image with the editor
  /// open for a caption.
  Future<void> _pasteNew() async {
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
    Uint8List? png;
    if (text.trim().isEmpty) {
      final image = await Pasteboard.image;
      if (image != null) png = await makeIcon(image);
      if (png == null) return;
    }
    final item = _store.create();
    if (png != null) {
      _store.setImage(item, png);
      return _editInMini(item);
    }
    _store.appendText(item, text);
    await _focusMini();
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
    if (e.logicalKey == LogicalKeyboardKey.escape && _dial == null) {
      if (_panel != null) {
        _closePanel();
        return KeyEventResult.handled;
      }
      if (_list) {
        openMini();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  // Build -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final drag = _drag;
    final dial = _dial;
    final panel = _panel;
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
                        key: _mini,
                        store: _store,
                        anchor: _anchor,
                        actions: this,
                        config: _config,
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
            if (panel != null)
              Positioned.fill(
                child: CustomSingleChildLayout(
                  delegate: BesideDelegate(target: _windowRect),
                  child: HitRegion(
                    radius: OH.unit * 5,
                    child: switch (panel) {
                      _Panel.settings => SettingsPanel(
                        config: widget.config,
                        native: widget.native,
                        store: _store,
                        prefixFree: _prefixFree,
                        onRecordPrefix: _recordPrefix,
                        onClose: _closePanel,
                      ),
                      _Panel.about => AboutPanel(
                        dataDir: widget.storage.dir.path,
                        prefix: Chord.parse(_config.prefix)!.label,
                        settingsKey: keyLabel(_config.keyFor(Command.settings)),
                        onClose: _closePanel,
                      ),
                    },
                  ),
                ),
              ),
            // In the region too: the window is clipped to it, so outside it
            // the hint would not show.
            if (_prefix && _shown && panel == null)
              Positioned.fill(
                child: CustomSingleChildLayout(
                  delegate: BesideDelegate(target: _windowRect),
                  child: HitRegion(
                    radius: OH.unit * 5,
                    child: PrefixHint(config: _config),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Points the text tokens at the configured font.
void applyFont(OneHitConfig c) {
  OH.userFace = c.fontFamily.isEmpty ? OH.face : c.fontFamily;
  OH.userSize = c.fontSize;
}
