class_name TouchSteeringWheel
extends Control

## B9 — «غربیلک فرمان» بازطراحی‌شده (premium sport wheel).
##
## Design goals (user feedback: the old wheel was a tiny 96 px doodle):
##  * reads as a real 3-spoke sport wheel at ANY widget size (all radii are
##    derived from `size`, nothing is a hardcoded pixel),
##  * live steering feedback: rim rotates, the active side of the rim lights
##    in the steering accent colour, and a torque arc fills from 12 o'clock,
##  * center hub shows the live steer percentage while the player is holding,
##  * generous grab area (the whole widget, not only the rim) + thumb-drag
##    anywhere, so it is easy to use with a thumb on a phone,
##  * spring return to center when released (same physics as before).
##
## Public API is unchanged: steer_value [-1..1], input_blocked,
## set_simulated_steer(), max_wheel_deg, recenter_rate.

@export_range(120.0, 360.0, 10.0) var max_wheel_deg: float = 250.0
@export_range(4.0, 24.0, 0.5) var recenter_rate: float = 10.5
## Thumb travel dead-zone (px) before a rotation counts.
@export var min_drag_px: float = 6.0

var steer_value: float = 0.0 # [-1.0 = full left, +1.0 = full right]
var input_blocked: bool = false:
	set(value):
		input_blocked = value
		if input_blocked:
			_tracking_touch_id = -1
			_mouse_dragging = false
			_wheel_angle_deg = 0.0
			steer_value = 0.0
			_glow = 0.0
			queue_redraw()
var _wheel_angle_deg: float = 0.0
var _tracking_touch_id: int = -1
var _mouse_dragging: bool = false
var _prev_pointer_angle_rad: float = 0.0
var _glow: float = 0.0          # 0..1 held-state highlight
var _hint_alpha: float = 1.0    # fades the «بکشید» hint after first grab

var _font_bold: Font = null
var _font_reg: Font = null
var _tl_hub: TextLine = TextLine.new()
var _tl_pct: TextLine = TextLine.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	_font_bold = UiTheme.font_bold()
	_font_reg = UiTheme.font_regular()
	if _font_bold == null:
		_font_bold = ThemeDB.fallback_font
	if _font_reg == null:
		_font_reg = _font_bold
	# TextLine refuses a zero font size (engine prints «Condition p_size <= 0»),
	# so the placeholder uses a real size; _draw() re-shapes both lines at the
	# widget-size-driven size on every redraw.
	_tl_hub.clear()
	_tl_hub.direction = TextServer.DIRECTION_RTL
	_tl_hub.add_string("K2", _font_bold, 16)
	_tl_pct.clear()
	_tl_pct.direction = TextServer.DIRECTION_LTR
	set_process(true)


func _process(delta: float) -> void:
	var held := _tracking_touch_id != -1 or _mouse_dragging
	var target_glow := 1.0 if held else 0.0
	if not is_equal_approx(_glow, target_glow):
		_glow = move_toward(_glow, target_glow, delta * 6.0)
		queue_redraw()
	if held and _hint_alpha > 0.0:
		_hint_alpha = maxf(0.0, _hint_alpha - delta * 2.0)
		queue_redraw()
	if not held and absf(_wheel_angle_deg) > 0.15:
		var alpha := 1.0 - exp(-recenter_rate * delta)
		_wheel_angle_deg = lerpf(_wheel_angle_deg, 0.0, alpha)
		if absf(_wheel_angle_deg) < 0.25:
			_wheel_angle_deg = 0.0
		steer_value = clampf(_wheel_angle_deg / max_wheel_deg, -1.0, 1.0)
		queue_redraw()


func set_simulated_steer(norm_val: float) -> void:
	_mouse_dragging = absf(norm_val) > 0.001
	_wheel_angle_deg = clampf(norm_val, -1.0, 1.0) * max_wheel_deg
	steer_value = clampf(_wheel_angle_deg / max_wheel_deg, -1.0, 1.0)
	_glow = 1.0 if _mouse_dragging else 0.0
	queue_redraw()


