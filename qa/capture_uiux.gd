extends SceneTree

## Kilometer 2 — before/after UI capture harness (dev-only, export-excluded).
## Captures the same screens and states for the baseline and the redesign so
## the two sets can be compared side by side.
##
## Run (Xvfb + OpenGL3, not headless):
##   xvfb-run -a -s "-screen 0 2560x1440x24" godot --path . \
##       --script res://qa/capture_uiux.gd --rendering-driver opengl3 \
##       -- --out=/abs/output/dir [--only=menu,driving] [--res=1280x720,844x390]
## Output: <out>/<w>x<h>_<NN>_<screen>.png

var out_dir := ""
var only: PackedStringArray = []
var res_filter: PackedStringArray = []
## Optional: UI scale (e.g. 1.2 = handheld default) and prompt device.
var ui_scale: float = -1.0
var device: String = ""
var suffix: String = ""
var _saved_scale: Variant = null

const MATRIX: Array[Vector2i] = [
	Vector2i(1280, 720),  # 16:9 design resolution
	Vector2i(1920, 1080), # 16:9 FHD
	Vector2i(1280, 800),  # 16:10
	Vector2i(1024, 768),  # 4:3
	Vector2i(2560, 1080), # 21:9
	Vector2i(844, 390),   # ~19.5:9 phone, landscape
	Vector2i(720, 1280),  # portrait desktop window (best effort)
]


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
		elif a.begins_with("--only="):
			only = a.substr(7).split(",")
		elif a.begins_with("--res="):
			res_filter = a.substr(6).split(",")
		elif a.begins_with("--scale="):
			ui_scale = float(a.substr(8))
		elif a.begins_with("--device="):
			device = a.substr(9)
	if out_dir.is_empty():
		push_error("capture_uiux: pass -- --out=/abs/dir")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	await _run()
	if _saved_scale != null:
		var sm: Script = load("res://scripts/ui/settings_manager.gd")
		sm.set("ui_scale", _saved_scale)
		SettingsManager.save_settings()
	print("CAPTURE_UIUX DONE")
	quit(0)


func _want(group: String) -> bool:
	return only.is_empty() or only.has(group)


func _step(frames: int, render: bool = false) -> void:
	if not render:
		RenderingServer.viewport_set_update_mode(root.get_viewport_rid(), RenderingServer.VIEWPORT_UPDATE_DISABLED)
	for _i in range(frames):
		await physics_frame
	RenderingServer.viewport_set_update_mode(root.get_viewport_rid(), RenderingServer.VIEWPORT_UPDATE_ALWAYS)
	await process_frame
	await process_frame


func _shot(res: Vector2i, idx: int, name: String) -> void:
	RenderingServer.viewport_set_update_mode(root.get_viewport_rid(), RenderingServer.VIEWPORT_UPDATE_ALWAYS)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var path := out_dir.path_join("%dx%d%s_%02d_%s.png" % [res.x, res.y, suffix, idx, name])
	var err := img.save_png(path)
	print("SHOT %s err=%d (%dx%d)" % [path.get_file(), err, img.get_width(), img.get_height()])


func _set_size(res: Vector2i) -> void:
	DisplayServer.window_set_size(res)
	root.size = res
	await _step(4, true)


func _press(node: Node, child_name: String) -> bool:
	var b := node.find_child(child_name, true, false) as BaseButton
	if b == null or not b.is_visible_in_tree():
		print("  (skip: %s not found/visible)" % child_name)
		return false
	b.pressed.emit()
	return true


