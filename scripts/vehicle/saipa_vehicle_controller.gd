class_name SaipaVehicleController
extends VehicleBody3D

## Production Godot 4.7 (Jolt Physics) controller for the Sport Pride (Saipa/Kia Pride Tuning)
## vehicle imported from sport_pride.zip (12WpIbCYEXizSI5hXNgRenHnaEH6ZEn_1).
## Built on VehicleBody3D + 4 VehicleWheel3D after empirical verification in Godot 4.7.2:
## - Local forward: +Z (Vector3.MODEL_FRONT), Left: +X, Up: +Y
## - Geometry-extracted wheelbase: 2.6693 m, front track: 1.7754 m, rear track: 1.8047 m, wheel radius: 0.3032 m
## - Visual wheels use dedicated right-handed Node3D transforms (det=+1) synchronized from
##   VehicleWheel3D contact/suspension/RPM/steering state to avoid VehicleWheel3D's internal det=-1 basis flip.

signal vehicle_reset_completed(new_transform: Transform3D)
## F4 (K2-REDESIGN-001): emitted on hard contacts; strength ~ impulse/100.
signal impact_detected(strength: float)

enum GearState {
	NEUTRAL = 0,
	DRIVE = 1,
	REVERSE = 2,
}

@export_group("Vehicle Identity & Camera Anchors")
@export var vehicle_id: String = "sport_pride"
@export var vehicle_name_fa: String = "پراید اسپرت"

@export_group("Mass & Center of Mass")
@export_range(500.0, 2500.0, 10.0) var vehicle_mass_kg: float = 950.0
@export var center_of_mass_local: Vector3 = Vector3(0.0, 0.20, 0.08)

@export_group("Powertrain & Brakes")
@export_range(500.0, 8000.0, 50.0) var max_engine_force_n: float = 2650.0
@export_range(300.0, 5000.0, 50.0) var max_reverse_force_n: float = 1550.0
@export_range(60.0, 260.0, 5.0) var max_forward_speed_kmh: float = 165.0
@export_range(15.0, 60.0, 1.0) var max_reverse_speed_kmh: float = 36.0
@export_range(5.0, 150.0, 1.0) var service_brake_force: float = 68.0
@export_range(10.0, 200.0, 1.0) var handbrake_rear_force: float = 85.0
@export_range(0.0, 15.0, 0.2) var coast_engine_drag_brake: float = 1.8

@export_group("Steering")
@export_range(15.0, 45.0, 0.5) var max_steer_angle_low_speed_deg: float = 31.0
@export_range(4.0, 20.0, 0.5) var max_steer_angle_high_speed_deg: float = 9.5
@export_range(40.0, 160.0, 5.0) var high_speed_steer_ref_kmh: float = 95.0
@export_range(2.0, 20.0, 0.5) var steer_response_rate: float = 8.0

@export_group("Suspension & Tires")
@export_range(0.20, 0.50, 0.001) var wheel_radius_m: float = 0.3032
@export_range(0.05, 0.30, 0.005) var suspension_rest_length_m: float = 0.12
@export_range(0.05, 0.35, 0.005) var suspension_travel_m: float = 0.16
@export_range(20.0, 120.0, 1.0) var suspension_stiffness: float = 58.0
@export_range(2000.0, 30000.0, 250.0) var suspension_max_force_n: float = 12000.0
@export_range(0.5, 10.0, 0.1) var damping_compression: float = 2.8
@export_range(0.5, 10.0, 0.1) var damping_relaxation: float = 3.6
@export_range(0.5, 5.0, 0.05) var front_tire_friction_slip: float = 1.92
@export_range(0.5, 5.0, 0.05) var rear_tire_friction_slip: float = 1.98
@export_range(0.0, 0.4, 0.01) var wheel_roll_influence: float = 0.03
@export_range(0.0, 8000.0, 100.0) var anti_roll_stiffness_nm: float = 2600.0

@export_group("Safety & Reset")
@export var auto_recover_rollover: bool = true
@export_range(1.0, 10.0, 0.5) var rollover_recover_delay_sec: float = 2.5

