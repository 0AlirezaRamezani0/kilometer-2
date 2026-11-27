# Changelog (`CHANGELOG.md`)
All notable changes to Kilometer 2 are documented in this file.

## [v0.2-b2] — map + collision rework, playable — 2026-11-27

The v0.2-b1 drive was rejected on play: invisible walls, a road that pinched to zero width, a
flat floor under a 7 m overpass, and a loading screen that flashed past. v0.2-b2 rebuilds the
drivable surface from the artwork itself and proves it by driving the whole lap with an
autopilot. Version **v0.2-b2**, versionCode 7. Regression: **19 suites / 900 checks /
0 failures** (new suite `tests/test_track_drive.gd`, 16 checks).

### Root causes found (all proven from data, not guessed)
- `centerline.json` carried **30 samples with `half_w = 0`** (34 under 2 m). The width came from
  a distance transform of the *whole* asphalt mask, so wherever the bridge deck or the infield
  tarmac touched the line the ribbon collapsed. That is the invisible wall the player hit.
- The deck was a **single flat plane** at y≈0.36 m while the art carries an overpass at 7.4 m,
  so the ramp was a wall of air and the lane under it a ceiling.
- Collision was **one shape per prism face** (12,360 static shapes) in the first cut of this
  rework, which swamped the broadphase; it is now 42 chunked concave shapes.
- `get_longest_straight_transform()` accepted a 24 m-radius corner as "straight" (it summed
  |Δyaw| over the span), so the camera-lag and RPM suites were staging on the inside of a bend.

### Changed — the map
- `assets/track/surface.json` — re-surveyed lane: elevation tracked sample by sample through the
  overpass (0.36 → 6.76 m, max grade **22 %**, vertical curves at the knees), width clamped to
  the surveyed asphalt (4.1–5.0 m half-width, **zero samples under 4 m**).
- `assets/track/collision.json` — new barrier-aware plan: 973 lane samples, **974 barrier
  prisms** along both edges whose inner face is the ribbon edge, and a 56-segment guard ring at
  the outer sand edge. Prism positions are measured from the art's own kerb/wall triangles at
  0.25 m precision, so the ribbon edge sits 0.45 m inside what the player sees.
- `scripts/track/desert_circuit.gd` — collision and visuals are built from the same plan:
  the ribbon (`DryTrackStaticBody`), the barrier prisms (`CircuitBoundary`, 42 chunked concave
  shapes, two-sided) and a **continuous visible 1 m kerb mesh** (`CircuitBarriers`, ~12k tris).
  Every barrier the car can hit is drawn. `has_collision_plan()`, `barrier_count()` and
  `lane_half_width()` added for tests and tools.
- `get_longest_straight_transform()` rewritten: 10 m steps, rejects any span whose heading
  wanders >3° or whose elevation moves >0.8 m. It now returns the 100 m flat run at s=939.
- `tools/capture_map.gd` — new `ramp` and `bridge` still modes (car staged on the overpass,
  fixed three-quarter camera; `look_at` after `add_child`).

### Changed — loading screen
- **3-second dwell, simulated**: `SceneTransition.DWELL_SECONDS = 3.0` holds the screen for the
  full three seconds regardless of how fast the next scene loads, stepping the progress rule
  (0.45 → 0.82 → 0.94 → 1.0). `LoadingScreen.MIN_SHOW` raised 0.65 → 3.0 s so the module keeps
  the contract when presented directly.
- The 5-lamp countdown no longer runs behind the loading screen (it used to hand the player a
  lap already 1.4 s old). `main_driving_template.gd` exposes `race_ready()`, called once the
  screen is gone; `test_desert_circuit.gd` asserts the contract.

### Changed — tests (expectations updated with comments, never deleted)
- `tests/test_desert_circuit.gd` 30 → 33 checks: 3 s dwell edge test, countdown-after-loading,
  chip assertion now prints the live countdown. Version gate → v0.2-b2 / code 7.
- `tests/test_track_drive.gd` (new, 16 checks): plan sanity (no zero width, ribbon on the
  painted road, real elevation), barrier visibility, and a **full lap driven by a pure-pursuit
  autopilot**: reaches s=967/973 in 55 s, never stopped, never leaves the ribbon (worst 0.00 m),
  climbs to 7.18 m, never sinks through the deck (worst 0.67 m, suspension compression on the
  22 % ramp).
