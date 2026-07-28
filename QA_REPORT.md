# Awaken — Automated QA Report

**Date:** 2026-07-28
**Method:** Android-MCP automation pass against a `flutter run --debug --flavor dev` build on `emulator-5554`, driving the UI directly (taps, swipes, snapshots) and cross-checking against the live `flutter run` / `adb logcat` output for exceptions and frame-skip warnings.
**Scope:** Home, Alarms (CRUD + preview ring), Territory (map + run tracking), Squad, Profile/Settings, nav shell. **Camera verification was explicitly excluded** (needs a real camera feed the emulator can't provide).

---

## Bugs found

### 1. Squad leaderboard shows a different area value than every other screen (data bug)
Home, Territory, and Profile all consistently show **0.05 km²** (0.049 rounded) for the signed-in user's territory. The Squad tab's own leaderboard — both the inline list and the "Leaderboards" bottom sheet (Global/Weekly filters too) — shows **0.06 km²** for the exact same user at the exact same moment.

This is a genuine inconsistency, not a rounding quirk (0.049 rounds to 0.05, not 0.06). Worth checking whether the squad leaderboard RPC/query reads a stale or differently-aggregated area column than `watch_owned_area` (used by Home/Territory/Profile).

**Repro:** Open Home (note km² owned) → open Profile (note Territory km²) → open Squad and compare your own row / the Leaderboards sheet.

### 2. `ListTile` ripple/selection effects are invisible inside a glass-style bottom sheet (caught Flutter assertion)
Confirmed 3 times in the running log:

```
ListTile background color or ink splashes may be invisible.
The ListTile is wrapped in a DecoratedBox that has a background color. Because ListTile paints its
background and ink splashes on the nearest Material ancestor, this DecoratedBox will hide those
effects.

ListTile:
  ListTile(selectedColor: Color(...), contentPadding: EdgeInsets.zero, onTap: Closure: () => void)
DecoratedBox:
  DecoratedBox(bg: BoxDecoration(color: Color(alpha: 0.9000, red: 1.0, green: 1.0, blue: 1.0, ...),
    border: Border.all(BorderSide(color: Color(alpha: 0.6000, ...), width: 0.5)),
    borderRadius: BorderRadius.only(topLeft: Radius.circular(28.0), topRight: Radius.circular(28.0))))
```

The `DecoratedBox` (translucent white bg, rounded top corners, thin border) matches the app's frosted-glass bottom-sheet style — seen on the Appearance theme picker sheet. The `ListTile`s inside (theme radio rows) never show their tap ripple/selection highlight because there's no `Material` ancestor between them and the sheet's own background decoration.

Not a crash, but a real, reproducible UX bug: taps in these sheets give no visual feedback.

**Repro:** Profile → Appearance → tap any of the System default / Light / Dark rows while `debugPrintRebuildDirtyWidgets`-style assertions are enabled (or just note the missing ripple visually).

**Suggested fix:** wrap the sheet's `ListTile` rows (or the row container) in `Material(type: MaterialType.transparency)` so ripple/selection paints correctly without breaking the frosted-glass look.

---

## Accessibility gaps found

### 3. Reps stepper (`-`/`+`) buttons have no semantic label or coordinates at all
In the Add/Edit Alarm sheet, every other control (exercise toggle, day-of-week toggles, save/cancel, time picker) appears in the accessibility tree with a label and tappable bounds. The reps `-`/`+` buttons never appear in the tree at all — a screen-reader user has no way to discover or operate the reps stepper.

Inconsistent with the rest of the app, which is otherwise WCAG-conscious (e.g. the 44×44 touch-target fix documented in `expressive_widgets.dart`'s `ProfileAvatarButton`).

**Suggested fix:** add `Semantics`/tooltip labels ("Decrease reps" / "Increase reps") to those `IconButton`s.

### 4. Map attribution "i" icon isn't exposed as a distinct interactive element
The small circled-i icon on both the Territory and Active Run maps doesn't register in the accessibility tree with its own label/bounds, unlike every other map control (zoom in/out, layers, center-map). Minor, but likely raw MapLibre attribution UI not wrapped in Flutter semantics.

---

## What worked correctly

- **Alarms**: add (time picker, exercise mode toggle, reps stepper, day-of-week recurrence), save confirmation snackbar, toggle on/off, delete with confirmation dialog + "Alarm deleted" snackbar, tap-to-preview ring screen (pulse animation, wake-up tax display), back navigation without state corruption.
- **Alarm reliability settings** (battery optimization exemption status) and **Run self-test** page: render correctly.
- **Territory map**: rival-territory layer toggle, zoom in/out, center-map, all re-render correctly.
- **Run tracking**: start, live timer, GPS-quality indicator, disabled "Close loop & capture" button while the loop isn't closed, discard confirmation dialog ("Discard this run?" → Discard/Keep running), clean return to the map afterward.
- **Squad**: leaderboard, invite-code copy (with snackbar confirmation), Nearby/Global and All-time/Weekly leaderboard filters, "Report member" dialog (text field + Cancel) — all functioned correctly aside from bug #1 above.
- **Profile**: territory/streak stats, live Appearance theme switching (System default / Light / Dark) applied instantly and rendered cleanly across Home and Alarms in dark mode with no contrast issues, settings navigation.
- No new Choreographer frame-skip warnings beyond the expected cold-start ones — no jank observed during any interaction.
- No crashes, no `FlutterError.onError` fatals anywhere in the session.

---

## Not covered

- **Camera verification / pose detection** — excluded per instruction; needs a real camera feed.
- **Onboarding flow / battery-exemption first-run page** — not reachable without a fresh install or full app-data reset, which would have torn down the existing signed-in test account/session state used for the rest of this pass.

---

## Suggested improvements (priority order)

1. Fix #1 — trace the squad leaderboard's area query back to whatever `watch_owned_area`/Home/Profile use, so all screens agree on the same territory-area figure.
2. Fix #2 — wrap the glass bottom sheet's `ListTile` rows in a transparent `Material` ancestor.
3. Fix #3 — add semantic labels to the reps stepper buttons (and spot-check other icon-only controls for the same gap).
4. Nice-to-have: an "Undo" affordance on the alarm-delete snackbar, since the delete flow already has a confirmation dialog but no way to recover after confirming.
