class_name VehicleCameraRig
extends Node3D

## Kilometer 2 camera — single smooth free-follow rig.
##
## Architecture (fixed for zero forward/backward judder at any FPS):
## - project.godot enables physics/common/physics_interpolation = true so
##   Godot smoothly interpolates the vehicle body for rendering.
## - This rig (and its SpringArm3D + Camera3D children) sets
##   physics_interpolation_mode = PHYSICS_INTERPOLATION_MODE_OFF so the
##   engine NEVER double-interpolates transforms written in _process().
##   Previously, leaving FTI ON while moving the rig in _process() caused
##   Godot to lerp between stale 60 Hz snapshots and render-rate writes,
##   producing 20–50 cm back-and-forth camera glitches whenever the car
##   drove forward.
## - In _process(delta), the rig reads
##   target_vehicle.get_global_transform_interpolated() — the exact pose
##   the engine renders the car at on this frame. That eliminates the old
##   1-tick phase lag, Replay camera freeze (when vehicle.freeze == true),
##   Reset slingshot, and feed-forward crash overshoot in one stroke.
## - SpringArm3D's built-in 60 Hz internal step is disabled so distance
##   expansion during acceleration never stair-steps at 60 Hz; instead, a
##   physics-rate sphere cast (cast_motion) computes wall clearance and
##   _process() applies instant pull-in + smooth release at display rate.
## - Yaw uses frame-rate-independent exponential smoothing plus
##   look-into-the-corner (up to 8 deg, correct sign from smoothed_steer_rad).
## - Speed framing (eased): distance 5.2 -> 7.4 m, height +0.4 m,
##   FOV base -> base+13.
## - Shake: trauma-based, scaled by shake_amount (SettingsManager).
## - camera_reset action (C key / R3) snaps the rig to the vehicle.

@export var target_vehicle_path: NodePath
@export_group("Free Follow Tuning")
@export_range(2.8, 10.5, 0.1) var follow_distance_m: float = 5.2
@export_range(0.9, 4.5, 0.05) var follow_height_m: float = 1.9
@export_range(0.3, 2.2, 0.05) var look_target_height_m: float = 0.84
@export_range(40.0, 82.0, 1.0) var base_fov_deg: float = 55.0
@export_range(4.0, 30.0, 0.5) var smooth_yaw_rate: float = 9.0
@export_range(4.0, 40.0, 0.5) var smooth_pos_rate: float = 18.0
@export_group("Shake")
@export_range(0.0, 1.0, 0.05) var shake_amount: float = 0.35

var target_vehicle: SaipaVehicleController = null
var diagnostics_enabled: bool = false

var _smoothed_pivot_pos: Vector3 = Vector3.ZERO
var _vertical_offset: float = 0.0
var _smoothed_yaw_rad: float = 0.0
var _initialized: bool = false
var _eff_distance: float = 5.2
var _eff_height: float = 1.9
var _eff_fov: float = 55.0
var _desired_arm_len: float = 5.4
var _current_arm_len: float = 5.4
var _wall_clearance_len: float = INF
var _excluded_rids: Array[RID] = []

var _trauma: float = 0.0
var _shake_time: float = 0.0
var _shake_off: Vector3 = Vector3.ZERO

var _interp_fraction: float = 0.0
var _last_render_target: Vector3 = Vector3.ZERO
var _has_render_target: bool = false

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D


func _ready() -> void:
	top_level = true
	# Critical: rig moves every render frame in _process() — engine FTI
	# must be OFF on this subtree (children inherit OFF).
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	process_physics_priority = 100
	process_priority = 100
	VehicleInputMap.ensure_actions()
	_configure_spring_arm()
	if target_vehicle != null:
		_sync_excluded_vehicle()
		snap_immediately()
	elif not target_vehicle_path.is_empty():
		var node := get_node_or_null(target_vehicle_path)
		if node is SaipaVehicleController:
			bind_vehicle(node as SaipaVehicleController)


func _configure_spring_arm() -> void:
	if spring_arm == null:
		return
	# Prevent SpringArm3D from asynchronously overwriting camera.position.z
	# at 60 Hz while _process() eases speed-dependent follow distance at
	# display refresh rate.
	spring_arm.set_physics_process_internal(false)
	spring_arm.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if camera != null:
		camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _sync_excluded_vehicle() -> void:
	_excluded_rids.clear()
	if target_vehicle != null:
		var rid := target_vehicle.get_rid()
		if rid.is_valid():
			_excluded_rids.append(rid)
		if spring_arm != null:
			spring_arm.clear_excluded_objects()
			if rid.is_valid():
				spring_arm.add_excluded_object(rid)


