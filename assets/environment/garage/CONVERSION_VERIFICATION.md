# Garage model — conversion & parity verification (v0.1-b4)

Source delivered in Drive (`Mobile_Optimized_Model_001.fbx` + `Mobile_Optimized_Model_001_Package.zip`).
Conversion: **Blender 4.3.2 headless**, FBX imported into an empty scene and re-exported as
glTF 2.0 binary (`garage.glb` → `assets/environment/garage/garage_desert.glb`), textures
embedded, animations/cameras/lights excluded, modifiers applied, **no scale, axis or pivot
change**.

| Metric | Delivered FBX | Converted GLB |
|---|---|---|
| Mesh objects | 49 | 49 |
| Triangles | 10 315 | 10 315 |
| Vertices (evaluated) | 10 162 | 10 533 (vertices split at UV/normal seams by glTF) |
| Materials | 16 | 16 |
| Bounding box (X × Y × Z) | 17.147 × 21.827 × 12.096 | 17.147 × 21.827 × 12.096 |

Import into Godot 4.7.2 extracts 12 base-colour textures next to the `.glb` and reports
0 import errors. The axis conversion (Blender Z-up → glTF Y-up) is handled by the exporter and
by Godot's importer; the diorama's floor lands on y ≈ 0 and the turntable circle is centred on
x = z = 0, which is what the showroom stage relies on.

Not verified (inherited from the delivery report): USDZ contents (no USD support in Blender
4.3.2), material appearance parity beyond base colour, and mobile performance of 16 separate
materials (mitigated at runtime by the per-material merge in `_garage_merge_by_material`).

Licence: **CC BY-NC 4.0** — see `LICENSE_CC-BY-NC-4.0.txt`.
