# Licenses & Third-Party Attribution (`LICENSES.md`)

## 1. Template Source Code, Scenes, Procedural Track & Documentation
- **Scope**: All GDScript files (`scripts/`), automated test suites (`tests/`), Godot scene definitions (`scenes/`), procedural proving-ground materials, Persian UI controls, and Markdown engineering reports (`reports/`, `README.md`, `CHANGELOG.md`).
- **License**: **MIT License** — free to use, modify, extend, and redistribute with attribution.

---

## 2. Persian Typography — Vazirmatn Font (`assets/fonts/`)
- **Files**: `assets/fonts/Vazirmatn-Regular.ttf`, `assets/fonts/Vazirmatn-Medium.ttf`, `assets/fonts/Vazirmatn-Bold.ttf`, and `assets/fonts/OFL.txt` (official `Vazirmatn` release `v33.003`).
- **Author**: Saber Rastikerdar (`https://github.com/rastikerdar/vazirmatn`).
- **License**: **SIL Open Font License 1.1 (`OFL-1.1`)** — full license text included verbatim in `assets/fonts/OFL.txt`.

---

## 3. Provided 3D Vehicle Asset (`sport_pride.zip`)
- **Source Files**: `Optional_Intermediates/editable_project.blend`, `Sport_Pride_Optimized.fbx`, and `Textures/*.png` (`54` source PNGs), converted into `assets/vehicle/saipa_pride_body.glb` and `assets/vehicle/saipa_pride_wheel.glb`.
- **Provenance**: Provided directly by the project requester via Google Drive (`file_id = 12WpIbCYEXizSI5hXNgRenHnaEH6ZEn_1`, SHA-256 `e03c31d42c6e2314cdd0d51761f89b1f00b5a565192dc638b4a2a7318b763509`).
- **Embedded Upstream Credit**: Root hierarchy empty inside `editable_project.blend` reads `'Pride Tuning M-T ;) @GTA_SA_MT'`.
- **License Status**: **NO EXPLICIT LICENSE FILE INCLUDED IN SOURCE ARCHIVE**.
  - This asset was converted strictly for use inside the requester's private prototype/template as instructed.
  - Real-world automotive/aftermarket brand names and logos visible in the source textures (`PRIDE` / Saipa / Kia, `Bride`, `Yokohama ADVAN Neova`, `KOYORAD`, `Takara`, `GANDO`) remain the property of their respective trademark holders. Before commercial publication on public app stores (e.g., Google Play), verify upstream 3D mesh redistribution rights and replace or clear third-party brand decals as appropriate.

---

## 4. Godot Engine 4.7.2 & Jolt Physics Runtime (Bundled in Exported Android APK)
- **Godot Engine `4.7.2.stable`**: Copyright (c) 2014-present Godot Engine contributors; Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur. Licensed under the **MIT License** (`https://godotengine.org/license`).
- **Jolt Physics**: Copyright (c) 2021 Jorrit Rouwe. Licensed under the **MIT License** (`https://github.com/jrouwe/JoltPhysics/blob/master/LICENSE`).
- **FreeType / HarfBuzz / MbedTLS / Vulkan / Khronos Headers** (inside standard Godot Android export template): Licensed under their respective permissive open-source licenses as documented at `https://docs.godotengine.org/en/stable/about/complying_with_licenses.html`.

---

## 5. Build-Time Conversion Tooling (Not Bundled in Project or APK)
- **Blender `4.3.2`** (`GPL-3.0-or-later`) was used strictly as an offline build-time conversion tool to export `editable_project.blend` into standard Khronos glTF 2.0 `.glb` files. No Blender code is included in `VehicleTemplate/` or `saipa_beta_3.apk`.

## 6. Showroom Garage Environment (`assets/environment/garage/`)

- **Asset:** "Car Garage | Desert Garage Environment" by **DevPoly3D** (Sketchfab).
- **Licence:** Creative Commons Attribution-NonCommercial 4.0 International (CC BY-NC 4.0)
  — https://creativecommons.org/licenses/by-nc/4.0/
