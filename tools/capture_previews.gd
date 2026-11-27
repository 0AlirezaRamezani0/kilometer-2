extends SceneTree

## Kilometer 2 screenshot tool (Xvfb + OpenGL3, NOT headless).
## Developer/QA tool — excluded from exported builds (see export_presets.cfg).
## Captures the 15 official review screenshots: all six showroom vehicles,
## menu settings/controls, driving HUD with the single free-follow camera,
## pause + pause settings, and both touch-steering variants.
## Run: xvfb-run godot --path . --script res://tools/capture_previews.gd
## Output: res://reports/screenshots/*.png
##
## B9: the official set now also stores an extreme-aspect pair that the B9 UI
## bugs lived in — a short landscape phone window (844x390) for the menu
## settings card and the pause drawer, and a portrait (720x1280) HUD — so the
## responsive fixes below keep visual evidence, not just headless checks.

const OUT_DIR := "res://reports/screenshots/"


func _initialize() -> void:
	await _capture_suite()
	quit(0)


func _step(frames: int, render: bool = false) -> void:
	if not render:
		RenderingServer.viewport_set_update_mode(root.get_viewport_rid(), RenderingServer.VIEWPORT_UPDATE_DISABLED)
	for _i in range(frames):
		await physics_frame
	RenderingServer.viewport_set_update_mode(root.get_viewport_rid(), RenderingServer.VIEWPORT_UPDATE_ALWAYS)
	await process_frame
	await process_frame


func _save_shot(filename: String) -> void:
	RenderingServer.viewport_set_update_mode(root.get_viewport_rid(), RenderingServer.VIEWPORT_UPDATE_ALWAYS)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var err := img.save_png(ProjectSettings.globalize_path(OUT_DIR + filename))
	print("Captured: %s (err=%d, %dx%d)" % [filename, err, img.get_width(), img.get_height()])