func bind_vehicle(vehicle: SaipaVehicleController) -> void:
	if target_vehicle != null and target_vehicle.vehicle_reset_completed.is_connected(_on_vehicle_reset):
		target_vehicle.vehicle_reset_completed.disconnect(_on_vehicle_reset)
	target_vehicle = vehicle
	if target_vehicle != null:
		if not target_vehicle.vehicle_reset_completed.is_connected(_on_vehicle_reset):
			target_vehicle.vehicle_reset_completed.connect(_on_vehicle_reset)
		_sync_excluded_vehicle()
		if spring_arm != null:
			snap_immediately()


func get_mode_label() -> String:
	return "FOLLOW"


func get_persian_mode_label() -> String:
	return "دنبال‌کنندهٔ آزاد"


func add_shake(strength: float) -> void:
	_trauma = clampf(_trauma + strength, 0.0, 1.0)


func _extract_flat_yaw(xform: Transform3D, fallback_yaw: float = 0.0) -> float:
	var flat_fwd := Vector3(xform.basis.z.x, 0.0, xform.basis.z.z)
	if flat_fwd.length_squared() < 0.001:
		return fallback_yaw
	flat_fwd = flat_fwd.normalized()
	return atan2(flat_fwd.x, flat_fwd.z)


func _compute_arm_vector(yaw_rad: float, dist: float, height: float) -> Vector3:
	var back_dir := -Vector3(sin(yaw_rad), 0.0, cos(yaw_rad))
	return back_dir * dist + Vector3(0.0, height - look_target_height_m, 0.0)


func snap_immediately() -> void:
	if target_vehicle == null:
		return
	var xform := target_vehicle.global_transform
	var pivot := xform.origin + Vector3(0.0, look_target_height_m, 0.0)
	_smoothed_pivot_pos = pivot
	_vertical_offset = 0.0
	_last_render_target = pivot
	_has_render_target = true
	_smoothed_yaw_rad = _extract_flat_yaw(xform, _smoothed_yaw_rad)
	_eff_distance = follow_distance_m
	_eff_height = follow_height_m
	_eff_fov = base_fov_deg
	var arm_vec := _compute_arm_vector(_smoothed_yaw_rad, _eff_distance, _eff_height)
	_desired_arm_len = maxf(arm_vec.length(), 0.5)
	_current_arm_len = _desired_arm_len
	_wall_clearance_len = INF
	_trauma = 0.0
	_shake_off = Vector3.ZERO
	_initialized = true
	if camera != null:
		camera.fov = _eff_fov
		camera.rotation = Vector3.ZERO
	reset_physics_interpolation()
	_apply_transforms()


func _on_vehicle_reset(_new_tf: Transform3D) -> void:
	snap_immediately()


func _physics_process(_delta: float) -> void:
	# K2-REDESIGN-002: R3-stick / C key camera reset action.
	if Input.is_action_just_pressed("camera_reset"):
		snap_immediately()
	if target_vehicle == null or spring_arm == null or not is_inside_tree():
		return
	if spring_arm.is_physics_processing_internal():
		spring_arm.set_physics_process_internal(false)
	if not _initialized:
		snap_immediately()
		return
	_update_wall_clearance()
	# B8 regression fix (phase9 follow_camera_converges_at_speed,
	# lag 2.104 m): the rig transform was only ever written in
	# _process(), which runs once per render iteration, while physics
	# can advance several ticks in the same iteration. On slow
	# renderers (and in the test harness, which measures right after
	# the process_frame signal, before _process) the rig was left
	# multiple ticks behind the car. Apply the transform with the
	# physics pose every tick as a floor: at normal frame rates the
	# very next _process() overwrites it with the interpolated
	# rendered pose, so shipped visuals are unchanged. NOTE: this must
	# NOT write _smoothed_pivot_pos — that is the render-frame state
	# the diagnostics measure pivot_error_m against (writing it here
	# broke test_camera_lag, mean error 1.106 m).
	_apply_transforms(target_vehicle.global_position + Vector3(0.0, look_target_height_m, 0.0))


