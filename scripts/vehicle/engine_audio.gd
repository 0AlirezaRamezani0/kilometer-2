class_name EngineAudio
extends Node

## Kilometer 2 — Multi-Layer Vehicle Acoustic Engine (Velocity Pro v6).
##
## Preserves every vehicle's unique licensed engine loop (CC0 / CC-BY 3.0 —
## full provenance in AUDIO_CREDITS.md) and elevates the driving soundscape
## into a cohesive multi-layer automotive mix routed through dedicated
## `Vehicle` and `SFX` buses:
##   1. EngineBaseLayer     — per-car core engine loop (Vehicle bus)
##   2. EngineLoadLayer     — throttle-driven harmonic chorus growl (Vehicle bus)
##   3. EngineSubLayer      — warm 4-cyl sub-exhaust resonance body (Vehicle bus)
##   4. EngineStartupPlayer — real starter crank + ignition flare on spawn (SFX bus)
##   5. GearShiftPlayer     — mechanical transmission shift clunk + puff (SFX bus)
##   6. TireScreechPlayer   — lateral slip & handbrake rubber squeal loop (SFX bus)
##   7. WindRoadPlayer      — speed-scaled aerodynamic wind & asphalt roll (SFX bus)
##   8. ImpactPlayer        — chassis thud connected to impact_detected (SFX bus)
##   9. HandbrakePlayer     — tactile mechanical ratchet on pull (SFX bus)

const STREAM_PATHS: Array[String] = [
	"res://assets/audio/engine/engine_sport_pride.ogg",
	"res://assets/audio/engine/engine_tara.ogg",
	"res://assets/audio/engine/engine_megan.ogg",
	"res://assets/audio/engine/engine_pride132.ogg",
	"res://assets/audio/engine/engine_quick.ogg",
	"res://assets/audio/engine/engine_samand.ogg",
]
## Per-car pitch anchor: combined with each recording's own dominant
## frequency this keeps the six cars measurably distinct at equal RPM.
const BASE_PITCH: Array[float] = [1.06, 1.00, 0.85, 1.12, 0.97, 1.00]
## Per-car exhaust sub warmth scale (sporty / heavier sedans get slightly deeper body).
const SUB_GAIN: Array[float] = [0.34, 0.28, 0.32, 0.24, 0.26, 0.35]
const LAYER_CAP: float = 0.63 # -4 dB per layer
## B8: hard per-frame pitch slew cap. In slow-render environments one
## _process can span many physics ticks; the exponential approach alone
## then steps pitch by up to 0.116 in a single frame (probe-measured),
## breaking the pitch-continuity budget of 0.06. At 60 fps this cap is
## a 2.4/s slew — far faster than any real pitch travel in the model.
const PITCH_SLEW_PER_FRAME: float = 0.04

const PATH_EXHAUST_SUB := "res://assets/audio/sfx/sfx_exhaust_sub.ogg"
const PATH_STARTUP := "res://assets/audio/sfx/sfx_engine_start.ogg"
const PATH_GEAR_SHIFT := "res://assets/audio/sfx/sfx_gear_shift.ogg"
const PATH_TIRE_SCREECH := "res://assets/audio/sfx/sfx_tire_screech.ogg"
const PATH_WIND_ROAD := "res://assets/audio/sfx/sfx_wind_road.ogg"
const PATH_IMPACT := "res://assets/audio/sfx/sfx_impact_thud.ogg"
const PATH_HANDBRAKE := "res://assets/audio/sfx/sfx_handbrake_click.ogg"

var _vehicle: SaipaVehicleController = null
var _index: int = 0
var _base: AudioStreamPlayer = null
var _load: AudioStreamPlayer = null
var _sub: AudioStreamPlayer = null
var _startup: AudioStreamPlayer = null
var _gear_shift: AudioStreamPlayer = null
var _tire_screech: AudioStreamPlayer = null
var _wind_road: AudioStreamPlayer = null
var _impact: AudioStreamPlayer = null
var _handbrake: AudioStreamPlayer = null

