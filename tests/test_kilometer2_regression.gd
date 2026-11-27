extends SceneTree

## Kilometer 2 regression suite: persisted Input Map, pause/resume flow,
## pass-3 locked-vehicle invariant (selection only in the main menu).
## Run headless:
##   godot --headless --path . --script res://tests/test_kilometer2_regression.gd
## Rendering checks (pause overlay visibility) need Xvfb + opengl3 like phase9.

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
	RenderingServer.viewport_set_update_mode(root.get_viewport_rid(), RenderingServer.VIEWPORT_UPDATE_DISABLED)
	for i in range(count):
		await physics_frame
	RenderingServer.viewport_set_update_mode(root.get_viewport_rid(), RenderingServer.VIEWPORT_UPDATE_ALWAYS)
	await process_frame
	await process_frame


func _run_all() -> void:
	# v0.1-b3: geometry checks assume 100 % UI scale, whatever the persisted value.
	SettingsManager.load_settings()
	SettingsManager.ui_scale = 1.0
	SettingsManager.apply_ui_scale()
	SettingsManager.save_settings()
	print("=== KILOMETER 2 REGRESSION SUITE ===")
	# 1) Input actions persisted in project.godot, not only runtime-created.
	for action in VehicleInputMap.ACTIONS:
		check(ProjectSettings.has_setting("input/" + action), "input_persisted_" + action)
		check(InputMap.has_action(action), "input_runtime_" + action)

	root.size = Vector2i(1280, 720)
	var main_packed: PackedScene = load("res://scenes/main/main_driving_template.tscn")
	check(main_packed != null, "main_scene_loads")
	var main = main_packed.instantiate()
	root.add_child(main)
	await step_frames(90)

	var hud: VehicleHud = main.hud
	var car: SaipaVehicleController = main.vehicle
	check(hud != null and car != null, "hud_and_vehicle_bound")
	check(hud.pause_overlay != null, "pause_overlay_exists")
	check(not paused and not hud.is_game_paused, "starts_unpaused")

	# 2) Pause freezes the tree and shows overlay; resume restores.
	hud.set_game_paused(true)
	check(paused, "tree_paused")
	check(hud.pause_overlay.visible, "pause_overlay_visible")
	var frozen_pos := car.global_position
	await step_frames(30)
	check(car.global_position.distance_to(frozen_pos) < 0.01, "vehicle_frozen_while_paused", str(car.global_position))
	hud.set_game_paused(false)
	check(not paused and not hud.pause_overlay.visible, "resume_restores")

	# 3) Pass 3: no in-game vehicle switching exists (no input actions,
	# no HUD buttons); the tooling spawn path keeps exactly one body.
	check(not InputMap.has_action("cycle_vehicle"), "no_cycle_vehicle_action")
	check(not InputMap.has_action("cycle_camera"), "no_cycle_camera_action")
	check(hud.find_child("VehicleSelectButton", true, false) == null, "hud_has_no_vehicle_button")
	check(hud.find_child("CameraButton", true, false) == null, "hud_has_no_camera_button")
	for idx in [1, 2, 3, 4, 5, 0]:
		main.spawn_vehicle(idx)
		await step_frames(10)
	var bodies := 0
	var stack: Array[Node] = [main]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is VehicleBody3D:
			bodies += 1
		for ch in n.get_children():
			stack.append(ch)
	check(bodies == 1, "single_vehicle_after_full_cycle", "bodies=%d" % bodies)

	print("=== KILOMETER 2 SUMMARY: %d passed, %d failed ===" % [passed, failed])
	quit(1 if failed > 0 else 0)
