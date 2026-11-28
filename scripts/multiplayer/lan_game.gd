extends Node3D

## K2-FIX-004: LAN game scene — reconstruction of the original test
## build's LanGame (Node3D + EngineeredTestTrack + VehicleCameraRig +
## VehicleHud, vehicles named Player_<peer_id>), rebuilt on the
## current template's spawn/bind wiring.
##
## Sync model: each peer simulates ONLY its own car with full
## physics and streams its transform at 30 Hz with an
## unreliable_ordered RPC (the RPC flavour recovered from the
## original lan_session bytecode). The remote car is a frozen replica
## whose transform is interpolated toward the streamed states.
## Vehicle choice is exchanged with a reliable any_peer RPC and
## re-announced until both replicas exist (scene-entry race guard).
## Resets are mirrored with a reliable RPC.

const SLOT_OFFSET := 3.6

var _track: DesertCircuit
var _rig: VehicleCameraRig
var _hud: VehicleHud
var _local_car: SaipaVehicleController = null
var _remote_car: SaipaVehicleController = null
var _remote_target := Transform3D.IDENTITY
var _remote_has_state := false
var _remote_slot_tf := Transform3D.IDENTITY
var _remote_wheel_spin: float = 0.0
var _remote_prev_speed: float = 0.0
var _remote_steer_vis: float = 0.0
var _last_sync_msec: int = 0
var _outlier_count: int = 0
var _outlier_origin := Vector3.ZERO
var _partner_acked := false
var _own_idx := 0
var _tick := 0


func _ready() -> void:
	VehicleInputMap.ensure_actions()
	SettingsManager.ensure_loaded()
	_track = $EngineeredTestTrack
	_rig = $VehicleCameraRig
	_hud = $VehicleHud
	_own_idx = SettingsManager.selected_vehicle_index
	var own_id := multiplayer.get_unique_id()
	var own_slot := 0 if (own_id == 1) else 1
	_local_car = _spawn_car(_own_idx, own_slot, true)
	_local_car.name = "Player_%d" % own_id
	_rig.bind_vehicle(_local_car)
	_hud.bind_systems(_local_car, _rig, _track, self)
	_hud.apply_graphics_quality(SettingsManager.graphics_tier)
	SettingsManager.apply_to_systems(_hud, _rig)
	var am := get_node_or_null("/root/AudioManager")
	if am != null and am.has_method("play_driving_music"):
		am.call("play_driving_music", false)
	_local_car.vehicle_reset_completed.connect(_on_local_reset)
	if _session_active():
		rpc("_announce_vehicle", _own_idx)


func _exit_tree() -> void:
	# Leaving the LAN game for any reason ends the session cleanly.
	if LanSession.state == LanSession.State.IN_GAME:
		LanSession.close()


func _session_active() -> bool:
	return multiplayer.multiplayer_peer != null and LanSession.state == LanSession.State.IN_GAME


func _slot_transform(slot: int) -> Transform3D:
	var tf := _track.get_spawn_transform()
	var side := -0.5 * SLOT_OFFSET if slot == 0 else 0.5 * SLOT_OFFSET
	tf.origin += tf.basis.x * side
	return tf


func _spawn_car(idx: int, slot: int, is_local: bool) -> SaipaVehicleController:
	var entry := VehicleCatalog.get_entry(posmod(idx, VehicleCatalog.get_count()))
	var packed := load(str(entry["vehicle_scene"])) as PackedScene
	var car := packed.instantiate() as SaipaVehicleController
	add_child(car)
	var tf := _slot_transform(slot)
	car.set_spawn_transform(tf)
	car.set_graphics_quality_tier(SettingsManager.graphics_tier)
	car.reset_vehicle(tf)
	if is_local:
		var engine_audio := EngineAudio.new()
		engine_audio.name = "EngineAudio"
		car.add_child(engine_audio)
		engine_audio.configure(car, posmod(idx, VehicleCatalog.get_count()))
	else:
		# Replica: no local physics, no input, no engine sound; the
		# network stream drives its transform in _process, so disable
		# engine FTI to avoid double interpolation on the remote car.
		car.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		car.freeze = true
		car.set_physics_process(false)
		car.read_desktop_input = false
		car.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	return car


## K2-DEEP-005 basic hardening: the session has one active partner
## per match. RPCs from anyone else, malformed vehicle indices
## and non-finite / out-of-world / teleporting sync states are dropped.
func _is_partner(sender: int) -> bool:
	return sender != multiplayer.get_unique_id() and multiplayer.get_peers().has(sender)


@rpc("any_peer", "call_remote", "reliable")
func _ack_vehicle() -> void:
	if _is_partner(multiplayer.get_remote_sender_id()):
		_partner_acked = true


