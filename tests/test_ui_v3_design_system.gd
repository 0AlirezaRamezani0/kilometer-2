extends SceneTree

## Kilometer 2 — v0.1-b3 UI suite ("Proving Ground" design system).
## Guards the redesign: token contrast and size minimums, theme variations,
## Persian digits / RTL helpers, modal focus trapping and focus return, the
## confirm-before-quit flows, RTL-correct car paging, honest showroom specs,
## settings behaviour (UI scale, reduced motion, reset, domain-only apply,
## debounced save), HUD overlays inside the screen, cluster accuracy, device
## prompts, input-device broadcast, LAN lobby states and static hygiene.
## Run headless: godot --headless --path . --script res://tests/test_ui_v3_design_system.gd

var passed: int = 0
var failed: int = 0


## Test-only spy: counts graphics applications made by the panel.
class SpyPanel extends SettingsPanel:
	var gfx_calls: int = 0

	func _apply_graphics() -> void:
		gfx_calls += 1


func _initialize() -> void:
	await run_checks()
	print("=== UI V3 DESIGN SYSTEM SUMMARY: %d passed, %d failed ===" % [passed, failed])
	quit(1 if failed > 0 else 0)


func check(cond: bool, name: String, detail: String = "") -> void:
	if cond:
		passed += 1
		print("  [PASS] %s %s" % [name, detail])
	else:
		failed += 1
		push_error("  [FAIL] %s %s" % [name, detail])


func frames(n: int) -> void:
	for _i in range(n):
		await process_frame


func _lin(c: float) -> float:
	return c / 12.92 if c <= 0.04045 else pow((c + 0.055) / 1.055, 2.4)


func _lum(col: Color) -> float:
	return 0.2126 * _lin(col.r) + 0.7152 * _lin(col.g) + 0.0722 * _lin(col.b)


