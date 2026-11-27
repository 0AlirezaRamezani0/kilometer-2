class_name TouchPedalButton
extends Control

## Kilometer 2 — touch pedals and pads (v0.1-b3 "Proving Ground" styling).
## Semantic accents follow the telemetry convention and are never the only
## cue: throttle = green + up-chevrons + «گاز», brake = red + disc + «ترمز»,
## handbrake = amber + (P) + «ترمز دستی», steering = neutral + arrows.
## Pressed = accent fill with dark ink (contrast ≥ 4.5:1). Keyboard letters
## appear only while a keyboard is the active device.
## Input handling is unchanged: multi-touch (InputEventScreenTouch), mouse
## simulation and programmatic press; is_pressed_down is read by the HUD.

signal pedal_changed(pressed: bool)

@export var label_text: String = "گاز"
@export var sub_text: String = ""
@export var sub_label_text: String = ""
@export var icon_kind: String = ""    # "left" | "right" | "throttle" | "brake" | "handbrake" | ""
@export var idle_color: Color = Color(0.048, 0.064, 0.094, 0.62)
@export var active_color: Color = Color(0.95, 0.24, 0.18, 0.78)
@export var accent_color: Color = Color(0.95, 0.24, 0.18, 0.85):
	set(v):
		accent_color = v
		active_color = Color(v.r, v.g, v.b, 0.78)
		border_color = Color(v.r, v.g, v.b, 0.52)
@export var border_color: Color = Color(0.84, 0.90, 1.0, 0.30)
@export var corner_radius: int = 16

var is_pressed: bool = false
var is_pressed_down: bool = false
var input_blocked: bool = false:
	set(v):
		input_blocked = v
		if input_blocked:
			clear_all_touches()
var _active_touch_ids: Dictionary = {}
var _mouse_pressed: bool = false
var _simulated_pressed: bool = false
var _font_reg: Font = null
var _font_bold: Font = null
var _press_blend: float = 0.0
var _sb: StyleBoxFlat = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font_reg = UiTheme.font_regular()
	_font_bold = UiTheme.font_bold()
	if _font_reg == null:
		_font_reg = ThemeDB.fallback_font
	if _font_bold == null:
		_font_bold = _font_reg


func set_simulated_press(pressed: bool) -> void:
	_simulated_pressed = pressed
	_recompute_state()


func clear_all_touches() -> void:
	_active_touch_ids.clear()
	_mouse_pressed = false
	_simulated_pressed = false
	_recompute_state()


func _gui_input(event: InputEvent) -> void:
	if input_blocked:
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_active_touch_ids[st.index] = true
		else:
			_active_touch_ids.erase(st.index)
		_recompute_state()
		accept_event()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_mouse_pressed = mb.pressed
			_recompute_state()
			accept_event()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if not st.pressed and _active_touch_ids.has(st.index):
			_active_touch_ids.erase(st.index)
			_recompute_state()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed and _mouse_pressed:
			_mouse_pressed = false
			_recompute_state()


func _recompute_state() -> void:
	var new_state := (not input_blocked) and (_simulated_pressed or _mouse_pressed or not _active_touch_ids.is_empty())
	if new_state != is_pressed:
		is_pressed = new_state
		is_pressed_down = new_state
		_press_blend = 1.0 if is_pressed else 0.0
		emit_signal("pedal_changed", is_pressed)
		queue_redraw()


func _icon_name() -> String:
	match icon_kind:
		"left":
			return "steer_left"
		"right":
			return "steer_right"
		"throttle", "brake", "handbrake":
			return icon_kind
	return ""


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var is_compact_pill := size.y <= 48.0
	var eff_radius := int(size.y * 0.5) if is_compact_pill else corner_radius
	if icon_kind == "left" or icon_kind == "right":
		eff_radius = int(minf(size.x, size.y) * 0.30)
	if _sb == null:
		_sb = StyleBoxFlat.new()
		_sb.anti_aliasing = true
	var accent := accent_color
	var ink := Color(0.043, 0.059, 0.078) # dark ink on bright accent fills
	_sb.bg_color = Color(accent, 0.88) if is_pressed else Color(UiTheme.COLOR_SURFACE, 0.74)
	_sb.border_color = Color(1, 1, 1, 0.92) if is_pressed else Color(accent, 0.62)
	_sb.set_border_width_all(2 if is_pressed else 1)
	_sb.set_corner_radius_all(eff_radius)
	_sb.shadow_color = Color(accent, 0.45) if is_pressed else Color(0, 0, 0, 0.32)
	_sb.shadow_size = 16 if is_pressed else 8
	_sb.shadow_offset = Vector2.ZERO if is_pressed else Vector2(0, 3)
	draw_style_box(_sb, rect)

	# Grip ribs on the tall throttle pedal (texture cue, not decoration).
	if icon_kind == "throttle" and size.y >= 95.0:
		var rib_col := Color(ink, 0.30) if is_pressed else Color(1, 1, 1, 0.10)
		for r_idx in range(3):
			var ry := size.y - 14.0 - float(r_idx) * 7.0
			draw_line(Vector2(16.0, ry), Vector2(size.x - 16.0, ry), rib_col, 2.0, true)

	var fg := ink if is_pressed else Color.WHITE
	var icon_col := ink if is_pressed else accent.lerp(Color.WHITE, 0.15)
	var tex: Texture2D = null
	var icon_name := _icon_name()
	if not icon_name.is_empty():
		tex = UiIcon.texture(icon_name, 48)
	var show_key := InputPrompts.current_device() == InputPrompts.Device.KEYBOARD
	var effective_sub := sub_label_text if not sub_label_text.is_empty() else sub_text

	if is_compact_pill:
		var isz := size.y * 0.52
		var x0 := size.x - isz - 14.0
		if tex != null:
			draw_texture_rect(tex, Rect2(Vector2(x0, (size.y - isz) * 0.5), Vector2(isz, isz)), false, icon_col)
		if _font_bold != null:
			var fs := 15
			var ts := _font_bold.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			var avail := x0 - 10.0
			draw_string(_font_bold, Vector2(maxf(10.0, (avail - ts.x) * 0.5 + 4.0), size.y * 0.5 + ts.y * 0.30), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, fg)
		return

	var unit := minf(size.x, size.y)
	var isz2 := clampf(unit * 0.40, 22.0, 44.0)
	var icon_y := size.y * (0.32 if icon_kind == "throttle" else 0.36)
	if tex != null:
		draw_texture_rect(tex, Rect2(Vector2(size.x * 0.5 - isz2 * 0.5, icon_y - isz2 * 0.5), Vector2(isz2, isz2)), false, icon_col)
	if _font_bold != null:
		var fs2 := int(clampf(unit * 0.17, 14.0, 18.0))
		var lbl_y := icon_y + isz2 * 0.5 + fs2 + 4.0
		draw_string(_font_bold, Vector2(0.0, lbl_y), label_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs2, fg)
		if show_key and not effective_sub.is_empty() and lbl_y + 16.0 < size.y:
			draw_string(_font_reg, Vector2(0.0, size.y - 8.0), effective_sub, HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, Color(fg, 0.62))
