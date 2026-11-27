extends SceneTree

## Kilometer 2 project-integrity suite (added in the 4.0.0 audit).
## Verifies the whole project graph, not a single feature:
## - project identity + main scene configuration
## - every scene under scenes/ loads and instantiates
## - every production script compiles (load() succeeds)
## - every VehicleCatalog entry resolves to three loadable scenes
## - required input actions, font and icon resources exist
## Run headless:
##   godot --headless --path . --script res://tests/test_project_integrity.gd

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


func _collect(dir_path: String, suffix: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var item := dir.get_next()
	while item != "":
		var full := dir_path + "/" + item
		if dir.current_is_dir():
			_collect(full, suffix, out)
		elif item.ends_with(suffix):
			out.append(full)
		item = dir.get_next()
	dir.list_dir_end()


func _run_all() -> void:
	# --- Project identity & entry point --------------------------------
	check(ProjectSettings.get_setting("application/config/name") == "Kilometer 2", "project_name_is_kilometer_2")
	var main_scene := str(ProjectSettings.get_setting("application/run/main_scene"))
	check(main_scene == "res://scenes/ui/main_menu.tscn", "main_scene_is_menu", main_scene)
	check(ResourceLoader.exists(main_scene), "main_scene_resource_exists")

	# --- Every scene loads + instantiates -------------------------------
	var scenes: Array[String] = []
	_collect("res://scenes", ".tscn", scenes)
	scenes.sort()
	check(scenes.size() >= 25, "scene_count_sane", str(scenes.size()))
	for path in scenes:
		var packed := load(path) as PackedScene
		check(packed != null, "scene_loads", path)
		if packed != null:
			var inst := packed.instantiate()
			check(inst != null, "scene_instantiates", path)
			if inst != null:
				inst.free()

	# --- Every production script compiles -------------------------------
	var scripts: Array[String] = []
	_collect("res://scripts", ".gd", scripts)
	scripts.sort()
	check(scripts.size() >= 15, "script_count_sane", str(scripts.size()))
	for path in scripts:
		var res := load(path)
		check(res != null, "script_compiles", path)

	# --- Catalog integrity: 6 vehicles x 3 scenes ------------------------
	check(VehicleCatalog.get_count() == 6, "catalog_has_six_vehicles")
	var ids := {}
	for i in range(VehicleCatalog.get_count()):
		var entry := VehicleCatalog.get_entry(i)
		var vid := str(entry["id"])
		check(not ids.has(vid), "catalog_id_unique", vid)
		ids[vid] = true
		for key in ["vehicle_scene", "showcase_scene", "visual_scene"]:
			var p := str(entry[key])
			check(ResourceLoader.exists(p), "catalog_scene_exists", vid + ":" + key)
			if ResourceLoader.exists(p):
				check(load(p) != null, "catalog_scene_loads", vid + ":" + key)
		check(float(entry["mass_kg"]) > 0.0, "catalog_mass_positive", vid)
		check(float(entry["wheel_radius_m"]) > 0.0, "catalog_wheel_radius_positive", vid)

	# --- Input map, font, icon -------------------------------------------
	for action in ["throttle", "brake_reverse", "steer_left", "steer_right", "handbrake", "reset_vehicle", "pause_game"]:
		check(InputMap.has_action(action), "input_action_exists", action)
	check(ResourceLoader.exists("res://assets/fonts/Vazirmatn-Medium.ttf"), "default_font_exists")
	check(ResourceLoader.exists("res://icon.svg"), "icon_exists")

	print("=== PROJECT INTEGRITY SUMMARY: %d passed, %d failed ===" % [passed, failed])
	quit(0 if failed == 0 else 1)
