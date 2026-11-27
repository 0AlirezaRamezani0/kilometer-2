# Kilometer 2 — Architecture

## 1. Overall architecture

Kilometer 2 is a single-player 3D driving game with a strictly linear flow:

```
Main Menu (3D showroom)  →  Driving scene (track + 1 vehicle + HUD)
        ↑                            │
        └──────── pause → main menu ─┘
```

Design invariants (enforced by tests, do not break them):

1. **Vehicle selection exists only in the main menu.** The driving scene spawns exactly the persisted vehicle and locks it. There is no switching input, button or public method.
2. **Exactly one camera behavior** — a free-follow chase camera.
3. **Graphics settings have a single owner** (`SettingsManager` statics) and are applied only at scene start or on explicit settings edits. Spawning/binding a vehicle never re-applies graphics.
4. **One theme source** (`UiTheme`) for every screen; no screen invents colors or styles.

## 2. Directory structure

| Path | Contents |
|---|---|
| `project.godot` | Engine config: main scene, input actions, GL Compatibility, Jolt, 60 Hz physics |
| `export_presets.cfg` | Android preset (APK `Kilometer_2.apk`, v4.0.0); excludes `tests/`, `tools/`, `reports/` |
| `scenes/main/` | `main_driving_template.tscn` — the playable scene (5 root nodes; content code-driven) |
| `scenes/ui/` | `main_menu.tscn`, `settings_panel.tscn`, `vehicle_hud.tscn` (thin scenes: root node + script) |
| `scenes/vehicle/` | 18 scenes: for each of 6 cars `*_vehicle.tscn` (physics rig), `*_visual.tscn` (body rig), `*_showcase.tscn` (body + 4 wheel meshes for the showroom) |
| `scenes/camera/` | `vehicle_camera_rig.tscn` (SpringArm3D + Camera3D) |
| `scenes/track/` | `test_track.tscn` |
| `scenes/preview/` | `asset_integration_preview.tscn` — studio scene used by the carpack integration suite |
| `scripts/` | Mirrors `scenes/` (`camera/ main/ preview/ track/ ui/ vehicle/`). 17 production scripts |
| `assets/fonts/` | Vazirmatn Regular/Medium/Bold + OFL license |
| `assets/vehicle/` | Sport Pride `saipa_pride_body/wheel.glb` + extracted textures |
| `assets/vehicle/carpack/veh_01…05/` | Per-vehicle `*_body.glb`, `*_wheel.glb`, extracted textures |
| `tests/` | 17 headless SceneTree suites, 842 checks |
| `tools/` | `capture_previews.gd` — screenshot tool (dev-only, export-excluded) |
| `reports/` | `screenshots/` (16 review images), `physics_metrics.json`, `integration_metrics.json` (test outputs) |

Scenes are intentionally thin: node structure that must be tuned visually lives in `.tscn`; everything else is built in code so diffs stay reviewable.

## 3. Main scenes

- **`scenes/ui/main_menu.tscn`** (project main scene) — `scripts/ui/main_menu.gd` builds the 3D showroom and the RTL menu card in code. Since **v0.1-b4** the stage is the **desert-garage diorama** (`assets/environment/garage/garage_desert_lite.glb` — 1.4 MB optimised build; the full 5.7 MB conversion `garage_desert.glb` stays as a fallback — CC BY-NC 4.0): `_build_garage_stage()` instantiates it, culls the roof slabs above 6.3 m, merges all meshes into one `ArrayMesh` with one surface per material (`_garage_merge_by_material`, 49 → ≤16 surfaces), grades the materials to the graphite night palette, re-seats the model on `y = 0` and seats the wheels on the model's own turntable disc (`_garage_turntable_surface_y()` measures the disc surface from the mesh — 0.144 m — and the car is parked at y = 0.148). The v0.1-b3 procedural hangar (environment, key/fill/rim lights, floor, rotating platform, accent ring) is kept intact as `_build_procedural_hangar()` and is used when `--hangar-stage` is passed or the model is missing. `_show_vehicle()` instantiates the catalog **`showcase_scene`** (body + wheels; using `visual_scene` here was the 3.1.1 no-wheels bug).
- **`scenes/main/main_driving_template.tscn`** — root `Node3D` + `scripts/main/main_driving_template.gd` coordinator. Children: `EngineeredTestTrack`, `VehicleCameraRig`, `VehicleHud`. `_ready()` spawns the persisted vehicle once, resets it to the track spawn, binds camera/HUD, then applies graphics exactly once.

## 4. Gameplay systems

