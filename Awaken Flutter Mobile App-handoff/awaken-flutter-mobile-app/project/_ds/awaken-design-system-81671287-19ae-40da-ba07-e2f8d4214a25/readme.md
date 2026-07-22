# Awaken Design System

Gamified alarm + fitness app: alarms are dismissed by performing camera-verified exercises (squats,
push-ups), and outdoor runs that close a geographic loop capture "territory" on a shared map.
Built with Flutter for Android and iOS; Android is the primary/lead platform.

## Sources

- **Codebase:** [`CodeStorm-Hub/awaken_v1`](https://github.com/CodeStorm-Hub/awaken_v1) (private repo,
  branch `master`) — the Flutter app itself. Explore further for the real, evolving source of truth:
  `lib/core/theme/` (theme/motion/shape tokens), `lib/features/*/presentation/pages/` (real screens
  and copy), `README.md` and `awaken_app_refined_plan.md` (architecture + phased roadmap).
- **Design/UX blueprint:** `awaken_app_ui_ux_plan.md` in the same repo — a from-scratch Material 3
  Expressive UI/UX plan (not yet fully implemented in code). This design system draws its visual
  direction from it; treat its screen-by-screen sections as intent, not shipped pixels.
- No Figma file, slide deck, or brand guideline doc was attached. No logo or brand mark exists in the
  repo (the iOS asset catalog only contains the default Flutter icon) — this system renders the
  wordmark "Awaken" in type wherever a mark would go. **If you have a real logo, brand guide, or
  Figma file, please attach it** so this system can be corrected against real brand assets.

Re-explore the repo directly for anything this system doesn't cover — it moves fast (see its own
README's "Status" section: Phase 2 of 6 is in progress as of this writing).

## What's actually built vs. planned

`awaken_v1` is an early, functionally-driven codebase (Phase 0–2 of a 6-phase plan). The screens that
exist are plain Material widgets proving out hard engineering problems (exact-alarm reliability
across OEMs, ML Kit pose verification, offline-first sync) — they have real, shippable copy but not
yet the full M3 Expressive visual treatment the UI/UX plan describes. **Territory mapping and the
Squad social hub are plan-only — no code exists for them yet.** This design system:
- builds its component library and token set from the UI/UX plan's explicit Material 3 Expressive
  direction (spring motion, M3 shape/type scale, M3 color roles) grounded in the exact numeric values
  the codebase already commits to (`shape_tokens.dart`, `motion_tokens.dart`, the seed color in
  `app_theme.dart`);
- recreates, as its UI kit, only the screens that actually exist in code today, with their real copy;
- does **not** invent a territory map or squad UI — that would be designing ahead of the source, which
  the brand's own repo doesn't yet define.

## Content fundamentals

Copy pulled directly from the app's real strings (`alarm_ring_page.dart`, `verification_page.dart`,
`workout_celebration_sheet.dart`, `battery_exemption_page.dart`, `alarm_reliability_test_page.dart`):

- **Second person, direct, imperative.** "Do 3 clean reps to calibrate.", "Keep going!", "Start
  Workout to Dismiss." Commands, not suggestions — fitting an app whose entire premise is forcing
  action.
- **Blunt about stakes, not cute about them.** "Time to squat!" / "Time to push up!" as the first
  thing a groggy user reads. No softening, no jokes at 6am.
- **Plain-English systems explanations, not jargon.** "Android can silently stop apps in the
  background to save power. If that happens to Awaken, your alarm may not ring." — a permission
  rationale written for someone who has never heard of Doze mode, not a changelog.
  "Wake-up tax applied (×1.5)" turns an internal penalty-multiplier concept into one plain phrase.
- **Always leaves an escape hatch, said plainly.** "I can't do this exercise today" — never traps a
  user, and says so without qualification or guilt.
- **Terse status language.** "PASS — fired 42s after scheduling.", "Can't see you clearly — step back
  or find better light.", "Nice work — alarm dismissed." Short clauses, em-dash to join cause/result.
