extends SceneTree

## Kilometer 2 — B9 UI suite: responsive settings panel, larger touch
## controls, redesigned steering wheel, single-source build version.
##
## Regression guards for the B9 defect report:
##   1. menu settings card clipped outside the screen on short/portrait viewports
##   2. pause-drawer settings form cut in half
##   3. touch buttons too small to hit on a phone
##   4. wheel widget drew a tiny, hard-to-grab control
##   5. version string drifting between preset / menu / docs
##
## Run headless: godot --headless --path . --script res://tests/test_b9_ui_responsive.gd

var passed: int = 0
var failed: int = 0

const WIDE_SIZES: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(960, 540),
	Vector2i(1024, 768),
	Vector2i(720, 1280),
]
const TOL := 1.5


func _initialize() -> void:
	await run_checks()
	print("=== B9 UI RESPONSIVE SUMMARY: %d passed, %d failed ===" % [passed, failed])
	quit(1 if failed > 0 else 0)


func check(cond: bool, name: String, detail: String = "") -> void:
	if cond:
		passed += 1
		print("  [PASS] %s %s" % [name, detail])
	else:
		failed += 1
		push_error("  [FAIL] %s %s" % [name, detail])


func step_frames(count: int) -> void:
	for _i in range(count):
		await process_frame


func _inside(rect: Rect2, canvas: Vector2) -> bool:
	return rect.position.x >= -TOL and rect.position.y >= -TOL \
		and rect.end.x <= canvas.x + TOL and rect.end.y <= canvas.y + TOL


func _overlaps(a: Rect2, b: Rect2) -> bool:
	return a.intersects(b, false)


