import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onehit/config.dart';
import 'package:onehit/item/info_item.dart';
import 'package:onehit/item/info_item_view.dart';
import 'package:onehit/item/item_store.dart';
import 'package:onehit/plugin.dart';
import 'package:onehit/shell/keys.dart';
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
      'prefix': 'q',
      'fontSize': 99,
      'keys': {'list': 'f4', 'edit': 'nope'},
    });
    expect(c.previewRadius, 6);
    expect(c.detailHeight, 60);
    expect(c.prefix, 'ctrl+alt+o');
    expect(c.fontSize, 20);
    expect(c.keyFor(Command.list), 'f4');
    expect(c.keyFor(Command.edit), 'e');
  });

  test('binding a taken key swaps it', () {
    final c = const OneHitConfig().bind(Command.list, 'n');
    expect(c.keyFor(Command.list), 'n');
    expect(c.keyFor(Command.create), 'l');
    expect(c.commandFor('n'), Command.list);
    expect(c.bind(Command.list, 'l').keys, isEmpty);
  });

  test('prefix chords parse', () {
    final c = Chord.parse('Alt+Ctrl+Space')!;
    expect(c.modifiers, ['ctrl', 'alt']);
    expect(c.flags, 3);
    expect(c.virtualKey, 0x20);
    expect(c.label, 'Ctrl + Alt + Space');
    expect(Chord.parse('win+shift+f9')!.virtualKey, 0x78);
    expect(Chord.parse('hyper+q'), isNull);
    expect(Chord.parse('q'), isNull);
    expect(keyNameOf(0x4c), 'l');
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
