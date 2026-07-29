# Territory Map 3D / Game-Vibe Redesign Plan

Status: **planning only** — no code changed. Written 2026-07-30.
Scope: `lib/features/territory/**` (map rendering + surrounding UI), specifically
`TerritoryPage`, `ActiveRunPage`, `TerritoryMapStyle`/`TerritoryBasemapRecolor`,
`MapStyleLoader`, and the style assets in `assets/map/`.

Companion reading: `docs/awaken_app_refined_plan.md` (original scope), CLAUDE.md's
"Territory map rendering" section (load-bearing MapLibre Native gotchas already
discovered — dasharray data-expressions, `_styleReady` gating, degenerate rings,
symbol font).

---

## 1. What the feature actually is today (concept recap)

Awaken's territory mechanic: a user runs a real-world outdoor loop, GPS-tracked
client-side (`geolocator` + `kalman_dr` smoothing), and closes it by returning within
~30 m of the start after covering ≥400 m. On capture, the path is RDP-simplified and
sent to a `submit_run()` Postgres RPC that validates geometry/anti-cheat server-side,
polygonizes the loop, diffs it against rival territory (`ST_Difference`), and unions it
into the caller's owned land. The result is a set of `Territory` polygons rendered on a
MapLibre map, colored by ownership (mine/rival/neutral), with decay ("at risk" if
undefended), rival "steal-back" prompts, squad heatmaps, and gold bounty zones. Two
screens carry this: `TerritoryPage` (overview map + claim CTA) and `ActiveRunPage`
(live run tracking + loop-closure UI + capture).

This is conceptually an Ingress/Pokémon-GO-style "walk to conquer land" game. The gap
identified in review is that **the map currently reads as a utility map with a toggle-able
gimmick**, not as a game world.

## 2. Current-state findings (from code review)

### What already exists and works
- `fillExtrusionColor`/`fillExtrusionHeight`/`fillExtrusionBase` extrusion layer for
  territory polygons (`territory_page.dart`), height interpolated from `areaSqm` (0→160m
  over 0→20,000 sqm).
- A manual 3D toggle button that animates `CameraPosition.tilt` 0°↔45°.
- Ant-path animated dashed outlines for rival territory, pulsing outlines for at-risk
  territory, grow-in animation on new captures.
- A Pokémon-GO-inspired basemap recolor patch (`TerritoryBasemapRecolor`) already applied
  to OpenFreeMap's `liberty`/`dark` styles — water/parks/roads/POI recolored via
  `setLayerProperties`.
- A resilient 3-tier style loader (hosted → fallback URL → bundled offline style) — keep
  this, it is unrelated to the visual redesign and already hardened.

### Why it doesn't feel like a game (root causes)
1. **Extrusion height is imperceptible for realistic capture sizes.** The curve caps at
   160 m only at 20,000 sqm; a typical capture (hundreds–low-thousands of sqm) yields
   roughly single-digit-to-40 m of height — invisible at normal zoom/tilt.
2. **Extrusion color = flat 2D fill color at 0.8 opacity**, with no `light` block
   configured anywhere in the style. Translucent, unlit slabs read as "colored blocks,"
   not buildings.
3. **3D is opt-in and off by default** — at tilt 0° the extrusion layer is pixel-identical
   to the flat fill, so most users never see it.
4. **No real 3D city context.** OpenFreeMap's `building` layer *does* carry
   `render_height`/`render_min_height` (confirmed in research, §3 below) but nothing in
   this codebase renders it — surrounding buildings, roads, and terrain stay flat 2D even
   when the camera is tilted, so the player's own territory looks like a slab floating
   over a flat map rather than an integrated skyline.
5. **No sky/fog/lighting atmosphere** — nothing to sell depth at a glance.
6. **`ActiveRunPage` (where the player spends the actual play-session time) has none of
   this** — flat top-down map, plain line + two dots, no territory/bounty context, no
   game framing during the run itself.
7. Non-map UI is uniform frosted-glass Material chrome — clean, but generic; nothing
   territory/game-themed beyond stock Material icons.

## 3. What MapLibre + OpenFreeMap can actually support (research findings)

Confirmed via `maplibre_gl` (Flutter plugin) docs/changelog and MapLibre style-spec docs:

| Capability | Status | Notes |
|---|---|---|
| `fill-extrusion` layers | ✅ Solid, already used | `addFillExtrusionLayer` on controller since plugin v0.19 |
| Camera `tilt`/`bearing` | ✅ Solid, already used | `CameraPosition`/`CameraUpdate`, `easeCamera` w/ interpolation curves |
| OpenFreeMap `building` layer w/ `render_height` | ✅ Available now | No re-hosting needed — same tileset the app already pulls from |
| `sky` / 3D terrain (DEM) layers | ⚠️ Unconfirmed on Flutter plugin | No exposed controller API found for sky/terrain through v0.26.2; MapLibre Native has historically lagged JS here. **Needs a throwaway spike before being committed to design** (try raw style JSON `sky`/`terrain` block via `styleString` and see if Native renders it). |
| `hillshade` (2D raster-DEM shading) | ✅ Available | `addHillshadeLayer` exists; different from true 3D terrain exaggeration but adds cheap depth cues |