@rpc("any_peer", "call_remote", "reliable")
func _announce_vehicle(idx: int) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not _is_partner(sender):
		return
	if idx < 0 or idx >= VehicleCatalog.get_count():
		return
	# Always acknowledge so a slower-loading peer that missed our initial
	# announcements still learns we spawned its car and stops re-announcing.
	rpc_id(sender, "_ack_vehicle")
	if _remote_car != null:
		return
	var remote_slot := 0 if sender == 1 else 1
	_remote_slot_tf = _slot_transform(remote_slot)
	_remote_car = _spawn_car(idx, remote_slot, false)
	_remote_car.name = "Player_%d" % sender
	if _remote_has_state:
		_remote_car.global_transform = _remote_target
		_remote_car.reset_physics_interpolation()
	else:
		_remote_target = _remote_slot_tf


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _sync_state(tf: Transform3D) -> void:
	if not _is_partner(multiplayer.get_remote_sender_id()):
		return
	var clean_tf := tf.orthonormalized()
	var o := clean_tf.origin
	if not (is_finite(o.x) and is_finite(o.y) and is_finite(o.z)):
		return
	if absf(o.x) > 620.0 or absf(o.z) > 720.0 or o.y < -5.0 or o.y > 80.0:
		return
	var now_msec := Time.get_ticks_msec()
	if _remote_has_state:
		var elapsed := maxf(0.05, float(now_msec - _last_sync_msec) / 1000.0) if _last_sync_msec > 0 else 1.0
		var max_jump := maxf(24.0, 95.0 * elapsed)
		if o.distance_to(_remote_target.origin) > max_jump and o.distance_to(_remote_slot_tf.origin) > 2.5:
			# Recover after two consistent packets so a Wi-Fi stall or late scene entry
			# can never freeze the remote replica for the rest of the match.
			if _outlier_count >= 1 and o.distance_to(_outlier_origin) <= 18.0:
				_outlier_count = 0
			else:
				_outlier_origin = o
				_outlier_count += 1
				return
	_outlier_count = 0
	_last_sync_msec = now_msec
	_remote_target = clean_tf
	_remote_has_state = true


@rpc("any_peer", "call_remote", "reliable")
func _remote_reset() -> void:
	if not _is_partner(multiplayer.get_remote_sender_id()):
		return
	if _remote_car != null:
		_remote_car.global_transform = _remote_slot_tf
		_remote_car.reset_physics_interpolation()
		_remote_target = _remote_slot_tf
		_outlier_count = 0
		_last_sync_msec = Time.get_ticks_msec()
		_remote_prev_speed = 0.0
		_remote_steer_vis = 0.0


func _on_local_reset(_tf: Transform3D) -> void:
	if _session_active():
		rpc("_remote_reset")


func _physics_process(_delta: float) -> void:
	_tick += 1
	if _track != null and _local_car != null:
		_track.update_telemetry(_local_car)
	if not _session_active() or _local_car == null:
		return
	if not _partner_acked and _tick % 15 == 0:
		rpc("_announce_vehicle", _own_idx)
	if _tick % 2 == 0:
		rpc("_sync_state", _local_car.global_transform.orthonormalized())


func _process(delta: float) -> void:
	if _remote_car != null and _remote_has_state:
		var cur := _remote_car.global_transform.orthonormalized()
		var next_tf: Transform3D
		var snapped := false
		if cur.origin.distance_to(_remote_target.origin) > 8.0:
			next_tf = _remote_target # teleport/reset snap
			snapped = true
		else:
			var k := 1.0 - exp(-14.0 * delta)
			next_tf = cur.interpolate_with(_remote_target, k)
		_remote_car.global_transform = next_tf
		if snapped:
			_remote_car.reset_physics_interpolation()
			_remote_prev_speed = 0.0
			_remote_steer_vis = 0.0
		elif delta > 0.0005:
			_animate_remote_visuals(cur, next_tf, delta)


func _animate_remote_visuals(prev_tf: Transform3D, curr_tf: Transform3D, delta: float) -> void:
	if _remote_car == null:
		return
	var disp := curr_tf.origin - prev_tf.origin
	var fwd := curr_tf.basis.z.normalized()
	var fwd_disp := disp.dot(fwd)
	var speed_mps := fwd_disp / delta
	var radius := maxf(_remote_car.wheel_radius_m, 0.2)
	_remote_wheel_spin = wrapf(_remote_wheel_spin + fwd_disp / radius, -TAU, TAU)

	var prev_yaw := atan2(prev_tf.basis.z.x, prev_tf.basis.z.z)
	var curr_yaw := atan2(curr_tf.basis.z.x, curr_tf.basis.z.z)
	var yaw_rate := angle_difference(prev_yaw, curr_yaw) / delta
	var target_steer := clampf(yaw_rate * 0.35, -0.45, 0.45) if absf(speed_mps) > 0.5 else 0.0
	_remote_steer_vis = lerpf(_remote_steer_vis, target_steer, 1.0 - exp(-10.0 * delta))

	var vis_wheels := [_remote_car.vis_wheel_fl, _remote_car.vis_wheel_fr, _remote_car.vis_wheel_rl, _remote_car.vis_wheel_rr]
	for i in range(4):
		var vw: Node3D = vis_wheels[i]
		if vw == null:
			continue
		var is_left := (i == 0 or i == 2)
		var is_front := (i < 2)
		var b_steer := Basis(Vector3.UP, _remote_steer_vis if is_front else 0.0)
		var b_spin := Basis(Vector3.RIGHT, _remote_wheel_spin)
		var b_side := Basis(Vector3.UP, PI if is_left else 0.0)
		vw.transform.basis = b_steer * b_spin * b_side

	var braking := (_remote_prev_speed - speed_mps) / delta > 3.5 and speed_mps > 0.8
	_remote_prev_speed = speed_mps
	if _remote_car.visual_model != null:
		_remote_car.visual_model.update_cockpit_Telemetry(
			clampf(-_remote_steer_vis / 0.45, -1.0, 1.0),
			absf(speed_mps) * 3.6,
			clampf(0.15 + absf(speed_mps) / 35.0 * 0.75, 0.15, 0.95),
			braking
		)
