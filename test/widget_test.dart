import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onehit/config.dart';
import 'package:onehit/item/info_item.dart';
import 'package:onehit/item/info_item_view.dart';
import 'package:onehit/item/item_store.dart';
import 'package:onehit/plugin.dart';
import 'package:onehit/shell/hotkeys.dart';
import 'package:onehit/tags/tag_layer.dart';

void main() {
  final t0 = DateTime(2026, 1, 1, 9);

  test('time tag counts down, pauses and ends', () {
    final tag = TimeTag(
      kind: TimeKind.reminder,
      remaining: const Duration(minutes: 1),
      now: t0,
    );
    final t30 = t0.add(const Duration(seconds: 30));
    expect(tag.remaining(t30), const Duration(seconds: 30));

    tag.toggle(t30);
    expect(tag.state(t30.add(const Duration(minutes: 5))), TimeState.paused);
    expect(tag.manual, isTrue);

    tag.toggle(t30);
    expect(tag.state(t30.add(const Duration(minutes: 1))), TimeState.ended);
  });

  test('timer runs only while pinned unless set by hand', () {
    final a = InfoItem(id: 'a', text: 'a');
    final timed = InfoItem(
      id: 'b',
      text: 'b',
      time: TimeTag(
        kind: TimeKind.timer,
        remaining: const Duration(minutes: 5),
      ),
    );
    final store = ItemStore([a, timed]);
    expect(timed.time!.state(store.now), TimeState.paused);

    store.pin(timed);
    expect(timed.time!.state(store.now), TimeState.running);

    store.pin(a);
    expect(timed.time!.state(store.now), TimeState.paused);
    store.dispose();
  });

  test('formats remaining time', () {
    expect(formatRemaining(const Duration(minutes: 42, seconds: 8)), '42:08');
    expect(formatRemaining(const Duration(hours: 1, minutes: 5)), '1:05:00');
  });

  test('items survive a JSON round trip, running time keeps counting', () {
    final item = InfoItem(
      id: 'x',
      text: '带图片',
      icon: 'mail',
      image: Uint8List.fromList([1, 2, 3]),
      sunk: true,
      detail: true,
      time: TimeTag(
        kind: TimeKind.reminder,
        remaining: const Duration(minutes: 10),
        now: t0,
      ),
      extra: {'plugin': 1},
    );
    final json = item.toJson(t0);
    final back = InfoItem.fromJson(json);
    expect(back.text, '带图片');
    expect(back.icon, 'mail');
    expect(back.image, [1, 2, 3]);
    expect(back.sunk && back.detail, isTrue);
    expect(back.extra['plugin'], 1);
    expect(
      back.time!.remaining(t0.add(const Duration(minutes: 4))),
      const Duration(minutes: 6),
    );
  });

  test('store orders sunk items last and edits through one place', () {
    final a = InfoItem(id: 'a', text: 'a');
    final b = InfoItem(id: 'b', text: 'b');
    var saves = 0;
    final store = ItemStore([a, b], onSave: (_) => saves++);
    store.setSunk(a, true);
    expect(store.all.map((i) => i.id), ['b', 'a']);
    expect(store.pinned, b);

    store.appendText(b, '  more  ');
    expect(b.text, 'b more');

    final fresh = store.create();
    expect(store.pinned, fresh);
    expect(fresh.text, isEmpty);

    store.setTime(b, const Duration(minutes: 3), TimeKind.reminder);
    expect(b.time!.state(store.now), TimeState.running);
    store.setTime(b, const Duration(hours: 20), TimeKind.timer);
    expect(b.time!.remaining(store.now), TimeTag.max);
    expect(b.time!.kind, TimeKind.timer);

    store.pin(a);
    expect(a.sunk, isFalse);
    expect(saves, greaterThanOrEqualTo(6));
    store.dispose();
  });

  test('config falls back and clamps', () {
    final c = OneHitConfig.fromJson({
      'previewRadius': 40,
      'detailHeight': 5,
      'toggleHotkey': 7,
    });
    expect(c.previewRadius, 6);
    expect(c.detailHeight, 60);
    expect(c.toggleHotkey, 'ctrl+alt+o');
  });

  test('hotkey specs parse', () {
    final h = parseHotKey('Ctrl+Alt+Space')!;
    expect(h.key, PhysicalKeyboardKey.space);
    expect(h.modifiers, hasLength(2));
    expect(parseHotKey('win+shift+f9')!.key, PhysicalKeyboardKey.f9);
    expect(parseHotKey('hyper+q'), isNull);
  });

  test('tag zones sit outside the window and inside the screen', () {
    const work = Size(1920, 1040);
    for (final window in [
      const Rect.fromLTWH(1500, 200, 320, 52),
      const Rect.fromLTWH(10, 200, 320, 52),
      const Rect.fromLTWH(800, 400, 320, 52),
    ]) {
      final zones = layoutZones(builtInZones(), window, work);
      expect(zones, hasLength(3));
      for (final (_, r) in zones) {
        expect(r.overlaps(window), isFalse);
        expect(
          Offset.zero & work,
          predicate<Rect>((s) => s.contains(r.topLeft)),
        );
        expect(r.right <= work.width && r.bottom <= work.height, isTrue);
      }
    }
  });
}
