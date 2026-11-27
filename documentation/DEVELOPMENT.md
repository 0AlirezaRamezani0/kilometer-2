# Kilometer 2 — Development Guide

## 1. Development environment

- **Godot 4.7.2-stable** (standard build; .NET build not required — the project is pure GDScript).
- Any OS the editor supports. Headless test runs work on Linux CI with the official binary.
- Optional: Xvfb + OpenGL3 for screenshot captures on headless machines.

```bash
godot --headless --path . --import          # import / re-import
godot --headless --path . --script res://tests/test_project_integrity.gd
```

There are no addons, plugins, git submodules or package managers to install.

## 2. Project configuration (what lives where)

| Setting | Location |
|---|---|
| Project name, main scene, icon | `project.godot` `[application]` |
| Viewport 1280×720, stretch | `project.godot` `[display]` |
| Default font (Vazirmatn Medium) | `project.godot` `[gui]` |
| Input actions (7) | `project.godot` `[input]` + runtime guarantee in `VehicleInputMap.ensure_actions()` |
| Jolt, 60 Hz physics | `project.godot` `[physics]` |
| GL Compatibility, shadows, MSAA defaults | `project.godot` `[rendering]` (runtime tier overrides via `SettingsManager.apply_viewport_graphics`) |
| Android export | `export_presets.cfg` (display name "Kilometer 2", version 4.0.0/code 4, id `org.saipa.drivingtemplate` kept for install identity) |
| Player settings | `user://kilometer2_settings.cfg` at runtime (not in the repo) |

## 3. Coding standards

- GDScript with static typing where practical; `class_name` for shared types (`VehicleCatalog`, `SettingsManager`, `UiTheme`, controllers…).
- Scenes stay thin (root + script); layout is built in `_ready()` code using `UiTheme` factories — never invent local colors/styles in a screen.
- Semantic colors only: `UiTheme.COLOR_ACCENT / OK / WARN / DANGER / MUTED / TEXT`.
- Naming: `snake_case` files/functions/variables, `PascalCase` classes, scenes named after their root script's domain (`vehicle_hud.tscn` ↔ `scripts/ui/vehicle_hud.gd`). Scripts mirror the `scenes/` tree.
- Comments explain *why* (invariants, past bugs), not *what*. Keep the documented invariants in `ARCHITECTURE.md` §1 intact.
- Persian UI strings live in the UI scripts; keep RTL only on text containers, telemetry numerals Latin.

## 4. How to modify the project

### Add a new vehicle
1. Add `assets/vehicle/carpack/veh_XX_name/` with `*_body.glb`, `*_wheel.glb` (+ textures).
2. Create the three scenes in `scenes/vehicle/` by duplicating an existing car's trio and re-pointing the GLB instances (vehicle scene: physics rig on `SaipaVehicleController`; showcase: body + wheel meshes under `WheelMountFL/FR/RL/RR`; visual: body only).
3. Append one entry to `VehicleCatalog.ENTRIES` (id, names, scene paths, measured mass/wheelbase/wheel radius, paint).
4. Bump `catalog_has_six_vehicles` in `tests/test_project_integrity.gd` and run all suites. The showroom, HUD label and spawn flow pick the car up automatically.

### Add a setting
Add a static var + load/save lines in `SettingsManager` (with clamping), a control in `SettingsPanel`, and an apply path (`apply_to_systems` or a dedicated applier). Add a persistence round-trip check to `tests/test_pass3_ui_camera.gd`.

### Change graphics behavior
Only through `SettingsManager.apply_viewport_graphics()` + `EngineeredTestTrack.set_shadow_quality()` + `SaipaVehicleController.set_graphics_quality_tier()`, called from `VehicleHud.apply_graphics_quality()` at scene start or on explicit settings change. Never call these from spawn/bind paths (that coupling was the historical "changing the car changes the graphics" bug).

### Add a UI screen
Thin `.tscn` (root + script) in `scenes/ui/`, build controls in code with `UiTheme.make_theme()` and factories, Persian strings inline, RTL on text containers only.

## 5. Asset management

- Source GLBs and their extracted textures are committed as delivered; Godot imports them into `.godot/` (git-ignored). Textures are embedded in GLBs — do not delete PNGs that share names across body/wheel without an import test (see CLEANUP_REPORT.md).
- New art should follow the `veh_XX_slug` convention and be measured (dimensions, wheel radius) before catalog entry; `tests/test_phase3_model_audit.gd` encodes the geometry expectations.
- Licenses for every third-party asset go in `LICENSES.md` and `documentation/ASSET_CATALOG.md` at import time.

## 6. Development workflow

1. Open in Godot 4.7.2, let the first import finish (cold-cache font error on the very first import is transient; a second import is clean).
2. Make the change on the smallest surface that owns it (ARCHITECTURE.md invariants).
3. Run the affected suite, then **all** suites:
   ```bash
   for t in tests/test_*.gd; do godot --headless --path . --script "res://$t"; done
   ```
   Expected: 701 passed, 0 failed (counts grow as you add checks — keep them green).
4. If UI changed, regenerate screenshots:
   ```bash
   xvfb-run godot --path . --script res://tools/capture_previews.gd --rendering-driver opengl3
   ```
   and eyeball the results in `reports/screenshots/`.
5. Update `CHANGELOG.md` and, if structure changed, `documentation/`.

## 7. Exporting (Android)

Editor → Export → Android. The preset already targets `export/android/Kilometer_2.apk`, excludes dev content, and keeps the historical application id so existing installs upgrade in place. You need the Godot 4.7 Android export templates and a JDK/Android SDK per Godot's official docs.