var _pitch: float = 0.8
var _screech_level: float = 0.0
var _wind_level: float = 0.0
var _last_engine_gear: int = 1
var _last_gear_state: int = 1
var _last_handbrake_on: bool = false
var _shift_sfx_cooldown: float = 0.0
var _impact_sfx_cooldown: float = 0.0
var _ready_done: bool = false

## Test hooks: when >= 0 these replace the controller-derived values.
## Production code never sets them.
var debug_rpm_override: float = -1.0
var debug_throttle_override: float = -1.0


func _resolve_bus(preferred: String) -> String:
	return preferred if AudioServer.get_bus_index(preferred) >= 0 else "Master"


func _make_loop_player(node_name: String, path: String, bus_name: String) -> AudioStreamPlayer:
	if not ResourceLoader.exists(path):
		return null
	var st := load(path) as AudioStreamOggVorbis
	if st == null:
		return null
	st.loop = true
	var p := AudioStreamPlayer.new()
	p.name = node_name
	p.stream = st
	p.bus = _resolve_bus(bus_name)
	p.volume_db = -60.0
	add_child(p)
	return p


func _make_oneshot_player(node_name: String, path: String, bus_name: String) -> AudioStreamPlayer:
	if not ResourceLoader.exists(path):
		return null
	var st := load(path) as AudioStreamOggVorbis
	if st == null:
		return null
	st.loop = false
	var p := AudioStreamPlayer.new()
	p.name = node_name
	p.stream = st
	p.bus = _resolve_bus(bus_name)
	add_child(p)
	return p


## Called once by the main template right after the vehicle spawns.
func configure(vehicle_node: SaipaVehicleController, vehicle_index: int) -> void:
	_vehicle = vehicle_node
	_index = posmod(vehicle_index, STREAM_PATHS.size())
	var stream := load(STREAM_PATHS[_index]) as AudioStreamOggVorbis
	if stream == null:
		push_error("EngineAudio: missing stream " + STREAM_PATHS[_index])
		return
	stream.loop = true
	var veh_bus := _resolve_bus("Vehicle")

	_base = AudioStreamPlayer.new()
	_base.name = "EngineBaseLayer"
	_base.stream = stream
	_base.bus = veh_bus
	add_child(_base)

	_load = AudioStreamPlayer.new()
	_load.name = "EngineLoadLayer"
	_load.stream = stream
	_load.bus = veh_bus
	add_child(_load)

	# Rich supporting acoustic layers
	_sub = _make_loop_player("EngineSubLayer", PATH_EXHAUST_SUB, "Vehicle")
	_startup = _make_oneshot_player("EngineStartupPlayer", PATH_STARTUP, "SFX")
	_gear_shift = _make_oneshot_player("GearShiftPlayer", PATH_GEAR_SHIFT, "SFX")
	_tire_screech = _make_loop_player("TireScreechPlayer", PATH_TIRE_SCREECH, "SFX")
	_wind_road = _make_loop_player("WindRoadPlayer", PATH_WIND_ROAD, "SFX")
	_impact = _make_oneshot_player("ImpactPlayer", PATH_IMPACT, "SFX")
	_handbrake = _make_oneshot_player("HandbrakePlayer", PATH_HANDBRAKE, "SFX")

	_pitch = BASE_PITCH[_index] * 0.85
	_last_engine_gear = _vehicle.engine_gear
	_last_gear_state = int(_vehicle.gear_state)

	if not _vehicle.impact_detected.is_connected(_on_vehicle_impact):
		_vehicle.impact_detected.connect(_on_vehicle_impact)

	SettingsManager.ensure_loaded()
	_ready_done = true
	if SettingsManager.engine_volume > 0.001:
		_base.play()
		_load.play()
		if _sub != null:
			_sub.play()
		if _startup != null and SettingsManager.sfx_volume > 0.005:
			_startup.pitch_scale = clampf(BASE_PITCH[_index], 0.88, 1.14)
			_startup.volume_db = -4.0
			_startup.play()
	if _tire_screech != null:
		_tire_screech.play()
	if _wind_road != null:
		_wind_road.play()


