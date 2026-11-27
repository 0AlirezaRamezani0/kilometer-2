extends SceneTree

## Comprehensive Phase 7 Automated Validation Suite for the 5 Integrated Source A Vehicles,
## Live 6-Vehicle Main-Scene Switching, Memory/Node Hygiene, and Dedicated Studio Preview Scene.

var passed: int = 0
var failed: int = 0


func _initialize() -> void:
	call_deferred("_run_suite")


func _check(cond: bool, label: String, detail: String = "") -> void:
	if cond:
		passed += 1
		var suffix := (" (" + detail + ")") if not detail.is_empty() else ""
		print("  [PASS] %s%s" % [label, suffix])
	else:
		failed += 1
		var suffix := (" (" + detail + ")") if not detail.is_empty() else ""
		push_error("  [FAIL] %s%s" % [label, suffix])


func _collect_meshes(n: Node, out: Array[MeshInstance3D]) -> void:
	if n is MeshInstance3D:
		out.append(n as MeshInstance3D)
	for ch in n.get_children():
		_collect_meshes(ch, out)


func _count_vehicle_bodies(n: Node) -> int:
	var c := 1 if (n is VehicleBody3D and not n.is_queued_for_deletion()) else 0
	for ch in n.get_children():
		c += _count_vehicle_bodies(ch)
	return c


func _step_physics(frames: int) -> void:
	for _i in range(frames):
		await physics_frame


