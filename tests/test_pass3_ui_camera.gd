extends SceneTree

## Kilometer 2 pass 3 suite: unified UI redesign spec.
## - Vehicle is chosen ONLY in the main-menu 3D showroom and locked in game.
## - Graphics quality is independent of the vehicle (the old bug: changing
##   the car re-applied graphics/LOD and visibly changed quality).
## - The camera has exactly ONE behavior: smooth free follow.
## Run headless: godot --headless --path . --script res://tests/test_pass3_ui_camera.gd

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


func _count_wheel_meshes(scope: Node) -> int:
	# MeshInstance3D count under any WheelMount* node in the subtree.
	# The showroom must display the showcase scene (body + 4 wheels);
	# the plain visual scene has no wheels (regression guard).
	if scope == null:
		return 0
	var count := 0
	var stack: Array[Node] = [scope]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n.name.begins_with("WheelMount"):
			var sub: Array[Node] = [n]
			while not sub.is_empty():
				var m: Node = sub.pop_back()
				if m is MeshInstance3D:
					count += 1
				for c in m.get_children():
					sub.append(c)
		for c in n.get_children():
			stack.append(c)
	return count


func step_frames(count: int) -> void:
	RenderingServer.viewport_set_update_mode(root.get_viewport_rid(), RenderingServer.VIEWPORT_UPDATE_DISABLED)
	for i in range(count):
		await physics_frame
	RenderingServer.viewport_set_update_mode(root.get_viewport_rid(), RenderingServer.VIEWPORT_UPDATE_ALWAYS)
	await process_frame
	await process_frame


