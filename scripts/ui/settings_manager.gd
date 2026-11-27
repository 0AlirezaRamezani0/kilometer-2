class_name SettingsManager
extends RefCounted

## Kilometer 2 persistent settings.
## Ownership rules (fix for "changing the car changes the graphics"):
## - Graphics quality is owned ONLY here. It is applied at scene start and
##   when the user edits it in Settings (main menu or pause). Spawning or
##   showing a vehicle NEVER re-applies or mutates graphics state.
## - The selected vehicle is chosen only in the main-menu showroom and is
##   locked for the whole driving session.
## v0.1-b3: UI scale + reduced motion (accessibility), a defaults table with
## reset, and granular appliers so editing one setting never re-applies the
## others (an audio slider used to re-apply the whole graphics tier).

const SAVE_PATH := "user://kilometer2_settings.cfg"
const SECTION := "kilometer2"

## UI scale range (Window.content_scale_factor). The base canvas is 1280x720;
## every screen reflows down to a 480 px tall logical canvas (150 %).
const UI_SCALE_MIN := 0.85
const UI_SCALE_MAX := 1.5
## Handheld default: a 720 px canvas on a ~6" landscape phone renders 1 px at
## ~0.55 pt, so 120 % brings body text to ~11 pt (Apple games guidance).
const UI_SCALE_HANDHELD_DEFAULT := 1.2

static var fullscreen: bool = false
static var master_volume_db: float = 0.0
static var graphics_tier: int = 1
static var cam_fov_deg: float = 55.0
static var cam_smoothing: float = 9.0
static var cam_distance_m: float = 5.15
static var cam_shake: float = 0.35
# K2-REDESIGN-002 gamepad: stick deadzone (0.05..0.35) + vibration scale.
static var joy_deadzone: float = 0.15
static var joy_vibration: float = 0.7
static var steer_mode: int = 0
# K2-FINAL-003: touch controls stay available next to a gamepad.
# Default ON; the toggle only controls their visibility.
static var show_touch_controls: bool = true
# Audio mixer levels (0..1), each mapped to its dedicated AudioBus.
static var engine_volume: float = 0.80
static var music_volume: float = 0.55
static var sfx_volume: float = 0.85
static var ui_volume: float = 0.75
## 0 = پویا (خودکار) | 1 = انرژیک (Velocity) | 2 = بزرگراه شب (Slipstream) | 3 = آرام (Lounge) | 4 = خاموش
static var music_track_mode: int = 0
static var dynamic_music_ducking: bool = true
# v0.1-b3 accessibility.
static var ui_scale: float = 1.0
static var reduce_motion: bool = false

static var show_perf: bool = false # B8: dev telemetry is opt-in, not shown to players by default
static var show_cam_diag: bool = false
static var selected_vehicle_index: int = 0
static var _loaded: bool = false
static var _defaults_applied: bool = false


static func default_ui_scale() -> float:
	return UI_SCALE_HANDHELD_DEFAULT if OS.has_feature("mobile") else 1.0


## Factory defaults for every player-facing setting (selected vehicle and
## developer overlays are not "settings" and are not reset).
static func defaults() -> Dictionary:
	return {
		"fullscreen": false,
		"master_volume_db": 0.0,
		"graphics_tier": 1,
		"cam_fov_deg": 55.0,
		"cam_smoothing": 9.0,
		"cam_distance_m": 5.15,
		"cam_shake": 0.35,
		"joy_deadzone": 0.15,
		"joy_vibration": 0.7,
		"steer_mode": 0,
		"show_touch_controls": true,
		"engine_volume": 0.80,
		"music_volume": 0.55,
		"sfx_volume": 0.85,
		"ui_volume": 0.75,
		"music_track_mode": 0,
		"dynamic_music_ducking": true,
		"ui_scale": default_ui_scale(),
		"reduce_motion": false,
	}


static func _apply_platform_defaults_once() -> void:
	if _defaults_applied:
		return
	_defaults_applied = true
	ui_scale = default_ui_scale()