# External control state (touch UI & automated tests write here; combined with desktop InputMap)
## Post-integration body transforms, sampled in _integrate_forces.
## The camera rig reads these instead of global_transform so it never
## works from a one-tick-stale pose (K2-REDESIGN-002, defect D3).
var integrated_transform := Transform3D.IDENTITY
var prev_integrated_transform := Transform3D.IDENTITY

var touch_throttle: float = 0.0
var touch_brake_reverse: float = 0.0
var touch_steer: float = 0.0 # [-1.0 = right, +1.0 = left] or set via set_touch_controls()
var touch_handbrake: bool = false
# K2-FINAL-003: live values for EngineAudio (updated every physics tick).
# K2-FIX-004: engine_rpm_norm now comes from a real RPM model (below),
# not from road speed — the speed-derived value pinned the pitch near
# redline at any cruise speed and could not flare at launch.
var engine_rpm_norm: float = 0.0
var engine_throttle: float = 0.0
## K2-FIX-004 engine model state.
const ENGINE_IDLE_RPM := 950.0
const ENGINE_REDLINE_RPM := 6300.0
const GEAR_TOP_FRACTIONS: Array[float] = [0.20, 0.34, 0.48, 0.63, 0.82, 1.18]
var engine_gear: int = 1
var _engine_rpm: float = ENGINE_IDLE_RPM
var _shift_timer: float = 0.0
var external_override_active: bool = false
var read_desktop_input: bool = true

# Runtime telemetry
var gear_state: GearState = GearState.DRIVE
var current_speed_kmh: float = 0.0
var forward_speed_mps: float = 0.0
var smoothed_steer_rad: float = 0.0
var active_surface_grip: float = 1.0
var _spawn_transform: Transform3D = Transform3D.IDENTITY
var _upside_down_timer: float = 0.0
var _braking_lights_on: bool = false
var _wheel_spin_rad: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0, 0.0])

@onready var wheel_fl: VehicleWheel3D = $WheelFL
@onready var wheel_fr: VehicleWheel3D = $WheelFR
@onready var wheel_rl: VehicleWheel3D = $WheelRL
@onready var wheel_rr: VehicleWheel3D = $WheelRR

@onready var vis_wheel_fl: Node3D = $VisualWheels/VisWheelFL
@onready var vis_wheel_fr: Node3D = $VisualWheels/VisWheelFR
@onready var vis_wheel_rl: Node3D = $VisualWheels/VisWheelRL
@onready var vis_wheel_rr: Node3D = $VisualWheels/VisWheelRR
@onready var visual_model: SaipaVisualModel = get_node_or_null("SaipaPrideVisual") as SaipaVisualModel


var _wheel_mesh_instances: Array[MeshInstance3D] = []
var _phys_wheels: Array[VehicleWheel3D] = []
var _vis_wheels: Array[Node3D] = []


func _ready() -> void:
	VehicleInputMap.ensure_actions()
	contact_monitor = true
	max_contacts_reported = 8
	_spawn_transform = global_transform
	_phys_wheels = [wheel_fl, wheel_fr, wheel_rl, wheel_rr]
	_vis_wheels = [vis_wheel_fl, vis_wheel_fr, vis_wheel_rl, vis_wheel_rr]
	if visual_model == null:
		for ch in get_children():
			if ch is SaipaVisualModel:
				visual_model = ch as SaipaVisualModel
				break
	if visual_model != null:
		visual_model.enable_runtime_static_batching()
	_share_wheel_materials()
	apply_tuning_parameters()
	_sync_visual_wheels(0.0)


func _share_wheel_materials() -> void:
	_wheel_mesh_instances.clear()
	var shared_by_name: Dictionary = {}
	for vw: Node3D in _vis_wheels:
		if vw == null:
			continue
		var stack: Array[Node] = [vw]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			if n is MeshInstance3D:
				var mi := n as MeshInstance3D
				_wheel_mesh_instances.append(mi)
				if mi.mesh != null:
					for s_idx in range(mi.mesh.get_surface_count()):
						var mat := mi.get_active_material(s_idx)
						if mat != null:
							var key := mat.resource_name if not mat.resource_name.is_empty() else str(mat.get_instance_id())
							if not shared_by_name.has(key):
								shared_by_name[key] = mat
							mi.set_surface_override_material(s_idx, shared_by_name[key])
			for ch in n.get_children():
				stack.append(ch)


