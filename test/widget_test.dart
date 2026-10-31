import 'package:flutter_test/flutter_test.dart';
import 'package:onehit/item/info_item.dart';
import 'package:onehit/item/info_item_view.dart';
import 'package:onehit/item/item_store.dart';

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
}
