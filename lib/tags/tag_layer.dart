import 'package:flutter/material.dart';

import '../item/info_item.dart';
import '../item/info_item_view.dart';
import '../plugin.dart';
import '../strings.dart';
import '../theme/tokens.dart';

const double _pillW = 152;
const double _pillH = OH.stripHeight;
const double _square = 120;
const double _gap = OH.unit * 3;
const double _away = OH.unit * 6;
const double _edge = OH.unit * 2;

/// Where each zone sits: a column beside [window] on whichever side has
/// room (right first), or a row below it when neither side fits.
List<(TagZone, Rect)> layoutZones(List<TagZone> zones, Rect window, Size work) {
  Size sizeOf(TagZone z) =>
      z.square ? const Size(_square, _square) : const Size(_pillW, _pillH);
  final sizes = [for (final z in zones) sizeOf(z)];
  final colW = sizes.fold(0.0, (w, s) => s.width > w ? s.width : w);
  final colH =
      sizes.fold(0.0, (h, s) => h + s.height) + _gap * (zones.length - 1);

  double? x;
  if (window.right + _away + colW <= work.width - _edge) {
    x = window.right + _away;
  } else if (window.left - _away - colW >= _edge) {
    x = window.left - _away - colW;
  }

  final out = <(TagZone, Rect)>[];
  if (x != null) {
    final maxY = work.height - colH - _edge;
    var y = (window.center.dy - colH / 2).clamp(
      _edge,
      maxY < _edge ? _edge : maxY,
    );
    for (var i = 0; i < zones.length; i++) {
      final s = sizes[i];
      out.add((zones[i], Offset(x + (colW - s.width) / 2, y) & s));
      y += s.height + _gap;
    }
    return out;
  }

  // Row below (or above, when there is no room below).
  final rowW =
      sizes.fold(0.0, (w, s) => w + s.width) + _gap * (zones.length - 1);
  final rowH = sizes.fold(0.0, (h, s) => s.height > h ? s.height : h);
  final below = window.bottom + _away + rowH <= work.height - _edge;
  final y = below ? window.bottom + _away : window.top - _away - rowH;
  final maxX = work.width - rowW - _edge;
  var left = (window.center.dx - rowW / 2).clamp(
    _edge,
    maxX < _edge ? _edge : maxX,
  );
  for (var i = 0; i < zones.length; i++) {
    final s = sizes[i];
    out.add((zones[i], Offset(left, y + (rowH - s.height) / 2) & s));
    left += s.width + _gap;
  }
  return out;
}

/// Tag zones around the window plus the dragged item following the
/// pointer. When [returning], the item glides back to [origin] and the
/// zones fade away.
class TagLayer extends StatelessWidget {
  const TagLayer({
    super.key,
    required this.zones,
    required this.item,
    required this.now,
    required this.origin,
    required this.ghostAt,
    required this.hovered,
    required this.returning,
  });

  final List<(TagZone, Rect)> zones;
  final InfoItem item;
  final DateTime now;

  /// The row the item was lifted from.
  final Rect origin;

  /// Top-left of the dragged copy.
  final Offset ghostAt;
  final String? hovered;
  final bool returning;

  @override
  Widget build(BuildContext context) {
    final at = returning ? origin.topLeft : ghostAt;
    return Stack(
      children: [
        for (final (zone, rect) in zones)
          Positioned.fromRect(
            rect: rect,
            child: AnimatedOpacity(
              opacity: returning ? 0 : 1,
              duration: OH.quick,
              child: _FadeIn(
                child: _Zone(
                  zone: zone,
                  label: zone.activeLabel?.call(item) ?? zone.label,
                  hint: zone.id == 'time'
                      ? (item.time == null
                            ? strings.setCountdown
                            : strings.changeCountdown)
                      : null,
                  hovered: hovered == zone.id && !returning,
                ),
              ),
            ),
          ),
        AnimatedPositioned(
          left: at.dx,
          top: at.dy,
          duration: returning ? OH.settle : Duration.zero,
          curve: Curves.easeOutExpo,
          child: IgnorePointer(
            child: AnimatedScale(
              scale: hovered != null && !returning ? 0.92 : 1,
              duration: OH.quick,
              child: InfoItemView(item: item, now: now),
            ),
          ),
        ),
      ],
    );
  }
}

class _FadeIn extends StatelessWidget {
  const _FadeIn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: OH.quick,
    curve: Curves.easeOut,
    builder: (context, t, child) => Opacity(
      opacity: t,
      child: Transform.scale(scale: 0.94 + 0.06 * t, child: child),
    ),
    child: child,
  );
}

class _Zone extends StatelessWidget {
  const _Zone({
    required this.zone,
    required this.label,
    required this.hovered,
    this.hint,
  });

  final TagZone zone;
  final String label;
  final String? hint;
  final bool hovered;

  @override
  Widget build(BuildContext context) {
    final shape = zone.square
        ? RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(OH.unit * 6),
            side: BorderSide(
              color: OH.ink.withValues(alpha: hovered ? 1 : 0.16),
              width: hovered ? 2 : 1.5,
            ),
          )
        : StadiumBorder(
            side: BorderSide(
              color: OH.ink.withValues(alpha: hovered ? 1 : 0.16),
              width: hovered ? 2 : 1.5,
            ),
          );
    final text = Text(label, style: OH.itemText);
    return AnimatedScale(
      scale: hovered ? 1.06 : 1,
      duration: OH.quick,
      curve: Curves.easeOutBack,
      child: AnimatedContainer(
        duration: OH.quick,
        decoration: ShapeDecoration(
          color: OH.ground.withValues(alpha: hovered ? 0.98 : 0.72),
          shape: shape,
          shadows: hovered ? OH.lift : const [],
        ),
        child: zone.square
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(zone.icon, size: 36, color: OH.ink),
                  const SizedBox(height: OH.unit * 2),
                  text,
                  if (hint != null)
                    Text(
                      hint!,
                      style: OH.itemText.copyWith(
                        fontSize: 12,
                        color: OH.inkSoft,
                      ),
                    ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(zone.icon, size: 20, color: OH.ink),
                  const SizedBox(width: OH.unit * 2),
                  text,
                ],
              ),
      ),
    );
  }
}
