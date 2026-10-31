import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

import 'config.dart';
import 'item/item_store.dart';
import 'item/storage.dart';
import 'plugin.dart';
import 'shell/native.dart';
import 'shell/shell.dart';
import 'theme/tokens.dart';

/// Custom plugins go here; each can add tag zones and watch the store.
final List<OneHitPlugin> plugins = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  final storage = Storage(await getApplicationSupportDirectory());
  final config = ConfigStore(
    await OneHitConfig.load(storage.config),
    onSave: storage.saveConfig,
  );
  applyFont(config.value);
  final store = ItemStore(await storage.loadItems(), onSave: storage.saveItems);
  for (final p in plugins) {
    p.attach(store);
  }

  // The window covers the chosen display's work area (not the whole
  // monitor, so Windows never treats it as a fullscreen app). Only the
  // drawn parts take the mouse; see shell/regions.dart.
  final native = NativeBridge();
  final work =
      (await native.placeOn(config.value.display))?.$2 ?? const Size(1280, 720);

  final saved = await storage.loadAnchor();
  final fallback = Offset(
    work.width - OH.stripWidth - 40,
    40 + 2 * OH.rowPitch,
  );
  final anchor =
      saved == null ||
          saved.dx < 0 ||
          saved.dy < 0 ||
          saved.dx > work.width - OH.stripWidth ||
          saved.dy > work.height - OH.stripHeight
      ? fallback
      : saved;

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
    // Dropping the frame can shift the bounds, so place it again.
    await native.placeOn(config.value.display);
    await windowManager.show();
  });

  runApp(
    OneHitApp(
      child: OneHitShell(
        store: store,
        config: config,
        storage: storage,
        native: native,
        zones: [...builtInZones(), for (final p in plugins) ...p.zones],
        anchor: anchor,
      ),
    ),
  );
}

class OneHitApp extends StatelessWidget {
  const OneHitApp({super.key, required this.child});

  final Widget child;

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
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: OH.ink,
          selectionColor: Color(0x33111114),
        ),
      ),
      home: Material(type: MaterialType.transparency, child: child),
    );
  }
}
