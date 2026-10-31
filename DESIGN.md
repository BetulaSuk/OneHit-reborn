---
name: OneHit
description: One pinned line on the desktop, its countdown drawn as an Activity ring unrolled into a pill.
colors:
  ground: "#ffffff"
  ink: "#111114"
  disc-fill: "#f0f0f3"
  run-track: "#edf9d9"
  run-lap: "#a3e635"
  run-over: "#6cc417"
  pause-track: "#fff2cf"
  pause-lap: "#ffc233"
  pause-over: "#f59e0b"
  pause-ink: "#7a4e00"
  end-ring: "#e0123f"
  end-ink: "#ffffff"
  end-track: "#fde2e8"
  add-ink: "#157a32"
  add-fill: "#e7f8ea"
typography:
  title:
    fontFamily: "Segoe UI Variable Display, Segoe UI, Microsoft YaHei UI"
    fontSize: "20px"
    fontWeight: 700
    lineHeight: 1
    fontFeature: "tnum"
  body:
    fontFamily: "Segoe UI Variable Display, Segoe UI, Microsoft YaHei UI"
    fontSize: "15px"
    fontWeight: 400
    lineHeight: 1.2
    letterSpacing: "-0.1px"
rounded:
  pill: "26px"
  disc: "18px"
spacing:
  unit: "4px"
  sm: "8px"
  md: "12px"
  lg: "16px"
  margin: "24px"
components:
  strip:
    backgroundColor: "{colors.ground}"
    textColor: "{colors.ink}"
    typography: "{typography.body}"
    rounded: "{rounded.pill}"
    padding: "0 16px 0 8px"
    width: "320px"
    height: "52px"
  strip-running:
    backgroundColor: "{colors.run-track}"
    textColor: "{colors.ink}"
    rounded: "{rounded.pill}"
  strip-paused:
    backgroundColor: "{colors.pause-track}"
    textColor: "{colors.pause-ink}"
    rounded: "{rounded.pill}"
  strip-ended:
    backgroundColor: "{colors.end-ring}"
    textColor: "{colors.end-ink}"
    rounded: "{rounded.pill}"
  lap-running:
    backgroundColor: "{colors.run-lap}"
    rounded: "{rounded.pill}"
    height: "52px"
  lap-running-overflow:
    backgroundColor: "{colors.run-over}"
    rounded: "{rounded.pill}"
    height: "52px"
  lap-paused:
    backgroundColor: "{colors.pause-lap}"
    rounded: "{rounded.pill}"
    height: "52px"
  lap-paused-overflow:
    backgroundColor: "{colors.pause-over}"
    rounded: "{rounded.pill}"
    height: "52px"
  icon-disc:
    backgroundColor: "{colors.disc-fill}"
    textColor: "{colors.ink}"
    rounded: "{rounded.disc}"
    size: "36px"
  time-cell:
    textColor: "{colors.ink}"
    typography: "{typography.title}"
  time-cell-paused:
    textColor: "{colors.pause-ink}"
    typography: "{typography.title}"
  time-cell-ended:
    textColor: "{colors.end-ink}"
    typography: "{typography.title}"
  add-slot:
    backgroundColor: "{colors.add-fill}"
    textColor: "{colors.add-ink}"
    typography: "{typography.body}"
    rounded: "{rounded.pill}"
    width: "320px"
    height: "52px"
---

# Design System: OneHit

## Overview

**Creative North Star: "The Unrolled Ring"**

OneHit is a single white pill that stays on top of the Windows desktop. It shows the one item that matters right now, and when that item is timed, its remaining time is drawn the way an Apple Watch Activity ring fills: a thick, round-capped lap growing across the pill from the left. One lap is one hour. Time past the first hour is laid over it as a deeper lap of the same hue, blending in near the lap start and casting a soft shadow at its cap, like a ring passing its own start. The user chose this world ("like the ring of apple watch sports") over the contract's candidate direction. It is translated onto an always-light ground: white pill, near-black ink, and ring colour only where it carries state.

