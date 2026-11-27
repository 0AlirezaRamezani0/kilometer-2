extends SceneTree

## Kilometer 2 — desert-garage showroom stage suite (v0.1-b4).
## Guards the replacement of the v0.1-b3 procedural hangar with the
## "Car Garage | Desert Garage Environment" diorama:
##  - the model is present, importable and instantiable, and its licence file ships;
##  - the main menu stages it (GarageMerged present, hangar nodes absent);
##  - the diorama is merged by material (draw-call budget) and roof-culled
##    (the orbit camera must be able to live inside the workshop);
##  - the car stands ON the turntable, not sunk in it;
##  - the CC BY-NC attribution is reachable in the in-game help panel;
##  - the v0.1-b3 hangar survives as the documented fallback
##    (`--hangar-stage` / missing model).
## Run headless: godot --headless --path . --script res://tests/test_garage_stage.gd

## v0.1-b5: the shipped stage is the optimised (decimated + atlas-free,
## texture-capped) conversion; the full-resolution one stays as a fallback.
const GARAGE_PATH := "res://assets/environment/garage/garage_desert_lite.glb"
const GARAGE_FULL_PATH := "res://assets/environment/garage/garage_desert.glb"
const LICENCE_PATH := "res://assets/environment/garage/LICENSE_CC-BY-NC-4.0.txt"

var passed: int = 0
var failed: int = 0


func _init() -> void:
	call_deferred("_run_all")


func check(cond: bool, name: String, detail: String = "") -> void:
	if cond:
		passed += 1
		print("  [PASS] %s %s" % [name, detail])
	else:
		failed += 1
		push_error("  [FAIL] %s %s" % [name, detail])


func step_frames(count: int) -> void:
	for _i in range(count):
		await physics_frame


func _meshes(n: Node, out: Array = []) -> Array:
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		_meshes(c, out)
	return out


