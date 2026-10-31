import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'info_item.dart';

/// One item drawn as a pill: icon disc, text, and (when timed) the
/// remaining time. A countdown fills the pill from the left like an
/// unrolled activity ring.
class InfoItemView extends StatelessWidget {
  const InfoItemView({
    super.key,
    required this.item,
    required this.now,
    this.onTimeTap,
    this.lifted = true,
    this.fade = 1,
    this.ring,
  });

  final InfoItem item;
  final DateTime now;
  final VoidCallback? onTimeTap;

  /// The pinned strip casts a shadow; preview rows sit flatter.
  final bool lifted;

  /// Preview rows fade with distance from the strip. The ground stays
  /// near-opaque so the desktop never reads through; the ink fades and the
  /// lap pales toward its own track, keeping its state hue.
  final double fade;

  /// Outline for the selected row or a drop target.
  final Color? ring;

  @override
  Widget build(BuildContext context) {
    final time = item.time;
    final state = time?.state(now);
    final ended = state == TimeState.ended;
    // The track (or the ended fill) is the pill's own ground. Painting it
    // over a white ground inside the clip leaves the white's antialiased
    // edge showing as a fringe around the pill.
    final ground = switch (state) {
      null => OH.ground,
      TimeState.running => OH.runTrack,
      TimeState.paused => OH.pauseTrack,
      TimeState.ended => Color.lerp(OH.endTrack, OH.endRing, fade)!,
    };

    return MetaData(
      metaData: ItemTag(item.id),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: OH.stripWidth,
        height: OH.stripHeight,
        decoration: ShapeDecoration(
          color: ground.withValues(alpha: 0.94 + 0.06 * fade),
          shape: const StadiumBorder(),
          shadows: lifted ? OH.lift : const [],
        ),
        foregroundDecoration: ring == null
            ? null
            : ShapeDecoration(
                shape: StadiumBorder(side: BorderSide(color: ring!, width: 2)),
              ),
        child: ClipPath(
          clipper: const ShapeBorderClipper(shape: StadiumBorder()),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (time != null && !ended)
                CustomPaint(
                  painter: LapPainter(
                    remaining: time.remaining(now),
                    state: state!,
                    fade: fade,
                  ),
                ),
              Opacity(
                opacity: fade,
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: OH.padStart,
                    right: OH.padEnd,
                  ),
                  child: Row(
                    children: [
                      ItemDisc(item: item),
                      const SizedBox(width: OH.gap),
                      Expanded(
                        child: Text(
                          item.text.isEmpty ? '空白信息' : item.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ended
                              ? OH.itemText.copyWith(color: endInk(fade))
                              : item.text.isEmpty
                              ? OH.itemText.copyWith(color: OH.inkSoft)
                              : OH.itemText,
                        ),
                      ),
                      if (time != null) ...[
                        const SizedBox(width: OH.unit * 2),
                        _TimeCell(
                          remaining: time.remaining(now),
                          state: state!,
                          fade: fade,
                          onTap: onTimeTap,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Marks an item's pill so a drop from another app can find the item under
/// the pointer.
class ItemTag {
  const ItemTag(this.id);
  final String id;
}

/// White on the full red pill; red once the pill has paled toward its track.
Color endInk(double fade) => Color.lerp(OH.endRing, OH.endInk, fade)!;

/// The item's image, or its glyph on a grey disc.
class ItemDisc extends StatelessWidget {
  const ItemDisc({super.key, required this.item, this.size = OH.disc});

  final InfoItem item;
  final double size;

  @override
  Widget build(BuildContext context) {
    final image = item.image;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: OH.discFill,
        image: image == null
            ? null
            : DecorationImage(
                image: MemoryImage(image),
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
              ),
      ),
      alignment: Alignment.center,
      child: image == null
          ? Icon(item.glyph, size: size * 0.56, color: OH.ink)
          : null,
    );
  }
}

/// Pointer ids that went down on a time cell. Row gestures skip these so a
/// quick double click on the time does not also open the list.
final Set<int> timeCellPointers = {};

/// Remaining time; click to pause or resume. The pause/play glyph appears
/// on hover and stays while paused.
class _TimeCell extends StatefulWidget {
  const _TimeCell({
    required this.remaining,
    required this.state,
    this.fade = 1,
    this.onTap,
  });

  final Duration remaining;
  final TimeState state;
  final double fade;
  final VoidCallback? onTap;

  @override
  State<_TimeCell> createState() => _TimeCellState();
}

class _TimeCellState extends State<_TimeCell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _morph = AnimationController(
    vsync: this,
    duration: OH.settle,
    value: widget.state == TimeState.paused ? 1 : 0,
  );
  bool _hover = false;

  @override
  void didUpdateWidget(_TimeCell old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) {
      // 0 = pause glyph (running), 1 = play glyph (paused).
      if (widget.state == TimeState.paused) {
        _morph.animateTo(1, curve: Curves.easeOutExpo);
      } else if (widget.state == TimeState.running) {
        _morph.animateTo(0, curve: Curves.easeOutExpo);
      }
    }
  }

  @override
  void dispose() {
    _morph.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final ink = switch (state) {
      TimeState.running => OH.ink,
      TimeState.paused => OH.pauseInk,
      TimeState.ended => endInk(widget.fade),
    };
    final showGlyph =
        state == TimeState.paused || (_hover && state == TimeState.running);
    final interactive = widget.onTap != null && state != TimeState.ended;

    return Listener(
      onPointerDown: interactive
          ? (e) {
              timeCellPointers
                ..clear()
                ..add(e.pointer);
            }
          : null,
      child: MouseRegion(
        cursor: interactive ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: interactive ? widget.onTap : null,
          child: Semantics(
            button: interactive,
            label: switch (state) {
              TimeState.running => '暂停倒计时',
              TimeState.paused => '继续倒计时',
              TimeState.ended => '倒计时已结束',
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedOpacity(
                  opacity: showGlyph ? 1 : 0,
                  duration: OH.quick,
                  child: AnimatedIcon(
                    icon: AnimatedIcons.pause_play,
                    progress: _morph,
                    size: 18,
                    color: ink,
                  ),
                ),
                const SizedBox(width: OH.unit),
                Text(
                  formatRemaining(widget.remaining),
                  style: OH.timeText.copyWith(color: ink),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `m:ss` under an hour, `h:mm:ss` above.
String formatRemaining(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
}

/// Fills the pill's track from the left (the track itself is the pill's
/// ground). One lap is one hour; time beyond the first
/// hour is laid over it in a deeper shade, blending in near the lap start
/// and casting a soft shadow at its round cap, like an activity ring
/// passing its own start. Away from the strip ([fade] < 1) every colour
/// pales toward its track, so the pinned strip stays the most saturated.
class LapPainter extends CustomPainter {
  LapPainter({required this.remaining, required this.state, this.fade = 1});

  final Duration remaining;
  final TimeState state;
  final double fade;

  static const double _lap = 3600;

  @override
  void paint(Canvas canvas, Size size) {
    if (state == TimeState.ended) return;

    final (track, fullLap, fullOver) = switch (state) {
      TimeState.running => (OH.runTrack, OH.runLap, OH.runOver),
      _ => (OH.pauseTrack, OH.pauseLap, OH.pauseOver),
    };
    final lap = Color.lerp(track, fullLap, fade)!;
    final over = Color.lerp(track, fullOver, fade)!;

    final laps = remaining.inMilliseconds / 1000 / _lap;
    final first = laps.clamp(0.0, 1.0);
    if (first > 0) {
      final path = _shape(size, _width(size, first));
      canvas.drawShadow(path, const Color(0x33000000), 2, false);
      canvas.drawPath(path, Paint()..color = lap);
    }

    if (laps > 1) {
      final frac = laps - laps.floor();
      final extra = frac == 0 ? 1.0 : frac;
      final w = _width(size, extra);
      final blend = math.min(w, size.height * 1.5);
      final paint = Paint()
        ..shader = LinearGradient(
          colors: [lap, over],
          stops: [0, blend / w],
        ).createShader(Rect.fromLTWH(0, 0, w, size.height));
      final cap = _shape(size, w);
      canvas.drawShadow(cap, const Color(0x55000000), 3, false);
      canvas.drawPath(cap, paint);
    }
  }

  double _width(Size size, double f) =>
      size.height + (size.width - size.height) * f;

  Path _shape(Size size, double w) => Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, w, size.height),
        Radius.circular(size.height / 2),
      ),
    );

  @override
  bool shouldRepaint(LapPainter old) =>
      old.remaining != remaining || old.state != state || old.fade != fade;
}
