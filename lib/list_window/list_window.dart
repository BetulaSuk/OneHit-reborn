import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../editor/side_editor.dart';
import '../item/info_item.dart';
import '../item/info_item_view.dart';
import '../item/item_cards.dart';
import '../item/item_gestures.dart';
import '../item/item_store.dart';
import '../shell/beside.dart';
import '../shell/regions.dart';
import '../shell/shell_actions.dart';
import '../theme/tokens.dart';

/// The detailed window: every item, floating ones first and sunk ones
/// dimmed after them. Fills the shell's screen-sized stack and draws itself
/// at [rect], with the side editor beside it.
class ListWindow extends StatefulWidget {
  const ListWindow({
    super.key,
    required this.store,
    required this.rect,
    required this.actions,
    this.selectedId,
    this.dropTarget,
  });

  static const double header = 44;
  static const double pad = OH.unit * 3;

  /// Card height for [count] items plus the add slot, before capping.
  static double heightFor(int count) =>
      header + OH.unit + (count + 1) * OH.rowPitch + pad;

  static double get width => OH.stripWidth + pad * 2;

  final ItemStore store;
  final Rect rect;
  final ShellActions actions;
  final String? selectedId;
  final String? dropTarget;

  @override
  State<ListWindow> createState() => _ListWindowState();
}

class _ListWindowState extends State<ListWindow> {
  final _scroll = ScrollController();

  /// Item whose side editor is open, and whether to focus its text.
  String? _editorId;
  bool _editorFocus = false;

  ItemStore get _store => widget.store;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStore);
  }

  @override
  void dispose() {
    _store.removeListener(_onStore);
    _scroll.dispose();
    super.dispose();
  }

  void _onStore() => setState(() {});

  Future<void> _openEditor(InfoItem item, {bool focusText = false}) async {
    widget.actions.select(item);
    setState(() {
      _editorId = item.id;
      _editorFocus = focusText;
    });
    await windowManager.focus();
  }

  void _closeEditor() {
    final item = _editorId == null ? null : _store.byId(_editorId!);
    setState(() => _editorId = null);
    if (item != null && item.text.trim().isEmpty) _store.remove(item);
  }

  void _create() {
    final item = _store.create();
    _scroll.animateTo(0, duration: OH.settle, curve: Curves.easeOutExpo);
    _openEditor(item, focusText: true);
  }

  void _onPointerDown(PointerDownEvent e) {
    if (e.buttons & kMiddleMouseButton != 0 && _scroll.hasClients) {
      _scroll.animateTo(0, duration: OH.settle, curve: Curves.easeOutExpo);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rect = widget.rect;
    final items = _store.all;
    return Stack(
      children: [
        Positioned.fromRect(
          rect: rect,
          child: HitRegion(radius: OH.unit * 5, child: _card(items)),
        ),
        if (_editorId != null) _editorLayer(items),
      ],
    );
  }

  Widget _card(List<InfoItem> items) {
    final actions = widget.actions;
    return Container(
      decoration: const ShapeDecoration(
        color: OH.ground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(OH.unit * 5)),
        ),
        shadows: OH.lift,
      ),
      child: Column(
        children: [
          ItemGestures(
            onDoubleTap: actions.openMini,
            onPanStart: actions.holdFull,
            onPanUpdate: actions.moveBy,
            onPanEnd: () {
              actions.releaseFull();
              actions.moveDone();
            },
            child: SizedBox(
              height: ListWindow.header,
              child: Padding(
                padding: const EdgeInsets.only(left: OH.unit * 5, right: 6),
                child: Row(
                  children: [
                    Text(
                      '全部信息',
                      style: OH.itemText.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: OH.unit * 2),
                    Text(
                      '${items.length}',
                      style: OH.itemText.copyWith(color: OH.inkSoft),
                    ),
                    const Spacer(),
                    Tooltip(
                      message: '缩回浮窗（双击标题栏）',
                      waitDuration: const Duration(milliseconds: 600),
                      child: InkResponse(
                        onTap: actions.openMini,
                        radius: 18,
                        child: const SizedBox(
                          width: 32,
                          height: 32,
                          child: Icon(
                            Icons.close_fullscreen_rounded,
                            size: 18,
                            color: OH.ink,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Listener(
              onPointerDown: _onPointerDown,
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(
                  ListWindow.pad,
                  OH.unit,
                  ListWindow.pad,
                  ListWindow.pad,
                ),
                itemExtent: OH.rowPitch,
                itemCount: items.length + 1,
                itemBuilder: (context, i) => Align(
                  alignment: Alignment.topCenter,
                  child: i == items.length
                      ? ItemGestures(onTap: _create, child: const AddSlot())
                      : _row(items[i]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(InfoItem item) {
    final actions = widget.actions;
    final ring = widget.dropTarget == item.id
        ? OH.ink
        : (widget.selectedId == item.id ? OH.inkSoft : null);
    return Builder(
      builder: (context) => ItemGestures(
        onTap: () => actions.select(item),
        onDoubleTap: () => _openEditor(item),
        onSecondaryTap: () => _openEditor(item, focusText: true),
        onLongPressStart: (p) =>
            actions.tagDragStart(item, globalRect(context), p),
        onLongPressMove: actions.tagDragMove,
        onLongPressEnd: actions.tagDragEnd,
        child: AnimatedOpacity(
          opacity: item.sunk ? 0.45 : 1,
          duration: OH.quick,
          child: InfoItemView(
            item: item,
            now: _store.now,
            lifted: false,
            ring: ring,
            onTimeTap: item.sunk ? null : () => _store.toggleTime(item),
          ),
        ),
      ),
    );
  }

  /// The editor follows its row while the list scrolls and closes for good
  /// once the row scrolls out of view.
  Widget _editorLayer(List<InfoItem> items) {
    final index = items.indexWhere((i) => i.id == _editorId);
    if (index < 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _editorId = null);
      });
      return const SizedBox.shrink();
    }
    final item = items[index];
    final rect = widget.rect;
    final bodyTop = rect.top + ListWindow.header;
    return AnimatedBuilder(
      animation: _scroll,
      builder: (context, _) {
        final offset = _scroll.hasClients ? _scroll.offset : 0.0;
        final rowTop = bodyTop + OH.unit + index * OH.rowPitch - offset;
        final rowMid = rowTop + OH.stripHeight / 2;
        if (rowMid < bodyTop || rowMid > rect.bottom - ListWindow.pad / 2) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _editorId == item.id) _closeEditor();
          });
        }
        return CustomSingleChildLayout(
          delegate: BesideDelegate(target: rect, top: rowTop - OH.unit * 2),
          child: HitRegion(
            radius: OH.unit * 5,
            child: SideEditor(
              key: ValueKey(item.id),
              item: item,
              store: _store,
              focusText: _editorFocus,
              onClose: _closeEditor,
              onTimeDial: () => widget.actions.openTimeDial(item),
            ),
          ),
        );
      },
    );
  }
}
