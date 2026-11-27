extends SceneTree

var passed: int = 0
var failed: int = 0
var metrics: Dictionary = {}


func _initialize() -> void:
	await _run_suite()
	var out_json := ProjectSettings.globalize_path("res://reports/physics_metrics.json")
	var f := FileAccess.open(out_json, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(metrics, "\t"))
		f.close()
	print("PHASE5_PHYSICS_SUITE: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func check(cond: bool, label: String, detail: String = "") -> void:
	if cond:
		passed += 1
		print("  [PASS] %s %s" % [label, detail])
	else:
		failed += 1
		push_error("  [FAIL] %s %s" % [label, detail])


func _make_static_box(parent: Node3D, box_size: Vector3, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, grip: float = 1.0) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.position = pos
	sb.rotation_degrees = rot_deg
	sb.set_meta("surface_grip", grip)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = box_size
	cs.shape = sh
	sb.add_child(cs)
	parent.add_child(sb)
	return sb


func _step_ticks(count: int) -> void:
	for _i in range(count):
		await physics_frame


func _run_suite() -> void:
	await process_frame

	var arena := Node3D.new()
	arena.name = "PhysicsTestArena"
	root.add_child(arena)

	# Flat 800m x 800m dry asphalt baseline (top surface at Y = 0.0)
	_make_static_box(arena, Vector3(800.0, 2.0, 800.0), Vector3(0.0, -1.0, 0.0), Vector3.ZERO, 1.0)

	var car_scene := load("res://scenes/vehicle/saipa_pride_vehicle.tscn") as PackedScene
	check(car_scene != null, "vehicle_packed_scene_loads")
	if car_scene == null:
		return

	var car := car_scene.instantiate() as SaipaVehicleController
	car.read_desktop_input = false
	var spawn := Transform3D(Basis.IDENTITY, Vector3(0.0, 0.03, 0.0))
	car.transform = spawn
	arena.add_child(car)
	car.set_spawn_transform(spawn)

	# -------------------------------------------------------------------------
	# Test 1: Static 4-Wheel Contact, Ride Height, & Visual Wheel Right-Handed Basis
	# -------------------------------------------------------------------------
	car.set_control_inputs(0.0, 0.0, 0.0, false)
	await _step_ticks(90)
	var settled_y := car.global_position.y
	var grounded_idle := car.get_grounded_wheel_count()
	var idle_spd := car.current_speed_kmh
	var det_ok := true
	for vw in [car.vis_wheel_fl, car.vis_wheel_fr, car.vis_wheel_rl, car.vis_wheel_rr]:
		if absf(vw.global_transform.basis.determinant() - 1.0) > 0.02:
			det_ok = false
	metrics["static_equilibrium"] = {
		"settled_chassis_y_m": snappedf(settled_y, 0.0001),
		"grounded_wheels": grounded_idle,
		"idle_speed_kmh": snappedf(idle_spd, 0.001),
		"visual_wheels_right_handed_det_pos1": det_ok,
	}
	check(grounded_idle == 4, "idle_all_4_wheels_in_contact", "(contacts=%d)" % grounded_idle)
	check(absf(settled_y) <= 0.025, "idle_chassis_ride_height_near_zero", "(y=%.4f m)" % settled_y)
	check(idle_spd < 0.25, "idle_zero_creep_drift", "(spd=%.4f km/h)" % idle_spd)
	check(det_ok, "visual_wheels_have_positive_right_handed_determinant")

	# -------------------------------------------------------------------------
	# Test 2: 5-Second Straight-Line Flat Acceleration
	# -------------------------------------------------------------------------
	car.reset_vehicle(spawn)
	await _step_ticks(30)
	car.set_control_inputs(1.0, 0.0, 0.0, false)
	var min_accel_contacts := 4
	for _t in range(300): # 5.0 seconds @ 60 Hz
		await physics_frame
		min_accel_contacts = mini(min_accel_contacts, car.get_grounded_wheel_count())
	var accel_5s_kmh := car.current_speed_kmh
	var accel_5s_dist_m := car.global_position.z
	var accel_5s_lat_drift_m := absf(car.global_position.x)
	metrics["flat_acceleration_5s"] = {
		"speed_5s_kmh": snappedf(accel_5s_kmh, 0.01),
		"distance_5s_m": snappedf(accel_5s_dist_m, 0.01),
		"lateral_drift_m": snappedf(accel_5s_lat_drift_m, 0.001),
		"min_grounded_wheels": min_accel_contacts,
	}
	check(accel_5s_kmh >= 65.0 and accel_5s_kmh <= 98.0, "accel_5s_reaches_realistic_speed", "(%.2f km/h, dist=%.2f m)" % [accel_5s_kmh, accel_5s_dist_m])
	check(accel_5s_lat_drift_m < 0.35, "accel_5s_tracks_straight", "(lat_drift=%.4f m)" % accel_5s_lat_drift_m)
	check(min_accel_contacts == 4, "accel_5s_maintains_4_wheel_contact")

	# -------------------------------------------------------------------------
	# Test 3: Straight Braking Distance from 60 km/h (Dry Asphalt)
	# -------------------------------------------------------------------------
	car.reset_vehicle(spawn)
	await _step_ticks(25)
	car.set_control_inputs(1.0, 0.0, 0.0, false)
	while car.current_speed_kmh < 60.0:
		await physics_frame
	var brake_entry_kmh := car.current_speed_kmh
	var brake_start_pos := car.global_position
	car.set_control_inputs(0.0, 1.0, 0.0, false)
	var brake_ticks := 0
	while car.current_speed_kmh > 0.5 and brake_ticks < 240:
		await physics_frame
		brake_ticks += 1
	var dry_stop_dist_m := car.global_position.distance_to(brake_start_pos)
	var dry_stop_time_s := float(brake_ticks) / 60.0
	var brake_yaw_deg := absf(rad_to_deg(car.rotation.y))
	metrics["braking_from_60kmh_dry"] = {
		"entry_speed_kmh": snappedf(brake_entry_kmh, 0.01),
		"stopping_distance_m": snappedf(dry_stop_dist_m, 0.01),
		"stopping_time_s": snappedf(dry_stop_time_s, 0.01),
		"yaw_deviation_deg": snappedf(brake_yaw_deg, 0.01),
	}
	check(car.current_speed_kmh <= 0.5, "braking_comes_to_complete_stop", "(final=%.2f km/h)" % car.current_speed_kmh)
	check(dry_stop_dist_m >= 9.0 and dry_stop_dist_m <= 24.0, "braking_distance_realistic_60_to_0", "(dist=%.2f m in %.2f s)" % [dry_stop_dist_m, dry_stop_time_s])
	check(brake_yaw_deg < 3.0, "braking_straight_line_stability", "(yaw=%.2f deg)" % brake_yaw_deg)

	# -------------------------------------------------------------------------
	# Test 4: Low-Friction Surface Grip Comparison (Braking from 60 km/h on Wet/Ice Skidpad)
	# -------------------------------------------------------------------------
	var slick_patch := _make_static_box(arena, Vector3(18.0, 0.04, 160.0), Vector3(60.0, 0.0, 75.0), Vector3.ZERO, 0.28)
	var slick_spawn := Transform3D(Basis.IDENTITY, Vector3(60.0, 0.05, 5.0))
	car.reset_vehicle(slick_spawn)
	await _step_ticks(25)
	car.set_control_inputs(0.85, 0.0, 0.0, false)
	var wait_slick := 0
	while car.current_speed_kmh < 52.0 and wait_slick < 360:
		await physics_frame
		wait_slick += 1
	var wet_entry_kmh := car.current_speed_kmh
	var wet_start_pos := car.global_position
	var observed_grip := car.active_surface_grip
	car.set_control_inputs(0.0, 1.0, 0.0, false)
	var wet_ticks := 0
	while car.current_speed_kmh > 0.5 and wet_ticks < 420:
		await physics_frame
		wet_ticks += 1
	var wet_stop_dist_m := car.global_position.distance_to(wet_start_pos)
	# Normalize stopping distance by v^2 ratio to compare directly at 60 km/h entry speed
	var norm_wet_60_dist := wet_stop_dist_m * pow(brake_entry_kmh / maxf(wet_entry_kmh, 1.0), 2.0)
	metrics["low_friction_braking_comparison"] = {
		"observed_surface_grip": snappedf(observed_grip, 0.01),
		"wet_entry_speed_kmh": snappedf(wet_entry_kmh, 0.01),
		"wet_raw_stop_dist_m": snappedf(wet_stop_dist_m, 0.01),
		"wet_normalized_60kmh_stop_dist_m": snappedf(norm_wet_60_dist, 0.01),
		"wet_vs_dry_distance_ratio": snappedf(norm_wet_60_dist / maxf(dry_stop_dist_m, 0.1), 0.01),
	}
	check(observed_grip < 0.35 and norm_wet_60_dist > dry_stop_dist_m * 1.35, "low_friction_patch_increases_stopping_distance", "(grip=%.2f, norm_wet=%.2f m vs dry=%.2f m)" % [observed_grip, norm_wet_60_dist, dry_stop_dist_m])
	slick_patch.queue_free()

	# -------------------------------------------------------------------------
	# Test 5: Reverse Gear Engagement & Speed Cap
	# -------------------------------------------------------------------------
	car.reset_vehicle(spawn)
	await _step_ticks(30)
	car.set_control_inputs(0.0, 1.0, 0.0, false)
	await _step_ticks(210) # 3.5 seconds
	var rev_z := car.global_position.z
	var rev_kmh := -car.forward_speed_mps * 3.6
	var rev_gear := car.get_gear_label()
	metrics["reverse_test"] = {
		"gear_label": rev_gear,
		"reverse_speed_kmh": snappedf(rev_kmh, 0.01),
		"z_displacement_m": snappedf(rev_z, 0.01),
	}
	check(rev_gear == "R", "reverse_engages_gear_R", "(gear=%s)" % rev_gear)
	check(rev_z < -12.0, "reverse_moves_backward_negative_z", "(z=%.2f m)" % rev_z)
	check(rev_kmh >= 18.0 and rev_kmh <= 38.5, "reverse_speed_cleanly_governed", "(rev_spd=%.2f km/h)" % rev_kmh)

	# -------------------------------------------------------------------------
	# Test 6: Low-Speed Left/Right Symmetry & High-Speed Hard Cornering Stability
	# -------------------------------------------------------------------------
	car.reset_vehicle(spawn)
	await _step_ticks(25)
	car.set_control_inputs(0.40, 0.0, -1.0, false) # Full Left (+X)
	await _step_ticks(150)
	var left_turn_x := car.global_position.x

	car.reset_vehicle(spawn)
	await _step_ticks(25)
	car.set_control_inputs(0.40, 0.0, 1.0, false) # Full Right (-X)
	await _step_ticks(150)
	var right_turn_x := car.global_position.x

	metrics["low_speed_steering_symmetry"] = {
		"left_turn_x_m": snappedf(left_turn_x, 0.01),
		"right_turn_x_m": snappedf(right_turn_x, 0.01),
	}
	check(left_turn_x > 3.0 and right_turn_x < -3.0 and absf(left_turn_x + right_turn_x) < 0.45, "low_speed_left_and_right_steering_work", "(left_x=+%.2f m, right_x=%.2f m)" % [left_turn_x, right_turn_x])

	# High-speed hard cornering stability at ~70 km/h
	car.reset_vehicle(spawn)
	await _step_ticks(25)
	car.set_control_inputs(1.0, 0.0, 0.0, false)
	while car.current_speed_kmh < 70.0:
		await physics_frame
	car.set_control_inputs(0.65, 0.0, 1.0, false) # Hard full-input right turn at 70 km/h for 3.0s
	var max_corner_roll_deg := 0.0
	var min_corner_up_dot := 1.0
	var min_corner_contacts := 4
	for _c in range(180):
		await physics_frame
		max_corner_roll_deg = maxf(max_corner_roll_deg, absf(rad_to_deg(car.rotation.z)))
		min_corner_up_dot = minf(min_corner_up_dot, car.global_transform.basis.y.normalized().dot(Vector3.UP))
		min_corner_contacts = mini(min_corner_contacts, car.get_grounded_wheel_count())
	metrics["high_speed_cornering_70kmh"] = {
		"max_body_roll_deg": snappedf(max_corner_roll_deg, 0.01),
		"min_up_dot": snappedf(min_corner_up_dot, 0.0001),
		"min_grounded_wheels": min_corner_contacts,
	}
	check(min_corner_up_dot > 0.96 and max_corner_roll_deg < 8.0, "high_speed_cornering_no_rollover", "(max_roll=%.2f deg, min_up_dot=%.4f)" % [max_corner_roll_deg, min_corner_up_dot])
	check(min_corner_contacts >= 3, "high_speed_cornering_maintains_road_holding", "(min_contacts=%d)" % min_corner_contacts)

	# -------------------------------------------------------------------------
	# Test 7: Slope Climb (10 deg incline) & Speed Bump Traversal (0.10 m bump)
	# -------------------------------------------------------------------------
	# Ramp 18m long tilted -10 deg around X (rises along +Z from Y=0 to Y=3.12m) + flat plateau
	var ramp := _make_static_box(arena, Vector3(12.0, 0.5, 20.0), Vector3(-50.0, 1.48, 22.0), Vector3(-10.0, 0.0, 0.0), 1.0)
	var plateau := _make_static_box(arena, Vector3(12.0, 0.5, 20.0), Vector3(-50.0, 2.98, 41.2), Vector3.ZERO, 1.0)
	var slope_spawn := Transform3D(Basis.IDENTITY, Vector3(-50.0, 0.03, 0.0))
	car.reset_vehicle(slope_spawn)
	await _step_ticks(25)
	car.set_control_inputs(1.0, 0.0, 0.0, false)
	var peak_slope_y := 0.0
	for _s in range(240):
		await physics_frame
		peak_slope_y = maxf(peak_slope_y, car.global_position.y)
	metrics["slope_climb_10deg"] = {
		"peak_height_reached_m": snappedf(peak_slope_y, 0.01),
		"final_z_m": snappedf(car.global_position.z, 0.01),
	}
	check(peak_slope_y > 2.5, "climbs_10_degree_slope_onto_plateau", "(peak_y=%.2f m)" % peak_slope_y)
	ramp.queue_free()
	plateau.queue_free()

	# Chamfered speed hump at Z=22.0m (gentle 14-deg up/down ramps, 0.16m crown height)
	var bump_up := _make_static_box(arena, Vector3(10.0, 0.20, 1.40), Vector3(-90.0, -0.01, 21.15), Vector3(-14.0, 0.0, 0.0), 1.0)
	var bump_top := _make_static_box(arena, Vector3(10.0, 0.32, 0.70), Vector3(-90.0, 0.0, 22.0), Vector3.ZERO, 1.0)
	var bump_dn := _make_static_box(arena, Vector3(10.0, 0.20, 1.40), Vector3(-90.0, -0.01, 22.85), Vector3(14.0, 0.0, 0.0), 1.0)
	var bump_spawn := Transform3D(Basis.IDENTITY, Vector3(-90.0, 0.03, 0.0))
	car.reset_vehicle(bump_spawn)
	await _step_ticks(25)
	car.set_control_inputs(0.85, 0.0, 0.0, false)
	var peak_bump_y := 0.0
	for _b in range(240):
		await physics_frame
		peak_bump_y = maxf(peak_bump_y, car.global_position.y)
	var post_bump_up := car.global_transform.basis.y.normalized().dot(Vector3.UP)
	var post_bump_z := car.global_position.z
	metrics["bump_traversal"] = {
		"peak_bump_chassis_y_m": snappedf(peak_bump_y, 0.001),
		"post_bump_z_m": snappedf(post_bump_z, 0.01),
		"post_bump_up_dot": snappedf(post_bump_up, 0.001),
		"post_bump_contacts": car.get_grounded_wheel_count(),
	}
	check(post_bump_z > 30.0 and peak_bump_y > 0.08 and post_bump_up > 0.96, "traverses_speed_bump_cleanly_without_flip", "(z=%.2f m, peak_y=%.3f m, up_dot=%.3f)" % [post_bump_z, peak_bump_y, post_bump_up])
	bump_up.queue_free()
	bump_top.queue_free()
	bump_dn.queue_free()

	# -------------------------------------------------------------------------
	# Test 8: Solid Barrier Collision Safety (No Tunneling / No NaN)
	# -------------------------------------------------------------------------
	var wall := _make_static_box(arena, Vector3(14.0, 3.0, 1.2), Vector3(-130.0, 1.5, 30.0), Vector3.ZERO, 1.0)
	var wall_spawn := Transform3D(Basis.IDENTITY, Vector3(-130.0, 0.03, 0.0))
	car.reset_vehicle(wall_spawn)
	await _step_ticks(25)
	car.set_control_inputs(1.0, 0.0, 0.0, false)
	for _w in range(160):
		await physics_frame
	car.set_control_inputs(0.0, 0.5, 0.0, false)
	await _step_ticks(30)
	var wall_stopped_z := car.global_position.z
	var finite_ok := car.global_position.is_finite() and car.linear_velocity.is_finite()
	metrics["wall_collision"] = {
		"wall_face_z_m": 29.4,
		"vehicle_final_z_m": snappedf(wall_stopped_z, 0.01),
		"transforms_finite": finite_ok,
	}
	check(finite_ok and wall_stopped_z < 29.5, "wall_collision_blocks_vehicle_without_tunneling_or_nan", "(final_z=%.2f m < 29.5 m)" % wall_stopped_z)
	wall.queue_free()

	# -------------------------------------------------------------------------
	# Test 9: Rollover Auto-Recovery & Velocity-Clearing Manual Reset
	# -------------------------------------------------------------------------
	var flipped_tf := Transform3D(Basis(Vector3.MODEL_FRONT, PI), Vector3(0.0, 1.25, 0.0))
	car.reset_vehicle(flipped_tf)
	car.rollover_recover_delay_sec = 1.0
	car.set_control_inputs(0.0, 0.0, 0.0, false)
	await _step_ticks(120) # 2.0 seconds -> auto-recovery triggers at 1.0s + settles
	var recovered_up := car.global_transform.basis.y.normalized().dot(Vector3.UP)
	check(recovered_up > 0.98 and car.get_grounded_wheel_count() == 4, "upside_down_auto_recovery_restores_upright_state", "(up_dot=%.4f)" % recovered_up)

	# Accelerate, then trigger manual reset mid-motion and verify velocities clear to 0 immediately
	car.set_control_inputs(1.0, 0.0, 0.0, false)
	await _step_ticks(90)
	check(car.current_speed_kmh > 25.0, "pre_reset_vehicle_moving_fast")
	car.clear_external_inputs()
	car.reset_vehicle(spawn)
	await _step_ticks(2)
	var post_reset_spd := car.linear_velocity.length()
	var post_reset_ang := car.angular_velocity.length()
	metrics["reset_safety"] = {
		"post_reset_linear_speed_mps": snappedf(post_reset_spd, 0.001),
		"post_reset_angular_speed_rad_s": snappedf(post_reset_ang, 0.001),
		"post_reset_pos_error_m": snappedf(car.global_position.distance_to(spawn.origin), 0.001),
	}
	check(post_reset_spd < 0.35 and post_reset_ang < 0.35 and car.global_position.distance_to(spawn.origin) < 0.1, "manual_reset_clears_velocity_and_restores_spawn", "(lin=%.3f m/s, ang=%.3f rad/s)" % [post_reset_spd, post_reset_ang])
