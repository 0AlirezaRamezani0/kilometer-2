class_name TouchAnalogSteerBar
extends Control

## Multi-touch-safe Persian horizontal analog steering slider with deadzone & spring return.
## Outputs steer_value in [-1.0 = full left, +1.0 = full right].

@export_range(0.0, 0.30, 0.01) var deadzone: float = 0.08
@export_range(4.0, 25.0, 0.5) var recenter_rate: float = 12.0

var steer_value: float = 0.0
var input_blocked: bool = false:
	set(value):
		input_blocked = value
		if input_blocked:
			_tracking_touch_id = -1
			_mouse_dragging = false
			_raw_axis = 0.0
			_recompute_output()
			queue_redraw()
var _raw_axis: float = 0.0
var _tracking_touch_id: int = -1
var _mouse_dragging: bool = false

var _font_bold: Font = preload("res://assets/fonts/Estedad-Bold.ttf")
var _sb_panel: StyleBoxFlat
var _tl_title: TextLine = TextLine.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_sb_panel = StyleBoxFlat.new()
	_sb_panel.bg_color = Color(UiTheme.COLOR_SURFACE, 0.78)
	_sb_panel.border_color = Color(UiTheme.COLOR_ON_SURFACE, 0.45)
	_sb_panel.set_border_width_all(1)
	_sb_panel.set_corner_radius_all(16)

	_tl_title.clear()
	_tl_title.direction = TextServer.DIRECTION_RTL
	if _font_bold != null:
		_tl_title.add_string("◄   فرمان   ►", _font_bold, 15)


func _process(delta: float) -> void:
	if _tracking_touch_id == -1 and not _mouse_dragging:
		if absf(_raw_axis) > 0.001:
			var alpha := 1.0 - exp(-recenter_rate * delta)
			_raw_axis = lerpf(_raw_axis, 0.0, alpha)
			if absf(_raw_axis) < 0.003:
				_raw_axis = 0.0
			_recompute_output()
			queue_redraw()


func _input(event: InputEvent) -> void:
	if input_blocked or not is_visible_in_tree():
		_tracking_touch_id = -1
		_mouse_dragging = false
		_raw_axis = 0.0
		_recompute_output()
		return

	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		var local_pt := get_global_transform_with_canvas().affine_inverse() * st.position
		var inside := Rect2(Vector2.ZERO, size).has_point(local_pt)
		if st.pressed and _tracking_touch_id == -1 and inside:
			_tracking_touch_id = st.index
			_set_from_local_x(local_pt.x)
		elif not st.pressed and st.index == _tracking_touch_id:
			_tracking_touch_id = -1

	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.index == _tracking_touch_id:
			var local_pt := get_global_transform_with_canvas().affine_inverse() * sd.position
			_set_from_local_x(local_pt.x)

	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		var local_pt := get_global_transform_with_canvas().affine_inverse() * mb.position
		var inside := Rect2(Vector2.ZERO, size).has_point(local_pt)
		if mb.pressed and inside:
			_mouse_dragging = true
			_set_from_local_x(local_pt.x)
		elif not mb.pressed and _mouse_dragging:
			_mouse_dragging = false

	elif event is InputEventMouseMotion and _mouse_dragging:
		var mm := event as InputEventMouseMotion
		var local_pt := get_global_transform_with_canvas().affine_inverse() * mm.position
		_set_from_local_x(local_pt.x)


func set_simulated_raw_axis(axis: float) -> void:
	_mouse_dragging = absf(axis) > 0.0001
	_raw_axis = clampf(axis, -1.0, 1.0)
	_recompute_output()
	queue_redraw()


func _set_from_local_x(lx: float) -> void:
	var usable_half := maxf((size.x - 44.0) * 0.5, 20.0)
	var center_x := size.x * 0.5
	_raw_axis = clampf((lx - center_x) / usable_half, -1.0, 1.0)
	_recompute_output()
	queue_redraw()


func _recompute_output() -> void:
	var mag := absf(_raw_axis)
	if mag <= deadzone:
		steer_value = 0.0
	else:
		var norm := (mag - deadzone) / maxf(1.0 - deadzone, 0.01)
		steer_value = signf(_raw_axis) * clampf(norm, 0.0, 1.0)


func _draw() -> void:
	draw_style_box(_sb_panel, Rect2(Vector2.ZERO, size))

	var cy := size.y * 0.62
	var cx := size.x * 0.5
	var half_w := maxf((size.x - 48.0) * 0.5, 20.0)

	# Track rail + center deadzone band + active deflection bar
	draw_line(Vector2(cx - half_w, cy), Vector2(cx + half_w, cy), Color(0.35, 0.40, 0.47, 0.90), 6.0)
	var dz_px := half_w * deadzone
	draw_rect(Rect2(Vector2(cx - dz_px, cy - 9.0), Vector2(dz_px * 2.0, 18.0)), Color(0.45, 0.52, 0.60, 0.35), true)

	var puck_x := cx + _raw_axis * half_w
	if absf(steer_value) > 0.001:
		draw_line(Vector2(cx, cy), Vector2(puck_x, cy), Color(UiTheme.COLOR_ACCENT_SECONDARY, 0.95), 6.0)

	var puck_col := Color(UiTheme.COLOR_ACCENT_SECONDARY, 0.98) if absf(steer_value) > 0.001 else Color(0.85, 0.89, 0.94, 0.94)
	draw_circle(Vector2(puck_x, cy), 19.0, puck_col)
	draw_circle(Vector2(puck_x, cy), 8.5, Color(0.10, 0.16, 0.24, 0.90))

	var tsz := _tl_title.get_size()
	_tl_title.draw(get_canvas_item(), Vector2((size.x - tsz.x) * 0.5, 10.0), Color(0.90, 0.93, 0.96, 0.95))
