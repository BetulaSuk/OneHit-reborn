import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

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
    this.manual = false,
    DateTime? now,
  }) : _banked = _clamp(remaining),
       _since = running ? (now ?? DateTime.now()) : null;

  TimeTag._(this.kind, this._banked, this._since, this.manual);

  TimeKind kind;

  /// Remaining time at the moment [_since] was set (or at pause).
  Duration _banked;
  DateTime? _since;

  /// Set once the user starts or pauses by hand; auto rules then leave it.
  bool manual;

  static const Duration max = Duration(hours: 12);

  static Duration _clamp(Duration d) =>
      d.isNegative ? Duration.zero : (d > max ? max : d);

  bool get isRunning => _since != null;

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

  /// Re-adjusts the countdown, keeping it running if it was. A tag that had
  /// ended starts again.
  void set(Duration remaining, DateTime now) {
    final wasEnded = state(now) == TimeState.ended;
    final running = _since != null || wasEnded;
    _banked = _clamp(remaining);
    _since = running && _banked > Duration.zero ? now : null;
  }

  Map<String, Object?> toJson(DateTime now) => {
    'kind': kind.name,
    'remainingMs': remaining(now).inMilliseconds,
    'running': _since != null,
    'manual': manual,
    'savedAt': now.millisecondsSinceEpoch,
  };

  /// A running tag keeps counting from when it was saved, so time passes
  /// while the app is closed.
  factory TimeTag.fromJson(Map<String, Object?> json) {
    final savedAt = DateTime.fromMillisecondsSinceEpoch(
      (json['savedAt'] as num?)?.toInt() ?? 0,
    );
    final running = json['running'] == true;
    return TimeTag._(
      TimeKind.values.asNameMap()[json['kind']] ?? TimeKind.reminder,
      Duration(milliseconds: (json['remainingMs'] as num?)?.toInt() ?? 0),
      running ? savedAt : null,
      json['manual'] == true,
    );
  }
}

/// Glyphs an item can use when it has no image. Stored by name so saved
/// items survive icon tree-shaking.
const Map<String, IconData> itemIcons = {
  'notes': Icons.notes_rounded,
  'mail': Icons.mail_rounded,
  'groups': Icons.groups_rounded,
  'book': Icons.menu_book_rounded,
  'rocket': Icons.rocket_launch_rounded,
  'receipt': Icons.receipt_long_rounded,
  'basket': Icons.shopping_basket_rounded,
  'bolt': Icons.bolt_rounded,
  'call': Icons.call_rounded,
  'code': Icons.code_rounded,
  'event': Icons.event_rounded,
  'flag': Icons.flag_rounded,
  'home': Icons.home_rounded,
  'idea': Icons.lightbulb_rounded,
  'link': Icons.link_rounded,
  'star': Icons.star_rounded,
};

/// The single component model: information and tasks are the same thing.
/// Default structure is core text + icon + tags.
class InfoItem {
  InfoItem({
    required this.id,
    required this.text,
    this.icon = 'notes',
    this.image,
    this.sunk = false,
    this.detail = false,
    this.time,
    Map<String, Object?>? extra,
  }) : extra = extra ?? {};

  final String id;
  String text;

  /// Key into [itemIcons]; shown when there is no [image].
  String icon;

  /// Square PNG, already cropped and compressed (see `icon_image.dart`).
  Uint8List? image;

  /// Sunk items are dimmed, sorted last and never shown in the minimal window.
  bool sunk;

  /// The minimal window grows to show this item's full text and image.
  bool detail;

  TimeTag? time;

  /// Plugin-owned data, saved with the item untouched.
  final Map<String, Object?> extra;

  IconData get glyph => itemIcons[icon] ?? Icons.notes_rounded;

  Map<String, Object?> toJson(DateTime now) => {
    'id': id,
    'text': text,
    'icon': icon,
    if (image != null) 'image': base64Encode(image!),
    'sunk': sunk,
    'detail': detail,
    if (time != null) 'time': time!.toJson(now),
    if (extra.isNotEmpty) 'extra': extra,
  };

  factory InfoItem.fromJson(Map<String, Object?> json) => InfoItem(
    id: json['id'] as String,
    text: json['text'] as String? ?? '',
    icon: json['icon'] as String? ?? 'notes',
    image: json['image'] is String
        ? base64Decode(json['image'] as String)
        : null,
    sunk: json['sunk'] == true,
    detail: json['detail'] == true,
    time: json['time'] is Map
        ? TimeTag.fromJson((json['time'] as Map).cast<String, Object?>())
        : null,
    extra: json['extra'] is Map
        ? (json['extra'] as Map).cast<String, Object?>()
        : null,
  );
}
