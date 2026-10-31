import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'item/info_item.dart';
import 'item/item_store.dart';
import 'mini_window/mini_window.dart';
import 'theme/tokens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  // window_manager scales bounds by the view's ratio, so the screen size
  // must be converted with the same one.
  final dispatcher = PlatformDispatcher.instance;
  final screen =
      dispatcher.displays.first.size / dispatcher.views.first.devicePixelRatio;
  // Leave room above for the hover preview and reminder alerts.
  final anchor = Offset(
    screen.width - OH.stripWidth - 40,
    40 + 2 * OH.rowPitch,
  );

  const options = WindowOptions(
    titleBarStyle: TitleBarStyle.hidden,
    backgroundColor: Colors.transparent,
    skipTaskbar: true,
    alwaysOnTop: true,
    title: 'OneHit',
  );
  windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.setAsFrameless();
    await windowManager.setHasShadow(false);
    await windowManager.setBackgroundColor(Colors.transparent);
    await windowManager.setBounds(
      Rect.fromLTWH(
        anchor.dx - OH.margin,
        anchor.dy - OH.margin,
        OH.stripWidth + OH.margin * 2,
        OH.stripHeight + OH.margin * 2,
      ),
    );
    await windowManager.show();
  });

  runApp(OneHitApp(store: ItemStore(sampleItems()), anchor: anchor));
}

class OneHitApp extends StatelessWidget {
  const OneHitApp({super.key, required this.store, required this.anchor});

  final ItemStore store;
  final Offset anchor;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      color: Colors.transparent,
      theme: ThemeData(
        canvasColor: Colors.transparent,
        scaffoldBackgroundColor: Colors.transparent,
        fontFamily: OH.face,
        fontFamilyFallback: OH.faceFallback,
      ),
      home: Material(
        type: MaterialType.transparency,
        child: MiniWindow(store: store, anchor: anchor),
      ),
    );
  }
}

/// Synthetic demo items until persistence exists.
List<InfoItem> sampleItems() => [
  InfoItem(
    id: 'reply',
    text: '回复王老师的论文修改意见',
    icon: Icons.mail_rounded,
    time: TimeTag(
      kind: TimeKind.reminder,
      remaining: const Duration(minutes: 42, seconds: 18),
    ),
  ),
  InfoItem(
    id: 'meeting',
    text: '组会：带上周的实验数据',
    icon: Icons.groups_rounded,
    time: TimeTag(
      kind: TimeKind.reminder,
      remaining: const Duration(hours: 1, minutes: 40),
    ),
  ),
  InfoItem(
    id: 'pomodoro',
    text: '番茄钟 · 整理参考文献',
    icon: Icons.menu_book_rounded,
    time: TimeTag(
      kind: TimeKind.timer,
      remaining: const Duration(minutes: 18, seconds: 20),
      running: false,
    ),
  ),
  InfoItem(
    id: 'e2e',
    text: '发版前跑一遍 e2e',
    icon: Icons.rocket_launch_rounded,
    time: TimeTag(kind: TimeKind.reminder, remaining: Duration.zero),
  ),
  InfoItem(id: 'receipt', text: '提交本月报销单', icon: Icons.receipt_long_rounded),
  InfoItem(id: 'milk', text: '买牛奶和鸡蛋', icon: Icons.shopping_basket_rounded),
  InfoItem(id: 'meter', text: '给房东发水电读数', icon: Icons.bolt_rounded, sunk: true),
];
