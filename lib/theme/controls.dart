import 'package:flutter/material.dart';

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

class PillToggle extends StatelessWidget {
  const PillToggle({
    super.key,
    required this.label,
    required this.icon,
    required this.on,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: OH.quick,
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: OH.unit * 3),
          decoration: BoxDecoration(
            color: on ? OH.ink : OH.discFill,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: on ? OH.ground : OH.ink),
              const SizedBox(width: OH.unit * 1.5),
              Text(
                label,
                style: panelBody.copyWith(color: on ? OH.ground : OH.ink),
              ),
            ],
          ),
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
        radius: 18,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, size: 18, color: OH.ink, semanticLabel: label),
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
              Icon(icon, size: 16, color: OH.inkSoft),
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
  });

  final String label;
  final bool recording;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chip = AnimatedContainer(
      duration: OH.quick,
      height: 28,
      constraints: const BoxConstraints(minWidth: 28),
      padding: const EdgeInsets.symmetric(horizontal: OH.unit * 2.5),
      decoration: BoxDecoration(
        color: recording ? OH.ink : OH.discFill,
        borderRadius: BorderRadius.circular(14),
      ),
      // Hugs the label; a plain alignment would stretch to the full width.
      child: Align(
        widthFactor: 1,
        child: Text(
          recording ? '按下按键…' : label,
          style: panelBody.copyWith(
            color: recording ? OH.ground : OH.ink,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
    if (onTap == null) return chip;
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(cursor: SystemMouseCursors.click, child: chip),
    );
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
            radius: 16,
            child: SizedBox(
              width: 32,
              height: 32,
              child: Icon(
                icon,
                size: 16,
                color: enabled ? OH.ink : OH.inkSoft.withValues(alpha: 0.4),
              ),
            ),
          ),
        );

    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: OH.discFill,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(Icons.remove_rounded, -1, canDown, '减少'),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 40),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: panelBody.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          button(Icons.add_rounded, 1, canUp, '增加'),
        ],
      ),
    );
  }
}