static func load_settings() -> void:
	_apply_platform_defaults_once()
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		_loaded = true
		return
	fullscreen = bool(cfg.get_value(SECTION, "fullscreen", fullscreen))
	master_volume_db = clampf(float(cfg.get_value(SECTION, "master_volume_db", master_volume_db)), -40.0, 0.0)
	graphics_tier = clampi(int(cfg.get_value(SECTION, "graphics_tier", graphics_tier)), 0, 2)
	cam_fov_deg = clampf(float(cfg.get_value(SECTION, "cam_fov_deg", cam_fov_deg)), 45.0, 75.0)
	cam_smoothing = clampf(float(cfg.get_value(SECTION, "cam_smoothing", cam_smoothing)), 2.0, 20.0)
	cam_distance_m = clampf(float(cfg.get_value(SECTION, "cam_distance_m", cam_distance_m)), 3.5, 8.5)
	cam_shake = clampf(float(cfg.get_value(SECTION, "cam_shake", cam_shake)), 0.0, 1.0)
	joy_deadzone = clampf(float(cfg.get_value(SECTION, "joy_deadzone", joy_deadzone)), 0.05, 0.35)
	joy_vibration = clampf(float(cfg.get_value(SECTION, "joy_vibration", joy_vibration)), 0.0, 1.0)
	steer_mode = clampi(int(cfg.get_value(SECTION, "steer_mode", steer_mode)), 0, 2)
	show_touch_controls = bool(cfg.get_value(SECTION, "show_touch_controls", show_touch_controls))
	engine_volume = clampf(float(cfg.get_value(SECTION, "engine_volume", engine_volume)), 0.0, 1.0)
	music_volume = clampf(float(cfg.get_value(SECTION, "music_volume", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value(SECTION, "sfx_volume", sfx_volume)), 0.0, 1.0)
	ui_volume = clampf(float(cfg.get_value(SECTION, "ui_volume", ui_volume)), 0.0, 1.0)
	music_track_mode = clampi(int(cfg.get_value(SECTION, "music_track_mode", music_track_mode)), 0, 4)
	dynamic_music_ducking = bool(cfg.get_value(SECTION, "dynamic_music_ducking", dynamic_music_ducking))
	ui_scale = snappedf(clampf(float(cfg.get_value(SECTION, "ui_scale", ui_scale)), UI_SCALE_MIN, UI_SCALE_MAX), 0.05)
	reduce_motion = bool(cfg.get_value(SECTION, "reduce_motion", reduce_motion))
	show_perf = bool(cfg.get_value(SECTION, "show_perf", show_perf))
	show_cam_diag = bool(cfg.get_value(SECTION, "show_cam_diag", show_cam_diag))
	selected_vehicle_index = posmod(int(cfg.get_value(SECTION, "selected_vehicle_index", selected_vehicle_index)), VehicleCatalog.get_count())
	_loaded = true


static func ensure_loaded() -> void:
	if not _loaded:
		load_settings()


static func save_settings() -> int:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "fullscreen", fullscreen)
	cfg.set_value(SECTION, "master_volume_db", master_volume_db)
	cfg.set_value(SECTION, "graphics_tier", graphics_tier)
	cfg.set_value(SECTION, "cam_fov_deg", cam_fov_deg)
	cfg.set_value(SECTION, "cam_smoothing", cam_smoothing)
	cfg.set_value(SECTION, "cam_distance_m", cam_distance_m)
	cfg.set_value(SECTION, "cam_shake", cam_shake)
	cfg.set_value(SECTION, "joy_deadzone", joy_deadzone)
	cfg.set_value(SECTION, "joy_vibration", joy_vibration)
	cfg.set_value(SECTION, "steer_mode", steer_mode)
	cfg.set_value(SECTION, "show_touch_controls", show_touch_controls)
	cfg.set_value(SECTION, "engine_volume", engine_volume)
	cfg.set_value(SECTION, "music_volume", music_volume)
	cfg.set_value(SECTION, "sfx_volume", sfx_volume)
	cfg.set_value(SECTION, "ui_volume", ui_volume)
	cfg.set_value(SECTION, "music_track_mode", music_track_mode)
	cfg.set_value(SECTION, "dynamic_music_ducking", dynamic_music_ducking)
	cfg.set_value(SECTION, "ui_scale", ui_scale)
	cfg.set_value(SECTION, "reduce_motion", reduce_motion)
	cfg.set_value(SECTION, "show_perf", show_perf)
	cfg.set_value(SECTION, "show_cam_diag", show_cam_diag)
	cfg.set_value(SECTION, "selected_vehicle_index", selected_vehicle_index)
	return cfg.save(SAVE_PATH)


