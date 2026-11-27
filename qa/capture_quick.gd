extends SceneTree

## Fast iteration capture for the B9 UI pass (dev-only, NOT exported).
## Run: xvfb-run -a godot --path . --script res://qa/capture_quick.gd --rendering-driver opengl3 -- --tag=b9 --only=menu|hud|all

const OUT_DIR := "res://reports/screenshots/qa/"
var tag := "q"
var only := "all"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.substr(6)
		if a.begins_with("--only="):
			only = a.substr(7)
	await _run()
	quit(0)


func _frames(n: int) -> void:
	for _i in range(n):
		await process_frame


func _shot(shot_name: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var err := img.save_png(ProjectSettings.globalize_path(OUT_DIR + "%s_%s.png" % [tag, shot_name]))
	print("SHOT %s (%dx%d err=%d)" % [shot_name, img.get_width(), img.get_height(), err])


func _set_size(w: int, h: int) -> void:
	DisplayServer.window_set_size(Vector2i(w, h))
	root.size = Vector2i(w, h)
	await _frames(4)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	SettingsManager.load_settings()
	SettingsManager.graphics_tier = 1
	SettingsManager.save_settings()
	if only == "all" or only == "menu":
		await _capture_menu()
	if only == "all" or only == "hud":
		await _capture_hud()
	print("QUICK CAPTURE DONE")


func _capture_menu() -> void:
	for res: Vector2i in [Vector2i(1280, 720), Vector2i(960, 540), Vector2i(720, 1280), Vector2i(1024, 768)]:
		await _set_size(res.x, res.y)
		var menu := (load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate()
		root.add_child(menu)
		await _frames(28)
		(menu.find_child("MenuSettingsButton", true, false) as Button).pressed.emit()
		await _frames(22)
		var panel: SettingsPanel = menu.find_child("MenuSettingsPanel", true, false) as SettingsPanel
		var tabs_to_shot: Array[int] = [0, 1, 3]
		for i in tabs_to_shot:
			panel.call("_select_tab", i)
			await _frames(10)
			await _shot("settings_tab%d_%dx%d" % [i, res.x, res.y])
		(menu.find_child("MenuSettingsBackButton", true, false) as Button).pressed.emit()
		await _frames(6)
		menu.queue_free()
		await _frames(4)


func _capture_hud() -> void:
	for res: Vector2i in [Vector2i(960, 540), Vector2i(720, 1280)]:
		await _set_size(res.x, res.y)
		SettingsManager.set_selected_vehicle(2)
		var main := (load("res://scenes/main/main_driving_template.tscn") as PackedScene).instantiate()
		root.add_child(main)
		await _frames(36)
		var hud: VehicleHud = main.hud
		main.vehicle.read_desktop_input = false
		var modes: Array[VehicleHud.SteerUiMode] = [VehicleHud.SteerUiMode.BUTTONS, VehicleHud.SteerUiMode.WHEEL, VehicleHud.SteerUiMode.ANALOG_BAR]
		var names := ["buttons", "wheel", "analog"]
		for k in range(modes.size()):
			hud.steer_ui_mode = modes[k]
			await _frames(8)
			await _shot("hud_%s_%dx%d" % [names[k], res.x, res.y])
		hud.steer_ui_mode = VehicleHud.SteerUiMode.BUTTONS
		hud.set_game_paused(true)
		await _frames(8)
		await _shot("pause_%dx%d" % [res.x, res.y])
		(hud.find_child("PauseSettingsButton", true, false) as Button).pressed.emit()
		await _frames(20)
		await _shot("pause_settings_%dx%d" % [res.x, res.y])
		hud.set_game_paused(false)
		main.queue_free()
		await _frames(4)