func _capture_suite() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	await process_frame
	DisplayServer.window_set_size(Vector2i(1280, 720))
	root.size = Vector2i(1280, 720)
	SettingsManager.load_settings()
	SettingsManager.set_selected_vehicle(0)
	SettingsManager.graphics_tier = 1
	SettingsManager.save_settings()

	# ---- Main menu showroom ------------------------------------------
	var menu = (load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	await _step(45, true)
	await _save_shot("01_showroom_sport_pride.png")

	# B8 repair: the old NextVehicleButton no longer exists, and the
	# pager thumbs are 0-based (VehicleThumb0..5 in catalog order, see
	# main_menu.gd) — the previous 1-based mapping saved every showroom
	# shot under the wrong car's name and then crashed on the null
	# NextVehicleButton before reaching the settings/HUD shots.
	(menu.find_child("VehicleThumb1", true, false) as Button).pressed.emit()
	await _step(30, true)
	await _save_shot("02_showroom_tara.png")
	(menu.find_child("VehicleThumb2", true, false) as Button).pressed.emit()
	await _step(30, true)
	await _save_shot("03_showroom_megan.png")
	(menu.find_child("VehicleThumb3", true, false) as Button).pressed.emit()
	await _step(30, true)
	await _save_shot("04_showroom_pride_132.png")
	(menu.find_child("VehicleThumb4", true, false) as Button).pressed.emit()
	await _step(30, true)
	await _save_shot("05_showroom_quick.png")
	(menu.find_child("VehicleThumb5", true, false) as Button).pressed.emit()
	await _step(30, true)
	await _save_shot("06_showroom_samand.png")

	var settings_btn := menu.find_child("MenuSettingsButton", true, false) as Button
	settings_btn.pressed.emit()
	await _step(6, true)
	await _save_shot("07_menu_settings.png")
	(menu.find_child("MenuSettingsBackButton", true, false) as Button).pressed.emit()
	await _step(4, true)

	var controls_btn := menu.find_child("HelpButton", true, false) as Button
	controls_btn.pressed.emit()
	await _step(6, true)
	await _save_shot("08_menu_controls.png")
	(menu.find_child("CloseInfoButton", true, false) as Button).pressed.emit()
	await _step(4, true)

	menu.queue_free()
	await _step(4, true)

	# ---- Driving: HUD + single free-follow camera ---------------------
	SettingsManager.set_selected_vehicle(2) # رنو مگان
	var main = (load("res://scenes/main/main_driving_template.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _step(50)
	var hud: VehicleHud = main.hud
	var car: SaipaVehicleController = main.vehicle
	car.read_desktop_input = false
	await _save_shot("09_driving_hud_start.png")

	hud.btn_throttle.set_simulated_press(true)
	await _step(170)
	await _save_shot("10_driving_hud_speed.png")

	hud.btn_steer_left.set_simulated_press(true)
	await _step(55)
	hud.btn_steer_left.set_simulated_press(false)
	await _save_shot("11_driving_cornering.png")
	hud.btn_throttle.set_simulated_press(false)
	await _step(40)

	# ---- Pause + pause settings (graphics changeable in pause) --------
	hud.set_game_paused(true)
	await _step(6, true)
	await _save_shot("12_pause_menu.png")
	(hud.find_child("PauseSettingsButton", true, false) as Button).pressed.emit()
	await _step(6, true)
	await _save_shot("13_pause_settings.png")
	hud.set_game_paused(false)
	await _step(10, true)

	# ---- Touch steering variants --------------------------------------
	hud.steer_ui_mode = VehicleHud.SteerUiMode.WHEEL
	await _step(6, true)
	await _save_shot("14_hud_steering_wheel.png")
	hud.steer_ui_mode = VehicleHud.SteerUiMode.ANALOG_BAR
	await _step(6, true)
	await _save_shot("15_hud_analog_bar.png")
	hud.steer_ui_mode = VehicleHud.SteerUiMode.BUTTONS

	# ---- B9: responsive evidence (extreme aspects) ---------------------
	SettingsManager.set_selected_vehicle(0)
	main.queue_free()
	await _step(6, true)
	for res in [Vector2i(844, 390), Vector2i(720, 1280)]:
		DisplayServer.window_set_size(res)
		root.size = res
		await _step(4, true)
		var menu2 = (load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate()
		root.add_child(menu2)
		await _step(24, true)
		(menu2.find_child("MenuSettingsButton", true, false) as Button).pressed.emit()
		await _step(16, true)
		await _save_shot("17_menu_settings_%dx%d.png" % [res.x, res.y])
		(menu2.find_child("MenuSettingsBackButton", true, false) as Button).pressed.emit()
		await _step(4, true)
		menu2.queue_free()
		await _step(4, true)
		SettingsManager.set_selected_vehicle(2)
		var main2 = (load("res://scenes/main/main_driving_template.tscn") as PackedScene).instantiate()
		root.add_child(main2)
		await _step(40)
		var hud2: VehicleHud = main2.hud
		main2.vehicle.read_desktop_input = false
		await _save_shot("18_hud_buttons_%dx%d.png" % [res.x, res.y])
		hud2.steer_ui_mode = VehicleHud.SteerUiMode.WHEEL
		await _step(8, true)
		await _save_shot("19_hud_wheel_%dx%d.png" % [res.x, res.y])
		hud2.steer_ui_mode = VehicleHud.SteerUiMode.BUTTONS
		hud2.set_game_paused(true)
		await _step(8, true)
		(hud2.find_child("PauseSettingsButton", true, false) as Button).pressed.emit()
		await _step(18, true)
		await _save_shot("20_pause_settings_%dx%d.png" % [res.x, res.y])
		hud2.set_game_paused(false)
		main2.queue_free()
		await _step(4, true)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	root.size = Vector2i(1280, 720)
	print("CAPTURE DONE: 15 core + 8 responsive screenshots")
