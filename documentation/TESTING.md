# Kilometer 2 — Testing & QA Report

## v0.1-b4 (desert-garage showroom stage) — 2026-11-26

Environment: identical to the v0.1-b3 run below (Godot 4.7.2-stable, Debian, no GPU, Xvfb +
Mesa llvmpipe for captures).

| Change | Evidence |
|---|---|
| Showroom stage replaced by the desert-garage diorama | **`test_garage_stage` (30 checks)**: model imports (49 meshes), 35 textured meshes survive the import, the menu stages `ShowroomGarage`, the diorama is merged to 16 surfaces / 1 mesh node, the roof slabs above 6.3 m are culled, the walls stay (top 12.10 m), the floor is seated on y = 0, the wheels rest exactly on the turntable disc (wheel bottom 0.148 vs disc 0.144 — the "wheels sink into the turntable" bug), the CC BY-NC credit + licence file ship, and the help panel shows author/licence/source |
| Bug fix: wheels floated 0.26 m above (and were visually cut by) the turntable rim | `test_garage_stage › wheels_rest_on_turntable_disc` — the disc surface is measured from raw vertices in the central 2 m radius and the car is seated on it; low-angle close-ups (`reports/screenshots/`, `cu_side_low.png`) confirm contact |
| Version bump to v0.1-b4 (code 4) | `test_ui_v3_design_system › version_is_v0_1_b4`; `tools/sync_version.py --check` reports OK |
| Regression | **17 suites / 842 checks / 0 failures** (`bash qa/run_tests.sh`) |
| Visual | `qa/capture_uiux.gd --only=menu` re-rendered the 7-window matrix (1280×720, 1920×1080, 1280×800, 1024×768, 2560×1080, 844×390, 720×1280); every configuration keeps the RTL hero card clear of the car |
| Cost | RenderingServer counters, identical first-frame measurement: garage stage **343 draw calls / 354 038 primitives / 467 nodes**, v0.1-b3 procedural hangar **338 / 397 109 / 418** — the diorama is ~11 % cheaper in primitives, 5 draw calls more, so the stage swap does not raise the menu's GPU cost (the `--hangar-stage` flag exists for A/B captures) |

Not covered: the same hardware/device gaps as the v0.1-b3 run below (no physical Android
device, no GPU timing) — the diorama adds 35 textured meshes on screen, so an on-device
profile of the menu is still recommended.

## v0.1-b3 ("Proving Ground" redesign) — 2026-11-26

Environment: Godot 4.7.2-stable (official Linux binary, SHA-512 verified), Debian 12, 2 vCPU,
3.8 GB RAM, no GPU — headless for suites; Xvfb + Mesa llvmpipe (OpenGL 4.5) for captures.

| Suite | Checks | Result |
|---|---|---|
| test_audio_system | 33 | ✅ |
| test_b9_ui_responsive (reflow section rewritten) | 108 | ✅ |
| test_camera_lag | 4 | ✅ |
| test_carpack_integration | 124 | ✅ |
| test_engine_audio | 27 | ✅ |
| test_engine_rpm_model | 29 | ✅ |
| test_gamepad_mapping | 25 | ✅ |
| test_kilometer2_regression | 53 | ✅ |
| test_layout_modes (geometry assertions) | 15 | ✅ |
| test_pass3_ui_camera | 34 | ✅ |
| test_phase3_model_audit | 14 | ✅ |
| test_phase5_vehicle_physics | 24 | ✅ |
| test_phase9_full_integration (cluster readout) | 45 | ✅ |
| test_project_integrity | 152 | ✅ |
| test_touch_gamepad_coexist | 25 | ✅ |
| **test_ui_v3_design_system (new)** | 101 | ✅ |
| **Total — 16 suites** | **813** | **0 failures** |

Runtime/visual verification: `qa/capture_uiux.gd` renders the same states for the baseline and
the redesign at 1280×720, 1920×1080, 1280×800, 1024×768, 2560×1080, 844×390 and 720×1280
(portrait window); the responsive matrix and the before/after comparison sheets are in the
session reports. `qa/probe_focus.gd` reports focus owners per screen (baseline vs redesign).

Not covered by automation: physical Android hardware (performance, safe-area insets,
real multi-touch feel), a real gamepad, screen-reader output (AccessKit names are set but were
not exercised with NVDA/TalkBack), and two-device LAN play.

---


## 1. Test environment