func toggle_headlights() -> void:
	if visual_model != null:
		visual_model.headlights_enabled = not visual_model.headlights_enabled


func are_headlights_on() -> bool:
	return visual_model != null and visual_model.headlights_enabled


func set_graphics_quality_tier(tier: int) -> void:
	if visual_model != null:
		visual_model.set_vehicle_lod_tier(tier)
	var cast_mode := GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if tier == 0 else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for wmi in _wheel_mesh_instances:
		if wmi != null:
			wmi.cast_shadow = cast_mode


func set_spawn_transform(t: Transform3D) -> void:
	_spawn_transform = t


## Applies all @export vehicle parameters to VehicleBody3D and its 4 VehicleWheel3D nodes.
func apply_tuning_parameters() -> void:
	mass = vehicle_mass_kg
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = center_of_mass_local
	continuous_cd = true
	can_sleep = false

	var wheels := get_physics_wheels()
	for i in range(wheels.size()):
		var w := wheels[i]
		if w == null:
			continue
		var is_front := (i < 2)
		w.wheel_radius = wheel_radius_m
		w.wheel_rest_length = suspension_rest_length_m
		w.suspension_travel = suspension_travel_m
		w.suspension_stiffness = suspension_stiffness
		w.suspension_max_force = suspension_max_force_n
		w.damping_compression = damping_compression
		w.damping_relaxation = damping_relaxation
		w.wheel_roll_influence = wheel_roll_influence
		w.wheel_friction_slip = front_tire_friction_slip if is_front else rear_tire_friction_slip
		w.use_as_traction = is_front
		w.use_as_steering = is_front


func get_physics_wheels() -> Array[VehicleWheel3D]:
	if _phys_wheels.is_empty():
		_phys_wheels = [wheel_fl, wheel_fr, wheel_rl, wheel_rr]
	return _phys_wheels


## Clean API for Android touch controls or automated physics test suites.
## steer_right_positive: -1.0 = full left, +1.0 = full right (standard UI convention).
func set_control_inputs(throttle_in: float, brake_rev_in: float, steer_right_positive: float, handbrake_in: bool = false) -> void:
	external_override_active = true
	touch_throttle = clampf(throttle_in, 0.0, 1.0)
	touch_brake_reverse = clampf(brake_rev_in, 0.0, 1.0)
	touch_steer = clampf(steer_right_positive, -1.0, 1.0)
	touch_handbrake = handbrake_in


func clear_external_inputs() -> void:
	external_override_active = false
	touch_throttle = 0.0
	touch_brake_reverse = 0.0
	touch_steer = 0.0
	touch_handbrake = false