Density is extreme by design. At rest the window is exactly one 320×52 strip, plus a red pill above it for each Reminder that ended while it was not pinned. On hover the OS window grows above and below, and neighbouring items fade in as stacked pills while the pinned strip stays put on screen. Nothing else exists: no header, no footer, no dividers, no chrome. Every interaction acts directly on the pills: wheel to scroll, click to pin, middle-click to return, click the time to pause, drag the strip to move the window.

Confirmed rejections from the user: it must not read as a sticky note (便利贴), and it must not read as a shrunken todo app (待办 App 缩小版), so no checkbox rows, no paper or tape textures, and no Fluent widget card.

**Key Characteristics:**
- One 320×52 full-pill strip on a 4px geometry unit; the window is the pill.
- Colour only as state: lime running, amber paused, solid red ended. Each state has a track, a lap and an overflow lap.
- The lap is the countdown: one lap is one hour, deeper overflow lap past the hour, up to 12 hours.
- Preview rows fade by distance. The ground stays near-opaque, ink fades, and laps pale toward their own track.
- Round caps and stadium shapes everywhere; the only stroke is the add slot's outline.

## Colors

A white and near-black ground with three state hues borrowed from the Activity rings, each in a track, lap and overflow-lap step, plus one action green for adding.

### Primary
- **Ring Lime** (run-lap): the running lap, filling the pill from the left for the first hour remaining.
- **Deep Lime** (run-over): the overflow lap laid over Ring Lime for time past one hour; it blends from Ring Lime over the first 1.5 strip heights of its length.
- **Lime Track** (run-track): the unfilled ring behind a running countdown, and what Ring Lime pales toward in preview rows.

### Secondary
- **Pause Amber** (pause-lap): the paused lap. The whole strip switches hue the moment the countdown is paused.
- **Deep Amber** (pause-over): the paused overflow lap.
- **Amber Track** (pause-track): the unfilled ring behind a paused countdown.
- **Amber Ink** (pause-ink): the remaining time and pause/play glyph while paused. It is the only ink besides near-black and white.

### Tertiary
- **Ring Red** (end-ring): an ended countdown. The ring closes into a solid red pill, and both the item text and the time switch to white.
- **Red Track** (end-track): what the red pill pales toward in preview rows. Ended-row ink lerps from white back to Ring Red as the pill pales, so it stays readable.
- **Add Green** (add-ink) on **Add Mint** (add-fill): the "新建信息" slots at both ends of the list. This is an action colour, not a state.

### Neutral
- **Pill White** (ground): the strip surface. It is always light and never follows the OS dark theme. Preview rows keep it at 94% to 100% alpha, so the desktop never shows through.
- **Near-Black Ink** (ink): item text, the running time, and the disc icon.
- **Disc Grey** (disc-fill): the 36px icon disc behind an item's glyph or image.

### Named Rules
**The State-Only Colour Rule.** Hue appears only to say running, paused or ended (plus the green add affordance). An untimed item is white and near-black, with no accent at all.

**The Three-Step State Rule.** Every state has a track, a lap and an overflow lap in one hue. A new state must bring all three, never a single swatch.

**The Pale-Toward-Track Rule.** A preview row fades by lerping its lap colours toward that state's own track and fading its ink. It never desaturates to grey and never lowers the ground's opacity below 94%. The pinned strip is always the most saturated row.

## Typography

**Display Font:** Segoe UI Variable Display (with Segoe UI, Microsoft YaHei UI for CJK)
**Body Font:** the same stack

**Character:** One Windows-native family at two steps. The bold tabular time is the loudest thing in the window; the item text sits quietly beside it.

### Hierarchy
- **Title** (700, 20px, line-height 1, tabular figures): the remaining time, `m:ss` under an hour and `h:mm:ss` above. Tabular figures keep the digits still while they tick.
- **Body** (400, 15px, line-height 1.2, -0.1px tracking): the item text, one line, truncated with an ellipsis. Also the add-slot label.