Known MapLibre Native constraints to design around (same family as the dasharray issue
already documented in CLAUDE.md):
- Filter changes on fill/fill-extrusion layers may not re-render until a camera nudge
  (maplibre-native#3039) — relevant for dynamically filtering "claimed vs unclaimed"
  buildings.
- Fill-extrusion can't render sloped/curved geometry — flat-topped only, fine for our
  building-block look.
- Real-device memory cost of extrusion+pitch at street zoom has been reported at
  900MB–1.6GB+ on iOS at zoom 17 (maplibre-native#4107) — must gate with `minzoom` and
  possibly a device/low-memory fallback.
- Pitch/rotate gesture conflicts with parent scroll views have been reported
  (flutter-maplibre-gl#683) — worth a hands-on gesture QA pass, not just code review,
  given `ActiveRunPage` already does imperative camera control.

**Bottom line: everything in this plan except the sky/terrain atmosphere layer is
supported by the existing `maplibre_gl: ^0.26.2` dependency with no package upgrade or
re-hosting required.** The sky/terrain piece is a stretch goal pending a spike.

## 4. Redesign goals

1. Make 3D the *default* visual language of both territory screens, not a hidden toggle.
2. Render real city buildings (via OpenFreeMap's `render_height`) so territory polygons
   sit inside a genuinely 3D world instead of floating over a flat map.
3. Make claimed territory read unmistakably as "yours" — solid (not translucent) colored
   blocks with a lit/shaded look, a glowing rim/outline, and a height curve that's visible
   at realistic capture sizes.
4. Extend the game-world framing into `ActiveRunPage` so the run itself feels like part of
   the conquest, not a separate utility screen.
5. Keep everything within the current package set (`maplibre_gl` stays; no Mapbox GL,
   no native custom renderer) and preserve the already-hardened style-loading resilience
   (3-tier fallback, `_styleReady` gating, degenerate-ring filtering, font pinning) —
   this redesign is additive to `TerritoryMapStyle`/`MapStyleLoader`, not a rewrite of them.

## 5. Proposed changes

### 5.1 Real 3D city buildings (new)
- Add a `city-buildings` `fill-extrusion` layer sourced from OpenFreeMap's existing
  vector `building` source-layer (both `liberty`/`dark` primary styles — confirm the
  bundled offline fallback's tileset either carries the same fields or simply skips this
  layer, since it's a last-resort low-zoom tier anyway).
- `fill-extrusion-height`: `['interpolate', ['linear'], ['zoom'], 14, 0, 16,
  ['get', 'render_height']]` (standard OpenMapTiles pattern), `fill-extrusion-base:
  ['get', 'render_min_height']`.
- Recolor buildings to fit the game palette (desaturated indigo/slate, distinct from
  territory colors) rather than leaving MapLibre's default gray — extend
  `TerritoryBasemapRecolor`'s existing per-style-tier patch pattern.
- Gate with `minzoom: 15` (or similar) both for visual sense (buildings are meaningless
  zoomed out) and to bound the reported memory cost from §3.
- Insert `belowLayerId` = the existing territory outline layers, so territory polygons
  visually sit "on top of" the city, not underneath it.

### 5.2 Territory extrusion rework (fix, not new)
- **Height curve**: rescale so a *typical* capture (per the code's own stated range of
  "tens to low thousands of sqm") reads as a clearly visible building, not a bevel —
  e.g. steeper interpolation at the low end, with a sensible floor (a minimum visible
  height even for tiny captures) and a cap tuned against real building heights nearby so
  large empires don't dwarf the skyline absurdly.
- **Opacity**: raise from 0.8 toward ~0.95–1.0 (solid) so it reads as a lit volume, not a
  translucent slab.
- **Add a rim-light / glow effect**: MapLibre has no native glow/bloom, so approximate it
  the way comparable implementations do — a slightly-larger, brighter-colored companion
  `line` layer (or a second extrusion outline pass) around each territory's footprint to
  fake an emissive edge, consistent with the existing ant-path/pulse animation patterns
  already in `territory_map_style.dart`.
- Keep the existing color-by-ownership (teal mine / red rival) but consider a
  slightly punchier, more saturated pair specifically for the extrusion fill (translucent
  UI-chrome teal/red don't need to match the solid 3D block colors 1:1).

### 5.3 3D-by-default camera
- Default `TerritoryPage` to a tilted camera (e.g. 45–55°) on load instead of requiring
  the manual toggle; keep the existing toggle button but repurpose it as a "look straight
  down" / top-down-for-navigation escape hatch rather than the primary way to discover 3D.
- Consider a brief auto-rotate or fly-in camera animation on first load per session (using
  the already-available `easeCamera`/interpolation curves) as a "welcome to your empire"
  moment — low-cost, no new capability needed.
- Respect reduce-motion settings already used elsewhere in this feature (`_PulsingDot`
  pattern) for both the tilt-in animation and any auto-rotate.

### 5.4 Extend the game world into `ActiveRunPage`
- Default the live-run map to a tilted camera as well (currently always flat top-down),
  consistent with `TerritoryPage`.
- Render the same `city-buildings` extrusion layer here too, so the run itself takes
  place "inside" the 3D world.
- Show minimal territory/bounty context during the run (e.g. nearby owned/rival
  boundaries, bounty zone glow) rather than the current bare line+dots, so the
  conquest framing doesn't disappear the moment a run starts.

### 5.5 Atmosphere (stretch goal, spike-gated)
- If the sky/terrain spike from §3 confirms MapLibre Native support through the Flutter
  plugin: add a `sky` layer (gradient/atmospheric) and light `fog` to sell depth at the
  tilted angle, matched to light/dark theme.
- If unsupported: fall back to a raster `hillshade` layer for a cheaper depth cue, or skip
  atmosphere entirely for v1 — this should not block §5.1–5.4, which deliver the bulk of
  the visual improvement on their own.

### 5.6 Capture moment
- Tie the existing grow-in animation (`_animateCaptureGrowIn`, currently `TerritoryPage`-only)
  to a camera fly-to over the newly-claimed block immediately after capture on
  `ActiveRunPage`, so the "VICTORY! TERRITORY CLAIMED" sheet (`TerritoryCaptureSheet`) is
  paired with an actual visual payoff on the map rather than being a detached modal.

### 5.7 Out of scope for this plan
- Any change to the server-side `submit_run()` capture/anti-cheat logic, the Drift/outbox
  sync layer, or squad/bounty backend RPCs — this is purely a rendering/UI redesign.
- Custom low-poly/toon 3D modeling or a bespoke renderer — MapLibre has no shading
  pipeline for that; "game vibe" here is achieved through palette, lighting-adjacent
  tricks (rim glow), height tuning, and camera angle, not custom geometry.
- Package/dependency changes — no Mapbox GL migration, no `maplibre_gl` version bump
  assumed necessary (re-verify only if the §5.5 spike requires a newer version for
  sky/terrain).

## 6. Sequencing (build-order recommendation, not yet scheduled/estimated)

1. Spike: confirm sky/terrain support on the Flutter plugin (§3) — de-risks §5.5 before
   committing design time to it.
2. §5.1 city buildings + §5.2 territory extrusion rework — these two are the core visual
   fix and should land together since they're evaluated against each other (territory
   blocks need to look right *relative to* surrounding city buildings).
3. §5.3 default-tilted camera on `TerritoryPage`.
4. §5.4 extend to `ActiveRunPage`.
5. §5.6 capture-moment camera tie-in.
6. §5.5 atmosphere, if the spike (step 1) confirmed feasibility.

## 7. Risks / things to verify before implementation

- **Memory on real devices** at zoom ≥15 with buildings + territory extrusion + pitch —
  test on lower-end Android hardware and iOS, not just emulator (matches this codebase's
  existing pattern of trusting live-device testing over static analysis for map/alarm
  code — see CLAUDE.md).
- **Bundled offline fallback style** (`assets/map/fallback_style.json`) almost certainly
  doesn't carry building height data (it's a minimal self-hosted low-zoom style) — the
  redesign must degrade gracefully to flat rendering on that tier, not error.
- **Filter-update lag on fill-extrusion** (maplibre-native#3039) if buildings are ever
  dynamically filtered (e.g. highlighting buildings inside contested territory) — test
  this specifically rather than assuming JS-parity behavior.
- **Gesture handling** for pitch/rotate on the actual widget tree (`ActiveRunPage`'s map
  sits inside a card with other scrollable content) — verify no gesture-arena conflicts.
- No existing test coverage exists for any of the map-layer/animation code in this
  feature (confirmed in review) — this redesign is free to change it without breaking
  tests, but also won't get regression signal from the suite; consider adding at least
  golden/widget-level coverage for the new extrusion layer configuration as part of
  implementation, not just visual QA.

## 8. Definition of done for this plan

This document is planning-only. Implementation should be tracked as its own follow-up
work (likely broken into the phases in §6), each verified by running the app on a real
device per this repo's existing standard for map/location code, not just `flutter
analyze`.
