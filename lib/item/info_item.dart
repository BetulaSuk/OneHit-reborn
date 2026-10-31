import 'package:flutter/widgets.dart';

enum TimeKind {
  /// Runs whenever it is not paused by hand; announces itself when it ends
  /// off-screen.
  reminder,

  /// Runs only while shown in the minimal window, unless the user has
  /// started or paused it by hand.
  timer,
}

enum TimeState { running, paused, ended }

/// Countdown attached to an item. Time is derived from the wall clock, so
/// no per-second bookkeeping is needed.
class TimeTag {
  TimeTag({
    required this.kind,
    required Duration remaining,
    bool running = true,
    DateTime? now,
  }) : _banked = remaining,
       _since = running ? (now ?? DateTime.now()) : null;

  final TimeKind kind;

  /// Remaining time at the moment [_since] was set (or at pause).
  Duration _banked;
  DateTime? _since;

  /// Set once the user starts or pauses by hand; auto rules then leave it.
  bool manual = false;

  static const Duration max = Duration(hours: 12);

  Duration remaining(DateTime now) {
    final since = _since;
    if (since == null) return _banked;
    final left = _banked - now.difference(since);
    return left.isNegative ? Duration.zero : left;
  }

  TimeState state(DateTime now) {
    if (remaining(now) == Duration.zero) return TimeState.ended;
    return _since == null ? TimeState.paused : TimeState.running;
  }

  void start(DateTime now) {
    if (_since != null || _banked == Duration.zero) return;
    _since = now;
  }

  void pause(DateTime now) {
    if (_since == null) return;
    _banked = remaining(now);
    _since = null;
  }

  /// User click on the remaining time.
  void toggle(DateTime now) {
    switch (state(now)) {
      case TimeState.running:
        pause(now);
      case TimeState.paused:
        start(now);
      case TimeState.ended:
        return;
    }
    manual = true;
  }
}

/// The single component model: information and tasks are the same thing.
/// Default structure is core text + icon + tags.
class InfoItem {
  InfoItem({
    required this.id,
    required this.text,
    this.icon,
    this.image,
    this.sunk = false,
    this.time,
  });

  final String id;
  String text;

  /// Fallback glyph when no image is set.
  IconData? icon;
  ImageProvider? image;

  /// Sunk items are dimmed, sorted last and never shown in the minimal window.
  bool sunk;

  TimeTag? time;
}
