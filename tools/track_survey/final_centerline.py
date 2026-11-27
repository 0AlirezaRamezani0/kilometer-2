"""Finalise the desert-circuit centreline: closed loop, smoothed, 1 m samples, with elevation.

Reads  occ_raw.npy / height.npy / grid.json  (rasterize.py output)
Writes centerline.json  {length, samples:[{s,x,y,z,yaw,half_w}], checkpoints:[...]}
       overlay_final.png
"""
import json
import math
import os

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage
from skimage.morphology import skeletonize

RES = 1.0
WORK = os.environ.get("K2_SURVEY_DIR", os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../tmp_track_survey"))
occ = np.load(os.path.join(WORK, "occ_raw.npy"))
height = np.load(os.path.join(WORK, "height.npy"))
grid = json.load(open(os.path.join(WORK, "grid.json")))
minx, minz = grid["minx"], grid["minz"]
rows, cols = occ.shape

mask = ndimage.binary_closing(occ, np.ones((5, 5)))
mask = ndimage.binary_fill_holes(mask)
lbl, n = ndimage.label(mask)
sizes = ndimage.sum(mask, lbl, range(1, n + 1))
mask = lbl == (int(np.argmax(sizes)) + 1)
dist = ndimage.distance_transform_edt(mask) * RES
skel = skeletonize(mask)

pts = set(zip(*[a.tolist() for a in np.nonzero(skel)]))
NB = [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)]


def nbs(p):
    return [(p[0] + a, p[1] + b) for a, b in NB if (p[0] + a, p[1] + b) in pts]


# ---- walk the skeleton, starting from the most "isolated" endpoint (the ramp tip) ------------
ends = [p for p in pts if len(nbs(p)) == 1]
start = ends[0] if ends else min(pts)
path = [start]
seen = {start}
cur = start
while True:
    cand = [q for q in nbs(cur) if q not in seen]
    if not cand:
        # allow a single revisit if we closed onto the start neighbourhood
        break
    if len(path) > 1:
        dy = cur[0] - path[-2][0]
        dx = cur[1] - path[-2][1]
        cand.sort(key=lambda q: -(dy * (q[0] - cur[0]) + dx * (q[1] - cur[1])))
    cur = cand[0]
    path.append(cur)
    seen.add(cur)

