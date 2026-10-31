import 'package:flutter/material.dart';

import '../item/info_item.dart';
import '../item/info_item_view.dart';
import '../item/item_store.dart';
import '../strings.dart';
import '../theme/controls.dart';
import '../theme/tokens.dart';

/// Detached panel beside the list that edits every part of one item: text,
/// icon or image, and tags.
class SideEditor extends StatefulWidget {
  const SideEditor({
    super.key,
    required this.item,
    required this.store,
    required this.onClose,
    required this.onTimeDial,
    this.focusText = false,
  });

  static const double width = 300;

  final InfoItem item;
  final ItemStore store;
  final VoidCallback onClose;
  final VoidCallback onTimeDial;
  final bool focusText;

  @override
  State<SideEditor> createState() => _SideEditorState();
}

class _SideEditorState extends State<SideEditor> {
  late final _text = TextEditingController(text: widget.item.text);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.focusText) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _focus.requestFocus();
        _text.selection = TextSelection.collapsed(offset: _text.text.length);
      });
    }
  }

  @override
  void didUpdateWidget(SideEditor old) {
    super.didUpdateWidget(old);
    if (old.item != widget.item) _text.text = widget.item.text;
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final store = widget.store;
    // Text appended by a paste shows up unless the user is mid-typing.
    if (!_focus.hasFocus && _text.text != item.text) _text.text = item.text;

    return Container(
      width: SideEditor.width,
      padding: const EdgeInsets.all(OH.unit * 4),
      decoration: panelDecoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ItemDisc(item: item, size: 28),
              const SizedBox(width: OH.unit * 2),
              Expanded(child: Text(strings.editItem, style: panelTitle)),
              RoundIconButton(
                icon: Icons.close_rounded,
                label: strings.close,
                onTap: widget.onClose,
              ),
            ],
          ),
          const SizedBox(height: OH.unit * 3),
          TextField(
            controller: _text,
            focusNode: _focus,
            minLines: 2,
            maxLines: 5,
            style: OH.itemText.copyWith(height: 1.45),
            cursorColor: OH.ink,
            onChanged: (t) => store.setText(item, t),
            decoration: InputDecoration(
              hintText: strings.writeSomething,
              hintStyle: const TextStyle(color: OH.inkSoft),
              filled: true,
              fillColor: OH.discFill,
              contentPadding: const EdgeInsets.all(OH.unit * 3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(OH.unit * 3),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(OH.unit * 3),
                borderSide: const BorderSide(color: OH.ink, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: OH.unit * 4),
          PanelSection(strings.icon),
          Wrap(
            spacing: OH.unit * 1.5,
            runSpacing: OH.unit * 1.5,
            children: [
              for (final e in itemIcons.entries)
                _Glyph(
                  icon: e.value,
                  selected: item.image == null && item.icon == e.key,
                  onTap: () => store.setIcon(item, e.key),
                ),
            ],
          ),
          const SizedBox(height: OH.unit * 2),
          if (item.image != null)
            Row(
              children: [
                ItemDisc(item: item, size: 32),
                const SizedBox(width: OH.unit * 2),
                Expanded(child: Text(strings.imageIcon, style: panelBody)),
                QuietButton(
                  label: strings.removeImage,
                  onTap: () => store.setImage(item, null),
                ),
              ],
            )
          else
            Text(strings.iconHint, style: panelHint),
          const SizedBox(height: OH.unit * 4),
          PanelSection(strings.tags),
          Wrap(
            spacing: OH.unit * 2,
            runSpacing: OH.unit * 2,
            children: [
              PillToggle(
                label: strings.sink,
                icon: Icons.south_rounded,
                on: item.sunk,
                onTap: () => store.setSunk(item, !item.sunk),
              ),
              PillToggle(
                label: strings.detail,
                icon: Icons.unfold_more_rounded,
                on: item.detail,
                onTap: () => store.setDetail(item, !item.detail),
              ),
            ],
          ),
          const SizedBox(height: OH.unit * 3),
          _TimeRow(item: item, store: store, onDial: widget.onTimeDial),
          const SizedBox(height: OH.unit * 4),
          Align(
            alignment: Alignment.centerLeft,
            child: QuietButton(
              label: strings.deleteItem,
              icon: Icons.delete_outline_rounded,
              onTap: () {
                widget.onClose();
                store.remove(item);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.item,
    required this.store,
    required this.onDial,
  });

  final InfoItem item;
  final ItemStore store;
  final VoidCallback onDial;

  @override
  Widget build(BuildContext context) {
    final time = item.time;
    if (time == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: PillToggle(
          label: strings.time,
          icon: Icons.timer_outlined,
          on: false,
          onTap: onDial,
        ),
      );
    }
    final state = time.state(store.now);
    final ink = switch (state) {
      TimeState.running => OH.ink,
      TimeState.paused => OH.pauseInk,
      TimeState.ended => OH.endRing,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              formatRemaining(time.remaining(store.now)),
              style: OH.timeText.copyWith(color: ink),
            ),
            const SizedBox(width: OH.unit * 2),
            Text(switch (state) {
              TimeState.running => strings.running,
              TimeState.paused =>
                item.sunk ? strings.sunkPaused : strings.paused,
              TimeState.ended => strings.ended,
            }, style: panelHint),
            const Spacer(),
            if (state != TimeState.ended && !item.sunk)
              RoundIconButton(
                icon: state == TimeState.running
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                label: state == TimeState.running
                    ? strings.pause
                    : strings.resume,
                onTap: () => store.toggleTime(item),
              ),
            RoundIconButton(
              icon: Icons.tune_rounded,
              label: strings.adjustTime,
              onTap: onDial,
            ),
            RoundIconButton(
              icon: Icons.close_rounded,
              label: strings.removeTime,
              onTap: () => store.clearTime(item),
            ),
          ],
        ),
        const SizedBox(height: OH.unit * 2),
        KindSwitch(
          kind: time.kind,
          onChanged: (k) => store.setTime(item, time.remaining(store.now), k),
        ),
      ],
    );
  }
}

/// Reminder / Timer choice, shared with the time dial.
class KindSwitch extends StatelessWidget {
  const KindSwitch({super.key, required this.kind, required this.onChanged});

  final TimeKind kind;
  final ValueChanged<TimeKind> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget option(TimeKind k, String label, String tip) {
      final on = k == kind;
      return Expanded(
        child: Tooltip(
          message: tip,
          waitDuration: const Duration(milliseconds: 600),
          child: GestureDetector(
            onTap: () => onChanged(k),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: AnimatedContainer(
                duration: OH.quick,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: on ? OH.ground : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: on ? OH.lift.sublist(1) : null,
                ),
                child: Text(
                  label,
                  style: panelBody.copyWith(color: on ? OH.ink : OH.inkSoft),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: OH.discFill,
        borderRadius: BorderRadius.circular(19),
      ),
      child: Row(
        children: [
          option(TimeKind.reminder, 'Reminder', strings.reminderNote),
          option(TimeKind.timer, 'Timer', strings.timerNote),
        ],
      ),
    );
  }
}

class _Glyph extends StatelessWidget {
  const _Glyph({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: OH.quick,
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? OH.ink : OH.discFill,
          ),
          child: Icon(icon, size: 17, color: selected ? OH.ground : OH.ink),
        ),
      ),
    );
  }
}
