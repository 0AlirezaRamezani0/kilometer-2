extends SceneTree

const RUNWAY = preload("res://tests/support/test_runway.gd")

## K2-FIX-004: the engine RPM model. Before this fix, RPM was a
## linear function of road speed (idle pitch ~0.95x at standstill,
## near-redline pitch at any cruise). This suite drives a real car
## through idle / launch flare / upshifts / lift-off and checks the
## model + the audio pitch path that consumes it, for the default
## car in depth and all six cars for idle + stream mapping.

var passed: int = 0
var failed: int = 0
var _pitch_max_step: float = 0.0
var _last_pitch: float = -1.0
var _audio: EngineAudio = null


func _initialize() -> void:
	await run_checks()
	print("=== ENGINE RPM MODEL SUMMARY: %d passed, %d failed ===" % [passed, failed])
	quit(1 if failed > 0 else 0)


func check(cond: bool, label: String, detail: String = "") -> void:
	if cond:
		passed += 1
		print("  [PASS] %s %s" % [label, detail])
	else:
		failed += 1
		push_error("  [FAIL] %s %s" % [label, detail])


func _step(frames: int) -> void:
	for _i in range(frames):
		await physics_frame
		await process_frame


func _find_audio(car: SaipaVehicleController) -> EngineAudio:
	for c in car.get_children():
		if c is EngineAudio:
			return c as EngineAudio
	return null


func _on_process_frame() -> void:
	if _audio == null:
		return
	var p := _audio.get_current_pitch()
	if _last_pitch >= 0.0:
		_pitch_max_step = maxf(_pitch_max_step, absf(p - _last_pitch))
	_last_pitch = p


func _spawn(idx: int) -> Node:
	SettingsManager.load_settings()
	SettingsManager.set_selected_vehicle(idx)
	SettingsManager.graphics_tier = 1
	SettingsManager.engine_volume = 0.8
	SettingsManager.save_settings()
	var main = (load("res://scenes/main/main_driving_template.tscn") as PackedScene).instantiate()
	root.add_child(main)
	return main


func run_checks() -> void:
	await process_frame
	# ---- Deep drive cycle, default car (Sport Pride, anchor 1.06) ----
	var main = await _spawn(0)
	await _step(50)
	var car: SaipaVehicleController = main.vehicle
	var hud: VehicleHud = main.hud
	_audio = _find_audio(car)
	check(_audio != null, "audio_attached")
	# 1) Idle: quiet and low.
	await _step(70)
	check(car.engine_rpm_norm < 0.08, "idle_rpm_low", "norm=%.3f" % car.engine_rpm_norm)
	if _audio != null:
		check(_audio.get_current_pitch() < 0.80, "idle_pitch_low", "pitch=%.2f (anchor 1.06, idle target 0.64)" % _audio.get_current_pitch())
	# 2) Launch flare: body frozen (deterministic standstill) + full
	# throttle — RPM must flare on throttle alone, with zero road speed.
	process_frame.connect(_on_process_frame)
	car.freeze = true
	hud.btn_throttle.set_simulated_press(true)
	await _step(75)
	check(car.current_speed_kmh < 3.0, "flare_car_held", "speed=%.1f" % car.current_speed_kmh)
	check(car.engine_rpm_norm > 0.45, "launch_flare_rpm", "norm=%.2f at speed %.1f" % [car.engine_rpm_norm, car.current_speed_kmh])
	car.freeze = false
	# 3) Accelerate through the gears (stop at the end of the straight).
	# v0.2-b1: the map is now the desert circuit, whose grid sits just before a corner,
	# so the powertrain run is staged at the surveyed longest straight instead of relying
	# on the old proving ground's runway out of the spawn. Map change only — the gearbox
	# assertions below are unchanged.
	# v0.2-b2: the desert circuit has no 400 m straight any more, and this suite measures the
	# gearbox, so it brings its own runway (see tests/support/test_runway.gd). The 95 km/h gate
	# is deliberately unchanged — it is what proves the box reaches 4th/5th.
	var straight_tf: Transform3D = RUNWAY.build(main)
	car.set_spawn_transform(straight_tf)
	car.reset_vehicle(straight_tf)
	await _step(5)
	car.freeze = false
	hud.btn_throttle.set_simulated_press(true)
	var gears: Array[int] = []
	var rpms: Array[float] = []
	var shift_drop := 0.0
	var ticks := 0
	var max_speed := 0.0
	var rpm_at_max := 0.0
	var gear_at_max := 1
	while max_speed < 100.0 and ticks < 1500 and car.global_position.z < 170.0:
		await _step(1)
		ticks += 1
		if car.current_speed_kmh > max_speed:
			max_speed = car.current_speed_kmh
			rpm_at_max = car.engine_rpm_norm
			gear_at_max = car.engine_gear
		if gears.is_empty() or gears[-1] != car.engine_gear:
			if not gears.is_empty():
				# measure the drop over the next 30 ticks
				var at_shift: float = rpms[-1]
				for _j in range(30):
					await _step(1)
					ticks += 1
				shift_drop = maxf(shift_drop, at_shift - car.engine_rpm_norm)
			gears.append(car.engine_gear)
		rpms.append(car.engine_rpm_norm)
	check(max_speed >= 95.0, "reached_95plus", "max %.1f km/h in %d ticks" % [max_speed, ticks])
	check(gears.size() >= 3, "upshifts_happened", "gears=%s" % str(gears))
	check(shift_drop >= 0.12, "rpm_drops_on_upshift", "max drop=%.2f" % shift_drop)
	check(rpm_at_max < 0.97, "not_pinned_at_redline", "norm=%.2f at %.0f km/h gear %d" % [rpm_at_max, max_speed, gear_at_max])
	# 4) Pitch continuity across the whole cycle.
	check(_pitch_max_step < 0.06, "pitch_no_jumps", "max step=%.3f" % _pitch_max_step)
	# 5) Lift-off: RPM follows speed down (engine braking).
	var rpm_at_release := car.engine_rpm_norm
	hud.btn_throttle.set_simulated_press(false)
	await _step(240)
	check(car.engine_rpm_norm < rpm_at_release - 0.10, "liftoff_rpm_falls", "%.2f -> %.2f" % [rpm_at_release, car.engine_rpm_norm])
	if process_frame.is_connected(_on_process_frame):
		process_frame.disconnect(_on_process_frame)
	_audio = null
	main.queue_free()
	await _step(5)
	# ---- All six cars: idle + stream/pitch mapping ----
	for idx in range(6):
		var m2 = await _spawn(idx)
		await _step(45)
		var c2: SaipaVehicleController = m2.vehicle
		var a2 := _find_audio(c2)
		check(a2 != null and a2.get_stream_path() == EngineAudio.STREAM_PATHS[idx], "car%d_stream" % idx, a2.get_stream_path() if a2 != null else "<none>")
		check(c2.engine_rpm_norm < 0.08, "car%d_idle_rpm" % idx, "norm=%.3f" % c2.engine_rpm_norm)
		if a2 != null:
			var anchor: float = EngineAudio.BASE_PITCH[idx]
			check(a2.get_current_pitch() < anchor * 0.78, "car%d_idle_pitch" % idx, "pitch=%.2f anchor=%.2f" % [a2.get_current_pitch(), anchor])
		m2.queue_free()
		await _step(5)