# trim any tail that doubles back onto the head so the loop is simple
cut = len(path)
for i in range(len(path) - 1, len(path) // 2, -1):
    if math.dist(path[i], path[0]) <= 4:
        cut = i
        break
path = path[:cut]

# ---- Douglas-Peucker-lite: Chaikin smoothing on the pixel polyline --------------------------
def chaikin(pl, it=4):
    for _ in range(it):
        out = [pl[0]]
        for i in range(len(pl) - 1):
            a, b = pl[i], pl[i + 1]
            out.append((0.75 * a[0] + 0.25 * b[0], 0.75 * a[1] + 0.25 * b[1]))
            out.append((0.25 * a[0] + 0.75 * b[0], 0.25 * a[1] + 0.75 * b[1]))
        out.append(pl[-1])
        pl = out
    return pl


pl = [(c + 0.5, r + 0.5) for r, c in path]          # (col,row) in cells
pl = chaikin(pl, 4)
pl.append(pl[0])                                    # close the loop

# cumulative length
cum = [0.0]
for i in range(1, len(pl)):
    cum.append(cum[-1] + math.hypot(pl[i][0] - pl[i - 1][0], pl[i][1] - pl[i - 1][1]))
L = cum[-1]

# ---- resample at 1 m and attach elevation + width ------------------------------------------
STEP = 1.0
N = int(round(L / STEP))
samples = []
j = 0
for k in range(N):
    d = k * L / N
    while j < len(cum) - 2 and cum[j + 1] < d:
        j += 1
    t = (d - cum[j]) / max(1e-9, cum[j + 1] - cum[j])
    cxp = pl[j][0] + (pl[j + 1][0] - pl[j][0]) * t
    ryp = pl[j][1] + (pl[j + 1][1] - pl[j][1]) * t
    x = cxp * RES + minx
    z = ryp * RES + minz
    # heading from a 4 m lookahead
    k2 = (k + 4) % N
    while j < len(cum) - 2 and cum[j + 1] < k2 * L / N:
        j += 1
    t2 = (k2 * L / N - cum[j]) / max(1e-9, cum[j + 1] - cum[j])
    x2 = (pl[j][0] + (pl[j + 1][0] - pl[j][0]) * t2) * RES + minx
    z2 = (pl[j][1] + (pl[j + 1][1] - pl[j][1]) * t2) * RES + minz
    yaw = math.degrees(math.atan2(x2 - x, z2 - z))
    ri = int(min(rows - 1, max(0, ryp)))
    ci = int(min(cols - 1, max(0, cxp)))
    hw = float(dist[ri, ci])
    yy = height[ri, ci]
    if math.isnan(yy):
        yy = 0.0
    samples.append({"s": round(d, 1), "x": round(x, 2), "y": round(float(yy), 2),
                    "z": round(z, 2), "yaw": round(yaw, 1), "half_w": round(hw, 1)})

# ---- gaussian-smooth the closed polyline so 1 px stair-steps do not survive ----------------
from scipy.ndimage import gaussian_filter1d

xs_ = gaussian_filter1d(np.array([s["x"] for s in samples]), 5.0, mode="wrap")
zs_ = gaussian_filter1d(np.array([s["z"] for s in samples]), 5.0, mode="wrap")
seg = np.hypot(np.diff(np.append(xs_, xs_[0])), np.diff(np.append(zs_, zs_[0])))
cum2 = np.concatenate([[0], np.cumsum(seg)])
for k in range(N):
    samples[k]["x"] = round(float(xs_[k]), 2)
    samples[k]["z"] = round(float(zs_[k]), 2)
    samples[k]["s"] = round(float(cum2[k] * L / cum2[-1]), 1)

# recompute heading from the smoothed path
for k in range(N):
    k2 = (k + 4) % N
    samples[k]["yaw"] = round(math.degrees(math.atan2(samples[k2]["x"] - samples[k]["x"],
                                                      samples[k2]["z"] - samples[k]["z"])), 1)

# width / height re-sampled from the raster at the final positions (max over a 1 m disc)
for k in range(N):
    ci = int(round((samples[k]["x"] - minx) / RES))
    ri = int(round((samples[k]["z"] - minz) / RES))
    win = dist[max(0, ri - 1):ri + 2, max(0, ci - 1):ci + 2]
    samples[k]["half_w"] = round(float(win.max()) if win.size else 5.0, 1)

# smooth yaw over the closed loop
for _ in range(8):
    for k in range(N):
        a = samples[k - 1]["yaw"]
        b = samples[(k + 1) % N]["yaw"]
        da = (a - samples[k]["yaw"] + 180) % 360 - 180
        db = (b - samples[k]["yaw"] + 180) % 360 - 180
        samples[k]["yaw"] = round((samples[k]["yaw"] + 0.3 * (da + db) + 180) % 360 - 180, 1)

# ---- re-root on the start gantry, running the way the start lights face -------------------
# The skeleton walk starts wherever the ramp tip is, and it may run either direction. The
# delivered gantry sits over the north spur at x ~ 0, z ~ 3.8 and its start lights face -Z,
# so sample 0 must be the gantry crossing with the line heading -Z there.
N = len(samples)
gi = next((k for k in range(N) if abs(samples[k]["x"]) < 1.5 and 2.0 < samples[k]["z"] < 6.0), 0)
samples = samples[::-1]                      # run the lap the way the lamps face
gi = next((k for k in range(N) if abs(samples[k]["x"]) < 1.5 and 2.0 < samples[k]["z"] < 6.0), 0)
samples = samples[gi:] + samples[:gi]
for k in range(N):
    samples[k]["s"] = round(k * L / N, 1)
for k in range(N):
    a, b = samples[k], samples[(k + 4) % N]
    samples[k]["yaw"] = round(math.degrees(math.atan2(b["x"] - a["x"], b["z"] - a["z"])), 1)
for _ in range(8):
    for k in range(N):
        dp = (samples[k - 1]["yaw"] - samples[k]["yaw"] + 180) % 360 - 180
        dq = (samples[(k + 1) % N]["yaw"] - samples[k]["yaw"] + 180) % 360 - 180
        samples[k]["yaw"] = round((samples[k]["yaw"] + 0.3 * (dp + dq) + 180) % 360 - 180, 1)

# ---- checkpoints every ~1/12 of the lap, snapped to s --------------------------------------
cps = []
for i in range(12):
    idx = int(i * N / 12)
    s = samples[idx]
    cps.append({"index": i, "s": s["s"], "x": s["x"], "y": s["y"], "z": s["z"],
                "yaw": s["yaw"], "width": round(s["half_w"] * 2, 1)})

hw = [s["half_w"] for s in samples]
yy = [s["y"] for s in samples]
out = {
    "spawn_index": 0,
    "source": "Desert_Track_Godot.glb / Track asphalt palette (0.122, 0.4)",
    "length": round(L, 1),
    "sample_step": STEP,
    "count": N,
    "width_median": round(float(np.median(hw)) * 2, 1),
    "width_min": round(float(np.min(hw)) * 2, 1),
    "width_max": round(float(np.max(hw)) * 2, 1),
    "y_min": round(float(np.min(yy)), 2),
    "y_max": round(float(np.max(yy)), 2),
    "closed": math.dist((samples[-1]["x"], samples[-1]["z"]), (samples[0]["x"], samples[0]["z"])) < 2.0,
    "checkpoints": cps,
    "samples": samples,
}
json.dump(out, open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../assets/track/centerline.json"), "w"))

gap = math.dist((samples[-1]["x"], samples[-1]["z"]), (samples[0]["x"], samples[0]["z"]))
print("LEN %.1f m  samples %d  loop gap %.2f m" % (L, N, gap))
print("width median %.1f m (%.1f..%.1f)  elev %.2f..%.2f" % (out["width_median"], out["width_min"],
                                                            out["width_max"], out["y_min"], out["y_max"]))

# ---- overlay -------------------------------------------------------------------------------
SC = 3
img = Image.new("RGB", (cols * SC, rows * SC), (10, 11, 14))
dr = ImageDraw.Draw(img)
for r in range(rows):
    for c in range(cols):
        if mask[r, c]:
            img.putpixel((c * SC, r * SC), (58, 62, 70))
pts_img = [((s["x"] - minx) / RES * SC, (s["z"] - minz) / RES * SC) for s in samples]
dr.line(pts_img + [pts_img[0]], fill=(255, 84, 46), width=2)
for cp in cps:
    cx = (cp["x"] - minx) / RES * SC
    cz = (cp["z"] - minz) / RES * SC
    dr.ellipse([cx - 5, cz - 5, cx + 5, cz + 5], outline=(130, 245, 170), width=2)
dr.ellipse([pts_img[0][0] - 6, pts_img[0][1] - 6, pts_img[0][0] + 6, pts_img[0][1] + 6],
           fill=(255, 255, 255))
img.resize((cols * 2, rows * 2)).save(os.path.join(WORK, "overlay_final.png"))
print("overlay_final.png")