func _run_suite() -> void:
	print("=== PHASE 7 CARPACK INTEGRATION & 6-VEHICLE VALIDATION SUITE ===")

	# 1. Pass 2 intentionally boots to the new main menu; the driving scene
	# itself remains present and loadable. Documented in change summary.
	var main_path := str(ProjectSettings.get_setting("application/run/main_scene"))
	_check(main_path == "res://scenes/ui/main_menu.tscn", "boot_scene_is_main_menu_pass2", main_path)
	_check(ResourceLoader.exists("res://scenes/main/main_driving_template.tscn"), "driving_scene_still_exists", main_path)
	_check(VehicleCatalog.get_count() == 6, "catalog_has_6_vehicles", "count=%d" % VehicleCatalog.get_count())

	# 2. Audit Showcase Geometry, Materials, Proxy Stripping & Ground Plane for all 5 integrated cars
	for idx in range(1, 6):
		var entry := VehicleCatalog.get_entry(idx)
		var vid := str(entry["id"])
		var sc_packed := load(str(entry["showcase_scene"])) as PackedScene
		_check(sc_packed != null, "%s_showcase_loads" % vid)
		if sc_packed == null:
			continue
		var sc := sc_packed.instantiate() as Node3D
		root.add_child(sc)
		await process_frame

		var meshes: Array[MeshInstance3D] = []
		_collect_meshes(sc, meshes)
		_check(meshes.size() >= 8, "%s_has_valid_meshes" % vid, "meshes=%d" % meshes.size())

		var proxy_leaks := 0
		var missing_mats := 0
		var has_world_aabb := false
		var world_aabb := AABB()

		for mi in meshes:
			var nl := mi.name.to_lower()
			if nl.contains("colmesh") or nl.contains("colsphere") or nl.contains("shadowmesh") or nl.ends_with("_dam"):
				proxy_leaks += 1
			if mi.mesh != null and mi.visible:
				for s in range(mi.mesh.get_surface_count()):
					if mi.get_active_material(s) == null:
						missing_mats += 1
				var local_aabb := mi.mesh.get_aabb()
				var xf := mi.global_transform
				for cx in [0, 1]:
					for cy in [0, 1]:
						for cz in [0, 1]:
							var pt := local_aabb.position + Vector3(
								local_aabb.size.x * float(cx),
								local_aabb.size.y * float(cy),
								local_aabb.size.z * float(cz)
							)
							var wpt := xf * pt
							if not has_world_aabb:
								world_aabb = AABB(wpt, Vector3.ZERO)
								has_world_aabb = true
							else:
								world_aabb = world_aabb.expand(wpt)

		_check(proxy_leaks == 0, "%s_zero_collision_or_damage_proxies" % vid, "leaks=%d" % proxy_leaks)
		_check(missing_mats == 0, "%s_all_surfaces_have_materials" % vid, "missing=%d" % missing_mats)
		_check(absf(world_aabb.position.y) < 0.025, "%s_tires_grounded_at_y_zero" % vid, "min_y=%.4f" % world_aabb.position.y)
		_check(world_aabb.size.x > 1.70 and world_aabb.size.x < 2.35, "%s_realistic_metric_width" % vid, "w=%.3f m" % world_aabb.size.x)
		_check(world_aabb.size.y > 1.30 and world_aabb.size.y < 1.85, "%s_realistic_metric_height" % vid, "h=%.3f m" % world_aabb.size.y)
		_check(world_aabb.size.z > 4.20 and world_aabb.size.z < 5.15, "%s_realistic_metric_length" % vid, "l=%.3f m" % world_aabb.size.z)

		sc.queue_free()
		await process_frame

	# 3. Physics Arena Validation for all 5 integrated VehicleBody3D scenes
	var floor_body := StaticBody3D.new()
	var floor_col := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(200.0, 2.0, 600.0)
	floor_col.shape = floor_box
	floor_col.position = Vector3(0.0, -1.0, 0.0)
	floor_body.add_child(floor_col)
	root.add_child(floor_body)
	await _step_physics(4)

	for idx in range(1, 6):
		var entry := VehicleCatalog.get_entry(idx)
		var vid := str(entry["id"])
		var vp := load(str(entry["vehicle_scene"])) as PackedScene
		_check(vp != null, "%s_vehicle_scene_loads" % vid)
		if vp == null:
			continue
		var car := vp.instantiate() as SaipaVehicleController
		car.read_desktop_input = false
		root.add_child(car)
		car.reset_vehicle(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.05, 0.0)))

		# Verify simplified compound 2-box collision shapes
		var col_count := 0
		for ch in car.get_children():
			if ch is CollisionShape3D and (ch as CollisionShape3D).shape is BoxShape3D:
				col_count += 1
		_check(col_count == 2, "%s_compound_2_box_collision_hull" % vid, "boxes=%d" % col_count)

		# Settle 60 physics ticks (1.0 s)
		await _step_physics(60)
		var contacts := car.get_grounded_wheel_count()
		_check(contacts == 4, "%s_idle_4_wheels_grounded" % vid, "contacts=%d" % contacts)
		_check(absf(car.global_position.y) < 0.045, "%s_idle_ride_height_calibrated" % vid, "y=%.4f m" % car.global_position.y)
		_check(car.current_speed_kmh < 0.15, "%s_idle_zero_creep" % vid, "spd=%.4f km/h" % car.current_speed_kmh)

		var det_ok := true
		for vw in [car.vis_wheel_fl, car.vis_wheel_fr, car.vis_wheel_rl, car.vis_wheel_rr]:
			if vw == null or absf(vw.transform.basis.determinant() - 1.0) > 0.02:
				det_ok = false
		_check(det_ok, "%s_visual_wheels_right_handed_det_pos1" % vid)

		# Accelerate 3.0 s (180 physics ticks)
		car.set_control_inputs(1.0, 0.0, 0.0, false)
		await _step_physics(180)
		_check(car.current_speed_kmh > 38.0, "%s_accelerates_forward_cleanly" % vid, "spd=%.2f km/h, z=%.2f m" % [car.current_speed_kmh, car.global_position.z])
		_check(absf(car.global_position.x) < 0.25, "%s_tracks_straight_under_power" % vid, "lat_x=%.4f m" % car.global_position.x)

		# Steer left + brake check
		var pre_brake_spd := car.current_speed_kmh
		car.set_control_inputs(0.0, 1.0, -0.6, false)
		await _step_physics(60)
		_check(car.current_speed_kmh < pre_brake_spd - 15.0, "%s_service_brakes_decelerate" % vid, "%.1f -> %.1f km/h" % [pre_brake_spd, car.current_speed_kmh])
		_check(car.global_position.x > 0.25, "%s_steering_turns_cleanly" % vid, "x=%.2f m" % car.global_position.x)

		car.queue_free()
		await _step_physics(4)

	floor_body.queue_free()
	await _step_physics(2)

	# 4. Pass 3: main scene spawns the menu-selected vehicle exactly once;
	# there is no live switching. The tooling spawn path (tests only) must
	# still keep exactly one active body and rebind camera/HUD cleanly.
	SettingsManager.set_selected_vehicle(0)
	var main_packed := load("res://scenes/main/main_driving_template.tscn") as PackedScene
	var main_inst := main_packed.instantiate()
	root.add_child(main_inst)
	await _step_physics(30)

	_check(main_inst.active_vehicle_index == 0, "main_starts_on_menu_selected_sport_pride")
	_check(_count_vehicle_bodies(main_inst) == 1, "main_initial_single_vehicle_body")
	_check(not main_inst.hud.has_method("_on_vehicle_cycle_pressed"), "hud_has_no_vehicle_cycle_handler")

	for step_i in range(6):
		var expected_idx := (step_i + 1) % 6
		main_inst.spawn_vehicle(expected_idx)
		await _step_physics(25)
		var expected_entry := VehicleCatalog.get_entry(expected_idx)
		var active_car: SaipaVehicleController = main_inst.vehicle
		_check(main_inst.active_vehicle_index == expected_idx, "spawn_step_%d_index_matches" % step_i, "idx=%d (%s)" % [expected_idx, str(expected_entry["id"])])
		_check(_count_vehicle_bodies(main_inst) == 1, "spawn_step_%d_no_leaked_bodies" % step_i)
		_check(main_inst.camera_rig.target_vehicle == active_car and main_inst.hud.vehicle == active_car, "spawn_step_%d_cam_rebound" % step_i)
		_check(active_car.get_grounded_wheel_count() == 4, "spawn_step_%d_4_wheels_grounded" % step_i)

	main_inst.queue_free()
	await _step_physics(4)

	# 5. Dedicated Preview Scene Validation
	var prev_packed := load("res://scenes/preview/asset_integration_preview.tscn") as PackedScene
	_check(prev_packed != null, "preview_scene_loads")
	if prev_packed != null:
		var prev := prev_packed.instantiate() as AssetIntegrationPreview
		root.add_child(prev)
		await process_frame
		await process_frame
		_check(prev.spawned_showcases.size() == 6, "preview_scene_spawns_all_6_vehicles", "count=%d" % prev.spawned_showcases.size())
		_check(prev.preview_camera != null and prev.preview_camera.current, "preview_camera_is_current")
		for p_idx in range(7):
			prev.set_camera_preset(p_idx)
			await process_frame
		_check(prev.active_preset == 6, "preview_camera_presets_0_to_6_work")
		prev.queue_free()
		await process_frame

	print("=== CARPACK INTEGRATION SUMMARY: %d passed, %d failed ===" % [passed, failed])
	quit(0 if failed == 0 else 1)
