extends Node

## Kilometer 2 — Velocity Pro v6 Central Audio Manager (Autoload).
## Manages:
## - 5-bus mixer topology (Master, Music, Vehicle, SFX, UI) with hard limiter
##   on Master, dynamic Pause Low-Pass Filter on Music, and warm glue EQ/Comp
##   on Vehicle.
## - Dual-deck seamless crossfading music engine (Showroom Lounge vs Driving
##   Soundtracks) with dynamic engine-roar ducking & pause muffling.
## - 8-voice pooled UI SFX engine with hover throttling and auto-wiring for
##   Buttons, CheckButtons, OptionButtons, and HSliders.

const MUSIC_SHOWROOM := "res://assets/audio/music/music_showroom_lounge.ogg"
const MUSIC_VELOCITY := "res://assets/audio/music/music_drive_velocity.ogg"
const MUSIC_SLIPSTREAM := "res://assets/audio/music/music_drive_slipstream.ogg"

const UI_SFX := {
	"hover": "res://assets/audio/ui/ui_hover.ogg",
	"click": "res://assets/audio/ui/ui_click.ogg",
	"tab": "res://assets/audio/ui/ui_tab.ogg",
	"confirm": "res://assets/audio/ui/ui_confirm.ogg",
	"back": "res://assets/audio/ui/ui_back.ogg",
	"toggle_on": "res://assets/audio/ui/ui_toggle_on.ogg",
	"toggle_off": "res://assets/audio/ui/ui_toggle_off.ogg",
	"car_switch": "res://assets/audio/ui/ui_car_switch.ogg",
	"start_drive": "res://assets/audio/ui/ui_start_drive.ogg",
	"pause_open": "res://assets/audio/ui/ui_pause_open.ogg",
	"pause_close": "res://assets/audio/ui/ui_pause_close.ogg",
}

const UI_POOL_SIZE := 8
const BUS_MUSIC := "Music"
const BUS_VEHICLE := "Vehicle"
const BUS_SFX := "SFX"
const BUS_UI := "UI"

var _ui_streams: Dictionary = {}
var _ui_pool: Array[AudioStreamPlayer] = []
var _ui_cursor: int = 0
var _last_hover_msec: int = 0
var _last_slider_msec: int = 0

var _music_decks: Array[AudioStreamPlayer] = []
var _active_deck: int = 0
var _current_music_path: String = ""
var _music_context: String = "menu" # "menu" | "driving"
var _drive_track_cursor: int = 0
var _music_tween: Tween = null
var _muffle_tween: Tween = null
var _paused_muffled: bool = false
var _engine_duck_amount: float = 0.0
var _smoothed_duck: float = 0.0


func _ready() -> void:
	# Must run while SceneTree is paused so pause drawer UI & music muffle work smoothly.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	_preload_ui_streams()
	_build_players()
	SettingsManager.ensure_loaded()
	apply_audio_settings()


func _ensure_buses() -> void:
	# Guarantee all named buses exist even if a test runs without default_bus_layout.
	for bus_name in [BUS_MUSIC, BUS_VEHICLE, BUS_SFX, BUS_UI]:
		if AudioServer.get_bus_index(bus_name) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
	# Ensure Music bus has LowPassFilter at slot 0 for pause muffle.
	var m_idx := AudioServer.get_bus_index(BUS_MUSIC)
	if m_idx >= 0 and AudioServer.get_bus_effect_count(m_idx) == 0:
		var lpf := AudioEffectLowPassFilter.new()
		lpf.cutoff_hz = 20500.0
		lpf.resonance = 0.55
		AudioServer.add_bus_effect(m_idx, lpf, 0)


func _preload_ui_streams() -> void:
	for key in UI_SFX.keys():
		var path: String = UI_SFX[key]
		if ResourceLoader.exists(path):
			var st := load(path) as AudioStream
			if st != null:
				_ui_streams[key] = st


