# Desert circuit (v0.2-b2)

The playable map. This document records **what the delivered model actually contains**, how it
was optimised, and how the gameplay layer is derived from it — everything is reproducible from
the scripts in `tools/track_survey/`.

---

## 1. What was delivered

`Desert_Track_Godot_Package.zip` → `Godot_Project/`:

| File | Notes |
|---|---|
| `Desert_Track_Godot.glb` | 9,690,408 B. Two meshes: `Track` (93,412 tris) and `Desert_Visual` (24,200 tris) |
| `desert_track.tscn` | sample scene, no colliders, no gameplay |
| `preview.gd`, `project.godot` | sample viewer (Compatibility renderer) |
| `Desert_Track_Godot_desert_2k.jpg` | 2048² terrain photo |
| `Desert_Track_Godot_Image_0.png` | **8×8 palette swatch texture** — the only source of colour for `Track` |
| `LICENSE_terrain.txt` | CC BY 4.0, josevega — **terrain only** |

Audit findings that shaped the work:

* The track's colour comes from a **painter's palette UV map**, not textures. Every facet is
  UV-locked to one of nine swatches. Any lossy re-encode of that 8×8 PNG destroys the map, so
  it is exported as PNG while the photographic terrain goes to JPEG.
* The GLB **splits every vertex** (228,902 vertices for 93,412 triangles). Any adjacency walk
  over the mesh yields isolated 2-triangle islands — that is why the centreline could not be
  extracted by walking the topology.
* The layout is a **figure-eight with a flyover**. The N–S leg of the lower loop passes *under*
  the elevated E–W deck, and the deck runs at y ≈ 3.8–4.1 m between x ≈ −18…18, z ≈ −60…4.
* The **start gantry** is over the north spur at x ≈ 0, z ≈ 3.8 (green start-light swatch
  `(0.102, 0.592, 0.035)`, 448 tris, y 3.8–4.1 m).
* There are **no colliders, no gameplay hooks, no lap logic** in the delivered scene.

---

## 2. Optimisation (`tools/track_survey/optimize_glb.py`)

| Metric | Delivered | Shipped | Change |
|---|---|---|---|
| Triangles | 117,612 | **56,815** | −51.7 % |
| Vertices | 241,223 | **121,362** | −49.7 % |
| `Track` tris | 93,412 | 48,513 | props decimated, asphalt protected |
| `Desert_Visual` tris | 24,200 | 8,488 | collapse 0.45 |
| Terrain photo | 2048² JPEG | 1024² JPEG | −75 % texels |
| File size | 9.69 MB | **4.68 MB** | −51.7 % |

Passes applied, in order:

1. **Weld** coincident vertices at 0.8 mm — restores a watertight surface (228,902 → 43,421
   verts on `Track` before decimation) and is what makes LOD generation sane on mobile.
2. **Seam-safe coplanar dissolve** delimited by `UV | NORMAL | MATERIAL` — the palette UVs must
   never be merged across swatch boundaries, or the map re-colours itself.
3. **Asphalt-protected decimation.** Every face whose palette UV lands on the tarmac swatches
   (`0.122` and `0.4` greys) is written into an `ASPHALT_PROTECT` vertex group; the collapse
   modifier runs with that group inverted and a weight factor of 10, so kerbs/fences/gantry lose
   30 % of their polygons while the driving surface keeps its exact silhouette. Verified: the
   asphalt face count is 6,857 → 6,813 (rounding at UV edges only).
4. **Terrain collapse decimation** at 0.45 — the terrain is a photographed mountain range with
   no silhouette-critical detail under the wheels.
5. **Export** with `AUTO` image format so the palette stays PNG.

---

## 3. Surveying the racing line (`tools/track_survey/rasterize.py` → `final_centerline.py`)

The topology walk was abandoned; the line is extracted from the **rendered footprint** instead:

1. Select the tarmac faces: grey palette swatch (`|r−g| < 0.05`, `|g−b| < 0.05`), value ≤ 0.46,
   upward normal, and the face must belong to the deck (not a wall) — 8,385 faces.
2. Rasterise those triangles into a **1 m occupancy grid** (266 × 258 cells) with a per-triangle
   barycentric fill in Blender's own Python (no numpy rasteriser needed).