func _exit_tree() -> void:
	if Engine.has_singleton("AudioManager") or has_node("/root/AudioManager"):
		var am := get_node_or_null("/root/AudioManager")
		if am != null and am.has_method("set_engine_duck"):
			am.call("set_engine_duck", 0.0)


func get_stream_path() -> String:
	return STREAM_PATHS[_index]


func get_current_pitch() -> float:
	return _pitch


func is_engine_playing() -> bool:
	return _ready_done and _base != null and _base.playing


func _on_vehicle_impact(strength: float) -> void:
	if _impact == null or _impact_sfx_cooldown > 0.0:
		return
	if SettingsManager.sfx_volume <= 0.005:
		return
	var norm := clampf(strength / 4.5, 0.12, 1.0)
	_impact.volume_db = linear_to_db(norm * 0.85)
	_impact.pitch_scale = lerpf(0.84, 1.14, 1.0 - norm * 0.45) + randf_range(-0.04, 0.04)
	_impact.play()
	_impact_sfx_cooldown = 0.14


func _process(delta: float) -> void:
	if not _ready_done or _vehicle == null:
		return
	var d := clampf(delta, 0.0005, 0.05)
	_shift_sfx_cooldown = maxf(_shift_sfx_cooldown - d, 0.0)
	_impact_sfx_cooldown = maxf(_impact_sfx_cooldown - d, 0.0)

	var vol := SettingsManager.engine_volume
	var sfx_vol := SettingsManager.sfx_volume
	var rpm := clampf(_vehicle.engine_rpm_norm, 0.0, 1.0)
	var throttle := clampf(_vehicle.engine_throttle, 0.0, 1.0)
	if debug_rpm_override >= 0.0:
		rpm = clampf(debug_rpm_override, 0.0, 1.0)
	if debug_throttle_override >= 0.0:
		throttle = clampf(debug_throttle_override, 0.0, 1.0)

	# --- 1. Core Engine + Load + Warm Exhaust Sub-Body ----------------------
	if vol <= 0.001:
		if _base.playing:
			_base.stop()
			_load.stop()
			if _sub != null and _sub.playing:
				_sub.stop()
	else:
		if not _base.playing:
			_base.play()
			_load.play()
			if _sub != null and not _sub.playing:
				_sub.play()

		var target := BASE_PITCH[_index] * lerpf(0.60, 1.85, pow(rpm, 1.08))
		var alpha := 1.0 - exp(-9.0 * d)
		var smoothed := lerpf(_pitch, target, alpha)
		_pitch = clampf(smoothed, _pitch - PITCH_SLEW_PER_FRAME, _pitch + PITCH_SLEW_PER_FRAME)
		_base.pitch_scale = _pitch
		_load.pitch_scale = _pitch * 1.03

		# B8: SettingsManager.engine_volume is applied ONCE, on the Vehicle
		# bus (AudioManager.apply_audio_settings). It must not also scale
		# the per-player volumes (that squared the slider curve). `vol`
		# above is now only the zero-gate that stops/resumes playback.
		# Base layer breathes smoothly with RPM; load layer swells with throttle + revs.
		_base.volume_db = linear_to_db(maxf(LAYER_CAP * lerpf(0.55, 1.0, rpm) * lerpf(0.85, 1.0, throttle), 0.0001))
		_load.volume_db = linear_to_db(maxf(LAYER_CAP * throttle * (0.30 + 0.70 * rpm), 0.0001)) if throttle > 0.02 else -60.0

		if _sub != null:
			_sub.pitch_scale = clampf(lerpf(0.76, 2.20, pow(rpm, 1.02)) * (0.94 + 0.06 * BASE_PITCH[_index]), 0.65, 2.4)
			var sub_amp := SUB_GAIN[_index] * lerpf(0.45, 1.0, 0.35 * rpm + 0.65 * throttle)
			_sub.volume_db = linear_to_db(maxf(sub_amp, 0.0001))

	# Feed smooth engine intensity to AudioManager for subtle dynamic music ducking
	var am := get_node_or_null("/root/AudioManager")
	if am != null and am.has_method("set_engine_duck"):
		var intensity := clampf(rpm * 0.65 + throttle * 0.35, 0.0, 1.0) if vol > 0.001 else 0.0
		am.call("set_engine_duck", intensity)

	# --- 2. Gear Shift & Transmission Mechanical Clunk ----------------------
	var cur_gear := _vehicle.engine_gear
	var cur_state := int(_vehicle.gear_state)
	if (cur_gear != _last_engine_gear or cur_state != _last_gear_state) and _shift_sfx_cooldown <= 0.0:
		if _gear_shift != null and sfx_vol > 0.005 and (_vehicle.current_speed_kmh > 8.0 or cur_state != _last_gear_state):
			var upshift := cur_gear > _last_engine_gear
			_gear_shift.pitch_scale = (1.06 if upshift else 0.90) + randf_range(-0.03, 0.03)
			_gear_shift.volume_db = -5.5 if upshift else -7.5
			_gear_shift.play()
			_shift_sfx_cooldown = 0.22
	_last_engine_gear = cur_gear
	_last_gear_state = cur_state

	# --- 3. Handbrake Mechanical Ratchet Click ------------------------------
	var hb_on := _vehicle.touch_handbrake or Input.is_action_pressed("handbrake")
	if hb_on and not _last_handbrake_on and _handbrake != null and sfx_vol > 0.005:
		_handbrake.pitch_scale = 1.0 + randf_range(-0.04, 0.04)
		_handbrake.volume_db = -7.0
		_handbrake.play()
	_last_handbrake_on = hb_on

	# --- 4. Tire Screech / Lateral Skid & Braking Loop ----------------------
	if _tire_screech != null:
		var spd := absf(_vehicle.current_speed_kmh)
		var local_v := _vehicle.global_transform.basis.inverse() * _vehicle.linear_velocity
		var lat_mps := absf(local_v.x)
		var grounded := _vehicle.get_grounded_wheel_count()
		var target_screech := 0.0
		if grounded > 0 and spd > 14.0 and sfx_vol > 0.005:
			# Lateral slide or handbrake drift or hard high-speed braking
			var lat_slip := clampf((lat_mps - 1.9) / 6.5, 0.0, 1.0)
			var hb_slip := clampf((spd - 16.0) / 48.0, 0.0, 0.90) if hb_on else 0.0
			var steer_slip := clampf((absf(_vehicle.smoothed_steer_rad) - 0.14) * (spd / 75.0), 0.0, 0.55)
			var raw_slip := maxf(lat_slip, maxf(hb_slip, steer_slip))
			# Wet/slippery surfaces squeal much softer than dry asphalt
			var grip_scale := clampf((_vehicle.active_surface_grip - 0.22) / 0.78, 0.18, 1.0)
			target_screech = raw_slip * grip_scale
		var s_rate := 10.0 if target_screech > _screech_level else 6.0
		_screech_level = lerpf(_screech_level, target_screech, 1.0 - exp(-s_rate * d))
		if _screech_level > 0.015:
			if not _tire_screech.playing:
				_tire_screech.play()
			_tire_screech.pitch_scale = lerpf(0.82, 1.18, clampf(spd / 120.0, 0.0, 1.0)) * lerpf(0.85, 1.0, clampf(_vehicle.active_surface_grip, 0.3, 1.0))
			_tire_screech.volume_db = linear_to_db(maxf(_screech_level * 0.42, 0.0001))
		else:
			_tire_screech.volume_db = -60.0

	# --- 5. Aerodynamic Wind & Asphalt Road Roll ----------------------------
	if _wind_road != null:
		var spd := absf(_vehicle.current_speed_kmh)
		var target_wind := clampf((spd - 22.0) / 138.0, 0.0, 1.0) if sfx_vol > 0.005 else 0.0
		target_wind = pow(target_wind, 1.35)
		_wind_level = lerpf(_wind_level, target_wind, 1.0 - exp(-4.5 * d))
		if _wind_level > 0.01:
			if not _wind_road.playing:
				_wind_road.play()
			_wind_road.pitch_scale = lerpf(0.82, 1.28, _wind_level)
			_wind_road.volume_db = linear_to_db(maxf(_wind_level * 0.36, 0.0001))
		else:
			_wind_road.volume_db = -60.0
