# Kilometer 2 — Cleanup Report (4.0.0 Audit)

Scope: the complete project as of Pass 3 + 3.1.1 (300 files). Method: full reference-graph analysis (every `res://` path in scripts/scenes/config), class-name usage search (GDScript global classes hide path references), scene/script load tests, and empirical import verification before any deletion. User-approved strategy: **conservative** — keep the proven structure, remove only verified-dead content.

Excluded from this audit by explicit user instruction and never touched: Google Drive items `city 6 (682).zip`, `gtasa_ls.zip`, `GTA SA map 808/`.

## 1. Files inspected

- 300 files at intake: 25 scenes, 23 GDScript files (18 production + 5 capture tools), 6 test suites, ~150 vehicle asset files (GLB/PNG/import), fonts, docs, dev artifacts.
- Every script read or reference-scanned; every scene load/instantiate-tested by the new integrity suite.
- Baseline before changes: import 0 errors, **266/266** headless checks green.

## 2. Deletion manifest (what was removed and why)

### SAFE TO DELETE — removed (64 files)

| Item | Reason |
|---|---|
| `previews/` (13 PNG + `.gdignore`) | Pass-1 render outputs of deleted capture scripts; regenerated imagery now lives in `reports/screenshots/` |
| `previews_pass3/` (12 PNG + 12 `.import`) | Pass-3 capture outputs; superseded by `reports/screenshots/` (15 fresh shots) |
| `verification/` (3 files) | 3.1.1 fix evidence; superseded by `documentation/TESTING.md` + QA logs |
| `reports/environment.md`, `final_report.md`, `skills.md`, `test_matrix.md`, `vehicle_asset_audit.md` | Phase-era Persian reports; replaced by this English documentation package. (The two `reports/*.json` files are live test **outputs** and were preserved.) |
| `scripts/tests/capture_carpack_previews.gd`, `capture_final_previews.gd`, `capture_kilometer2_previews.gd`, `capture_phase3_renders.gd` (+ 4 `.uid`) | Four superseded screenshot scripts with overlapping purpose; replaced by one maintained tool |
| `scripts/tests/blender_export_pipeline.py`, `convert_carpack_to_godot.py` | One-off FBX→GLB conversion utilities; unreferenced by code/tests; pipeline provenance summarized in ASSET_CATALOG.md |
| 6 manifest JSONs (5 carpack `*_manifest.json` + `assets/vehicle/vehicle_geometry_manifest.json`) | Unreferenced by any script, test or export (the export preset already excluded them); their data was folded into ASSET_CATALOG.md before deletion |
| `assets/textures/` (empty directory) | Leftover of an earlier layout; contained no files |

### VERIFY BEFORE DELETION — verified, then removed (14 files)

| Item | Verification |
|---|---|
| 7 exact-duplicate textures (+ 7 `.import`): `saipa_pride_body_4.png`, `veh_03…_wheel_pkjhg.png`, `veh_03…_wheel_black.png`, `veh_01…_wheel_IKCO_Tara.png`, `veh_01…_wheel_Tara_NIMALAW.png`, `veh_05…_body_vehiclelights128.png`, `veh_05…_wheel_black.png` (~2.0 MB) | Byte-identical twins remained in place. After deletion: cold `--import` produced **zero** missing-texture errors (GLBs embed their images) and 165 model/carpack/regression checks passed; showroom screenshots confirm intact materials |
| Dead code in `saipa_vehicle_controller.gd`: `apply_driving_preset()`, `active_driving_preset`, 6 `_base_*` state vars | Zero callers in scripts/tests/scenes (driving presets were removed from the UI in an earlier pass). −46 lines |
| Dead exports `hood_cam_offset`, `cabin_eye_offset`, `cabin_look_offset` + assignments in 6 `*_vehicle.tscn` | Camera modes that used them were removed in Pass 3; no code reads them. Lines removed from scenes; integrity suite re-validates all 18 vehicle scenes |
| `VehicleHud.main_scene_ref` (write-only state) + `_target_main` parameter renamed | Written once, never read. Parameter kept for caller compatibility |
| `main_driving_template.get_active_vehicle_index()` | Zero references (tests read the public var directly) |

### MUST PRESERVE — kept after explicit verification

- All 6 vehicles × 3 scenes and the legacy Sport Pride asset set (catalog index 0, the default car — **not** legacy dead weight).
- `scenes/preview/` + `scripts/preview/` (used by the 124-check carpack integration suite).
- `reports/physics_metrics.json`, `reports/integration_metrics.json` (written by test suites at run time).
- All fonts + `OFL.txt`, `LICENSES.md`, every `.uid`/`.import` sidecar of surviving files.
- All 6 pre-existing test suites (266 checks) — none deleted; one obsolete assertion was updated to the new project name (spec change approved by the user).

## 3. Legacy-version elimination

The historical duplication risk in this project was *systems*, not files. The audit confirmed one authoritative implementation each: camera (single free-follow; hood/cabin/orbit modes were already removed in Pass 3 and their last dead exports were deleted now), vehicle switching (showroom-only), settings (one panel/store), theme (one `UiTheme`), capture tooling (5 scripts → 1). No duplicate scripts/scenes with identical content existed (hash scan).

## 4. Directories reorganized (conservative)

- `scripts/main_driving_template.gd` → `scripts/main/main_driving_template.gd` (scripts/ now mirrors scenes/ exactly; UID preserved, one `.tscn` reference updated).
- `scripts/tests/capture_pass3_previews.gd` → `tools/capture_previews.gd`; `scripts/tests/` directory eliminated.
- Capture output `previews_pass3/` → `reports/screenshots/`; new `documentation/` folder added; screenshots renamed to a 15-item review sequence (01–15) + 1 editor capture.

## 5. Statistics

| Metric | Before | After |
|---|---|---|
| Files (excl. `.godot`) | 300 | 262 (after adding 16 screenshots, 6 new docs, 1 new test suite + its `.uid`) |
| Project size (excl. `.godot`) | ~58 MB | 54,342,916 bytes (~53 MB) |
| Production GDScript | 5,583 lines (incl. tests/tools) | controller −46 dead lines; no functional code changed |
| Superseded capture scripts | 5 | 1 |
| Automated checks | 266 | **402** (new integrity suite: +136) |
| Broken `res://` references | 0 | 0 |

## 6. Remaining technical debt (honest list)

- Extracted PNG textures beside GLBs duplicate data already embedded in the GLBs (~35 MB of the project). They are kept deliberately: they are the only editable texture sources. A future pipeline pass could move them to a non-exported `assets/source/` tree.
- The two metrics JSONs in `reports/` are test outputs committed to the tree; harmless, but they change on every full test run.
- `SettingsManager` uses static mutable state (deliberate for this project's scale); a larger game would move it to an autoload.
- Vehicle scene trios (vehicle/visual/showcase) share structure by copy; a shared base scene could reduce repetition if the fleet grows.
- No automated Android device testing exists (see TESTING.md limitations).
