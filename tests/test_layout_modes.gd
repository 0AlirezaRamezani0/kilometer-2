extends SceneTree

## K2-REDESIGN-002: responsive layout mode selection — feeds three
## viewport sizes into the menu and asserts the mode, the panel rect
## anchors and the pager configuration for each.

var passed: int = 0
var failed: int = 0


func _initialize() -> void:
	await run_checks()
	print("=== LAYOUT MODES SUMMARY: %d passed, %d failed ===" % [passed, failed])
	quit(1 if failed > 0 else 0)


func check(cond: bool, label: String, detail: String = "") -> void:
	if cond:
		passed += 1
		print("  [PASS] %s %s" % [label, detail])
	else:
		failed += 1
		push_error("  [FAIL] %s %s" % [label, detail])


func run_checks() -> void:
	await process_frame
	SettingsManager.load_settings()
	# v0.1-b3: geometry checks assume 100 % UI scale, whatever the persisted value.
	SettingsManager.ui_scale = 1.0
	SettingsManager.apply_ui_scale()
	SettingsManager.save_settings()
	var menu = (load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	await process_frame
	await process_frame

	# Static mode thresholds.
	check(menu.compute_layout_mode(1.78) == "LANDSCAPE", "mode_threshold_landscape")
	check(menu.compute_layout_mode(1.0) == "SQUARE", "mode_threshold_square")
	check(menu.compute_layout_mode(0.45) == "PORTRAIT", "mode_threshold_portrait")

	# v0.1-b3: assert real geometry, not literal anchor values. (v0.1-b1
	# asserted anchor_left == 0.72, the value whose RTL mirroring put the
	# "right" hero on the LEFT — the test passed while the layout was wrong.)
	# LANDSCAPE: hero card on the start (right) side, clear of the dock.
	root.size = Vector2i(1280, 720)
	for _i in range(4):
		await process_frame
	var canvas := root.get_visible_rect().size
	menu.apply_layout(canvas)
	await process_frame
	await process_frame
	check(menu.get_layout_mode() == "LANDSCAPE", "landscape_mode")
	var hr: Rect2 = menu._panel.get_global_rect()
	check(hr.get_center().x > canvas.x * 0.5 and hr.end.x <= canvas.x + 1.0, "landscape_hero_on_start_side", str(hr))
	check(not hr.intersects(menu._dock.get_global_rect()), "landscape_hero_clear_of_dock")
	check(menu._pager_grid.columns == 6, "landscape_pager_columns")
	var land_radius: float = menu._orbit_radius
	# SQUARE (1:1 window): hero still on the start side.
	root.size = Vector2i(1000, 1000)
	for _i in range(4):
		await process_frame
	canvas = root.get_visible_rect().size
	menu.apply_layout(canvas)
	await process_frame
	await process_frame
	check(menu.get_layout_mode() == "SQUARE", "square_mode")
	hr = menu._panel.get_global_rect()
	check(hr.get_center().x > canvas.x * 0.5, "square_hero_on_start_side", str(hr))
	# PORTRAIT window: hero spans the width in the lower band; 3x2 selector.
	root.size = Vector2i(720, 1600)
	for _i in range(4):
		await process_frame
	canvas = root.get_visible_rect().size
	menu.apply_layout(canvas)
	await process_frame
	await process_frame
	check(menu.get_layout_mode() == "PORTRAIT", "portrait_mode")
	hr = menu._panel.get_global_rect()
	check(hr.size.x >= canvas.x - 2.0 * 20.0 - 2.0, "portrait_panel_full_width", str(hr))
	check(hr.position.y >= canvas.y * 0.40, "portrait_panel_lower_band", str(hr))
	check(menu._pager_grid.columns == 3, "portrait_pager_two_rows", str(menu._pager_grid.columns))
	check(menu._thumb_buttons[0].custom_minimum_size.y >= 44.0, "portrait_thumb_min_height")
	check(menu._orbit_radius > land_radius, "portrait_camera_pulls_back", "portrait=%.2f landscape=%.2f" % [menu._orbit_radius, land_radius])
	root.size = Vector2i(1280, 720)
	menu.queue_free()