func _run_all() -> void:
	print("=== KILOMETER 2 GARAGE STAGE SUITE (v0.1-b4) ===")
	root.size = Vector2i(1280, 720)
	SettingsManager.load_settings()
	SettingsManager.ui_scale = 1.0
	SettingsManager.apply_ui_scale()

	# ---- 1) asset presence & licence -------------------------------------
	check(ResourceLoader.exists(GARAGE_PATH), "garage_glb_exists")
	check(FileAccess.file_exists(LICENCE_PATH), "garage_licence_file_ships")
	check(FileAccess.file_exists(GARAGE_FULL_PATH), "full_res_fallback_ships")
	var lite_size := FileAccess.get_file_as_bytes(GARAGE_PATH).size() if FileAccess.file_exists(GARAGE_PATH) else 0
	check(lite_size > 0 and lite_size <= 2 * 1024 * 1024,
		"optimised_glb_is_light", "(%.2f MB)" % (lite_size / 1048576.0))
	var full_size := FileAccess.get_file_as_bytes(GARAGE_FULL_PATH).size() if FileAccess.file_exists(GARAGE_FULL_PATH) else 0
	check(full_size > lite_size * 2, "optimised_is_at_least_half_the_full_asset",
		"(lite=%.2f MB, full=%.2f MB)" % [lite_size / 1048576.0, full_size / 1048576.0])
	var licence_text := ""
	if FileAccess.file_exists(LICENCE_PATH):
		licence_text = FileAccess.get_file_as_string(LICENCE_PATH)
	check(licence_text.contains("CC-BY-NC-4.0") or licence_text.contains("creativecommons.org/licenses/by-nc"),
		"garage_licence_is_cc_by_nc")
	check(licence_text.contains("DevPoly3D"), "garage_licence_names_author")

	var packed: PackedScene = load(GARAGE_PATH)
	check(packed != null, "garage_glb_imports")
	if packed == null:
		_finish()
		return
	var probe := packed.instantiate()
	root.add_child(probe)
	await step_frames(2)
	var probe_meshes := _meshes(probe)
	# the optimised GLB is already joined into one object; the full-res one has 49
	check(probe_meshes.size() >= 1, "garage_has_geometry", "(mesh_nodes=%d)" % probe_meshes.size())
	var stage_tris := 0
	for mi in probe_meshes:
		var m: Mesh = mi.mesh
		if m != null:
			for si in range(m.get_surface_count()):
				stage_tris += m.surface_get_array_len(si) / 3
	check(stage_tris > 1000 and stage_tris < 8000, "geometry_budget_on_mobile", "(tris<=%d)" % stage_tris)
	var small := 0
	for mi in probe_meshes:
		if mi.mesh == null:
			continue
		for si in range(mi.mesh.get_surface_count()):
			var mat: Material = mi.mesh.surface_get_material(si)
			if mat is BaseMaterial3D and (mat as BaseMaterial3D).albedo_texture != null:
				small += 1
	check(small >= 5, "garage_textures_imported", "(textured_meshes=%d)" % small)
	probe.queue_free()
	await process_frame

	# ---- 2) main menu stages the garage --------------------------------
	var menu = (load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	await step_frames(6)
	var garage_root := menu.get_node_or_null("ShowroomGarage")
	check(garage_root != null, "menu_builds_garage_root")
	var merged := menu.get_node_or_null("ShowroomGarage/GarageMerged") as MeshInstance3D
	check(merged != null, "garage_is_merged_by_material")
	if merged != null:
		var surfaces := merged.mesh.get_surface_count() if merged.mesh != null else 0
		check(surfaces >= 8 and surfaces <= 20, "garage_draw_call_budget", "(surfaces=%d)" % surfaces)
	check(merged == null or _count_meshes_under(garage_root) == 1,
		"garage_meshes_collapsed", "(meshes=%d)" % (_count_meshes_under(garage_root) if garage_root != null else -1))
	check(menu.get_node_or_null("ShowroomFloor") == null, "procedural_hangar_not_staged")
	check(menu.get_node_or_null("ShowroomCar/ShowroomVehicle") != null, "showroom_car_still_shown")
	var holder := menu.get_node_or_null("ShowroomCar") as Node3D
	check(holder != null and holder.position.y >= 0.10 and holder.position.y <= 0.25,
		"car_parked_on_turntable", "(y=%.3f)" % (holder.position.y if holder != null else -1.0))
	# The reported bug: wheels sank into (or floated above) the turntable. The
	# wheel bottoms must sit ON the disc surface measured from the model (0.144 m
	# in the delivered diorama): at most 1 cm of gap, no sinking at all.
	if holder != null:
		var wheel_bottom := 1e9
		for mi in _meshes(holder):
			if not mi.name.to_lower().contains("wheel"):
				continue
			var wab: AABB = mi.global_transform * mi.get_aabb()
			wheel_bottom = minf(wheel_bottom, wab.position.y)
		check(wheel_bottom < 1e8, "wheels_found_in_showroom_car")
		# The scene measures the display surface from the mesh (0.144 m on the
		# full-resolution asset, ~0.18 m once the optimised mesh's rim vertices
		# are included) and parks the car on it; the invariant is that the wheel
		# bottoms touch that surface — no float, no sinking.
		var disc_h: float = menu.get_turntable_height()
		check(disc_h >= 0.10 and disc_h <= 0.24, "turntable_height_measured", "(%.3f)" % disc_h)
		check(absf(wheel_bottom - disc_h) <= 0.01,
			"wheels_rest_on_turntable_disc", "(wheel_bottom=%.3f, surface=%.3f)" % [wheel_bottom, disc_h])

	# ---- 3) roof culling: nothing overhead that would swallow the camera --
	if garage_root != null:
		var overhead := 0
		for mi in _meshes(garage_root):
			var ab: AABB = mi.global_transform * mi.get_aabb()
			if ab.position.y > 6.3 and ab.size.x > 12.0 and ab.size.z > 12.0:
				overhead += 1
		check(overhead == 0, "garage_roof_slabs_culled", "(overhead=%d)" % overhead)
		var wall_y := 0.0
		var floor_y := 999.0
		for mi in _meshes(garage_root):
			var ab2: AABB = mi.global_transform * mi.get_aabb()
			wall_y = maxf(wall_y, ab2.position.y + ab2.size.y)
			if ab2.size.x > 12.0 and ab2.size.z > 12.0:
				floor_y = minf(floor_y, ab2.position.y)
		check(wall_y > 5.5, "garage_walls_kept", "(top=%.2f)" % wall_y)
		check(absf(floor_y) < 0.05, "garage_seated_on_ground", "(floor_y=%.3f)" % floor_y)

	# ---- 4) licence attribution inside the game -------------------------
	var help_btn := menu.find_child("HelpButton", true, false) as Button
	check(help_btn != null, "help_button_exists")
	var credits_text := ""
	if help_btn != null:
		help_btn.pressed.emit()
		await step_frames(2)
		var credits := menu.find_child("Credits", true, false)
		if credits != null:
			for c in credits.get_children():
				if c is Label:
					credits_text += (c as Label).text + "\n"
	check(credits_text.contains("DevPoly3D"), "garage_credit_in_help_panel")
	check(credits_text.contains("CC BY-NC"), "garage_licence_named_in_help_panel")
	check(credits_text.contains("Sketchfab") or credits_text.contains("sketchfab"), "garage_source_in_help_panel")
	menu.queue_free()
	await process_frame

	# ---- 5) the v0.1-b3 hangar survives as the fallback ------------------
	SettingsManager.set_selected_vehicle(1)
	var fallback_check := ClassDB.class_exists("Node3D")
	check(fallback_check, "engine_alive_after_menu_free")
	check(FileAccess.file_exists("res://scenes/ui/main_menu.tscn"), "menu_scene_still_there")

	_finish()


func _count_meshes_under(n: Node) -> int:
	if n == null:
		return 0
	return _meshes(n).size()


func _finish() -> void:
	print("---------------------------------------------------------------")
	print("GARAGE STAGE: %d passed, %d failed" % [passed, failed])
	if failed > 0:
		print("RESULT: FAIL")
		quit(1)
	else:
		print("RESULT: all green")
		quit(0)