func _build_players() -> void:
	for i in range(2):
		var deck := AudioStreamPlayer.new()
		deck.name = "MusicDeck%d" % i
		deck.bus = BUS_MUSIC
		deck.volume_db = -80.0
		add_child(deck)
		deck.finished.connect(_on_music_deck_finished.bind(deck))
		_music_decks.append(deck)
	for i in range(UI_POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.name = "UiSfxPool%d" % i
		p.bus = BUS_UI
		add_child(p)
		_ui_pool.append(p)


func _process(delta: float) -> void:
	var d := clampf(delta, 0.001, 0.05)
	var target_duck := 0.0
	if SettingsManager.dynamic_music_ducking:
		if _paused_muffled:
			target_duck = 0.65
		else:
			target_duck = clampf(_engine_duck_amount, 0.0, 1.0) * 0.42
	_smoothed_duck = lerpf(_smoothed_duck, target_duck, 1.0 - exp(-5.0 * d))
	_apply_music_bus_gain()


func _apply_music_bus_gain() -> void:
	var m_idx := AudioServer.get_bus_index(BUS_MUSIC)
	if m_idx < 0:
		return
	var vol := clampf(SettingsManager.music_volume, 0.0, 1.0)
	if vol <= 0.005 or SettingsManager.music_track_mode == 4:
		AudioServer.set_bus_mute(m_idx, true)
		return
	AudioServer.set_bus_mute(m_idx, false)
	# Music sits tastefully below Vehicle/SFX (-3.5 dB nominal headroom), minus dynamic ducking up to -5.5 dB.
	var base_db := linear_to_db(vol) - 3.5
	var duck_db := -5.5 * _smoothed_duck
	AudioServer.set_bus_volume_db(m_idx, base_db + duck_db)


func apply_audio_settings() -> void:
	_ensure_buses()
	# Master bus
	if AudioServer.bus_count > 0:
		AudioServer.set_bus_volume_db(0, SettingsManager.master_volume_db)
		AudioServer.set_bus_mute(0, SettingsManager.master_volume_db <= -39.5)
	# Music bus
	_apply_music_bus_gain()
	# Vehicle bus
	var v_idx := AudioServer.get_bus_index(BUS_VEHICLE)
	if v_idx >= 0:
		var ev := clampf(SettingsManager.engine_volume, 0.0, 1.0)
		AudioServer.set_bus_mute(v_idx, ev <= 0.005)
		AudioServer.set_bus_volume_db(v_idx, linear_to_db(maxf(ev, 0.0001)))
	# SFX bus (tires, wind, impacts, gear shifts)
	var s_idx := AudioServer.get_bus_index(BUS_SFX)
	if s_idx >= 0:
		var sv := clampf(SettingsManager.sfx_volume, 0.0, 1.0)
		AudioServer.set_bus_mute(s_idx, sv <= 0.005)
		AudioServer.set_bus_volume_db(s_idx, linear_to_db(maxf(sv, 0.0001)))
	# UI bus
	var u_idx := AudioServer.get_bus_index(BUS_UI)
	if u_idx >= 0:
		var uv := clampf(SettingsManager.ui_volume, 0.0, 1.0)
		AudioServer.set_bus_mute(u_idx, uv <= 0.005)
		AudioServer.set_bus_volume_db(u_idx, linear_to_db(maxf(uv, 0.0001)) - 1.5)
	# Refresh active music track if user changed music mode in Settings
	_sync_music_for_context(_music_context, 0.75)


## --- Music State & Crossfader -----------------------------------------------

func play_menu_music() -> void:
	_music_context = "menu"
	_engine_duck_amount = 0.0
	set_paused_muffle(false)
	_sync_music_for_context("menu", 1.1)


func play_driving_music(rotate_auto: bool = false) -> void:
	_music_context = "driving"
	if rotate_auto:
		_drive_track_cursor = (_drive_track_cursor + 1) % 2
	set_paused_muffle(false)
	_sync_music_for_context("driving", 1.3)


func stop_music(fade_sec: float = 0.5) -> void:
	_current_music_path = ""
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween()
	for deck in _music_decks:
		if deck.playing:
			_music_tween.parallel().tween_property(deck, "volume_db", -60.0, fade_sec)
	_music_tween.tween_callback(func():
		for deck in _music_decks:
			deck.stop()
	)


func set_engine_duck(intensity_01: float) -> void:
	_engine_duck_amount = clampf(intensity_01, 0.0, 1.0)


func set_paused_muffle(paused: bool) -> void:
	_paused_muffled = paused
	var m_idx := AudioServer.get_bus_index(BUS_MUSIC)
	if m_idx < 0 or AudioServer.get_bus_effect_count(m_idx) == 0:
		return
	var lpf := AudioServer.get_bus_effect(m_idx, 0) as AudioEffectLowPassFilter
	if lpf == null:
		return
	var target_hz := 950.0 if (paused and SettingsManager.dynamic_music_ducking) else 20500.0
	if _muffle_tween != null and _muffle_tween.is_valid():
		_muffle_tween.kill()
	_muffle_tween = create_tween()
	_muffle_tween.tween_property(lpf, "cutoff_hz", target_hz, 0.28).set_trans(Tween.TRANS_SINE)


## B8: end-of-track handling. Previously play_driving_music(true) was
## never called from anywhere, so in auto mode the second driving track
## was unreachable. Now, when the active deck finishes a driving track
## in auto mode, rotate the cursor and crossfade to the other track.
## In any other mode the finished track simply restarts (its stream
## loops again via _crossfade_to), so music never dies silently.
func _on_music_deck_finished(deck: AudioStreamPlayer) -> void:
	if _music_decks.is_empty() or deck != _music_decks[_active_deck]:
		return
	if _current_music_path == "":
		return
	if _music_context == "driving" and SettingsManager.music_track_mode == 0:
		play_driving_music(true)
	else:
		_crossfade_to(_current_music_path, 0.75)


func get_current_music_path() -> String:
	return _current_music_path


func is_music_playing() -> bool:
	for d in _music_decks:
		if d.playing and d.volume_db > -55.0:
			return true
	return false


func _resolve_track_for_context(ctx: String) -> String:
	if SettingsManager.music_volume <= 0.005:
		return ""
	match SettingsManager.music_track_mode:
		0: # پویا (خودکار)
			if ctx == "menu":
				return MUSIC_SHOWROOM
			return MUSIC_VELOCITY if (_drive_track_cursor % 2 == 0) else MUSIC_SLIPSTREAM
		1: # انرژیک (Velocity)
			return MUSIC_VELOCITY
		2: # بزرگراه شب (Slipstream)
			return MUSIC_SLIPSTREAM
		3: # آرام (Lounge)
			return MUSIC_SHOWROOM
		_: # 4 = خاموش
			return ""


func _sync_music_for_context(ctx: String, fade_sec: float = 1.0) -> void:
	var target := _resolve_track_for_context(ctx)
	if target == "":
		if _current_music_path != "":
			stop_music(0.45)
		return
	if target == _current_music_path and is_music_playing():
		return
	_crossfade_to(target, fade_sec)


func _crossfade_to(path: String, fade_sec: float = 1.1) -> void:
	if not ResourceLoader.exists(path):
		return
	var stream := load(path) as AudioStreamOggVorbis
	if stream == null:
		return
	# B8: in "auto" mode the driving tracks must NOT loop — rotation to
	# the next driving track happens when the active deck emits
	# `finished` (see _on_music_deck_finished). Everything else loops.
	var is_drive_track := path == MUSIC_VELOCITY or path == MUSIC_SLIPSTREAM
	stream.loop = not (_music_context == "driving" and SettingsManager.music_track_mode == 0 and is_drive_track)
	var next_idx := 1 - _active_deck
	var out_deck := _music_decks[_active_deck]
	var in_deck := _music_decks[next_idx]
	in_deck.stream = stream
	in_deck.volume_db = -42.0
	in_deck.play()
	_active_deck = next_idx
	_current_music_path = path

	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.set_parallel(true)
	_music_tween.tween_property(in_deck, "volume_db", 0.0, fade_sec).set_trans(Tween.TRANS_SINE)
	if out_deck.playing:
		_music_tween.tween_property(out_deck, "volume_db", -52.0, fade_sec).set_trans(Tween.TRANS_SINE)
		_music_tween.chain().tween_callback(func(): out_deck.stop())


## --- UI Sound Effects -------------------------------------------------------

func play_ui(key: String, pitch_jitter: float = 0.02, volume_offset_db: float = 0.0) -> void:
	if SettingsManager.ui_volume <= 0.005:
		return
	if not _ui_streams.has(key):
		return
	if _ui_pool.is_empty():
		return
	var p := _ui_pool[_ui_cursor]
	_ui_cursor = (_ui_cursor + 1) % _ui_pool.size()
	p.stream = _ui_streams[key]
	p.volume_db = volume_offset_db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter) if pitch_jitter > 0.0 else 1.0
	p.play()


