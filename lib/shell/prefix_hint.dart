import 'package:flutter/material.dart';

import '../config.dart';
import '../strings.dart';
import '../theme/controls.dart';
import '../theme/tokens.dart';
import 'keys.dart';

/// Shown beside the window after the prefix: what each key does. It only
/// informs; the key press itself is caught natively, wherever focus is.
class PrefixHint extends StatelessWidget {
  const PrefixHint({super.key, required this.config});

  final OneHitConfig config;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(OH.unit * 4),
      decoration: panelDecoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PanelSection(strings.pressAKey),
          for (final c in Command.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: OH.unit / 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: KeyChip(label: keyLabel(config.keyFor(c))),
                    ),
                  ),
                  Expanded(child: Text(c.label, style: panelBody)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
