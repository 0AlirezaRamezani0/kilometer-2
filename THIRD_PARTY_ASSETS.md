# Third-Party Assets — Kilometer 2

> **v0.1-b4 status (2026-11-26):** the showroom stage is now the **desert garage diorama**
> (§6, CC BY-NC 4.0 — attribution is mandatory and is shown in-game in the Help/«راهنما»
> panel). The v0.1-b3 "Proving Ground" UI still draws every UI element and the instrument
> cluster in code from `UiTheme` tokens. **In use:** Estedad and Changa fonts (§3, §4) and the
> garage diorama (§6). **Retained on disk but no longer referenced by any script** (the
> procedural hangar remains only as a fallback stage, `--hangar-stage`): the Racing HUD Kit
> dials (§1), the Racing UI Kit (§2) and the Softline UI Kit (§5). A test
> (`tests/test_ui_v3_design_system.gd › retired_ui_kits_unreferenced`) guards this, and
> `tests/test_garage_stage.gd` guards the new stage.

This project uses UI assets by **Ville Seppänen** under **CC BY 4.0**.
Attribution is required and is shown in-game (main menu → Help / «راهنما» panel).

Required credit line (verbatim from the kits' readmes):

> Assets by Ville Seppänen https://www.villeseppanen.com

License: Creative Commons Attribution 4.0 International (CC BY 4.0)
https://creativecommons.org/licenses/by/4.0/
Access date for both kits: **2026-11-23**

It also uses the **Estedad** and **Changa** fonts under the **SIL Open Font
License 1.1** (see sections 3 and 4 — no attribution is required by OFL,
the license texts ship in `assets/fonts/` for compliance).

It also uses the **Softline UI Kit — Flat Night** by **The Cooked Works**
(see section 5 — modification/recolor/commercial use allowed, attribution
NOT required; a voluntary credit line is shown in-game next to the Ville
line in the main menu → Help / «راهنما» panel).

---

## 1) Racing HUD Kit — Ville Seppänen

- Source page: https://villesep.itch.io/racing-hud-kit-free-game-ui-asset-pack
- Author site: https://www.villeseppanen.com
- License: CC BY 4.0 (statement inside the kit's `copyright_readme_racing_hud.txt`,
  copied next to the assets)
- Location in project: `assets/ui/ville/hud/`
- Pieces used:
  - `speedometer1.png` — analog speedometer dial face (0–220 scale; mapped 1:1 to km/h in-game)
  - `tachometer1.png` — analog tachometer dial face (RPM ×1000)
  - `needlelong1.png` — speedometer needle
  - `needleshort1.png` — tachometer needle
  - `pointershaft1.png`, `pointershaft2.png` — needle centre caps
  - `copyright_readme_racing_hud.txt` — original license readme (unmodified)
- Known cosmetic limitation: the speedometer face texture has small "MPH"
  lettering baked in; the dial numbers 0–220 are mapped directly to km/h.

## 2) Racing UI Kit — Ville Seppänen — **NOT USED (as of B8 UI-CLEAN)**

- Source page: https://villesep.itch.io/racing-ui-kit
- Author site: https://www.villeseppanen.com
- License: CC BY 4.0 (statement on the source page and inside the source PSD's
  `__INFO` layer group; see `assets/ui/ville/menu/README_racing_ui_kit_license.txt`)
- Location in project: `assets/ui/ville/menu/` (files retained, **unused**)
- The kit ships as a single layered PSD only; the PNGs below were exported from
  individual PSD layers with psd-tools and recolored to the game's
  graphite/vermilion theme (modification is permitted under CC BY 4.0).
- Status history: briefly used in the B8 UI-VILLE pass (hexagonal button
  textures on the primary CTAs and carousel cards, `bar_bg.png` behind the
  spec bars, switch textures as CheckButton icons). **Removed in the
  B8 UI-CLEAN pass at the user's order** — menu buttons/panels are flat
  theme styleboxes again and CheckButton icons are drawn in-theme.
  No code references these files anymore; they are kept in the project
  only as a local archive. The in-game Ville credit line stays because
  the Racing HUD Kit (section 1) is still in use.
- Pieces (all unused):
  - `btn_primary.png` — hexagonal button (PSD group "BUTTONS", layer 126)
  - `btn_normal.png` — hexagonal button (PSD group "BUTTONS", layer 127)
  - `bar_bg.png` — bar background (PSD group "BAR BGS", layer 7)
  - `switch_on.png` / `switch_off.png` — toggle switches (PSD group
    "SWITCHES", layers 116 / 115)
  - `README_racing_ui_kit_license.txt` — license note for this kit

---

## 3) Estedad — Amin Abedi (main UI font family)

- Source: https://github.com/aminabedi68/Estedad (official repository,
  release v8.5)