## Restores every player-facing setting to its factory default (in memory;
## callers save and apply).
static func reset_to_defaults() -> void:
	var d := defaults()
	fullscreen = d["fullscreen"]
	master_volume_db = d["master_volume_db"]
	graphics_tier = d["graphics_tier"]
	cam_fov_deg = d["cam_fov_deg"]
	cam_smoothing = d["cam_smoothing"]
	cam_distance_m = d["cam_distance_m"]
	cam_shake = d["cam_shake"]
	joy_deadzone = d["joy_deadzone"]
	joy_vibration = d["joy_vibration"]
	steer_mode = d["steer_mode"]
	show_touch_controls = d["show_touch_controls"]
	engine_volume = d["engine_volume"]
	music_volume = d["music_volume"]
	sfx_volume = d["sfx_volume"]
	ui_volume = d["ui_volume"]
	music_track_mode = d["music_track_mode"]
	dynamic_music_ducking = d["dynamic_music_ducking"]
	ui_scale = d["ui_scale"]
	reduce_motion = d["reduce_motion"]


static func set_selected_vehicle(index: int) -> void:
	ensure_loaded()
	selected_vehicle_index = posmod(index, VehicleCatalog.get_count())
	save_settings()


static func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


## Window mode only (no-op when unchanged or headless).
static func apply_window_mode() -> void:
	if DisplayServer.get_name() == "headless" or OS.has_feature("mobile"):
		return
	var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	var cur := DisplayServer.window_get_mode()
	var cur_full := cur == DisplayServer.WINDOW_MODE_FULLSCREEN or cur == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if fullscreen != cur_full:
		DisplayServer.window_set_mode(want)


## Global UI scale: canvas_items stretch multiplies by content_scale_factor,
## so every Control reflows on a smaller logical canvas.
static func apply_ui_scale() -> void:
	var tree := _tree()
	if tree == null or tree.root == null:
		return
	var s := clampf(ui_scale, UI_SCALE_MIN, UI_SCALE_MAX)
	if not is_equal_approx(tree.root.content_scale_factor, s):
		tree.root.content_scale_factor = s


static func apply_audio() -> void:
	if AudioServer.bus_count > 0:
		AudioServer.set_bus_volume_db(0, master_volume_db)
		AudioServer.set_bus_mute(0, master_volume_db <= -39.5)
	var tree := _tree()
	if tree != null and tree.root != null:
		var am := tree.root.get_node_or_null("AudioManager")
		if am != null and am.has_method("apply_audio_settings"):
			am.call("apply_audio_settings")
			return
	# Fallback direct bus updates if AudioManager isn't mounted (isolated unit tests)
	for pair in [["Music", music_volume], ["Vehicle", engine_volume], ["SFX", sfx_volume], ["UI", ui_volume]]:
		var idx := AudioServer.get_bus_index(pair[0])
		if idx >= 0:
			var v := clampf(float(pair[1]), 0.0, 1.0)
			AudioServer.set_bus_mute(idx, v <= 0.005)
			AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)))


static func apply_display_and_audio() -> void:
	ensure_loaded()
	apply_window_mode()
	apply_ui_scale()
	apply_audio()


## The ONLY place viewport render scale / MSAA are decided.
static func apply_viewport_graphics(vp: Viewport) -> void:
	ensure_loaded()
	if vp == null:
		return
	match graphics_tier:
		0: # سریع موبایل
			vp.scaling_3d_scale = 0.80
			vp.msaa_3d = Viewport.MSAA_DISABLED
		1: # متعادل
			vp.scaling_3d_scale = 1.0
			vp.msaa_3d = Viewport.MSAA_2X
		_: # کیفیت بالا
			vp.scaling_3d_scale = 1.0
			vp.msaa_3d = Viewport.MSAA_4X


static func apply_camera(rig: VehicleCameraRig) -> void:
	if rig == null:
		return
	rig.base_fov_deg = cam_fov_deg
	rig.smooth_yaw_rate = cam_smoothing
	rig.smooth_pos_rate = cam_smoothing * 2.0
	rig.follow_distance_m = cam_distance_m
	rig.shake_amount = cam_shake


static func apply_hud(hud: VehicleHud) -> void:
	if hud == null:
		return
	hud.set_touch_controls_visible(show_touch_controls)
	hud.steer_ui_mode = steer_mode as VehicleHud.SteerUiMode
	hud.set_perf_telemetry_visible(show_perf)
	hud.set_camera_diag_visible(show_cam_diag)


## Pushes camera/HUD-facing values into live systems. Graphics are NOT
## touched here: callers apply graphics explicitly at scene start or when
## the user changes the graphics option in a settings panel.
static func apply_to_systems(hud: VehicleHud, rig: VehicleCameraRig) -> void:
	ensure_loaded()
	apply_display_and_audio()
	apply_camera(rig)
	apply_hud(hud)