func reset_to_center() -> void:
	_tracking_touch_id = -1
	_mouse_dragging = false
	_wheel_angle_deg = 0.0
	steer_value = 0.0
	queue_redraw()


func _grab_radius() -> float:
	return minf(size.x, size.y) * 0.52


func _input(event: InputEvent) -> void:
	if input_blocked or not is_visible_in_tree():
		if _tracking_touch_id != -1 or _mouse_dragging:
			reset_to_center()
		return

	var center := size * 0.5
	var hit_r := _grab_radius()

	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		var local_pt := get_global_transform_with_canvas().affine_inverse() * st.position
		if st.pressed and _tracking_touch_id == -1 and local_pt.distance_to(center) <= hit_r:
			_tracking_touch_id = st.index
			_prev_pointer_angle_rad = (local_pt - center).angle()
			queue_redraw()
		elif not st.pressed and st.index == _tracking_touch_id:
			_tracking_touch_id = -1
			queue_redraw()

	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.index == _tracking_touch_id:
			var local_pt := get_global_transform_with_canvas().affine_inverse() * sd.position
			_apply_pointer_move(local_pt - center)

	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		var local_pt := get_global_transform_with_canvas().affine_inverse() * mb.position
		if mb.pressed and local_pt.distance_to(center) <= hit_r:
			_mouse_dragging = true
			_prev_pointer_angle_rad = (local_pt - center).angle()
			queue_redraw()
		elif not mb.pressed and _mouse_dragging:
			_mouse_dragging = false
			queue_redraw()

	elif event is InputEventMouseMotion and _mouse_dragging:
		var mm := event as InputEventMouseMotion
		var local_pt := get_global_transform_with_canvas().affine_inverse() * mm.position
		_apply_pointer_move(local_pt - center)


func _apply_pointer_move(rel: Vector2) -> void:
	if rel.length_squared() < min_drag_px * min_drag_px:
		return
	var cur_ang := rel.angle()
	var delta_rad := wrapf(cur_ang - _prev_pointer_angle_rad, -PI, PI)
	_prev_pointer_angle_rad = cur_ang
	_wheel_angle_deg = clampf(_wheel_angle_deg + rad_to_deg(delta_rad), -max_wheel_deg, max_wheel_deg)
	steer_value = clampf(_wheel_angle_deg / max_wheel_deg, -1.0, 1.0)
	queue_redraw()