func play_ui_hover() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_hover_msec < 65:
		return
	_last_hover_msec = now
	play_ui("hover", 0.03, -2.0)


func play_ui_click() -> void:
	play_ui("click", 0.02, 0.0)


func play_ui_tab() -> void:
	play_ui("tab", 0.015, 0.0)


func play_ui_confirm() -> void:
	play_ui("confirm", 0.01, 0.5)


func play_ui_back() -> void:
	play_ui("back", 0.015, 0.0)


func play_ui_toggle(is_on: bool) -> void:
	play_ui("toggle_on" if is_on else "toggle_off", 0.015, 0.0)


func play_ui_car_switch() -> void:
	play_ui("car_switch", 0.025, 0.5)


func play_ui_start_drive() -> void:
	play_ui("start_drive", 0.0, 1.0)


func play_ui_pause(opened: bool) -> void:
	play_ui("pause_open" if opened else "pause_close", 0.01, 0.0)


func play_ui_slider_tick() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_slider_msec < 75:
		return
	_last_slider_msec = now
	play_ui("hover", 0.04, -1.0)


func play_audio_test_cue() -> void:
	# Plays a crisp UI confirmation chime so players immediately hear their settings balance.
	play_ui("confirm", 0.0, 1.5)


## Recursively attaches hover/press/toggle/slider cues to a UI subtree.
## Safe to call multiple times (tracks wired controls via metadata).
func attach_ui_sounds(root: Node) -> void:
	if root == null:
		return
	_wire_node_recursive(root)


