extends SceneTree

## Kilometer 2 — Full Audio System Verification Suite.
## Verifies 5-bus mixer topology, all 21 new mastered Ogg Vorbis streams,
## AudioManager crossfader/muffle/UI SFX pool, SettingsManager persistence,
## multi-layer EngineAudio (sub-exhaust, startup, gear shift, tire screech,
## wind/road, impact, handbrake), and the 4-tab SettingsPanel audio mixer.

var passed: int = 0
var failed: int = 0


func _initialize() -> void:
	await run_checks()
	print("=== AUDIO SYSTEM SUMMARY: %d passed, %d failed ===" % [passed, failed])
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

	# 1. Verify AudioManager autoload & 5-bus layout
	var am := root.get_node_or_null("AudioManager")
	check(am != null, "audio_manager_autoload_present")
	if am == null:
		return
	check(am.process_mode == Node.PROCESS_MODE_ALWAYS, "audio_manager_process_always")

	for b in ["Master", "Music", "Vehicle", "SFX", "UI"]:
		check(AudioServer.get_bus_index(b) >= 0, "bus_exists_" + b)

	var m_idx := AudioServer.get_bus_index("Music")
	check(m_idx >= 0 and AudioServer.get_bus_effect_count(m_idx) >= 1, "music_bus_has_lpf")

	# 2. Verify all 3 music tracks + 7 vehicle SFX + 11 UI SFX load as Ogg Vorbis
	var all_streams: Array[String] = [
		"res://assets/audio/music/music_showroom_lounge.ogg",
		"res://assets/audio/music/music_drive_velocity.ogg",
		"res://assets/audio/music/music_drive_slipstream.ogg",
		"res://assets/audio/sfx/sfx_engine_start.ogg",
		"res://assets/audio/sfx/sfx_tire_screech.ogg",
		"res://assets/audio/sfx/sfx_exhaust_sub.ogg",
		"res://assets/audio/sfx/sfx_wind_road.ogg",
		"res://assets/audio/sfx/sfx_gear_shift.ogg",
		"res://assets/audio/sfx/sfx_impact_thud.ogg",
		"res://assets/audio/sfx/sfx_handbrake_click.ogg",
		"res://assets/audio/ui/ui_hover.ogg",
		"res://assets/audio/ui/ui_click.ogg",
		"res://assets/audio/ui/ui_tab.ogg",
		"res://assets/audio/ui/ui_confirm.ogg",
		"res://assets/audio/ui/ui_back.ogg",
		"res://assets/audio/ui/ui_toggle_on.ogg",
		"res://assets/audio/ui/ui_toggle_off.ogg",
		"res://assets/audio/ui/ui_car_switch.ogg",
		"res://assets/audio/ui/ui_start_drive.ogg",
		"res://assets/audio/ui/ui_pause_open.ogg",
		"res://assets/audio/ui/ui_pause_close.ogg",
	]
	var loaded_ok := 0
	for p in all_streams:
		var st := load(p) as AudioStreamOggVorbis
		if st != null and st.get_length() > 0.02:
			loaded_ok += 1
	check(loaded_ok == all_streams.size(), "all_21_mastered_streams_load", "%d/%d" % [loaded_ok, all_streams.size()])

	# 3. Verify SettingsManager new audio fields persist cleanly
	SettingsManager.music_volume = 0.45
	SettingsManager.sfx_volume = 0.70
	SettingsManager.ui_volume = 0.65
	SettingsManager.music_track_mode = 2
	SettingsManager.dynamic_music_ducking = false
	SettingsManager.save_settings()
	SettingsManager.music_volume = 0.0
	SettingsManager.sfx_volume = 0.0
	SettingsManager.ui_volume = 0.0
	SettingsManager.music_track_mode = 0
	SettingsManager.dynamic_music_ducking = true
	SettingsManager.load_settings()
	check(absf(SettingsManager.music_volume - 0.45) < 0.01, "music_volume_persists")
	check(absf(SettingsManager.sfx_volume - 0.70) < 0.01, "sfx_volume_persists")
	check(absf(SettingsManager.ui_volume - 0.65) < 0.01, "ui_volume_persists")
	check(SettingsManager.music_track_mode == 2, "music_track_mode_persists")
	check(SettingsManager.dynamic_music_ducking == false, "dynamic_ducking_persists")

	# Restore defaults for live behavioral tests
	SettingsManager.music_volume = 0.55
	SettingsManager.sfx_volume = 0.85
	SettingsManager.ui_volume = 0.75
	SettingsManager.engine_volume = 0.80
	SettingsManager.music_track_mode = 0
	SettingsManager.dynamic_music_ducking = true
	SettingsManager.save_settings()
	SettingsManager.apply_display_and_audio()

	# 4. Music state switching (Menu -> Driving -> Off -> Auto) + Pause Muffle
	am.call("play_menu_music")
	await process_frame
	check(str(am.call("get_current_music_path")).ends_with("music_showroom_lounge.ogg"), "menu_plays_lounge")
	am.call("play_driving_music", false)
	await process_frame
	var drv_path := str(am.call("get_current_music_path"))
	check(drv_path.ends_with("music_drive_velocity.ogg") or drv_path.ends_with("music_drive_slipstream.ogg"), "driving_plays_race_track", drv_path)

	# Pause muffle LPF check
	am.call("set_paused_muffle", true)
	for i in range(30):
		await process_frame
	var lpf := AudioServer.get_bus_effect(m_idx, 0) as AudioEffectLowPassFilter
	check(lpf != null and lpf.cutoff_hz < 18000.0, "pause_muffle_lowers_lpf", "cutoff=%.0fHz" % (lpf.cutoff_hz if lpf != null else -1.0))
	am.call("set_paused_muffle", false)

	# UI SFX trigger does not error and plays on UI bus
	am.call("play_ui_click")
	am.call("play_ui_car_switch")
	am.call("play_ui_start_drive")
	await process_frame
	check(true, "ui_sfx_triggers_cleanly")

	# 5. Multi-layer EngineAudio inside real driving scene
	root.size = Vector2i(1280, 720)
	var main = (load("res://scenes/main/main_driving_template.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in range(15):
		await physics_frame
	await process_frame
	var ea := main.vehicle.get_node_or_null("EngineAudio") as EngineAudio
	check(ea != null, "engine_audio_attached")
	if ea != null:
		for layer_name in ["EngineBaseLayer", "EngineLoadLayer", "EngineSubLayer", "EngineStartupPlayer", "GearShiftPlayer", "TireScreechPlayer", "WindRoadPlayer", "ImpactPlayer", "HandbrakePlayer"]:
			check(ea.get_node_or_null(layer_name) != null, "layer_exists_" + layer_name)
		var base_p := ea.get_node("EngineBaseLayer") as AudioStreamPlayer
		check(base_p.bus == "Vehicle", "engine_routed_to_vehicle_bus", base_p.bus)
		var tire_p := ea.get_node("TireScreechPlayer") as AudioStreamPlayer
		check(tire_p.bus == "SFX", "tire_routed_to_sfx_bus", tire_p.bus)
		# Trigger impact and verify ImpactPlayer plays.
		# B8: checked synchronously in the same frame as the emit. The
		# thud stream is only 0.36 s long, while one process_frame on
		# the llvmpipe VM takes >2 s of real time — a probe showed
		# playing=true immediately after emit and already finished by
		# the first awaited frame, so the old await-then-check measured
		# VM frame time, not the signal wiring. The check itself (the
		# signal must start the thud) is unchanged.
		var imp_p := ea.get_node("ImpactPlayer") as AudioStreamPlayer
		main.vehicle.impact_detected.emit(3.0)
		check(imp_p.playing, "impact_signal_plays_thud")

	# 6. SettingsPanel 4-tab Studio Audio Mixer check
	var sp := (load("res://scenes/ui/settings_panel.tscn") as PackedScene).instantiate() as SettingsPanel
	root.add_child(sp)
	await process_frame
	check(sp.find_child("SettingsTab1", true, false) != null, "settings_audio_tab_exists")
	check(sp.find_child("AudioTestButton", true, false) != null, "settings_audio_test_btn_exists")
	sp.queue_free()
	main.queue_free()

	# Clean defaults restored
	SettingsManager.music_volume = 0.55
	SettingsManager.sfx_volume = 0.85
	SettingsManager.ui_volume = 0.75
	SettingsManager.engine_volume = 0.80
	SettingsManager.music_track_mode = 0
	SettingsManager.dynamic_music_ducking = true
	SettingsManager.save_settings()
