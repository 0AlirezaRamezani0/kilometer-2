class_name VehicleHud
extends CanvasLayer

## Kilometer 2 — driving HUD (v0.1-b3, "Proving Ground" design system).
## Layout — touch ergonomics are deliberately NOT mirrored for RTL: steering
## stays under the left thumb and the pedals under the right.
##   top     vehicle chip (start) · status chips (timer, surface, damage,
##           ghost, perf) · tools / pause buttons (end)
##   bottom  steering zone · instrument cluster · pedals
## Overlays live on OverlayRoot (a sibling of HudRoot) and run on a
## UiModalStack: tools sheet, quick-settings sheet, pause drawer (start
## side) with its settings view, and the confirmation dialog. Opening one
## traps focus, blocks the touch pedals and is closed by Esc / B / its close
## button; focus returns where it was.
## Still NO vehicle switching and NO camera switching in the HUD.

## B9: minimum comfortable thumb target (Material/Apple HIG floor is 44-48).
const CONTROL_SAFE_INSET := 14.0
const TOUCH_TARGET_MIN := 64.0
const TOUCH_TARGET_MAX := 168.0
const PAUSE_DRAWER_WIDTH := 440.0
const PAUSE_DRAWER_MAX_RATIO := 0.92
const GAMEPAD_HINT_SECONDS := 8.0
const TOAST_SECONDS := 2.6

enum SteerUiMode {
	BUTTONS = 0,
	WHEEL = 1,
	ANALOG_BAR = 2,
}

@export var steer_ui_mode: SteerUiMode = SteerUiMode.BUTTONS:
	set(value):
		steer_ui_mode = value
		_apply_steer_mode_visibility()

var vehicle: SaipaVehicleController = null
var camera_rig: VehicleCameraRig = null
var track_ref: DesertCircuit = null
var main_ref: Node = null

var graphics_quality_tier: int = 1
var show_perf_telemetry: bool = false # opt-in dev telemetry
var _perf_refresh_accum: float = 0.0
var _diag_refresh_accum: float = 0.0

var is_game_paused: bool = false
var _device_manager: InputDeviceManager = null
var _gamepad_hint: PanelContainer = null
var _gamepad_hint_timer: float = 0.0
var _touch_controls_visible: bool = true
var pause_overlay: PanelContainer = null
var _pause_layer: Control = null
var _pause_main_box: VBoxContainer = null
var _pause_settings_panel: SettingsPanel = null
var _pause_settings_box: VBoxContainer = null
var _pause_resume_btn: Button = null
var _confirm_box: Control = null
var _confirm_card: PanelContainer = null
var _confirm_title: Label = null
var _confirm_text_label: Label = null
var _confirm_yes: Button = null
var _confirm_no: Button = null
var _pending_confirm_action: String = ""
var cam_diag_label: Label = null

var speed_label: Label
var speed_unit_label: Label
var gear_label: Label
var grip_label: Label
var perf_label: Label
var vehicle_label: Label
var timer_label: Label
## v0.2-b1 circle-time chip: the desert circuit's live lap clock (current · best).
var lap_label: Label
var _lap_chip: PanelContainer = null
var ghost_delta_label: Label
var damage_label: Label
var reset_button: Button
var pause_button: Button
var tools_button: Button
var headlights_button: Button
var steer_buttons_box: HBoxContainer
var btn_steer_left: TouchPedalButton
var btn_steer_right: TouchPedalButton
var steering_wheel_pad: TouchSteeringWheel
var analog_steer_bar: TouchAnalogSteerBar
var gauge_cluster: PersianGaugeCluster
var btn_handbrake: TouchPedalButton
var btn_brake_rev: TouchPedalButton
var btn_throttle: TouchPedalButton

var _root: Control = null
var _overlay_root: Control = null
var _top_bar: Control = null
var _steer_zone: Control = null
var _pedal_col: VBoxContainer = null
var _grip_chip: PanelContainer = null
var _damage_chip: PanelContainer = null
var _ghost_chip: PanelContainer = null
var _perf_chip: PanelContainer = null
var _tray: PanelContainer = null
var _tray_layer: Control = null
var _tray_open: bool = false
var _sheet: PanelContainer = null
var _sheet_layer: Control = null
var _sheet_open: bool = false
var _quick_gfx_opt: SettingsPanel.Segmented = null
var _quick_dist_slider: HSlider = null
var _quick_dist_value: Label = null
var _quick_shake_slider: HSlider = null
var _quick_shake_value: Label = null
var _replay_active: bool = false
var _vignette: ColorRect = null
var _impact_chip: PanelContainer = null
var _impact_label: Label = null
var _toast: PanelContainer = null
var _toast_label: Label = null
var _toast_icon: UiIcon = null
var _toast_timer: float = 0.0
var _photo_hint: PanelContainer = null
var _flash: ColorRect = null
var _session_time: float = 0.0
var _idle_time: float = 0.0
var _faded: bool = false
var damage_percent: float = 0.0
var _modals: UiModalStack = null

# Photo mode (F1)
var photo_mode: bool = false
var _photo_cam: Camera3D = null
var _photo_yaw: float = 0.0
var _photo_pitch: float = 0.32
var _photo_dist: float = 7.0
var _photo_dragging: bool = false
var _photo_moved: float = 0.0
var _photo_touch_id: int = -1
var _photo_touch_moved: float = 0.0
var _photo_last_capture_msec: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 105
	VehicleInputMap.ensure_actions()
	_build_ui()
	_apply_steer_mode_visibility()
	# Input-device tracking (gamepad prompts, keyboard letters on pads).
	_device_manager = InputDeviceManager.new()
	_device_manager.name = "InputDeviceManager"
	add_child(_device_manager)
	_device_manager.mode_changed.connect(_apply_input_mode)
	SettingsManager.ensure_loaded()
	_touch_controls_visible = SettingsManager.show_touch_controls
	_apply_input_mode(InputDeviceManager.current_mode)
	var am := get_node_or_null("/root/AudioManager")
	if am != null and am.has_method("attach_ui_sounds"):
		am.call("attach_ui_sounds", self)
	_play_intro()


## HUD entrance — the bar drops in, the cluster fades up. One-shot, ≤ 320 ms,
## visual only; instant under reduced motion.
func _play_intro() -> void:
	var d := UiTheme.motion_sec(UiTheme.MOTION_SLOW_MS)
	if _top_bar == null or d <= 0.0:
		return
	_top_bar.offset_transform_enabled = true
	_top_bar.offset_transform_position = Vector2(0, -24)
	_top_bar.modulate.a = 0.0
	if gauge_cluster != null:
		gauge_cluster.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	UiTheme.ease_enter(tw.tween_property(_top_bar, "offset_transform_position", Vector2.ZERO, d))
	tw.tween_property(_top_bar, "modulate:a", 1.0, d * 0.8)
	if gauge_cluster != null:
		tw.tween_property(gauge_cluster, "modulate:a", 1.0, d).set_delay(0.06)


# =========================================================================
# Build
# =========================================================================
func _build_ui() -> void:
	_root = Control.new()
	_root.name = "HudRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiTheme.get_theme()
	add_child(_root)
	_overlay_root = Control.new()
	_overlay_root.name = "OverlayRoot"
	_overlay_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_root.theme = UiTheme.get_theme()
	add_child(_overlay_root)
	_modals = UiModalStack.new(_root)
	_modals.changed.connect(_sync_touch_input_block)

	_build_top_bar()
	_build_touch_controls()
	_build_cluster()
	_build_gamepad_hint()
	_build_feedback()
	_build_cam_diag_label(_root)
	_build_tray()
	_build_sheet()
	_build_pause_overlay()
	_build_confirm()
	_build_toast()
	_apply_responsive_control_sizes()
	get_viewport().size_changed.connect(_apply_responsive_control_sizes)
	get_viewport().size_changed.connect(_update_pause_drawer_width)


func _chip(tone: Color, icon: String, text: String, chip_name: String) -> Array:
	var chip := PanelContainer.new()
	chip.name = chip_name
	chip.add_theme_stylebox_override("panel", UiTheme.box(Color(UiTheme.COLOR_SURFACE, 0.86), UiTheme.RADIUS_FULL, Color(tone, 0.6), 1, Vector4(12, 6, 12, 6)))
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.layout_direction = Control.LAYOUT_DIRECTION_RTL
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(row)
	if not icon.is_empty():
		row.add_child(UiIcon.make(icon, 18, tone))
	var l := UiTheme.label(text, "LabelStrong")
	l.add_theme_color_override("font_color", tone if tone != UiTheme.COLOR_ON_SURFACE_VARIANT else UiTheme.COLOR_ON_SURFACE)
	row.add_child(l)
	return [chip, l]


## Live lap clock. Reads the circuit's state once per frame (no signal plumbing needed) and
## shows the running lap; the best lap joins it once the first lap is banked.
func _update_lap_chip() -> void:
	if lap_label == null or _lap_chip == null:
		return
	if track_ref == null:
		_lap_chip.visible = false
		return
	var st: Dictionary = track_ref.get_lap_state()
	var running := bool(st.get("running", false))
	var countdown := int(st.get("countdown", 0))
	_lap_chip.visible = running or countdown > 0
	if not _lap_chip.visible:
		return
	if countdown > 0:
		# start lights: show the count, then the clock takes over
		lap_label.text = str(countdown)
		lap_label.add_theme_color_override("font_color", UiTheme.COLOR_WARNING)
		return
	# LRM marks keep the two times in the order we compose them: the surrounding HUD runs
	# right-to-left, and without them the bidi algorithm swaps current and best on screen.
	var cur := "\u200E" + _fmt_lap(float(st.get("lap_time", 0.0)))
	var best := float(st.get("best_lap", -1.0))
	if best > 0.0:
		cur += "\u200E  ·  \u200E" + _fmt_lap(best)
	lap_label.text = cur
	# tone: vermilion when the last completed lap was a new personal best, amber off-track,
	# red wrong-way, otherwise neutral. The circuit owns the facts; the HUD only colours them.
	if bool(st.get("wrong_way", false)):
		lap_label.add_theme_color_override("font_color", UiTheme.COLOR_ERROR)
	elif bool(st.get("off_track", false)):
		lap_label.add_theme_color_override("font_color", UiTheme.COLOR_WARNING)
	elif bool(st.get("last_was_best", false)):
		lap_label.add_theme_color_override("font_color", UiTheme.COLOR_PRIMARY)
	else:
		lap_label.add_theme_color_override("font_color", UiTheme.COLOR_ON_SURFACE)


