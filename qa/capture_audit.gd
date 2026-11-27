extends SceneTree

## QA capture harness (dev-only, NOT exported).
## Captures the screens the user reported as broken, at several resolutions,
## so fixes can be verified visually before/after.
## Run:  xvfb-run -a godot --path . --script res://qa/capture_audit.gd --rendering-driver opengl3
## Out:  res://reports/screenshots/qa/<tag>_<w>x<h>_<name>.png

const OUT_DIR := "res://reports/screenshots/qa/"
var tag := "before"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.substr(6)
	await _run()
	quit(0)


func _frames(n: int) -> void:
	for _i in range(n):
		await process_frame


func _shot(name: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUT_DIR + "%s_%s.png" % [tag, name])
	var err := img.save_png(path)
	print("SHOT %s -> %s (%dx%d err=%d)" % [name, path.get_file(), img.get_width(), img.get_height(), err])


func _set_size(w: int, h: int) -> void:
	DisplayServer.window_set_size(Vector2i(w, h))
	root.size = Vector2i(w, h)
	await _frames(4)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	SettingsManager.load_settings()
	SettingsManager.set_selected_vehicle(0)
	SettingsManager.graphics_tier = 1
	SettingsManager.save_settings()

	# ---------- MENU: settings modal at 3 resolutions ----------
	for res in [Vector2i(1280, 720), Vector2i(960, 540), Vector2i(720, 1280), Vector2i(1024, 768), Vector2i(844, 390)]:
		await _set_size(res.x, res.y)
		var menu = (load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate()
		root.add_child(menu)
		await _frames(30)
		(menu.find_child("MenuSettingsButton", true, false) as Button).pressed.emit()
		await _frames(25)
		await _shot("menu_settings_%dx%d" % [res.x, res.y])
		# each tab
		var panel: SettingsPanel = menu.find_child("MenuSettingsPanel", true, false) as SettingsPanel
		if panel != null:
			for i in range(4):
				panel.call("_select_tab", i)
				await _frames(12)
				await _shot("menu_settings_tab%d_%dx%d" % [i, res.x, res.y])
		(menu.find_child("MenuSettingsBackButton", true, false) as Button).pressed.emit()
		await _frames(6)
		menu.queue_free()
		await _frames(4)

	# ---------- DRIVING: touch controls at 3 resolutions ----------
	for res in [Vector2i(1280, 720), Vector2i(960, 540), Vector2i(720, 1280), Vector2i(1024, 768), Vector2i(844, 390)]:
		await _set_size(res.x, res.y)
		SettingsManager.set_selected_vehicle(2)
		var main = (load("res://scenes/main/main_driving_template.tscn") as PackedScene).instantiate()
		root.add_child(main)
		await _frames(40)
		var hud: VehicleHud = main.hud
		var car: SaipaVehicleController = main.vehicle
		if car != null:
			car.read_desktop_input = false
		await _shot("driving_buttons_%dx%d" % [res.x, res.y])
		if hud != null:
			for mode in [VehicleHud.SteerUiMode.WHEEL, VehicleHud.SteerUiMode.ANALOG_BAR]:
				hud.steer_ui_mode = mode
				await _frames(10)
				var nm := "wheel" if mode == VehicleHud.SteerUiMode.WHEEL else "analog"
				await _shot("driving_%s_%dx%d" % [nm, res.x, res.y])
			hud.steer_ui_mode = VehicleHud.SteerUiMode.BUTTONS
			# pause + pause settings
			hud.set_game_paused(true)
			await _frames(8)
			await _shot("pause_%dx%d" % [res.x, res.y])
			var ps := hud.find_child("PauseSettingsButton", true, false) as Button
			if ps != null:
				ps.pressed.emit()
				await _frames(25)
				await _shot("pause_settings_%dx%d" % [res.x, res.y])
			hud.set_game_paused(false)
		main.queue_free()
		await _frames(4)
	print("QA CAPTURE DONE (tag=%s)" % tag)