- License: SIL Open Font License 1.1 (OFL) —
  https://openfontlicense.org — full text in `assets/fonts/OFL-Estedad.txt`
- Copyright (from the font files): Copyright 2026 The Estedad Project
  Authors (https://github.com/aminabedi68/Estedad)
- Attribution: not required by OFL; recorded here for provenance.
- Access date: **2026-11-23**
- Location in project: `assets/fonts/`
- Weights used: `Estedad-Regular.ttf` (body), `Estedad-Medium.ttf`
  (project default font), `Estedad-Bold.ttf` (buttons/labels),
  `Estedad-Black.ttf` (titles, vehicle name, big numbers).
  Wired via `UiTheme` (`FONT_*_PATH`) and `project.godot`
  (`theme/custom_font`). Persian glyphs incl. گ چ پ ژ and Persian digits
  ۰-۹ verified in captures.

## 4) Changa ExtraBold — Eduardo Tunni (Latin display numerals)

- Source: Google Fonts — https://fonts.google.com/specimen/Changa
  (upstream: https://github.com/eliheuer/changa-vf)
- License: SIL Open Font License 1.1 (OFL) —
  https://openfontlicense.org — full text in `assets/fonts/OFL-Changa.txt`
- Copyright (from the font file): Copyright 2018 The Changa Project
  Authors (https://github.com/eliheuer/changa-vf)
- Attribution: not required by OFL; recorded here for provenance.
- Access date: **2026-11-23**
- Location in project: `assets/fonts/Changa-ExtraBold.ttf`
- Used for: Latin display numerals only — the speed value in the HUD
  top pill (`SpeedValueLabel`, via `UiTheme.font_changa_xbold()`).

---

## 5) Softline UI Kit — Flat Night — The Cooked Works

- Source page: https://the-cooked-works.itch.io/softline-ui-kit-flat-night-free-game-ui-pack
- Author: The Cooked Works
- License: the kit's own license (LICENSE.pdf v1.2, copied verbatim into
  `assets/ui/softline/LICENSE.pdf`). Summary: free for personal and
  commercial use; modification and recoloring explicitly allowed;
  redistribution/resale of the asset files themselves is prohibited.
  **Attribution is NOT required.** Suggested line (used voluntarily
  in-game, in the Help panel next to the Ville credit):
  "UI: Softline UI Kit by The Cooked Works"
- Access date: **2026-11-24**
- Location in project: `assets/ui/softline/` (SVG sources only; Godot
  rasterizes them on import. `slices.json` from the kit is copied there
  too — its 9-slice margins drive the `StyleBoxTexture` content/texture
  margins in `UiTheme`.)
- Recolor: the kit's orange accent family was recolored from the SVG
  sources to the game's vermilion tokens — `#FF7A45 → #FF3D2E`
  (accent), `#FF8758 → #FF5A4D` (hover), `#E06B3D → #D92B1E` (pressed).
  The kit's charcoal neutrals are used exactly as shipped.
- Pieces used (wired through `UiTheme`'s `softline_*` helpers):
  - Buttons: large/small × primary/secondary × normal/hover/pressed,
    plus both disabled pieces — theme default buttons, primary CTAs,
    nav tabs, car carousel cards, settings dropdowns.
  - `panels/panel.svg`, `panels/panel_inset.svg` — settings/info/pause/
    sheet/LAN panels.
  - `controls/toggle_on/off.svg` — CheckButton icons;
    `controls/checkbox_on/off.svg`, `controls/radio_on/off.svg` —
    CheckBox icons.
  - `controls/slider_track.svg`, `controls/slider_fill.svg`,
    `controls/slider_knob.svg` — settings sliders.
  - `controls/tab_active.svg` — active settings/menu tab.
  - `controls/scrollbar_track.svg`, `controls/scrollbar_thumb.svg`.
  - `bars/bar_track.svg`, `bars/bar_fill_primary.svg` (recolored;
    kit name `bar_fill_accent.svg`), `bars/bar_fill_blue.svg`,
    `bars/bar_fill_yellow.svg` — vehicle spec bars + ProgressBar theme.
  - `fields/input_normal.svg`, `fields/input_focus.svg` — LineEdit theme.
  - `items/hud_pill.svg` — HUD status pill + settings value readouts.
- Note: the kit's README discloses AI-assisted creation of the artwork.

## 6) Car Garage | Desert Garage Environment — DevPoly3D — **IN USE (v0.1-b4)**

| Item | Value |
|---|---|
| File | `assets/environment/garage/garage_desert.glb` (6.0 MB, glTF 2.0) |
| Licence | **CC BY-NC 4.0** — https://creativecommons.org/licenses/by-nc/4.0/ |
| Source | https://sketchfab.com/3d-models/car-garage-desert-garage-environment-ef8bb81713814d688487a81ae2467a51 |
| Author | DevPoly3D — https://sketchfab.com/DevPoly3D |
| Delivered as | `Mobile_Optimized_Model_001.fbx` + textures (converted to glTF 2.0 in Blender 4.3.2, no geometry change) |
| Content | 49 meshes, 16 materials, 10 315 triangles, 12 base-colour textures |
| In-game use | Main-menu showroom stage (behind the vehicle turntable) |

Required credit (shown in the in-game Help panel and in `README.md`):

> This work is based on "Car Garage | Desert Garage Environment"
> (https://sketchfab.com/3d-models/car-garage-desert-garage-environment-ef8bb81713814d688487a81ae2467a51)
> by DevPoly3D (https://sketchfab.com/DevPoly3D) licensed under CC-BY-NC-4.0
> (http://creativecommons.org/licenses/by-nc/4.0/).

**Non-commercial restriction:** NC forbids use "primarily intended for or directed toward
commercial advantage or monetary compensation". A free build is fine; **any paid or ad-monetised
release must first obtain a separate licence from DevPoly3D** (or the stage must be swapped back
to the procedural hangar with `--hangar-stage`). See `LICENSES.md` §6.

## 7) Desert circuit map — **RETIRED in v0.2-b2-racetrack-obj**

| Item | Value |
|---|---|
| Files | `assets/track/desert_circuit_opt.glb` (4.7 MB, glTF 2.0), embedded palette + terrain JPG |
| Delivered as | `Desert_Track_Godot_Package.zip` → `Godot_Project/Desert_Track_Godot.glb` (9.7 MB, 117,612 tris), re-exported by `tools/track_survey/optimize_glb.py` |
| Content | `Track` mesh (road ribbon, kerbs, catch fencing, start gantry, light towers) + `Desert_Visual` terrain |
| Verified licences | Terrain base: **CC BY 4.0** — josevega, Sketchfab «FREE - Dry Sand Terrain» (attribution required, see below). `LICENSE_terrain.txt` ships with the delivered package. |
| **Release blocker** | The **track mesh licence is not stated anywhere in the delivered package** (`README.txt` only describes the export). Obtain the author's written licence for the track geometry and for the 8×8 UV palette before any public/paid build. Tracked in `LICENSES.md` §7. |

Required credit for the terrain base (also shown in the in-game Help panel):

> Terrain based on "FREE - Dry Sand Terrain" by josevega
> (https://sketchfab.com/josevega), licensed CC BY 4.0
> (http://creativecommons.org/licenses/by/4.0/).

Optimisation performed in-house (documented in `documentation/DESERT_CIRCUIT.md`):
vertex weld, seam-safe coplanar dissolve, asphalt-protected decimation of the props only,
terrain collapse 24,200 → 8,488 tris, terrain photo 2048² → 1024². The UV palette texture is
kept lossless (PNG) because it carries the material colours, not a photo.

## 8) Racetrack — **IN USE (v0.2-b2-racetrack-obj)**

| Item | Value |
|---|---|
| Files | `assets/track/racetrack.glb` (172 KB), source `racetrack.obj` + `racetrack.jpg` |
| Author | **Ville Seppanen** |
| Licence | **CC BY 3.0** (http://creativecommons.org/licenses/by/3.0/) |
| Required credit | `Ville Seppanen` in the in-game credits list and any contributor list |
| Built by | `tools/newtrack/build_newtrack2.py` — OBJ → glTF, colours per group taken from the delivered atlas |

**Why the atlas is not used as a texture:** its UVs do not correspond to `racetrack.jpg`
(projecting the terrain's positions onto its own UVs gives r = 0.017 in x, −0.03 in z, i.e.
no relationship at all), and the picture is a *baked top-down view of the island*, so on
vertical faces it smears into stripes. It is a **preview render, not a texture map**. The
circuit therefore uses per-group colours read off that same picture:

| Group | Colour | Where it came from |
|---|---|---|
| track | `(0.30, 0.30, 0.30)` | the mid-grey asphalt band |
| kerb | `(0.82, 0.82, 0.80)` | the white kerb stripe |
| terraintransition | `(0.62, 0.55, 0.30)` | dry grass |
| treelines | `(0.05, 0.09, 0.01)` | the darkest 5 % of the atlas |
| terrain | `(0.63, 0.57, 0.32)` | the dominant non-grey cluster (14 % of the atlas) |

### Desert terrain — **IN USE**

`assets/track/desert_ground.glb` (1.2 MB, 24,200 tris): josevega, CC BY 4.0, as in §7.
Exported from the delivered original, weld only.