- Godot **4.7.2-stable** Linux x86_64 binary, headless mode for suites; Xvfb + OpenGL3 (`--rendering-driver opengl3`) for genuine rendering captures.
- Project imported from a cold cache (`.godot/` deleted) before the runs below.
- Date: 2026-10-30. Version under test: 4.0.0 (post-audit).

## 2. Tests performed

### 2.1 Import & compilation
- `godot --headless --path . --import`: exit 0, **0 script errors, 0 errors** on warm cache.
- Known Godot behavior, documented honestly: on a *completely cold* cache the first import prints a transient `Vazirmatn-Medium.ttf` load error because `project.godot` requests the custom font before its import finishes; a second import is fully clean. This exists in the pre-audit build as well and is not a regression.

### 2.2 Automated suites (all headless SceneTree)

| Suite | Checks | Result | Covers |
|---|---|---|---|
| `tests/test_kilometer2_regression.gd` | 27 | ✅ 27/0 | InputMap persistence, pause/resume, locked-vehicle invariant |
| `tests/test_carpack_integration.gd` | 124 | ✅ 124/0 | All 6 vehicles: scenes, catalog, preview integration, spawn |
| `tests/test_phase3_model_audit.gd` | 14 | ✅ 14/0 | Model geometry: wheel positions, doors, LHD cabin |
| `tests/test_phase5_vehicle_physics.gd` | 24 | ✅ 24/0 | Acceleration, braking, steering, surfaces, reset (writes `reports/physics_metrics.json`) |
| `tests/test_phase9_full_integration.gd` | 43 | ✅ 43/0 | End-to-end flow, project name, settings, graphics ownership (writes `reports/integration_metrics.json`) |
| `tests/test_pass3_ui_camera.gd` | 34 | ✅ 34/0 | Unified UI, showroom (incl. 4-wheel regression checks for the 3.1.1 bug), single follow camera, pause settings |
| `tests/test_project_integrity.gd` *(new in 4.0.0)* | 136 | ✅ 136/0 | Every scene loads+instantiates (25), every production script compiles (17), catalog 6×3 scenes resolve, input actions, font, icon |
| **Total** | **402** | ✅ **402 passed, 0 failed** | |

Deletion safety was additionally proven empirically: after removing the 7 duplicate textures, cold import produced no missing-resource errors and 165 model/integration/regression checks passed.

### 2.3 Runtime & visual verification
- 15 screenshots captured from the real running game via `tools/capture_previews.gd` (Xvfb): all six showroom cars with wheels and intact materials, menu settings, controls help, driving HUD at start/speed/cornering, pause, pause settings, rotary-wheel and analog-bar steering modes.
- 1 genuine Godot editor capture (project structure + main scene viewport).
- All 16 images visually inspected; see `reports/screenshots/`.

### 2.4 Shipped-artifact verification
The delivered `Kilometer 2 - Final.zip` was extracted to a clean directory, imported (0 errors) and re-tested (integrity + UI/camera suites green) to prove the archive itself is valid.

## 3. Errors fixed during this audit

- None functional — by design. The audit fixed structural issues only: project naming, dead preset/camera code, one write-only HUD field, an unreferenced getter, stale export-exclusion paths, and four superseded tooling scripts.
- Pre-existing, fixed in 3.1.1 before this audit: showroom cars rendered without wheels (`visual_scene` → `showcase_scene`); regression checks included above.

## 4. Remaining bugs / limitations

- **Cold-cache first-import font message** (cosmetic, self-heals on second import; upstream Godot import-order behavior).
- **Not tested:** real Android hardware (no device/emulator in this environment) — the Android preset is configured but an APK was not built or run; performance on low-end GPUs is inferred from tier design, not measured.
- **Not tested:** export build itself (`--export-release`) — requires Android SDK + export templates not present here.
- Long-session memory/soak testing and multiplayer (not a feature) are out of scope.
- Settings saved under the pre-4.0 project name live in the old `user://` folder and will not migrate (documented in CHANGELOG).

## 5. Compatibility verification

- Godot 4.7.2 opens/imports/runs the project with zero errors; project remains on the 4.7 feature tag (no version upgrade performed or needed).
- Renderer GL Compatibility, Jolt physics, input map and export preset all validated by the suites above.
- Behavior parity with 3.1.1: physics/UI suites from previous releases pass unchanged (same 266 checks), proving the cleanup changed no gameplay behavior.