func _run_all() -> void:
	print("=== KILOMETER 2 PASS 3 UI / CAMERA SUITE ===")
	root.size = Vector2i(1280, 720)

	# 1) Persisted selection + graphics are independent values.
	SettingsManager.load_settings()
	# v0.1-b3: geometry checks assume 100 % UI scale, whatever the persisted value.
	SettingsManager.ui_scale = 1.0
	SettingsManager.apply_ui_scale()
	SettingsManager.save_settings()
	SettingsManager.selected_vehicle_index = 3
	SettingsManager.graphics_tier = 2
	SettingsManager.save_settings()
	SettingsManager.selected_vehicle_index = 0
	SettingsManager.graphics_tier = 1
	SettingsManager.load_settings()
	check(SettingsManager.selected_vehicle_index == 3, "selected_vehicle_persists", "(idx=%d)" % SettingsManager.selected_vehicle_index)
	check(SettingsManager.graphics_tier == 2, "graphics_tier_persists_independently", "(tier=%d)" % SettingsManager.graphics_tier)

	# 2) Main menu: showroom selection changes car, never graphics.
	var menu_packed: PackedScene = load("res://scenes/ui/main_menu.tscn")
	check(menu_packed != null, "main_menu_loads")
	var menu = menu_packed.instantiate()
	root.add_child(menu)
	await step_frames(10)
	check(menu.get_node_or_null("ShowroomCar") != null, "showroom_stage_exists")
	check(menu.get_node_or_null("ShowroomCar/ShowroomVehicle") != null, "showroom_vehicle_shown")
	check(_count_wheel_meshes(menu.get_node_or_null("ShowroomCar")) >= 4, "showroom_vehicle_has_wheels", "(wheel_meshes=%d)" % _count_wheel_meshes(menu.get_node_or_null("ShowroomCar")))
	var tier_before := SettingsManager.graphics_tier
	# K2-REDESIGN-001: prev/next arrows replaced by the thumbnail pager;
	# pressing thumbnail 4 is the same "advance from 3 to 4" action.
	var next_btn := menu.find_child("VehicleThumb4", true, false) as Button
	check(next_btn != null, "showroom_next_button_exists")
	if next_btn != null:
		next_btn.pressed.emit()
		await process_frame
	check(SettingsManager.selected_vehicle_index == 4, "showroom_next_selects_and_persists", "(idx=%d)" % SettingsManager.selected_vehicle_index)
	check(SettingsManager.graphics_tier == tier_before, "vehicle_change_never_touches_graphics_tier")
	var counter := menu.find_child("VehicleCounter", true, false) as Label
	check(counter != null and counter.text.contains("از ۶"), "showroom_counter_updates", "(%s)" % (counter.text if counter != null else "<none>"))
	check(_count_wheel_meshes(menu.get_node_or_null("ShowroomCar")) >= 4, "showroom_switched_vehicle_has_wheels", "(wheel_meshes=%d)" % _count_wheel_meshes(menu.get_node_or_null("ShowroomCar")))
	var holder = menu.get_node_or_null("ShowroomCar")
	var rot_before: float = holder.rotation.y if holder != null else 0.0
	await step_frames(20)
	check(holder != null and absf(holder.rotation.y - rot_before) > 0.01, "showroom_rotates")
	menu.queue_free()
	await process_frame

	# 3) Driving scene spawns exactly the menu-selected vehicle, locked.
	SettingsManager.set_selected_vehicle(2)
	var main_packed: PackedScene = load("res://scenes/main/main_driving_template.tscn")
	check(main_packed != null, "driving_scene_loads")
	var main = main_packed.instantiate()
	root.add_child(main)
	await step_frames(90)
	check(main.active_vehicle_index == 2, "driving_spawns_menu_selection", "(idx=%d)" % main.active_vehicle_index)
	check(main.vehicle != null and main.vehicle.vehicle_id == "veh_02_megan", "spawned_vehicle_matches_selection", "(id=%s)" % (main.vehicle.vehicle_id if main.vehicle != null else "<none>"))
	check(not main.has_method("cycle_next_vehicle") and not main.has_method("select_vehicle"), "no_runtime_vehicle_switch_api")
	check(not InputMap.has_action("cycle_vehicle") and not InputMap.has_action("cycle_camera"), "no_cycle_input_actions")

	var hud: VehicleHud = main.hud
	var rig: VehicleCameraRig = main.camera_rig
	check(hud.find_child("VehicleSelectButton", true, false) == null, "hud_has_no_vehicle_button")
	check(hud.find_child("CameraButton", true, false) == null, "hud_has_no_camera_button")
	check(hud.find_child("TopBar", true, false) != null, "hud_unified_top_bar_exists")
	check(hud.vehicle_label.text.contains("مگان"), "hud_shows_locked_vehicle", "(%s)" % hud.vehicle_label.text)

	# 4) Graphics independence: tooling spawn must not move tier/viewport.
	SettingsManager.graphics_tier = 1
	hud.apply_graphics_quality(1)
	var vp := root.get_viewport()
	var scale_before := vp.scaling_3d_scale
	var msaa_before := vp.msaa_3d
	main.spawn_vehicle(4)
	await step_frames(10)
	check(SettingsManager.graphics_tier == 1 and hud.graphics_quality_tier == 1, "spawn_keeps_graphics_tier")
	check(is_equal_approx(vp.scaling_3d_scale, scale_before) and vp.msaa_3d == msaa_before, "spawn_keeps_viewport_graphics")
	main.spawn_vehicle(2)
	await step_frames(10)

	# 5) Single free-follow camera.
	check(rig.get_mode_label() == "FOLLOW", "camera_single_follow_mode")
	check(rig.get_node_or_null("DirectCamera3D") == null, "camera_no_secondary_node")
	check(root.get_camera_3d() == rig.camera, "camera_is_current")
	var diag := rig.get_camera_diagnostics()
	check(str(diag["mode"]) == "FOLLOW" and bool(diag["is_current"]), "camera_diagnostics_follow")
	hud.btn_throttle.set_simulated_press(true)
	await step_frames(150)
	hud.btn_throttle.set_simulated_press(false)
	diag = rig.get_camera_diagnostics()
	check(float(diag["pivot_error_m"]) < 1.1, "follow_camera_converges", "(err=%.3f m)" % float(diag["pivot_error_m"]))
	var cam_pos: Vector3 = rig.camera.global_position
	var to_car: Vector3 = main.vehicle.global_position - cam_pos
	to_car.y = 0.0
	var fwd_flat := Vector3(main.vehicle.global_transform.basis.z.x, 0.0, main.vehicle.global_transform.basis.z.z).normalized()
	check(to_car.normalized().dot(fwd_flat) > 0.5, "follow_camera_behind_vehicle")

	# 6) Pause: settings reachable, graphics changeable there, resume works.
	hud.set_game_paused(true)
	check(paused and hud.pause_overlay.visible, "pause_overlay_shows")
	var psb := hud.find_child("PauseSettingsButton", true, false) as Button
	check(psb != null, "pause_settings_button")
	if psb != null:
		psb.pressed.emit()
		await process_frame
	check(hud.find_child("PauseSettingsPanel", true, false) != null, "pause_settings_panel")
	hud.apply_graphics_quality(0)
	check(SettingsManager.graphics_tier == 0 and hud.graphics_quality_tier == 0, "pause_graphics_change_applies")
	hud.apply_graphics_quality(1)
	hud.set_game_paused(false)
	check(not paused and not hud.is_game_paused, "resume_restores")

	main.queue_free()
	await process_frame
	SettingsManager.set_selected_vehicle(0)
	SettingsManager.graphics_tier = 1
	SettingsManager.save_settings()

	print("=== PASS 3 SUMMARY: %d passed, %d failed ===" % [passed, failed])
	quit(1 if failed > 0 else 0)
