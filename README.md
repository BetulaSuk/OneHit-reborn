# OneHit

一键唤起的轻量信息缓存区 — an always-on-top floating window for Windows that
keeps the one piece of information you need next in view.

Information and tasks are the same thing here: an item is a line of text, an
icon, and tags. A countdown is drawn as an Activity-style ring unrolled into
the item's pill: lime while running, amber while paused, solid red when it
ends.

## Status

The **minimal floating window** is built and runs on sample data
(`sampleItems()` in `lib/main.dart`).

| Works now | Not built yet |
| --- | --- |
| Pinned item shown as a single pill strip | Adding items (the add slot does nothing on click) |
| Hover: neighbouring items fade in above and below; the strip stays put | Editing, tag drag (long press is reserved for it) |
| Wheel to scroll, left click to pin, middle click to return | Detailed window, global hotkey |
| Click the time to pause or resume, with a pause/play morph | Persistence (nothing is saved between runs) |
| Timer runs only while pinned; Reminder always runs; sunk items pause | Ring-close animation when a countdown hits zero |
| Ended reminders that aren't pinned stay above the strip | Click-through on the transparent shadow margin |
| Drag the strip to move the window | |

## Run

Requires Flutter 3.47+ with Windows desktop support.

```bash
flutter pub get
```

```bash
flutter run -d windows
```

```bash
flutter test
```

## Layout

```
lib/
  main.dart                 window setup (frameless, transparent, always on top) and sample data
  config.dart               user-tunable options (preview radius)
  theme/tokens.dart         design tokens: geometry, state colours, type, motion
  item/info_item.dart       InfoItem and TimeTag (countdown state derived from the wall clock)
  item/item_store.dart      item list, 1 Hz tick, Timer/Reminder rules
  item/info_item_view.dart  the pill: icon disc, text, time cell, LapPainter
  mini_window/mini_window.dart  rest/hover window sizing, scroll, pin, drag
windows/runner/             runner tweaks: 368x100 start size, no auto-show (Dart shows the window)
test/widget_test.dart       countdown, Timer/Reminder rules, time formatting
```

## Docs

- [`docs/top-idea.md`](docs/top-idea.md) — the original product concept (Chinese).
- [`PRODUCT.md`](PRODUCT.md) — users, purpose, constraints, open questions, principles.
- [`DESIGN.md`](DESIGN.md) — the design system ("The Unrolled Ring"): colours, type,
  layout, components, and rules. Its machine-readable sidecar is
  [`.impeccable/design.json`](.impeccable/design.json).
- `.impeccable/` — design-process records: the direction brief for the minimal window
  (`surfaces/`), the direction sketches that were weighed (`mocks/decision/`), and
  screenshots of the shipped build used in review (`review/`).