func _physics_process(delta: float) -> void:
	# K2-DEEP-005 safety net: never fall forever. With the grass safety
	# floor this should be unreachable in normal play, but any physics
	# edge case that gets the car under the world recovers to spawn.
	if global_position.y < -8.0:
		reset_vehicle()
		return
	if read_desktop_input and Input.is_action_just_pressed("reset_vehicle"):
		reset_vehicle(_spawn_transform)
		return
	if read_desktop_input and Input.is_action_just_pressed("toggle_headlights"):
		toggle_headlights()

	var forward_dir := global_transform.basis.z.normalized()
	forward_speed_mps = linear_velocity.dot(forward_dir)
	current_speed_kmh = linear_velocity.length() * 3.6

	# Gather combined keyboard + gamepad + touch inputs.
	# K2-FINAL-003 merge policy (fixed, documented in GAMEPAD.md):
	# pedals take the MAX across sources, steering takes the LARGEST
	# ABSOLUTE value, handbrake is OR. Sources can therefore never
	# stack past their range, fight each other, or double-apply;
	# whichever source the driver pushes hardest wins, deterministically.
	var raw_throttle := 0.0
	var raw_brake_rev := 0.0
	var raw_steer_right_pos := 0.0
	var raw_handbrake := false

	if read_desktop_input:
		raw_throttle = Input.get_action_strength("throttle")
		raw_brake_rev = Input.get_action_strength("brake_reverse")
		raw_steer_right_pos = Input.get_action_strength("steer_right") - Input.get_action_strength("steer_left")
		raw_handbrake = Input.is_action_pressed("handbrake")

	# K2-REDESIGN-002: analog gamepad axes (progressive steering,
	# normalised triggers) merge with keyboard strengths.
	if read_desktop_input and not Input.get_connected_joypads().is_empty():
		raw_throttle = maxf(raw_throttle, VehicleInputMap.joy_throttle_value())
		raw_brake_rev = maxf(raw_brake_rev, VehicleInputMap.joy_brake_value())
		var j_steer := VehicleInputMap.joy_steer_axis()
		if absf(j_steer) > absf(raw_steer_right_pos):
			raw_steer_right_pos = j_steer
	if external_override_active or touch_throttle > 0.0 or touch_brake_reverse > 0.0 or absf(touch_steer) > 0.001 or touch_handbrake:
		raw_throttle = maxf(raw_throttle, touch_throttle)
		raw_brake_rev = maxf(raw_brake_rev, touch_brake_reverse)
		if absf(touch_steer) > absf(raw_steer_right_pos):
			raw_steer_right_pos = touch_steer
		raw_handbrake = raw_handbrake or touch_handbrake
	engine_throttle = raw_throttle

	_update_surface_friction_and_anti_roll(raw_handbrake)
	_update_steering(raw_steer_right_pos, delta)
	_update_powertrain_and_brakes(raw_throttle, raw_brake_rev, raw_handbrake)
	_check_rollover_safety(delta)
	_sync_visual_wheels(delta)
	_update_engine_rpm(delta)
	_sync_cockpit_visuals()


func _update_steering(steer_right_positive: float, delta: float) -> void:
	# Speed-sensitive steering limit: full lock at 0 km/h, smoothly reduced at highway speeds
	var speed_t := clampf(current_speed_kmh / maxf(high_speed_steer_ref_kmh, 1.0), 0.0, 1.0)
	var max_deg := lerpf(max_steer_angle_low_speed_deg, max_steer_angle_high_speed_deg, speed_t)
	# In Godot VehicleBody3D (+Z forward, +X left), positive steering turns LEFT (+X)
	var target_steer_rad := -clampf(steer_right_positive, -1.0, 1.0) * deg_to_rad(max_deg)
	var alpha := 1.0 - exp(-steer_response_rate * delta)
	smoothed_steer_rad = lerpf(smoothed_steer_rad, target_steer_rad, alpha)
	steering = smoothed_steer_rad