- `tests/support/test_runway.gd` (new): a synthetic 900 m slab 120 m above the circuit. The
  camera-lag, RPM and touch suites need 90–95 km/h and the circuit's longest flat straight is
  100 m, so they stage their own runway. **Their gates are unchanged** (this is the reason the
  runway exists rather than a lowered threshold).

### Fixed
- Barriers could be driven through from one side (one-sided concave shape).
- GDScript `Array` literal indexing crash in the prism builder.
- Repaint of the HUD chip during the loading dwell.

## [v0.2-b1] — desert circuit map + identity-v2 loading screen — 2026-11-26

The procedural proving ground is gone. The playable map is now the commissioned desert
circuit, optimised for mobile, with real collision and a lap/telemetry layer. The
identity-v2 loading screen is mounted for every scene change. Version **v0.2-b1**,
versionCode 6. Regression: **18 suites / 881 checks / 0 failures**. Regression suite
`tests/test_desert_circuit.gd` (30 checks) covers the new map and the loading-screen mount.

### Added
- `assets/track/desert_circuit_opt.glb` — the desert circuit, optimised on import:
  **117,612 → 56,815 triangles (−51.7 %)**, **241,223 → 121,362 vertices (−49.7 %)**,
  terrain photo 2048² → 1024². The asphalt deck is protected by a vertex group so only the
  props (kerbs, catch fencing, gantry, light towers) are collapse-decimated; the shipped
  colour is a UV palette, so it stays byte-lossless while the photo goes JPEG.
- `assets/track/centerline.json` — the circuit surveyed from the mesh itself: the asphalt
  palette swatches are rasterised, skeletonised and walked into a **closed 973 m loop with
  973 samples at 1 m** (position, heading, half-width, elevation) and 12 sector gates.
  Regenerable with `tools/track_survey/rasterize.py` + `final_centerline.py`.
- `scripts/track/desert_circuit.gd` (`class_name DesertCircuit`) — replaces
  `engineered_test_track.gd`. Superset of the old public API (`get_spawn_transform`,
  `set_shadow_quality`) plus `get_track_length`, `get_progress`, `lateral_offset`,
  `get_lap_state`, `update_telemetry`, signals for lap/checkpoint/countdown/wrong-way/
  off-track.
- Interaction layer: 5-lamp start gantry countdown, 12 ordered sector checkpoints, lap
  clock with best/last, wrong-way detection (forward vector vs racing-line heading) and
  off-track telemetry with 0.6 m hysteresis.
- Collision: the asphalt deck is a `ConcavePolygonShape3D` ribbon (24 m chunks, 41 chunks)
  on `DryTrackStaticBody` (`surface_grip` 1.0), a `SandStaticBody` floor at grip 0.5, and
  `CircuitBoundary` walls at the terrain edge.
- `assets/ui/loading/plate_map.png` re-shot from the actual circuit (runtime top-down capture
  `tools/capture_map.gd`, instead of the studio car plate).
- Loading screen: `SceneTransition` now mounts `scenes/ui/loading_screen.tscn` instead of
  drawing a caption veil. Logotype-only, geometry-only progress, no numerals — enforced in
  the autoload so no call site can reintroduce text.

### Changed
- `scenes/track/test_track.tscn` re-authored for the desert map (desert sky/fog/sun tuned
  for the sand albedo; the node is still named `EngineeredTestTrack` so the main scene, the
  LAN scene and the camera rig keep their paths).
- `main_driving_template.gd`, `vehicle_hud.gd`, `lan_game.gd`: typed references moved from
  `EngineeredTestTrack` to `DesertCircuit`; the driving scene starts the countdown and pipes
  `track.update_telemetry(vehicle)` each physics tick.
- `lan_lobby.gd` owns its loading spinner (the veil's `Spinner` class went away with the
  veil).

