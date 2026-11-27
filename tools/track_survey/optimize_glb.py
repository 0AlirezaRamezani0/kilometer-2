"""Optimise Desert_Track_Godot.glb for mobile.

The source GLB exports with split vertices (every triangle owns its own copy), which triples
vertex memory. This pass:
  1. welds coincident vertices (merge by distance) so the mesh is watertight again,
  2. dissolves coplanar faces while respecting UV seams (the colour is a UV palette, so UV
     boundaries must never be crossed),
  3. decimates the terrain mesh (photo texture, safe to lose polygons),
  4. downsamples the terrain texture 2048 -> 1024,
  5. re-exports a single GLB plus a stats JSON.
"""
import bpy
import json
import os

SRC = os.environ.get("K2_SOURCE_GLB", os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../desert_track_pkg/Godot_Project/Desert_Track_Godot.glb"))
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../tmp_track_survey")
os.makedirs(OUT, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)

def _palette_reader(ob):
    """Return a predicate telling whether a UV lands on an asphalt palette swatch."""
    mat = ob.material_slots[0].material
    tex = next(n for n in mat.node_tree.nodes if n.type == "TEX_IMAGE")
    img = tex.image
    W, H = img.size
    px = list(img.pixels)

    def predicate(u, v):
        x = int(min(W - 1, max(0, u * W)))
        y = int(min(H - 1, max(0, v * H)))
        i = (y * W + x) * 4
        r, g, b = round(px[i], 3), round(px[i + 1], 3), round(px[i + 2], 3)
        if not (abs(r - g) < 0.05 and abs(g - b) < 0.05):
            return False
        return r <= 0.46

    return predicate


stats = {}
for ob in list(bpy.data.objects):
    if ob.type != "MESH":
        continue
    me = ob.data
    before_tris = len(me.loop_triangles) if me.loop_triangles else 0
    me.calc_loop_triangles()
    before_tris = len(me.loop_triangles)
    before_verts = len(me.vertices)
    stats[ob.name] = {"tris_before": before_tris, "verts_before": before_verts}

    bpy.context.view_layer.objects.active = ob
    for o in bpy.context.selected_objects:
        o.select_set(False)
    ob.select_set(True)

    # 1. weld
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=0.0008)
    bpy.ops.object.mode_set(mode="OBJECT")

    # 2. dissolve coplanar, never across a UV seam
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    try:
        bpy.ops.mesh.dissolve_limited(angle_limit=0.0174533, use_dissolve_boundaries=False,
                                      delimit={"UV", "NORMAL", "MATERIAL"})
    except TypeError:
        bpy.ops.mesh.dissolve_limited(angle_limit=0.0174533)
    bpy.ops.object.mode_set(mode="OBJECT")

    # 3. terrain: collapse decimation is safe (photo texture, no silhouette to protect)
    if ob.name.lower().startswith("desert"):
        mod = ob.modifiers.new("dec", "DECIMATE")
        mod.decimate_type = "COLLAPSE"
        mod.ratio = 0.45
        mod.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=mod.name)
    else:
        # Track: decimate only the props (kerbs, walls, fences, gantry, lights). The asphalt
        # deck is protected through a vertex group so the driving surface keeps its exact
        # silhouette and UV palette.
        asphalt_vg = ob.vertex_groups.new(name="ASPHALT_PROTECT")
        pal = _palette_reader(ob)
        protect = set()
        for poly in me.polygons:
            if poly.material_index >= len(me.materials):
                continue
            uv = me.uv_layers.active.data[poly.loop_indices[0]].uv
            if pal(uv.x, uv.y):
                protect.update(poly.vertices)
        asphalt_vg.add(list(protect), 1.0, "REPLACE")
        stats[ob.name]["asphalt_verts"] = len(protect)
        mod = ob.modifiers.new("dec", "DECIMATE")
        mod.decimate_type = "COLLAPSE"
        mod.ratio = 0.30
        mod.vertex_group = "ASPHALT_PROTECT"
        mod.vertex_group_factor = 10.0
        mod.invert_vertex_group = True
        mod.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=mod.name)

    me.calc_loop_triangles()
    stats[ob.name]["tris_after"] = len(me.loop_triangles)
    stats[ob.name]["verts_after"] = len(me.vertices)

# 4. texture: re-encode the terrain photo at 1024
for im in bpy.data.images:
    if im.size[0] >= 1024 and im.name.lower() != "render result" and im.size[0] != 8:
        im.scale(1024, 1024)
        stats.setdefault("textures", []).append({"name": im.name, "size": list(im.size)})

bpy.ops.export_scene.gltf(
    filepath=os.path.join(OUT, "desert_circuit_opt.glb"),
    export_format="GLB",
    export_apply=True,
    export_texcoords=True,
    export_normals=True,
    export_materials="EXPORT",
    export_image_format="AUTO",
    export_jpeg_quality=82,
)
json.dump(stats, open(os.path.join(OUT, "stats.json"), "w"), indent=1)
print("STATS " + json.dumps(stats))
