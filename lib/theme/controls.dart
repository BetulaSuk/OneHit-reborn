import 'package:flutter/material.dart';

import '../strings.dart';
import 'tokens.dart';

/// Shared parts of the detached panels (editor, settings, about): a white
/// rounded card with ink controls. Selected things turn ink; everything
/// else sits on Disc Grey.

const ShapeDecoration panelDecoration = ShapeDecoration(
  color: OH.ground,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(OH.unit * 5)),
  ),
  shadows: OH.lift,
);

TextStyle get panelTitle => OH.itemText.copyWith(fontWeight: FontWeight.w700);
TextStyle get panelBody => OH.itemText.copyWith(fontSize: OH.userSize - 1);
TextStyle get panelHint => OH.itemText.copyWith(
  fontSize: OH.userSize - 3,
  color: OH.inkSoft,
  height: 1.4,
);

class PanelSection extends StatelessWidget {
  const PanelSection(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: OH.unit * 2),
    child: Text(label, style: panelHint.copyWith(fontWeight: FontWeight.w700)),
  );
}

/// Lets the keyboard reach [child]: Tab stops on it, Enter or Space calls
/// [onActivate], and an ink ring hugs its pill (or [circle]) while it has
/// keyboard focus. Mouse use never shows the ring. Pointer input is left to
/// the child; [Pressable] adds the click.
class FocusRing extends StatefulWidget {
  const FocusRing({
    super.key,
    required this.onActivate,
    required this.child,
    this.circle = false,
    this.focusNode,
    this.cursor = MouseCursor.defer,
  });

  final VoidCallback? onActivate;
  final Widget child;
  final bool circle;
  final FocusNode? focusNode;
  final MouseCursor cursor;

  @override
  State<FocusRing> createState() => _FocusRingState();
}

class _FocusRingState extends State<FocusRing> {
  bool _ring = false;

  @override
  Widget build(BuildContext context) {
    final activate = widget.onActivate;
    // Set 3px off the control so it also reads against an ink fill.
    const side = BorderSide(color: OH.ink, width: 2);
    return FocusableActionDetector(
      enabled: activate != null,
      focusNode: widget.focusNode,
      mouseCursor: widget.cursor,
      onShowFocusHighlight: (v) => setState(() => _ring = v),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            activate?.call();
            return null;
          },
        ),
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          widget.child,
          if (_ring)
            Positioned.fill(
              left: -3,
              top: -3,
              right: -3,
              bottom: -3,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    shape: widget.circle
                        ? const CircleBorder(side: side)
                        : const StadiumBorder(side: side),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A control that works for every input: click, Tab then Enter or Space,
/// and Narrator, which reads it as a button with [label] (or its own text)
/// and, when given, its [toggled] or [selected] state.
class Pressable extends StatelessWidget {
  const Pressable({
    super.key,
    required this.onTap,
    required this.child,
    this.label,
    this.toggled,
    this.selected,
    this.circle = false,
  });

  final VoidCallback? onTap;
  final Widget child;
  final String? label;
  final bool? toggled;
  final bool? selected;
  final bool circle;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Semantics(
      button: true,
      enabled: onTap != null,
      toggled: toggled,
      selected: selected,
      label: label,
      child: FocusRing(
        onActivate: onTap,
        circle: circle,
        cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: child,
        ),
      ),
    ),
  );
}

/// How a [PillToggle] reads to Narrator.
enum PillRole {
  /// On or off, like sink or start with Windows.
  toggle,

  /// One of a set, like the language or the display.
  choice,

  /// A plain button that only looks like the others.
  action,
}

class PillToggle extends StatelessWidget {
  const PillToggle({
    super.key,
    required this.label,
    required this.icon,
    required this.on,
    required this.onTap,
    this.role = PillRole.toggle,
  });