## m:ss٫cc with a Persian decimal separator, matching the instrument style.
func _fmt_lap(seconds: float) -> String:
	var t := maxf(0.0, seconds)
	var m := int(t) / 60
	var sec := t - float(m * 60)
	return "%02d:%05.2f" % [m, sec]


func _build_top_bar() -> void:
	var top := MarginContainer.new()
	_top_bar = top
	top.name = "TopBar"
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = UiTheme.SAFE_INSET
	top.offset_right = -UiTheme.SAFE_INSET
	top.offset_top = 10.0
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(top)
	var bar := HBoxContainer.new()
	bar.layout_direction = Control.LAYOUT_DIRECTION_RTL
	bar.add_theme_constant_override("separation", UiTheme.SPACE_2)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(bar)

	# Start side: the locked vehicle (no prefix — the icon says "car").
	var veh := PanelContainer.new()
	veh.name = "VehicleIsland"
	veh.theme_type_variation = "HudPanel"
	veh.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	veh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(veh)
	var veh_row := HBoxContainer.new()
	veh_row.layout_direction = Control.LAYOUT_DIRECTION_RTL
	veh_row.add_theme_constant_override("separation", UiTheme.SPACE_2)
	veh_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veh.add_child(veh_row)
	veh_row.add_child(UiIcon.make("car", 20, UiTheme.COLOR_PRIMARY))
	vehicle_label = UiTheme.label("—", "LabelStrong")
	vehicle_label.name = "VehicleNameLabel"
	veh_row.add_child(vehicle_label)

	var sp1 := Control.new()
	sp1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(sp1)

	# Centre: status chips — only exceptions are loud (surface, damage).
	var status := HBoxContainer.new()
	status.name = "StatusPill"
	status.layout_direction = Control.LAYOUT_DIRECTION_RTL
	status.add_theme_constant_override("separation", UiTheme.SPACE_2)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(status)
	var timer_chip := PanelContainer.new()
	timer_chip.name = "SessionTimerChip"
	timer_chip.theme_type_variation = "HudPanel"
	timer_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	timer_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timer_label = UiTheme.ltr_label("00:00", "NumericLabel")
	timer_label.name = "SessionTimerLabel"
	timer_label.add_theme_font_size_override("font_size", 18)
	timer_chip.add_child(timer_label)
	status.add_child(timer_chip)
	# v0.2-b1: lap clock for the desert circuit. Latin digits, same instrument treatment as
	# the speedometer; hidden until the circuit reports a running lap.
	var lap := _chip(UiTheme.COLOR_ON_SURFACE_VARIANT, "", "لاپ 00:00٫00", "LapTimeChip")
	lap_label = lap[1]
	lap_label.name = "LapTimeLabel"
	lap_label.layout_direction = Control.LAYOUT_DIRECTION_LTR
	lap[0].visible = false
	status.add_child(lap[0])
	_lap_chip = lap[0]
	var g := _chip(UiTheme.COLOR_WARNING, "alert", "سطح لغزنده", "GripChip")
	_grip_chip = g[0]
	grip_label = g[1]
	grip_label.name = "GripBadgeLabel"
	_grip_chip.visible = false
	status.add_child(_grip_chip)
	var dmg := _chip(UiTheme.COLOR_ERROR, "alert", "آسیب ۰٪", "DamageChip")
	_damage_chip = dmg[0]
	damage_label = dmg[1]
	damage_label.name = "DamageLabel"
	_damage_chip.visible = false
	status.add_child(_damage_chip)
	var gh := _chip(UiTheme.COLOR_INFO, "ghost", "", "GhostChip")
	_ghost_chip = gh[0]
	ghost_delta_label = gh[1]
	ghost_delta_label.name = "GhostDeltaLabel"
	_ghost_chip.visible = false
	status.add_child(_ghost_chip)
	var pf := _chip(UiTheme.COLOR_ON_SURFACE_VARIANT, "", "-- FPS", "PerfChip")
	_perf_chip = pf[0]
	perf_label = pf[1]
	perf_label.name = "PerfBadgeLabel"
	perf_label.text_direction = Control.TEXT_DIRECTION_LTR
	_perf_chip.visible = false
	status.add_child(_perf_chip)

	var sp2 := Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(sp2)

	# End side: tools + pause (neutral; the vermilion fill belongs to CTAs).
	var actions := HBoxContainer.new()
	actions.name = "TopActionsCluster"
	actions.layout_direction = Control.LAYOUT_DIRECTION_RTL
	actions.add_theme_constant_override("separation", UiTheme.SPACE_2)
	actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(actions)
	tools_button = UiTheme.make_button("ابزار", "UtilityTrayButton", false, Vector2(UiTheme.TOUCH_MIN, UiTheme.TOUCH_MIN), "icon", "tools")
	tools_button.set_meta("full_text", "ابزار")
	tools_button.accessibility_name = "ابزار رانندگی"
	tools_button.pressed.connect(_toggle_tray)
	actions.add_child(tools_button)
	pause_button = UiTheme.make_button("توقف", "PauseButton", false, Vector2(UiTheme.TOUCH_MIN, UiTheme.TOUCH_MIN), "icon", "pause")
	pause_button.set_meta("full_text", "توقف")
	pause_button.accessibility_name = "توقف بازی"
	pause_button.pressed.connect(func() -> void: set_game_paused(true))
	actions.add_child(pause_button)
	# Not part of keyboard/gamepad driving focus (pause has its own key).
	tools_button.focus_mode = Control.FOCUS_CLICK
	pause_button.focus_mode = Control.FOCUS_CLICK


func _build_touch_controls() -> void:
	# B9: the zone is re-derived from the real canvas size at runtime
	# (_apply_responsive_control_sizes).
	var steer_zone := Control.new()
	steer_zone.name = "SteerZone"
	steer_zone.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	steer_zone.offset_left = CONTROL_SAFE_INSET
	steer_zone.offset_top = -170.0
	steer_zone.offset_right = CONTROL_SAFE_INSET + 168.0
	steer_zone.offset_bottom = -CONTROL_SAFE_INSET
	steer_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(steer_zone)
	_steer_zone = steer_zone

	steer_buttons_box = HBoxContainer.new()
	steer_buttons_box.name = "SteerButtonsBox"
	steer_buttons_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	steer_buttons_box.add_theme_constant_override("separation", 10)
	steer_buttons_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	steer_zone.add_child(steer_buttons_box)
	btn_steer_left = _make_pad("چپ", "A", UiTheme.COLOR_ON_SURFACE, 28, "left")
	btn_steer_left.name = "SteerLeftPad"
	btn_steer_left.size_flags_vertical = Control.SIZE_SHRINK_END
	btn_steer_left.custom_minimum_size = Vector2(108, 108)
	steer_buttons_box.add_child(btn_steer_left)
	btn_steer_right = _make_pad("راست", "D", UiTheme.COLOR_ON_SURFACE, 28, "right")
	btn_steer_right.name = "SteerRightPad"
	btn_steer_right.size_flags_vertical = Control.SIZE_SHRINK_END
	btn_steer_right.custom_minimum_size = Vector2(108, 108)
	steer_buttons_box.add_child(btn_steer_right)

	steering_wheel_pad = TouchSteeringWheel.new()
	steering_wheel_pad.name = "SteeringWheelPad"
	steering_wheel_pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	steering_wheel_pad.mouse_filter = Control.MOUSE_FILTER_STOP
	steer_zone.add_child(steering_wheel_pad)

	analog_steer_bar = TouchAnalogSteerBar.new()
	analog_steer_bar.name = "AnalogSteerBar"
	analog_steer_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	analog_steer_bar.custom_minimum_size = Vector2(300, 84)
	analog_steer_bar.offset_left = -150.0
	analog_steer_bar.offset_right = 150.0
	analog_steer_bar.offset_top = -96.0
	analog_steer_bar.offset_bottom = -12.0
	steer_zone.add_child(analog_steer_bar)

	var pedal_col := VBoxContainer.new()
	pedal_col.name = "PedalColumn"
	pedal_col.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	pedal_col.offset_left = -232.0
	pedal_col.offset_top = -196.0
	pedal_col.offset_right = -CONTROL_SAFE_INSET
	pedal_col.offset_bottom = -CONTROL_SAFE_INSET
	pedal_col.add_theme_constant_override("separation", 8)
	pedal_col.alignment = BoxContainer.ALIGNMENT_END
	pedal_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(pedal_col)
	_pedal_col = pedal_col
	var hb_row := HBoxContainer.new()
	hb_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	hb_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pedal_col.add_child(hb_row)
	btn_handbrake = _make_pad("ترمز دستی", "Space", UiTheme.COLOR_HANDBRAKE, 20, "handbrake")
	btn_handbrake.name = "HandbrakePad"
	btn_handbrake.custom_minimum_size = Vector2(150, 48)
	btn_handbrake.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	hb_row.add_child(btn_handbrake)
	var pedals := HBoxContainer.new()
	pedals.name = "PedalRow"
	pedals.add_theme_constant_override("separation", 12)
	pedals.alignment = BoxContainer.ALIGNMENT_END
	pedals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pedal_col.add_child(pedals)
	btn_brake_rev = _make_pad("ترمز", "S", UiTheme.COLOR_BRAKE, 18, "brake")
	btn_brake_rev.name = "BrakeReversePad"
	btn_brake_rev.custom_minimum_size = Vector2(108, 104)
	btn_brake_rev.size_flags_vertical = Control.SIZE_SHRINK_END
	pedals.add_child(btn_brake_rev)
	btn_throttle = _make_pad("گاز", "W", UiTheme.COLOR_THROTTLE, 16, "throttle")
	btn_throttle.name = "ThrottlePad"
	btn_throttle.custom_minimum_size = Vector2(108, 140)
	btn_throttle.size_flags_vertical = Control.SIZE_SHRINK_END
	pedals.add_child(btn_throttle)


