extends SceneTree

## v0.2-b1 — desert circuit + identity-v2 loading screen suite.
##
## Covers the two things this build actually changed:
##   1. the map: surveyed centreline, collision ribbon, grips, spawn, countdown, sectors,
##      wrong-way and off-track telemetry;
##   2. the loading screen: the v2 module is mounted by the SceneTransition autoload, carries
##      the logotype, and shows geometry-only progress with no text anywhere.

var passed := 0
var failed := 0


func check(cond: bool, name: String, detail: String = "") -> void:
	if cond:
		passed += 1
		print("  [PASS] %s %s" % [name, detail])
	else:
		failed += 1
		push_error("  [FAIL] %s %s" % [name, detail])


func frames(n: int) -> void:
	for i in range(n):
		await physics_frame


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== DESERT CIRCUIT + LOADING SCREEN SUITE (v0.2-b1) ===")
	root.size = Vector2i(1280, 720)

	var packed: PackedScene = load("res://scenes/main/main_driving_template.tscn")
	check(packed != null, "driving_scene_loads")
	var main: Node3D = packed.instantiate()
	root.add_child(main)
	await frames(90)

	var track: DesertCircuit = main.track
	var car: SaipaVehicleController = main.vehicle
	check(track != null and car != null, "circuit_and_vehicle_bound")

	# ---- 1. surveyed centreline -------------------------------------------------------
	# v0.2-b2-tracksb: the map is racetrack.obj now, a 356 m loop.
	check(track.get_track_length() > 300.0 and track.get_track_length() < 420.0,
		"centreline_length_is_the_surveyed_loop", "(%.1f m)" % track.get_track_length())
	check(track.sample_count() >= 300, "centreline_sampled_at_1m", "(%d)" % track.sample_count())
	var spawn := track.get_spawn_transform()
	var p0: Dictionary = track._sample_at(0)
	check(Vector2(spawn.origin.x - float(p0["x"]), spawn.origin.z - float(p0["z"])).length() < 0.2,
		"spawn_sits_on_the_start_line")
	# progress must increase monotonically along the loop
	var prev := -1.0
	var monotonic := true
	var sample_n := track.sample_count()
	for k in [0, sample_n / 4, sample_n / 2, (3 * sample_n) / 4]:
		var s: Dictionary = track._sample_at(k)
		var prog := track.get_progress(Vector3(float(s["x"]), float(s["y"]), float(s["z"])))
		if prog <= prev:
			monotonic = false
		prev = prog
	check(monotonic, "progress_increases_along_the_lap")

	# ---- 2. collision surface ---------------------------------------------------------
	var dry := track.find_child("DryTrackStaticBody", true, false) as StaticBody3D
	var sand := track.find_child("SandStaticBody", true, false) as StaticBody3D
	check(dry != null and float(dry.get_meta("surface_grip", 0.0)) == 1.0, "asphalt_body_grip_1_0")
	check(sand != null and float(sand.get_meta("surface_grip", 0.0)) == 0.5, "sand_body_grip_0_5")
	var ribbon_count := 0
	var ribbon_tris := 0
	for c in dry.get_children():
		var cs := c as CollisionShape3D
		if cs != null and cs.shape is ConcavePolygonShape3D:
			ribbon_count += 1
			ribbon_tris += (cs.shape as ConcavePolygonShape3D).get_faces().size() / 3
	# 356 samples / 24 per chunk = 15 chunks, 712 tris
	check(ribbon_count >= 10, "asphalt_ribbon_chunked_for_mobile", "(%d chunks)" % ribbon_count)
	check(ribbon_tris >= 600, "asphalt_ribbon_covers_the_loop", "(%d tris)" % ribbon_tris)
	check(car.get_grounded_wheel_count() == 4, "car_spawns_on_the_new_surface")

	# ---- 3. interaction ---------------------------------------------------------------
	check(track.get_node_or_null("StartLamp0") != null and track.get_node_or_null("StartLamp4") != null,
		"five_start_gantry_lamps")
	var state := track.get_lap_state()
	check(state.has("lap") and state.has("sector") and state.has("sectors_total"), "lap_state_shape")
	check(int(state["sectors_total"]) == DesertCircuit.CHECKPOINT_COUNT, "twelve_sectors")
	# telemetry runs every physics tick: driving off the line must raise off-track
	var start_pos := car.global_position
	car.reset_vehicle(spawn)
	await frames(5)
	var off_at_spawn := bool(track.get_lap_state()["off_track"])
	check(not off_at_spawn, "on_the_line_is_not_off_track", "(pos=%s)" % car.global_position)
	check(track.off_track_depth(start_pos) < 0.0 or car.global_position != start_pos,
		"off_track_depth_negative_on_asphalt")
	# a point 20 m to the side of the line must read as off-track / sand
	var side: Dictionary = track._sample_at(300)
	var right := Vector3(cos(deg_to_rad(float(side["yaw"]))), 0.0, -sin(deg_to_rad(float(side["yaw"]))))
	var off_point := Vector3(float(side["x"]), float(side["y"]), float(side["z"])) + right * 20.0
	check(track.off_track_depth(off_point) > 5.0, "off_track_detected_beyond_the_edge",
		"(depth=%.1f m)" % track.off_track_depth(off_point))
	# wrong-way detection: feed a car facing backwards
	car.reset_vehicle(spawn)
	await frames(3)
	check(track.get_lap_state().has("wrong_way"), "wrong_way_flag_present")

	# ---- 4. loading screen mount ------------------------------------------------------
	var st := root.get_node_or_null("SceneTransition")
	check(st != null, "scene_transition_autoload_present")
	var loader: Node = null
	if st != null:
		loader = st.call("_ensure_loader")
	check(loader != null and loader is LoadingScreen, "loading_screen_mounted_by_autoload")
	if loader is LoadingScreen:
		var ls := loader as LoadingScreen
		ls.present("map", "")
		ls.set_progress(0.5, true)
		await frames(2)
		check(ls.visible, "loading_screen_presents")
		var logo := ls.find_child("Logotype", true, false) as TextureRect
		check(logo != null and logo.texture != null, "logotype_is_the_only_type")
		var rule := ls.find_child("ProgressRule", true, false) as ColorRect
		check(rule != null and rule.size.x > 1.0, "progress_is_geometry", "(%.1f px)" % (rule.size.x if rule != null else 0.0))
		# standing art rule: no text nodes at all inside the loading screen
		var texts: Array[String] = []
		var stack: Array[Node] = [ls]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			stack.append_array(n.get_children())
			if n is Label or n is RichTextLabel:
				texts.append(str(n.name))
		check(texts.is_empty(), "no_text_nodes_in_loading_screen", str(texts))
		# v0.2-b2: the brief asks for a real ~3 s dwell, simulated rather than load-dependent.
		# The module must still be on screen 2.4 s after present(), and gone 0.9 s after that
		# (3.0 s dwell + 0.32 s fade). Both edges are checked so a shortened dwell fails loudly.
		ls.present("map", "")
		var t0 := Time.get_ticks_msec() / 1000.0
		var waited := 0.0
		while waited < 2.4:
			await create_timer(0.1).timeout
			waited = Time.get_ticks_msec() / 1000.0 - t0
		check(ls.visible, "loading_dwell_holds_three_seconds",
			"(still visible at %.1f s)" % waited)
		ls.dismiss()
		await create_timer(0.9).timeout
		check(not ls.visible, "loading_screen_dismisses_after_the_dwell",
			"(hidden at %.1f s)" % (Time.get_ticks_msec() / 1000.0 - t0))

	# ---- 4a. the countdown must not run behind the loading screen ---------------------
	# v0.2-b2 regression: with the 3 s dwell in place the old flow handed the player a lap that
	# was already 1.4 s old, because start_countdown() fired during the dwell. The template now
	# waits for race_ready(); this checks the contract rather than the timing.
	main.race_ready()
	await frames(6)
	check(int(track.get_lap_state()["countdown"]) > 0, "countdown_starts_only_after_loading",
		"(countdown=%d)" % int(track.get_lap_state()["countdown"]))
	track.reset_lap()
	main.race_ready()
	track._countdown = 3
	await frames(2)

	# ---- 4b. lap chip on the HUD -------------------------------------------------------
	var hud: VehicleHud = main.hud
	check(hud.lap_label != null, "hud_lap_chip_exists")
	if hud.lap_label != null:
		var chip := hud.lap_label.get_parent().get_parent() as Control
		# the countdown is running at scene start, so the chip must already be visible
		check(chip != null and chip.visible, "lap_chip_visible_during_countdown")
		# the chip reads the live countdown digit (5..1) while the lights are on
		check(hud.lap_label.text != "" and hud.lap_label.text.length() <= 4, "lap_chip_shows_the_start_count",
			"(text='%s', countdown=%d)" % [hud.lap_label.text, int(track.get_lap_state()["countdown"])])
		# drive the clock for real: the countdown outranks the clock on the chip, so end it
		# first, then force a running lap and read the formatted value
		track._countdown = 0
		track._countdown_running = false
		track._lap_running = true
		track._lap_time = 83.456
		track._best_lap = 79.02
		hud._update_lap_chip()
		check(hud.lap_label.text.contains("01:23.46"), "lap_chip_formats_current_lap",
			"(text='%s')" % hud.lap_label.text)
		check(hud.lap_label.text.contains("01:19.02"), "lap_chip_shows_best_lap",
			"(text='%s')" % hud.lap_label.text)
		track._lap_running = false
		track._best_lap = -1.0
		track._lap_time = 0.0
		track.reset_lap()

	# ---- 5. version ---------------------------------------------------------------
	# v0.3-b2-android-lan: Build 2 Android LAN discovery/handshake fixes increment the version. CODE must
	# only ever increase, and 14 > 13 keeps Android from rejecting the upgrade.
	check(VersionInfo.BUILD == "v0.3-b2-android-lan" and VersionInfo.CODE == 14,
		"version_is_v0_3_b2_android_lan", VersionInfo.BUILD)

	print("=== DESERT CIRCUIT + LOADING SUMMARY: %d passed, %d failed ===" % [passed, failed])
	quit(0 if failed == 0 else 1)
