class_name ReplayRecorder
extends Node

## F2/F3 (K2-REDESIGN-001, MVP): records the last 15 seconds of the
## vehicle's global transform at 20 Hz into a ring buffer.
## - Replay: plays the buffer back on the real vehicle (frozen physics,
##   driving HUD muted via replay_started/replay_finished), then restores
##   the vehicle to its exact pre-replay pose.
## - Ghost: keeps the highest-distance 15s segment as the "best run"; a
##   translucent clone of the vehicle's showcase scene (with wheels) loops
##   through it while the player drives.

signal replay_started
signal replay_finished

const SAMPLE_DT := 0.05
const MAX_SAMPLES := 300 # 15s at 20 Hz
const BEST_CHECK_INTERVAL := 20 # check best-segment upgrade once per second

var vehicle: SaipaVehicleController = null
var hud: VehicleHud = null

var _buffer: Array[Transform3D] = []
var _best: Array[Transform3D] = []
var _best_distance_m: float = 0.0
var _samples_since_best_check: int = 0
var _accum: float = 0.0
var _run_time: float = 0.0

var _replaying: bool = false
var _replay_idx: float = 0.0
var _was_frozen: bool = false
var _was_reading_desktop: bool = true
var _pre_replay_tf: Transform3D = Transform3D.IDENTITY

var _ghost_node: Node3D = null
var _ghost_active: bool = false
var _ghost_idx: float = 0.0


func bind(target_vehicle: SaipaVehicleController, target_hud: VehicleHud) -> void:
	vehicle = target_vehicle
	hud = target_hud


func _compute_path_distance(samples: Array[Transform3D]) -> float:
	var total := 0.0
	for i in range(1, samples.size()):
		total += samples[i - 1].origin.distance_to(samples[i].origin)
	return total


func _physics_process(delta: float) -> void:
	if vehicle == null:
		return
	if _replaying:
		_replay_idx += delta / SAMPLE_DT
		if _replay_idx >= float(_buffer.size() - 1):
			_end_replay()
		else:
			var i := int(_replay_idx)
			var frac := _replay_idx - float(i)
			var a := _buffer[i]
			var b := _buffer[i + 1]
			vehicle.global_transform = a.interpolate_with(b, frac)
		return
	# Record.
	_run_time += delta
	_accum += delta
	if _accum >= SAMPLE_DT:
		_accum = 0.0
		_buffer.append(vehicle.global_transform)
		if _buffer.size() > MAX_SAMPLES:
			_buffer.pop_front()
		_samples_since_best_check += 1
		if _samples_since_best_check >= BEST_CHECK_INTERVAL:
			_samples_since_best_check = 0
			var dist := _compute_path_distance(_buffer)
			# Upgrade best run while filling up OR whenever a newer 15s
			# window covers strictly more distance (faster segment).
			if (_best.size() < MAX_SAMPLES and _buffer.size() > _best.size()) or dist > _best_distance_m + 5.0:
				_best = _buffer.duplicate()
				_best_distance_m = dist
	# Ghost playback runs alongside live driving.
	if _ghost_active and _ghost_node != null and _best.size() > 1:
		_ghost_idx += delta / SAMPLE_DT
		if _ghost_idx >= float(_best.size() - 1):
			_ghost_idx = 0.0
			_run_time = 0.0
		var gi := int(_ghost_idx)
		var gfrac := _ghost_idx - float(gi)
		_ghost_node.global_transform = _best[gi].interpolate_with(_best[gi + 1], gfrac)
		if hud != null:
			var ghost_t := float(_best.size()) * SAMPLE_DT
			hud.set_ghost_delta("شبح: %.1f ث | شما: %.1f ث" % [ghost_t, _run_time])


func start_replay() -> bool:
	if vehicle == null or _buffer.size() < 10 or _replaying:
		if hud != null and not _replaying:
			hud.show_toast("دادهٔ کافی برای بازپخش نیست")
		return false
	_replaying = true
	_replay_idx = 0.0
	_was_frozen = vehicle.freeze
	_was_reading_desktop = vehicle.read_desktop_input
	_pre_replay_tf = vehicle.global_transform
	vehicle.clear_external_inputs()
	vehicle.read_desktop_input = false
	vehicle.freeze = true
	vehicle.global_transform = _buffer[0]
	vehicle.reset_physics_interpolation()
	replay_started.emit()
	return true


func _end_replay() -> void:
	_replaying = false
	if vehicle != null:
		vehicle.freeze = _was_frozen
		vehicle.read_desktop_input = _was_reading_desktop
		# Restore the exact pre-replay position instead of teleporting back
		# to the track spawn point.
		vehicle.reset_vehicle(_pre_replay_tf)
	replay_finished.emit()


func is_replaying() -> bool:
	return _replaying


func toggle_ghost() -> void:
	if _ghost_active:
		_ghost_active = false
		if _ghost_node != null:
			_ghost_node.queue_free()
			_ghost_node = null
		if hud != null:
			hud.set_ghost_delta("")
		return
	if vehicle == null:
		return
	# If the player toggles ghost before the 1s check ran, seed _best from _buffer.
	if _best.size() < 10 and _buffer.size() >= 10:
		_best = _buffer.duplicate()
		_best_distance_m = _compute_path_distance(_best)
	if _best.size() < 10:
		if hud != null:
			hud.show_toast("هنوز رکوردی برای شبح نیست")
		return
	var entry := VehicleCatalog.get_entry(VehicleCatalog.find_index_by_id(vehicle.vehicle_id))
	# Use showcase_scene (includes wheels) rather than visual_scene (body-only).
	var scene_path := str(entry.get("showcase_scene", entry.get("visual_scene", "")))
	var packed := load(scene_path) as PackedScene
	if packed == null:
		return
	_ghost_node = packed.instantiate() as Node3D
	if _ghost_node == null:
		return
	_ghost_node.name = "GhostCar"
	# Translucent ghost material on every mesh surface.
	var ghost_mat := StandardMaterial3D.new()
	ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_mat.albedo_color = Color(0.0, 0.85, 1.0, 0.30)
	ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost_mat.no_depth_test = false
	var stack: Array[Node] = [_ghost_node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			if mi.mesh != null:
				for s in range(mi.mesh.get_surface_count()):
					mi.set_surface_override_material(s, ghost_mat)
		for ch in n.get_children():
			stack.append(ch)
	get_parent().add_child(_ghost_node)
	_ghost_node.global_transform = _best[0]
	_ghost_node.reset_physics_interpolation()
	_ghost_idx = 0.0
	_run_time = 0.0
	_ghost_active = true
	if hud != null:
		hud.show_toast("شبح بهترین رکورد فعال شد")


func is_ghost_active() -> bool:
	return _ghost_active


func sample_count() -> int:
	return _buffer.size()