## Runs a single sphere sweep in physics space matching SpringArm3D's shape
## and margin, so wall collision never fights display-rate distance easing.
func _update_wall_clearance() -> void:
	var world := get_world_3d()
	if world == null:
		_wall_clearance_len = INF
		return
	var space_state := world.direct_space_state
	if space_state == null:
		_wall_clearance_len = INF
		return
	var arm_vec := _compute_arm_vector(_smoothed_yaw_rad, _eff_distance, _eff_height)
	var arm_len := maxf(arm_vec.length(), 0.5)
	var origin := target_vehicle.global_position + Vector3(0.0, look_target_height_m, 0.0)

	if _excluded_rids.is_empty():
		_sync_excluded_vehicle()

	if spring_arm.shape != null:
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = spring_arm.shape
		query.transform = Transform3D(Basis.IDENTITY, origin)
		query.motion = arm_vec
		query.collision_mask = spring_arm.collision_mask
		query.exclude = _excluded_rids
		var hit := space_state.cast_motion(query)
		if hit.size() >= 1 and hit[0] < 1.0:
			_wall_clearance_len = maxf(arm_len * hit[0] - spring_arm.margin, 0.5)
		else:
			_wall_clearance_len = INF
	else:
		var ray := PhysicsRayQueryParameters3D.create(origin, origin + arm_vec, spring_arm.collision_mask, _excluded_rids)
		var res := space_state.intersect_ray(ray)
		if not res.is_empty():
			var hit_pos: Vector3 = res["position"]
			_wall_clearance_len = maxf(origin.distance_to(hit_pos) - spring_arm.margin, 0.5)
		else:
			_wall_clearance_len = INF


func _process(delta: float) -> void:
	if target_vehicle == null or camera == null or spring_arm == null:
		return
	if not target_vehicle.is_inside_tree():
		return
	if not _initialized:
		snap_immediately()
		return
	if not camera.current:
		camera.make_current()
	var d := clampf(delta, 0.0005, 0.05)

	# --- Exact rendered vehicle pose (single clock with engine FTI) ---
	_interp_fraction = Engine.get_physics_interpolation_fraction()
	var render_xform := target_vehicle.get_global_transform_interpolated()
	var render_pivot := render_xform.origin + Vector3(0.0, look_target_height_m, 0.0)
	var render_yaw := _extract_flat_yaw(render_xform, _smoothed_yaw_rad)
	_last_render_target = render_pivot
	_has_render_target = true

	# --- Speed-sensitive framing (eased smoothly at display rate) -----
	var speed_kmh := target_vehicle.current_speed_kmh
	var speed_ratio := clampf(speed_kmh / maxf(target_vehicle.max_forward_speed_kmh, 1.0), 0.0, 1.0)
	var dist_target := lerpf(follow_distance_m, follow_distance_m * (7.4 / 5.2), speed_ratio)
	var height_target := lerpf(follow_height_m, follow_height_m + 0.4, speed_ratio)
	var fov_target := base_fov_deg + 13.0 * speed_ratio
	var ease_a := 1.0 - exp(-3.0 * d)
	_eff_distance = lerpf(_eff_distance, dist_target, ease_a)
	_eff_height = lerpf(_eff_height, height_target, ease_a)
	_eff_fov = lerpf(_eff_fov, fov_target, ease_a)
	camera.fov = _eff_fov

	# --- Pivot position: phase-locked X/Z + gentle vertical filtering -
	# Locking X/Z directly to the engine's interpolated car pose gives
	# zero longitudinal rubber-banding and zero crash overshoot, while
	# a tightly clamped vertical lag filters tiny suspension chatter.
	var prev_y := _smoothed_pivot_pos.y
	var target_y := render_pivot.y
	var y_alpha := 1.0 - exp(-maxf(smooth_pos_rate, 8.0) * d)
	var filtered_y := lerpf(prev_y, target_y, y_alpha)
	_vertical_offset = clampf(filtered_y - target_y, -0.08, 0.08)
	_smoothed_pivot_pos = Vector3(render_pivot.x, target_y + _vertical_offset, render_pivot.z)

	# --- Rotation: exponential + look-INTO-the-corner (max 8 deg) -----
	# In VehicleBody3D (+Z forward, +X left), smoothed_steer_rad > 0 is
	# LEFT (+yaw) and < 0 is RIGHT (-yaw) — same sign as atan2(fwd.x, fwd.z).
	var max_steer_rad := maxf(deg_to_rad(target_vehicle.max_steer_angle_low_speed_deg), 0.01)
	var steer_norm := clampf(target_vehicle.smoothed_steer_rad / max_steer_rad, -1.0, 1.0)
	var corner_scale := clampf(target_vehicle.forward_speed_mps * 3.6 / 60.0, 0.0, 1.0)
	var corner_yaw := render_yaw + steer_norm * deg_to_rad(8.0) * corner_scale
	var rot_alpha := 1.0 - exp(-smooth_yaw_rate * d)
	_smoothed_yaw_rad = lerp_angle(_smoothed_yaw_rad, corner_yaw, rot_alpha)

	# --- Wall-safe arm length (instant pull-in, smooth release) -------
	var arm_vec := _compute_arm_vector(_smoothed_yaw_rad, _eff_distance, _eff_height)
	_desired_arm_len = maxf(arm_vec.length(), 0.5)
	var allowed_len := minf(_desired_arm_len, _wall_clearance_len)
	if allowed_len < _current_arm_len:
		_current_arm_len = allowed_len
	else:
		var release_alpha := 1.0 - exp(-8.0 * d)
		_current_arm_len = lerpf(_current_arm_len, allowed_len, release_alpha)
		if is_inf(_wall_clearance_len) and absf(_current_arm_len - _desired_arm_len) < 0.002:
			_current_arm_len = _desired_arm_len

	# --- Shake (trauma^2, scaled by shake_amount, clamped) ------------
	_shake_time += d
	_trauma = maxf(_trauma - d * 1.6, 0.0)
	var shake_mag := shake_amount * _trauma * _trauma
	_shake_off = Vector3(
		sin(_shake_time * 67.0) * 0.05,
		sin(_shake_time * 83.0 + 1.7) * 0.04,
		sin(_shake_time * 59.0 + 0.6) * 0.03) * shake_mag
	camera.rotation = Vector3(0.0, 0.0, sin(_shake_time * 71.0) * 0.02 * shake_mag)

	_apply_transforms()


