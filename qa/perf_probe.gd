extends SceneTree

## Dev-only performance probe (export-excluded). Prints comparable numbers for
## the baseline and the redesign:
##   headless:  per-frame process/physics time, nodes/objects, static memory
##              while driving (throttle held) and in the idle showroom;
##   rendered:  draw calls / objects in the showroom and the driving HUD.
## Run: godot --headless --path . --script res://qa/perf_probe.gd
##      xvfb-run -a godot --path . --script res://qa/perf_probe.gd --rendering-driver opengl3 -- --render


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	await process_frame
	var render := OS.get_cmdline_user_args().has("--render")
	SettingsManager.load_settings()
	SettingsManager.graphics_tier = 1
	SettingsManager.set_selected_vehicle(2)

	var menu: Node = (load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	await _settle(60)
	var m := await _sample(240)
	print("PERF menu      process_ms=%.3f (max %.3f) nodes=%d objects=%d mem_mb=%.1f draw_calls=%d" % [m["proc"], m["proc_max"], m["nodes"], m["objects"], m["mem"], m["dc"]])
	menu.queue_free()
	await _settle(10)

	var main: Node = (load("res://scenes/main/main_driving_template.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _settle(60)
	var hud = main.hud
	main.vehicle.read_desktop_input = false
	hud.btn_throttle.set_simulated_press(true)
	var d := await _sample(600)
	hud.btn_throttle.set_simulated_press(false)
	print("PERF driving   process_ms=%.3f (max %.3f) physics_ms=%.3f nodes=%d objects=%d mem_mb=%.1f draw_calls=%d" % [d["proc"], d["proc_max"], d["phys"], d["nodes"], d["objects"], d["mem"], d["dc"]])
	hud.set_game_paused(true)
	await _settle(10)
	var p := await _sample(120)
	print("PERF paused    process_ms=%.3f nodes=%d draw_calls=%d" % [p["proc"], p["nodes"], p["dc"]])
	hud.set_game_paused(false)
	print("PERF mode=", "rendered" if render else "headless")
	quit(0)


func _settle(n: int) -> void:
	for _i in range(n):
		await process_frame


func _sample(n: int) -> Dictionary:
	var proc := 0.0
	var proc_max := 0.0
	var phys := 0.0
	var dc := 0
	for _i in range(n):
		await process_frame
		var tp := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		proc += tp
		proc_max = maxf(proc_max, tp)
		phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		dc = maxi(dc, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	return {
		"proc": proc / float(n), "proc_max": proc_max, "phys": phys / float(n), "dc": dc,
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"mem": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
	}
