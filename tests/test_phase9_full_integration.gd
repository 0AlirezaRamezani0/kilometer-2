extends SceneTree

## Phase 9/10 Full End-to-End Integration, Single Follow Camera, Optimization & Persian UI Suite (Kilometer 2, pass 3 spec).

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


func _flat_heading(car: Node3D) -> float:
	var f := car.global_transform.basis.z
	return atan2(f.x, f.z)


## Signed lateral offset (m) from the spawn point, measured perpendicular to the spawn
## heading: positive = the car's left, negative = right.
func _lateral_m(car: Node3D, heading: float, origin: Vector3) -> float:
	var fwd := Vector3(sin(heading), 0.0, cos(heading))
	var left := Vector3(fwd.z, 0.0, -fwd.x)
	return (car.global_position - origin).dot(left)


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
	print("=== SAIPA BETA 3 FULL INTEGRATION, FIXED CAMERA & PERSIAN UI SUITE ===")
	root.size = Vector2i(1280, 720)
	var main_packed: PackedScene = load("res://scenes/main/main_driving_template.tscn")
	check(main_packed != null, "main_driving_template_loads")

	var main: Node3D = main_packed.instantiate()
	root.add_child(main)
	await step_frames(90)

	var car: SaipaVehicleController = main.vehicle
	var cam_rig: VehicleCameraRig = main.camera_rig
	var hud: VehicleHud = main.hud
	var track: DesertCircuit = main.track

	check(car != null and cam_rig != null and hud != null and track != null, "all_core_subsystems_bound")
	check(ProjectSettings.get_setting("application/config/name") == "Kilometer 2", "project_name_is_kilometer_2")

	# 1. Optimization Architecture Verification (MultiMesh + Consolidated StaticBodies + Batched Vehicle Shell)
	var static_body_count := 0
	var stack: Array[Node] = [track]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is StaticBody3D:
			static_body_count += 1
		for ch in n.get_children():
			stack.append(ch)
	# v0.2-b1: the map is the desert circuit. The old expectation (10 bodies:
	# 2 shared surfaces + 7 slalom cones + 1 grass floor) described the procedural
	# proving ground that this build replaces, so it is updated deliberately:
	# 3 bodies now — DryTrackStaticBody (asphalt ribbon), SandStaticBody (low-grip
	# floor), CircuitBoundary (terrain-edge walls). Nothing was silently dropped;
	# the cones/skidpad no longer exist because their map does not.
	check(static_body_count == 3, "track_static_bodies_asphalt_sand_boundary", "(count=%d)" % static_body_count)
	check(track.find_child("DryTrackStaticBody", true, false) != null and track.find_child("SandStaticBody", true, false) != null, "track_shared_surface_bodies_exist")
	check(track.find_child("CircuitBoundary", true, false) != null, "track_boundary_walls_exist")
	var asphalt := track.find_child("DryTrackStaticBody", true, false) as StaticBody3D
	var sand := track.find_child("SandStaticBody", true, false) as StaticBody3D
	check(asphalt != null and float(asphalt.get_meta("surface_grip", 0.0)) == 1.0, "asphalt_surface_grip_is_1")
	check(sand != null and float(sand.get_meta("surface_grip", 0.0)) == 0.5, "sand_surface_grip_is_half")
	check(track.get_track_length() > 300.0 and track.get_track_length() < 420.0, "circuit_length_matches_survey", "(len=%.1f m)" % track.get_track_length())
	check(track.sample_count() >= 300, "circuit_centerline_sampled_1m", "(samples=%d)" % track.sample_count())
	check(track.get_node_or_null("StartLamp0") != null and track.get_node_or_null("StartLamp4") != null, "start_gantry_lamps_exist")
	check(track.get_lap_state().has("lap") and track.get_lap_state().has("sector"), "lap_state_exposed")
	check(car.visual_model.find_child("BatchedExteriorShell", false, false) != null, "vehicle_runtime_surface_batching_active")

	# 2. Persian HUD Typography & Initial Telemetry
	check(car.get_grounded_wheel_count() == 4, "main_scene_spawn_4_wheels_grounded")
	# v0.1-b3: the digital readout lives in the speedometer as two labels —
	# the number (speed_label, Latin instrument digits) and its Persian unit.
	check(hud.speed_unit_label != null and hud.speed_unit_label.text.contains("کیلومتر/ساعت") and hud.speed_unit_label.is_visible_in_tree(), "persian_speed_unit_displayed", "(%s)" % (hud.speed_unit_label.text if hud.speed_unit_label != null else "null"))
	check(hud.gear_label.text.contains("خلاص") or hud.gear_label.text.contains("دنده"), "persian_gear_badge_displayed", "(%s)" % hud.gear_label.text)
	# v0.1-b3: the chip shows the Persian catalog name next to a car icon
	# (the redundant «خودرو:» prefix was removed — audit A-12).
	check(hud.vehicle_label.text == str(VehicleCatalog.get_entry(VehicleCatalog.find_index_by_id(car.vehicle_id))["name_fa"]), "persian_vehicle_chip_displayed", "(%s)" % hud.vehicle_label.text)
	check(hud.find_child("CameraButton", true, false) == null and hud.find_child("VehicleSelectButton", true, false) == null, "no_camera_or_vehicle_switch_buttons")

	# 3. Single Free-Follow Camera (pass 3): one camera, smoothed follow,
	# no steer-input yaw sway while stationary, gentle speed FOV.
	check(cam_rig.get_mode_label() == "FOLLOW", "single_follow_camera_mode")
	check(cam_rig.get_node_or_null("DirectCamera3D") == null, "no_secondary_camera_node")
	check(root.get_camera_3d() == cam_rig.camera, "follow_camera_is_current")
	var base_fov := cam_rig.base_fov_deg
	# Pure steering while stationary must NOT swing the locked camera yaw!
	var yaw_before_steer := cam_rig.spring_arm.global_rotation.y
	hud.btn_steer_right.set_simulated_press(true)
	await step_frames(25)
	var yaw_during_steer := cam_rig.spring_arm.global_rotation.y
	hud.btn_steer_right.set_simulated_press(false)
	await step_frames(10)
	check(absf(wrapf(yaw_during_steer - yaw_before_steer, -PI, PI)) < 0.02, "follow_camera_no_unwanted_steer_sway", "(dyaw=%.5f)" % absf(yaw_during_steer - yaw_before_steer))

	# 4. Touch Throttle + Free-Follow convergence under acceleration
	hud.btn_throttle.set_simulated_press(true)
	await step_frames(180)
	var touch_spd := car.current_speed_kmh
	var expected_pivot := car.global_position + Vector3(0.0, cam_rig.look_target_height_m, 0.0)
	var pivot_lag_m := cam_rig.global_position.distance_to(expected_pivot)
	check(touch_spd > 42.0, "touch_throttle_accelerates_vehicle", "(speed=%.2f km/h)" % touch_spd)
	check(pivot_lag_m < 1.1, "follow_camera_converges_at_speed", "(lag=%.3f m)" % pivot_lag_m)
	check(cam_rig.camera.fov >= base_fov - 0.01 and cam_rig.camera.fov <= base_fov + 13.01, "follow_camera_gentle_speed_fov", "(fov=%.2f)" % cam_rig.camera.fov)
	check(cam_rig.camera.global_position.distance_to(car.global_position) > 3.0, "follow_camera_stays_behind_vehicle")
	var hud_spd_int := int(hud.speed_label.text.strip_edges())
	check(absi(hud_spd_int - int(round(touch_spd))) <= 2 and hud.speed_unit_label.text.contains("کیلومتر/ساعت"), "persian_hud_speed_matches_vehicle", "(hud='%s %s', actual=%.1f)" % [hud.speed_label.text, hud.speed_unit_label.text, touch_spd])
	hud.btn_throttle.set_simulated_press(false)

	# 5. Pass 3: no look-back / no alternate views — the single follow
	# camera stays current and behind the car at all times.
	check(root.get_camera_3d() == cam_rig.camera and cam_rig.get_mode_label() == "FOLLOW", "single_camera_remains_active")
	var cam_to_car := (car.global_position - cam_rig.camera.global_position)
	cam_to_car.y = 0.0
	var car_fwd_flat := Vector3(car.global_transform.basis.z.x, 0.0, car.global_transform.basis.z.z).normalized()
	check(cam_to_car.normalized().dot(car_fwd_flat) > 0.55, "follow_camera_trails_behind_heading")

	# 6. Touch Brake -> Auto-Reverse Verification
	hud.btn_brake_rev.set_simulated_press(true)
	await step_frames(210)
	check(car.gear_state == SaipaVehicleController.GearState.REVERSE and car.forward_speed_mps < -2.0, "touch_brake_stops_and_reverses", "(vz=%.2f m/s, hud_gear=%s)" % [car.forward_speed_mps, hud.gear_label.text])
	hud.btn_brake_rev.set_simulated_press(false)

	# 7. HUD Reset Button
	hud.reset_button.pressed.emit()
	await step_frames(30)
	check(car.current_speed_kmh < 0.3 and car.global_position.distance_to(track.get_spawn_transform().origin) < 0.35, "hud_reset_restores_spawn_cleanly")

	# 8. Steering Mode 1: Button Pads
	# v0.2-b1: the map changed, so the steering checks are now measured in the car's own
	# heading frame (lateral offset from the spawn heading) instead of on the world X axis.
	# The old assertions baked in the proving ground's spawn orientation, which no longer
	# exists; the behaviour being tested — "left is left" — is unchanged.
	var start_head := _flat_heading(car)
	hud.steer_ui_mode = VehicleHud.SteerUiMode.BUTTONS
	hud.btn_throttle.set_simulated_press(true)
	hud.btn_steer_left.set_simulated_press(true)
	await step_frames(90)
	var lat_btn_left := _lateral_m(car, start_head, track.get_spawn_transform().origin)
	hud.btn_throttle.set_simulated_press(false)
	hud.btn_steer_left.set_simulated_press(false)
	check(lat_btn_left > 1.2, "touch_button_steer_turns_left", "(lateral=%.2f m)" % lat_btn_left)

	# 9. Steering Mode 2: Interactive Rotary Virtual Steering Wheel (غربیلک لمسی)
	hud.reset_button.pressed.emit()
	await step_frames(30)
	hud.steer_ui_mode = VehicleHud.SteerUiMode.WHEEL
	await process_frame
	check(hud.steer_ui_mode == VehicleHud.SteerUiMode.WHEEL and hud.steering_wheel_pad.visible, "rotary_steering_wheel_mode_toggles")
	hud.btn_throttle.set_simulated_press(true)
	hud.steering_wheel_pad.set_simulated_steer(0.75)
	await step_frames(90)
	var lat_wheel_right := _lateral_m(car, start_head, track.get_spawn_transform().origin)
	hud.btn_throttle.set_simulated_press(false)
	hud.steering_wheel_pad.set_simulated_steer(0.0)
	check(lat_wheel_right < -1.2, "rotary_steering_wheel_steers_right", "(lateral=%.2f m)" % lat_wheel_right)

	# 10. Steering Mode 3: Analog Slider + Deadzone
	hud.reset_button.pressed.emit()
	await step_frames(30)
	hud.steer_ui_mode = VehicleHud.SteerUiMode.ANALOG_BAR
	await process_frame
	check(hud.steer_ui_mode == VehicleHud.SteerUiMode.ANALOG_BAR and hud.analog_steer_bar.visible, "analog_steer_bar_mode_toggles")
	hud.analog_steer_bar.set_simulated_raw_axis(0.04)
	await process_frame
	check(absf(hud.analog_steer_bar.steer_value) < 0.001, "analog_steer_deadzone_filters_noise")
	hud.btn_throttle.set_simulated_press(true)
	hud.analog_steer_bar.set_simulated_raw_axis(0.72)
	await step_frames(90)
	var lat_analog_right := _lateral_m(car, start_head, track.get_spawn_transform().origin)
	hud.btn_throttle.set_simulated_press(false)
	hud.analog_steer_bar.set_simulated_raw_axis(0.0)
	check(lat_analog_right < -1.2, "analog_steer_bar_steers_right", "(lateral=%.2f m)" % lat_analog_right)
	hud.steer_ui_mode = VehicleHud.SteerUiMode.BUTTONS # Back to BUTTONS

	# 11. Pass 3 spec: single follow camera (no cycling, no lock toggle,
	# no HUD switching UI) + graphics owned by Settings only.
	var visited_modes: Array[String] = [cam_rig.get_mode_label()]
	check(visited_modes == ["FOLLOW"], "only_one_camera_behavior", "(modes=%s)" % str(visited_modes))
	check(not InputMap.has_action("cycle_camera") and not InputMap.has_action("cycle_vehicle"), "no_cycle_input_actions")
	check(hud.find_child("CameraLockButton", true, false) == null and hud.find_child("LightsButton", true, false) == null, "no_removed_hud_toggles")

	hud.set_game_paused(true)
	var pause_settings_btn := hud.find_child("PauseSettingsButton", true, false) as Button
	check(pause_settings_btn != null, "pause_settings_button_exists")
	if pause_settings_btn != null:
		pause_settings_btn.pressed.emit()
		await process_frame
		check(hud.find_child("PauseSettingsPanel", true, false) != null, "pause_settings_panel_opens")
	hud.apply_graphics_quality(0)
	check(hud.graphics_quality_tier == 0 and SettingsManager.graphics_tier == 0, "mobile_fast_graphics_tier_applies")
	hud.apply_graphics_quality(1)
	check(hud.graphics_quality_tier == 1 and SettingsManager.graphics_tier == 1, "balanced_graphics_tier_restores")
	var vp := root.get_viewport()
	check(vp != null and vp.msaa_3d == Viewport.MSAA_2X, "viewport_graphics_follow_tier")
	hud.set_game_paused(false)
	check(not hud.is_game_paused, "pause_settings_flow_resumes")

	# 12. Multi-Aspect-Ratio Responsive Persian HUD Audit (16:9, 18:9, 20:9, 4:3)
	var test_resolutions: Array[Vector2i] = [
		Vector2i(1280, 720),
		Vector2i(1440, 720),
		Vector2i(1600, 720),
		Vector2i(1024, 768),
	]
	for res in test_resolutions:
		root.size = res
		await process_frame
		await process_frame
		var canvas_size := root.get_visible_rect().size
		var left_rect := hud.steer_buttons_box.get_global_rect()
		var gauge_rect := hud.gauge_cluster.get_global_rect()
		var right_rect := hud.btn_throttle.get_global_rect()
		var no_overlap := (left_rect.end.x + 20.0 < gauge_rect.position.x) and (gauge_rect.end.x + 20.0 < right_rect.position.x)
		var inside_bounds := (left_rect.position.x >= 0.0) and (right_rect.end.x <= canvas_size.x + 1.0) and (right_rect.end.y <= canvas_size.y + 1.0)
		check(no_overlap and inside_bounds, "responsive_persian_hud_%dx%d" % [res.x, res.y], "(left_end=%.0f, gauge=[%.0f..%.0f], throttle=[%.0f..%.0f], canvas=%.0fx%.0f)" % [left_rect.end.x, gauge_rect.position.x, gauge_rect.end.x, right_rect.position.x, right_rect.end.x, canvas_size.x, canvas_size.y])

	main.queue_free()
	await process_frame

	var summary := {
		"project": "Kilometer 2",
		"passed": passed,
		"failed": failed,
		"visited_camera_modes": visited_modes,
		"fixed_camera_pivot_lag_m": snappedf(pivot_lag_m, 0.0001),
		"touch_peak_speed_kmh": snappedf(touch_spd, 0.01),
	}
	var f := FileAccess.open("res://reports/integration_metrics.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(summary, "\t"))
		f.close()

	print("=== SAIPA BETA 3 INTEGRATION SUMMARY: %d passed, %d failed ===" % [passed, failed])
	quit(1 if failed > 0 else 0)