func _cr(a: Color, b: Color) -> float:
	var la := _lum(a)
	var lb := _lum(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


func _over(fg: Color, bg: Color) -> Color:
	return Color(fg.r * fg.a + bg.r * (1.0 - fg.a), fg.g * fg.a + bg.g * (1.0 - fg.a), fg.b * fg.a + bg.b * (1.0 - fg.a), 1.0)


func _inside(r: Rect2, canvas: Vector2) -> bool:
	return r.position.x >= -1.5 and r.position.y >= -1.5 and r.end.x <= canvas.x + 1.5 and r.end.y <= canvas.y + 1.5


func _press_action(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)


func run_checks() -> void:
	print("=== KILOMETER 2 UI V3 DESIGN SYSTEM SUITE ===")
	# The first frame resets root.size to the headless window size, so the
	# canvas is configured only after it.
	await frames(1)
	SettingsManager.load_settings()
	var saved_motion := SettingsManager.reduce_motion
	var saved_scale := SettingsManager.ui_scale
	SettingsManager.reduce_motion = true # deterministic: tweens land instantly
	SettingsManager.ui_scale = 1.0
	SettingsManager.apply_ui_scale()
	root.size = Vector2i(1280, 720)
	await frames(2)

	# ------------------------------------------------------------ tokens
	var surf := UiTheme.COLOR_SURFACE_CONTAINER
	var sky := Color("#E8EEF5")
	var glass_on_sky := _over(UiTheme.COLOR_GLASS, sky)
	var pairs := [
		[UiTheme.COLOR_ON_SURFACE, surf, 4.5, "body_on_card"],
		[UiTheme.COLOR_ON_SURFACE_VARIANT, surf, 4.5, "secondary_on_card"],
		[UiTheme.COLOR_ON_SURFACE_VARIANT, UiTheme.COLOR_SURFACE_HIGH, 4.5, "secondary_on_button"],
		[UiTheme.COLOR_ON_SURFACE_DISABLED, surf, 3.0, "inactive_text_3to1"],
		[UiTheme.COLOR_ON_PRIMARY, UiTheme.COLOR_PRIMARY_CONTAINER, 4.5, "cta_label_on_fill"],
		[UiTheme.COLOR_ON_PRIMARY, UiTheme.COLOR_PRIMARY_HOVER, 4.5, "cta_label_on_hover"],
		[UiTheme.COLOR_ON_PRIMARY, UiTheme.COLOR_PRIMARY_PRESSED, 4.5, "cta_label_on_pressed"],
		[UiTheme.COLOR_PRIMARY, surf, 4.5, "vermilion_text_on_card"],
		[UiTheme.COLOR_SUCCESS, surf, 4.5, "success_on_card"],
		[UiTheme.COLOR_WARNING, surf, 4.5, "warning_on_card"],
		[UiTheme.COLOR_ERROR, surf, 4.5, "error_on_card"],
		[UiTheme.COLOR_INFO, surf, 4.5, "info_on_card"],
		[UiTheme.COLOR_OUTLINE, surf, 3.0, "outline_non_text_3to1"],
		[UiTheme.COLOR_FOCUS, surf, 3.0, "focus_ring_vs_card"],
		[UiTheme.COLOR_FOCUS, UiTheme.COLOR_PRIMARY_CONTAINER, 3.0, "focus_ring_vs_cta"],
		[UiTheme.COLOR_ON_SURFACE, glass_on_sky, 4.5, "text_on_glass_over_sky"],
		[UiTheme.COLOR_ON_SURFACE_VARIANT, glass_on_sky, 4.5, "secondary_on_glass_over_sky"],
		[UiTheme.COLOR_ON_INVERSE_SURFACE, UiTheme.COLOR_INVERSE_SURFACE, 4.5, "toast_text"],
	]
	for p in pairs:
		var r := _cr(p[0], p[1])
		check(r >= float(p[2]), "contrast_" + str(p[3]), "(%.2f:1 >= %.1f)" % [r, float(p[2])])
	check(UiTheme.TYPE_CAPTION >= 15 and UiTheme.TYPE_BODY >= 17 and UiTheme.TYPE_LABEL >= 16, "type_scale_minimums", "(caption=%d body=%d)" % [UiTheme.TYPE_CAPTION, UiTheme.TYPE_BODY])
	check(UiTheme.TOUCH_MIN >= 56.0, "touch_min_56")
	check(is_equal_approx(SettingsManager.UI_SCALE_HANDHELD_DEFAULT, 1.2) and is_equal_approx(SettingsManager.default_ui_scale(), 1.0), "ui_scale_defaults_handheld_120_desktop_100")
	check(UiTheme.COLOR_THROTTLE != UiTheme.COLOR_BRAKE, "throttle_and_brake_colours_differ")

	var th := UiTheme.get_theme()
	check(th == UiTheme.get_theme() and th == UiTheme.make_theme(), "theme_is_shared_singleton")
	var variations := ["PrimaryButton", "SecondaryButton", "GhostButton", "DangerButton", "IconButton", "TabButton", "ChipButton",
		"DisplayLabel", "HeadlineLabel", "TitleLabel", "SectionLabel", "BodyLabel", "BodyMutedLabel", "CaptionLabel", "LabelStrong", "NumericLabel",
		"GlassPanel", "CardPanel", "SheetPanel", "DialogPanel", "HudPanel", "ToastPanel", "StatBar", "ErrorLineEdit"]
	var missing := []
	for v in variations:
		if th.get_type_variation_base(v) == &"":
			missing.append(v)
	check(missing.is_empty(), "theme_variations_defined", str(missing))
	var ring := th.get_stylebox("focus", "Button") as StyleBoxFlat
	check(ring != null and not ring.draw_center and ring.border_width_top >= 3 and ring.border_color == UiTheme.COLOR_FOCUS, "focus_ring_is_3px_white_outline")
	var cta_focus := th.get_stylebox("focus", "PrimaryButton") as StyleBoxFlat
	var tab_pressed := th.get_stylebox("pressed", "TabButton") as StyleBoxFlat
	check(cta_focus != null and tab_pressed != null and tab_pressed.border_color == UiTheme.COLOR_PRIMARY and cta_focus.border_color != tab_pressed.border_color, "focus_distinct_from_selection")

	# ------------------------------------------------------- text helpers
	check(UiTheme.fa_digits("12.5%") == "۱۲٫۵٪", "fa_digits_decimal_percent", UiTheme.fa_digits("12.5%"))
	check(UiTheme.fa_int_grouped(3650) == "۳٬۶۵۰", "fa_int_grouped", UiTheme.fa_int_grouped(3650))
	check(UiTheme.fa_percent(0.8) == "۸۰٪", "fa_percent", UiTheme.fa_percent(0.8))
	var lbl := UiTheme.label("IP این دستگاه: 10.0.0.2")
	check(lbl.text_direction == Control.TEXT_DIRECTION_RTL and lbl.layout_direction == Control.LAYOUT_DIRECTION_RTL, "persian_label_forces_rtl_paragraph")
	var ltr := UiTheme.ltr_label("192.168.1.2")
	check(ltr.text_direction == Control.TEXT_DIRECTION_LTR, "latin_runs_get_ltr_label")
	lbl.free()
	ltr.free()

	# --------------------------------------------------------- prompts
	check(InputPrompts.glyphs("brake_reverse", InputPrompts.Device.GAMEPAD) == ["LT", "X"], "gamepad_prompt_includes_brake_reverse")
	check(InputPrompts.glyphs("throttle", InputPrompts.Device.TOUCH).is_empty(), "touch_has_no_key_glyphs")
	check(InputPrompts.text("pause_game", InputPrompts.Device.KEYBOARD) == "Esc", "keyboard_pause_prompt")
	check(InputPrompts.glyphs("reset_vehicle", InputPrompts.Device.GAMEPAD).is_empty(), "unbound_action_hides_prompt")

	# ---------------------------------------------- device broadcast fix
	var dm_a := InputDeviceManager.new()
	var dm_b := InputDeviceManager.new()
	root.add_child(dm_a)
	root.add_child(dm_b)
	await frames(1)
	var got := [0, 0]
	dm_a.mode_changed.connect(func(_m: int) -> void: got[0] += 1)
	dm_b.mode_changed.connect(func(_m: int) -> void: got[1] += 1)
	InputDeviceManager.current_mode = InputDeviceManager.Mode.KEYBOARD_MOUSE
	dm_a._set_mode(InputDeviceManager.Mode.GAMEPAD)
	check(got[0] == 1 and got[1] == 1, "mode_change_reaches_every_tracker", str(got))
	InputDeviceManager.current_mode = InputDeviceManager.Mode.KEYBOARD_MOUSE
	dm_a.queue_free()
	dm_b.queue_free()
	await frames(1)

	# ---------------------------------------------- catalog vs physics
	var defaults_car := SaipaVehicleController.new()
	var def_speed := defaults_car.max_forward_speed_kmh
	var def_force := defaults_car.max_engine_force_n
	defaults_car.free()
	var drift := []
	for i in range(VehicleCatalog.get_count()):
		var e := VehicleCatalog.get_entry(i)
		var txt := FileAccess.get_file_as_string(str(e["vehicle_scene"]))
		var spd := def_speed
		var frc := def_force
		for line in txt.split("\n"):
			if line.begins_with("max_forward_speed_kmh = "):
				spd = float(line.split("=")[1])
			elif line.begins_with("max_engine_force_n = "):
				frc = float(line.split("=")[1])
		if not is_equal_approx(spd, float(e["top_speed_kmh"])) or not is_equal_approx(frc, float(e["engine_force_n"])):
			drift.append(str(e["id"]))
	check(drift.is_empty(), "catalog_specs_match_vehicle_physics", str(drift))

	# ------------------------------------------------------------- menu
	SettingsManager.set_selected_vehicle(0)
	var menu: Node = (load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	await frames(6)
	var start_btn := menu.find_child("StartDriveButton", true, false) as Button
	check(root.gui_get_focus_owner() == start_btn, "menu_initial_focus_on_cta")
	var vehicle_name := menu.find_child("VehicleName", true, false) as Label
	check(vehicle_name.text_direction == Control.TEXT_DIRECTION_RTL, "menu_vehicle_name_rtl")
	var hero := menu.find_child("HeroTelemetryBlock", true, false) as Control
	var canvas := root.get_visible_rect().size
	check(hero.get_global_rect().get_center().x > canvas.x * 0.5, "menu_hero_on_start_side")
	var primary_fills := 0
	for b in menu.find_children("*", "Button", true, false):
		if (b as Button).theme_type_variation == "PrimaryButton" and (b as Button).is_visible_in_tree():
			primary_fills += 1
	check(primary_fills == 1, "menu_single_vermilion_cta", "(primary buttons=%d)" % primary_fills)
	# Honest specs, Persian digits.
	var e0 := VehicleCatalog.get_entry(0)
	var spd_lbl := menu.find_child("SpecValue_top_speed_kmh", true, false) as Label
	check(spd_lbl != null and spd_lbl.text == UiTheme.fa_int(int(e0["top_speed_kmh"])) + " کیلومتر بر ساعت", "menu_spec_top_speed_persian", spd_lbl.text if spd_lbl != null else "null")
	var max_speed := 0.0
	for i in range(VehicleCatalog.get_count()):
		max_speed = maxf(max_speed, float(VehicleCatalog.get_entry(i)["top_speed_kmh"]))
	var bar := menu.find_child("SpecBar_top_speed_kmh", true, false) as ProgressBar
	check(bar != null and absf(bar.value - float(e0["top_speed_kmh"]) / max_speed * 100.0) < 0.5, "menu_spec_bar_fraction_of_fleet_max", "(%.1f)" % (bar.value if bar != null else -1.0))
	# RTL-correct paging: ← (left) from the CTA = next car, → = previous.
	start_btn.grab_focus()
	_press_action("ui_left")
	await frames(2)
	check(SettingsManager.selected_vehicle_index == 1, "menu_left_moves_to_next_car_rtl", "(index=%d)" % SettingsManager.selected_vehicle_index)
	_press_action("ui_right")
	await frames(2)
	check(SettingsManager.selected_vehicle_index == 0, "menu_right_moves_to_previous_car_rtl")
	_press_action("ui_page_left")
	await frames(2)
	check(SettingsManager.selected_vehicle_index == 1, "menu_lb_moves_left_next_car")
	_press_action("ui_page_right")
	await frames(2)
	check(SettingsManager.selected_vehicle_index == 0, "menu_rb_moves_right_previous_car")
	var sel_thumb := menu.find_child("VehicleThumb0", true, false) as Button
	check(sel_thumb.button_pressed and not (menu.find_child("VehicleThumb1", true, false) as Button).button_pressed, "menu_selected_card_marked")
	# Settings modal: focus moves in, cannot escape, Esc closes, focus returns.
	start_btn.grab_focus()
	(menu.find_child("MenuSettingsButton", true, false) as Button).pressed.emit()
	await frames(3)
	var overlay := menu.find_child("MenuSettingsOverlay", true, false) as Control
	var f := root.gui_get_focus_owner()
	check(f != null and overlay.is_ancestor_of(f), "settings_focus_moves_into_modal", f.name if f != null else "none")
	var escaped := false
	for side in [SIDE_TOP, SIDE_BOTTOM, SIDE_LEFT, SIDE_RIGHT]:
		(menu.find_child("MenuSettingsBackButton", true, false) as Control).grab_focus()
		for _s in range(10):
			var cur := root.gui_get_focus_owner()
			var nb := cur.find_valid_focus_neighbor(side) if cur != null else null
			if nb == null:
				break
			nb.grab_focus()
			var now := root.gui_get_focus_owner()
			if now != null and not overlay.is_ancestor_of(now):
				escaped = true
				break
	check(not escaped, "settings_focus_trapped_all_directions")
	check((menu.find_child("MenuChrome", true, false) as Control).mouse_behavior_recursive == Control.MOUSE_BEHAVIOR_DISABLED, "settings_blocks_mouse_behind")
	_press_action("ui_cancel")
	await frames(3)
	check(not overlay.visible, "esc_closes_settings")
	check(root.gui_get_focus_owner() == start_btn, "focus_returns_after_settings", str(root.gui_get_focus_owner()))
	# Quit asks first.
	(menu.find_child("QuitButton", true, false) as Button).pressed.emit()
	await frames(2)
	var quit_ov := menu.find_child("QuitConfirmOverlay", true, false) as Control
	check(quit_ov.visible and root.gui_get_focus_owner() == menu.find_child("QuitCancelButton", true, false), "menu_quit_asks_confirmation_focus_safe")
	(menu.find_child("QuitCancelButton", true, false) as Button).pressed.emit()
	await frames(2)
	check(not quit_ov.visible, "menu_quit_cancel_closes")
	# Help: device-aware tabs, credits, focus inside.
	(menu.find_child("HelpButton", true, false) as Button).pressed.emit()
	await frames(2)
	var info := menu.find_child("InfoOverlay", true, false) as Control
	f = root.gui_get_focus_owner()
	check(info.visible and f != null and info.is_ancestor_of(f), "help_opens_with_focus_inside")
	check(menu.find_child("HelpControls", true, false).get_child_count() >= 8 and menu.find_child("Credits", true, false) != null, "help_lists_controls_and_credits")
	_press_action("ui_cancel")
	await frames(2)
	check(not info.visible, "esc_closes_help")
	menu.queue_free()
	await frames(3)

	# --------------------------------------------------------- settings
	root.size = Vector2i(1280, 720)
	await frames(2)
	var host := Control.new()
	root.add_child(host)
	var spy := SpyPanel.new()
	host.add_child(spy)
	spy.size = Vector2(680, 560)
	await frames(3)
	check(spy.tab_count() == 5 and spy.find_child("SettingsTab4", true, false) != null, "settings_has_accessibility_tab")
	spy._music_vol_slider.value = 0.30
	check(spy.gfx_calls == 0, "audio_change_does_not_reapply_graphics", "(calls=%d)" % spy.gfx_calls)
	spy._gfx_option.get_button(2).pressed.emit()
	check(spy.gfx_calls == 1 and SettingsManager.graphics_tier == 2, "graphics_change_applies_once")
	spy._gfx_option.get_button(1).pressed.emit()
	spy.flush_pending()
	var cfg := ConfigFile.new()
	cfg.load(SettingsManager.SAVE_PATH)
	check(is_equal_approx(float(cfg.get_value(SettingsManager.SECTION, "music_volume", -1.0)), 0.30), "debounced_save_flushes_to_disk")
	spy._scale_slider.value = 1.25
	spy.flush_pending()
	check(is_equal_approx(root.content_scale_factor, 1.25), "ui_scale_applies_content_scale", "(%.2f)" % root.content_scale_factor)
	await frames(2)
	var scaled := root.get_visible_rect().size
	check(absf(scaled.x - 1024.0) < 1.0 and absf(scaled.y - 576.0) < 1.0, "ui_scale_shrinks_logical_canvas", str(scaled))
	spy._motion_check.button_pressed = false
	spy._motion_check.button_pressed = true
	spy.flush_pending()
	SettingsManager.reduce_motion = false
	SettingsManager.load_settings()
	check(SettingsManager.reduce_motion, "reduce_motion_persists")
	spy._do_reset()
	check(is_equal_approx(SettingsManager.music_volume, 0.55) and is_equal_approx(SettingsManager.ui_scale, 1.0) and not SettingsManager.reduce_motion and SettingsManager.graphics_tier == 1, "reset_restores_defaults")
	check(is_equal_approx(root.content_scale_factor, 1.0), "reset_restores_ui_scale")
	SettingsManager.reduce_motion = true
	spy.size = Vector2(320, 560)
	await frames(3)
	var t_row := spy.find_child("Row_reduce_motion", true, false) as BoxContainer
	check(t_row != null and not t_row.vertical, "toggle_rows_stay_inline_when_narrow")
	host.queue_free()
	await frames(2)

	# -------------------------------------------------------------- HUD
	root.size = Vector2i(1280, 720)
	await frames(2)
	SettingsManager.set_selected_vehicle(2)
	var main: Node = (load("res://scenes/main/main_driving_template.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await frames(8)
	var hud: VehicleHud = main.hud
	canvas = root.get_visible_rect().size
	var hud_root := hud.get_node("HudRoot") as Control
	# Cluster accuracy.
	hud.gauge_cluster.update_telemetry(100.0, 1.0, "D", false, false, false, 1.0, 0.0, 3)
	check(is_equal_approx(hud.gauge_cluster.rpm, SaipaVehicleController.ENGINE_REDLINE_RPM), "cluster_rpm_full_is_real_redline", "(%.0f)" % hud.gauge_cluster.rpm)
	check(hud.speed_label.text == "100" and hud.speed_unit_label.text == "کیلومتر/ساعت", "cluster_digital_speed_and_unit")
	check(hud.gear_label.text.contains("۳"), "cluster_shows_auto_gear_number", hud.gear_label.text)
	hud.gauge_cluster.update_telemetry(0.0, 0.0, "R", false, false, false)
	check(is_equal_approx(hud.gauge_cluster.rpm, SaipaVehicleController.ENGINE_IDLE_RPM) and hud.gear_label.text == "دنده عقب", "cluster_idle_and_reverse")
	check(hud.gauge_cluster._plate_sb == null, "cluster_still_borderless")
	# B (handbrake) never pauses while driving.
	var b_ev := InputEventJoypadButton.new()
	b_ev.button_index = JOY_BUTTON_B
	b_ev.pressed = true
	Input.parse_input_event(b_ev)
	await frames(2)
	var b_up := InputEventJoypadButton.new()
	b_up.button_index = JOY_BUTTON_B
	b_up.pressed = false
	Input.parse_input_event(b_up)
	await frames(1)
	check(not hud.is_game_paused, "gamepad_b_is_handbrake_not_pause")
	# Pause traps focus and blocks the HUD behind it.
	_press_action("pause_game")
	await frames(3)
	check(hud.is_game_paused and root.gui_get_focus_owner() == hud.find_child("PauseResumeButton", true, false), "pause_action_opens_drawer_focus_resume")
	check(hud_root.focus_behavior_recursive == Control.FOCUS_BEHAVIOR_DISABLED and hud_root.mouse_behavior_recursive == Control.MOUSE_BEHAVIOR_DISABLED, "pause_disables_hud_behind")
	check(hud.btn_throttle.input_blocked, "pause_blocks_touch_pedals")
	var drawer := hud.pause_overlay.get_global_rect()
	check(drawer.get_center().x > canvas.x * 0.5 and drawer.end.x <= canvas.x + 1.0, "pause_drawer_on_start_side", str(drawer))
	(hud.find_child("PauseQuitButton", true, false) as Button).pressed.emit()
	await frames(2)
	var confirm := hud.find_child("PauseConfirmBox", true, false) as Control
	check(confirm.visible and root.gui_get_focus_owner() == hud.find_child("ConfirmNoButton", true, false), "pause_quit_asks_confirmation_focus_safe")
	check((hud.find_child("ConfirmYesButton", true, false) as Button).theme_type_variation == "DangerButton", "destructive_action_uses_danger_style")
	_press_action("ui_cancel")
	await frames(2)
	check(not confirm.visible and hud.is_game_paused, "esc_closes_confirm_first")
	_press_action("ui_cancel")
	await frames(2)
	check(not hud.is_game_paused and hud_root.focus_behavior_recursive == Control.FOCUS_BEHAVIOR_INHERITED, "esc_then_resumes")
	check(not hud.btn_throttle.input_blocked, "resume_unblocks_pedals")
	# Quick settings: inside the screen, closable, blocks pedals while open.
	hud._open_sheet()
	await frames(2)
	var sheet := hud.find_child("QuickSettingsSheet", true, false) as Control
	check(sheet.is_visible_in_tree() and _inside(sheet.get_global_rect(), canvas), "quick_settings_inside_screen", str(sheet.get_global_rect()))
	check(hud.btn_throttle.input_blocked, "quick_settings_blocks_pedals")
	(hud.find_child("QuickSettingsCloseButton", true, false) as Button).pressed.emit()
	await frames(2)
	check(not sheet.is_visible_in_tree() and not hud.btn_throttle.input_blocked, "quick_settings_close_button_closes")
	# Tools: inside the screen, focus on first tile, action closes the sheet.
	hud._open_tray()
	await frames(2)
	var tray := hud.find_child("UtilityTray", true, false) as Control
	check(tray.is_visible_in_tree() and _inside(tray.get_global_rect(), canvas), "tools_sheet_inside_screen", str(tray.get_global_rect()))
	check(root.gui_get_focus_owner() == hud.headlights_button, "tools_focus_first_tile")
	hud.reset_button.pressed.emit()
	await frames(2)
	check(not tray.is_visible_in_tree(), "tool_action_closes_sheet")
	# Toast: one line for short text, inside the screen.
	hud.show_toast("آزمایش پیام کوتاه")
	await frames(3)
	var toast := hud.find_child("Toast", true, false) as Control
	check(toast.visible and toast.size.y < 64.0 and _inside(toast.get_global_rect(), canvas), "toast_single_line_inside_screen", str(toast.get_global_rect()))
	hud.show_toast("این یک پیام طولانی برای آزمایش شکستن خط در نوار پیام است که باید در چند خط و درون صفحه نمایش داده شود")
	await frames(3)
	check(toast.size.x <= canvas.x * 0.75 and _inside(toast.get_global_rect(), canvas), "toast_long_text_wraps_inside_screen", str(toast.get_global_rect()))
	main.queue_free()
	await frames(3)

	# ------------------------------------------------------------ LAN lobby
	var lobby: Node = (load("res://scenes/multiplayer/lan_lobby.tscn") as PackedScene).instantiate()
	root.add_child(lobby)
	await frames(4)
	check(root.gui_get_focus_owner() == lobby.find_child("CreateRoom", true, false), "lobby_initial_focus")
	check((lobby.find_child("CancelRoom", true, false) as Button).disabled, "lobby_cancel_disabled_when_idle")
	var join := lobby.find_child("JoinRoom", true, false) as Button
	check(join.disabled, "lobby_join_disabled_without_ip")
	var ip := lobby.find_child("IpField", true, false) as LineEdit
	ip.text = "300.1.1.1"
	ip.text_changed.emit(ip.text)
	check(not join.disabled, "lobby_join_enabled_with_text")
	join.pressed.emit()
	await frames(1)
	# Autoloads are not compile-time identifiers in --script tests; IDLE == 0.
	var lan := root.get_node("LanSession")
	check((lobby.find_child("IpError", true, false) as Label).visible and int(lan.get("state")) == 0, "lobby_invalid_ip_shows_error_no_connect")
	lobby.queue_free()
	await frames(2)

	# --------------------------------------------------------- hygiene
	var offenders := []
	var dirs := ["res://scripts/ui", "res://scripts/multiplayer", "res://scripts/main"]
	for d in dirs:
		var da := DirAccess.open(d)
		if da == null:
			continue
		for fn in da.get_files():
			if fn.ends_with(".gd"):
				var src := FileAccess.get_file_as_string(d.path_join(fn))
				if src.contains("res://assets/ui/softline") or src.contains("res://assets/ui/ville"):
					offenders.append(fn)
	check(offenders.is_empty(), "retired_ui_kits_unreferenced", str(offenders))
	var preset := FileAccess.get_file_as_string("res://export_presets.cfg")
	check(preset.contains("keystore/release_password=\"\"") and preset.contains("keystore/release_user=\"\""), "export_preset_has_no_keystore_secret")
	check(preset.contains("qa/*"), "export_excludes_qa_tools")
	# v0.3-b1-android-lan: the version lives in one place and only ever goes forward.
	check(VersionInfo.BUILD == "v0.3-b1-android-lan" and VersionInfo.CODE >= 13, "version_is_v0_3_b1_android_lan")
	check(root.get_node_or_null("SceneTransition") != null, "scene_transition_autoload_present")

	SettingsManager.reduce_motion = saved_motion
	SettingsManager.ui_scale = saved_scale
	SettingsManager.apply_ui_scale()
	SettingsManager.save_settings()