3. Close the grid (5×5), fill holes, keep the largest blob → **one connected ribbon**
   (9,875 cells). The flyover merges into the road below it, which is exactly what we want for a
   top-down racing line.
4. `skimage.morphology.skeletonize`, walk the skeleton from the ramp tip, prune the walk at the
   point where it closes on itself, Chaikin-smooth ×4, then Gaussian-smooth the 1 m resample
   (σ = 5 samples) so 1-pixel stair-steps do not become steering noise.
5. Emit `assets/track/centerline.json`:

```json
{ "length": 973.0, "sample_step": 1.0, "count": 973, "closed": true,
  "width_median": 12.0, "deck_y": 0.39, "spawn_index": 0,
  "checkpoints": [ … 12 entries … ],
  "samples": [ { "s": 0.0, "x": -0.07, "y": 0.36, "z": 5.15, "yaw": -180.0, "half_w": 6.0 }, … ] }
```

Survey results: **973.0 m closed loop, 12.0 m wide**, minimum corner radius 20.1 m (median
67.4 m), road surface y = 0.36–0.68 m. The line is re-rooted so s = 0 sits under the start
gantry with the direction the start lights face (heading −Z at s = 0).

Elevation: the ribbon is effectively flat (0.36–0.68 m of crown/camber). The delivered
"figure-8 with overpass" is a **visual** structure — the top-down footprint is a single closed
loop with no elevated lane that the car must climb, so the racing surface is surveyed at ground
level and the elevated deck reads as scenery, exactly as in the delivered model.

---

## 4. Gameplay layer (`scripts/track/desert_circuit.gd`)

`class_name DesertCircuit` — a superset of the retired `EngineeredTestTrack` API, so the HUD,
camera rig, LAN game and the main scene keep working:

| Member | Purpose |
|---|---|
| `get_spawn_transform()` | grid pose at s = 0 (kept from the old class) |
| `set_shadow_quality(tier)` / `apply_graphics_quality(tier)` | shadow + sun energy per quality tier |
| `get_track_length()` | 973.0 m |
| `get_progress(pos)` | 0…1 around the lap |
| `lateral_offset(pos)` / `off_track_depth(pos)` | distance from the line / past the painted edge |
| `nearest_index(pos)`, `sample_count()`, `get_longest_straight_transform()` | survey access |
| `start_countdown()`, `reset_lap()`, `get_lap_state()`, `update_telemetry(vehicle)` | interaction |
| signals | `lap_started`, `lap_completed`, `checkpoint_passed`, `countdown_changed`, `wrong_way_changed`, `off_track_changed` |

**Collision** — built from the survey, not from the mesh:

* `DryTrackStaticBody` (`surface_grip` = 1.0): the asphalt ribbon as 41 `ConcavePolygonShape3D`
  chunks of 24 m (1,946 triangles). Quads are split explicitly — Jolt rejects non-triangular
  concave shapes.
* `SandStaticBody` (`surface_grip` = 0.5): a 760 × 760 m floor under the whole map, so leaving
  the road costs grip instead of falling through the world.
* `CircuitBoundary` (`surface_grip` = 0.5): four invisible walls at the terrain edge.

**Interaction**

* **Start lights** — five lamps on the gantry, 5 → 1 with 0.72 s spacing, then the lap clock
  starts. Lamps idle with a slow pulse between sessions.
* **Sectors** — 12 ordered gates at equal arc length; each must be crossed inside the road
  (≤ 0.6 m past the edge) for the lap to count.
* **Lap timing** — current / last / best, emitted through `lap_completed`.
* **Wrong way** — the car's forward vector against the racing-line heading, armed above 3 m/s.
* **Off track** — signed depth with 0.6 m engage / 0.4 m release hysteresis, so a kerb brush
  does not flicker.

The driving scene starts the countdown on `_ready` and calls `track.update_telemetry(vehicle)`
once per physics tick.

**HUD read-out.** `VehicleHud` owns a `LapTimeChip` next to the session timer. It reads
`track.get_lap_state()` once per frame and shows the countdown digits, then `current · best`;
LRM marks (`\u200E`) keep the pair in composition order inside the RTL HUD. Tone is factual, not
decorative: vermilion when `last_was_best`, amber when `off_track`, red when `wrong_way`.