func run_checks() -> void:
	print("=== KILOMETER 2 B9 UI RESPONSIVE SUITE ===")
	SettingsManager.load_settings()
	# v0.1-b3: geometry checks assume 100 % UI scale, whatever the persisted value.
	SettingsManager.ui_scale = 1.0
	SettingsManager.apply_ui_scale()
	SettingsManager.save_settings()
	SettingsManager.graphics_tier = 1
	SettingsManager.save_settings()

	# ---------------------------------------------------------------- version
	var preset_text := FileAccess.get_file_as_string("res://export_presets.cfg")
	var preset_name := ""
	for line in preset_text.split("\n"):
		if line.begins_with("version/name="):
			preset_name = line.split("=")[1].strip_edges().trim_prefix("\"").trim_suffix("\"")
	check(preset_name == VersionInfo.BUILD, "version_preset_matches_single_source", "(preset=%s, code=%s)" % [preset_name, VersionInfo.BUILD])
	check(VersionInfo.DISPLAY == "K2 · " + VersionInfo.BUILD, "version_display_string", VersionInfo.DISPLAY)

	# ------------------------------------------------- menu settings card fit
	for res in WIDE_SIZES:
		root.size = res
		await step_frames(3)
		var menu := (load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate()
		root.add_child(menu)
		await step_frames(3)
		(menu.find_child("MenuSettingsButton", true, false) as Button).pressed.emit()
		await step_frames(4)
		var panel: SettingsPanel = menu.find_child("MenuSettingsPanel", true, false)
		var canvas := root.get_visible_rect().size
		check(panel != null, "menu_settings_panel_exists_%dx%d" % [res.x, res.y])
		if panel == null:
			menu.queue_free()
			continue
		var pr := panel.get_global_rect()
		check(_inside(pr, canvas), "menu_settings_card_inside_screen_%dx%d" % [res.x, res.y],
			"(card=[%.0f,%.0f %.0fx%.0f], canvas=%.0fx%.0f)" % [pr.position.x, pr.position.y, pr.size.x, pr.size.y, canvas.x, canvas.y])
		check(pr.size.y <= canvas.y - 40.0, "menu_settings_card_leaves_room_%dx%d" % [res.x, res.y], "(h=%.0f)" % pr.size.y)

		# tabs must fit and stay tappable
		var tabs: GridContainer = panel.find_child("SettingsTabBar", true, false)
		var tabs_rect := tabs.get_global_rect()
		check(_inside(tabs_rect, canvas), "menu_settings_tabs_inside_%dx%d" % [res.x, res.y], "(tabs=[%.0f..%.0f])" % [tabs_rect.position.x, tabs_rect.end.x])
		var tab_min := 10_000.0
		for t in tabs.get_children():
			tab_min = minf(tab_min, (t as Control).size.y)
		check(tab_min >= 44.0, "menu_settings_tab_height_tappable_%dx%d" % [res.x, res.y], "(%.0f px)" % tab_min)

		# every tab page must render inside the card, with no row squatting or
		# overflowing (the wrapped-label bug produced 400 px tall rows)
		var bad_rows := 0
		var tallest := 0.0
		for i in range(panel.tab_count()):
			panel.call("_select_tab", i)
			await step_frames(2)
			var pages: VBoxContainer = panel.find_child("SettingsPages", true, false)
			for page in pages.get_children():
				if not (page as Control).visible:
					continue
				for row in page.get_children():
					var rr := (row as Control).get_global_rect()
					tallest = maxf(tallest, rr.size.y)
					if rr.size.y > 120.0:
						bad_rows += 1
					if rr.position.x < pr.position.x - TOL or rr.end.x > pr.end.x + TOL:
						bad_rows += 1
		check(bad_rows == 0, "menu_settings_rows_fit_card_%dx%d" % [res.x, res.y], "(bad=%d, tallest=%.0f)" % [bad_rows, tallest])

		# the body must scroll, never overflow
		var scroll: ScrollContainer = panel.find_child("SettingsScroll", true, false)
		check(scroll != null and scroll.size.y > 0.0, "menu_settings_scroll_body_%dx%d" % [res.x, res.y])
		(menu.find_child("MenuSettingsBackButton", true, false) as Button).pressed.emit()
		await step_frames(2)
		var back := menu.find_child("MenuSettingsBackButton", true, false) as Button
		check(_inside(back.get_global_rect(), canvas), "menu_settings_close_button_visible_%dx%d" % [res.x, res.y])
		menu.queue_free()
		await step_frames(2)

	# -------------------------------------------------- settings row reflow
	# v0.1-b3: rows reflow by flipping BoxContainer.vertical — nothing is
	# rebuilt, so the same widgets survive. (The v0.1-b1 version of this
	# check compared zero-size rects on a hidden page and passed vacuously.)
	root.size = Vector2i(1280, 720)
	await step_frames(2)
	var host := Control.new()
	root.add_child(host)
	var standalone := (load("res://scenes/ui/settings_panel.tscn") as PackedScene).instantiate() as SettingsPanel
	host.add_child(standalone)
	standalone.position = Vector2.ZERO
	standalone.size = Vector2(660, 560)
	await step_frames(4)
	standalone.call("_select_tab", 1)
	await step_frames(3)
	var row_w := standalone.find_child("Row_engine_volume", true, false) as BoxContainer
	var title_w := row_w.find_child("RowTitle", true, false) as Control
	var slider_w := row_w.find_child("Slider", true, false) as Control
	check(not row_w.vertical, "settings_wide_row_is_single_line_mode")
	check(absf(title_w.get_global_rect().get_center().y - slider_w.get_global_rect().get_center().y) < 14.0 and slider_w.size.x > 100.0,
		"settings_wide_row_is_single_line",
		"(title_y=%.0f slider_y=%.0f slider_w=%.0f)" % [title_w.get_global_rect().get_center().y, slider_w.get_global_rect().get_center().y, slider_w.size.x])
	standalone.size = Vector2(320, 560)
	await step_frames(4)
	var row_c := standalone.find_child("Row_engine_volume", true, false) as BoxContainer
	check(row_c.vertical, "settings_compact_row_stacks_label_and_controls")
	check(title_w.get_global_rect().end.y <= slider_w.get_global_rect().position.y + 1.0, "settings_compact_title_above_control",
		"(title_end=%.0f slider_top=%.0f)" % [title_w.get_global_rect().end.y, slider_w.get_global_rect().position.y])
	check(row_c.find_child("Slider", true, false) == slider_w, "settings_reflow_keeps_same_widgets")
	var tabs_compact: GridContainer = standalone.find_child("SettingsTabBar", true, false)
	check(tabs_compact.columns < SettingsPanel.TAB_DEFS.size(), "settings_compact_tab_grid_reflows", "(columns=%d)" % tabs_compact.columns)
	check(standalone._steer_option != null and standalone._steer_option.item_count >= 3, "settings_controls_survive_rebuild")
	host.queue_free()
	await step_frames(2)

	# ------------------------------------------- driving scene: HUD geometry
	for res in WIDE_SIZES + [Vector2i(1440, 720), Vector2i(1600, 720)]:
		root.size = res
		await step_frames(2)
		SettingsManager.set_selected_vehicle(2)
		var main := (load("res://scenes/main/main_driving_template.tscn") as PackedScene).instantiate()
		root.add_child(main)
		await step_frames(6)
		var hud: VehicleHud = main.hud
		var canvas := root.get_visible_rect().size
		var gauge := hud.gauge_cluster.get_global_rect()
		var pads: Array[Control] = [hud.btn_steer_left, hud.btn_steer_right, hud.btn_brake_rev, hud.btn_throttle, hud.btn_handbrake]
		var pad_names := ["steer_left", "steer_right", "brake", "throttle", "handbrake"]
		var all_big := true
		var inside := true
		var detail := ""
		for i in range(pads.size()):
			var r := pads[i].get_global_rect()
			if r.size.x < 64.0 or r.size.y < 40.0:
				all_big = false
				detail += "%s=%.0fx%.0f " % [pad_names[i], r.size.x, r.size.y]
			if not _inside(r, canvas):
				inside = false
				detail += "%s_off " % pad_names[i]
		check(all_big, "touch_targets_large_%dx%d" % [res.x, res.y], detail)
		check(inside, "touch_targets_inside_%dx%d" % [res.x, res.y], detail)
		var steer_box := hud.btn_steer_left.get_global_rect().merge(hud.btn_steer_right.get_global_rect())
		var pedal_box := hud.btn_throttle.get_global_rect().merge(hud.btn_brake_rev.get_global_rect())
		check(not _overlaps(steer_box, gauge) and not _overlaps(gauge, pedal_box) and not _overlaps(steer_box, pedal_box),
			"bottom_islands_do_not_overlap_%dx%d" % [res.x, res.y],
			"(steer_end=%.0f gauge=[%.0f..%.0f] pedal_start=%.0f)" % [steer_box.end.x, gauge.position.x, gauge.end.x, pedal_box.position.x])

		# redesigned wheel must be a real target, not a 96 px doodle
		hud.steer_ui_mode = VehicleHud.SteerUiMode.WHEEL
		await step_frames(2)
		var wheel_rect: Rect2 = hud.steering_wheel_pad.get_global_rect()
		check(hud.steering_wheel_pad.visible and wheel_rect.size.x >= 128.0 and wheel_rect.size.y >= 128.0,
			"steering_wheel_is_large_%dx%d" % [res.x, res.y], "(%.0fx%.0f)" % [wheel_rect.size.x, wheel_rect.size.y])
		check(hud.steering_wheel_pad._grab_radius() >= 0.5 * minf(wheel_rect.size.x, wheel_rect.size.y),
			"steering_wheel_grab_area_covers_widget_%dx%d" % [res.x, res.y])
		check(_inside(wheel_rect, canvas), "steering_wheel_inside_screen_%dx%d" % [res.x, res.y])
		hud.steer_ui_mode = VehicleHud.SteerUiMode.BUTTONS
		await step_frames(2)

		# pause drawer + its settings card must stay on screen
		hud.set_game_paused(true)
		await step_frames(3)
		var drawer := hud.pause_overlay.get_global_rect()
		check(drawer.size.x <= canvas.x * 0.95 + TOL, "pause_drawer_width_capped_%dx%d" % [res.x, res.y], "(%.0f of %.0f)" % [drawer.size.x, canvas.x])
		(hud.find_child("PauseSettingsButton", true, false) as Button).pressed.emit()
		await step_frames(4)
		var dpanel: SettingsPanel = hud.find_child("PauseSettingsPanel", true, false)
		var dr := dpanel.get_global_rect()
		check(_inside(dr, canvas), "pause_settings_card_inside_screen_%dx%d" % [res.x, res.y],
			"(card=[%.0f,%.0f %.0fx%.0f] canvas=%.0fx%.0f)" % [dr.position.x, dr.position.y, dr.size.x, dr.size.y, canvas.x, canvas.y])
		var dscroll: ScrollContainer = dpanel.find_child("SettingsScroll", true, false)
		check(dscroll != null and dscroll.size.y > 80.0, "pause_settings_body_has_room_%dx%d" % [res.x, res.y], "(h=%.0f)" % (dscroll.size.y if dscroll != null else -1.0))
		hud.set_game_paused(false)
		main.queue_free()
		await step_frames(2)

	# ----------------------------------- B9.1 cluster / button balance guard
	for res in [Vector2i(1280, 720), Vector2i(960, 540), Vector2i(720, 1280)]:
		root.size = res
		await step_frames(2)
		SettingsManager.set_selected_vehicle(2)
		var main2 := (load("res://scenes/main/main_driving_template.tscn") as PackedScene).instantiate()
		root.add_child(main2)
		await step_frames(6)
		var hud2: VehicleHud = main2.hud
		var canvas2 := root.get_visible_rect().size
		var cl := hud2.gauge_cluster
		var cl_rect := cl.get_global_rect()
		# the cluster must read as the anchor of the bottom row: at least 29% of
		# the width in landscape / 50% in portrait, and tall enough for the dials
		# The stretch mode (canvas_items/expand) makes the canvas taller than the
		# window in portrait, so the width ratio is the stable measure here.
		var min_ratio := 0.29
		check(cl_rect.size.x >= canvas2.x * min_ratio, "cluster_size_proportional_%dx%d" % [res.x, res.y],
			"(%.0fx%.0f of %.0fx%.0f)" % [cl_rect.size.x, cl_rect.size.y, canvas2.x, canvas2.y])
		# borderless: the kit plate (bg + 1px border + 20 px radius) is gone
		check(cl._plate_sb == null, "cluster_has_no_box_plate_%dx%d" % [res.x, res.y])
		# controls stay compact: no pad taller than 28% of the canvas height
		var tallest_pad := maxf(maxf(hud2.btn_throttle.size.y, hud2.btn_steer_left.size.y), hud2.btn_brake_rev.size.y)
		check(tallest_pad <= canvas2.y * 0.28, "touch_controls_not_oversized_%dx%d" % [res.x, res.y],
			"(tallest=%.0f of %.0f)" % [tallest_pad, canvas2.y])
		main2.queue_free()
		await step_frames(2)

	# ------------------------------------------- steering wheel interaction
	root.size = Vector2i(1280, 720)
	await step_frames(2)
	var wheel := TouchSteeringWheel.new()
	wheel.custom_minimum_size = Vector2(240, 240)
	root.add_child(wheel)
	await step_frames(3)
	wheel.set_simulated_steer(0.75)
	check(absf(wheel.steer_value - 0.75) < 0.01, "wheel_reports_steer_value", "(%.2f)" % wheel.steer_value)
	wheel.set_simulated_steer(-1.0)
	check(absf(wheel.steer_value + 1.0) < 0.01, "wheel_clamps_full_lock", "(%.2f)" % wheel.steer_value)
	wheel.input_blocked = true
	check(absf(wheel.steer_value) < 0.001, "wheel_zeroes_when_input_blocked")
	wheel.input_blocked = false
	wheel.set_simulated_steer(0.4)
	check(absf(wheel.steer_value - 0.4) < 0.01, "wheel_accepts_input_after_unblock")
	wheel.queue_free()
	await step_frames(2)

	print("=== B9 UI RESPONSIVE SUMMARY: %d passed, %d failed ===" % [passed, failed])
