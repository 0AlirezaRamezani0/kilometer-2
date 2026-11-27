"""Rasterise the desert map's asphalt deck into a 1 m occupancy grid (runs inside Blender).

Blender's bundled Python has no numpy/scipy extras beyond numpy, so the triangle rasterisation is
written by hand here; the skeletonising happens in build_centerline.py with system Python.
"""
import os

import bpy, json, math
import numpy as np

OUT_DIR = os.environ.get("K2_SURVEY_DIR", os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../tmp_track_survey"))
os.makedirs(OUT_DIR, exist_ok=True)

GLB = os.environ.get("K2_SOURCE_GLB", os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../desert_track_pkg/Godot_Project/Desert_Track_Godot.glb"))
RES = 1.0
PAD = 12.0

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)
tr = bpy.data.objects["Track"]
me = tr.data
mat = tr.material_slots[0].material
tex = next(n for n in mat.node_tree.nodes if n.type == "TEX_IMAGE")
img = tex.image
W, H = img.size
pxx = list(img.pixels)


def pal(u, v):
    x = int(min(W - 1, max(0, u * W)))
    y = int(min(H - 1, max(0, v * H)))
    i = (y * W + x) * 4
    return (round(pxx[i], 3), round(pxx[i + 1], 3), round(pxx[i + 2], 3))


uvl = me.uv_layers.active.data
mw = tr.matrix_world

faces = []
for poly in me.polygons:
    uv = uvl[poly.loop_indices[0]].uv
    r, g, b = pal(uv.x, uv.y)
    if not (abs(r - g) < 0.05 and abs(g - b) < 0.05):
        continue
    # two tarmac palette entries are in use: the dark deck (0.122) and the lighter
    # ramp/bridge/kerb-free deck (0.4..0.45). Everything above that is sand, paint or props.
    if r > 0.46:
        continue
    if poly.normal.z < 0.35:
        continue
    vs = [mw @ me.vertices[i].co for i in poly.vertices]
    zs = [v.z for v in vs]
    if max(zs) - min(zs) > 1.2:        # a wall face, not the deck
        continue
    # Blender (x, y, z) -> game (x, y_up, z) = (x, z, -y)
    faces.append([(v.x, v.z, -v.y) for v in vs])
print("DECK_FACES", len(faces))

allx = [v[0] for f in faces for v in f]
allz = [v[2] for f in faces for v in f]
minx, maxx = min(allx) - PAD, max(allx) + PAD
minz, maxz = min(allz) - PAD, max(allz) + PAD
cols = int((maxx - minx) / RES) + 1
rows = int((maxz - minz) / RES) + 1
print("GRID", cols, rows, "extent", round(minx), round(maxx), round(minz), round(maxz))

occ = np.zeros((rows, cols), dtype=bool)
heights = np.full((rows, cols), np.nan, dtype=np.float32)

for f in faces:
    xs = np.array([(v[0] - minx) / RES for v in f])
    zs = np.array([(v[2] - minz) / RES for v in f])
    hy = np.array([v[1] for v in f], dtype=np.float32)
    x0, x1 = int(max(0, math.floor(xs.min()))), int(min(cols - 1, math.ceil(xs.max())))
    z0, z1 = int(max(0, math.floor(zs.min()))), int(min(rows - 1, math.ceil(zs.max())))
    if x1 < x0 or z1 < z0:
        continue
    gx, gz = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(z0, z1 + 1) + 0.5)
    # barycentric test
    x1_, z1_ = xs[0], zs[0]
    x2_, z2_ = xs[1], zs[1]
    x3_, z3_ = xs[2], zs[2]
    den = (z2_ - z3_) * (x1_ - x3_) + (x3_ - x2_) * (z1_ - z3_)
    if abs(den) < 1e-9:
        continue
    a = ((z2_ - z3_) * (gx - x3_) + (x3_ - x2_) * (gz - z3_)) / den
    b = ((z3_ - z1_) * (gx - x3_) + (x1_ - x3_) * (gz - z3_)) / den
    c = 1.0 - a - b
    inside = (a >= -0.02) & (b >= -0.02) & (c >= -0.02)
    if not inside.any():
        continue
    sub = occ[z0:z1 + 1, x0:x1 + 1]
    sub |= inside
    hsub = heights[z0:z1 + 1, x0:x1 + 1]
    hval = a * hy[0] + b * hy[1] + c * hy[2]
    hsub[inside & np.isnan(hsub)] = hval[inside & np.isnan(hsub)]

print("OCCUPANCY", int(occ.sum()), "cells")
np.save(os.path.join(OUT_DIR, "occ_raw.npy"), occ)
# high-pass occupancy: cells whose deck is elevated (the overpass), for crossing resolution
hi = np.zeros((rows, cols), dtype=bool)
fill = ~np.isnan(heights)
for r_ in range(rows):
    for c_ in range(cols):
        pass
np.save(os.path.join(OUT_DIR, "height_raw.npy"), heights)
np.save(os.path.join(OUT_DIR, "height.npy"), heights)
json.dump({"minx": minx, "minz": minz, "res": RES, "cols": cols, "rows": rows},
          open(os.path.join(OUT_DIR, "grid.json"), "w"))
print("saved grid")
