import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';
import 'info_item.dart';
import 'info_item_view.dart';

/// An item with the detail tag, pinned: the strip grows downward into a card
/// that shows the whole text and a larger image.
class DetailCard extends StatelessWidget {
  const DetailCard({
    super.key,
    required this.item,
    required this.now,
    required this.height,
    this.onTimeTap,
    this.ring,
  });

  final InfoItem item;
  final DateTime now;

  /// Extra height below the strip, from the config.
  final double height;
  final VoidCallback? onTimeTap;
  final Color? ring;

  @override
  Widget build(BuildContext context) {
    final image = item.image;
    return Container(
      width: OH.stripWidth,
      height: OH.stripHeight + height,
      decoration: const ShapeDecoration(
        color: OH.ground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(OH.radius)),
        ),
        shadows: OH.lift,
      ),
      foregroundDecoration: ring == null
          ? null
          : ShapeDecoration(
              shape: RoundedRectangleBorder(
                borderRadius: const BorderRadius.all(
                  Radius.circular(OH.radius),
                ),
                side: BorderSide(color: ring!, width: 2),
              ),
            ),
      child: Column(
        children: [
          InfoItemView(
            item: item,
            now: now,
            lifted: false,
            onTimeTap: onTimeTap,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                OH.padStart + OH.disc + OH.gap,
                OH.unit,
                OH.padEnd,
                OH.unit * 4,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        item.text.isEmpty ? '空白信息' : item.text,
                        style: OH.itemText.copyWith(
                          color: item.text.isEmpty ? OH.inkSoft : OH.ink,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ),
                  if (image != null) ...[
                    const SizedBox(width: OH.gap),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(OH.unit * 3),
                      child: Image.memory(
                        image,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The strip opened up for typing. Enter saves, Shift+Enter starts a new
/// line, Esc cancels.
class InlineEditor extends StatelessWidget {
  const InlineEditor({
    super.key,
    required this.item,
    required this.controller,
    required this.focusNode,
    required this.onCommit,
    required this.onCancel,
  });

  static const double height = OH.stripHeight + 84;

  final InfoItem item;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onCommit;
  final VoidCallback onCancel;

  KeyEventResult _key(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.escape) {
      onCancel();
      return KeyEventResult.handled;
    }
    if ((e.logicalKey == LogicalKeyboardKey.enter ||
            e.logicalKey == LogicalKeyboardKey.numpadEnter) &&
        !HardwareKeyboard.instance.isShiftPressed) {
      onCommit();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: OH.stripWidth,
      height: height,
      padding: const EdgeInsets.fromLTRB(
        OH.padStart,
        OH.padStart,
        OH.padEnd,
        OH.unit * 2,
      ),
      decoration: const ShapeDecoration(
        color: OH.ground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(OH.radius)),
          side: BorderSide(color: OH.ink, width: 2),
        ),
        shadows: OH.lift,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ItemDisc(item: item),
                const SizedBox(width: OH.gap),
                Expanded(
                  child: Focus(
                    onKeyEvent: _key,
                    skipTraversal: true,
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      autofocus: true,
                      maxLines: null,
                      expands: true,
                      keyboardType: TextInputType.multiline,
                      style: OH.itemText.copyWith(height: 1.45),
                      cursorColor: OH.ink,
                      cursorWidth: 1.5,
                      decoration: const InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.only(top: 9),
                        hintText: '写点什么',
                        hintStyle: TextStyle(color: OH.inkSoft),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: OH.disc + OH.gap),
            child: Text(
              'Enter 保存 · Shift+Enter 换行 · Esc 取消',
              style: OH.itemText.copyWith(fontSize: 12, color: OH.inkSoft),
            ),
          ),
        ],
      ),
    );
  }
}

/// Green slot at either end of the list for adding a new item.
class AddSlot extends StatelessWidget {
  const AddSlot({super.key, this.fade = 1});

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
