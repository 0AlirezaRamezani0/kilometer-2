extends SceneTree

var passed: int = 0
var failed: int = 0


func _initialize() -> void:
	await run_audit()
	print("PHASE3_MODEL_AUDIT: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func check(cond: bool, label: String, detail: String = "") -> void:
	if cond:
		passed += 1
		print("  [PASS] %s %s" % [label, detail])
	else:
		failed += 1
		push_error("  [FAIL] %s %s" % [label, detail])


func check_approx(actual: float, expected: float, tol: float, label: String) -> void:
	var diff := absf(actual - expected)
	check(diff <= tol, label, "(actual=%.4f, expected=%.4f, tol=%.4f)" % [actual, expected, tol])


func run_audit() -> bool:
	await process_frame

	var showcase_scene := load("res://scenes/vehicle/saipa_pride_showcase.tscn") as PackedScene
	check(showcase_scene != null, "showcase_packed_scene_loads")
	if showcase_scene == null:
		return false

	var car: Node3D = showcase_scene.instantiate() as Node3D
	root.add_child(car)
	await process_frame

	var meshes: Array[MeshInstance3D] = []
	var has_negative_scale := false
	var missing_material_surfaces := 0
	var stack: Array[Node] = [car]

	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Node3D:
			var sc := (n as Node3D).scale
			if sc.x <= 0.0 or sc.y <= 0.0 or sc.z <= 0.0:
				has_negative_scale = true
				push_error("Negative/zero scale on node: %s -> %s" % [n.name, str(sc)])
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			meshes.append(mi)
			if mi.mesh != null:
				for s in range(mi.mesh.get_surface_count()):
					if mi.get_active_material(s) == null:
						missing_material_surfaces += 1
		for ch in n.get_children():
			stack.append(ch)

	# 29 body meshes + 4 wheel meshes = 33 MeshInstance3D nodes
	check(meshes.size() == 33, "mesh_instance_count_equals_33", "(count=%d)" % meshes.size())
	check(not has_negative_scale, "no_negative_or_zero_node_scales")
	check(missing_material_surfaces == 0, "all_mesh_surfaces_have_materials", "(missing=%d)" % missing_material_surfaces)

	# Compute exact world AABB across all 33 MeshInstance3D nodes
	var min_pt := Vector3(1e9, 1e9, 1e9)
	var max_pt := Vector3(-1e9, -1e9, -1e9)
	for mi in meshes:
		var aabb := mi.get_aabb()
		for corner_idx in range(8):
			var world_pt := mi.global_transform * aabb.get_endpoint(corner_idx)
			min_pt = min_pt.min(world_pt)
			max_pt = max_pt.max(world_pt)

	var size := max_pt - min_pt
	print("  [INFO] World AABB min=%s max=%s size=%s" % [str(min_pt), str(max_pt), str(size)])

	check_approx(min_pt.y, 0.0, 0.015, "tires_rest_on_ground_y_zero")
	check_approx(size.x, 2.0735, 0.05, "vehicle_width_matches_source")
	check_approx(size.y, 1.4448, 0.05, "vehicle_height_matches_source")
	check_approx(size.z, 4.5970, 0.05, "vehicle_length_matches_source")

	# Verify orientation: Front bumper at +Z (Vector3.MODEL_FRONT), Rear bumper at -Z
	var front_bumper := car.find_child("bump_front_ok", true, false) as MeshInstance3D
	var rear_bumper := car.find_child("bump_rear_ok", true, false) as MeshInstance3D
	var door_lf := car.find_child("door_lf_ok", true, false) as MeshInstance3D
	var door_rf := car.find_child("door_rf_ok", true, false) as MeshInstance3D
	var steer := car.find_child("steering_dummy", true, false) as Node3D

	check(front_bumper != null and rear_bumper != null, "front_and_rear_bumpers_present")
	if front_bumper != null and rear_bumper != null:
		var fb_center := (front_bumper.global_transform * front_bumper.get_aabb().get_center())
		var rb_center := (rear_bumper.global_transform * rear_bumper.get_aabb().get_center())
		check(fb_center.z > 1.5, "front_bumper_at_positive_z_model_front", "(z=%.3f)" % fb_center.z)
		check(rb_center.z < -1.4, "rear_bumper_at_negative_z_model_rear", "(z=%.3f)" % rb_center.z)

	if door_lf != null and door_rf != null:
		var lf_center := (door_lf.global_transform * door_lf.get_aabb().get_center())
		var rf_center := (door_rf.global_transform * door_rf.get_aabb().get_center())
		check(lf_center.x > 0.5, "left_front_door_at_positive_x_model_left", "(x=%.3f)" % lf_center.x)
		check(rf_center.x < -0.5, "right_front_door_at_negative_x_model_right", "(x=%.3f)" % rf_center.x)

	check(steer != null and steer.global_position.x > 0.2 and steer.global_position.z > 0.3, "lhd_steering_column_in_front_left_cabin")

	car.queue_free()
	await process_frame
	return true