func _run() -> void:
	SettingsManager.load_settings()
	SettingsManager.set_selected_vehicle(0)
	SettingsManager.graphics_tier = 1
	SettingsManager.steer_mode = 0
	SettingsManager.show_touch_controls = true
	# UI scale goes through the script resource so this harness still compiles
	# against builds whose SettingsManager has no ui_scale (the v0.1-b1
	# baseline). Without --scale the run is pinned to 100 %, and the player's
	# persisted value is restored when the run ends.
	var sm: Script = load("res://scripts/ui/settings_manager.gd")
	_saved_scale = sm.get("ui_scale")
	sm.set("ui_scale", ui_scale if ui_scale > 0.0 else 1.0)
	print("capture ui_scale=", sm.get("ui_scale"))
	if ui_scale > 0.0:
		suffix += "_s%d" % int(round(ui_scale * 100.0))
	SettingsManager.save_settings()
	root.content_scale_factor = ui_scale if ui_scale > 0.0 else 1.0
	match device:
		"gamepad":
			InputDeviceManager.current_mode = InputDeviceManager.Mode.GAMEPAD
			suffix += "_pad"
		"touch":
			InputDeviceManager.current_mode = InputDeviceManager.Mode.TOUCH
			suffix += "_touch"

	for res in MATRIX:
		if not res_filter.is_empty() and not res_filter.has("%dx%d" % [res.x, res.y]):
			continue
		await _set_size(res)
		var full := res == Vector2i(1280, 720)

		# ------------------------------------------------------------ menu
		if _want("menu"):
			SettingsManager.set_selected_vehicle(0)
			var menu: Node = (load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate()
			root.add_child(menu)
			await _step(50, true)
			await _shot(res, 1, "menu_showroom")
			if full:
				_press(menu, "VehicleThumb2")
				await _step(30, true)
				await _shot(res, 2, "menu_showroom_vehicle3")
			if _press(menu, "MenuSettingsButton"):
				await _step(20, true)
				await _shot(res, 3, "menu_settings_tab0")
				var panel := menu.find_child("MenuSettingsPanel", true, false)
				if panel != null and full:
					for t in range(1, 8):
						if panel.has_method("tab_count") and t >= int(panel.call("tab_count")):
							break
						if not panel.has_method("tab_count") and t >= 4:
							break
						panel.call("_select_tab", t)
						await _step(14, true)
						await _shot(res, 3, "menu_settings_tab%d" % t)
				_press(menu, "MenuSettingsBackButton")
				await _step(6, true)
			if _press(menu, "HelpButton"):
				await _step(16, true)
				await _shot(res, 4, "menu_help")
				_press(menu, "CloseInfoButton")
				await _step(6, true)
			# The baseline quit button exits immediately — only press it when the
			# build exposes the confirm flow (request_quit), or the run would end.
			if full and menu.has_method("request_quit") and _press(menu, "QuitButton"):
				await _step(14, true)
				await _shot(res, 5, "menu_quit_confirm")
				_press(menu, "QuitCancelButton")
				await _step(6, true)
			menu.queue_free()
			await _step(6, true)

		# ------------------------------------------------------- LAN lobby
		if _want("lan") and (full or res == Vector2i(844, 390) or res == Vector2i(720, 1280)):
			var lobby: Node = (load("res://scenes/multiplayer/lan_lobby.tscn") as PackedScene).instantiate()
			root.add_child(lobby)
			await _step(30, true)
			await _shot(res, 6, "lan_lobby")
			lobby.queue_free()
			await _step(6, true)

		# --------------------------------------------------------- driving
		if _want("driving"):
			SettingsManager.set_selected_vehicle(2)
			var main: Node = (load("res://scenes/main/main_driving_template.tscn") as PackedScene).instantiate()
			root.add_child(main)
			await _step(50)
			var hud: VehicleHud = main.hud
			var car: SaipaVehicleController = main.vehicle
			car.read_desktop_input = false
			await _shot(res, 10, "hud_start")
			hud.btn_throttle.set_simulated_press(true)
			await _step(150)
			await _shot(res, 11, "hud_speed")
			hud.btn_throttle.set_simulated_press(false)
			await _step(30)
			if full:
				hud.steer_ui_mode = VehicleHud.SteerUiMode.WHEEL
				await _step(8, true)
				await _shot(res, 12, "hud_wheel")
				hud.steer_ui_mode = VehicleHud.SteerUiMode.ANALOG_BAR
				await _step(8, true)
				await _shot(res, 13, "hud_analog")
				hud.steer_ui_mode = VehicleHud.SteerUiMode.BUTTONS
				await _step(4, true)
				if _press(hud, "UtilityTrayButton"):
					await _step(14, true)
					await _shot(res, 14, "hud_tools")
					if _press(hud, "QuickSettingsButton"):
						await _step(14, true)
						await _shot(res, 15, "hud_quick_settings")
						if not _press(hud, "QuickSettingsCloseButton"):
							_press(hud, "QuickSettingsButton")
						await _step(6, true)
					if hud.has_method("close_tools"):
						hud.call("close_tools")
					elif hud.find_child("UtilityTray", true, false) != null and (hud.find_child("UtilityTray", true, false) as Control).visible:
						_press(hud, "UtilityTrayButton")
					await _step(6, true)
				hud.show_toast("نمونهٔ پیام بازخورد")
				await _step(6, true)
				await _shot(res, 16, "hud_toast")
			hud.set_game_paused(true)
			await _step(14, true)
			await _shot(res, 20, "pause")
			if _press(hud, "PauseSettingsButton"):
				await _step(20, true)
				await _shot(res, 21, "pause_settings")
				_press(hud, "PauseSettingsBackButton")
				await _step(6, true)
			if full and _press(hud, "PauseMainMenuButton"):
				await _step(12, true)
				await _shot(res, 22, "pause_confirm_menu")
				_press(hud, "ConfirmNoButton")
				await _step(6, true)
			hud.set_game_paused(false)
			await _step(4, true)
			main.queue_free()
			await _step(6, true)