The user can change the family and the body size (12 to 20px) in settings. The title follows at a third larger, rounded, and panel text steps down from the body size (body −1, hints −3). The sizes above are the defaults. Every style keeps the default stack as its fallback, so glyphs a chosen font lacks still come from Segoe UI or Microsoft YaHei UI.

### Named Rules
**The One-Weight-Per-Line Rule.** Item text stays at 400. Microsoft YaHei UI has no semibold, so any heavier weight renders CJK bold next to lighter Latin. The contract called for 15px semibold; the build settled on 400 for this reason, and the build is canonical.

**The Still Digits Rule.** Any countdown or clock figure uses tabular figures.

## Layout

Everything sits on a 4px unit. The strip is 320×52 (80×13 units). Inside it, the 36px disc starts 8px from the left edge, a 12px gap separates it from the text, the time sits 8px after the text with a 4px gap before its glyph, and 16px of padding closes the right side. A transparent 24px margin surrounds the content so the lift shadow is never clipped by the OS window.

Preview rows stack on a 56px pitch (52px strip + 4px gap). By default the preview shows two rows above and two below the strip. Opacity falls by 0.375 per row of distance, to about 0.25 at the edge, and the rows outside that range are cut. The pinned strip never moves on screen: the window grows upward and downward around it. Ended Reminders stack directly above the strip at rest on the same pitch.

**Screen edges.** Near the top or bottom edge, rows that have no room on one side go to the other, keeping the total; when one side holds more than two rows, the fade per row slows (0.75 ÷ rows) so the last row still lands near 0.25. When there is not room for a full set of rows below, the list runs upward: the items after the pinned one stack above it, and wheel-down still moves rows up. Ended Reminders go below the strip when they do not fit above. The inline editor and the detail card grow downward; when they would cross the bottom edge, the whole block rises to end 8px above it, and returns when it shrinks back. This is the one time the strip moves without being dragged.

The window is a fixed-size desktop surface. There are no breakpoints.

## Elevation & Depth

The system is flat except for one lift. The pinned strip floats on a soft two-layer ambient shadow; preview rows sit flat beneath it, and nearer rows paint over farther ones. Inside the pill, depth belongs to the ring: the lap casts a faint shadow at its cap, and the overflow lap casts a slightly stronger one, which is how the second lap visibly passes over the first.

### Shadow Vocabulary
- **Lift** (`0 8px 24px rgba(0,0,0,0.12), 0 1px 3px rgba(0,0,0,0.08)`): the pinned strip only.
- **Lap cap** (Flutter `drawShadow`, elevation 2, `#00000033`): the end of the first-hour lap.
- **Overflow cap** (Flutter `drawShadow`, elevation 3, `#00000055`): the end of the overflow lap.

### Named Rules
**The One Lift Rule.** Among the pills, only the pinned strip casts a shadow. Preview rows, alerts and add slots are flat. Detached panels (side editor, settings, about, the shortcut hint) carry the same Lift, because they float beside the strip rather than in its stack.

## Shapes

The form language is the stadium. The strip, the laps, the add slot and the ended pill are all full pills (26px radius on a 52px height). The disc is a full circle. A lap is never narrower than a circle the height of the strip, so even a few seconds remaining reads as a round cap rather than a sliver. Content is clipped to the pill. There are no dividers and no borders, except the add slot's 1.5px Add Green outline.

## Components

### Strip (signature component)
The item pill. It is calm when untimed and becomes a ring when timed.
- **Shape:** full pill (26px), 320×52, carrying the Lift shadow when pinned.
- **Untimed:** Pill White ground, Disc Grey disc, Near-Black body text.
- **Running:** Lime Track fills the pill. The Ring Lime lap grows from the left (one lap = one hour); past the hour, the Deep Lime overflow lap is laid over it with a gradient blend at its start and a cap shadow.
- **Paused:** the same anatomy in Amber Track, Pause Amber and Deep Amber, with Amber Ink time.
- **Ended:** a solid Ring Red pill with white text and time. The time cell is no longer interactive.
- **Preview:** ground at 94% to 100% alpha, content opacity equal to the row's fade, laps lerped toward their track.

