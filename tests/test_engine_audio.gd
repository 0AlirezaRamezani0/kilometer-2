extends SceneTree

## K2-FINAL-003: engine audio — one licensed recording per car.
## Headless VM has no audio hardware (dummy driver), so this asserts
## player STATE and file identity, not audibility. File-level sound
## character (spectral centroid / dominant frequency / peak) was
## measured on the shipped .ogg files with an offline FFT analysis;
## the numbers live in AUDIO_CREDITS.md.

var passed: int = 0
var failed: int = 0

const EXPECTED: Array[String] = [
	"res://assets/audio/engine/engine_sport_pride.ogg",
	"res://assets/audio/engine/engine_tara.ogg",
	"res://assets/audio/engine/engine_megan.ogg",
	"res://assets/audio/engine/engine_pride132.ogg",
	"res://assets/audio/engine/engine_quick.ogg",
	"res://assets/audio/engine/engine_samand.ogg",
]


func _initialize() -> void:
	await run_checks()
	print("=== ENGINE AUDIO SUMMARY: %d passed, %d failed ===" % [passed, failed])
	quit(1 if failed > 0 else 0)


func check(cond: bool, label: String, detail: String = "") -> void:
	if cond:
		passed += 1
		print("  [PASS] %s %s" % [label, detail])
	else:
		failed += 1
		push_error("  [FAIL] %s %s" % [label, detail])


func _md5(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	while not f.eof_reached():
		ctx.update(f.get_buffer(65536))
	return ctx.finish().hex_encode()


func run_checks() -> void:
	await process_frame
	SettingsManager.load_settings()

	# Every car's stream exists, loads as Ogg Vorbis and has real length.
	var hashes: Array[String] = []
	for i in range(EXPECTED.size()):
		var path := EXPECTED[i]
		check(ResourceLoader.exists(path), "stream_exists_car_%d" % i, path)
		var stream := load(path) as AudioStreamOggVorbis
		check(stream != null and stream.get_length() > 0.3, "stream_loads_car_%d" % i,
			"len=%.2fs" % (stream.get_length() if stream != null else -1.0))
		hashes.append(_md5(path))
	# All six files are byte-distinct (not one file renamed six times).
	var uniq := {}
	for h in hashes:
		uniq[h] = true
	check(uniq.size() == EXPECTED.size(), "all_six_files_distinct", "%d unique" % uniq.size())

	# Behaviour in the real driving scene.
	root.size = Vector2i(1280, 720)
	SettingsManager.set_selected_vehicle(0)
	SettingsManager.engine_volume = 0.8
	SettingsManager.save_settings()
	var main = (load("res://scenes/main/main_driving_template.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in range(20):
		await physics_frame
	await process_frame
	var audio := main.vehicle.get_node_or_null("EngineAudio") as EngineAudio
	check(audio != null, "engine_audio_attached_to_vehicle")
	if audio == null:
		return
	check(audio.get_stream_path() == EXPECTED[0], "car0_stream_mapped")
	check(audio.is_engine_playing(), "engine_playing_at_idle")

	# Pitch follows RPM: idle vs redline, smoothed but monotonic.
	# (debug overrides: the controller re-derives the real values every
	# physics tick, so they cannot be pinned from outside the node.)
	audio.debug_rpm_override = 0.12
	audio.debug_throttle_override = 0.0
	for i in range(400):
		await process_frame
		if audio.get_current_pitch() < 0.95:
			break
	var p_idle := audio.get_current_pitch()
	audio.debug_rpm_override = 1.0
	audio.debug_throttle_override = 1.0
	for i in range(600):
		await process_frame
		if audio.get_current_pitch() > 1.7:
			break
	var p_top := audio.get_current_pitch()
	check(p_top > p_idle * 1.5, "pitch_rises_with_rpm", "idle=%.2f top=%.2f" % [p_idle, p_top])

	# Load layer fades with throttle.
	var load_player := audio.get_node("EngineLoadLayer") as AudioStreamPlayer
	audio.debug_throttle_override = 0.0
	for i in range(10):
		await process_frame
	var v_idle := load_player.volume_db
	audio.debug_throttle_override = 1.0
	for i in range(10):
		await process_frame
	check(load_player.volume_db > v_idle + 10.0, "load_layer_follows_throttle",
		"%.1f -> %.1f dB" % [v_idle, load_player.volume_db])
	audio.debug_rpm_override = -1.0
	audio.debug_throttle_override = -1.0

	# Engine-volume setting: 0 stops playback, restoring resumes it.
	SettingsManager.engine_volume = 0.0
	for i in range(10):
		await process_frame
	check(not audio.is_engine_playing(), "engine_volume_zero_stops_playback")
	SettingsManager.engine_volume = 0.8
	for i in range(10):
		await process_frame
	check(audio.is_engine_playing(), "engine_volume_restore_resumes")

	# Per-car mapping across the whole catalog.
	var seen: Array[String] = []
	for i in range(6):
		main.spawn_vehicle(i)
		for k in range(5):
			await physics_frame
		var a2 := main.vehicle.get_node_or_null("EngineAudio") as EngineAudio
		check(a2 != null and a2.get_stream_path() == EXPECTED[i], "stream_mapping_car_%d" % i,
			a2.get_stream_path() if a2 != null else "missing")
		if a2 != null:
			seen.append(a2.get_stream_path())
	check(seen.size() == 6, "six_cars_six_streams")

	# Restore shared user settings for other suites.
	SettingsManager.set_selected_vehicle(0)
	SettingsManager.engine_volume = 0.8
	SettingsManager.save_settings()