func _build_cluster() -> void:
	gauge_cluster = PersianGaugeCluster.new()
	gauge_cluster.name = "GaugeCluster"
	gauge_cluster.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	gauge_cluster.custom_minimum_size = Vector2(400, 168)
	gauge_cluster.offset_left = -200.0
	gauge_cluster.offset_right = 200.0
	gauge_cluster.offset_top = -182.0
	gauge_cluster.offset_bottom = -14.0
	gauge_cluster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(gauge_cluster)
	speed_label = gauge_cluster.speed_label
	speed_unit_label = gauge_cluster.unit_label
	gear_label = gauge_cluster.gear_caption


func _build_feedback() -> void:
	_vignette = ColorRect.new()
	_vignette.name = "DamageVignette"
	_vignette.color = Color(UiTheme.COLOR_ERROR, 0.0)
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_vignette)
	var ic := _chip(UiTheme.COLOR_ERROR, "alert", "ضربه", "ImpactChip")
	_impact_chip = ic[0]
	_impact_label = ic[1]
	_impact_label.name = "ImpactLabel"
	_impact_chip.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_impact_chip.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_impact_chip.offset_top = 84.0
	_impact_chip.modulate.a = 0.0
	_root.add_child(_impact_chip)


## B9 RESPONSIVE TOUCH CONTROLS
## Everything below is computed from the real canvas size so the thumb
## targets never collapse on small phones and never look oversized on a
## tablet. The gauge cluster is lifted above the controls when the two
## bottom islands leave too little room (regression-guarded by
## tests/test_b9_ui_responsive.gd).
func _apply_responsive_control_sizes(canvas_hint: Vector2 = Vector2.ZERO) -> void:
	var cv := canvas_hint if canvas_hint.x > 0.0 and canvas_hint.y > 0.0 else get_viewport().get_visible_rect().size
	if cv.x <= 0.0 or cv.y <= 0.0:
		return
	# Handheld safe area: HudRoot (driving chrome) is inset so thumb controls
	# and chips never sit under a cutout; edge-anchored overlays follow.
	# Zero on desktop/headless, so desktop geometry is unchanged.
	var ins := UiTheme.safe_insets(get_viewport())
	if _root != null:
		_root.offset_left = ins.x
		_root.offset_top = ins.y
		_root.offset_right = -ins.z
		_root.offset_bottom = -ins.w
	if pause_overlay != null:
		pause_overlay.offset_right = -ins.z
	if _tray != null:
		_tray.offset_left = UiTheme.SAFE_INSET + ins.x
		_tray.offset_top = 10.0 + UiTheme.TOUCH_MIN + 10.0 + ins.y
	if _photo_hint != null:
		_photo_hint.offset_bottom = -UiTheme.SAFE_INSET - 8.0 - ins.w
	cv = Vector2(cv.x - ins.x - ins.z, cv.y - ins.y - ins.w)
	var base := clampf(cv.y * 0.16, 48.0, 96.0)
	var pad_sq := clampf(base * 1.00, 52.0, 98.0)
	var pedal_w := clampf(base * 1.02, 54.0, 100.0)
	var brake_h := clampf(base * 1.00, 50.0, 96.0)
	var throttle_h := clampf(base * 1.32, 58.0, 112.0)
	var hb_h := clampf(base * 0.42, 34.0, 46.0)
	var block_h := hb_h + 8.0 + maxf(brake_h, throttle_h)
	var zone_w := pad_sq * 2.0 + 8.0
	var pedal_block_w := pedal_w * 2.0 + 10.0
	var portrait := cv.y > cv.x
	if portrait:
		zone_w = maxf(zone_w, minf(cv.x * 0.26, 210.0))
		pad_sq = maxf(pad_sq, (zone_w - 8.0) * 0.5)
	var feet := CONTROL_SAFE_INSET + block_h

	if _steer_zone != null:
		var zy := maxf(48.0, feet)
		_steer_zone.offset_left = CONTROL_SAFE_INSET
		_steer_zone.offset_right = CONTROL_SAFE_INSET + zone_w
		_steer_zone.offset_top = -zy
		_steer_zone.offset_bottom = -CONTROL_SAFE_INSET
	if btn_steer_left != null:
		btn_steer_left.custom_minimum_size = Vector2(pad_sq, pad_sq)
	if btn_steer_right != null:
		btn_steer_right.custom_minimum_size = Vector2(pad_sq, pad_sq)
	if steering_wheel_pad != null:
		steering_wheel_pad.custom_minimum_size = Vector2.ZERO
	if analog_steer_bar != null:
		var bar_h := minf(88.0, zone_w * 0.40)
		analog_steer_bar.custom_minimum_size = Vector2(zone_w, bar_h)
		analog_steer_bar.offset_left = -zone_w * 0.5
		analog_steer_bar.offset_right = zone_w * 0.5
		analog_steer_bar.offset_top = -bar_h - 4.0
		analog_steer_bar.offset_bottom = -4.0
	if _pedal_col != null:
		_pedal_col.offset_left = -(pedal_block_w + CONTROL_SAFE_INSET)
		_pedal_col.offset_right = -CONTROL_SAFE_INSET
		_pedal_col.offset_top = -feet
		_pedal_col.offset_bottom = -CONTROL_SAFE_INSET
	if btn_handbrake != null:
		btn_handbrake.custom_minimum_size = Vector2(pedal_block_w, hb_h)
	if btn_brake_rev != null:
		btn_brake_rev.custom_minimum_size = Vector2(pedal_w, brake_h)
	if btn_throttle != null:
		btn_throttle.custom_minimum_size = Vector2(pedal_w, throttle_h)

	if gauge_cluster != null:
		var gap := cv.x - 2.0 * (zone_w + pedal_block_w + CONTROL_SAFE_INSET) - 24.0
		var desired_w := minf(560.0, cv.x * (0.62 if portrait else 0.36))
		var gauge_w := desired_w
		var above_controls := gap < 260.0
		if above_controls:
			gauge_w = maxf(minf(desired_w, cv.x - 2.0 * CONTROL_SAFE_INSET), 260.0)
		else:
			gauge_w = maxf(minf(desired_w, gap), 260.0)
		var gauge_h := clampf(gauge_w * 0.47, 120.0, 210.0)
		gauge_cluster.custom_minimum_size = Vector2(gauge_w, gauge_h)
		gauge_cluster.offset_left = -gauge_w * 0.5
		gauge_cluster.offset_right = gauge_w * 0.5
		if above_controls:
			gauge_cluster.offset_bottom = -(feet + 10.0)
			gauge_cluster.offset_top = -(feet + 10.0 + gauge_h)
		else:
			gauge_cluster.offset_bottom = -10.0
			gauge_cluster.offset_top = -10.0 - gauge_h

	# Top bar: labels on the action buttons only when there is room.
	var wide := cv.x >= 1000.0
	for b in [tools_button, pause_button]:
		if b != null:
			b.text = str(b.get_meta("full_text", "")) if wide else ""
			b.tooltip_text = str(b.get_meta("full_text", ""))
	if _tray != null:
		_tray.custom_minimum_size = Vector2(minf(460.0, cv.x - 2.0 * UiTheme.SAFE_INSET), 0)
	if _sheet != null:
		_sheet.offset_right = -UiTheme.SAFE_INSET - ins.z
		_sheet.offset_left = -minf(420.0, cv.x - 2.0 * UiTheme.SAFE_INSET) - UiTheme.SAFE_INSET - ins.z
		_sheet.offset_top = 10.0 + UiTheme.TOUCH_MIN + 10.0 + ins.y


func _make_pad(text: String, sub: String, accent: Color, radius: int, kind: String = "") -> TouchPedalButton:
	var p := TouchPedalButton.new()
	p.label_text = text
	p.sub_label_text = sub
	p.accent_color = accent
	p.corner_radius = radius
	p.icon_kind = kind
	p.custom_minimum_size = Vector2(96, 104)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	p.accessibility_name = text
	return p


func _overlay(overlay_name: String, scrim_alpha: float = 0.0) -> Control:
	var o := Control.new()
	o.name = overlay_name
	o.visible = false
	o.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay_root.add_child(o)
	var scrim := ColorRect.new()
	scrim.name = "Scrim"
	scrim.color = Color(UiTheme.COLOR_SCRIM, scrim_alpha)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	o.add_child(scrim)
	return o


func _sheet_header(parent: VBoxContainer, title: String, close_name: String, on_close: Callable) -> void:
	var hdr := HBoxContainer.new()
	hdr.layout_direction = Control.LAYOUT_DIRECTION_RTL
	hdr.add_theme_constant_override("separation", UiTheme.SPACE_3)
	parent.add_child(hdr)
	var h := UiTheme.make_heading(title, "TitleLabel")
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(h)
	var close := UiTheme.make_button("", close_name, false, Vector2(UiTheme.TOUCH_MIN, UiTheme.TOUCH_MIN), "icon", "close")
	close.tooltip_text = "بستن"
	close.accessibility_name = "بستن"
	close.pressed.connect(on_close)
	hdr.add_child(close)