# ------------------------------------------------------------------- drawing
func _draw() -> void:
	var c := size * 0.5
	var unit := minf(size.x, size.y)
	var r_out := unit * 0.43            # outer rim centre-line radius
	var rim_w := maxf(10.0, unit * 0.085) # rim thickness scales with the widget
	var rot := deg_to_rad(_wheel_angle_deg)

	var cyan := UiTheme.COLOR_ACCENT_SECONDARY
	var verm := UiTheme.COLOR_ACCENT_PRIMARY
	var steel := Color(0.82, 0.87, 0.94, 0.96)
	var graphite := Color(0.12, 0.145, 0.19, 0.98)

	# 1) Glass disc + ambient ring (the "touch zone" itself).
	draw_circle(c, r_out + rim_w * 0.95, Color(0.035, 0.05, 0.075, 0.66))
	draw_arc(c, r_out + rim_w * 0.95, 0.0, TAU, 64, Color(cyan, 0.20 + 0.30 * _glow), maxf(1.5, unit * 0.008), true)

	# 2) Steering travel arc: fills from 12 o'clock toward the active side.
	var travel := absf(steer_value)
	if travel > 0.002:
		var span := deg_to_rad(78.0) * travel
		var base := -PI * 0.5
		var col := cyan if steer_value > 0.0 else Color(0.55, 0.78, 1.0, 1.0)
		if steer_value > 0.0:
			draw_arc(c, r_out + rim_w * 0.95, base, base + span, 24, col, maxf(2.0, unit * 0.014), true)
		else:
			draw_arc(c, r_out + rim_w * 0.95, base - span, base, 24, col, maxf(2.0, unit * 0.014), true)

	# 3) Rim base: dark charcoal torus, with specular top edge.
	draw_arc(c, r_out, 0.0, TAU, 72, graphite, rim_w, true)
	draw_arc(c, r_out - rim_w * 0.30, -PI * 0.95, -PI * 0.05, 24, Color(1, 1, 1, 0.10), rim_w * 0.22, true)

	# 4) Spokes (rotate with the wheel): two horizontal + one down.
	for sa in [0.0, PI, PI * 0.5]:
		var a: float = float(sa) + rot
		var p_end := c + Vector2(cos(a), sin(a)) * (r_out - rim_w * 0.42)
		var spoke_col := steel if not is_equal_approx(float(sa), PI * 0.5) else Color(0.30, 0.34, 0.40, 0.98)
		draw_line(c, p_end, spoke_col, maxf(6.0, unit * 0.052), true)
		# machined highlight on the spoke
		draw_line(c, p_end, Color(1, 1, 1, 0.16), maxf(1.5, unit * 0.012), true)

	# 5) Leather side grips (white leather at 9 and 3 o'clock) + grip stitches.
	for base_a in [0.0, PI]:
		var a0: float = float(base_a) + rot - 0.62
		var a1: float = float(base_a) + rot + 0.62
		draw_arc(c, r_out, a0, a1, 22, Color(0.93, 0.95, 0.98, 0.97), rim_w * 0.96, true)
		# stitch line
		draw_arc(c, r_out, a0 + 0.06, a1 - 0.06, 18, Color(0.45, 0.50, 0.58, 0.55), maxf(1.0, unit * 0.006), true)

	# 6) Top-center racing marker (vermilion), rotates with the rim.
	var top_a := -PI * 0.5 + rot
	draw_arc(c, r_out, top_a - 0.10, top_a + 0.10, 10, verm, rim_w * 1.02, true)
	draw_circle(c + Vector2(cos(top_a), sin(top_a)) * r_out, maxf(2.0, unit * 0.016), Color(1.0, 0.30, 0.24, 1.0))

	# 7) Hub: brushed plate, red hex bolts, K2 wordmark, live percentage.
	var hub_r := r_out * 0.42
	draw_circle(c, hub_r, Color(0.085, 0.105, 0.145, 0.99))
	draw_arc(c, hub_r, 0.0, TAU, 40, Color(cyan, 0.35 + 0.35 * _glow), maxf(1.2, unit * 0.007), true)
	for b_i in range(6):
		var ba := rot + float(b_i) * TAU / 6.0
		draw_circle(c + Vector2(cos(ba), sin(ba)) * (hub_r * 0.74), maxf(1.6, unit * 0.011), Color(0.86, 0.22, 0.20, 0.95))

	var held := _tracking_touch_id != -1 or _mouse_dragging
	var pct := int(round(steer_value * 100.0))
	_tl_hub.clear()
	_tl_hub.direction = TextServer.DIRECTION_LTR
	_tl_hub.add_string(("K2" if not held else "%d%%" % pct), _font_bold, int(maxf(13.0, unit * 0.085)))
	var tsz := _tl_hub.get_size()
	_tl_hub.draw(get_canvas_item(), c - tsz * 0.5,
		Color(0.90, 0.95, 1.0, 0.96) if not held else Color(cyan, 1.0))

	# 8) «بکشید» affordance under the wheel, fades after first grab.
	if _hint_alpha > 0.01 and _glow < 0.5:
		_tl_pct.clear()
		_tl_pct.direction = TextServer.DIRECTION_RTL
		_tl_pct.add_string("بچرخانید", _font_reg, int(maxf(13.0, unit * 0.07)))
		var hsz := _tl_pct.get_size()
		_tl_pct.draw(get_canvas_item(), Vector2(c.x - hsz.x * 0.5, size.y - hsz.y * 1.05),
			Color(0.92, 0.95, 1.0, 0.85 * _hint_alpha))