func _apply_transforms(pivot_override: Vector3 = Vector3.INF) -> void:
	if camera == null or spring_arm == null:
		return
	var pivot := (pivot_override if not is_inf(pivot_override.x) else _smoothed_pivot_pos) + _shake_off
	global_position = pivot
	var arm_vec := _compute_arm_vector(_smoothed_yaw_rad, _eff_distance, _eff_height)
	var arm_len := maxf(arm_vec.length(), 0.5)
	var forward_neg_z := -(arm_vec / arm_len)
	spring_arm.spring_length = arm_len
	spring_arm.global_transform = Transform3D(Basis.looking_at(forward_neg_z, Vector3.UP), pivot)
	camera.position = Vector3(0.0, 0.0, _current_arm_len)


func get_camera_diagnostics() -> Dictionary:
	var target_pos := Vector3.ZERO
	var yaw_error_deg := 0.0
	if target_vehicle != null:
		target_pos = target_vehicle.global_position
		var fwd := target_vehicle.global_transform.basis.z
		yaw_error_deg = rad_to_deg(angle_difference(_smoothed_yaw_rad, atan2(fwd.x, fwd.z)))
	var render_ref := _last_render_target if _has_render_target else (target_pos + Vector3(0.0, look_target_height_m, 0.0))
	var tick_ms := 1000.0 / maxf(float(Engine.physics_ticks_per_second), 1.0)
	return {
		"mode": get_mode_label(),
		"mode_fa": get_persian_mode_label(),
		"active_camera": camera.name if camera != null else "<none>",
		"is_current": camera != null and camera.current,
		"target_pos": target_pos,
		"pivot_pos": _smoothed_pivot_pos,
		"pivot_error_m": (_smoothed_pivot_pos - render_ref).length(),
		"physics_pose_error_m": (_smoothed_pivot_pos - (target_pos + Vector3(0.0, look_target_height_m, 0.0))).length(),
		"render_delay_ms": (1.0 - _interp_fraction) * tick_ms,
		"yaw_error_deg": yaw_error_deg,
		"fov": camera.fov if camera != null else 0.0,
		"spring_length": _current_arm_len,
		"smooth_yaw_rate": smooth_yaw_rate,
		"smooth_pos_rate": smooth_pos_rate,
		"distance_eff": _eff_distance,
		"height_eff": _eff_height,
		"trauma": _trauma,
		"shake_amount": shake_amount,
	}