---

## 5. Look development

The old rig was tuned for the procedural proving ground (untextured albedo), which blew the
sand out to white on the textured terrain. `scenes/track/test_track.tscn` now carries a desert
grade: Filmic tonemap at exposure 1.0, sun at 1.75 energy with a 0.7° angular size (soft, hot
shadows), a warm constant ambient at 0.62 for sky/ground bounce that does not wash the albedo,
and a light warm fog (0.00085) that only picks up in the far ridges. Sun energy steps with the
graphics tier (1.55 / 1.75 / 1.90).

Two runtime captures used for the loading plate and the docs:

* `tools/capture_map.gd` — `xvfb-run godot --path . --rendering-driver opengl3
  --script res://tools/capture_map.gd -- 1400 900 top out.png` (modes: `chase`, `top`, `gantry`,
  `hero`).
* `_shot_loader.gd` — captures the loading screen at any viewport size.

---

## 9. v0.2-b2 — the map/collision rework (why the drive was unplayable, and what changed)

The v0.2-b1 build drove badly: invisible walls, a road that pinched, and an overpass that could
not be climbed. Every cause was found in the data.

| Symptom the player felt | Measured cause | Fix in v0.2-b2 |
|---|---|---|
| "invisible walls" mid-corner | `centerline.json` had **30 samples with `half_w = 0`** (34 < 2 m): the width was a distance transform of the whole asphalt mask, so the bridge deck / infield tarmac touching the line collapsed it | width comes from `surface.json` (contiguous asphalt, 4.1–5.0 m) and the ribbon floor is enforced in the planner; **zero samples under 4 m** |
| stopped by nothing | collision was one shape per prism face (12,360 static shapes) in the first cut of the rework | 42 chunked concave shapes, two-sided, built from `collision.json` |
| ramp was a wall, lane under it a ceiling | the deck was a single flat plane at y≈0.36 m while the art carries a 7.4 m overpass | elevation tracked per sample through the overpass: 0.36 → **6.76 m**, max grade **22 %**, vertical curves at the knees |
| barriers in places the eyes did not expect | prisms were placed by a 1 m occupancy raster, which inflated the corridor to 9 m | prism lines are measured from the art's own kerb/wall triangles at **0.25 m**; the ribbon edge sits 0.45 m inside the visible kerb |
| could see through a gap that still stopped you | the first cut drew only the prisms the art did not already have | **every** prism is drawn: a continuous 1 m kerb mesh (`CircuitBarriers`) built from the same numbers as the collision |

### The plan file (`assets/track/collision.json`)
Produced by `k2map/build_track.py` from `k2map/surfaces.json` (Blender triangle survey of the
shipped GLB, in game coordinates) plus `assets/track/surface.json` (the lane):

| Key | Content |
|---|---|
| `lane[]` | 973 samples: `s, x, y, z, yaw, half_w` — the drivable ribbon, elevation included |
| `walls[]` | 974 barrier prisms: `a, b` (plan), `ya, yb` (bottom/top), `t` (thickness), `art` flag |
| `guard[]` | 56-prism ring at the outer sand edge, always drawn |

### Proof, not assertion
`tests/test_track_drive.gd` puts the real `SaipaVehicleController` on the real circuit and drives
a full lap with a pure-pursuit autopilot:

```
lap_completes_without_being_stopped   reached s=967 of 973
no_invisible_wall_on_the_racing_line  (never stalled)
car_never_leaves_the_ribbon           worst 0.00 m
car_climbs_the_overpass               crest 6.76 m, reached 7.18 m
car_never_sinks_through_the_deck      worst 0.67 m (suspension compression on the 22 % ramp)
```

Stills: `reports/desert_circuit_v0.2-b2/07_ramp_visible_kerb.png`, `08_overpass_deck.png`,
`09_plan_ribbon_vs_barriers.png` (the plan drawn over the art's barrier triangles).

### Known limits
- The barriers are a stylised desert-concrete kerb, not the art's own catch fencing; the art's
  rails sit behind it. Nothing is invisible, but the kerb is a new object on the map.
- The overpass crest is taken at 22 % with a vertical curve; at 22 m/s the car gets about 1.5 m
  of air over the top. That is deliberate (a jump), not a defect.