func _wire_node_recursive(node: Node) -> void:
	if not node.has_meta("_k2_ui_audio_wired"):
		if node is CheckButton:
			var cb := node as CheckButton
			cb.set_meta("_k2_ui_audio_wired", true)
			cb.mouse_entered.connect(play_ui_hover)
			cb.toggled.connect(func(on: bool): play_ui_toggle(on))
		elif node is OptionButton:
			var ob := node as OptionButton
			ob.set_meta("_k2_ui_audio_wired", true)
			ob.mouse_entered.connect(play_ui_hover)
			ob.pressed.connect(play_ui_click)
			ob.item_selected.connect(func(_idx: int): play_ui_tab())
		elif node is Button:
			var b := node as Button
			b.set_meta("_k2_ui_audio_wired", true)
			b.mouse_entered.connect(play_ui_hover)
			var bname := b.name.to_lower()
			if "start" in bname or "resume" in bname or "host" in bname or "join" in bname:
				b.pressed.connect(play_ui_confirm)
			elif "close" in bname or "back" in bname or "quit" in bname or "exit" in bname:
				b.pressed.connect(play_ui_back)
			elif "tab" in bname or "nav" in bname:
				b.pressed.connect(play_ui_tab)
			else:
				b.pressed.connect(play_ui_click)
		elif node is HSlider:
			var sl := node as HSlider
			sl.set_meta("_k2_ui_audio_wired", true)
			sl.value_changed.connect(func(_v: float): play_ui_slider_tick())
	for child in node.get_children():
		_wire_node_recursive(child)
