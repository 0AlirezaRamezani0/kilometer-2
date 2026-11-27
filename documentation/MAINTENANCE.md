# Kilometer 2 — Maintenance Guide

## 1. Golden rules (invariants that keep this project healthy)

1. Vehicle selection lives **only** in the main-menu showroom; the driving session is locked to the persisted choice.
2. One camera behavior (free-follow). Do not reintroduce camera modes without removing this rule deliberately and updating tests.
3. Graphics are applied **only** at scene start or on explicit settings edits (`VehicleHud.apply_graphics_quality`). Never from spawn/bind code.
4. All UI styling flows through `UiTheme`; all settings through `SettingsManager`.
5. The showroom must instantiate `showcase_scene` (with wheels), never `visual_scene` (3.1.1 bug).
6. RTL only on text containers; never on anchoring roots.
7. UI is styled through `UiTheme` theme variations (`PrimaryButton`, `TitleLabel`, `GlassPanel`, …); add a variation instead of scattering overrides. One filled `PrimaryButton` per screen.
8. Every overlay goes through a `UiModalStack` (focus trap + Esc/B + focus return). Never show a modal by toggling `visible` alone.
9. Persian text via `UiTheme.label()`; numbers in prose via `UiTheme.fa_*`; instruments stay Latin. Prompts via `InputPrompts` (never hard-code «Esc» or «A»).
10. Movement animations use `motion_sec()` (0 under reduced motion) and `offset_transform_*` so layout never moves.

## 2. Routine maintenance

| Task | Command / action |
|---|---|
| Re-import after asset changes | `godot --headless --path . --import` (run twice from a cold cache; first-run font message is transient) |
| Full test pass | `for t in tests/test_*.gd; do godot --headless --path . --script "res://$t"; done` → expect all green (836 checks at v0.1-b4; totals grow with new checks) |
| Refresh screenshots | `xvfb-run godot --path . --script res://tools/capture_previews.gd --rendering-driver opengl3` |
| Clear regenerable cache | Delete `.godot/` (never commit it; it is git-ignored) |
| Clean a test run's outputs | `reports/*.json` are regenerated; safe to delete |

## 3. How to extend

- **New vehicle / setting / UI screen:** follow the recipes in `DEVELOPMENT.md` §4, then extend the relevant suite (carpack for vehicles, pass3 suite for settings/UI) and the integrity count if the catalog size changes.
- **New system:** put its script under the matching `scripts/<domain>/` folder, scene (if any) under `scenes/<domain>/`, and wire it through the scene coordinator — not through new autoloads, unless state must truly outlive scenes.
- **Renaming/moving resources:** move files inside the Godot editor (it rewrites references), or if scripting it, update every `res://` reference and keep `.uid` files paired with their resources. Afterwards run the integrity suite — it load-tests every scene and script.

## 4. Troubleshooting

| Symptom | Likely cause & fix |
|---|---|
| Font error on first import after deleting `.godot/` | Expected cold-cache ordering artifact; import again — must reach 0 errors |
| Car has no wheels in the menu | `main_menu.gd` must load `showcase_scene`; check `showroom_*_has_wheels` checks in `test_pass3_ui_camera.gd` |
| "Changing X changed the graphics" | Something re-applied graphics outside scene-start/settings-change. Audit new calls to `apply_graphics_quality`, `apply_viewport_graphics`, `set_shadow_quality`, `set_graphics_quality_tier` |
| Steering/pedal zones swapped sides | RTL was set on an anchoring root Control. Restrict RTL to text containers |
| Pause dialog won't show / Esc misbehaves | Confirmations must be in-layer panels inside the HUD CanvasLayer (Window dialogs don't pop reliably while paused); Esc handling checks the settings box visibility first |
| Two vehicles in the driving scene | Spawn path must free existing `SaipaVehicleController` children first (`main_driving_template.spawn_vehicle` does); never instantiate vehicle scenes elsewhere in the driving scene |
| Tests fail after moving a file | A `res://` path or UID pairing broke. Run `test_project_integrity.gd`; it names the failing scene/script |
| Settings seem reset after 4.0.0 | Expected once: `user://` follows the project name ("Kilometer 2"). Old settings remain in the old-named folder, unused |

## 5. Updating Godot

The project targets the 4.7 feature tag. To move to a newer 4.x: open a *copy* in the new editor, import, run all suites + captures, and only then adopt it. Do not upgrade mid-feature. Godot 3.x is incompatible.

## 6. Release checklist

1. All suites green; screenshots refreshed and eyeballed.
2. `CHANGELOG.md` entry with version bump; `export_presets.cfg` version/code in sync.
3. Cold-cache import clean (second run 0 errors).
4. Zip the project **without** `.godot/`; extract the zip elsewhere, import, run the integrity + pass3 suites against the extracted copy.
5. Verify asset licenses (`LICENSES.md`, ASSET_CATALOG.md) before any public/commercial build — especially vehicle-brand decals.

## Showroom stage — licence switch (v0.1-b4)

The menu stage is the **"Car Garage | Desert Garage Environment"** diorama by DevPoly3D,
licensed **CC BY-NC 4.0** (attribution mandatory, **no commercial use**). Before any paid or
ad-monetised release:

1. Obtain a commercial licence from DevPoly3D, **or**
2. drop the diorama: pass `--hangar-stage` (or make `_garage_stage_requested()` return
   `false`), delete `assets/environment/garage/`, and remove §6 from `THIRD_PARTY_ASSETS.md`
   plus the garage credit line in the menu's help panel (`_build_help_overlay`).

Attribution must stay visible in-game (Help → «دربارهٔ بازی و مجوزها») for as long as the
diorama ships. `tests/test_garage_stage.gd` fails if the credit line, the licence file or the
stage itself goes missing.