## Tools: an action sheet under the end-side buttons. Choosing a tool
## performs it and closes the sheet; Esc / B / the close button / a tap on
## the scrim also close it.
func _build_tray() -> void:
	_tray_layer = _overlay("UtilityTrayLayer", 0.25)
	(_tray_layer.get_node("Scrim") as Control).gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			_close_tray())
	_tray = PanelContainer.new()
	_tray.name = "UtilityTray"
	_tray.theme_type_variation = "SheetPanel"
	_tray.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_tray.offset_left = UiTheme.SAFE_INSET
	_tray.offset_top = 10.0 + UiTheme.TOUCH_MIN + 10.0
	_tray_layer.add_child(_tray)
	var v := VBoxContainer.new()
	v.layout_direction = Control.LAYOUT_DIRECTION_RTL
	v.add_theme_constant_override("separation", UiTheme.SPACE_4)
	_tray.add_child(v)
	_sheet_header(v, "ابزار", "UtilityTrayCloseButton", _close_tray)
	var grid := GridContainer.new()
	grid.name = "ToolGrid"
	grid.columns = 3
	grid.layout_direction = Control.LAYOUT_DIRECTION_RTL
	grid.add_theme_constant_override("h_separation", UiTheme.SPACE_2)
	grid.add_theme_constant_override("v_separation", UiTheme.SPACE_2)
	v.add_child(grid)
	headlights_button = _tool_tile(grid, "چراغ‌ها", "headlight", "HeadlightsButton", _on_headlights_pressed)
	reset_button = _tool_tile(grid, "بازنشانی خودرو", "reset", "ResetButton", _on_reset_pressed)
	_tool_tile(grid, "حالت عکس", "camera", "PhotoModeButton", enter_photo_mode)
	_tool_tile(grid, "بازپخش ۱۵ ثانیه", "replay", "ReplayButton", _on_replay_pressed)
	_tool_tile(grid, "شبح بهترین دور", "ghost", "GhostButton", _on_ghost_pressed)
	_tool_tile(grid, "تنظیم سریع", "tune", "QuickSettingsButton", func() -> void: _open_sheet())


func _tool_tile(grid: GridContainer, text: String, icon: String, btn_name: String, action: Callable) -> Button:
	var b := UiTheme.make_button(text, btn_name, false, Vector2(128, 88), "default", icon)
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", UiTheme.TYPE_CAPTION)
	b.pressed.connect(func() -> void:
		if btn_name != "QuickSettingsButton":
			_close_tray()
		action.call())
	grid.add_child(b)
	return b


func _toggle_tray() -> void:
	if _tray_open:
		_close_tray()
	else:
		_open_tray()


func _open_tray() -> void:
	if is_game_paused or photo_mode:
		return
	_sync_headlights_tile()
	_tray_open = true
	_modals.push(_tray_layer, headlights_button, _close_tray)
	var d := UiTheme.motion_sec(UiTheme.MOTION_MEDIUM_MS)
	if d > 0.0:
		_tray.offset_transform_enabled = true
		_tray.offset_transform_position = Vector2(0, -12)
		_tray_layer.modulate.a = 0.0
		var tw := _tray.create_tween()
		tw.set_parallel(true)
		tw.tween_property(_tray_layer, "modulate:a", 1.0, UiTheme.fade_sec(UiTheme.MOTION_FAST_MS + 40.0))
		UiTheme.ease_enter(tw.tween_property(_tray, "offset_transform_position", Vector2.ZERO, d))


func _close_tray() -> void:
	if not _tray_open:
		return
	_tray_open = false
	_modals.close(_tray_layer)


func _sync_headlights_tile() -> void:
	if headlights_button == null:
		return
	var on := vehicle != null and vehicle.visual_model != null and vehicle.visual_model.headlights_enabled
	headlights_button.text = "چراغ‌ها: روشن" if on else "چراغ‌ها: خاموش"


## Quick settings: a sized, scrollable side sheet on the start side with an
## explicit close button (v0.1-b1's fixed 150 px band clipped its last row
## off-screen and had no way to close it — audit A-02).
func _build_sheet() -> void:
	_sheet_layer = _overlay("QuickSettingsLayer", 0.35)
	(_sheet_layer.get_node("Scrim") as Control).gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			_close_sheet())
	_sheet = PanelContainer.new()
	_sheet.name = "QuickSettingsSheet"
	_sheet.theme_type_variation = "SheetPanel"
	_sheet.anchor_left = 1.0
	_sheet.anchor_right = 1.0
	_sheet.anchor_top = 0.0
	_sheet.anchor_bottom = 1.0
	_sheet.offset_left = -420.0 - UiTheme.SAFE_INSET
	_sheet.offset_right = -UiTheme.SAFE_INSET
	_sheet.offset_top = 10.0 + UiTheme.TOUCH_MIN + 10.0
	_sheet.offset_bottom = -UiTheme.SAFE_INSET
	_sheet_layer.add_child(_sheet)
	var v := VBoxContainer.new()
	v.layout_direction = Control.LAYOUT_DIRECTION_RTL
	v.add_theme_constant_override("separation", UiTheme.SPACE_4)
	_sheet.add_child(v)
	_sheet_header(v, "تنظیم سریع", "QuickSettingsCloseButton", _close_sheet)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	v.add_child(scroll)
	var body := VBoxContainer.new()
	body.layout_direction = Control.LAYOUT_DIRECTION_RTL
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", UiTheme.SPACE_4)
	scroll.add_child(body)
	body.add_child(UiTheme.label("کیفیت گرافیک", "LabelStrong"))
	_quick_gfx_opt = SettingsPanel.Segmented.new()
	_quick_gfx_opt.name = "QuickGraphicsOption"
	for n in SettingsPanel.GFX_NAMES:
		_quick_gfx_opt.add_item(n)
	_quick_gfx_opt.item_selected.connect(func(idx: int) -> void:
		apply_graphics_quality(idx)
		_quick_saved())
	body.add_child(_quick_gfx_opt)
	var dist := _quick_slider(body, "فاصلهٔ دوربین", "QuickCameraDistance", 3.5, 8.5, 0.1)
	_quick_dist_slider = dist[0]
	_quick_dist_value = dist[1]
	_quick_dist_slider.value_changed.connect(func(val: float) -> void:
		SettingsManager.cam_distance_m = val
		_quick_dist_value.text = UiTheme.fa_float(val, 1) + " متر"
		if camera_rig != null:
			camera_rig.follow_distance_m = val
		_quick_saved())
	var shake := _quick_slider(body, "لرزش هنگام ضربه", "QuickShakeSlider", 0.0, 1.0, 0.05)
	_quick_shake_slider = shake[0]
	_quick_shake_value = shake[1]
	_quick_shake_slider.value_changed.connect(func(val: float) -> void:
		SettingsManager.cam_shake = val
		_quick_shake_value.text = UiTheme.fa_percent(val)
		if camera_rig != null:
			camera_rig.shake_amount = val
		_quick_saved())
	var full := UiTheme.make_button("همهٔ تنظیمات", "QuickFullSettingsButton", false, Vector2(0, UiTheme.TOUCH_MIN), "secondary", "settings")
	full.pressed.connect(func() -> void:
		_close_sheet()
		set_game_paused(true)
		_on_pause_settings_pressed())
	body.add_child(full)


func _quick_slider(parent: VBoxContainer, title: String, slider_name: String, min_v: float, max_v: float, step: float) -> Array:
	var row := HBoxContainer.new()
	row.layout_direction = Control.LAYOUT_DIRECTION_RTL
	row.add_theme_constant_override("separation", UiTheme.SPACE_3)
	var t := UiTheme.label(title, "LabelStrong")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	var val := UiTheme.label("", "ValueLabel")
	row.add_child(val)
	parent.add_child(row)
	var s := HSlider.new()
	s.name = slider_name
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.custom_minimum_size = Vector2(0, 44)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.focus_mode = Control.FOCUS_ALL
	s.accessibility_name = title
	parent.add_child(s)
	return [s, val]


var _quick_save_timer: SceneTreeTimer = null


func _quick_saved() -> void:
	# Debounced save, same policy as the settings panel.
	if _quick_save_timer != null:
		return
	_quick_save_timer = get_tree().create_timer(0.35, true, false, true)
	await _quick_save_timer.timeout
	_quick_save_timer = null
	SettingsManager.save_settings()
	if _pause_settings_panel != null:
		_pause_settings_panel.refresh_from_settings()


func _sync_quick_settings_ui() -> void:
	if _quick_gfx_opt != null:
		_quick_gfx_opt.select(clampi(SettingsManager.graphics_tier, 0, 2))
	if _quick_dist_slider != null:
		_quick_dist_slider.set_value_no_signal(SettingsManager.cam_distance_m)
		_quick_dist_value.text = UiTheme.fa_float(SettingsManager.cam_distance_m, 1) + " متر"
	if _quick_shake_slider != null:
		_quick_shake_slider.set_value_no_signal(SettingsManager.cam_shake)
		_quick_shake_value.text = UiTheme.fa_percent(SettingsManager.cam_shake)


func _toggle_sheet() -> void:
	if _sheet_open:
		_close_sheet()
	else:
		_open_sheet()


func _open_sheet() -> void:
	if is_game_paused or photo_mode or _sheet_open:
		return
	_close_tray()
	_sync_quick_settings_ui()
	_sheet_open = true
	_modals.push(_sheet_layer, _quick_gfx_opt.get_button(clampi(SettingsManager.graphics_tier, 0, 2)), _close_sheet)
	var d := UiTheme.motion_sec(UiTheme.MOTION_MEDIUM_MS)
	if d > 0.0:
		_sheet.offset_transform_enabled = true
		_sheet.offset_transform_position = Vector2(40, 0)
		var tw := _sheet.create_tween()
		UiTheme.ease_enter(tw.tween_property(_sheet, "offset_transform_position", Vector2.ZERO, d))


func _close_sheet() -> void:
	if not _sheet_open:
		return
	_sheet_open = false
	_modals.close(_sheet_layer)


func _sync_touch_input_block() -> void:
	var blocked := is_game_paused or photo_mode or _replay_active or (_modals != null and not _modals.is_empty())
	for pad in [btn_throttle, btn_brake_rev, btn_handbrake, btn_steer_left, btn_steer_right]:
		if pad != null:
			pad.input_blocked = blocked
	if steering_wheel_pad != null:
		steering_wheel_pad.input_blocked = blocked
	if analog_steer_bar != null:
		analog_steer_bar.input_blocked = blocked