- **Game terms treated as plain vocabulary, not decorated.** "streak", "wake-up tax", "territory" are
  dropped in matter-of-factly (a 4-day streak reads "4-day streak", not "🔥 4 day streak!!"). Confirms
  the no-emoji rule below.
- **No emoji, anywhere, in any real string.** The one celebratory glyph in the app (`Icons.emoji_events`
  — a trophy) is a Material icon glyph, not a Unicode emoji character.
- **Casing:** sentence case throughout — titles, buttons, dialog headers ("Schedule alarm", "Keep
  alarms reliable"). No title-case buttons, no all-caps.

## Visual foundations

The codebase's *actual* theming is a single seed color fed to `ColorScheme.fromSeed` — everything
below extrapolates from that seed plus the UI/UX plan's explicit Material 3 Expressive direction.

- **Color:** Material You dynamic color, seeded from `fallbackSeed = Color(0xFF2E7D32)` (a mid-tone
  brand green) when the platform has no wallpaper-extracted scheme (`app_theme.dart`). This system's
  `tokens/colors.css` computes a full M3 role set (primary/secondary/tertiary × container/on- pairs,
  error, surface, outline) from that same seed. Primary green marks high-prominence actions (workout
  CTAs); a teal tertiary is reserved for future map/territory surfaces: the plan explicitly assigns
  "secondary and tertiary key colors" to "filter chips on the geospatial map." Error red is used
  functionally (permission warnings) but also, unusually, as a **full-screen background** on the
  ringing-alarm screen (`colorScheme.errorContainer`) — deliberately urgent, not just a small badge.
- **Type:** Material 3's default type scale (Display/Headline/Title/Body/Label × Large/Medium/Small),
  used directly via `Theme.of(context).textTheme.*` in the app. The plan calls for a variable font
  (`Roboto Flex` or `Google Sans Flex`) so weight/width can flex to fit constrained layouts — this
  system substitutes Roboto Flex (see FONT SUBSTITUTION note below). Display-scale numerals are the
  app's real hero moment: the rep counter and countdown both render in `displayLarge`.
  Sentence case everywhere, including buttons and headers — never uppercase.
- **Shape:** a defined radius scale from 4dp to 48dp (`shape_tokens.dart`), rounded by default. One
  explicit, intentional exception: `sharpWarning` (zero radius) for the Wake-Up Tax penalty visualizer
  — the plan calls this out by name as deliberate visual tension against the app's otherwise rounded
  rhythm. Don't soften that one component; the sharpness is the point.
- **Motion:** physics-based springs, not duration/easing curves — hand-implemented in
  `motion_tokens.dart` because core Flutter doesn't ship M3 Expressive's spring system. Two families:
  *spatial* springs (position/scale/shape morphs) intentionally overshoot for a bounce; *effects*
  springs (opacity/color) never overshoot, to avoid jarring flashes. In the shipped app today, this
  shows up modestly — `workout_celebration_sheet.dart`'s trophy icon scales in with
  `Curves.easeOutBack`, the plan's own stated "close enough" stand-in until Flutter ships true spring
  support. This system's CSS motion tokens follow that same overshoot/no-overshoot split.
- **Backgrounds:** flat Material surfaces throughout — no photography, no illustration, no gradients,
  no textures/patterns. The one deliberate full-bleed background is functional: `errorContainer` red
  fills the entire ringing-alarm screen.
- **Hover/press states:** not yet custom-designed in code (stock Material ripple + state-layer
  opacity). Assume standard M3 state layers: ~8% opacity overlay on hover, ~12% on press/focus, in
  the foreground-on-background color pair.
- **Borders/shadows:** no custom border or shadow system yet; use Material 3's default elevation
  tiers (tokens included as `--elevation-1/2/3`) rather than inventing a bespoke shadow language.
- **Transparency/blur:** one real usage — `Colors.black54` behind the status banner text overlaid on
  the live camera feed during verification (`verification_page.dart`), so instructional text stays
  legible over unpredictable video. Not used decoratively elsewhere.
- **Imagery:** none shipped (no photography or illustration assets in the repo). The verification
  screen's only "imagery" is the user's own live front-camera feed with a skeletal pose overlay drawn
  in `CustomPaint` — not a design asset.
- **Layout:** single-pane, full-screen mobile views today (the plan's adaptive/multi-pane rail layouts
  for tablet/desktop are unbuilt). The ringing-alarm screen is a `PopScope(canPop: false)` — the one
  deliberately non-dismissible, non-navigable screen in the app; don't add a back affordance to its
  recreation.
- **Corner radii / cards:** list rows and dialogs use default Material `Card`/`ListTile` geometry —
  no custom card shadow+radius+border combination has been designed yet beyond the shape scale above.

## Iconography

The app uses Flutter's built-in **Material Icons** font exclusively (`Icons.add`,
`Icons.delete_outline`, `Icons.battery_charging_full`, `Icons.bug_report_outlined`,
`Icons.check_circle`, `Icons.warning_amber`, `Icons.emoji_events`, `Icons.videocam_off`, etc.) — no
custom icon set, no SVG icon files, no PNG icon assets, and no emoji anywhere in the UI. This system
substitutes **Material Symbols Outlined** (Google's current, actively-maintained superset of the
classic Material Icons font, same glyphs/metaphor set the app already draws from) loaded from Google
Fonts' CDN, used as a webfont via `.material-symbols` utility class in `tokens/fonts.css`'s import.
No substitution flag needed here — it's the same family, just the current distribution channel.