func _update_powertrain_and_brakes(throttle_in: float, brake_rev_in: float, handbrake_in: bool) -> void:
	var target_engine := 0.0
	var target_service_brake := 0.0
	_braking_lights_on = false

	if gear_state == GearState.REVERSE:
		if throttle_in > 0.05:
			if forward_speed_mps < -0.8:
				# Braking while reversing
				target_service_brake = throttle_in * service_brake_force
				_braking_lights_on = true
			else:
				gear_state = GearState.DRIVE
		elif brake_rev_in > 0.05:
			# Driving in reverse with smooth speed governor
			var rev_kmh := maxf(0.0, -forward_speed_mps * 3.6)
			var rev_taper := clampf(1.0 - (rev_kmh / maxf(max_reverse_speed_kmh, 1.0)), 0.0, 1.0)
			target_engine = -brake_rev_in * max_reverse_force_n * rev_taper
		else:
			if absf(forward_speed_mps) < 0.35:
				gear_state = GearState.NEUTRAL
			else:
				target_service_brake = coast_engine_drag_brake

	if gear_state != GearState.REVERSE:
		if brake_rev_in > 0.05 and throttle_in < 0.05:
			if forward_speed_mps > 0.9:
				# Service braking while moving forward
				gear_state = GearState.DRIVE
				target_service_brake = brake_rev_in * service_brake_force
				_braking_lights_on = true
			else:
				# Transition cleanly into Reverse once nearly stopped
				gear_state = GearState.REVERSE
				var rev_kmh := maxf(0.0, -forward_speed_mps * 3.6)
				var rev_taper := clampf(1.0 - (rev_kmh / maxf(max_reverse_speed_kmh, 1.0)), 0.0, 1.0)
				target_engine = -brake_rev_in * max_reverse_force_n * rev_taper
		elif throttle_in > 0.02:
			gear_state = GearState.DRIVE
			var fwd_kmh := maxf(0.0, forward_speed_mps * 3.6)
			var torque_taper := clampf(1.0 - pow(fwd_kmh / maxf(max_forward_speed_kmh, 1.0), 2.0), 0.0, 1.0)
			target_engine = throttle_in * max_engine_force_n * torque_taper
			if brake_rev_in > 0.05:
				target_service_brake = brake_rev_in * service_brake_force
				_braking_lights_on = true
		else:
			if absf(forward_speed_mps) < 0.25:
				gear_state = GearState.NEUTRAL
				target_service_brake = 3.5 # Gentle parking hold on flat ground
			else:
				target_service_brake = coast_engine_drag_brake

	engine_force = target_engine
	brake = target_service_brake

	# Apply extra rear-wheel handbrake lock when requested
	if wheel_rl != null and wheel_rr != null:
		if handbrake_in:
			wheel_rl.brake = maxf(target_service_brake, handbrake_rear_force)
			wheel_rr.brake = maxf(target_service_brake, handbrake_rear_force)
			_braking_lights_on = true
		else:
			wheel_rl.brake = 0.0
			wheel_rr.brake = 0.0


func _update_surface_friction_and_anti_roll(handbrake_in: bool) -> void:
	var wheels := get_physics_wheels()
	var grip_sum := 0.0
	var grip_count := 0

	for i in range(wheels.size()):
		var w := wheels[i]
		if w == null:
			continue
		var is_front := (i < 2)
		var base_slip := front_tire_friction_slip if is_front else rear_tire_friction_slip
		var surf_mult := 1.0
		if w.is_in_contact():
			var cbody := w.get_contact_body()
			if cbody != null and cbody.has_meta("surface_grip"):
				surf_mult = clampf(float(cbody.get_meta("surface_grip")), 0.15, 2.0)
			grip_sum += surf_mult
			grip_count += 1
		if not is_front and handbrake_in:
			surf_mult *= 0.76
		w.wheel_friction_slip = base_slip * surf_mult

	active_surface_grip = (grip_sum / float(grip_count)) if grip_count > 0 else 1.0

	# Proportional front & rear anti-roll bar torque around local forward (+Z) axis
	if anti_roll_stiffness_nm > 0.0:
		var fl_travel := _get_wheel_compression(wheel_fl)
		var fr_travel := _get_wheel_compression(wheel_fr)
		var rl_travel := _get_wheel_compression(wheel_rl)
		var rr_travel := _get_wheel_compression(wheel_rr)
		var roll_diff := (fl_travel - fr_travel) + (rl_travel - rr_travel)
		if absf(roll_diff) > 0.0005:
			# Positive roll_diff means left side compressed more -> apply restoring torque around +Z
			apply_torque(global_transform.basis.z * (-roll_diff * anti_roll_stiffness_nm))


func _get_wheel_compression(w: VehicleWheel3D) -> float:
	if w == null or not w.is_in_contact():
		return 0.0
	var contact_local := to_local(w.get_contact_point())
	var mount_y := w.position.y
	var current_len := mount_y - (contact_local.y + wheel_radius_m)
	return clampf(suspension_rest_length_m - current_len, -suspension_travel_m, suspension_travel_m)