  final String label;
  final IconData icon;
  final bool on;
  final VoidCallback onTap;
  final PillRole role;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      toggled: role == PillRole.toggle ? on : null,
      selected: role == PillRole.choice ? on : null,
      child: AnimatedContainer(
        duration: OH.quick,
        height: 32 * OH.scale,
        padding: const EdgeInsets.symmetric(horizontal: OH.unit * 3),
        decoration: BoxDecoration(
          color: on ? OH.ink : OH.discFill,
          borderRadius: BorderRadius.circular(16 * OH.scale),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16 * OH.scale, color: on ? OH.ground : OH.ink),
            const SizedBox(width: OH.unit * 1.5),
            Text(
              label,
              style: panelBody.copyWith(color: on ? OH.ground : OH.ink),
            ),
          ],
        ),
      ),
    );
  }
}

class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      waitDuration: const Duration(milliseconds: 600),
      child: InkResponse(
        onTap: onTap,
        radius: 18 * OH.scale,
        child: SizedBox(
          width: 32 * OH.scale,
          height: 32 * OH.scale,
          child: Icon(icon, size: 18 * OH.scale, color: OH.ink, semanticLabel: label),
        ),
      ),
    );
  }
}

class QuietButton extends StatelessWidget {
  const QuietButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(OH.unit * 2),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: OH.unit * 2,
          vertical: OH.unit * 1.5,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16 * OH.scale, color: OH.inkSoft),
              const SizedBox(width: OH.unit),
            ],
            Text(label, style: panelBody.copyWith(color: OH.inkSoft)),
          ],
        ),
      ),
    );
  }
}

/// A key or key combination, like `L` or `Ctrl + Alt + O`. While
/// [recording] it turns ink and asks for the new key.
class KeyChip extends StatelessWidget {
  const KeyChip({
    super.key,
    required this.label,
    this.recording = false,
    this.onTap,
    this.semanticLabel,
  });

  final String label;
  final bool recording;
  final VoidCallback? onTap;

  /// What the key is for, read before the key itself (`New item, N`).
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final chip = AnimatedContainer(
      duration: OH.quick,
      height: 28 * OH.scale,
      constraints: BoxConstraints(minWidth: 28 * OH.scale),
      padding: const EdgeInsets.symmetric(horizontal: OH.unit * 2.5),
      decoration: BoxDecoration(
        color: recording ? OH.ink : OH.discFill,
        borderRadius: BorderRadius.circular(14 * OH.scale),
      ),
      // Hugs the label; a plain alignment would stretch to the full width.
      child: Align(
        widthFactor: 1,
        child: Text(
          recording ? strings.pressKey : label,
          style: panelBody.copyWith(
            color: recording ? OH.ground : OH.ink,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
    if (onTap == null) return chip;
    return Pressable(onTap: onTap, label: semanticLabel, child: chip);
  }
}

/// − value + on a grey pill.
class PillStepper extends StatelessWidget {
  const PillStepper({
    super.key,
    required this.label,
    required this.onStep,
    this.canDown = true,
    this.canUp = true,
  });

  final String label;
  final void Function(int direction) onStep;
  final bool canDown;
  final bool canUp;

  @override
  Widget build(BuildContext context) {
    Widget button(IconData icon, int direction, bool enabled, String tip) =>
        Tooltip(
          message: tip,
          waitDuration: const Duration(milliseconds: 600),
          child: InkResponse(
            onTap: enabled ? () => onStep(direction) : null,
            radius: 16 * OH.scale,
            child: SizedBox(
              width: 32 * OH.scale,
              height: 32 * OH.scale,
              child: Icon(
                icon,
                size: 16 * OH.scale,
                color: enabled ? OH.ink : OH.inkSoft.withValues(alpha: 0.4),
              ),
            ),
          ),
        );

    return Container(
      height: 32 * OH.scale,
      decoration: BoxDecoration(
        color: OH.discFill,
        borderRadius: BorderRadius.circular(16 * OH.scale),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(Icons.remove_rounded, -1, canDown, strings.decrease),
          ConstrainedBox(
            constraints: BoxConstraints(minWidth: 40 * OH.scale),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: panelBody.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          button(Icons.add_rounded, 1, canUp, strings.increase),
        ],
      ),
    );
  }
}