- **Source:** https://sketchfab.com/3d-models/car-garage-desert-garage-environment-ef8bb81713814d688487a81ae2467a51
- **Files:** `garage_desert.glb` (glTF 2.0 conversion of the delivered FBX, no geometry change),
  `LICENSE_CC-BY-NC-4.0.txt` (verbatim source licence), `README_IMPORT_NOTES.txt`.
- **Attribution:** mandatory; shown in-game (main menu → «راهنما» → «دربارهٔ بازی و مجوزها»),
  in `README.md` and in `THIRD_PARTY_ASSETS.md` §6.
- **⚠ Non-commercial only.** A paid or ad-monetised release of Kilometer 2 must either obtain a
  commercial licence from DevPoly3D or ship the procedural hangar stage instead (the code keeps
  it as a fallback: `godot --path . -- --hangar-stage`). This is an owner decision and is listed
  as an open risk in `documentation/MAINTENANCE.md`.

## 7) Desert circuit map — **REPLACED in v0.2-b2-racetrack-obj**

The map from `Desert_Track_Godot_Package.zip` is **no longer in the project** (its geometry
and its licence problem both went with it). The circuit is now **§8** below. Only its desert
terrain is still used, and that terrain is josevega's CC BY 4.0 mesh — see §8.

Historical note (kept because the licence file is still on disk in `archive/`):

## 7b) Desert circuit map (v0.2-b1, retired)

The delivered track package (`Desert_Track_Godot_Package.zip`) contains
`LICENSE_terrain.txt` covering the **terrain** mesh only (CC BY 4.0, josevega, Sketchfab
"FREE - Dry Sand Terrain"). It contains **no licence statement for the track geometry**
(road ribbon, kerbs, catch fencing, start gantry, light towers) nor for the 8×8 UV palette
that colours it.

Status: **UNRESOLVED — release blocker for public builds.** The geometry is shipped in the
current internal build because the brief explicitly asked for this map to replace the
proving ground; before any store/public release the author must supply a written licence
(or the track mesh must be replaced with in-house geometry surveyed from the same layout —
the centreline in `assets/track/centerline.json` makes that rebuild mechanical).

## 8) Racetrack by Ville Seppanen — **IN USE (v0.2-b2-racetrack-obj)**

| Item | Value |
|---|---|
| Files | `assets/track/racetrack.glb` (172 KB, 3,524 tris) built from `racetrack.obj` + `racetrack.jpg` |
| Author | **Ville Seppanen** — <http://vvvvvv.org>`/`racetrack readme |
| Licence | **CC BY 3.0** — <http://creativecommons.org/licenses/by/3.0/> |
| Requirement | the author's name **"Ville Seppanen"** must appear in the credits list in the game and everywhere else contributors are listed |
| Verbatim clause | *"to include my name "Ville Seppanen" in the credits list in the application/game and everywhere else where the creators/contributors are listed"* |
| Attribution shown | in-game credits + this file + `THIRD_PARTY_ASSETS.md` §8 + `documentation/DESERT_CIRCUIT.md` |

No separate licence exists for `racetrack.jpg`; it is treated as part of the same work
(the OBJ references it as its material map).

### Desert terrain (still in use)

`assets/track/desert_ground.glb` (1.2 MB, 24,200 tris) is the `Desert_Visual` mesh from
`Desert_Track_Godot_Package.zip`, exported **straight from the delivered original** (welded
vertices only — no dissolve, no decimation), because the earlier optimisation had turned the
flat desert into 92 oversized plates.

> Terrain based on "FREE - Dry Sand Terrain" by josevega
> (https://sketchfab.com/josevega), licensed CC BY 4.0
> (http://creativecommons.org/licenses/by/4.0/).

`LICENSE_terrain.txt` from the delivered package covers this mesh and only this mesh.