func _build_cam_diag_label(root: Control) -> void:
	cam_diag_label = Label.new()
	cam_diag_label.name = "CameraDiagLabel"
	cam_diag_label.visible = false
	cam_diag_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	cam_diag_label.position = Vector2(10, -118)
	cam_diag_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	cam_diag_label.theme_type_variation = "CaptionLabel"
	cam_diag_label.add_theme_color_override("font_color", UiTheme.COLOR_SUCCESS)
	root.add_child(cam_diag_label)


## Pause: a drawer on the start (right) side — the track stays visible on
## the other side. OverlayRoot is LTR, so the right anchor is literal
## (v0.1-b1 set RTL on the anchored drawer, which mirrored it to the left).
func _build_pause_overlay() -> void:
	_pause_layer = _overlay("PauseLayer", 0.0)
	var dim := _pause_layer.get_node("Scrim") as ColorRect
	dim.name = "PauseDim"
	dim.color = Color(0.012, 0.02, 0.03, 0.58)

	pause_overlay = PanelContainer.new()
	pause_overlay.name = "PauseOverlay"
	pause_overlay.theme_type_variation = "SheetPanel"
	pause_overlay.add_theme_stylebox_override("panel", UiTheme.with_shadow(UiTheme.box(Color(UiTheme.COLOR_SURFACE, 0.97), 0, UiTheme.COLOR_OUTLINE_VARIANT, 1, Vector4(28, 24, 28, 24)), 32, 0.55, 0.0))
	pause_overlay.anchor_left = 1.0
	pause_overlay.anchor_right = 1.0
	pause_overlay.anchor_top = 0.0
	pause_overlay.anchor_bottom = 1.0
	pause_overlay.offset_left = -PAUSE_DRAWER_WIDTH
	pause_overlay.offset_right = 0.0
	pause_overlay.set_meta("k2_rest_offset_left", -PAUSE_DRAWER_WIDTH)
	_pause_layer.add_child(pause_overlay)
	_update_pause_drawer_width()

	var vroot := VBoxContainer.new()
	vroot.layout_direction = Control.LAYOUT_DIRECTION_RTL
	vroot.add_theme_constant_override("separation", UiTheme.SPACE_4)
	pause_overlay.add_child(vroot)

	_pause_main_box = VBoxContainer.new()
	_pause_main_box.name = "PauseMainBox"
	_pause_main_box.layout_direction = Control.LAYOUT_DIRECTION_RTL
	_pause_main_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pause_main_box.add_theme_constant_override("separation", UiTheme.SPACE_3)
	vroot.add_child(_pause_main_box)

	var hdr := HBoxContainer.new()
	hdr.layout_direction = Control.LAYOUT_DIRECTION_RTL
	hdr.add_theme_constant_override("separation", UiTheme.SPACE_3)
	_pause_main_box.add_child(hdr)
	var title := UiTheme.make_heading("توقف", "HeadlineLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(title)
	hdr.add_child(InputPrompts.PromptChip.new("pause_game", "ادامه"))

	_pause_resume_btn = UiTheme.make_button("ادامهٔ رانندگی", "PauseResumeButton", true, Vector2(0, UiTheme.CONTROL_HEIGHT_LG), "primary", "play")
	_pause_resume_btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_pause_resume_btn.pressed.connect(func() -> void: set_game_paused(false))
	_pause_main_box.add_child(_pause_resume_btn)

	var list := VBoxContainer.new()
	list.name = "PauseActions"
	list.add_theme_constant_override("separation", UiTheme.SPACE_2)
	_pause_main_box.add_child(list)
	_pause_item(list, "بازنشانی خودرو روی پیست", "reset", "PauseResetButton", _on_pause_reset_pressed)
	_pause_item(list, "شروع دوبارهٔ جلسه", "restart", "PauseRestartButton", func() -> void: _ask_confirmation("restart"))
	_pause_item(list, "تنظیمات", "settings", "PauseSettingsButton", _on_pause_settings_pressed)

	var p_spacer := Control.new()
	p_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pause_main_box.add_child(p_spacer)
	_pause_main_box.add_child(HSeparator.new())
	var footer := VBoxContainer.new()
	footer.add_theme_constant_override("separation", UiTheme.SPACE_2)
	_pause_main_box.add_child(footer)
	_pause_item(footer, "بازگشت به نمایشگاه", "home", "PauseMainMenuButton", func() -> void: _ask_confirmation("main_menu"), "ghost")
	_pause_item(footer, "خروج از بازی", "power", "PauseQuitButton", func() -> void: _ask_confirmation("quit"), "ghost")

	var settings_scene := load("res://scenes/ui/settings_panel.tscn") as PackedScene
	if settings_scene != null:
		_pause_settings_box = VBoxContainer.new()
		_pause_settings_box.name = "PauseSettingsBox"
		_pause_settings_box.visible = false
		_pause_settings_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_pause_settings_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vroot.add_child(_pause_settings_box)
		_pause_settings_panel = settings_scene.instantiate() as SettingsPanel
		_pause_settings_panel.name = "PauseSettingsPanel"
		_pause_settings_panel.custom_minimum_size = Vector2(260, 220)
		_pause_settings_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_pause_settings_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_pause_settings_box.add_child(_pause_settings_panel)
		# Inside the drawer the panel is flat (the drawer is the surface).
		_pause_settings_panel.add_theme_stylebox_override("panel", UiTheme.box(Color(0, 0, 0, 0), 0, Color(0, 0, 0, 0), 0, Vector4.ZERO))
		_pause_settings_panel.close_button.name = "PauseSettingsBackButton"
		_pause_settings_panel.close_button.text = "بازگشت"
		_pause_settings_panel.close_button.icon = UiIcon.texture("back")
		_pause_settings_panel.close_requested.connect(_on_pause_settings_back)


func _pause_item(parent: Control, text: String, icon: String, btn_name: String, action: Callable, variant: String = "secondary") -> Button:
	var b := UiTheme.make_button(text, btn_name, false, Vector2(0, UiTheme.TOUCH_MIN), variant, icon)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(action)
	parent.add_child(b)
	return b


## Confirmation dialog for leaving/restarting/quitting (XAG 115): specific
## title and action label, consequence spelled out, focus on the safe choice.
func _build_confirm() -> void:
	_confirm_box = _overlay("PauseConfirmBox", 0.55)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm_box.add_child(center)
	_confirm_card = PanelContainer.new()
	_confirm_card.name = "ConfirmCard"
	_confirm_card.theme_type_variation = "DialogPanel"
	center.add_child(_confirm_card)
	var v := VBoxContainer.new()
	v.layout_direction = Control.LAYOUT_DIRECTION_RTL
	v.add_theme_constant_override("separation", UiTheme.SPACE_4)
	_confirm_card.add_child(v)
	_confirm_title = UiTheme.label("", "TitleLabel")
	_confirm_title.name = "ConfirmTitle"
	v.add_child(_confirm_title)
	_confirm_text_label = UiTheme.label("", "BodyMutedLabel", true)
	_confirm_text_label.name = "ConfirmText"
	_confirm_text_label.custom_minimum_size = Vector2(320, 0)
	v.add_child(_confirm_text_label)
	var actions := HBoxContainer.new()
	actions.layout_direction = Control.LAYOUT_DIRECTION_RTL
	actions.add_theme_constant_override("separation", UiTheme.SPACE_3)
	v.add_child(actions)
	_confirm_no = UiTheme.make_button("ادامهٔ رانندگی", "ConfirmNoButton", false, Vector2(0, UiTheme.TOUCH_MIN), "secondary")
	_confirm_no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm_no.pressed.connect(_cancel_confirmation)
	actions.add_child(_confirm_no)
	_confirm_yes = UiTheme.make_button("", "ConfirmYesButton", false, Vector2(0, UiTheme.TOUCH_MIN), "danger")
	_confirm_yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm_yes.pressed.connect(_on_confirm_accepted)
	actions.add_child(_confirm_yes)


func _build_toast() -> void:
	_toast = PanelContainer.new()
	_toast.name = "Toast"
	_toast.theme_type_variation = "ToastPanel"
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.offset_top = 10.0 + UiTheme.TOUCH_MIN + 14.0
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.modulate.a = 0.0
	_toast.visible = false
	_overlay_root.add_child(_toast)
	var row := HBoxContainer.new()
	row.layout_direction = Control.LAYOUT_DIRECTION_RTL
	row.add_theme_constant_override("separation", UiTheme.SPACE_2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.add_child(row)
	_toast_icon = UiIcon.make("info", 20, UiTheme.COLOR_ON_INVERSE_SURFACE)
	row.add_child(_toast_icon)
	_toast_label = UiTheme.label("", "LabelStrong")
	_toast_label.name = "ToastLabel"
	_toast_label.add_theme_color_override("font_color", UiTheme.COLOR_ON_INVERSE_SURFACE)
	row.add_child(_toast_label)

	_photo_hint = PanelContainer.new()
	_photo_hint.name = "PhotoModeHint"
	_photo_hint.theme_type_variation = "HudPanel"
	_photo_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_photo_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_photo_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_photo_hint.offset_bottom = -UiTheme.SAFE_INSET - 8.0
	_photo_hint.visible = false
	_photo_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_root.add_child(_photo_hint)
	var prow := HBoxContainer.new()
	prow.layout_direction = Control.LAYOUT_DIRECTION_RTL
	prow.add_theme_constant_override("separation", UiTheme.SPACE_5)
	prow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_photo_hint.add_child(prow)
	prow.add_child(UiTheme.label("حالت عکس", "LabelStrong"))
	prow.add_child(InputPrompts.PromptChip.new("accept", "ثبت عکس", "برای ثبت ضربه بزنید · برای چرخش بکشید"))
	prow.add_child(InputPrompts.PromptChip.new("back", "خروج"))

	_flash = ColorRect.new()
	_flash.name = "PhotoFlash"
	_flash.color = Color(1, 1, 1, 0.0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_root.add_child(_flash)


func _build_gamepad_hint() -> void:
	_gamepad_hint = PanelContainer.new()
	_gamepad_hint.name = "GamepadHintStrip"
	_gamepad_hint.theme_type_variation = "HudPanel"
	_gamepad_hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_gamepad_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_gamepad_hint.offset_top = 10.0 + UiTheme.TOUCH_MIN + 12.0
	_gamepad_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.layout_direction = Control.LAYOUT_DIRECTION_RTL
	row.add_theme_constant_override("separation", UiTheme.SPACE_4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gamepad_hint.add_child(row)
	for d in [["throttle", "گاز"], ["brake_reverse", "ترمز / عقب"], ["handbrake", "ترمز دستی"], ["toggle_headlights", "چراغ"], ["pause_game", "توقف"]]:
		row.add_child(InputPrompts.PromptChip.new(d[0], d[1]))
	_gamepad_hint.visible = false
	_root.add_child(_gamepad_hint)


# =========================================================================
# Binding / state
# =========================================================================
func bind_systems(target_vehicle: SaipaVehicleController, target_cam: VehicleCameraRig, target_track: DesertCircuit = null, _target_main: Node = null) -> void:
	vehicle = target_vehicle
	camera_rig = target_cam
	track_ref = target_track
	main_ref = _target_main
	SettingsManager.apply_to_systems(self, camera_rig)
	if _pause_settings_panel != null:
		_pause_settings_panel.bind_systems(self, camera_rig)
	if vehicle != null and vehicle.has_signal("impact_detected") and not vehicle.impact_detected.is_connected(_on_vehicle_impact):
		vehicle.impact_detected.connect(_on_vehicle_impact)
	_refresh_vehicle_label()


func _refresh_vehicle_label() -> void:
	if vehicle_label == null:
		return
	if vehicle != null:
		var idx := VehicleCatalog.find_index_by_id(vehicle.vehicle_id)
		vehicle_label.text = str(VehicleCatalog.get_entry(idx)["name_fa"])
	else:
		vehicle_label.text = "—"


func set_perf_telemetry_visible(v: bool) -> void:
	show_perf_telemetry = v
	if _perf_chip != null:
		_perf_chip.visible = v


func set_camera_diag_visible(v: bool) -> void:
	if camera_rig != null:
		camera_rig.diagnostics_enabled = v
	if cam_diag_label != null:
		cam_diag_label.visible = v


func set_ghost_delta(text: String) -> void:
	if ghost_delta_label != null:
		ghost_delta_label.text = text
	if _ghost_chip != null:
		_ghost_chip.visible = text != ""


func apply_graphics_quality(tier: int) -> void:
	graphics_quality_tier = clampi(tier, 0, 2)
	SettingsManager.graphics_tier = graphics_quality_tier
	SettingsManager.apply_viewport_graphics(get_viewport())
	if track_ref != null:
		track_ref.set_shadow_quality(graphics_quality_tier)
	if vehicle != null:
		vehicle.set_graphics_quality_tier(graphics_quality_tier)
	_sync_quick_settings_ui()


func _is_lan_active() -> bool:
	var lan := get_node_or_null("/root/LanSession")
	return lan != null and lan.has_method("is_in_game") and bool(lan.call("is_in_game"))


func set_replay_active(active: bool) -> void:
	_replay_active = active
	if active:
		_close_tray()
		_close_sheet()
	if _root != null:
		var steer_zone := _root.get_node_or_null("SteerZone") as Control
		var pedal_col := _root.get_node_or_null("PedalColumn") as Control
		if steer_zone != null:
			steer_zone.visible = (not active) and _touch_controls_visible
		if pedal_col != null:
			pedal_col.visible = (not active) and _touch_controls_visible
	_sync_touch_input_block()
	if active:
		show_toast("بازپخش ۱۵ ثانیهٔ اخیر", "replay")
	else:
		show_toast("بازپخش تمام شد", "check")


## Gamepad mode shows the binding strip for a few seconds; touch controls
## stay visible next to the pad (visibility is owned by
## set_touch_controls_visible). Pads redraw so keyboard letters appear only
## for keyboard players.
func _apply_input_mode(mode: int) -> void:
	var pad := mode == InputDeviceManager.Mode.GAMEPAD
	if _gamepad_hint != null:
		_gamepad_hint.visible = pad
		_gamepad_hint.modulate.a = 1.0
		_gamepad_hint_timer = GAMEPAD_HINT_SECONDS if pad else 0.0
	_refresh_touch_zone_visibility()
	for p in [btn_throttle, btn_brake_rev, btn_handbrake, btn_steer_left, btn_steer_right]:
		if p != null:
			p.queue_redraw()
	if pad and is_game_paused and _pause_resume_btn != null and _pause_main_box != null and _pause_main_box.visible:
		_pause_resume_btn.grab_focus()


## Single owner of touch-control visibility. Turning the controls off also
## zeroes their inputs immediately, so a press in flight can never stick.
func set_touch_controls_visible(v: bool) -> void:
	_touch_controls_visible = v
	_refresh_touch_zone_visibility()
	if not v and vehicle != null:
		vehicle.touch_throttle = 0.0
		vehicle.touch_brake_reverse = 0.0
		vehicle.touch_handbrake = false
		vehicle.touch_steer = 0.0


func _refresh_touch_zone_visibility() -> void:
	if has_node("HudRoot/SteerZone"):
		(get_node("HudRoot/SteerZone") as Control).visible = _touch_controls_visible and not _replay_active
	if has_node("HudRoot/PedalColumn"):
		(get_node("HudRoot/PedalColumn") as Control).visible = _touch_controls_visible and not _replay_active


func _apply_steer_mode_visibility() -> void:
	if steer_buttons_box == null or steering_wheel_pad == null or analog_steer_bar == null:
		return
	steer_buttons_box.visible = (steer_ui_mode == SteerUiMode.BUTTONS)
	steering_wheel_pad.visible = (steer_ui_mode == SteerUiMode.WHEEL)
	analog_steer_bar.visible = (steer_ui_mode == SteerUiMode.ANALOG_BAR)


func _on_headlights_pressed() -> void:
	if vehicle != null:
		vehicle.toggle_headlights()
		var on := vehicle.visual_model != null and vehicle.visual_model.headlights_enabled
		show_toast("چراغ‌ها روشن شد" if on else "چراغ‌ها خاموش شد", "headlight")


func _on_reset_pressed() -> void:
	if vehicle != null:
		vehicle.reset_vehicle()


func _on_replay_pressed() -> void:
	if main_ref != null and main_ref.has_method("start_replay"):
		main_ref.start_replay()
	else:
		show_toast("بازپخش در دسترس نیست", "alert")


func _on_ghost_pressed() -> void:
	if main_ref != null and main_ref.has_method("toggle_ghost"):
		main_ref.toggle_ghost()
	else:
		show_toast("شبح در دسترس نیست", "alert")


# ------------------------------------------------------------------ F4 damage
func _on_vehicle_impact(strength: float) -> void:
	var add := clampf(strength * 2.2, 1.5, 12.0)
	damage_percent = clampf(damage_percent + add, 0.0, 100.0)
	if damage_label != null:
		damage_label.text = "آسیب " + UiTheme.fa_digits("%d" % int(round(damage_percent))) + "٪"
	if _damage_chip != null:
		_damage_chip.visible = damage_percent > 0.0
	if camera_rig != null:
		camera_rig.add_shake(clampf(strength / 6.0, 0.15, 1.0))
	if SettingsManager.joy_vibration > 0.01:
		var vib_scale := clampf(strength / 8.0, 0.2, 1.0) * SettingsManager.joy_vibration
		for dev in Input.get_connected_joypads():
			Input.start_joy_vibration(dev, vib_scale * 0.65, vib_scale, 0.24)
	if _vignette != null:
		_vignette.color = Color(UiTheme.COLOR_ERROR, 0.0 if SettingsManager.reduce_motion else 0.28)
		var tw := create_tween()
		tw.tween_property(_vignette, "color", Color(UiTheme.COLOR_ERROR, 0.0), 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if _impact_chip != null:
		_impact_chip.modulate.a = 1.0
		var tw2 := create_tween()
		tw2.tween_interval(0.35)
		tw2.tween_property(_impact_chip, "modulate:a", 0.0, 0.5)


## Snackbar on the inverse surface (readable over any sky/track — audit
## A-18). Stays visible in photo mode (lives on OverlayRoot).
func show_toast(text: String, icon: String = "info") -> void:
	if _toast_label == null:
		return
	_toast_label.text = text
	if _toast_icon != null:
		_toast_icon.kind = icon if UiIcon.has_icon(icon) else "info"
	# Wrap only when the text is wider than 60 % of the canvas, and then at
	# an explicit width: an autowrapping Label inside an HBox reports a ~1
	# glyph minimum width and stacks one letter per line.
	var vp := get_viewport().get_visible_rect().size
	var max_w := maxf(220.0, vp.x * 0.6)
	var text_w := max_w + 1.0
	if UiTheme.font_bold() != null:
		text_w = UiTheme.font_bold().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.TYPE_LABEL).x
	if text_w > max_w:
		_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_toast_label.custom_minimum_size = Vector2(max_w, 0)
	else:
		_toast_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		_toast_label.custom_minimum_size = Vector2.ZERO
	_toast.visible = true
	_toast.modulate.a = 1.0
	# Re-centre from the measured size (reset_size keeps the top-left fixed,
	# which pushed long toasts off the right edge).
	var ms := _toast.get_combined_minimum_size()
	_toast.offset_left = -ms.x * 0.5
	_toast.offset_right = ms.x * 0.5
	_toast.offset_bottom = _toast.offset_top + ms.y
	_toast_timer = TOAST_SECONDS


# ------------------------------------------------------------------ F1 photo mode
func enter_photo_mode() -> void:
	if vehicle == null or photo_mode:
		return
	if _is_lan_active():
		show_toast("حالت عکس در بازی شبکه‌ای در دسترس نیست", "alert")
		return
	photo_mode = true
	_photo_dragging = false
	_photo_moved = 0.0
	_photo_touch_id = -1
	_photo_touch_moved = 0.0
	_close_tray()
	_close_sheet()
	_sync_touch_input_block()
	get_tree().paused = true
	if _root != null:
		_root.visible = false
	if _photo_hint != null:
		_photo_hint.visible = true
	_photo_cam = Camera3D.new()
	_photo_cam.name = "PhotoCamera"
	_photo_cam.far = 900.0
	var host := vehicle.get_parent()
	if host != null:
		host.add_child(_photo_cam)
		var fwd := vehicle.global_transform.basis.z.normalized()
		_photo_yaw = atan2(fwd.x, fwd.z)
		_update_photo_cam(0.0)
		_photo_cam.current = true


func exit_photo_mode() -> void:
	if not photo_mode:
		return
	photo_mode = false
	_photo_dragging = false
	_photo_touch_id = -1
	if _photo_cam != null:
		_photo_cam.queue_free()
		_photo_cam = null
	if camera_rig != null and camera_rig.camera != null:
		camera_rig.camera.make_current()
	if _root != null:
		_root.visible = true
	if _photo_hint != null:
		_photo_hint.visible = false
	get_tree().paused = is_game_paused and not _is_lan_active()
	_sync_touch_input_block()


func _update_photo_cam(_delta: float) -> void:
	if _photo_cam == null or vehicle == null:
		return
	var center := vehicle.global_position + Vector3.UP * 0.8
	var dir := Vector3(sin(_photo_yaw) * cos(_photo_pitch), sin(_photo_pitch), cos(_photo_yaw) * cos(_photo_pitch))
	var desired_pos := center + dir * _photo_dist
	desired_pos.y = maxf(desired_pos.y, vehicle.global_position.y + 0.35)
	# Wall/ground clearance so the photo camera never clips inside geometry.
	var world := vehicle.get_world_3d()
	if world != null and world.direct_space_state != null:
		var ray := PhysicsRayQueryParameters3D.create(center, desired_pos, 1, [vehicle.get_rid()])
		var hit := world.direct_space_state.intersect_ray(ray)
		if not hit.is_empty():
			var hit_pos: Vector3 = hit["position"]
			var safe_dist := maxf(center.distance_to(hit_pos) - 0.35, 1.5)
			desired_pos = center + (desired_pos - center).normalized() * safe_dist
	_photo_cam.global_position = desired_pos
	_photo_cam.look_at(center, Vector3.UP)


func _save_photo() -> void:
	var now_ms := Time.get_ticks_msec()
	# Debounce: emulate_touch_from_mouse can fire mouse-up and touch-up for one click.
	if now_ms - _photo_last_capture_msec < 250:
		return
	_photo_last_capture_msec = now_ms
	# Hide the hint for the capture so it is not in the photo.
	var hint_was := _photo_hint != null and _photo_hint.visible
	if _photo_hint != null:
		_photo_hint.visible = false
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if _photo_hint != null:
		_photo_hint.visible = hint_was and photo_mode
	var dir_path := "user://photos"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var path := "%s/km2_photo_%s.png" % [dir_path, stamp]
	var err := img.save_png(ProjectSettings.globalize_path(path))
	if err == OK:
		show_toast("عکس ذخیره شد: km2_photo_%s.png" % stamp, "check")
		if _flash != null and not SettingsManager.reduce_motion:
			_flash.color = Color(1, 1, 1, 0.55)
			create_tween().tween_property(_flash, "color", Color(1, 1, 1, 0.0), 0.25)
	else:
		show_toast("عکس ذخیره نشد (خطای %s). فضای ذخیره‌سازی را بررسی کنید." % UiTheme.fa_int(err), "alert")


func _input(event: InputEvent) -> void:
	_idle_time = 0.0
	if not photo_mode and event.is_action_pressed("photo_mode") and not is_game_paused and _modals.is_empty():
		enter_photo_mode()
		get_viewport().set_input_as_handled()
		return
	if photo_mode:
		if event.is_action_pressed("pause_game") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("photo_mode") or event.is_action_pressed("menu_back"):
			exit_photo_mode()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("menu_accept") or (event is InputEventKey and event.is_action_pressed("ui_accept")):
			_save_photo()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT:
				if mb.pressed:
					_photo_dragging = true
					_photo_moved = 0.0
				else:
					_photo_dragging = false
					if _photo_moved < 6.0:
						_save_photo()
		if event is InputEventMouseMotion and _photo_dragging:
			var mm := event as InputEventMouseMotion
			_photo_moved += mm.relative.length()
			_photo_yaw -= mm.relative.x * 0.005
			_photo_pitch = clampf(_photo_pitch + mm.relative.y * 0.005, -0.05, 1.1)
			_update_photo_cam(0.0)
		if event is InputEventScreenTouch:
			var st := event as InputEventScreenTouch
			if st.pressed and _photo_touch_id == -1:
				_photo_touch_id = st.index
				_photo_touch_moved = 0.0
			elif not st.pressed and st.index == _photo_touch_id:
				_photo_touch_id = -1
				if _photo_touch_moved < 6.0:
					_save_photo()
		if event is InputEventScreenDrag:
			var sd := event as InputEventScreenDrag
			if sd.index == _photo_touch_id:
				_photo_touch_moved += sd.relative.length()
				_photo_yaw -= sd.relative.x * 0.005
				_photo_pitch = clampf(_photo_pitch + sd.relative.y * 0.005, -0.05, 1.1)
				_update_photo_cam(0.0)


## Driving: only the pause action (Esc / P / Start) pauses — B stays the
## handbrake. With an overlay open: Esc / B (menu_back) closes the top one,
## the pause action resumes from the pause drawer.
func _unhandled_input(event: InputEvent) -> void:
	if photo_mode:
		return
	if _modals.is_empty():
		if event.is_action_pressed("pause_game"):
			set_game_paused(true)
			get_viewport().set_input_as_handled()
		return
	var top := _modals.top()
	if event.is_action_pressed("pause_game") and top == _pause_layer and _pause_main_box.visible:
		set_game_paused(false)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu_back") or event.is_action_pressed("pause_game"):
		_modals.handle_cancel()
		get_viewport().set_input_as_handled()


func _on_pause_settings_pressed() -> void:
	if _pause_settings_box == null:
		return
	if _pause_settings_panel != null:
		_pause_settings_panel.refresh_from_settings()
	_pause_main_box.visible = false
	_pause_settings_box.visible = true
	if _pause_settings_panel != null and _pause_settings_panel.default_focus() != null:
		_pause_settings_panel.default_focus().grab_focus()


func _on_pause_settings_back() -> void:
	if _pause_settings_box == null:
		return
	if _pause_settings_panel != null:
		_pause_settings_panel.flush_pending()
	_sync_quick_settings_ui()
	_pause_settings_box.visible = false
	_pause_main_box.visible = true
	var b := pause_overlay.find_child("PauseSettingsButton", true, false) as Control
	if b != null:
		b.grab_focus()
	elif _pause_resume_btn != null:
		_pause_resume_btn.grab_focus()


func _pause_cancel() -> void:
	if _pause_settings_box != null and _pause_settings_box.visible:
		if _pause_settings_panel == null or not _pause_settings_panel.handle_cancel():
			_on_pause_settings_back()
		return
	set_game_paused(false)


func _ask_confirmation(action: String) -> void:
	_pending_confirm_action = action
	match action:
		"restart":
			_confirm_title.text = "شروع دوبارهٔ جلسه؟"
			_confirm_text_label.text = "خودرو به نقطهٔ شروع برمی‌گردد و زمان جلسه صفر می‌شود."
			_confirm_yes.text = "شروع دوباره"
			_confirm_yes.icon = UiIcon.texture("restart")
		"main_menu":
			_confirm_title.text = "بازگشت به نمایشگاه؟"
			_confirm_text_label.text = "این جلسهٔ رانندگی تمام می‌شود. در نمایشگاه می‌توانید خودروی دیگری انتخاب کنید."
			_confirm_yes.text = "بازگشت به نمایشگاه"
			_confirm_yes.icon = UiIcon.texture("home")
		"quit":
			_confirm_title.text = "از بازی خارج می‌شوید؟"
			_confirm_text_label.text = "جلسهٔ رانندگی بسته می‌شود. تنظیمات و خودروی انتخاب‌شده ذخیره شده‌اند."
			_confirm_yes.text = "خروج از بازی"
			_confirm_yes.icon = UiIcon.texture("power")
	_confirm_no.text = "انصراف"
	_modals.push(_confirm_box, _confirm_no, _cancel_confirmation)
	var d := UiTheme.motion_sec(UiTheme.MOTION_MEDIUM_MS)
	if d > 0.0:
		_confirm_card.offset_transform_enabled = true
		_confirm_card.offset_transform_position = Vector2(0, 16)
		UiTheme.ease_enter(_confirm_card.create_tween().tween_property(_confirm_card, "offset_transform_position", Vector2.ZERO, d))


func _cancel_confirmation() -> void:
	_pending_confirm_action = ""
	_modals.close(_confirm_box)


func _on_confirm_accepted() -> void:
	var action := _pending_confirm_action
	_pending_confirm_action = ""
	_modals.close(_confirm_box)
	match action:
		"restart":
			set_game_paused(false)
			if _is_lan_active():
				# In LAN multiplayer, reloading the scene closes LanSession;
				# reset the local car cleanly instead (mirrors via RPC).
				if vehicle != null:
					vehicle.reset_vehicle()
			else:
				get_tree().reload_current_scene()
		"main_menu":
			set_game_paused(false)
			SceneTransitionLayer.go(get_tree(), "res://scenes/ui/main_menu.tscn", "بازگشت به نمایشگاه…")
		"quit":
			get_tree().quit()


func set_game_paused(paused_value: bool) -> void:
	var prev_paused := is_game_paused
	is_game_paused = paused_value
	var am := get_node_or_null("/root/AudioManager")
	if am != null:
		if am.has_method("set_paused_muffle"):
			am.call("set_paused_muffle", paused_value)
		if prev_paused != paused_value and am.has_method("play_ui_pause"):
			am.call("play_ui_pause", paused_value)
	if pause_overlay != null:
		if paused_value:
			if photo_mode:
				exit_photo_mode()
			if not _modals.has(_pause_layer):
				_modals.clear()
				_tray_open = false
				_sheet_open = false
				if _pause_settings_box != null:
					_pause_settings_box.visible = false
				if _pause_main_box != null:
					_pause_main_box.visible = true
				_update_pause_drawer_width()
				pause_overlay.visible = true
				_modals.push(_pause_layer, _pause_resume_btn, _pause_cancel)
				_animate_drawer_in()
		else:
			if _pause_settings_panel != null:
				_pause_settings_panel.flush_pending()
			_modals.close(_pause_layer)
			# The drawer's own flag mirrors the pause state (public contract).
			pause_overlay.visible = false
	# Never freeze the SceneTree during active LAN multiplayer (keeps 30 Hz sync alive).
	get_tree().paused = paused_value and not _is_lan_active()
	_sync_touch_input_block()
	if paused_value:
		# R8: stop haptics while paused.
		for dev in Input.get_connected_joypads():
			Input.stop_joy_vibration(dev)
	if vehicle != null:
		if _is_lan_active():
			vehicle.read_desktop_input = not paused_value
		if paused_value:
			vehicle.touch_throttle = 0.0
			vehicle.touch_brake_reverse = 0.0
			vehicle.touch_steer = 0.0
			vehicle.touch_handbrake = false
	if paused_value and _pause_resume_btn != null:
		_pause_resume_btn.grab_focus()


## Drawer slides in from the right edge and fades; lands on exactly its rest
## offsets (offset_transform, so the anchored rect itself never moves).
func _animate_drawer_in() -> void:
	var d := UiTheme.motion_sec(UiTheme.MOTION_MEDIUM_MS)
	if d <= 0.0:
		_pause_layer.modulate.a = 1.0
		return
	pause_overlay.offset_transform_enabled = true
	pause_overlay.offset_transform_position = Vector2(80, 0)
	_pause_layer.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	UiTheme.ease_enter(tw.tween_property(pause_overlay, "offset_transform_position", Vector2.ZERO, d))
	tw.tween_property(_pause_layer, "modulate:a", 1.0, UiTheme.fade_sec(UiTheme.MOTION_FAST_MS + 60.0))


## The pause drawer is 440 px wide on desktop but never more than 92 % of a
## phone canvas, so the settings form inside it always has room.
func _pause_drawer_rest_width(canvas_hint: Vector2 = Vector2.ZERO) -> float:
	var vw := canvas_hint.x if canvas_hint.x > 0.0 else get_viewport().get_visible_rect().size.x
	if vw <= 0.0:
		return PAUSE_DRAWER_WIDTH
	return minf(PAUSE_DRAWER_WIDTH, vw * PAUSE_DRAWER_MAX_RATIO)


func _update_pause_drawer_width(canvas_hint: Vector2 = Vector2.ZERO) -> void:
	if pause_overlay == null:
		return
	var w := _pause_drawer_rest_width(canvas_hint)
	pause_overlay.set_meta("k2_rest_offset_left", -w)
	pause_overlay.offset_left = -w


func toggle_game_pause() -> void:
	set_game_paused(not is_game_paused)


func _on_pause_reset_pressed() -> void:
	if vehicle != null:
		vehicle.reset_vehicle()
	set_game_paused(false)
	show_toast("خودرو به پیست برگشت", "reset")


func _process(delta: float) -> void:
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0 and _toast != null:
			var d := UiTheme.fade_sec(UiTheme.MOTION_MEDIUM_MS)
			if d > 0.0:
				var tw := create_tween()
				tw.tween_property(_toast, "modulate:a", 0.0, d)
				tw.tween_callback(func() -> void: _toast.visible = false)
			else:
				_toast.visible = false
	if _gamepad_hint_timer > 0.0 and not is_game_paused:
		_gamepad_hint_timer -= delta
		if _gamepad_hint_timer <= 0.0 and _gamepad_hint != null:
			var tw2 := create_tween()
			tw2.tween_property(_gamepad_hint, "modulate:a", 0.0, UiTheme.fade_sec(UiTheme.MOTION_SLOW_MS))
			tw2.tween_callback(func() -> void: _gamepad_hint.visible = false)
	if photo_mode:
		var dz := SettingsManager.joy_deadzone
		for dev in Input.get_connected_joypads():
			var rx := Input.get_joy_axis(dev, JOY_AXIS_RIGHT_X)
			var ry := Input.get_joy_axis(dev, JOY_AXIS_RIGHT_Y)
			if absf(rx) >= dz:
				_photo_yaw -= rx * delta * 2.4
			if absf(ry) >= dz:
				_photo_pitch = clampf(_photo_pitch + ry * delta * 1.6, -0.05, 1.1)
		_update_photo_cam(delta)
		return
	if is_game_paused:
		return
	if vehicle == null:
		return

	# Gently dim the top bar after 6 s of true idle; any input restores it.
	var actively_driving := (
		(btn_throttle != null and btn_throttle.is_pressed_down)
		or (btn_brake_rev != null and btn_brake_rev.is_pressed_down)
		or (btn_handbrake != null and btn_handbrake.is_pressed_down)
		or (btn_steer_left != null and btn_steer_left.is_pressed_down)
		or (btn_steer_right != null and btn_steer_right.is_pressed_down)
		or vehicle.current_speed_kmh > 3.0
	)
	if actively_driving:
		_idle_time = 0.0
	else:
		_idle_time += delta
	if _idle_time >= 6.0 and not _faded and _top_bar != null:
		_faded = true
		create_tween().tween_property(_top_bar, "modulate:a", 0.72, UiTheme.fade_sec(UiTheme.MOTION_MEDIUM_MS))
	elif _idle_time < 6.0 and _faded and _top_bar != null:
		_faded = false
		create_tween().tween_property(_top_bar, "modulate:a", 1.0, UiTheme.fade_sec(UiTheme.MOTION_FAST_MS))

	_session_time += delta
	if timer_label != null:
		var t := int(_session_time)
		timer_label.text = "%02d:%02d" % [t / 60, t % 60]

	_update_lap_chip()

	if cam_diag_label != null and cam_diag_label.visible and camera_rig != null:
		_diag_refresh_accum += delta
		if _diag_refresh_accum >= 0.25:
			_diag_refresh_accum = 0.0
			var d2: Dictionary = camera_rig.get_camera_diagnostics()
			cam_diag_label.text = "CAM %s | %s\nهدف: %s | محور: %s\nخطای محور: %.2f م | خطای زاویه: %.1f° | FOV %.0f | فنر: %.2f م" % [str(d2["mode"]), str(d2["active_camera"]), str(d2["target_pos"]), str(d2["pivot_pos"]), float(d2["pivot_error_m"]), float(d2["yaw_error_deg"]), float(d2["fov"]), float(d2["spring_length"])]

	# K2-FINAL-003 coexistence policy: touch values are written in EVERY input
	# mode whenever the touch controls are visible. The controller merges all
	# sources with a fixed rule — pedals take the MAX, steering the LARGEST
	# ABSOLUTE value, handbrake is OR — so simultaneous touch + pad + keyboard
	# input is predictable. Hidden controls report zero here AND clear their
	# own press state in TouchPedalButton, so nothing can stick.
	if _touch_controls_visible:
		vehicle.touch_throttle = 1.0 if btn_throttle.is_pressed_down else 0.0
		vehicle.touch_brake_reverse = 1.0 if btn_brake_rev.is_pressed_down else 0.0
		vehicle.touch_handbrake = btn_handbrake.is_pressed_down
		match steer_ui_mode:
			SteerUiMode.BUTTONS:
				var pad_steer := 0.0
				if btn_steer_left.is_pressed_down:
					pad_steer -= 1.0
				if btn_steer_right.is_pressed_down:
					pad_steer += 1.0
				vehicle.touch_steer = pad_steer
			SteerUiMode.WHEEL:
				vehicle.touch_steer = steering_wheel_pad.steer_value
			SteerUiMode.ANALOG_BAR:
				vehicle.touch_steer = analog_steer_bar.steer_value
	else:
		vehicle.touch_throttle = 0.0
		vehicle.touch_brake_reverse = 0.0
		vehicle.touch_handbrake = false
		vehicle.touch_steer = 0.0

	var g := vehicle.get_gear_label()
	var slippery := vehicle.active_surface_grip < 0.65
	if _grip_chip != null and _grip_chip.visible != slippery:
		_grip_chip.visible = slippery
	if grip_label != null:
		grip_label.text = "سطح لغزنده" if slippery else "سطح خشک"

	var lights_on := vehicle.visual_model.headlights_enabled if vehicle.visual_model != null else false
	var live_thr := 1.0 if (btn_throttle.is_pressed_down or vehicle.engine_force > 50.0) else clampf(vehicle.touch_throttle, 0.0, 1.0)
	var live_brk := 1.0 if (btn_brake_rev.is_pressed_down or vehicle.brake > 8.0) else clampf(vehicle.touch_brake_reverse, 0.0, 1.0)
	gauge_cluster.update_telemetry(
		vehicle.current_speed_kmh,
		vehicle.engine_rpm_norm,
		g,
		btn_brake_rev.is_pressed_down or vehicle.brake > 8.0,
		btn_handbrake.is_pressed_down,
		lights_on,
		live_thr,
		live_brk,
		vehicle.engine_gear if g == "D" else 0
	)

	if show_perf_telemetry and perf_label != null:
		_perf_refresh_accum += delta
		if _perf_refresh_accum >= 0.25:
			_perf_refresh_accum = 0.0
			var raw_fps := int(round(Engine.get_frames_per_second()))
			var fps := mini(raw_fps, 120)
			var dc := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			perf_label.text = ("%d FPS · %d DC" % [fps, dc]) if fps > 0 else ("-- FPS · %d DC" % dc)
