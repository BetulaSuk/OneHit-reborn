import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onehit/config.dart';
import 'package:onehit/item/info_item.dart';
import 'package:onehit/item/info_item_view.dart';
import 'package:onehit/item/item_gestures.dart';
import 'package:onehit/item/item_store.dart';
import 'package:onehit/plugin.dart';
import 'package:onehit/settings/settings_panel.dart';
import 'package:onehit/shell/keys.dart';
import 'package:onehit/shell/native.dart';
import 'package:onehit/shell/scroll_steps.dart';
import 'package:onehit/strings.dart';
import 'package:onehit/tags/tag_layer.dart';
import 'package:onehit/theme/controls.dart';
import 'package:onehit/theme/tokens.dart';

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

  test('the clock only notifies while a countdown runs', () {
    final paused = InfoItem(
      id: 'p',
      text: 'p',
      time: TimeTag(
        kind: TimeKind.reminder,
        remaining: const Duration(hours: 1),
        running: false,
      ),
    );
    final store = ItemStore([InfoItem(id: 'a', text: 'a'), paused]);
    var calls = 0;
    store.addListener(() => calls++);
    store.tick();
    expect(calls, 0);

    store.toggleTime(paused);
    expect(calls, 1);
    store.tick();
    expect(calls, 2);
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
      'language': 'fr',
    });
    expect(c.previewRadius, 6);
    expect(c.detailHeight, 60);
    expect(c.prefix, 'ctrl+alt+o');
    expect(c.fontSize, 20);
    expect(c.keyFor(Command.list), 'f4');
    expect(c.keyFor(Command.edit), 'e');
    expect(c.language, '');
    expect(OneHitConfig.fromJson({'language': 'en'}).language, 'en');
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

  test('an edit left empty keeps what the item had', () {
    final kept = InfoItem(id: 'a', text: 'call the bank');
    final blank = InfoItem(id: 'b', text: '');
    final pictured = InfoItem(id: 'c', text: '', image: Uint8List(4));
    final store = ItemStore([kept, blank, pictured]);

    kept.text = '';
    store.settleEmptyText(kept, 'call the bank');
    expect(kept.text, 'call the bank');
    expect(store.byId('a'), isNotNull);

    store.settleEmptyText(blank, '');
    expect(store.byId('b'), isNull);

    store.settleEmptyText(pictured, '');
    expect(store.byId('c'), isNotNull);
    store.dispose();
  });

  for (final language in ['zh', 'en']) {
    testWidgets('settings switch the API on and off ($language)', (
      tester,
    ) async {
      addTearDown(() => strings = Strings.of(''));
      strings = Strings.of(language);
      final saved = <OneHitConfig>[];
      final config = ConfigStore(const OneHitConfig(), onSave: saved.add);
      final store = ItemStore([InfoItem(id: 'a', text: 'a')]);
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: Center(
              child: SizedBox(
                height: 500,
                child: SettingsPanel(
                  config: config,
                  native: NativeBridge(),
                  store: store,
                  prefixFree: true,
                  onRecordPrefix: (_) {},
                  onClose: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final toggle = find.text(strings.allowApi);
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      expect(find.text(strings.allowApiHint), findsOneWidget);

      await tester.tap(toggle);
      await tester.pump();
      expect(config.value.apiEnabled, isTrue);
      expect(saved.single.apiEnabled, isTrue);

      await tester.tap(toggle);
      await tester.pump();
      expect(config.value.apiEnabled, isFalse);
      store.dispose();
    });
  }

  test('strip geometry grows with Windows text size', () {
    addTearDown(() => OH.scale = 1);
    final height = OH.stripHeight;
    final width = OH.stripWidth;
    OH.scale = 1.5;
    expect(OH.stripHeight, height * 1.5);
    expect(OH.stripWidth, width * 1.5);
    expect(OH.radius, OH.stripHeight / 2);
  });

  group('touch and pen on a row', () {
    late List<String> got;

    Future<Offset> pumpRow(WidgetTester tester) async {
      got = [];
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: ItemGestures(
              onTap: () => got.add('tap'),
              onSecondaryTap: () => got.add('edit'),
              onLongPressStart: (_) => got.add('drag'),
              child: const SizedBox(width: 200, height: 52),
            ),
          ),
        ),
      );
      return tester.getCenter(find.byType(SizedBox));
    }

    testWidgets('a quick touch tap is a tap', (tester) async {
      final at = await pumpRow(tester);
      final g = await tester.startGesture(at, kind: PointerDeviceKind.touch);
      await g.up();
      expect(got, ['tap']);
    });

    testWidgets('a touch hold released in place edits', (tester) async {
      final at = await pumpRow(tester);
      final g = await tester.startGesture(at, kind: PointerDeviceKind.touch);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      expect(got, isEmpty);
      await g.up();
      expect(got, ['edit']);
    });

    testWidgets('a touch hold then move starts a tag drag', (tester) async {
      final at = await pumpRow(tester);
      final g = await tester.startGesture(at, kind: PointerDeviceKind.touch);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await g.moveBy(const Offset(0, 40));
      expect(got, ['drag']);
      await g.up();
      expect(got, ['drag']);
    });

    testWidgets('a mouse long press starts the drag at once', (tester) async {
      final at = await pumpRow(tester);
      final g = await tester.startGesture(at, kind: PointerDeviceKind.mouse);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      expect(got, ['drag']);
      await g.up();
    });

    testWidgets('the pen barrel button edits', (tester) async {
      final at = await pumpRow(tester);
      final g = await tester.startGesture(
        at,
        kind: PointerDeviceKind.stylus,
        buttons: kPrimaryButton | kPrimaryStylusButton,
      );
      await g.up();
      expect(got, ['edit']);
    });
  });

  testWidgets('touchpad pans and wheel notches both step', (tester) async {
    final steps = <int>[];
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ScrollSteps(
          wheel: 40,
          pan: 40,
          onStep: steps.add,
          child: const ColoredBox(color: Color(0xFFFFFFFF)),
        ),
      ),
    );
    final center = tester.getCenter(find.byType(ColoredBox));

    // Fingers up 100px: content moves up, which scrolls down twice.
    final pad = TestPointer(1, PointerDeviceKind.trackpad);
    await tester.sendEventToBinding(pad.panZoomStart(center));
    await tester.sendEventToBinding(
      pad.panZoomUpdate(center, pan: const Offset(0, -100)),
    );
    await tester.sendEventToBinding(pad.panZoomEnd());
    expect(steps, [1, 1]);

    final mouse = TestPointer(2, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.hover(center));
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, -120)));
    expect(steps, [1, 1, -1]);
  });

  testWidgets('Tab reaches a pill and Enter or Space presses it', (
    tester,
  ) async {
    var on = false;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Center(
            child: PillToggle(
              label: 'Sink',
              icon: Icons.south_rounded,
              on: on,
              onTap: () => setState(() => on = !on),
            ),
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(on, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(on, isFalse);
    expect(
      tester.getSemantics(find.byType(PillToggle)),
      matchesSemantics(
        label: 'Sink',
        isButton: true,
        hasToggledState: true,
        isEnabled: true,
        hasEnabledState: true,
        isFocusable: true,
        isFocused: true,
        hasFocusAction: true,
        hasTapAction: true,
      ),
    );
  });
}
