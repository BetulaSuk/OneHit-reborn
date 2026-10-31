# OneHit

一键唤起的轻量信息缓存区 — an always-on-top floating window for Windows that
keeps the one piece of information you need next in view.

Information and tasks are the same thing here: an item is a line of text, an
icon, and tags. A countdown is drawn as an Activity-style ring unrolled into
the item's pill: lime while running, amber while paused, solid red when it
ends.

## Features

Everything in [`docs/top-idea.md`](docs/top-idea.md) is built.

| Where | What you do | What happens |
| --- | --- | --- |
| Strip | Hover | Neighbouring items fade in above and below; the strip stays put |
| Strip | Wheel / left click / middle click | Scroll / pin an item / return to the pinned one |
| Strip | Click the time | Pause or resume the countdown |
| Strip | Right click an item | Edit its text in place (Enter saves, Shift+Enter new line, Esc cancels; an emptied item is deleted) |
| Strip | Click the add slot | Creates an item and opens it for editing |
| Strip | Drag | Moves the window; the position is saved |
| Strip | Double click | Opens the list (at most half the screen high) |
| List | Middle click | Scrolls back to the top |
| List | Double click the header | Shrinks back to the strip (so does Esc or the corner button) |
| List | Double click or right click an item | Opens the side editor beside its row: text, icon palette, tags, delete. It follows the row and closes for good once the row scrolls out of view |
| Strip or list | Long press and drag an item | The window dims and tag zones appear around it; drop on one to apply it |
| Tag: 下沉 / 上浮 | Drop | Sinks the item to the bottom (dimmed, timer paused), or floats it back |
| Tag: 时间 | Drop | Opens the ring dial: drag the knob, scroll the ring (±5 min), hours (±1 h) or minutes (±1 min); one lap per hour, up to 12 h; Reminder or Timer |
| Tag: 详细 | Drop | The pinned strip grows a detail card with the full text |
| Any item | Drop an image file or image URL on it | It becomes the item's icon (centre-cropped to 128 px) |
| Any item | Drop or paste text | Appended to the item's text (with nothing selected, a paste creates a new item) |
| Window | Paste an image (Ctrl+V) | Replaces the selected item's icon |

Timers run only while their item is pinned; Reminders always run; sunk items
pause. An ended Reminder that is not pinned stays above the strip.

The OS window covers the screen's work area, but only the drawn surfaces take
the mouse (a native click region), so the rest of the desktop stays usable.

### Hotkeys

| Default | Action |
| --- | --- |
| `Ctrl+Alt+O` | Hide or show OneHit |
| `Ctrl+Alt+L` | Open or close the list |

Global hotkeys that another app already holds fail silently (the Windows
plugin does not report it); pick another key in `config.json` if one does
nothing.

### Data and config

Saved under `%APPDATA%\dev.onehit\onehit\`:

- `items.json` — the items, including icons and countdown state.
- `state.json` — the strip's last position.
- `config.json` — written with defaults on first run; edit it and restart.

| Key | Default | Meaning |
| --- | --- | --- |
| `previewRadius` | `2` | Items shown above and below the strip on hover |
| `detailHeight` | `160` | Height of the detail card |
| `toggleHotkey` | `"ctrl+alt+o"` | `ctrl` / `alt` / `shift` / `win` + a letter, digit, `f1`–`f12`, `space`, `enter`, `tab`, `esc` or `` ` `` |
| `listHotkey` | `"ctrl+alt+l"` | Same format |

Bad values fall back to the defaults. Delete the data files to see the
first-run tips again.

### Plugins

A plugin implements `OneHitPlugin` (`lib/plugin.dart`) and is added to the
`plugins` list in `lib/main.dart`. It can contribute `TagZone`s, which appear
next to the built-in tags during a drag and get the store and the dropped
item in `onDrop`. It can also watch the `ItemStore` in `attach`. A plugin
keeps its own per-item data in `InfoItem.extra`, which is saved with the item.

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
  main.dart                     startup: load data, size the window to the work area, plugins
  config.dart                   config.json options
  plugin.dart                   OneHitPlugin, TagZone, built-in tags
  theme/tokens.dart             design tokens: geometry, state colours, type, motion
  item/                         the item component, independent of the windows
    info_item.dart              InfoItem and TimeTag (countdown derived from the wall clock)
    item_store.dart             item list, 1 Hz tick, Timer/Reminder rules, edits
    storage.dart                JSON files in the app support folder
    info_item_view.dart         the pill: icon disc, text, time cell, LapPainter
    item_cards.dart             detail card, inline editor, add slot
    item_gestures.dart          click / double click / right click / long press / move
    icon_image.dart             image file, URL or clipboard → 128 px icon
  shell/                        the screen-sized window that hosts everything
    shell.dart                  state: mini/list, selection, tag drag, dial, drops, paste, hotkeys
    regions.dart                HitRegion widgets → native click region
    native.dart                 bridge to the runner: click region, OLE drops
    hotkeys.dart                hotkey parsing and registration
  mini_window/mini_window.dart  the strip: hover preview, scroll, pin, inline edit
  list_window/list_window.dart  the list and its side-editor layer
  editor/side_editor.dart       the side editor
  tags/tag_layer.dart           tag zones and the dragged item
  tags/time_dial.dart           the ring dial
windows/runner/native_bridge.*  SetWindowRgn click region and OLE drop target
test/                           countdown rules, JSON, store, config, hotkeys, zone layout, editor keys
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