### Removed
- `scripts/track/engineered_test_track.gd` and its procedural proving-ground geometry (curved ribbons, skidpad, slalom cones,
  (curved ribbons, skidpad, slalom cones, grandstand, floodlight masts, cypress trees) — the
  map it modelled is replaced. The survey scripts that produced the new map ship in
  `tools/track_survey/`; the method is documented in `documentation/DESERT_CIRCUIT.md`.

## [v0.1-b5] — lighter garage asset — 2026-11-26

The desert-garage diorama is optimised for mobile and re-delivered as the project's current
build in the `game pro` Drive folder. No gameplay/UI change.

### Changed
- `assets/environment/garage/garage_desert_lite.glb` is now the shipped stage:
  **6.0 MB → 1.4 MB (−75 %, 4.0× lighter)**, 10 315 → 5 458 triangles, texture memory
  19.8 MB → 6.3 MB (every texture capped at 512 px, UVs untouched). The roof volume the orbit
  camera can never see (deck, parapet, wire trim, roof sign) and sub-25 cm bench clutter are
  culled offline; the 49 objects are joined, welded and collapse-decimated (ratio 0.55).
  File-level report: `assets/environment/garage/OPTIMIZATION_VERIFICATION.md`.
- `main_menu.gd` falls back to the full-resolution `garage_desert.glb` (kept in the repo for
  marketing renders) if the lite file is ever missing.
- The display surface is measured over the car's own footprint (2.8 m radius) so the decimated
  mesh still seats the wheels exactly on the turntable: wheel bottoms == measured surface
  (0.188 m) — `test_garage_stage › wheels_rest_on_turntable_disc`.
- Version **v0.1-b5**, versionCode 5. Regression: **17 suites / 842 checks / 0 failures**.

## [v0.1-b4] — desert-garage showroom stage — 2026-11-26

The main-menu showroom is now staged inside the delivered **"Car Garage | Desert Garage
Environment"** diorama (DevPoly3D, CC BY-NC 4.0) instead of the procedural graphite hangar.
UI, gameplay, physics, audio, save data and input bindings are untouched.

### Added
- `assets/environment/garage/garage_desert.glb` — glTF 2.0 conversion of the delivered
  `Mobile_Optimized_Model_001.fbx` (FBX was re-imported in a clean Blender 4.3.2 scene and
  re-exported with textures embedded; no geometry, pivot or scale change), plus the verbatim
  source licence and the import notes.
- `_build_garage_stage()` in `scripts/ui/main_menu.gd`: instantiates the diorama, culls the
  roof/parapet slabs above 6.3 m so the orbit camera stays inside the workshop, merges all 49
  meshes into one `ArrayMesh` (16 surfaces, one per material) to keep draw calls low on
  Android, grades every surface to the graphite night-studio palette, re-seats the model on
  y = 0 and adds a night ceiling, three emissive light bars, a soft overhead pool light and a
  key/fill pair tuned for brick + steel.
- `--hangar-stage` runtime flag: stages the v0.1-b3 procedural hangar instead (comparison
  captures, or if the diorama has to be removed for a commercial release). `--no-shadows`
  disables the diorama's shadow casting for mobile profiling.
- `tests/test_garage_stage.gd` — 25 checks guarding the stage, its draw-call budget, the
  turntable seating and the licence attribution.
- In-game licence credit for the diorama (Help → «دربارهٔ بازی و مجوزها»), plus
  `LICENSES.md` §6, `THIRD_PARTY_ASSETS.md` §6, `documentation/ASSET_CATALOG.md` §1b and a
  README attribution block — CC BY-NC 4.0 requires attribution.
- `documentation/MAINTENANCE.md`: how to switch the stage back off before a commercial release.

### Fixed
- **Wheels sank into / floated above the turntable.** The first seating pass placed the car on
  the model's raised wooden rim (a 0.18 m drum) instead of the flat disc inside it, which left
  the wheels 0.26 m in the air while the rim visually cut across them at low camera angles.
  The disc surface is now measured from the mesh itself (`_garage_turntable_surface_y()` scans
  the vertices inside the central 2 m radius → 0.144 m in the delivered model) and the wheels
  sit on it with a 4 mm epsilon: `ShowroomCar.y = 0.148`, wheel bottoms at 0.148.
  Guarded by `test_garage_stage › wheels_rest_on_turntable_disc`.

### Changed
- `ShowroomCar` sits on the diorama's turntable disc (y = 0.03 → 0.148) and the camera look
  target rises to 0.95 m when the diorama is the stage; the v0.1-b3 framing math is unchanged.
- The stage environment (filmic tonemap, exposure 0.94, exponential fog, graphite ambient) is
  shared by both stages through `_make_stage_environment()`.
- Version **v0.1-b4**, versionCode 4 (`tools/sync_version.py` synced the export preset and the
  docs). Regression: **17 suites / 838 checks / 0 failures**.

### Known limitations
- The diorama is **CC BY-NC 4.0**: free builds only; a paid or ad-monetised release needs a
  commercial licence or `--hangar-stage`.
- The delivered model has no rig, no animations and 16 separate materials; it is merged at
  runtime (one-time cost at menu load) rather than atlas-merged offline.
- The roof sign ("GARAGE") sits above the culled roof line and is therefore not visible from
  the in-workshop camera.

## [v0.1-b3] — "Proving Ground" UI/UX redesign — 2026-11-26

Complete UI/UX redesign of every existing screen on a new design system, built on the
stable v0.1-b1 codebase. Gameplay, physics, audio, save data and input bindings are
unchanged. Full detail: `documentation/DESIGN_SYSTEM.md`, `documentation/UX_ARCHITECTURE.md`
and the session reports. Regression: **16 suites, 813 checks, 0 failures**.

*Note on numbering:* v0.1-b2 was an earlier redesign branch whose working copy was lost with
its sandbox (checkpoints remain in Drive); b3 was rebuilt from the verified v0.1-b1 baseline
and uses versionCode 3 so Android installs stay monotonic.

### Fixed (audit IDs in the session audit report)
- **A-01** Settings/Help modals did not trap focus — Enter/A inside settings started a
  driving session through the hidden «شروع رانندگی» button. All overlays now run on
  `UiModalStack` (Godot 4.5+ `focus_behavior_recursive` / `mouse_behavior_recursive`), move
  focus in on open and return it on close; Esc/B closes the top overlay.
- **A-02** Quick-settings band clipped its last row off-screen and had no close control →
  sized, scrollable side sheet with a close button.
- **A-03** LAN lobby had no focus and no back key → focus on «ساخت اتاق», Esc/B back.
- **A-04** Bidi: Persian labels starting with a Latin word rendered scrambled → every Persian
  label forces an RTL paragraph; Latin runs (IP, version, keys) get their own LTR label.
- **A-05** Quit (menu and pause) exited immediately → confirmation dialogs (focus on «ماندن»/«انصراف»).
- **A-07** Cluster printed «MPH» on a km/h dial, a 9 000 rpm redline for 6 300 rpm engines,
  and drew rpm as norm × 7000 → vector cluster with km/h scale, real rpm (idle 950 → redline
  6 300), red zone at the real redline, digital speed, automatic gear number.
- **A-08/A-09** Throttle and brake shared one red; three vermilion "primary" elements
  competed; white on `#FF3D2E` was 3.5:1 → semantic telemetry colours (throttle green, brake
  red, handbrake amber), one filled CTA per screen, CTA fill `#D2291A` (5.2:1).
- **A-10** RTL anchors mirrored the showroom card and pause drawer to the wrong side →
  anchored containers stay LTR; both now sit on the start (right) side as intended.
- **A-11** Fake «گاراژ» tab removed. **A-12** duplicate speed, raw grip value and «خودرو:»
  prefix removed. **A-13** every slider tick wrote the config and re-applied graphics →
  domain-only apply + 350 ms debounced save with a «ذخیره شد» chip. **A-14** prompts follow
  the active device (keyboard letters on pads only for keyboard; timed gamepad strip incl.
  brake/reverse). **A-15** numerals consistent (Persian in prose, Latin in instruments).
  **A-16** honest showroom specs (top speed, engine force, weight). **A-17** structured help
  with credits. **A-18** toasts on an inverse-surface backplate. **A-21** settings no longer
  rebuild on reflow (UI sounds stay wired). **A-23** scene transition with a loading caption.
- **A-24** Android keystore user/password removed from `export_presets.cfg` (supply them via
  the editor's export credentials or `GODOT_ANDROID_KEYSTORE_RELEASE_USER/PASSWORD`).
- **A-25** `qa/*` dev scripts excluded from exports.
- Input-device tracking: a mode change is now broadcast to every tracker (only the first
  tracker used to emit).

### Added
- `scripts/ui/ui_theme.gd` rewritten: colour roles, type scale, spacing/shape/elevation,
  motion tokens, reduced-motion helpers, Persian digit helpers, RTL label factories, one shared
  `Theme` with variations (PrimaryButton, SecondaryButton, GhostButton, DangerButton,
  IconButton, TabButton, ChipButton, Display/Headline/Title/Section/Body/Caption labels,
  Glass/Card/Sheet/Dialog/Hud/Toast panels…). Legacy API kept as thin shims.
- `scripts/ui/ui_icon.gd` (46 vector icons), `scripts/ui/input_prompts.gd` (device prompts),
  `scripts/ui/ui_modal_stack.gd` (focus model), `scripts/ui/scene_transition.gd` (autoload
  `SceneTransition`).
- Settings: 5th tab «دسترسی» — **UI scale** 85–150 % (handheld default 120 %) and **reduced
  motion**; reset to defaults; descriptions; segmented controls; values with units.
- Showroom: start-side hero card, spec bars from real physics values (catalog
  `top_speed_kmh` / `engine_force_n`, drift-checked against the vehicle scenes), RTL-correct
  car paging (← / LB / Q = next car on the left), selection follows focus.
- HUD: tools action sheet, contextual status chips (surface, damage, ghost, FPS), photo-mode
  prompt bar and gamepad capture (A), toasts with icons, pause drawer list with
  «خروج از بازی» (confirmed).
- Input actions `ui_page_left` / `ui_page_right` (Q/E, LB/RB).
- `tests/test_ui_v3_design_system.gd` (101 checks); `qa/capture_uiux.gd` (before/after matrix)
  and `qa/probe_focus.gd` (focus/bidi probe); 4 vetted agent skills (`skills-lock.json`).

### Changed (tests kept, assertions moved to the new structure)
- `test_layout_modes.gd` asserts real geometry instead of literal anchors (the old 0.72 anchor
  passed while the card rendered on the wrong side); `test_b9_ui_responsive.gd` reflow checks
  now measure a visible page (the old check passed vacuously on zero-size rects);
  `test_phase9_full_integration.gd` reads the digital speed and its unit from the cluster.

## [v0.1-b1] — renamed release of the stable B9.1 build — 2026-11-25

This is the **stable B9.1 codebase** (15 suites / 701 checks / 0 failures) re-released
under the new product name and version scheme. No gameplay, physics, audio or UI
behaviour was changed in this release; the B10 UI-kit experiment was reverted and
removed.

- Version: `4.2.0-b9-1` (versionCode 10) → **`v0.1-b1` (versionCode 1)**.
- `scripts/ui/version_info.gd`: `BASE="v0.1"`, `TRACK="b1"`, `CODE=1`;
  the menu pill now shows `K2 · v0.1-b1`.
- `export_presets.cfg`: `version/name="v0.1-b1"`, `version/code=1`,
  `export_path="export/android/k2-v0.1-b1.apk"`.
- Project folder renamed to `K2_v0.1_b1_source`.
- `tools/sync_version.py --check` → `OK: everything reports v0.1-b1`.

## [4.2.0-b9-1] — HUD balance pass — 2026-11-24

Follow-up to b9 on user feedback («the cluster got too small, remove the boxy
border and size it properly; the buttons got too big»).

- **Cluster**: the carbon-glass plate (background + 1 px border + 20 px radius +
  drop shadow) and the centre scrim disc are gone — the dials, needles, gear
  badge and status lamps now sit borderless on the scene. Size is allocated
  from the canvas instead of "whatever was left": 36% of the width in landscape
  (~432x203 at 1280x720, was squeezed to 240x168), 62% in portrait, capped at
  560 px, height = 0.47 x width (the kit art's own aspect, i.e. the B8 scale).
- **Touch controls**: base scale 26% → 16% of canvas height (clamped 48..96 px);
  steering pads are square and bottom-aligned again (filling the zone had turned
  them into tall rectangles); handbrake/brake/throttle re-proportioned. In
  portrait the steering zone is sized from the canvas *width* (26%) so it stays
  thumb-friendly.
- `VersionInfo.CODE` is now an explicit, monotonically increasing versionCode.
- `tests/test_b9_ui_responsive.gd`: 3 new guards (cluster width ratio, no box
  plate, controls never taller than 28% of the canvas). Suite total: 701 checks
  in 15 suites, 0 failures.

## [4.2.0-b9] — UI responsiveness, touch ergonomics, steering-wheel redesign — 2026-11-24

Full detail: `documentation/B9_UI_FIX_REPORT.md`. Test suite: 15 suites, 692 checks, 0 failures.

### Fixed
- **Menu settings card was clipped outside the screen.** The card lived in a
  `CenterContainer` and forced a hard 600x480 minimum, so on short or portrait
  viewports its lower half (and its drawer content) fell off-screen. The card
  now sits in a `MarginContainer` with a pixel-exact size per layout mode
  (`max 620x640`, always inside the screen) and the panel adapts internally.
- **Pause-drawer settings were cut in half.** A 360 px panel with a 600 px
  minimum inside a 410 px drawer overflowed to the left. The drawer width is
  now `min(410, 92% of the viewport)`, the panel fills it, and the slide-in
  tween lands on the computed rest offset instead of a hardcoded -410.
- **Touch controls were too small on phones.** Every pedal/pad had a fixed
  1280x720-era pixel size. `VehicleHud._apply_responsive_control_sizes()`
  derives all sizes from the canvas (≈26% of height, clamped 64..168 px) and
  re-applies them on every resize; the gauge cluster shrinks first so the
  three bottom islands can never overlap.
- Wrapped section labels inside `HBox` collapsed to a 1 px minimum and blew
  rows up to 400+ px tall; page rebuilds stacked two page sets (`queue_free`
  left children attached for the rest of the frame) and lost the widget sync,
  so sliders came back empty after a WIDE↔COMPACT reflow.
- Version string had drifted across three places (preset + menu pill said
  `4.2.0-b7`, the README said `4.0.0`).

### Changed
- `scripts/ui/settings_panel.gd` rebuilt as a host-driven responsive panel:
  single-line rows when wide, stacked rows + 2x2 tab grid when narrow, a
  scrollable body per tab, 46/54 px tabs, TTF-free layout constants.
- Pause-settings close button is graphite (UI-CLEAN rule 2: the only
  vermilion CTA is «شروع رانندگی»).

### Added
- `scripts/ui/version_info.gd` — single source of truth for the build version;
  the menu pill reads `VersionInfo.DISPLAY`.
- `tools/sync_version.py` — pushes the version into `export_presets.cfg` and
  the docs; `--check` mode fails CI when something drifts.
- `tests/test_b9_ui_responsive.gd` — 97 checks: card fits, tabs tappable, rows
  fit, no clipping, touch targets >= 64 px inside the screen at six aspect
  ratios, bottom islands never overlap, wheel grab area, pause drawer/panel
  geometry, version single-source.
- `qa/run_tests.sh` (summary runner), `qa/capture_quick.gd` and
  `qa/capture_audit.gd` (dev-only before/after capture harnesses).
- `.claude/skills/` + `skills-lock.json` — 9 code-review/analysis skills
  (excluded from exported builds) and a project-specific audit playbook.

### Redesigned
- **غربیلک فرمان (`touch_steering_wheel.gd`)**: full sport wheel drawn from the
  widget size — leather rim with white nine-and-three grips and stitching,
  three machined spokes, red 12-o'clock marker, bolted hub with the K2 mark,
  live torque arc, live steer percentage, whole-widget grab area, fade-out
  «بچرخانید» hint. Public API unchanged (`steer_value`, `input_blocked`,
  `set_simulated_steer`, `max_wheel_deg`, `recenter_rate`).

## [4.0.0] — Kilometer 2: full audit, cleanup & documentation — 2026-10-30

### Renamed
- Project officially renamed from the working title "saipa beta 3" to
  **Kilometer 2**: `application/config/name`, Android package display name,
  APK filename (`Kilometer_2.apk`), version 4.0.0 (code 4), and the
  project-name test assertion. The Android application id
  (`org.saipa.drivingtemplate`) is intentionally unchanged (install
  identity). Note: the `user://` data directory follows the project name,
  so settings saved under the old name start fresh once.

### Removed (verified unused/obsolete; see documentation/CLEANUP_REPORT.md)
- Dev artifacts from the source tree: `previews/` (13 pass-1 renders),
  `previews_pass3/` (12 renders; regenerated as reports/screenshots/),
  `verification/` (3.1.1 evidence, superseded), 5 phase-era reports.
- Four superseded capture scripts and two one-off Python converters from
  `scripts/tests/`; replaced by one maintained tool (`tools/`).
- Six unreferenced asset-pipeline manifest JSONs (data folded into
  documentation/ASSET_CATALOG.md).
- Seven exact-duplicate texture files (~2.0 MB), verified safe by cold
  import + 165 model/integration tests (GLBs embed their textures).
- Dead code: driving-preset system in SaipaVehicleController
  (`apply_driving_preset` and friends, zero callers), unused hood/cabin
  camera exports (+ their lines in 6 vehicle scenes), write-only
  `VehicleHud.main_scene_ref`, unreferenced
  `main_driving_template.get_active_vehicle_index`.

### Changed
- `scripts/main_driving_template.gd` moved to `scripts/main/` so scripts/
  mirrors scenes/; scene reference updated, UID preserved.
- `scripts/tests/capture_pass3_previews.gd` moved to
  `tools/capture_previews.gd`; now writes 15 screenshots (all six
  showroom vehicles) to `reports/screenshots/`.
- Export preset exclude filter pruned of stale paths; now excludes
  `tests/*, tools/*, reports/*, export/*`.
- Header comments updated from the old working title to Kilometer 2.

### Added
- `tests/test_project_integrity.gd`: 136-check suite validating every
  scene, script, catalog entry, input action and core resource.
  Total automated checks: 402, all passing.
- Complete English documentation package in `documentation/`
  (ARCHITECTURE, DEVELOPMENT, CLEANUP_REPORT, TESTING, ASSET_CATALOG,
  MAINTENANCE) and a rewritten README.
- 16 genuine screenshots in `reports/screenshots/` (15 in-game via the
  capture tool + 1 Godot editor capture).

### Fixed
- Nothing functional: gameplay, physics, UI and graphics behavior are
  byte-identical in behavior to 3.1.1; this release is structural.


## [3.1.1] — Showroom wheels fix — 2026-10-30
### چرخ‌های نمایشگاه برگشتند
- **Bug**: the main-menu showroom loaded the catalog `visual_scene` (body-only rig; its wheels are spawned at runtime by the driving vehicle controller, which never runs in the menu) — so every car floated wheel-less on the showroom platform.
- **Fix**: `MainMenu._show_vehicle()` now instantiates the catalog `showcase_scene` (body + 4 `WheelMount*` wheel meshes), the same scene the asset-integration preview already used.
- **Regression guards**: `tests/test_pass3_ui_camera.gd` now asserts ≥4 wheel meshes under the showroom mounts for the initial car and after switching (`showroom_vehicle_has_wheels`, `showroom_switched_vehicle_has_wheels`). Suite 34/34; project total **266 passed / 0 failed**.

---

## [3.1.0] — Pass 3: Unified UI Redesign — 2026-10-30
### رابط کاربری یکپارچه، انتخاب خودرو در نمایشگاه، دوربین تک‌حالته
- **Unified visual language (`UiTheme`)**: every screen (main menu, HUD, pause, settings, dialogs) rebuilt from scratch on one dark-sport theme — glass panels, single orange accent, Vazirmatn typography. The old stacked-patch HUD (top action bar + settings modal with car/gfx/drive/paint rows) is deleted.
- **Showroom vehicle selection (locked)**: the main menu is a live 3D showroom (rotating catalog visual, prev/next, specs). The choice persists in `SettingsManager.selected_vehicle_index`, the driving scene spawns exactly that vehicle, and there is NO in-game switching (no `cycle_vehicle` action, no HUD vehicle button, no runtime switch API).
- **Graphics independence fix**: previously every vehicle switch re-ran `bind_systems()` → graphics tier + per-vehicle LOD were re-applied, visibly changing graphics. Now graphics are owned only by `SettingsManager`, applied once at scene start and on explicit Settings changes (menu or pause); spawning a vehicle never touches tier/viewport/track state. Regression-checked by `tests/test_pass3_ui_camera.gd`.
- **Single free-follow camera**: `VehicleCameraRig` reduced to one smooth follow behavior (physics-tick smoothing + SpringArm). Hood/cabin/diagnostic modes, lock toggle, orbit drag, look-back and reverse flip removed; `cycle_camera` action removed.
- **Tests**: new pass-3 suite 32/32; inherited suites updated to the new spec — total 264 passed / 0 failed (32 + 27 + 14 + 24 + 124 + 43).

---

## [3.0.0-beta3] — `saipa beta 3` — 2026-10-25
### بهینه‌سازی عمیق، دوربین فیکس و سیستم رابط کاربری فارسی پیشرفته
- **Project & APK Branding (`saipa beta 3`)**:
  - Updated `project.godot` (`application/config/name = "saipa beta 3"`) and `export_presets.cfg` (`package/name = "saipa beta 3"`, `version/code = 3`, `version/name = "3.0.0-beta3"`, output `export/android/saipa_beta_3.apk`).
  - Pruned duplicate staged source assets from APK packaging, reducing signed APK size from `96 MB` to **`62 MB` (`64,505,401` bytes)**.
- **Rendering, GPU Batching & Jolt Physics Optimization**:
  - Re-architected `EngineeredTestTrack` (`scripts/track/engineered_test_track.gd`) to batch repeated road dashes, 20 m distance gates, FIA red/white kerbs, guardrails, and perimeter posts via `MultiMeshInstance3D` (`7` GPU multimeshes) and consolidated `24` `StaticBody3D` nodes into **`2` shared `StaticBody3D` bodies** (dry grip `1.00`, wet skidpad grip `0.28`).
  - Removed duplicate directional light forward pass in `test_track.tscn` (`gl_compatibility`), tuned sky hemisphere ambient lighting (`0.88`), and configured 2-split directional shadows (`2048` desktop / `1024` mobile).
  - Added runtime static material-surface batching + HLOD distance culling + interior shadow-caster pruning in `SaipaVisualModel` and shared wheel materials across all 4 wheels in `SaipaVehicleController`.
  - Verified in Godot `4.7.2` (`1280×720` OpenGL3): Draw calls reduced from **`441` -> `230` (`-47.8%`)** in Balanced mode and **`198` (`-55.1%`)** in Mobile Fast mode; shadow casters reduced from **`55` -> `9` / `4`**.
- **Fixed Camera System (`VehicleCameraRig`)**:
  - Implemented post-Jolt pre-render synchronization (`process_priority = 100`) eliminating 1-tick physics-vs-render camera jitter (`0.00000 m` pivot lag at `51.46 km/h`).
  - Default `CHASE_FOLLOW` with `camera_locked = true` locks pivot, horizon, yaw heading (`0.00000 rad` unwanted stationary steer sway), and constant `55.0°` FOV, plus `HOOD_FIXED` (`نمای کاپوت`), `Look Back` (`آینه عقب`), and optional unlocked 360° touch orbit.
- **Advanced Persian/Farsi RTL UI (`VehicleHud`)**:
  - Bundled `Vazirmatn` v`33.003` (`OFL-1.1`) in `assets/fonts/`.
  - Added vector circular tachometer & digital speedometer (`PersianGaugeCluster`), interactive rotary touch steering wheel (`TouchSteeringWheel`), cached zero-allocation multi-touch pedals (`TouchPedalButton`), toggleable `SpotLight3D` headlights, and a collapsible RTL Persian Settings & Car Tuning modal (3 graphics tiers, 3 driving physics presets, camera distance slider, 5 live body paint colors, FPS/DC toggle).
  - Expanded automated verification to **`78/78` passing assertions (`0 failed`)** and `13` rendered visual previews.

---

## [1.1.0] — 2026-10-25
- Swapped vehicle asset to Google Drive `sport_pride.zip` (`12WpIbCYEXizSI5hXNgRenHnaEH6ZEn_1`), normalized `saipa_pride_body.glb` + `saipa_pride_wheel.glb`, recalibrated widebody Jolt suspension/brakes (`53/53 PASS`), and exported `saipa_vehicle_template_debug.apk`.

## [1.0.0] — 2026-10-25
- Initial Godot `4.7.2` + Jolt 3D vehicle physics template, proving ground, multi-touch HUD, and Android debug APK export.