| System | Implementation | Responsibility |
|---|---|---|
| Vehicle physics | `scripts/vehicle/saipa_vehicle_controller.gd` (`SaipaVehicleController extends VehicleBody3D`) | Engine/brake/reverse gear state machine, speed-sensitive steering, suspension/tire setup, surface-grip sampling via `surface_grip` metadata, anti-roll torque, rollover recovery, visual-wheel synchronization (right-handed bases), cockpit telemetry push |
| Visual model | `scripts/vehicle/saipa_visual_model.gd` | Body hierarchy, paint, headlights/brake lights, cockpit wheel/gauge needles, LOD tier application, runtime static batching |
| Vehicle catalog | `scripts/vehicle/vehicle_catalog.gd` | Single registry of the 6 vehicles: scene paths, mass, wheelbase, wheel radius, FA/EN names, paint |
| Camera | `scripts/camera/vehicle_camera_rig.gd` | Single free-follow: smoothed pivot + yaw, physics-tick update after the vehicle (`process_physics_priority = 10`), SpringArm3D collision, FOV from settings, diagnostics for tests/HUD |
| Track | `scripts/track/engineered_test_track.gd` | Procedural proving ground: zones, grip areas (`surface_grip` metadata), spawn transform, MultiMesh scenery, per-tier shadow quality |
| Input | `scripts/vehicle/vehicle_input_map.gd` | Idempotent runtime guarantee of the 7 InputMap actions (also persisted in `project.godot`) |

## 5. UI systems (v0.1-b3 "Proving Ground")

| Component | File | Notes |
|---|---|---|
| Design system | `scripts/ui/ui_theme.gd` | Colour roles, type scale, spacing/shape/elevation, motion tokens + reduced-motion helpers, Persian digit helpers, RTL label factories, one shared `Theme` with variations (buttons, labels, panels). Legacy builders kept as shims |
| Icons | `scripts/ui/ui_icon.gd` | 46 vector icons (inline SVG → cached textures), tinted by theme icon colours |
| Prompts | `scripts/ui/input_prompts.gd` | Glyphs per action per device (keyboard / gamepad / touch), `PromptChip` auto-updates on device change |
| Device tracking | `scripts/ui/input_device_manager.gd` | Static current mode; broadcasts changes to every tracker; `ensure_tracker()` for UI |
| Overlay model | `scripts/ui/ui_modal_stack.gd` | Push/pop with focus trap (`focus_behavior_recursive`/`mouse_behavior_recursive`), focus return, Esc/B cancel |
| Scene transition | `scripts/ui/scene_transition.gd` (autoload `SceneTransition`) | Fade + loading caption; `SceneTransitionLayer.go()` falls back to a direct change in isolated tests |
| Settings store | `scripts/ui/settings_manager.gd` | Static `ConfigFile`; adds `ui_scale` (content scale factor) and `reduce_motion`; defaults table + reset; granular appliers (window, UI scale, audio, camera, HUD) |
| Settings panel | `scripts/ui/settings_panel.gd` + thin scene | 5 tabs; rows reflow via `BoxContainer.vertical` (no rebuild); domain-only apply; debounced save + chip; reset confirm |
| Showroom | `scripts/ui/main_menu.gd` | 3D stage (unchanged) + app bar, start-side hero, dock, help, quit confirm on a modal stack |
| HUD | `scripts/ui/vehicle_hud.gd` | `HudRoot` (driving chrome; test paths `HudRoot/SteerZone`, `PedalColumn`, `GamepadHintStrip`) + `OverlayRoot` (tools sheet, quick settings, pause drawer + settings, confirm, toast, photo prompts) |
| Cluster | `scripts/ui/persian_gauge_cluster.gd` | Vector dual-dial cluster; real rpm/redline from `SaipaVehicleController`; Label readouts |
| Touch controls | `touch_pedal_button.gd`, `touch_steering_wheel.gd`, `touch_analog_steer_bar.gd` | Input logic unchanged; semantic accents; keyboard letters only in keyboard mode |
| LAN lobby | `scripts/multiplayer/lan_lobby.gd` | Host/guest cards, validated IP, status chip, focus + back |

**RTL rule:** `layout_direction = RTL` only on text containers and labels, never on anchored
roots (an RTL anchored node mirrors its anchors — this is what put the v0.1-b1 showroom card
and pause drawer on the wrong side). Thumb controls are not mirrored. Persian labels are made
with `UiTheme.label()` (explicit RTL paragraph); Latin runs with `UiTheme.ltr_label()`.

## 6. Communication architecture

- **Direct references, minimal signals.** The driving coordinator wires vehicle ↔ camera ↔ HUD in `_ready()` via `bind_*` calls. Signals are used only where lifecycle demands it: `SaipaVehicleController.vehicle_reset_completed` → camera snap; UI `pressed` signals → handlers.
- **Settings bus (pull model).** `SettingsManager.apply_to_systems(hud, rig)` pushes persisted values into live systems at bind time and on settings edits. Systems never read the ConfigFile directly.
- **Test hooks.** Controllers accept external input (`set_control_inputs`, touch fields, `read_desktop_input = false`) so headless suites can drive physics deterministically.

## 7. Resource management

- Vehicles are `load()`ed on demand from catalog paths at menu/spawn time; nothing heavy is preloaded at boot.
- GLB textures are embedded in the `.glb` binaries; the extracted PNGs beside them are source/provenance files imported by Godot (exact-duplicate PNGs were deduplicated in 4.0.0 — verified by cold import).
- The `.godot/` import cache is regenerable and git-ignored; `reports/*.json` are test outputs; `reports/screenshots/` is documentation imagery, export-excluded together with `tests/` and `tools/`.
- All resources keep stable UIDs; the 4.0.0 script move preserved the script UID so scene references stayed valid.
