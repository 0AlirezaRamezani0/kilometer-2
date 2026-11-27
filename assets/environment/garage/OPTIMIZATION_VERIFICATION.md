# Garage asset optimisation (v0.1-b5)

The diorama shipped in v0.1-b4 was the straight FBX→glTF conversion (6.0 MB, 49 meshes,
16 materials, 12 full-resolution textures). For the mobile menu it is now optimised offline in
Blender 4.3.2 (`optimize2.py`, kept in the session report): geometry the in-workshop orbit camera
can never see is culled, the 49 objects are joined into one mesh, welded and decimated, and every
texture is capped at 512 px while UVs are left untouched.

| Metric | v0.1-b4 (full) | v0.1-b5 (lite) | Change |
|---|---|---|---|
| File size (GLB) | 6,010,560 B (5.73 MB) | 1,498,132 B (1.43 MB) | **75 % smaller (4.01× lighter)** |
| Mesh objects | 49 | 1 | joined |
| Vertices | 10,162 | 2,859 | −72 % |
| Triangles | 10,315 | 5,458 | −47 % |
| Materials | 16 | 16 | unchanged (merged per material at runtime) |
| Texture memory (RGBA) | 19.8 MB | 6.3 MB | −68 % |
| Primitives drawn in the menu | 354 038 | 338 205 | −4.5 % |

What was removed and why it is safe:
- **Roof volume above 6.3 m** (roof deck, parapet, wire trim, roof "GARAGE" sign): the orbit
  camera lives at 1-3 m inside the workshop and the code culled these slabs at runtime anyway.
- **Loose props under 25 cm** (bench clutter): sub-pixel at menu distance.
- **Decimation (collapse, ratio 0.55)**: applies to large flat surfaces and dense props; the
  turntable disc, floor, walls, bench, lockers, door and warning stripes keep their silhouette.
- **Texture cap 512 px**: the largest source textures were 2048×1024; 512 px still maps to
  <1 px per screen pixel at 1080p for the surfaces the camera actually sees.

Kept on purpose: `garage_desert.glb` (the full-resolution conversion) stays next to the lite
build and `main_menu.gd` falls back to it if the lite file is ever missing, so the stage can be
swapped back for marketing renders without re-converting anything.