## Repo structure

```
styles.css                 — root: @imports every token file below (link this one file)
tokens/
  fonts.css                 — Roboto Flex (+ Roboto Mono) import, FONT SUBSTITUTION notes
  colors.css                — M3 color roles, light + dark, derived from the real seed color
  typography.css            — M3 type scale (Display/Headline/Title/Body/Label × L/M/S)
  spacing.css                — 4dp spacing scale
  shape.css                  — exact radii from shape_tokens.dart + elevation shadows
  motion.css                  — spring-derived duration/easing tokens
guidelines/                — foundation specimen cards (Design System tab: Colors, Type, Spacing,
                              Shape, Motion, Brand groups)
components/
  forms/                    — Button, IconButton, Chip
  feedback/                  — StatusBanner, Badge, ProgressSpinner
  data-display/              — Card, ListItem, RepCounter
  overlays/                  — Dialog
ui_kits/awaken-app/          — interactive recreation of the real, shipped screens: alarm list +
                              schedule dialog, ringing alarm, workout verification (camera + pose),
                              celebration sheet, battery-exemption onboarding, reliability self-test
SKILL.md                    — Claude Code-compatible skill wrapper for this system
```

## Index

- `styles.css` + `tokens/` — link `styles.css` for every token in this system.
- `guidelines/` — 13 specimen cards (Colors ×4, Type ×3, Spacing, Shape ×2, Motion, Brand ×2) in the
  Design System tab.
- `components/forms/` — Button, IconButton, Chip.
- `components/feedback/` — StatusBanner, Badge, ProgressSpinner.
- `components/data-display/` — Card, ListItem, RepCounter.
- `components/overlays/` — Dialog.
- `ui_kits/awaken-app/` — interactive click-through recreation of the alarm-schedule → ring →
  camera-verify → celebrate flow, plus battery-exemption onboarding and the reliability self-test.
- `SKILL.md` — Claude Code-compatible wrapper for using this system outside this tool.

## Intentional additions

- **Badge** and **ProgressSpinner** have no dedicated custom widget in the codebase (they use stock
  Material `CircularProgressIndicator` and ad hoc `Icon` + `Text` rows) — added as small reusable
  primitives since the same streak-badge and loading-spinner patterns repeat across screens.