### Lap
Painted, not a widget. Its width is `height + (width - height) × fraction`, with the cap radius half the strip height. Maximum duration is 12 hours (12 laps).

### Time Cell
- **Typography:** Title.
- **Ink:** Near-Black when running, Amber Ink when paused, white when ended (lerping to Ring Red in fading previews).
- **Interaction:** click toggles pause and resume, with a pointer cursor. An 18px pause/play glyph fades in over 180ms on hover while running, stays visible while paused, and morphs between pause and play over 320ms with an expo-out curve.

### Icon Disc
A 36px Disc Grey circle that holds a 20px rounded Material icon in Near-Black, or the item's image cropped to cover.

### Add Slot
A strip-sized Add Mint pill with a 1.5px Add Green outline, a 20px add icon and the "新建信息" label in Add Green body type, centred. It sits at both ends of the preview list, and it is the strip itself when nothing is pinned. Clicking it creates an item and opens the inline editor on it.

### Preview Stack
- **Enter:** hovering grows the window, then the rows fade in over 180ms.
- **Leave:** after a 140ms grace period, the rows fade out, the scroll returns to the pinned item over 320ms, and the window shrinks.
- **Scroll:** wheel steps one row per 40 units of scroll delta, settling over 320ms with expo-out. The add slots bound the range.
- **Pin and return:** clicking a row pins it and glides it into the strip position. Middle-click returns to the pinned item.
- **Drag:** a plain drag on the strip moves the window. Long press lifts the item for tag drag: the window dims to 40% and the tag zones fade in beside it.

### Panel
The detached surface for everything that is not an item: the side editor, settings, about, and the shortcut hint.
- **Shape:** Pill White card, 20px radius, Lift shadow, 16 to 20px padding. Settings is 400px wide and scrolls when taller than the screen; about is 340px; the hint is 240px.
- **Placement:** beside the strip or list, on whichever side has room, vertically centred on it and kept 8px inside the screen.
- **Sections:** a small bold Ink Soft label over the rows.
- **Controls:** pills on Disc Grey that turn Near-Black with white text when selected (display choice, toggles); round Disc Grey icon buttons; steppers (− value +) in one Disc Grey pill.
- **Key chip:** a 28px-high Disc Grey pill holding a key name in bold body type with tabular figures, hugging its label. While recording, it turns Near-Black and reads "按下按键…".

### Tray and app mark
The tray icon and the about panel's mark are the same drawing: a Near-Black disc carrying three quarters of a Ring Lime lap on a dim green track, the ring in its running state. The tray menu is the native Windows menu.

### Not designed yet
These are open, not specified: the ring-close motion when a countdown reaches zero (today the strip simply switches to the red pill), and any persistence-related UI. Inline editing, tag drag and its drop zones, and the detail card are built, and the README describes them, but they have not been through a design pass.

## Do's and Don'ts

### Do:
- **Do** keep every length a multiple of the 4px unit, and every surface a full pill or circle.
- **Do** express state only through the track, lap and overflow-lap triplet of its hue, and switch the whole strip's hue on a state change.
- **Do** keep the ground near-opaque (at least 94% alpha) in preview rows, and fade ink and pale laps toward their own track instead.
- **Do** set countdown figures at 20px, weight 700, with tabular figures, and item text at 15px, weight 400.
- **Do** reserve the Lift shadow for the pinned strip.

### Don't:
- **Don't** make the window dark or follow the OS theme; the pill is always light.
- **Don't** let it read as a sticky note (便利贴) or a shrunken todo app (待办 App 缩小版): no checkboxes, no paper or tape, no list chrome, header or footer.
- **Don't** add dividers or borders between or inside pills; the add slot's outline is the only stroke.
- **Don't** set item text above weight 400 in this font stack; CJK and Latin weights split.
- **Don't** use colour decoratively or on untimed items.
