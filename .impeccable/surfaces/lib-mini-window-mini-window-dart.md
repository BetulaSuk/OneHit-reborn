---
version: 1
slug: "lib-mini-window-mini-window-dart"
primary_target: "lib/mini_window/mini_window.dart"
related_targets: []
---

# Surface: OneHit minimal floating window

Mode: Operate. Always-on-top frameless strip that shows the single pinned info item; hover previews neighbours; wheel scrolls, left-click selects, middle-click returns; time-tagged items show countdown state.

Scope this round: display, hover preview, wheel/click/middle-click, countdown states (running / paused / ended), Timer vs Reminder auto behaviour, ended-Reminder alert row. Sample data, no persistence. Out of scope: right-click edit, create flow, tag drag, detailed window, hotkey.

Constraints: always light (user). Not a sticky note, not a shrunken todo app (user). State colours per docs/top-idea.md: green running, yellow/amber paused, red ended, green new-item box.

## Direction contract

THESIS: The countdown is an Activity ring unrolled into the strip: one pinned item, its time drawn as a thick round-capped lap. Refuses the Fluent widget card and the checkbox row.

OWN-WORLD: User-pinned: Apple Watch Activity-ring grammar, translated to a light ground. White pill strip, near-black ink, ring colours only for state: lime-green lap (running), amber (paused), ring-red (ended). Laps past one hour overlay in a deeper shade with a short gradient blend at the lap start. Round caps everywhere; no dividers, no borders except the ended ring.

STORY: The user glances, reads the one thing and how long is left, scrolls to swap, clicks the time to pause, and gets back to work.

FIRST VIEWPORT: 320×52 white pill on the desktop. Left: 36px icon disc. Middle: item text, 15px semibold. Right: remaining time, 20px bold tabular. The lap fills the pill behind the content from the left. Hover: neighbour rows fade above and below; green add slots at both list ends.

FORM: User-pinned direction (Activity rings) overriding roll candidate 5 (Platform Clock). seed:537ced2349bc14b2

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
