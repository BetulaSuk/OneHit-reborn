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
import '../strings.dart';
import '../theme/controls.dart';
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

  static double get header => 44 * OH.scale;
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

  /// The item's text when its editor opened. The editor saves as it types,
  /// so this is what a cleared field goes back to.
  String _editorBefore = '';

  /// One focus node per row, so closing the editor can hand the keyboard
  /// back to the row it came from.
  final Map<String, FocusNode> _rowFocus = {};

  FocusNode _focusFor(String id) =>
      _rowFocus.putIfAbsent(id, () => FocusNode(debugLabel: 'row $id'));

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
    for (final node in _rowFocus.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _onStore() {
    _rowFocus.removeWhere((id, node) {
      final gone = _store.byId(id) == null;
      if (gone) node.dispose();
      return gone;
    });
    setState(() {});
  }

  Future<void> _openEditor(InfoItem item, {bool focusText = false}) async {
    widget.actions.select(item);
    if (_editorId != item.id) _settleEditor();
    setState(() {
      _editorId = item.id;
      _editorFocus = focusText;
      _editorBefore = item.text;
    });
    await windowManager.focus();
  }

  void _closeEditor() {
    final id = _editorId;
    _settleEditor();
    setState(() => _editorId = null);
    final row = id == null ? null : _rowFocus[id];
    if (row != null && row.context != null) row.requestFocus();
  }

  /// Settles the open editor's item when its text was left empty.
  void _settleEditor() {
    final item = _editorId == null ? null : _store.byId(_editorId!);
    if (item != null && item.text.trim().isEmpty) {
      _store.settleEmptyText(item, _editorBefore);
    }
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
                      strings.allItems,
                      style: OH.itemText.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: OH.unit * 2),
                    Text(
                      '${items.length}',
                      style: OH.itemText.copyWith(color: OH.inkSoft),
                    ),
                    const Spacer(),
                    Tooltip(
                      message: strings.shrink,
                      waitDuration: const Duration(milliseconds: 600),
                      child: InkResponse(
                        onTap: actions.openMini,
                        radius: 18 * OH.scale,
                        child: SizedBox(
                          width: 32 * OH.scale,
                          height: 32 * OH.scale,
                          child: Icon(
                            Icons.close_fullscreen_rounded,
                            size: 18 * OH.scale,
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
                      ? FocusRing(
                          onActivate: _create,
                          child: Semantics(
                            button: true,
                            child: ItemGestures(
                              onTap: _create,
                              child: AddSlot(),
                            ),
                          ),
                        )
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
    // Tab or the arrows reach a row; Enter opens its editor, which holds
    // everything the mouse gestures do.
    return Builder(
      builder: (context) => FocusRing(
        focusNode: _focusFor(item.id),
        onActivate: () => _openEditor(item, focusText: true),
        child: Semantics(
          container: true,
          button: true,
          selected: widget.selectedId == item.id,
          hint: strings.editHint,
          child: ItemGestures(
            onTap: () => actions.select(item),
            onDoubleTap: () => _openEditor(item),
            onSecondaryTap: () => _openEditor(item, focusText: true),
            onLongPressStart: (p) =>
                actions.tagDragStart(item, globalRect(context), p),
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