func _sync_visual_wheels(delta: float) -> void:
	var phys_wheels := get_physics_wheels()
	if _vis_wheels.is_empty():
		_vis_wheels = [vis_wheel_fl, vis_wheel_fr, vis_wheel_rl, vis_wheel_rr]
	var min_wy := wheel_radius_m - 0.0932
	var max_wy := wheel_radius_m + 0.0868

	for i in range(4):
		var pw: VehicleWheel3D = phys_wheels[i]
		var vw: Node3D = _vis_wheels[i]
		if pw == null or vw == null:
			continue
		var is_left := (i == 0 or i == 2)
		var is_front := (i < 2)

		# Position: follow exact contact point + normal*radius when grounded, else VehicleWheel3D center
		var wheel_local_pos := pw.position
		if pw.is_in_contact():
			var world_center := pw.get_contact_point() + global_transform.basis.y.normalized() * wheel_radius_m
			wheel_local_pos = to_local(world_center)
			# Keep lateral X and longitudinal Z locked to hub axis so tire never drifts sideways
			wheel_local_pos.x = pw.position.x
			wheel_local_pos.z = pw.position.z
			wheel_local_pos.y = clampf(wheel_local_pos.y, min_wy, max_wy)
		else:
			wheel_local_pos.y = clampf(pw.position.y, min_wy, max_wy)
		vw.position = wheel_local_pos

		# Spin integration from wheel RPM (+Z forward -> positive rotation around +X rolls top toward +Z)
		if delta > 0.0:
			var omega_rad_s := (pw.get_rpm() * TAU) / 60.0
			_wheel_spin_rad[i] = wrapf(_wheel_spin_rad[i] + omega_rad_s * delta, -TAU, TAU)

		var steer_yaw := smoothed_steer_rad if is_front else 0.0
		var side_flip := PI if is_left else 0.0
		# Right-handed basis (det = +1): Steer around Y -> Spin around X -> Flip 180 deg around Y for left wheels
		var b_steer := Basis(Vector3.UP, steer_yaw)
		var b_spin := Basis(Vector3.RIGHT, _wheel_spin_rad[i])
		var b_side := Basis(Vector3.UP, side_flip)
		vw.transform.basis = b_steer * b_spin * b_side


## K2-FIX-004: real engine RPM model. RPM is locked to wheel speed
## within the current gear (with hysteresis gear selection and a tall
## top gear, so highway cruise sits mid-range instead of near
## redline), flares under throttle at launch / standstill (clutch
## slip), drops visibly on upshifts, and falls with road speed on
## lift-off (engine braking). Replaces the old speed-ratio formula
## that pinned the soundtrack near redline whenever the car moved.
func _update_engine_rpm(delta: float) -> void:
	var speed := absf(current_speed_kmh)
	var top := maxf(max_forward_speed_kmh, 1.0)
	_shift_timer = maxf(_shift_timer - delta, 0.0)
	if gear_state == GearState.DRIVE:
		while engine_gear < GEAR_TOP_FRACTIONS.size() and speed > GEAR_TOP_FRACTIONS[engine_gear - 1] * top:
			engine_gear += 1
			_shift_timer = 0.25
		while engine_gear > 1 and speed < GEAR_TOP_FRACTIONS[engine_gear - 2] * top * 0.88:
			engine_gear -= 1
	var gear_top := GEAR_TOP_FRACTIONS[engine_gear - 1] * top
	if gear_state == GearState.REVERSE:
		gear_top = GEAR_TOP_FRACTIONS[0] * top
	var in_gear := clampf(speed / maxf(gear_top, 1.0), 0.0, 1.0)
	var engaged := ENGINE_IDLE_RPM + (ENGINE_REDLINE_RPM - ENGINE_IDLE_RPM) * in_gear
	var target := engaged
	if engine_throttle > 0.05 and speed < 10.0 and gear_state == GearState.DRIVE:
		var flare := ENGINE_IDLE_RPM + (ENGINE_REDLINE_RPM - ENGINE_IDLE_RPM) * 0.88 * engine_throttle
		target = maxf(target, flare)
	var rate := 3400.0 if target > _engine_rpm else 2600.0
	if _shift_timer > 0.0 and target < _engine_rpm:
		rate = 6500.0 # crisp drop on upshift
	_engine_rpm = move_toward(_engine_rpm, target, rate * delta)
	engine_rpm_norm = clampf((_engine_rpm - ENGINE_IDLE_RPM) / (ENGINE_REDLINE_RPM - ENGINE_IDLE_RPM), 0.0, 1.0)


