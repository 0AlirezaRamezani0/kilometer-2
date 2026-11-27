extends SceneTree

const RUNWAY = preload("res://tests/support/test_runway.gd")

## K2-REDESIGN-002 (D3): camera pivot lag measurement. Drives the
## default car to >90 km/h on the main straight and samples the rig
## diagnostics. The brief's target is < 0.01 m; the asserted gate is
## the regression threshold (mean < 0.10 m at >90 km/h) and the exact
## measured values are printed for the report. Before this rework the
## same harness measured 0.23 m.

var passed: int = 0
var failed: int = 0


func _initialize() -> void:
	await run_checks()
	print("=== CAMERA LAG SUMMARY: %d passed, %d failed ===" % [passed, failed])
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


func run_checks() -> void:
	await process_frame
	SettingsManager.load_settings()
	SettingsManager.set_selected_vehicle(0)
	SettingsManager.graphics_tier = 1
	SettingsManager.save_settings()
	var main = (load("res://scenes/main/main_driving_template.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _step(50)
	var hud: VehicleHud = main.hud
	var rig: VehicleCameraRig = main.camera_rig
	var car: SaipaVehicleController = main.vehicle
	# v0.2-b2: the desert circuit's longest flat straight is ~100 m (the old proving ground had
	# 400 m), which is not enough runway to reach the 90 km/h gate. This suite measures the
	# *camera*, so it stages its own straight: a synthetic slab in clean air above the circuit
	# (tests/support/test_runway.gd). The gate itself is unchanged.
	var runway: Transform3D = RUNWAY.build(main)
	car.set_spawn_transform(runway)
	car.reset_vehicle(runway)
	main.camera_rig.bind_vehicle(car)
	await _step(10)
	var run_start := car.global_position
	hud.btn_throttle.set_simulated_press(true)
	var samples: Array[float] = []
	var best_speed := 0.0
	var err_at_best := 0.0
	for i in range(900):
		await _step(2)
		var spd: float = car.current_speed_kmh
		if spd > best_speed:
			best_speed = spd
			err_at_best = float(rig.get_camera_diagnostics()["pivot_error_m"])
		if spd > 90.0:
			samples.append(float(rig.get_camera_diagnostics()["pivot_error_m"]))
		if car.global_position.distance_to(run_start) > 170.0:
			break
	hud.btn_throttle.set_simulated_press(false)
	check(best_speed > 90.0, "reached_high_speed", "%.1f km/h" % best_speed)
	check(not samples.is_empty(), "lag_samples_collected", "n=%d" % samples.size())
	if not samples.is_empty():
		var sum := 0.0
		var mx := 0.0
		for s in samples:
			sum += s
			mx = maxf(mx, s)
		var mean := sum / samples.size()
		print("  LAG at %.1f km/h: sample=%.4f m | >90km/h mean=%.4f max=%.4f n=%d" % [best_speed, err_at_best, mean, mx, samples.size()])
		check(mean < 0.10, "pivot_lag_mean_under_10cm", "mean=%.4f" % mean)
		check(mx < 0.25, "pivot_lag_max_under_25cm", "max=%.4f" % mx)
	main.queue_free()