func _sync_cockpit_visuals() -> void:
	if visual_model == null:
		return
	var max_rad := deg_to_rad(max_steer_angle_low_speed_deg)
	var steer_norm := clampf(-smoothed_steer_rad / maxf(max_rad, 0.01), -1.0, 1.0)
	visual_model.update_cockpit_Telemetry(steer_norm, current_speed_kmh, engine_rpm_norm, _braking_lights_on)


func _check_rollover_safety(delta: float) -> void:
	if not auto_recover_rollover:
		return
	var up_dot := global_transform.basis.y.normalized().dot(Vector3.UP)
	if up_dot < 0.25 and current_speed_kmh < 5.0:
		_upside_down_timer += delta
		if _upside_down_timer >= rollover_recover_delay_sec:
			_upside_down_timer = 0.0
			# Recover upright slightly above current horizontal spot
			var flat_fwd := Vector3(global_transform.basis.z.x, 0.0, global_transform.basis.z.z)
			if flat_fwd.length_squared() < 0.01:
				flat_fwd = Vector3.MODEL_FRONT
			flat_fwd = flat_fwd.normalized()
			var right_vec := Vector3.UP.cross(flat_fwd).normalized()
			var rec_basis := Basis(right_vec, Vector3.UP, flat_fwd)
			var rec_pos := Vector3(global_position.x, maxf(global_position.y, 0.0) + 0.35, global_position.z)
			reset_vehicle(Transform3D(rec_basis, rec_pos))
	else:
		_upside_down_timer = 0.0


## Physics-safe vehicle reset: clears linear/angular velocities, wheel forces, and steering,
## and synchronizes both SceneTree transform and PhysicsServer3D Jolt body state.
func reset_vehicle(target_transform: Transform3D = _spawn_transform) -> void:
	clear_external_inputs()
	engine_force = 0.0
	brake = 0.0
	steering = 0.0
	smoothed_steer_rad = 0.0
	gear_state = GearState.DRIVE
	_upside_down_timer = 0.0
	_wheel_spin_rad = PackedFloat32Array([0.0, 0.0, 0.0, 0.0])

	if wheel_rl != null:
		wheel_rl.brake = 0.0
	if wheel_rr != null:
		wheel_rr.brake = 0.0

	global_transform = target_transform
	integrated_transform = target_transform
	prev_integrated_transform = target_transform
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	current_speed_kmh = 0.0
	forward_speed_mps = 0.0
	sleeping = false

	var rid := get_rid()
	if rid.is_valid():
		PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM, target_transform)
		PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO)
		PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)
		# K2-FIX-004: physics interpolation is enabled now — a teleport
		# must reset the interpolation state or the car would visibly
		# smear from the old pose to the spawn pose over one frame.
		reset_physics_interpolation()

	_sync_visual_wheels(0.0)
	_sync_cockpit_visuals()
	vehicle_reset_completed.emit(target_transform)


func get_gear_label() -> String:
	match gear_state:
		GearState.REVERSE:
			return "R"
		GearState.NEUTRAL:
			return "N"
		_:
			return "D"


func get_grounded_wheel_count() -> int:
	var c := 0
	for w in get_physics_wheels():
		if w != null and w.is_in_contact():
			c += 1
	return c


var _impact_cooldown: float = 0.0


## F4: read RigidBody contacts; a hard hit (impulse above threshold)
## notifies the HUD once per 0.35s at most.
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	prev_integrated_transform = integrated_transform
	integrated_transform = state.transform
	_impact_cooldown = maxf(_impact_cooldown - state.step, 0.0)
	if _impact_cooldown > 0.0:
		return
	var worst := 0.0
	for i in range(state.get_contact_count()):
		worst = maxf(worst, state.get_contact_impulse(i).length())
	if worst > 320.0:
		_impact_cooldown = 0.35
		impact_detected.emit(clampf(worst / 100.0, 1.0, 10.0))
